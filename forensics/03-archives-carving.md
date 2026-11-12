# Forensics: Archives & File Carving

**Навіщо:** контейнери (zip/tar/gz) і вкладені файли — основа forensics-матрьошок. Витягнути все, обійти пошкодження, знайти захищені архіви.
**Коли:** `file` каже архів; `binwalk` знайшов вкладене; розмір більший за очікуваний.
← [README](README.md) · [file-triage](01-file-triage.md) · крек паролів архівів — **окрема хвиля** (тут лише вказівник)

---

## 1. Розпакування за типом
```bash
unzip archive.zip -d out/                      # ZIP (і docx/xlsx/apk/jar — теж zip!)
tar xvf archive.tar                            # TAR
tar xzvf a.tar.gz   ;  tar xjvf a.tar.bz2      # gzip / bzip2 tar
gunzip file.gz      ;  bunzip2 file.bz2        # одиночні
7z x archive.7z     ;  7z x anything           # 7z (і як універсальний екстрактор майже всього)
unrar x archive.rar                            # RAR
7z l archive.zip                               # лише список вмісту (не розпаковуючи)
```
**Інтерпретація:** docx/xlsx/pptx/apk/jar — це **zip**; `unzip` їх → усередині XML/ресурси, де часто ховають дані ([stego-other](07-stego-other.md)).
**Далі:** кожен розпакований файл → [тріаж](01-file-triage.md) наново.

## 2. Вкладені архіви (матрьошка)
**Коли:** архів в архіві в архіві (CTF-класика «розпакуй N разів»).
```bash
# рекурсивно розпакувати поки є що:
while file * 2>/dev/null | grep -q 'archive\|compressed'; do
  for f in *; do 7z x -y "$f" 2>/dev/null && rm "$f"; done
done
# 7z універсальний — тягне gzip/zip/tar/bzip2/xz по черзі
```
**Обмеження:** можуть чергуватись формати (zip→gz→tar→bz2) — `7z x` зазвичай впорається з усіма; якщо ні — дивись `file` і бери відповідний екстрактор.

## 3. Пошкоджені архіви
**Коли:** `unzip` каже «cannot find central directory» / «unexpected end» — хедер/структуру навмисно зіпсовано.
```bash
# ZIP: спробувати відновити
zip -FF broken.zip --out fixed.zip             # reconstruct central directory
jar xvf broken.zip                             # jar-екстрактор толерантніший за unzip
7z x broken.zip                                # 7z інколи бере те, що unzip не бере
# GZIP обрізаний — витягти що є:
gunzip -c broken.gz > out 2>/dev/null ; cat broken.gz | zcat 2>/dev/null > out
# подивитись/полагодити сигнатуру вручну (ZIP local header = 50 4B 03 04):
xxd broken.zip | head                          # перші байти — чи PK?
```
**Інтерпретація:** часто псують лише magic/footer — виправлення байта в `xxd`/hexedit (напр. `PK\x03\x04` на початку) робить архів валідним. PNG/JPEG «ламають» так само ([stego-images](05-stego-images.md) — фікс CRC/розмірів).
**Далі:** відновив → розпакувати → тріаж.

## 4. Захищені паролем архіви
**Коли:** `unzip` просить пароль.
```bash
unzip -P 'password' archive.zip                # якщо пароль відомий/вгадано (спершу порожній, 'password', назва челенджу)
7z x archive.7z -p'password'
```
**Крек — вказівник (окрема хвиля «Crypto/Hash Cracking»):**
```bash
# згенерувати хеш для john (НЕ крекати словником тут — це наступна хвиля):
zip2john archive.zip > hash.txt
rar2john archive.rar > hash.txt
7z2john.pl archive.7z > hash.txt
# → john hash.txt --wordlist=rockyou.txt   (деталі — у майбутньому crypto-розділі)
```
**Обмеження:** спершу спробуй **очевидні паролі** (порожній, `password`, назва завдання, знайдене в метаданих/strings) — крек словником лиши як останнє.

## 5. File carving — витягти файли з контейнера/дампу
**Коли:** один великий файл (образ диску, пам'ять, «склеєний» файл) містить багато вкладених; або `binwalk` показав сигнатури.

### binwalk (перший вибір)
```bash
binwalk image.bin                              # показати знайдені сигнатури + офсети
binwalk -e image.bin                           # авто-екстракт відомих → _image.bin.extracted/
binwalk -Me image.bin                          # рекурсивний екстракт (матрьошка автоматично)
binwalk --dd='.*' image.bin                    # витягти ВСЕ знайдене (не лише відоме)
```
**Інтерпретація:** `binwalk` дає офсет+тип; `-Me` сам рекурсивно розпакує вкладене. Хибні спрацювання → звіряй офсет.

### foremost (коли binwalk щось пропустив)
```bash
foremost -i image.bin -o out/                  # карвінг за header/footer → out/<тип>/
foremost -t png,jpg,zip -i image.bin -o out/   # обмежити типи (точніше)
```
**Інтерпретація:** `foremost` сортує по підтеках типів (`out/png/`, `out/zip/`...) + `audit.txt` зі знайденим. Часто бере те, що binwalk не витяг.

### scalpel (тонкий карвінг за конфігом)
```bash
# розкоментувати потрібні типи у /etc/scalpel/scalpel.conf, далі:
scalpel -o out/ image.bin
```
**Коли:** треба нестандартний/точний патерн header-footer, якого нема у foremost.

**Практичний приклад (binwalk ↔ foremost):** bitsCTF — `binwalk` побачив JPEG, але **не витяг WAV**; `foremost` знайшов і витяг усі три файли ([bitsCTF: Finders Keepers](https://emree-1.github.io/posts/bitskrieg-finders-keepers)). Правило: binwalk не впорався → foremost.

## 6. Дописаний хвіст вручну (dd)
```bash
# точний витяг за офсетом (з binwalk/xxd):
dd if=image.bin of=carved.zip bs=1 skip=<офсет> 2>/dev/null
# «усе після PNG IEND»: знайти офсет IEND і відрізати:
grep -aboP '\x49\x45\x4e\x44\xae\x42\x60\x82' image.png   # офсет кінця PNG
```

## Типові пастки
- Не помітити, що docx/apk/jar — це zip (розпакувати як zip!).
- Крекати пароль архіву, не спробувавши порожній/очевидний.
- Зупинитись на `binwalk -e` і не перевірити `foremost`, коли тип не витягся.
- Не прогнати тріаж рекурсивно на кожен витягнутий файл.

## Джерела
- HackTricks — carving & recovery tools: https://book.hacktricks.wiki/en/generic-methodologies-and-resources/basic-forensic-methodology/partitions-file-systems-carving/file-data-carving-recovery-tools.html
- binwalk vs foremost (bitsCTF): https://emree-1.github.io/posts/bitskrieg-finders-keepers
- foremost (BSidesNYC matrioshka): https://blog.osiris.cyber.nyu.edu/bsidesnyc-ctfd-writeup-secret-map-scratching-the-surface-2
- binwalk офіц.: https://github.com/ReFirmLabs/binwalk
