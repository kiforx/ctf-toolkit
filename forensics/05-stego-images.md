# Forensics: Image Steganography

**Навіщо:** найчастіша stego-категорія. Дані ховають у LSB, каналах, бітових площинах, кінці файлу або парольному контейнері. Інструмент залежить від **формату**.
**Коли:** PNG / JPEG / BMP / GIF.
← [README](README.md) · [file-triage](01-file-triage.md) · [metadata](02-metadata.md) · [tools](tools.md)

> **Головне правило вибору інструмента за форматом:**
> - **PNG / BMP** → `zsteg` (LSB), `stegsolve` (бітові площини). `steghide` їх **не** підтримує.
> - **JPEG / BMP / WAV** → `steghide` (парольний контейнер), `stegseek` (брут пароля).
> - будь-що → `exiftool`, `binwalk`, `strings`.

---

## Workflow (порядок, що покриває ~90%)
```
1. file + exiftool + strings           → тип, метадані, явні рядки   ([triage],[metadata])
2. binwalk img ; xxd img | tail        → дописане/вкладене?          ([triage §3])
3. PNG/BMP → zsteg -a                   → LSB у каналах/площинах
   JPEG/BMP/WAV → steghide info → steghide extract / stegseek
4. stegsolve (GUI)                      → перегляд бітових площин/каналів очима
5. не вийшло → канали/прозорість/CRC    → глибший ручний аналіз
```

## 1. Швидкі перевірки (завжди першими)
```bash
file img ; exiftool -a -u img                        # тип + метадані ([metadata])
strings -n6 img | grep -iE 'flag|ctf|pass|xoxo'
binwalk img                                           # вкладене ([triage §3])
# шумо-стійкий флаг прямо в байтах:
strings -n6 img | grep -aoE 'b[-_.]*e[-_.]*s[-_.]*t[-_.]*C[-_.]*T[-_.]*F[-_.]*\{[[:alnum:]_]+\}:[A-Za-z0-9]+'
```

## 2. PNG / BMP → zsteg (LSB)
**Коли:** PNG або BMP (zsteg працює саме з ними).
```bash
zsteg -a image.png                  # перебрати ВСІ методи (канали/порядок бітів/напрямок)
zsteg image.png                     # базовий набір (швидше)
zsteg -E 'b1,rgb,lsb,xy' image.png  # витягти конкретний канал (з виводу -a) у stdout/файл
```
**Як інтерпретувати:** `zsteg -a` друкує знахідки на кшталт `b1,rgb,lsb,xy .. text: "flag{...}"`. Рядок `text:`/`file:` з осмисленим вмістом → це воно; `-E` з тим самим дескриптором витягує payload.
**Що далі:** витягнутий `file:` → [тріаж](01-file-triage.md) (може бути вкладений zip/зображення).
**Обмеження:** zsteg — лише PNG/BMP; на JPEG не працює (там LSB руйнується стисненням). Багато шуму на `-a` — шукай `text:`/`file:` з реальним вмістом, не випадкові байти.

