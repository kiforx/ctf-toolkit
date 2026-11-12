# Windows: Fundamentals (рівно стільки, щоб діяти)

**Навіщо:** не курс з адміністрування, а мінімум понять, без яких команди з інших файлів незрозумілі: чому `whoami /priv` важливіший за `whoami`, що таке NTLM-хеш і чому його можна «передати», коли ціль — домен.
← [README](README.md) · далі: [enumeration](01-enumeration.md) · [privesc](03-privesc.md) · [AD](05-active-directory.md)

---

## 1. Користувачі, групи, SID
- **SID** (Security Identifier) — унікальний ідентифікатор суб'єкта, напр. `S-1-5-21-<domain>-500`.
  - `-500` = вбудований **Administrator**; `-501` = Guest; `-512` = Domain Admins; `-513` = Domain Users; `S-1-5-18` = **SYSTEM**.
- Ключові групи локально: **Administrators** (повний контроль хоста), **Backup Operators** (читання будь-яких файлів → витяг SAM), **Remote Management Users** (доступ по WinRM), **Remote Desktop Users** (RDP).
- `whoami /groups` показує членство (у т.ч. доменні групи) — звідти видно, куди юзер має доступ.
> **Практичний сенс:** мета privesc — стати членом `Administrators` або отримати `SYSTEM`. Мета в домені — дійти до `Domain Admins`.

