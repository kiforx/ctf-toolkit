# Forensics: Audio Steganography

**Навіщо:** в аудіо прапорець найчастіше «намальований» у **спектрограмі** (текст/QR/Morse), рідше — LSB семплів або реверс. Починай завжди зі спектрограми.
**Коли:** WAV / MP3 / OGG / FLAC, або «дивний» звук/шум/пищання.
← [README](README.md) · [file-triage](01-file-triage.md) · [tools](tools.md)

> **Золоте правило:** waveform зазвичай нічого не дає — дані ховають у **спектрограмі**. Спершу подивись спектрограму, лише потім копай у семпли.

---

## Workflow
```
1. file + exiftool + strings + binwalk     → тип/метадані/вкладене ([triage])
2. СПЕКТРОГРАМА (sox або Sonic Visualiser)  → текст/QR/Morse/візерунок?   ← 90% задач
3. не видно → реверс / швидкість / канали   → прихований голос/тон
4. все ще ні → LSB семплів (WavSteg) / DTMF  → дані в бітах/тонах
```

## 1. Поверхневі перевірки
```bash
file audio.wav ; exiftool audio.wav          # тип/метадані ([metadata])
strings -n6 audio.wav | grep -iE 'flag|ctf'
binwalk audio.wav                             # вкладене ([triage §3])
```

## 2. Спектрограма (головне) ⭐
### sox (CLI, без GUI)
```bash
sox audio.wav -n spectrogram -o spec.png                       # базова
sox audio.wav -n spectrogram -o spec.png -X 200 -Y 2050        # більша роздільність (читабельніше)
sox audio.wav -n spectrogram -z 130 -Z -20 -x 1000             # розширити дБ-діапазон/ширину
```
**Інтерпретація:** відкрий `spec.png` — у спектрограмі часто **намальований текст прапорця**, QR-код або патерн (кольорові блоки = біти). За замовчуванням картинка дрібна/темна → підвищ `-X/-Y` (роздільність) і `-z/-Z` (дБ-діапазон), щоб проступив напис.
**Приклади:** QR-код прямо у спектрограмі; «мелодичний» діапазон, де кольорові блоки = 1, порожні = 0 → декодувати як бінарне ([ctftime audacity/spectrogram writeups](https://ctftime.org/writeup/1205)); sox `-X 200 -Y 2050` для читабельності ([ctftime](https://ctftime.org/writeup/19110)).

### Sonic Visualiser / Audacity (GUI, точніше)
```bash
sonic-visualiser audio.wav     # Layer → Add Spectrogram (або Melodic Range Spectrogram)
audacity audio.wav             # трек → ▼ → Spectrogram
```
**Що робити:** переключити на Spectrogram view, підкрутити діапазон/контраст → текст/Morse/QR стають чіткими. Sonic Visualiser дає кращий контроль над діапазоном частот.

## 3. Morse / reversed / швидкість
**Morse:** у спектрограмі/звуці крапки-тире.
```bash
# на слух або візуально у спектрограмі → декодувати крапки/тире вручну:
# .... . .-.. .-.. ---  → HELLO   (таблиця Morse у довіднику)
```
**Reversed speech / аудіо:**
```bash
sox audio.wav reversed.wav reverse        # відтворити назад (прихований голос читає флаг навпаки)
```
**Зміна швидкості/тону (прихований шар):**
```bash
sox audio.wav slow.wav speed 0.5          # уповільнити (почути сховане)
sox audio.wav tempo.wav tempo 0.5         # темп без зміни висоти
```
**Інтерпретація:** голос «задом наперед» → `reverse` робить його читабельним; надто швидкий/високий тон → сповільнити. У спектрограмі крапки/тире → Morse → декодувати в текст.
**Приклад:** reversed-голос у середині кліпу; Morse у спектрограмі, що читається у Sonic Visualiser ([neverlanCTF: Listen to this](https://maltemo.github.io/write-ups/neverlanCTF_2020_Forensic_Listen_to_this.html), [ctftime audio stego](https://ctftime.org/writeup/32286)).

## 4. LSB семплів / DTMF (глибше)
```bash
# LSB у WAV (WavSteg зі stego-toolkit / stegolsb):
stegolsb wavsteg -r -i audio.wav -o out.bin -n 1       # прочитати 1 LSB/семпл
# (альтернатива: python-скрипт читання молодших бітів семплів)
# DTMF-тони (телефонні) → декодувати (multimon-ng / онлайн-таблиця тонів):
multimon-ng -a DTMF -t wav audio.wav
```
**Коли:** спектрограма чиста, реверс не дав → дані в бітах семплів (LSB) або в тонах (DTMF/FSK).
**Обмеження:** LSB-аудіо рідше за спектрограму; DTMF/FSK виглядають як «дані», але **перевір спочатку спектрограму** — часто рішення візуальне, а не декодування потоку.

## Типові пастки
- Дивитись waveform замість спектрограми (дані майже завжди у спектрограмі).
- Не підняти роздільність/дБ sox — напис «не видно», хоча він там (`-X -Y -z -Z`).
- Пропустити `reverse`/`speed` для прихованого голосу.
- Лізти в LSB семплів, не глянувши спектрограму.

## Джерела
- HackTricks — audio stego (у Stego tricks): https://book.hacktricks.wiki/en/generic-methodologies-and-resources/stego-tricks.html
- sox spectrogram (CTF): https://ctftime.org/writeup/19110 · Morse/Sonic Visualiser: https://maltemo.github.io/write-ups/neverlanCTF_2020_Forensic_Listen_to_this.html
- sox офіц.: https://sox.sourceforge.net/ · Sonic Visualiser: https://www.sonicvisualiser.org/
- stego-toolkit (WavSteg/DeepSound огляд): https://github.com/DominicBreuker/stego-toolkit
