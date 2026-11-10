# MASTER ROADMAP

**Головний алгоритм роботи з ціллю.** Не лінійний — рух за розгалуженнями «якщо знайдено X → крок Y».
Повертатися сюди після завершення кроку або при затику.

> Профіль цього CTF: **root не потрібен**, прапорці розкидані по сервісах/юзерах/файлах → акцент на enum, credential reuse і латеральному русі, а не на priv-esc.

---

## 0. Підготовка
- [ ] VPN піднятий (`sudo wg show` → `latest handshake`) · [vpn](../00-setup/vpn-wireguard.md)
- [ ] `ping -c2 <TARGET>` відповідає
- [ ] Спільний нотатник для знахідок відкрито — усі порти/креди/прапорці туди

---

## 1. Recon — перше сканування (паралельно)
→ детально: [recon roadmap](recon.md) · [network-enum workflow](../02-workflows/network-enum.md) · [nmap cheatsheet](../03-cheatsheets/nmap.md)

```bash
# A) Швидкий — щоб одразу почати працювати
nmap -sC -sV -T4 --open <TARGET> -oN nmap-quick.txt
# B) Повний (паралельно, у фоні)
nmap -p- -T4 --open <TARGET> -oN nmap-allports.txt
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
| **3306/5432/6379/27017** DB/Redis | [service-enum: DB](../02-workflows/service-enum.md#бази-даних) — default creds |
| **3389/5985** RDP/WinRM | Windows → [windows-enum](../06-windows/windows-enum.md) |
| Нетиповий порт | `nc -nv <TARGET> <PORT>`, banner → `searchsploit <сервіс версія>` |

**Правило:** жоден порт не ігнорувати. Кожен порт = потенційний прапорець.

---

## 2. Web Enum
→ детально: [web-enum roadmap](web-enum.md) · [workflow](../02-workflows/web-enum.md)

Порядок: `whatweb <url>` → перегляд сайту + **View Source** → `gobuster/ffuf` директорії → форми вводу/параметри/upload/login.

### Розгалуження:
| Знайдено | → |
|---|---|
| Login-форма | default creds (admin:admin) → [SQLi bypass](../03-cheatsheets/sqlmap-sqli.md) |
| Параметр `?file=`/`?page=` | [LFI/traversal](../03-cheatsheets/lfi-traversal.md) — `/etc/passwd`, конфіги, ключі |
| Параметр `?cmd=`/ping-форма | [command injection](../03-cheatsheets/command-injection.md) |
| Форма upload | [webshell](../03-cheatsheets/webshells-revshells.md) |
| Параметр з URL | SSRF → [web-vulns](../04-techniques/web-vulns-overview.md) |
| CMS (WordPress/Joomla) | версія → `searchsploit`, вразливі плагіни |
| `.git/` `.bak` `~` | завантажити й читати сорси/креди |
| Нічого | ffuf з розширеннями (`.php,.txt,.bak,.zip`), vhosts, інші порти |

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

## 4. Post-Exploitation (без рута) <a id="4-post-exploitation"></a>
→ детально: [post-exploitation roadmap](post-exploitation.md)

Швидкий автозбір:
```bash
id; sudo -l; cat ~/.bash_history; ls -la ~ /home/*; env
ss -tlnp 2>/dev/null                 # внутрішні сервіси на localhost
```
→ за наявності часу — залити [linpeas](../02-workflows/file-transfer.md).

### Розгалуження:
| Знахідка | → |
|---|---|
| Креди в конфігах/`.env`/`history` | [credential-hunting](../02-workflows/credential-hunting.md) → перевірка на інших юзерах |
| `sudo -l` дає команди | [perms/SUID](../04-techniques/linux-perms-suid-cap.md) — часто доступ до файлів/флагу |
| Внутрішній порт (напр. 3306 на localhost) | [pivoting/port-forward](../02-workflows/pivoting-portforward.md) |
| SSH-ключ іншого юзера | `ssh -i key user@localhost` → [lateral](../02-workflows/lateral-movement.md) |
| Новий користувач/сервіс | повернення до enum цього сервісу |

**Кожен новий користувач = нова домашня директорія = ймовірно новий прапорець.**

---

## 5. Flag Hunting
→ детально: [flag-hunting roadmap](flag-hunting.md) · скрипт [flagscan.sh](../05-scripts/flagscan.sh)

На кожному рівні доступу:
```bash
bash flagscan.sh --key=KEY /          # пошук за форматом (дедуп, фільтри)
# keyless-варіант:
grep -raoHE 'b[-_.]*e[-_.]*s[-_.]*t[-_.]*C[-_.]*T[-_.]*F[-_.]*\{[[:alnum:]_]+\}:[0-9]+' / 2>/dev/null | sort -u
```
Місця: `/home/*`, `/var/www`, `/opt`, `/srv`, `/tmp`, `/var/mail`, конфіги, БД, `/var/backups`, env.

**Знайдено прапорець** → [перевірити](flag-hunting.md#перевірка-перед-здачею) → здати під номером на платформі → записати в tracker.

---

## 6. Цикл (поки є час)
```
Новий доступ/креди/порт?  → так → повернення до відповідного enum (крок 1/2/4)
                          → ні  → ще раз flag-hunt + перечитати спільний нотатник
Затик на одному векторі надовго? → позначити rabbit hole, узяти інший вектор
```

---

## Довідники (швидкий доступ)
**Cheatsheets:** [exploit-chains (повні потоки)](../03-cheatsheets/exploit-chains.md) · [nmap](../03-cheatsheets/nmap.md) · [ffuf/gobuster](../03-cheatsheets/ffuf-gobuster.md) · [curl](../03-cheatsheets/curl.md) · [netcat/socat](../03-cheatsheets/netcat-socat.md) · [sqlmap/SQLi](../03-cheatsheets/sqlmap-sqli.md) · [databases](../03-cheatsheets/databases.md) · [LFI/traversal](../03-cheatsheets/lfi-traversal.md) · [command injection](../03-cheatsheets/command-injection.md) · [webshells/revshells](../03-cheatsheets/webshells-revshells.md) · [SMB](../03-cheatsheets/smb-enum.md) · [grep/find](../03-cheatsheets/grep-find.md) · [linux-quick](../03-cheatsheets/linux-quick.md)

**Techniques:** [perms/SUID/cap](../04-techniques/linux-perms-suid-cap.md) · [cron/services](../04-techniques/cron-services.md) · [credentials reuse](../04-techniques/credentials-reuse.md) · [web vulns](../04-techniques/web-vulns-overview.md) · [containers](../04-techniques/containers.md)

**Інше:** [tools (бінарники)](../tools/README.md) · [Windows](../06-windows/windows-enum.md) · [файли/передача](../02-workflows/file-transfer.md)

