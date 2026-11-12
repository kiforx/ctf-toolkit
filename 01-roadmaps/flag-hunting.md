# Roadmap: Flag Hunting

**Для чого:** швидко знаходити прапорці на будь-якому рівні доступу й коректно їх здавати.
**Коли:** отримано доступ (shell/файли/БД).
← [MASTER](MASTER-ROADMAP.md) · пошук: [flags_searcher_obf.sh](../05-scripts/flags_searcher_obf.sh) · здача: [flag-encode.sh](../05-scripts/flag-encode.sh) · [grep/find](../03-cheatsheets/grep-find.md)

---

## Формат (основний етап)
```
на машині:    be-.s-tCT.F--{FLAG}:<буква><номер>     напр. be-.s-tCT.F--{h1dd3n}:A3
на платформу: bestCTF{FLAG}                  напр. bestCTF{h1dd3n}
```
- Літери `best`+`CTF` розділені будь-якою кількістю `-` `_` `.` (зокрема кратними й відсутніми).
- Тіло `{...}` · хвіст `:<буква-категорія><номер>` — вказує, **у яке поле** на платформі здавати.
- На платформу вносимо **лише `bestCTF{FLAG}`** — букву та номер НЕ включати.
- Формат може змінитись → `FLAG_REGEX`/`NOISE` у скрипті.

## Пошук
```bash
# основний: обфускований searcher (space-форма; --key = ФАЙЛ з ключем)
printf '%s' 'S@mEvEryC0olk3Y1414$' > /tmp/.k    # ключ у файл (один раз)

bash flags_searcher_obf.sh --key /tmp/.k --directory / | bash flag-encode.sh
#   → bestCTF{FLAG}  slot=A3   (фільтри: --include 1,2 / --exclude 7 / --output FILE)

# keyless-варіант (той самий формат, без скрипта)
grep -raoHE 'b[-_.]*e[-_.]*s[-_.]*t[-_.]*C[-_.]*T[-_.]*F[-_.]*\{[[:alnum:]_]+\}:[A-Za-z0-9]+' / 2>/dev/null | sort -u
```
Повний опис опцій — [05-scripts/README](../05-scripts/README.md).

## Де шукати (за пріоритетом)
| Місце | Команда |
|---|---|
| Домашні директорії всіх юзерів | `ls -la /home/* /root 2>/dev/null; cat /home/*/*.txt` |
| Веб-корінь | `grep -rl best /var/www 2>/dev/null` |
| Конфіги/додатки | `/opt`, `/srv`, `/etc`, `/usr/local` |
| Тимчасові | `/tmp`, `/dev/shm`, `/var/tmp` |
| Пошта | `/var/mail/*`, `/var/spool/mail/*` |
| Бекапи/дампи | `/var/backups`, `*.sql`, `*.bak`, `*.tar*`, `*.zip` |
| Бази даних | вхід у БД → `SELECT` по таблицях (креди/нотатки) |
| Env/процеси | `env`, `cat /proc/*/environ 2>/dev/null \| tr '\0' '\n'` |
| Логи, метадані файлів | `/var/log/*`; EXIF/PDF-метадані (зразки `3x1f_m3tadata`, `pdf_m3tadata`) → [forensics/metadata](../forensics/02-metadata.md) |

## Пошук за назвою
```bash
find / \( -iname '*flag*' -o -iname '*.flag' -o -iname 'proof*' \) 2>/dev/null
```

## <a id="перевірка-перед-здачею"></a>Перевірка перед здачею
1. Нормалізувати у `bestCTF{FLAG}` ([flag-encode.sh](../05-scripts/flag-encode.sh)) — прибрати сепаратори, відкинути `:<буква><номер>`.
2. Слот `:<буква><номер>` (напр. `A3`) = **яке поле/категорія** на платформі. Здавати в правильний слот.
3. У поле вносити **лише `bestCTF{FLAG}`** — без букви та номера.
4. Приклади/зразки не плутати з реальними (дивитись контекст файлу).
5. Записати у спільний нотатник → здати → позначити «submitted».

## Після здачі
Повернення у [post-exploitation](post-exploitation.md): кожен новий доступ/рівень → знову flag-hunt.
