# Forensics: Metadata (ExifTool)

**Навіщо:** прапорець або підказку часто кладуть просто в метадані — поле Comment, Artist, GPS, XMP, кастомний тег. Переглядачі зображень їх не показують.
**Коли:** зображення, PDF, документ, медіа, будь-який файл з метаданими.
← [README](README.md) · [file-triage](01-file-triage.md) · [stego-images](05-stego-images.md) · [stego-other](07-stego-other.md)

> Зразки прапорців у цьому форматі: `3x1f_m3tadata`, `pdf_m3tadata` (див. [flag-hunting](../01-roadmaps/flag-hunting.md)) — метадані тут очікувані.

---

## 1. Повний дамп метаданих
**Що перевірити:**
```bash
exiftool file.jpg                   # усі теги
exiftool -a -u -g1 file.jpg         # -a дублікати, -u невідомі/приховані теги, -g1 за групами
exiftool -b -Comment file.jpg       # дістати конкретне поле «сире» (напр. бінарні дані коментаря)
```
**Як інтерпретувати — де дивитись:**
| Поле | Що ховають |
|---|---|
| `Comment` / `UserComment` | прямий текст/флаг/base64 |
| `Artist` / `Author` / `Copyright` | підказка/флаг |
| `Software` | яким інструментом зроблено (напр. `steghide`, GIMP — натяк на наступний крок) |
| `GPS*` | координати → карта/геокод → підказка |
| `XMP` / `IPTC` | розширені поля, часто кастомні теги з даними |
| `DateTime*` | аномальні дати → підказка/впорядкування |
| `Document*`/`Producer` (PDF) | автор/інструмент PDF |

**Що далі:**
- Текст виглядає як base64/hex → `echo '...' | base64 -d` / `xxd -r -p`.
- `Software: steghide`/незвичний інструмент → піти в [stego-images](05-stego-images.md) саме з цим інструментом.
- GPS → ввести координати, часто вказує слово/місце-підказку.
**Обмеження:** EXIF повноцінно живе в JPEG/TIFF; PNG має лише текстові чанки (`tEXt`/`zTXt`/`iTXt` — exiftool їх теж читає); «порожні» метадані не означають чисто — йди в LSB/карвінг.

## 2. Пошук по всіх полях одразу
```bash
exiftool file.* | grep -iE 'flag|ctf|pass|secret|key|base64'
exiftool -a -u -g1 file.png | grep -iaE 'best|ctf|\{'
# пакетно по теці:
exiftool -r -Comment -UserComment -XMP:all ./images/
```

## 3. Запис/порівняння (рідше, але корисно)
```bash
exiftool -Comment file.jpg          # лише коментар
# порівняти метадані двох схожих файлів (оригінал vs підмінений):
diff <(exiftool orig.jpg) <(exiftool mod.jpg)
```
**Коли:** дано пару файлів → різниця в метаданих = сховане.

## 4. PNG-специфічні текстові чанки (вручну, якщо треба)
```bash
# exiftool зазвичай достатньо, але вручну видно й «дивні» чанки:
pngcheck -t -7 file.png             # теги tEXt/zTXt + цілісність (див. stego-images)
```

## Типові пастки
- Дивитись метадані у GUI-переглядачі (він ховає кастомні теги) замість `exiftool -a -u`.
- Пропустити `-b` для бінарного поля (напр. мініатюра-прев'ю може містити ІНШЕ зображення: `exiftool -b -ThumbnailImage f.jpg > thumb.jpg`).
- Вважати, що «нема EXIF» = чисто; метадані — лише один з шарів.

## Практичний приклад
Стего-челенджі регулярно починаються з exiftool: кастомні поля не видно у звичайному переглядачі, їх треба явно запитати; типовий перший крок image-челенджу — exiftool, далі LSB ([codingtarik: finding flags in CTF image challenges](https://codingtarik.github.io/posts/2025-03-14-uncovering-hidden-gems-a-guide-to-finding-flags-in-ctf-image-challenges), [c4ptur3 th3 fl4g, THM](https://davidtkeane.github.io/posts/ctf-steganography-c4ptur3-th3-fl4g)).

## Джерела
- ExifTool офіц. документація: https://exiftool.org/
- HackTricks — Image acquisition & stego: https://book.hacktricks.wiki/en/generic-methodologies-and-resources/stego-tricks.html
- Thumbnail-prev'ю трюк: https://exiftool.org/ (ThumbnailImage тег)
