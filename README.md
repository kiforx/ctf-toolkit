# CTF Toolkit

Офлайн-інструментарій для CTF: roadmaps, workflows, cheatsheets, technique-гайди та скрипти
для розвідки, отримання доступу, пост-експлойту й пошуку прапорців.

Розрахований на роботу **без інтернету** (локальні довідники й скрипти) та **без AI** під час змагання —
усе потрібне зібрано тут, щоб швидко знайти наступну дію й повернутися до практики.

Основне середовище — **Kali**. Усі посилання відносні, працюють офлайн.

---

## Як користуватися

Документація не для лінійного читання. Точка входу під час гри — **[Master Roadmap](01-roadmaps/MASTER-ROADMAP.md)**:
він веде по етапах роботи з ціллю й розгалужується залежно від знахідок. Решта файлів відкривається за посиланнями з нього.

Швидкий старт:
1. Підготувати середовище й інструменти заздалегідь — [pre-game checklist](00-setup/pre-game-checklist.md).
2. Підняти мережу/VPN, перевірити доступ до цілі — [network setup](00-setup/vpn-wireguard.md).
3. Відкрити [Master Roadmap](01-roadmaps/MASTER-ROADMAP.md), запустити розвідку.
4. Усі знахідки (порти, креди, прапорці) одразу фіксувати у спільному нотатнику команди.

---

## Навігація

### Roadmaps — що робити і в якому порядку
| Документ | Коли відкривати |
|---|---|
| **[MASTER ROADMAP](01-roadmaps/MASTER-ROADMAP.md)** | Завжди. Головний алгоритм з розгалуженнями |
| [Recon](01-roadmaps/recon.md) | На старті: що сканувати |
| [Web Enum](01-roadmaps/web-enum.md) | Знайдено HTTP(S) |
| [Initial Access](01-roadmaps/initial-access.md) | Знайдено вразливість/вхід |
| [Post-Exploitation](01-roadmaps/post-exploitation.md) | Отримано доступ |
| [Flag Hunting](01-roadmaps/flag-hunting.md) | Є доступ — пошук прапорців |

### Workflows — як зробити конкретну задачу
[network-enum](02-workflows/network-enum.md) · [web-enum](02-workflows/web-enum.md) · [service-enum](02-workflows/service-enum.md) · [credential-hunting](02-workflows/credential-hunting.md) · [lateral-movement](02-workflows/lateral-movement.md) · [file-transfer](02-workflows/file-transfer.md) · [pivoting](02-workflows/pivoting-portforward.md)

### Cheatsheets — швидкі команди
[exploit-chains (повні потоки)](03-cheatsheets/exploit-chains.md) · [nmap](03-cheatsheets/nmap.md) · [ffuf/gobuster](03-cheatsheets/ffuf-gobuster.md) · [curl](03-cheatsheets/curl.md) · [netcat/socat](03-cheatsheets/netcat-socat.md) · [sqlmap/SQLi](03-cheatsheets/sqlmap-sqli.md) · [databases](03-cheatsheets/databases.md) · [LFI/traversal](03-cheatsheets/lfi-traversal.md) · [command injection](03-cheatsheets/command-injection.md) · [webshells/revshells](03-cheatsheets/webshells-revshells.md) · [SMB](03-cheatsheets/smb-enum.md) · [grep/find](03-cheatsheets/grep-find.md) · [linux-quick](03-cheatsheets/linux-quick.md)

### Techniques — зрозуміти механізм
[perms/SUID/cap](04-techniques/linux-perms-suid-cap.md) · [cron/services](04-techniques/cron-services.md) · [credentials reuse](04-techniques/credentials-reuse.md) · [web vulns](04-techniques/web-vulns-overview.md) · [containers](04-techniques/containers.md)

### Scripts
[flagscan.sh](05-scripts/flagscan.sh) (пошук прапорців) · [quick-recon.sh](05-scripts/quick-recon.sh) · [cred-spray-local.sh](05-scripts/cred-spray-local.sh) · [опис](05-scripts/README.md)

### Tools (готові бінарники/скрипти для заливки на ціль)
[linpeas/pspy/chisel/socat/ncat, webshells, win-бінарі](tools/README.md) — ~31 МБ, працюють офлайн.

### Windows (вторинно)
[windows-enum](06-windows/windows-enum.md) · [windows cheatsheet](06-windows/windows-cheatsheet.md)

### Довідка
[джерела та статус перевірки](09-research/sources.md)

---

## Формат прапорця (поточна ціль)
```
best + CTF із шумом [-_.] + {payload} + :<номер>
приклад:  be_s_t_CTF-_{h1dd3n_r0b0ts_txt}:1
```
Пошук — [flagscan.sh](05-scripts/flagscan.sh) або [flag-hunting roadmap](01-roadmaps/flag-hunting.md).
Формат налаштовується: `FLAG_REGEX`/`NOISE` у скрипті змінюються під будь-яку ціль.

---

## Легенда позначок
`P1/P2/P3` — пріоритет (критично / бажано / опційно) · `повтор` — повернутися до кроку · `→` наступний документ.

## Обмеження / правила
Матеріали орієнтовані на дозволені дії: розвідка, enum, пошук прапорців. Без деструктиву (DoS, видалення сервісів/файлів, блокування інших) — конкретні обмеження завжди за правилами конкретного змагання.
