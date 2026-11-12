# Forensics: File Triage (перше з будь-яким файлом)

**Навіщо:** 80% forensics-задач вирішуються на цьому кроці — визначити справжній тип, глянути рядки й метадані, помітити дописане/вкладене. Не вгадуй за розширенням.
**Коли:** отримано будь-який незнайомий файл.
← [README](README.md) · далі: [metadata](02-metadata.md) · [archives-carving](03-archives-carving.md) · [cheatsheet](cheatsheet.md)

---

## 1. Справжній тип файлу
**Що перевірити:**
```bash
file suspicious.bin                 # евристика за magic bytes
xxd suspicious.bin | head -5        # перші байти вручну (magic)
trid suspicious.bin                 # (якщо є) ймовірності типів
```
**Як інтерпретувати — часті magic bytes (перші байти):**
| Hex (початок) | ASCII | Тип |
|---|---|---|
| `FF D8 FF` | `ÿØÿ` | JPEG |
| `89 50 4E 47` | `.PNG` | PNG |
| `47 49 46 38` | `GIF8` | GIF |
| `42 4D` | `BM` | BMP |
| `25 50 44 46` | `%PDF` | PDF |
| `50 4B 03 04` | `PK..` | ZIP / docx / xlsx / jar / apk |
| `1F 8B` | | GZIP |
| `42 5A 68` | `BZh` | BZIP2 |
| `37 7A BC AF` | `7z..` | 7-Zip |
| `52 61 72 21` | `Rar!` | RAR |
| `7F 45 4C 46` | `.ELF` | ELF (→ [reversing](../03-cheatsheets/reversing.md)) |
| `4D 5A` | `MZ` | PE/EXE (→ [reversing](../03-cheatsheets/reversing.md)) |
| `49 49 2A 00`/`4D 4D` | `II*`/`MM` | TIFF / RAW |
| `52 49 46 46` | `RIFF` | WAV / AVI (далі 4 байти: `WAVE`/`AVI `) |
| `4F 67 67 53` | `OggS` | OGG |
| `66 4C 61 43` | `fLaC` | FLAC |

**Що далі:**
- `file` каже «data» або тип ≠ розширення → **невідповідність** (див. §2).
- PK → це zip-контейнер → [archives](03-archives-carving.md) (навіть docx/apk — розпакувати як zip).
- Зображення/аудіо/PDF → відповідний stego-файл.
**Обмеження:** `file` дивиться лише перші байти — **дописане в кінець** не побачить (див. §3). Підроблений/обрізаний header → `file` бреше; звіряй `xxd` вручну.

## 2. Невідповідність розширення ↔ формату
**Коли:** `photo.jpg`, а `file` каже PNG (або навпаки); частий CTF-трюк.
```bash
file photo.jpg                      # "PNG image data" → насправді PNG
# виправити розширення й працювати як з реальним типом:
mv photo.jpg photo.png
```
**Інтерпретація:** інструменти (zsteg/steghide) прив'язані до **реального** формату — на хибному розширенні впадуть. Спершу визнач тип, потім обирай інструмент.

## 3. Дописані / вкладені дані (найчастіший трюк)
**Коли:** розмір файлу більший за очікуваний; «картинка» важить забагато; після валідного файлу є ще байти.
**Що перевірити:**
```bash
binwalk suspicious.png              # сигнатури вкладених файлів + офсети
xxd suspicious.png | tail -20       # що в кінці? текст/PK/новий magic після IEND/EOF?
strings -n6 suspicious.png | tail   # хвостові рядки — часто флаг/пароль/наступний крок
```
**Як інтерпретувати:**
- PNG закінчується на `IEND` (`49 45 4E 44 AE 42 60 82`), JPEG — на `FF D9`. **Байти ПІСЛЯ** цього — дописана корисна нагрузка.
- `binwalk` показав напр. `Zip archive` на офсеті 0x4A12 → всередині є zip.
**Що далі — витягти (3 способи):**
```bash
binwalk -e suspicious.png           # авто-екстракт у _suspicious.png.extracted/
binwalk --dd='.*' suspicious.png    # витягти ВСІ знайдені (не лише відомі)
# вручну по офсету (найнадійніше для «хвоста»):
dd if=suspicious.png of=hidden.zip bs=1 skip=18962   # skip = офсет з binwalk/xxd
```
→ для кожного витягнутого — знову [§1 тріаж]; архіви → [archives-carving](03-archives-carving.md).
**Обмеження:** `binwalk` дає **хибні спрацювання** (випадкові байти схожі на сигнатури) — звіряй офсет і витягуй `dd`-ом, якщо авто-екстракт дав сміття. (Стара вразливість carving: binwalk ≤2.3.3 CVE-2022-4510 — для гри некритично, але не карвіть вороже на проді.)

## 4. Рядки глибше
```bash
strings -n6 file | grep -iE 'flag|ctf|pass|key|http|BEGIN'
strings -e l file                   # 16-бітні little-endian (UTF-16) — Windows-рядки
strings -e b file                   # big-endian
# шумо-стійкий флаг-пошук прямо у файлі:
strings -n6 file | grep -aoE 'b[-_.]*e[-_.]*s[-_.]*t[-_.]*C[-_.]*T[-_.]*F[-_.]*\{[[:alnum:]_]+\}:[A-Za-z0-9]+'
```
> Різні кодування: якщо `strings` порожній, а файл текстовий — спробуй `iconv`/подивись `xxd` (може бути base64/hex-блоб → `base64 -d` / `xxd -r -p`).

## 5. Цілісність / хеші / порівняння
```bash
sha256sum file ; md5sum file        # ідентифікувати відомий файл / порівняти версії
cmp -l orig.png mod.png             # побайтова різниця двох файлів (знайти змінені байти)
xxd a.png > a.hex; xxd b.png > b.hex; diff a.hex b.hex | head   # візуальний дифф
```
**Коли корисно:** дано «оригінал + змінений» → `cmp`/`diff` показує, де саме сховано. Відомий хеш → перевірити, чи файл стандартний (напр. дефолтне зображення).

## Типові пастки
- Довіритись розширенню замість `file` → не той інструмент → «нічого не знаходить».
- `file` сказав тип і зупинитись — не глянути `xxd ... | tail` на дописане.
- Витягати лише `binwalk -e` і не чистити хибні спрацювання → купа сміттєвих файлів.
- Забути прогнати `strings`/`binwalk` рекурсивно на КОЖЕН витягнутий файл.

## Практичний приклад
GlacierCTF: PDF-челендж → `binwalk file.pdf` знайшов вкладений PNG → витягти → прапорець на зображенні ([джерело](https://tg-pentestportfolio.pages.dev/writeups/ctfs/glacierctf2025.html)). Класична матрьошка «контейнер → вкладений файл → флаг».

## Джерела
- HackTricks — File/Data carving & recovery: https://book.hacktricks.wiki/en/generic-methodologies-and-resources/basic-forensic-methodology/partitions-file-systems-carving/file-data-carving-recovery-tools.html
- binwalk у CTF (хибні спрацювання): https://dev.to/rudycandy/binwalk-in-ctf-spot-false-positives-fast-7fp
- file carving cheatsheet: https://xbpt.gitlab.io/ctf/file-carving-cheatsheet.html
- Gary Kessler — File Signatures (magic bytes): https://www.garykessler.net/library/file_sigs.html
