# Forensics & Steganography — технічна база (CTF)

Дослідження незнайомих файлів і пошук прихованих даних: від визначення типу до витягнутого прапорця. Паралельний трек до Linux/Windows-частин — відкривається, коли в руках **файл** (знайдений на цілі, доданий до завдання, викопаний з архіву/дампу), а не хост чи веб.

← назад: [MASTER-ROADMAP](../01-roadmaps/MASTER-ROADMAP.md) · суміжне: [reversing](../03-cheatsheets/reversing.md) (виконувані ELF/PE) · [grep/find](../03-cheatsheets/grep-find.md) · [flag-hunting](../01-roadmaps/flag-hunting.md)

> **Статус матеріалів.** Команди — стандартний синтаксис інструментів Kali, звірений з офіційною документацією, HackTricks і реальними CTF-writeup'ами (джерела в кінці кожного файлу). Проти конкретного челенджу в цьому середовищі **не прогонялись** — підставляй свій файл. Де техніка має конкретне лабораторне підтвердження — позначено.

---

## Майстер-workflow (золоте правило)
```
Отримав файл
  │
  1. ТИП:        file X ; xxd X | head ; trid/magic bytes  → що це НАСПРАВДІ (не за розширенням!)
  │
  2. ПОВЕРХНЯ:   strings -n6 X | grep -i flag ; exiftool X   → флаг/підказка часто одразу тут
  │
  3. СТРУКТУРА:  binwalk X ; xxd X | tail ; розмір vs очікуваний  → щось ДОПИсане/ВКЛАДЕНЕ?
  │
  4. ВИТЯГ:      binwalk -e / foremost ; unzip ; dd  → дістати вкладені файли → назад до кроку 1 для КОЖНОГО
  │
  5. ЗА ТИПОМ:   зображення→stego-images · аудіо→stego-audio · дамп→memory · pdf/doc→stego-other
  │
  6. АНАЛІЗ:     LSB/спектрограма/метадані/карвінг → витягнуті дані → grep флаг
```
**Принцип:** на кожному кроці питай «тип файлу змінився? з'явився новий вкладений файл? → почни тріаж наново для нього». Більшість CTF-forensics — це матрьошка (файл у файлі у файлі).

---

## Файли напряму
| Файл | Для чого | Коли |
|---|---|---|
| [01-file-triage](01-file-triage.md) | `file`/`xxd`/`strings`, magic bytes, невідповідність розширення, дописані/вкладені дані, хеші, полігліоти | **завжди перше** з будь-яким файлом |
| [02-metadata](02-metadata.md) | ExifTool: метадані зображень/PDF/doc, підозрілі поля | зображення/документ/медіа |
| [03-archives-carving](03-archives-carving.md) | ZIP/TAR/GZIP, вкладені/пошкоджені/захищені архіви; binwalk/foremost/scalpel | «всередині щось є» / контейнер |
| [04-memory-disk-logs](04-memory-disk-logs.md) | Volatility 3 (memory dump), дискові образи, артефакти логів | `.raw`/`.vmem`/`.mem`/`.dd`/`.E01` |
| [05-stego-images](05-stego-images.md) | LSB, канали RGB, бітові площини, zsteg/stegsolve/steghide/stegseek | PNG/JPEG/BMP/GIF |
| [06-stego-audio](06-stego-audio.md) | спектрограма (sox/Sonic Visualiser/Audacity), Morse, reversed, LSB | WAV/MP3/OGG/FLAC |
| [07-stego-other](07-stego-other.md) | PDF, GIF-кадри, відео, office-doc, QR/штрихкоди | решта форматів |
| [cheatsheet](cheatsheet.md) | дерево рішень «за типом файлу» + швидкі команди | під час гри |
| [tools](tools.md) | інвентар інструментів: що в Kali, що доставити, офлайн-підготовка | **до гри** |

**Порядок читання до гри:** 01 → 02 → 03 → 05 → 06 → 07 → 04. Під час гри: [cheatsheet](cheatsheet.md) як індекс.

---

## Пошук прапорця у витягнутому
Після будь-якого витягу — той самий шумо-стійкий пошук, що і скрізь у репо:
```bash
# у файлі/теці витягнутого:
grep -raoHE 'b[-_.]*e[-_.]*s[-_.]*t[-_.]*C[-_.]*T[-_.]*F[-_.]*\{[[:alnum:]_]+\}:[A-Za-z0-9]+' . 2>/dev/null | sort -u
# або скрипт: bash ../05-scripts/flags_searcher_obf.sh --key /tmp/.k --directory ./out | bash ../05-scripts/flag-encode.sh
```
Деталі/нормалізація — [flag-hunting](../01-roadmaps/flag-hunting.md), [grep/find](../03-cheatsheets/grep-find.md), [05-scripts](../05-scripts/README.md).

## Межі напряму
- **Крек хешів / криптографія** (pdf2john, zip2john, RSA, класичні шифри) — **наступна окрема хвиля**, тут лише вказівники «де це крекати».
- **Виконувані ELF/PE** (не дані) → [reversing](../03-cheatsheets/reversing.md), не сюди.
- Повний DFIR-курс не ставимо — лише типові CTF-задачі.

## Джерела (напрям загалом)
- HackTricks — Basic Forensic Methodology: https://book.hacktricks.wiki/en/generic-methodologies-and-resources/basic-forensic-methodology/index.html
- HackTricks — Stego tricks: https://book.hacktricks.wiki/en/generic-methodologies-and-resources/stego-tricks.html
- CTF Field Guide / aperi'solve, стего-чеклисти (у відповідних файлах).