## 3. JPEG / BMP / WAV → steghide + stegseek
**Коли:** JPEG (найчастіше), BMP, WAV, AU.
```bash
steghide info image.jpg             # чи є вкладене + чи потрібен пароль
steghide extract -sf image.jpg      # витягти (спитає пароль; порожній = Enter)
steghide extract -sf image.jpg -p 'password'   # з паролем
```
**Брут пароля (stegseek — секунди проти rockyou):**
```bash
stegseek image.jpg /usr/share/wordlists/rockyou.txt    # знайде пароль + ОДРАЗУ витягне вкладене
stegseek --crack image.jpg rockyou.txt
```
**Як інтерпретувати:** `steghide info` каже «embedded file "secret.txt"» → є payload; порожній пароль часто працює в CTF. stegseek виводить `Found passphrase: "..."` і пише `image.jpg.out`.
**Порядок:** спершу **порожній пароль** (Enter) і очевидні (назва челенджу, слова з метаданих) → лише потім stegseek зі словником.
**Обмеження:** steghide **не підтримує PNG** (`stegseek`/`steghide` на PNG → unsupported-file-type; формати: jpg/bmp/wav/au) — для PNG йди в zsteg. stegseek значно швидший за stegcracker (той години, stegseek секунди).
**Приклад:** THM *c4ptur3 th3 fl4g* і дев-гайди: `steghide info` → порожній пароль / stegseek rockyou → `extract` ([dev.to steghide CTF](https://dev.to/rudycandy/steghide-in-ctf-extract-flags-g8j), [c4ptur3](https://davidtkeane.github.io/posts/ctf-steganography-c4ptur3-th3-fl4g)).

## 4. Stegsolve — бітові площини й канали очима (GUI)
**Коли:** zsteg/steghide не дали, або задача «видно оком» (прихований текст/QR/обличчя в площині).
```bash
java -jar stegsolve.jar             # відкрити зображення → стрілками гортати площини/канали
```
**Що робити в Stegsolve:**
- **Analyse → Bit Planes / стрілки:** гортати Red/Green/Blue 0..7 — флаг часто в одній площині (часто **bit 0** або **bit 7**).
- **Analyse → Data Extract:** вибрати канали/біти/порядок → Preview → Save bin (той самий LSB, але вручну).
- **Analyse → Image Combine / XOR:** якщо дано два зображення (різниця/XOR відкриває сховане).
- **Color inversions / channels:** інвертувати/розділити канали — прихований шар стає видимим.
**Як інтерпретувати:** у «шумній» площині раптом читабельний текст/QR/контур → це шар з даними. QR → зчитати (`zbarimg`, [stego-other](07-stego-other.md)).
**Приклад:** DawgCTF — приховане обличчя у **вищих бітових площинах (біля bit 7)** після поділу каналів і bit-plane аналізу кожного RGB-каналу ([DawgCTF: hiding in plain sight](https://ret2future.ase.ro/docs/ctfs/dawgctf2026/forensics/hiding-in-plain-sight/)).

## 5. Ручний / глибший аналіз
```bash
# цілісність PNG + приховані чанки
pngcheck -vt image.png              # биті CRC / неправильні розміри / tEXt-чанки
# прозорість (альфа-канал інколи ховає): відкрити й прибрати альфу у stegsolve/GIMP
# розділити канали (ImageMagick):
convert image.png -channel R -separate r.png   # кожен канал окремо → дивитись
convert image.png -separate ch_%d.png
# різниця двох зображень:
compare orig.png mod.png diff.png ; convert orig.png mod.png -compose difference -composite d.png
# альтернатива всьому одразу (якщо є): aperisolve (онлайн; офлайн — набір вище)
```
**Інтерпретація:** `pngcheck` каже «incorrect CRC»/«invalid IHDR dimensions» → зображення **обрізане висотою** (ховають, зменшивши height у IHDR) → виправити height-байти в `xxd` → відкриється повна картинка з флагом.
**Обмеження:** правка IHDR вимагає перерахунку CRC (або ігнорувати попередження переглядача) — pngcheck підкаже правильні значення.

## Дерево рішень (швидко)
```
PNG/BMP ─ zsteg -a ─ порожньо ─ stegsolve (bit planes) ─ порожньо ─ pngcheck (height trick) / channels
JPEG   ─ steghide info ─ пароль? ─ порожній → stegseek rockyou ─ extract
будь-що ─ exiftool / binwalk / strings  (ЗАВЖДИ паралельно)
GIF    ─ кадри → [stego-other]
```

## Типові пастки
- zsteg на JPEG або steghide на PNG → «не підтримується»; спершу `file` → правильний інструмент.
- Не спробувати **порожній пароль** у steghide перед брутом.
- Зупинитись на zsteg без stegsolve (деякі речі видно лише оком у площині).
- Пропустити `pngcheck` (обрізана висота — дуже частий трюк).
- Не прогнати exiftool/binwalk/strings — вони часто вирішують без LSB.

## Джерела
- HackTricks — Stego tricks (повний набір): https://book.hacktricks.wiki/en/generic-methodologies-and-resources/stego-tricks.html
- zsteg: https://github.com/zed-0xff/zsteg · steghide: https://steghide.sourceforge.net/ · stegseek: https://github.com/RickdeJager/stegseek
- Stego-чеклист (fareedfauzi): https://fareedfauzi.gitbook.io/ctf-checklist-for-beginner/steganography
- Finding flags in CTF image challenges: https://codingtarik.github.io/posts/2025-03-14-uncovering-hidden-gems-a-guide-to-finding-flags-in-ctf-image-challenges
