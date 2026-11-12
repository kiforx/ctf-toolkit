# Forensics & Stego: Cheatsheet (швидко під час гри)

Дерево рішень «за типом файлу» + найважливіші команди. Деталі — за посиланнями.
← [README](README.md) · triage [01](01-file-triage.md) · meta [02](02-metadata.md) · archives [03](03-archives-carving.md) · memory [04](04-memory-disk-logs.md) · img [05](05-stego-images.md) · audio [06](06-stego-audio.md) · other [07](07-stego-other.md)

---

## Перші 4 команди з БУДЬ-ЯКИМ файлом
```bash
file X                 # справжній тип (не за розширенням!)
exiftool -a -u X       # усі метадані (+ приховані теги)
strings -n6 X | grep -iaE 'flag|ctf|pass'
binwalk X ; xxd X | tail -20    # дописане/вкладене?
```

## Дерево рішень за типом
```
file каже...
├─ PNG/BMP ........ exiftool → zsteg -a → stegsolve(bit planes) → pngcheck(height) → channels   [05]
├─ JPEG ........... exiftool → steghide info → (порожній пароль) → stegseek rockyou → extract    [05]
├─ GIF ............ convert gif frame_%03d.png → кожен кадр як зображення                          [07]
├─ WAV/MP3/OGG .... sox spectrogram → Sonic Visualiser → reverse/speed → LSB                       [06]
├─ PDF ............ pdfimages/-all → pdftotext → pdfid/pdf-parser → qpdf декомпрес                  [07]
├─ docx/xlsx/apk .. це ZIP → unzip → grep media/xml ; olevba (макроси)                              [07]
├─ ZIP/7z/RAR/TAR . 7z x / unzip ; пошкоджений → zip -FF ; пароль → очевидні→zip2john(крек:хвиля)   [03]
├─ .raw/.vmem/.mem  vol -f X windows.info/pslist/cmdline/filescan                                   [04]
├─ .dd/.img/.E01 .. fdisk -l ; mmls/fls/icat ; mount -o ro,loop ; binwalk/foremost                  [04]
├─ ELF/PE ......... це виконуваний → reversing (не forensics)                             [../03-cheatsheets/reversing.md]
└─ data/невідомо .. binwalk -Me → foremost → dd по офсету → тріаж витягнутого                       [01][03]
```

## Карвінг (витягти вкладене)
```bash
binwalk X ; binwalk -e X ; binwalk -Me X        # показати / екстракт / рекурсивно
foremost -i X -o out/                           # коли binwalk пропустив
dd if=X of=carved bs=1 skip=<офсет>             # ручний хвіст за офсетом
```

## Зображення
```bash
zsteg -a img.png                                # PNG/BMP LSB (усі методи)
zsteg -E 'b1,rgb,lsb,xy' img.png                # витягти конкретний
steghide info img.jpg ; steghide extract -sf img.jpg   # JPEG контейнер (порожній пароль = Enter)
stegseek img.jpg rockyou.txt                    # брут пароля steghide (секунди)
java -jar stegsolve.jar                         # GUI: бітові площини/канали/XOR двох img
pngcheck -vt img.png                            # CRC/розміри (обрізана height!)
convert img.png -separate ch_%d.png             # розділити канали
```

## Аудіо
```bash
sox a.wav -n spectrogram -o s.png -X 200 -Y 2050   # спектрограма (підняти роздільність)
sonic-visualiser a.wav                              # GUI спектрограма (QR/Morse/текст)
sox a.wav r.wav reverse ; sox a.wav s.wav speed 0.5 # реверс / сповільнити
```

## Метадані / текст-трюки
```bash
exiftool -a -u -g1 X ; exiftool -b -Comment X       # усі теги / дістати поле
zbarimg img.png                                      # зчитати QR/barcode
stegsnow -C file.txt                                 # whitespace-стего
base64 -d <<< 'BLOB' ; xxd -r -p <<< 'HEXBLOB'        # декодувати знайдене
```

## Memory (Volatility 3)
```bash
vol -f mem.raw windows.info                      # ОС дампу
vol -f mem.raw windows.pslist / pstree / psscan  # процеси (psscan ловить приховані)
vol -f mem.raw windows.cmdline                   # командні рядки (паролі/iex!)
vol -f mem.raw windows.filescan | grep -i flag   # → windows.dumpfiles --virtaddr <a>
vol -f mem.raw windows.netscan                   # мережа
```

## Пошук прапорця у витягнутому
```bash
grep -raoHE 'b[-_.]*e[-_.]*s[-_.]*t[-_.]*C[-_.]*T[-_.]*F[-_.]*\{[[:alnum:]_]+\}:[A-Za-z0-9]+' . 2>/dev/null | sort -u
# або: bash ../05-scripts/flags_searcher_obf.sh --key /tmp/.k --directory ./out | bash ../05-scripts/flag-encode.sh
```

## Золоті правила
- **Тип за `file`/`xxd`, не за розширенням.** Інструмент залежить від реального формату.
- **PNG→zsteg, JPEG→steghide** (не навпаки).
- **Аудіо → спектрограма першою** (не waveform).
- **Усе рекурсивно:** кожен витягнутий файл → тріаж наново (матрьошка).
- Спершу дешеве: exiftool/strings/binwalk — часто вирішують без LSB.
