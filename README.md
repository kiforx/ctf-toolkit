# CTF Toolkit

Офлайн-інструментарій для CTF (KotH): roadmaps, workflows, cheatsheets, technique-гайди та скрипти
для розвідки, отримання доступу, підняття до **root** і пошуку прапорців.

**Ціль основного етапу:** отримати root і вписати назву команди у `king.txt` (платформа нараховує бали за утримання вершини); прапорці — бонус по дорозі; знайдені вразливості **патчити** в міру. Деталі — [patching/defense](patching/README.md).

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
[exploit-chains (повні потоки)](03-cheatsheets/exploit-chains.md) · [nmap](03-cheatsheets/nmap.md) · [ffuf/gobuster](03-cheatsheets/ffuf-gobuster.md) · [curl](03-cheatsheets/curl.md) · [netcat/socat](03-cheatsheets/netcat-socat.md) · [sqlmap/SQLi](03-cheatsheets/sqlmap-sqli.md) · [databases](03-cheatsheets/databases.md) · [LFI/traversal](03-cheatsheets/lfi-traversal.md) · [command injection](03-cheatsheets/command-injection.md) · [SSTI](03-cheatsheets/ssti.md) · [XXE](03-cheatsheets/xxe.md) · [auth/JWT](03-cheatsheets/auth-jwt.md) · [XSS](03-cheatsheets/xss.md) · [webshells/revshells](03-cheatsheets/webshells-revshells.md) · [SMB](03-cheatsheets/smb-enum.md) · [grep/find](03-cheatsheets/grep-find.md) · [reversing](03-cheatsheets/reversing.md) · [linux-quick](03-cheatsheets/linux-quick.md)

### Techniques — зрозуміти механізм
[perms/SUID/cap](04-techniques/linux-perms-suid-cap.md) · [cron/services](04-techniques/cron-services.md) · [credentials reuse](04-techniques/credentials-reuse.md) · [web vulns](04-techniques/web-vulns-overview.md) · [containers](04-techniques/containers.md)

### Ports — довідник портів
[ports](08-ports/README.md) — поширені + незвичні порти: що це може бути і з чого почати

### Scripts
[flags_searcher_obf.sh](05-scripts/flags_searcher_obf.sh) (пошук прапорців) · [flag-encode.sh](05-scripts/flag-encode.sh) (→ `bestCTF{FLAG}`) · [quick-recon.sh](05-scripts/quick-recon.sh) · [cred-spray-local.sh](05-scripts/cred-spray-local.sh) · [опис](05-scripts/README.md)

### Tools (готові бінарники/скрипти для заливки на ціль)
[linpeas/pspy/chisel/socat/ncat, webshells, win-бінарі](tools/README.md) — ~31 МБ, працюють офлайн.

### Windows (окремий напрям)
Повна база: **[windows/](windows/README.md)** — [fundamentals](windows/00-fundamentals.md) · [enum](windows/01-enumeration.md) · [cmd/powershell](windows/02-cmd-powershell.md) · [privesc](windows/03-privesc.md) · [credentials](windows/04-credentials.md) · [AD](windows/05-active-directory.md) · [lateral/post-ex](windows/06-lateral-postex.md) · [forensics/logs](windows/07-forensics-logs.md) · [cheatsheet](windows/cheatsheet.md)

### Forensics & Stego (окремий напрям — дослідження файлів)
Повна база: **[forensics/](forensics/README.md)** — [file-triage](forensics/01-file-triage.md) · [metadata](forensics/02-metadata.md) · [archives/carving](forensics/03-archives-carving.md) · [memory/disk/logs](forensics/04-memory-disk-logs.md) · [stego-images](forensics/05-stego-images.md) · [stego-audio](forensics/06-stego-audio.md) · [stego-other](forensics/07-stego-other.md) · [cheatsheet](forensics/cheatsheet.md) · [tools](forensics/tools.md)

### Patching / Defense (окремий напрям — утримання вершини на KotH)
Закрити вразливість, якою зайшов, не вбиваючи сервіс. Повна база: **[patching/](patching/README.md)** — [метод](patching/00-method.md) · [web](patching/01-web.md) (webshell/upload/LFI/cmdi/SQLi/SSTI/XXE) · [сервіси](patching/02-services.md) (SSH/FTP/SMB/Redis/БД/SNMP/NFS) · [система](patching/03-system.md) (SUID/cron/sudo/креди) · [cheatsheet](patching/cheatsheet.md)

### Довідка
[джерела та статус перевірки](09-research/sources.md)

---

## Формат прапорця
```
на машині:    be-.s-tCT.F--{FLAG}:<буква><номер>    напр. be-.s-tCT.F--{h1dd3n}:A3
на платформу: bestCTF{FLAG}                          напр. bestCTF{h1dd3n}
```
`best`+`CTF` із шумом `[-_.]`, тіло `{...}`, суфікс `:<буква-категорія><номер>` = у який слот здавати.
На платформу вносимо **лише `bestCTF{FLAG}`** (без букви/номера). Нормалізація — [flag-encode.sh](05-scripts/flag-encode.sh).
Пошук — [flags_searcher_obf.sh](05-scripts/flags_searcher_obf.sh) · деталі — [flag-hunting](01-roadmaps/flag-hunting.md).

---

## Легенда позначок
`P1/P2/P3` — пріоритет (критично / бажано / опційно) · `повтор` — повернутися до кроку · `→` наступний документ.

## Обмеження / правила (SG main)
Дозволено: розвідка, enum, вхід, підняття до root на **своїй** цілі, пошук прапорців, **патчинг** своєї машини.
Заборонено (бан): DoS/флуд/брут платформи · вимикати машину, видаляти сервіси/системні файли · **видаляти чи змінювати прапорці** · блокувати інших фаєрволом · **атакувати IP інших учасників** (навіть із захопленої машини) · **AI-асистенти** (штраф). Повні правила — у брифі організаторів.
