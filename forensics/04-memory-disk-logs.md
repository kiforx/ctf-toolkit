# Forensics: Memory / Disk / Logs (CTF-рівень)

**Навіщо:** memory dump → процеси/команди/паролі/флаг у пам'яті; дисковий образ → файли/видалене; логи → хто що робив. Не повний DFIR, а типові CTF-задачі.
**Коли:** файл — дамп пам'яті (`.raw`/`.vmem`/`.mem`/`.dmp`/`.lime`), образ диску (`.dd`/`.img`/`.E01`) або набір логів.
← [README](README.md) · [file-triage](01-file-triage.md) · Windows-логи на хості: [windows/07-forensics-logs](../windows/07-forensics-logs.md)

---

## A. Memory forensics — Volatility 3

> **Чому Vol3, не Vol2:** Volatility 3 **не потребує профілю** (сам визначає ОС), імена плагінів namespaced (`windows.pslist`). Команда в Kali: `vol` або `vol3` / `python3 vol.py`. Перевір: `vol -h`.

### Крок 1 — впізнати дамп
```bash
vol -f mem.raw windows.info          # ОС/білд/архітектура (Windows)
# якщо Linux-дамп: vol -f mem.lime banners.Banners  → версія ядра (потрібен відповідний symbol table)
```
**Інтерпретація:** `windows.info` дає напр. `Windows 10.0.19041 x64` → підтверджує платформу й що дамп валідний. Linux потребує symbol-таблиці під ядро (часто вузьке місце офлайн).

