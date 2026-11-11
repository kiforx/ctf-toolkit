# Windows: Enumeration / Post-Exploitation (вторинно)

**Навіщо:** якщо ціль — Windows. За профілем тесту ймовірніший Linux, тому тут — мінімум робочих сценаріїв, а не повний курс.
**Коли:** nmap показав 139/445/3389/5985/135, або ОС Windows.
← [MASTER](../01-roadmaps/MASTER-ROADMAP.md) · [windows cheatsheet](windows-cheatsheet.md) · [smb](../03-cheatsheets/smb-enum.md)

---

## 5 типових сценаріїв (найчастіше на easy/medium)
| # | Сценарій | Ознака | Вхід |
|---|---|---|---|
| 1 | **SMB-шари** з читабельними файлами | 445 відкритий, null/guest | `smbclient`, `netexec` → креди/флаги у шарах |
| 2 | **Веб-додаток** (IIS/Tomcat/панель) | 80/8080 | default creds (Tomcat `tomcat:tomcat`), upload `.war`/`.aspx` |
| 3 | **Відомий CVE сервісу** | версія з nmap | `searchsploit` (напр. старий SMB/веб) |
| 4 | **Credential reuse** | знайдений пароль | WinRM/SMB/RDP на інших юзерах |
| 5 | **Незахищений сервіс** (MSSQL, FTP) | 1433/21 | default sa, anon FTP |

## Швидка розвідка
```bash
nmap -p- -sCV $TARGET -oN win-all.txt
netexec smb $TARGET                      # ОС/домен/ім'я
netexec smb $TARGET -u '' -p '' --shares # null шари
enum4linux-ng -A $TARGET
```

## Доступ і робота з Kali
```bash
# WinRM (5985) — головний спосіб "shell" на Windows з Kali
netexec winrm $TARGET -u user -p pass
evil-winrm -i $TARGET -u user -p pass
# RDP (3389)
xfreerdp /u:user /p:pass /v:$TARGET
# MSSQL (1433)
netexec mssql $TARGET -u sa -p pass
```

## Пост-експлойт (без адміна — аналог "без рута")
```powershell
whoami /all                      # привілеї та групи
net user ; net localgroup administrators
systeminfo                       # версія/патчі -> відомі CVE
```
- Файли/флаги: `C:\Users\*\Desktop`, `Documents`, `C:\inetpub\wwwroot`, `C:\xampp\htdocs`.
- Паролі: `*.config`, `web.config`, `unattend.xml`, PowerShell history
  (`%APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt`).
- Credential reuse між юзерами — так само як на Linux.

## Flag-hunt (Windows)
> Літери флагу розбиті сепараторами `-_.`, тож пошук літерального `bestCTF` їх не ловить. PowerShell-regex із шумом:
```powershell
$fr = 'b[-_.]*e[-_.]*s[-_.]*t[-_.]*C[-_.]*T[-_.]*F[-_.]*\{[A-Za-z0-9_]+\}:[A-Za-z0-9]+'
Get-ChildItem C:\ -Recurse -Include *.txt,*.config,*.xml -ErrorAction SilentlyContinue | Select-String -Pattern $fr
```
Альтернатива: забрати цікаві файли на Kali ([file-transfer](../02-workflows/file-transfer.md)) і прогнати [flags_searcher_obf.sh](../05-scripts/flags_searcher_obf.sh).

## Пастки
- На Windows не витрачати багато часу, якщо ціль — Linux.
- `evil-winrm` має бути встановлений на Kali заздалегідь ([pre-game](../00-setup/pre-game-checklist.md)).
