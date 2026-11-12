# MASTER ROADMAP

**Головний алгоритм роботи з ціллю.** Не лінійний — рух за розгалуженнями «якщо знайдено X → крок Y».
Повертатися сюди після завершення кроку або при затику.

> **Ціль (основний етап, KotH):** отримати **root** і вписати назву команди у `king.txt` — платформа читає його й нараховує бали за утримання вершини. Прапорці знаходимо по дорозі до рута (бонусні бали). Знайдені вразливості **патчимо** (в міру), щоб суперники не пройшли тим самим шляхом.
> Повний шлях: recon → вхід → **privilege escalation до root** → `king.txt` + патч. Flag-hunt — на кожному рівні доступу.

---

## 0. Підготовка
-VPN піднятий (`sudo wg show` → `latest handshake`) · [vpn](../00-setup/vpn-wireguard.md)
`ping -c2 <TARGET>` відповідає
-Listener для revshell — на VPN-адресі `10.8.N.x` (там, де піднятий VPN), інакше shell не дійде
-Спільний нотатник для знахідок відкрито — усі порти/креди/прапорці туди

---

## 1. Recon — перше сканування (паралельно)
→ детально: [recon roadmap](recon.md) · [network-enum workflow](../02-workflows/network-enum.md) · [nmap cheatsheet](../03-cheatsheets/nmap.md)

```bash
# A) Швидкий — щоб одразу почати працювати
nmap -sC -sV -T4 --open <TARGET> -oN nmap-quick.txt
# B) Повний (паралельно, у фоні)
nmap -p- -T4 --min-rate 2000 --open <TARGET> -oN nmap-allports.txt
# C) UDP топ (третій термінал)
sudo nmap -sU --top-ports 50 <TARGET> -oN nmap-udp.txt
```