### Крок 2 — процеси (що запущено / що підозріле)
```bash
vol -f mem.raw windows.pslist        # список процесів (PID/PPID/час)
vol -f mem.raw windows.pstree        # дерево (хто кого породив — аномальні зв'язки)
vol -f mem.raw windows.psscan        # сканування (ловить ПРИХОВАНІ/завершені, яких нема в pslist)
```
**Інтерпретація:** шукай дивне — `powershell`/`cmd` під несподіваним батьком, `notepad` з аномаліями, архіватор як parent браузера. Є в `psscan`, нема в `pslist` → процес ховали.
**Приклад:** BelkaCTF — `pslist` → підозрілий Notepad за PID ([ogmini](https://ogmini.github.io/2025/07/28/BelkaCTF-7-AAR-Whoami.html)); L3AK — `7za.exe` як parent `conhost.exe`/`msedge.exe` виглядав дивно ([hackmd](https://hackmd.io/@nh0kt1g3r12/S1OlHg78gx)).

### Крок 3 — командні рядки й зв'язки
```bash
vol -f mem.raw windows.cmdline       # аргументи процесів (паролі/URL/iex тут!)
vol -f mem.raw windows.netscan       # мережеві з'єднання/порти (C2, exfil)
vol -f mem.raw windows.netstat
```
**Інтерпретація:** `cmdline` часто містить ключ/пароль/`IEX(New-Object Net.WebClient)...` — пряма підказка. `netscan` показує, куди ходив процес.
**Приклад:** wannagame — `cmdline` підтвердив `iex` у PowerShell ([devobass](https://devobass.codeberg.page/posts/2025/wannagame/championship)).

### Крок 4 — витягти дані
```bash
vol -f mem.raw windows.dumpfiles --pid <PID>          # файли процесу
vol -f mem.raw windows.filescan | grep -i flag        # файли в пам'яті за іменем
vol -f mem.raw windows.dumpfiles --virtaddr <addr>    # конкретний файл за офсетом з filescan
vol -f mem.raw windows.hashdump                        # NT-хеші (→ крек: окрема хвиля)
vol -f mem.raw windows.registry.printkey --key 'Software\...'   # ключі реєстру
vol -f mem.raw windows.memmap --pid <PID> --dump      # повний дамп пам'яті процесу → strings по ньому
```
**Далі:** витягнутий файл → [тріаж](01-file-triage.md); дамп пам'яті процесу → `strings dump | grep flag`.

### Часті плагіни (швидкий довідник)
| Задача | Плагін |
|---|---|
| ОС дампу | `windows.info` |
| процеси / дерево / приховані | `windows.pslist` / `windows.pstree` / `windows.psscan` |
| командні рядки | `windows.cmdline` |
| мережа | `windows.netscan` / `windows.netstat` |
| файли в пам'яті | `windows.filescan` → `windows.dumpfiles` |
| реєстр | `windows.registry.hivelist` / `.printkey` |
| хеші | `windows.hashdump` / `windows.lsadump` |
| консоль/історія команд | `windows.cmdscan` / `windows.consoles` |
| буфер обміну, clipboard | (через strings дампу процесу) |

**Обмеження:** Volatility 3 офлайн потребує symbol-tables (Windows вшиті; **Linux/Mac** — під конкретне ядро, часто треба інтернет → підготувати **до гри**). Плагіни з повним іменем, якщо коротке неоднозначне: `windows.pslist.PsList`. Процес у `psscan`, але не в `pslist` — норма для прихованих.

## B. Disk / filesystem images
**Коли:** `.dd`/`.img`/`.raw` (диск) або `.E01` (EnCase).
```bash
file disk.img ; fdisk -l disk.img              # таблиця розділів, офсети
# змонтувати розділ (офсет = start_sector * 512):
sudo mount -o ro,loop,offset=$((2048*512)) disk.img /mnt/x
# E01 → raw:
ewfmount disk.E01 /mnt/ewf ; mount -o ro,loop /mnt/ewf/ewf1 /mnt/x
# The Sleuth Kit (без монтування):
mmls disk.img                                  # розділи
fls -r -o 2048 disk.img                        # лістинг файлів (у т.ч. видалених, познач. *)
icat -o 2048 disk.img <inode> > recovered      # витягти файл за inode
```
**Інтерпретація:** `fls` з `*` = видалений файл → `icat` відновлює. Не монтується → `binwalk`/`foremost` по сирому образу ([carving](03-archives-carving.md)).
**Обмеження:** монтуй **тільки ro** (не псувати доказ); екзотична ФС може не монтуватись → carving.

## C. Logs
```bash
# веб/сервіс-логи: хронологія атаки, URL з payload, креди
grep -iE 'flag|union|select|\.\./|cmd=|base64|wget|curl' access.log
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head   # топ IP (хто довбав)
# Windows .evtx на Kali:
evtx_dump.py Security.evtx | grep -iE '4624|4625|4688'           # (python-evtx)
# лінійка часу по файлах образу:
fls -r -m / -o 2048 disk.img > bodyfile ; mactime -b bodyfile -d > timeline.csv
```
**Інтерпретація:** послідовність подій у логах = таймлайн атаки; payload в URL/командах = що саме робив зловмисник (часто там і флаг/наступний крок).

## Типові пастки
- Vol2-синтаксис (`--profile`) у Vol3 — у Vol3 профілю нема, інші імена плагінів.
- Монтувати образ rw → зіпсувати; завжди `ro`.
- Дивитись лише `pslist` і проґавити приховане (`psscan`).
- Linux-дамп без symbol-table → нічого; готувати до гри.

## Джерела
- Volatility 3 офіц. docs: https://volatility3.readthedocs.io/
- HackTricks — Volatility cheatsheet: https://book.hacktricks.wiki/en/generic-methodologies-and-resources/basic-forensic-methodology/memory-dump-analysis/volatility-cheatsheet.html
- BelkaCTF (pslist/info): https://ogmini.github.io/2025/07/28/BelkaCTF-7-AAR-Whoami.html · HTB SideSpell (cmdline): https://www.hackthebox.com/blog/sidespell-uni-ctf-2022-forensics-writeup
- The Sleuth Kit: https://www.sleuthkit.org/sleuthkit/
