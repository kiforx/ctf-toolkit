# Roadmap: Flag Hunting

**Для чого:** швидко знаходити прапорці на будь-якому рівні доступу й коректно їх здавати.
**Коли:** отримано доступ (shell/файли/БД).
← [MASTER](MASTER-ROADMAP.md) · скрипт: [flagscan.sh](../05-scripts/flagscan.sh) · [grep/find](../03-cheatsheets/grep-find.md)

---

## Формат (тестовий етап)
```
be_s_t_CTF-_{h1dd3n_r0b0ts_txt}:1
```
- Літери `best`+`CTF` розділені будь-якою кількістю `-` `_` `.` (зокрема кратними й відсутніми).
- Тіло `{[[:alnum:]_]+}` · хвіст `:<номер>` — поле на платформі.
- Основний етап може мати інший формат → змінити `FLAG_REGEX`/`NOISE` у [flagscan.sh](../05-scripts/flagscan.sh).

## Пошук
```bash
# скрипт тімейта (дедуп, фільтри, пропуск бінарних)
bash flagscan.sh --key=KEY /
bash flagscan.sh --key=KEY --include=1,5,7 /     # лише потрібні номери

# keyless-варіант (той самий regex)
grep -raoHE 'b[-_.]*e[-_.]*s[-_.]*t[-_.]*C[-_.]*T[-_.]*F[-_.]*\{[[:alnum:]_]+\}:[0-9]+' / 2>/dev/null | sort -u
```

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
| Логи, метадані файлів | `/var/log/*`; EXIF/PDF-метадані (зразки `3x1f_m3tadata`, `pdf_m3tadata`) |

## Пошук за назвою
```bash
find / \( -iname '*flag*' -o -iname '*.flag' -o -iname 'proof*' \) 2>/dev/null
```

## <a id="перевірка-перед-здачею"></a>Перевірка перед здачею
1. Прапорець брати повністю, як вимагає поле платформи (тіло та/або повний токен).
2. Перевірити **номер** — здавати в правильне поле (`:1`→поле №1).
3. Приклади/зразки не плутати з реальними (дивитись контекст файлу).
4. Записати в [tracker](../07-koth-strategy/findings-tracker.md) → здати → позначити «submitted».

## Після здачі
Повернення у [post-exploitation](post-exploitation.md): кожен новий доступ → знову flag-hunt.