### Розгалуження за портами:
| Знайдено | → Куди |
|---|---|
| **80/443/8080/8000** HTTP(S) | [Web Enum](#2-web-enum) — зазвичай головний вектор |
| **21** FTP | [service-enum: FTP](../02-workflows/service-enum.md#ftp) — anonymous |
| **22** SSH | Поки мимо. Повернення з кредами ([lateral](../02-workflows/lateral-movement.md)) |
| **139/445** SMB | [service-enum: SMB](../02-workflows/service-enum.md#smb) + [smb cheatsheet](../03-cheatsheets/smb-enum.md) |
| **3306/5432/6379/27017** DB/Redis | [databases cheatsheet](../03-cheatsheets/databases.md) — enum/dump/outfile/Redis-foothold |
| **3389/5985** RDP/WinRM | Windows → [windows/](../windows/README.md) |
| Нетиповий порт | `nc -nv <TARGET> <PORT>`, banner → `searchsploit`; що це може бути → [ports](../08-ports/README.md) |

**Правило:** жоден порт не ігнорувати. Кожен порт = потенційний прапорець.

---

## 2. Web Enum
→ детально: [web-enum roadmap](web-enum.md) · [workflow](../02-workflows/web-enum.md)

Порядок: `whatweb <url>` → перегляд сайту + **View Source** → `gobuster/ffuf` директорії → форми вводу/параметри/upload/login.

### Розгалуження (→ готовий потік команд):
| Знайдено | Деталі | Повний ланцюжок |
|---|---|---|
| Login-форма | default creds → [SQLi bypass](../03-cheatsheets/sqlmap-sqli.md) | [chain: SQLi](../03-cheatsheets/exploit-chains.md#sqli) |
| Параметр `?file=`/`?page=` | [LFI/traversal](../03-cheatsheets/lfi-traversal.md) | [chain: LFI→RCE](../03-cheatsheets/exploit-chains.md#lfi) |
| Параметр `?cmd=`/ping-форма | [command injection](../03-cheatsheets/command-injection.md) | [chain: cmd-inj](../03-cheatsheets/exploit-chains.md#cmdi) |
| Форма upload | [webshell](../03-cheatsheets/webshells-revshells.md) | [chain: upload](../03-cheatsheets/exploit-chains.md#upload) |
| SQLi у `id=1` | [sqlmap/SQLi](../03-cheatsheets/sqlmap-sqli.md) | [chain: SQLi](../03-cheatsheets/exploit-chains.md#sqli) |
| Параметр з URL | SSRF → [web-vulns](../04-techniques/web-vulns-overview.md) | — |
| Ввід відбивається, `{{7*7}}`=49 | [SSTI](../03-cheatsheets/ssti.md) → RCE | [chain: SSTI](../03-cheatsheets/exploit-chains.md#ssti) |
| Ендпоінт приймає XML, upload `.svg`/`.docx` | [XXE](../03-cheatsheets/xxe.md) | [chain: XXE](../03-cheatsheets/exploit-chains.md#xxe) |
| JWT-токен / cookie з `role`,`isAdmin` | [auth/JWT](../03-cheatsheets/auth-jwt.md) | — |
| JSON-логін, проходить `{"$ne":null}` | [NoSQLi](../04-techniques/web-vulns-overview.md#nosqli) | — |
| CMS (WordPress/Joomla) | версія → `searchsploit`, вразливі плагіни | — |
| `.git/` `.bak` `~` | завантажити й читати сорси/креди | — |
| Нічого | ffuf з розширеннями (`.php,.txt,.bak,.zip`), vhosts, інші порти | — |

---

## 3. Initial Access
→ детально: [initial-access roadmap](initial-access.md) · готові повні ланцюжки: [exploit-chains](../03-cheatsheets/exploit-chains.md)

Мета — виконання команд або валідні креди. Варіанти: webshell → reverse shell ([revshells](../03-cheatsheets/webshells-revshells.md)), SSH зі знайденими кредами, авторизований доступ до панелі.

**Отримано shell** → стабілізувати (PTY), далі ↓
```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'  # Ctrl+Z; stty raw -echo; fg; export TERM=xterm
```
→ одразу пошук прапорця на місці ([flag-hunting](flag-hunting.md)), далі [Post-Exploitation](#4-post-exploitation).

**Отримано креди (не shell)** → перевірити їх на всіх сервісах → [lateral-movement](../02-workflows/lateral-movement.md).

---

## 4. Post-Exploitation → Privilege Escalation до root <a id="4-post-exploitation"></a>
→ детально: [post-exploitation roadmap](post-exploitation.md) · [perms/SUID/cap](../04-techniques/linux-perms-suid-cap.md) · [cron/services](../04-techniques/cron-services.md)

Швидкий автозбір (готовий блок — [linux-quick: швидкі вектори](../03-cheatsheets/linux-quick.md)):
```bash
id; sudo -l; cat ~/.bash_history; ls -la ~ /home/*; env
ss -tlnp 2>/dev/null                 # внутрішні сервіси на localhost
./linpeas.sh ; ./les.sh              # авто-enum priv-esc (залити з tools/)
```
→ залити: [tools/](../tools/README.md) через [file-transfer](../02-workflows/file-transfer.md).

### Розгалуження (мета — root):
| Знахідка | → |
|---|---|
| `sudo -l` дає команди | [perms/SUID escapes](../04-techniques/linux-perms-suid-cap.md) — готові payload-и до root |
| SUID / capabilities | [perms/SUID/cap](../04-techniques/linux-perms-suid-cap.md) — escape-таблиця |
| Cron/скрипт від root із записом | [cron/services](../04-techniques/cron-services.md) — writable/PATH/wildcard |
| Стара версія ядра | `./les.sh` → kernel exploit |
| Креди в конфігах/`.env`/`history` | [credential-hunting](../02-workflows/credential-hunting.md) → `su`/reuse (інколи root) |
| Внутрішній порт (напр. 3306 на localhost) | [pivoting/port-forward](../02-workflows/pivoting-portforward.md) |

**Отримано root** → вписати назву команди у `king.txt`, далі патчити вектор ([patching](../04-techniques/patching-defense.md)):
```bash
id                                   # uid=0(root)
echo '<НАЗВА_КОМАНДИ>' > /king.txt   # шлях, який читає платформа (уточнити розташування)
```
Кожен новий користувач/рівень = нова домашня директорія = ймовірно новий прапорець.

---

## 5. Flag Hunting
→ детально: [flag-hunting roadmap](flag-hunting.md) · пошук [flags_searcher_obf.sh](../05-scripts/flags_searcher_obf.sh) · здача [flag-encode.sh](../05-scripts/flag-encode.sh)

На кожному рівні доступу:
```bash
printf '%s' 'S@mEvEryC0olk3Y1414$' > /tmp/.k            # ключ у файл (один раз)
bash flags_searcher_obf.sh --key /tmp/.k --directory / | bash flag-encode.sh   # → bestCTF{FLAG}  slot=A3
# keyless-варіант:
grep -raoHE 'b[-_.]*e[-_.]*s[-_.]*t[-_.]*C[-_.]*T[-_.]*F[-_.]*\{[[:alnum:]_]+\}:[A-Za-z0-9]+' / 2>/dev/null | sort -u
```
Місця: `/home/*`, `/var/www`, `/opt`, `/srv`, `/tmp`, `/var/mail`, конфіги, БД, `/var/backups`, env.
Здача: у поле вносимо **лише `bestCTF{FLAG}`**; `:<буква><номер>` = у який слот.

**Знайдено прапорець** → [нормалізувати](flag-hunting.md#перевірка-перед-здачею) у `bestCTF{FLAG}` → здати у слот `:<буква><номер>` → записати у спільний нотатник.

---

## 6. Цикл (поки є час)
```
Новий доступ/креди/порт?  → так → повернення до відповідного enum (крок 1/2/4)
                          → ні  → ще раз flag-hunt + перечитати спільний нотатник
Затик на одному векторі надовго? → позначити rabbit hole, узяти інший вектор
```

---

## Довідники (швидкий доступ)
**Cheatsheets:** [exploit-chains (повні потоки)](../03-cheatsheets/exploit-chains.md) · [nmap](../03-cheatsheets/nmap.md) · [ffuf/gobuster](../03-cheatsheets/ffuf-gobuster.md) · [curl](../03-cheatsheets/curl.md) · [netcat/socat](../03-cheatsheets/netcat-socat.md) · [sqlmap/SQLi](../03-cheatsheets/sqlmap-sqli.md) · [databases](../03-cheatsheets/databases.md) · [LFI/traversal](../03-cheatsheets/lfi-traversal.md) · [command injection](../03-cheatsheets/command-injection.md) · [SSTI](../03-cheatsheets/ssti.md) · [XXE](../03-cheatsheets/xxe.md) · [auth/JWT](../03-cheatsheets/auth-jwt.md) · [XSS](../03-cheatsheets/xss.md) · [webshells/revshells](../03-cheatsheets/webshells-revshells.md) · [SMB](../03-cheatsheets/smb-enum.md) · [grep/find](../03-cheatsheets/grep-find.md) · [reversing](../03-cheatsheets/reversing.md) · [linux-quick](../03-cheatsheets/linux-quick.md)

**Techniques:** [perms/SUID/cap](../04-techniques/linux-perms-suid-cap.md) · [cron/services](../04-techniques/cron-services.md) · [credentials reuse](../04-techniques/credentials-reuse.md) · [web vulns](../04-techniques/web-vulns-overview.md) · [containers](../04-techniques/containers.md) · [patching/defense](../04-techniques/patching-defense.md)

**Інше:** [ports reference](../08-ports/README.md) · [tools (бінарники)](../tools/README.md) · [Windows](../windows/README.md) · [Forensics/Stego](../forensics/README.md) (аналіз знайдених файлів) · [файли/передача](../02-workflows/file-transfer.md)

