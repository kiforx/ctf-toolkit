# Windows — технічна база (CTF / KotH)

Першокласний Windows-напрям: від enum незнайомої Windows-цілі до privesc, credentials, Active Directory й post-exploitation. Паралельний трек до Linux-частини — відкривається, коли nmap показав **135/139/445/3389/5985/5986/1433/389** або ОС Windows.

← назад: [MASTER-ROADMAP](../01-roadmaps/MASTER-ROADMAP.md) · суміжне: [SMB](../03-cheatsheets/smb-enum.md) · [ports](../08-ports/README.md) · [tools](../tools/README.md)

> **Статус матеріалів.** Команди — стандартний синтаксис інструментів (impacket/netexec/evil-winrm/PowerShell), звірений з офіційною документацією та HackTricks (джерела в кінці кожного файлу). **Проти живої Windows-цілі в цьому середовищі вони не запускались** — IP/юзера/пароль/домен підставляти на місці. Де команда перевірена практично — позначено явно.

---

## Порядок роботи з Windows-ціллю (швидкий флоу)
```
1. Розвідка ззовні      nmap -p- -sCV  →  порти 445/3389/5985/88/389?  (88/389 = домен-контролер)
2. Enum без кредів       netexec smb/ldap · enum4linux-ng · null/guest сесія · anon LDAP
3. Отримати креди        шари (SMB), веб, default creds, AS-REP roast (без автентифікації)
4. Доступ                evil-winrm (5985) / xfreerdp (3389) / impacket-psexec / mssqlclient
5. Локальний enum        whoami /priv · winPEAS · accesschk · Seatbelt-аналог
6. Privilege escalation  SeImpersonate→Potato · service misconfig · AlwaysInstallElevated · ...
7. Credentials           SAM/LSASS (secretsdump/mimikatz) · DPAPI · cmdkey · конфіги
8. Домен (якщо AD)       BloodHound · Kerberoast · ACL abuse → Domain Admin
9. Lateral / post-ex     Pass-the-Hash · Pass-the-Ticket · pivot до інших хостів
```
Кожен крок → свій файл нижче. На будь-якому рівні доступу — **flag-hunt**: скрипт [flags_searcher.ps1](../05-scripts/flags_searcher.ps1) (пошук+нормалізація) або [cheatsheet](cheatsheet.md#пошук-прапорців).

---

## Файли напряму
| Файл | Призначення | Коли відкривати |
|---|---|---|
| [00-fundamentals](00-fundamentals.md) | Архітектура, SID/токени/integrity/UAC, NTLM/Kerberos, AD-основи | щоб **розуміти**, чому техніка працює (не для заучування) |
| [01-enumeration](01-enumeration.md) | Host+service enum: система, юзери, привілеї, сервіси, таски, мережа, шари | після будь-якого доступу — перше, що робити |
| [02-cmd-powershell](02-cmd-powershell.md) | Практичні основи CMD/PowerShell, ExecutionPolicy, автоматизація | коли бракує синтаксису «як це зробити на Windows» |
| [03-privesc](03-privesc.md) | Повний local privesc: Potato/service/AlwaysInstallElevated/DLL/GPP/... | є обмежений shell, треба SYSTEM/Administrator |
| [04-credentials](04-credentials.md) | SAM/LSASS/DPAPI/Credential Manager/cmdkey/NTLM-хеші | шукати паливо для lateral/privesc |
| [05-active-directory](05-active-directory.md) | LDAP/RPC enum, Kerberoast, AS-REP, BloodHound, ACL abuse | відкриті 88/389/636 → це домен |
| [06-lateral-postex](06-lateral-postex.md) | PtH, PtT, WinRM/WMI/PsExec, рух між хостами, аналіз чужого доступу | є креди/хеш → розширити доступ |
| [07-forensics-logs](07-forensics-logs.md) | Event Logs, PowerShell-логи, LOLBAS, native-утиліти, аналіз файлів | прапорець у логах/метаданих; детект чужої активності |
| [cheatsheet](cheatsheet.md) | Найважливіші команди одним екраном + коротка послідовність | під час гри, коли треба швидко |

**Рекомендований порядок читання до гри:** 00 → 01 → 02 → 03 → 04 → 05 → 06 → 07.
**Під час гри:** [cheatsheet](cheatsheet.md) як індекс, звідти — у потрібний файл.

---

## Інструменти напряму (офлайн, уже в репо)
`tools/windows/` — заливати на ціль через [file-transfer](../02-workflows/file-transfer.md). Версії й SHA-256 — у [tools/README](../tools/README.md#windows--заливати-на-windows-ціль).

| Інструмент | Для чого | Файл |
|---|---|---|
| **winPEAS** | авто-enum privesc/кредів/misconfig | `winPEASx64.exe`, `winPEAS.bat` (без .NET) |
| **accesschk** (Sysinternals) | права на сервіси/файли/реєстр | `accesschk.exe` / `accesschk64.exe` |
| **PrintSpoofer** | SeImpersonate → SYSTEM | `PrintSpoofer64.exe` |
| **GodPotato** | SeImpersonate → SYSTEM (ширша сумісність ОС) | `GodPotato-NET4.exe` |
| **RunasCs** | запуск під іншим юзером з паролем/хешем (без інтерактиву) | `RunasCs.exe` |
| **SharpHound** | збір даних AD для BloodHound | `SharpHound.exe`, `SharpHound.ps1` |
| **nc/plink/wget/whoami** | listener/тунель/завантаження (старі ОС) | `*.exe` |

На Kali (атакуюча сторона, уже встановлено): `netexec`/`nxc`, `evil-winrm`, `impacket-*` (`psexec`, `secretsdump`, `GetUserSPNs`, `GetNPUsers`, `mssqlclient`), `xfreerdp`, `enum4linux-ng`, `ldapsearch`, `bloodhound`/`bloodhound-python`.

---

## Межі напряму
- **Крек хешів** (NTLM/Kerberos) — таблиця `hashcat -m` у [05-active-directory](05-active-directory.md#крек-кербероста) і [04-credentials](04-credentials.md); офлайн, не проти платформи (правила).
- **Персистенція** як закріплення **не є ціллю** KotH; у [06-lateral-postex](06-lateral-postex.md) персистенція розглядається лише для **виявлення чужої** (detection), а не для власного закріплення.
- Правила змагання (не ламати сервіс, не DoS, без AI) діють і тут — див. [patching-defense](../04-techniques/patching-defense.md).

## Джерела (напрям загалом)
- HackTricks — Windows Hardening: https://book.hacktricks.wiki/en/windows-hardening/index.html
- HackTricks — Windows Local Privilege Escalation: https://book.hacktricks.wiki/en/windows-hardening/windows-local-privilege-escalation/index.html
- HackTricks — Active Directory Methodology: https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/index.html
- PayloadsAllTheThings — Windows Privilege Escalation: https://github.com/swisskyrepo/PayloadsAllTheThings
- LOLBAS: https://lolbas-project.github.io/
- MITRE ATT&CK (Enterprise/Windows): https://attack.mitre.org/
