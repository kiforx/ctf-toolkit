# Forensics: Other Formats (PDF / GIF / Video / Docs / QR)

**Навіщо:** решта контейнерів, де ховають дані: PDF (шари/об'єкти/вкладення), GIF (кадри), відео (кадри/доріжки), office-doc (zip-нутрощі/макроси), QR/штрихкоди.
**Коли:** файл не зображення/аудіо/архів у чистому вигляді.
← [README](README.md) · [file-triage](01-file-triage.md) · [archives-carving](03-archives-carving.md)

---

## 1. PDF
**Коли:** `%PDF` на початку.
```bash
# поверхня
exiftool doc.pdf ; strings doc.pdf | grep -iE 'flag|ctf'
pdfinfo doc.pdf                      # метадані/структура
# витягти вкладені зображення (часто флаг у них):
pdfimages -all doc.pdf out/          # → out-000.png ... → далі stego-images
# текст (прихований білим/крихітним шрифтом — виділиться тут):
pdftotext doc.pdf - | less
# об'єкти/потоки/JS (pdf-parser, pdfid з Kali):
pdfid.py doc.pdf                     # підозрілі елементи (/JavaScript /OpenAction /EmbeddedFile)
pdf-parser.py --search flag doc.pdf
pdf-parser.py -o <obj> -f -d out.bin doc.pdf   # витягти/декомпресувати об'єкт
# декомпресія стрімів (прихований текст у стиснених потоках):
qpdf --qdf --object-streams=disable doc.pdf uncompressed.pdf ; strings uncompressed.pdf | grep -i flag
mutool clean -d doc.pdf clean.pdf
```
**Інтерпретація:** `pdfid` з `/EmbeddedFile` → є вкладення (`pdf-parser -o`); текст, «невидимий» у переглядачі (білий на білому) → `pdftotext` його покаже; флаг у картинці → `pdfimages` + [stego-images](05-stego-images.md).
**Далі (захищений PDF):** `pdf2john doc.pdf > hash.txt` → крек — **окрема хвиля** (crypto/hash).
**Приклад:** image/PDF-челенджі — `pdfimages` дістати картинки → stego; `qpdf`/`mutool` декомпресувати стріми ([codingtarik image challenges](https://codingtarik.github.io/posts/2025-03-14-uncovering-hidden-gems-a-guide-to-finding-flags-in-ctf-image-challenges)).

## 2. GIF (кадри)
**Коли:** анімований GIF — дані розкидані по кадрах (один кадр = QR/текст).
```bash
# розкласти на кадри:
convert anim.gif frame_%03d.png      # ImageMagick → кожен кадр окремо
# або:
ffmpeg -i anim.gif frame_%03d.png
# подивитись усі кадри (флаг часто в одному):
identify anim.gif                    # кількість/затримки кадрів
```
**Інтерпретація:** переглянь кадри по одному — текст/QR часто лише на одному кадрі або «складається» з кількох. Далі кожен кадр → [stego-images](05-stego-images.md).

## 3. Video
**Коли:** mp4/avi/mkv.
```bash
ffprobe video.mp4                    # потоки/доріжки/метадані (прихована субтитр-доріжка?)
ffmpeg -i video.mp4 frames/%05d.png  # покадрово → шукати кадр з флагом
ffmpeg -i video.mp4 audio.wav        # витягти аудіо → [stego-audio] (спектрограма!)
exiftool video.mp4 ; binwalk video.mp4
mkvextract / mkvinfo file.mkv        # вкладення/доріжки в Matroska
```
**Інтерпретація:** відео = контейнер картинок + аудіо → розклади на кадри (image-stego) і витягни аудіо (audio-stego спектрограма). Додаткові доріжки/вкладення (`ffprobe`/`mkvinfo`) — часте місце схову.

## 4. Office-документи (docx/xlsx/pptx)
**Коли:** `PK` magic (це zip!).
```bash
unzip doc.docx -d docx/              # розпакувати як архів
grep -riE 'flag|ctf|http' docx/      # у word/document.xml, media/, тощо
ls docx/word/media/                  # вкладені зображення → stego-images
# макроси (олдскульні .doc/.xlsm):
olevba document.xlsm                 # VBA-макроси (підказки/payload)
oledump.py document.doc              # OLE-стріми
```
**Інтерпретація:** текст у `document.xml`, картинки в `word/media/`, макрос у VBA — три типові схованки. `olevba` витягує макрос (там буває декодер/флаг).

## 5. QR / штрихкоди
```bash
zbarimg image.png                    # зчитати QR / barcode → текст/URL/флаг
# частковий/пошкоджений QR → відновити в GIMP (контраст/вирівняти) → zbarimg
```
**Коли:** у файлі/спектрограмі/кадрі проступив QR → `zbarimg` зчитує. Пошкоджений → підправити контраст/кути й повторити.

## 6. Текстові / «порожні» трюки (швидко)
- **Zero-width / Unicode-стего:** невидимі символи між буквами → `xxd`/спец-декодер (zero-width chars `U+200B` тощо).
- **Whitespace-стего** (SNOW): пробіли/таби в кінці рядків → `stegsnow -C file.txt`.
- **Base64/hex-блоб** у тексті → `base64 -d` / `xxd -r -p`.

## Типові пастки
- Не помітити, що docx/pptx — zip (розпакувати!).
- Дивитись відео очима замість покадрового розкладання + витягу аудіо.
- Пропустити вкладені зображення PDF (`pdfimages`) і стиснені стріми (`qpdf`).
- Забути зчитати QR зі спектрограми/кадру (`zbarimg`).

## Джерела
- HackTricks — Stego tricks (PDF/docs/QR): https://book.hacktricks.wiki/en/generic-methodologies-and-resources/stego-tricks.html
- Didier Stevens — pdf-parser/pdfid: https://blog.didierstevens.com/programs/pdf-tools/
- oletools (olevba/oledump): https://github.com/decalage2/oletools
- zbar: https://github.com/mchehab/zbar
