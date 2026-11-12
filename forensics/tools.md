# Forensics & Stego: Tools & Offline Prep

**Навіщо:** під час гри немає інтернету — усе має бути встановлено й перевірено **до** змагання. Нижче — що вже в Kali, що доставити, і як перевірити.
← [README](README.md) · загальна підготовка: [pre-game-checklist](../00-setup/pre-game-checklist.md)

> **Важливо:** назви пакетів/наявність **звіряй на своїй Kali** (`command -v <tool>`), версії дрейфують. Нижче — типовий стан Kali rolling + офіційні джерела. Бінарники в репо **не кладемо** (на відміну від `tools/`): усе — пакети Kali/pip/gem, встановлювані заздалегідь. Хеш/PE-валідність не доводять безпечності.

---

## Перевірка наявності (прогнати до гри)
```bash
for t in file xxd strings binwalk foremost scalpel exiftool steghide stegseek zsteg \
         sox sonic-visualiser audacity vol pdfinfo pdfimages pdftotext pdfid pdf-parser \
         qpdf mutool zbarimg stegsnow olevba multimon-ng convert ffmpeg pngcheck \
         fls icat mmls ewfmount trid; do
  command -v "$t" >/dev/null && echo "[+] $t" || echo "[-] $t ВІДСУТНІЙ"; done
java -jar ~/tools/stegsolve.jar --help 2>/dev/null && echo "[+] stegsolve" || echo "[-] stegsolve (jar)"
```

## Інвентар
| Інструмент | Призначення | Пакет / встановлення | Інтернет для запуску? | Pre-game |
|---|---|---|---|---|
| `file` `xxd` `strings` `dd` | тріаж, magic, рядки, витяг | coreutils/binutils (є завжди) | ні | — |
| `exiftool` | метадані | `apt install libimage-exiftool-perl` | ні | P1 |
| `binwalk` | карвінг/вкладені | `apt install binwalk` (є) | ні | P1 |
| `foremost` | карвінг за сигнатурами | `apt install foremost` | ні | P1 |
| `scalpel` | карвінг за конфігом | `apt install scalpel` | ні | P2 |
| `steghide` | JPEG/BMP/WAV контейнер | `apt install steghide` | ні | P1 |
| `stegseek` | брут пароля steghide | `apt install stegseek` або .deb з GitHub | ні (словник локальний) | P1 |
| `zsteg` | PNG/BMP LSB | `gem install zsteg` (або `apt install zsteg`) | ні | P1 |
| `stegsolve.jar` | GUI бітові площини/канали | **завантажити** (нема в apt) + `default-jre` | ні | P1 (доставити!) |
| `sox` | спектрограма/реверс аудіо | `apt install sox libsox-fmt-all` | ні | P1 |
| `sonic-visualiser` | GUI спектрограма | `apt install sonic-visualiser` | ні | P2 |
| `audacity` | GUI аудіо | `apt install audacity` | ні | P2 |
| `volatility3` (`vol`) | memory dump | `apt install volatility3` або `pipx install volatility3` | **так** (Linux symbol-tables) | P1 |
| `poppler-utils` | `pdfinfo/pdfimages/pdftotext` | `apt install poppler-utils` | ні | P1 |
| `pdfid` `pdf-parser` | PDF об'єкти/JS | `apt install pdfid pdf-parser` (Didier Stevens) | ні | P2 |
| `qpdf` `mutool` | декомпресія PDF-стрімів | `apt install qpdf mupdf-tools` | ні | P2 |
| `oletools` (`olevba`) | макроси office | `pipx install oletools` | ні | P2 |
| `zbar-tools` (`zbarimg`) | QR/штрихкоди | `apt install zbar-tools` | ні | P2 |
| `stegsnow` | whitespace-стего | `apt install stegsnow` | ні | P3 |
| `multimon-ng` | DTMF/FSK-тони | `apt install multimon-ng` | ні | P3 |
| `imagemagick` (`convert`) | канали/кадри/дифф | `apt install imagemagick` (є) | ні | P1 |
| `ffmpeg` (`ffprobe`) | відео→кадри/аудіо | `apt install ffmpeg` | ні | P2 |
| `pngcheck` | цілісність PNG/чанки | `apt install pngcheck` | ні | P1 |
| `sleuthkit` (`fls/icat/mmls`) | дискові образи | `apt install sleuthkit` (є) | ні | P2 |
| `ewf-tools` (`ewfmount`) | образи `.E01` | `apt install ewf-tools` | ні | P3 |
| `python-evtx` (`evtx_dump.py`) | Windows `.evtx` | `pipx install python-evtx` | ні | P3 |
| `trid` | ідентифікація типу | `apt install trid` (+ `trid-defs`) | ні | P3 |
| `stego-lsb` (`stegolsb`) | LSB images/wav | `pipx install stego-lsb` | ні | P3 |

## Доставити вручну (нема в apt)
**stegsolve** — найкорисніший GUI, якого немає в репозиторіях:
```bash
# ДО гри (офіційне джерело автора Caesum):
mkdir -p ~/tools && wget -O ~/tools/stegsolve.jar http://www.caesum.com/handbook/Stegsolve.jar
chmod +x ~/tools/stegsolve.jar ; java -jar ~/tools/stegsolve.jar   # перевірити запуск
```
> Застереження: офіційне джерело stegsolve — без HTTPS і без опублікованого checksum; версіонування відсутнє. Завантаж **заздалегідь**, перевір запуск; у репо не кладемо (немає верифіковного релізу/хешу — як і Seatbelt у Windows-частині).

## Volatility 3 — офлайн-нюанс
- **Windows**-дампи: symbol-tables вшиті → працює офлайн одразу.
- **Linux/Mac**-дампи: треба symbol-table під конкретне ядро — **тягнеться з інтернету**. Якщо очікуєш Linux-memory — підготуй/закешуй symbols **до гри** (або згенеруй з `dwarf2json` під відому версію ядра). Без цього Linux-дамп офлайн не розбереться.

## Мінімум P1 (встановити й перевірити обов'язково)
`exiftool binwalk foremost steghide stegseek zsteg sox volatility3 poppler-utils imagemagick pngcheck` + **stegsolve.jar**. Решта — за наявності часу/місця.

## Інтеграція з рештою репо
- Пошук флага у витягнутому — [05-scripts](../05-scripts/README.md) / [grep-find](../03-cheatsheets/grep-find.md).
- Виконувані ELF/PE (не дані) — [reversing](../03-cheatsheets/reversing.md).
- Крек паролів (zip/pdf/hash) — **наступна окрема хвиля** (crypto/hash cracking).