## 2. Access tokens, привілеї, integrity levels
- Кожен процес несе **токен** з SID-ами й **привілеями** (`Se*Privilege`). Привілеї — це не групи; їх дає `whoami /priv`.
- «Золоті» привілеї для privesc (детально → [privesc](03-privesc.md#1-зловживання-привілеями-токена)):
  | Привілей | Що дає |
  |---|---|
  | **SeImpersonatePrivilege** | імперсонувати токен → Potato-атаки → SYSTEM (часто у service-акаунтів: IIS, MSSQL) |
  | **SeAssignPrimaryToken** | те саме сімейство |
  | **SeBackupPrivilege** | читати будь-який файл (копія SAM/SYSTEM) |
  | **SeRestorePrivilege** | писати будь-який файл |
  | **SeDebugPrivilege** | доступ до пам'яті процесів (дамп LSASS) |
  | **SeTakeOwnership** | стати власником будь-якого об'єкта |
- **Integrity levels:** Low < Medium < High < System. Звичайний процес = Medium; адмін *до* UAC-elevation = Medium, *після* = High; SYSTEM = System. `whoami /groups` показує рядок `Mandatory Label\...Mandatory Level`.
> **Практичний сенс:** побачив `SeImpersonatePrivilege` у `whoami /priv` зі статусом Enabled/Disabled (неважливо) → це майже завжди пряма дорога до SYSTEM. Це перше, що перевіряти.

## 3. UAC (User Account Control)
- Адмін-юзер працює з **Medium**-токеном; адмінські дії вимагають «elevation» (High). Це **не межа безпеки**, а зручність — але на практиці обмежений High-shell доводиться «піднімати» (UAC bypass) або брати SYSTEM напряму.
- Ознака: ти в групі Administrators (`whoami /groups`), але `whoami /priv` бідний і запис у `C:\Windows` падає → потрібен elevated-контекст.
> **Практичний сенс:** якщо вже в Administrators — простіше взяти SYSTEM через Potato/службу, ніж возитися з UAC-bypass.

## 4. Permissions (NTFS / об'єкти / сервіси)
- NTFS-права читає/міняє **`icacls`** (сучасний) та **`accesschk`** (Sysinternals, детальніше по сервісах/реєстру).
  - `(F)` full, `(M)` modify, `(W)` write, `(R)` read, `(RX)` read+execute.
- Групи, що цікавлять для privesc: **`Everyone`**, **`Authenticated Users`**, **`BUILTIN\Users`**, **`NT AUTHORITY\INTERACTIVE`** з правом **W/M/F** на чужий бінар/сервіс/теку.
> **Практичний сенс:** `(Users ... W)` на бінарі сервісу, що стартує від SYSTEM → підміна → SYSTEM. Саме це шукає accesschk ([privesc](03-privesc.md)).

## 5. NTLM (аутентифікація)
- Пароль зберігається як **NT-хеш** (MD4 від UTF-16 паролю) — це і є «NTLM-хеш» у рядку SAM `user:RID:LM:NT:::`.
- **NTLM-хеш = пароль для багатьох протоколів.** Знаючи NT-хеш, не треба знати пароль: **Pass-the-Hash** працює по SMB/WinRM/RPC (→ [lateral](06-lateral-postex.md#pass-the-hash)).
- **NetNTLMv2** — це *не* те саме: це challenge-response з мережі (ловиться Responder), його **не можна** передати як PtH, лише **крекати** офлайн (`hashcat -m 5600`).
> **Практичний сенс:** `aad3b435...:31d6cfe0...` → NT-хеш (PtH або `-m 1000` крек). `user::DOMAIN:1122...:...` → NetNTLMv2 (тільки крек `-m 5600`). Плутанина типів — класична втрата часу.

## 6. Kerberos (домен)
- У домені основна автентифікація — Kerberos. Спрощено: клієнт бере **TGT** у KDC (контролер домену), потім **TGS**-квиток на конкретний сервіс (SPN).
- Дві атаки, що працюють без доступу до хоста (лише валідний/і навіть невалідний доменний контекст):
  - **Kerberoasting:** будь-який доменний юзер може запросити TGS на сервісний акаунт (SPN) → квиток зашифровано хешем пароля сервіс-акаунта → крек офлайн (`-m 13100`). → [AD](05-active-directory.md#kerberoasting).
  - **AS-REP Roasting:** юзери з «Do not require Kerberos preauth» віддають шифрований AS-REP **без автентифікації** → крек (`-m 18200`). → [AD](05-active-directory.md#as-rep-roasting).
- **Pass-the-Ticket:** вкрадений/підроблений квиток (.ccache/.kirbi) імпортується й використовується. → [lateral](06-lateral-postex.md#pass-the-ticket).
> **Практичний сенс:** відкриті порти **88** (Kerberos) + **389** (LDAP) = це домен-контролер → переходь на [AD](05-active-directory.md), а не лише локальний enum.

## 7. Active Directory — мінімум понять
- **Domain** — база об'єктів (users, groups, computers, GPO) на **Domain Controller (DC)**.
- Автентифікація/пошук: **LDAP** (389/636), **Kerberos** (88), **SMB/RPC** (445/135). Enum часто починається з **anonymous LDAP** або **null SMB**.
- Шлях атаки в CTF-AD майже завжди: foothold (один доменний юзер) → **BloodHound** збирає граф «хто куди має права» → знаходиш ланцюг (ACL abuse / Kerberoast / вкладені групи) → **Domain Admin** → DCSync (дамп усіх хешів).
> **Практичний сенс:** не намагайся «зрозуміти весь ліс» — ціль проста: один доменний креденшл → граф BloodHound → найкоротший шлях до DA.

---

## Куди далі
- Перший доступ отримано → [01-enumeration](01-enumeration.md).
- Побачив `SeImpersonate`/службу з кривими правами → [03-privesc](03-privesc.md).
- Порти 88/389 → це домен → [05-active-directory](05-active-directory.md).

## Джерела
- Microsoft — Access tokens / SIDs / privileges: https://learn.microsoft.com/en-us/windows/win32/secauthz/access-tokens
- Microsoft — Well-known SIDs: https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/understand-security-identifiers
- HackTricks — NTLM: https://book.hacktricks.wiki/en/windows-hardening/ntlm/index.html
- HackTricks — Kerberos / AD methodology: https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/index.html
- HackTricks — Integrity levels / UAC: https://book.hacktricks.wiki/en/windows-hardening/windows-local-privilege-escalation/index.html
