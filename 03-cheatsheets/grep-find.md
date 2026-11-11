# Cheatsheet: grep / find (пошук файлів і вмісту)

Головні інструменти flag-hunting та пошуку кредів. ← [flag-hunting](../01-roadmaps/flag-hunting.md) · [credential-hunting](../02-workflows/credential-hunting.md)

## grep — пошук за вмістом
```bash
grep -rn 'password' /var/www 2>/dev/null         # -n номер рядка, помилки приховані
grep -rin 'pass\|secret\|token' /etc 2>/dev/null # -i регістр, \| АБО
grep -rl 'secret' / 2>/dev/null                  # -l лише імена файлів
grep -raoHE '<regex>' / 2>/dev/null              # -o лише збіг, -a бінарні як текст, -H ім'я файлу
grep -rn 'db' --include='*.php' /var/www          # лише певні файли
```
Прапорці: `-r` рекурсивно · `-i` без регістру · `-n` рядок · `-l` лише файли · `-o` лише збіг · `-E`/`-P` regex · `-a` бінарні як текст · `-H` ім'я файлу · `--include`.

### Flag regex (сепаратори `-` `_` `.`)
```bash
grep -raoHE 'b[-_.]*e[-_.]*s[-_.]*t[-_.]*C[-_.]*T[-_.]*F[-_.]*\{[[:alnum:]_]+\}:[A-Za-z0-9]+' / 2>/dev/null | sort -u
```
Готовий скрипт із дедупом і фільтрами: [flags_searcher_obf.sh](../05-scripts/flags_searcher_obf.sh) (`--key ФАЙЛ --directory ДИР`, [опис](../05-scripts/README.md)).
> Увага: літери флагу розбиті сепараторами, тож пошук літерального `bestCTF` реальні флаги НЕ ловить — лише regex вище.

## ripgrep (`rg`) — швидше за `grep -r` (якщо є на цілі)
```bash
rg -n 'password|secret|token' /var/www        # швидкий рекурсивний пошук
rg -uu -n 'api[_-]?key' /                       # -uu: не ігнорувати hidden/.gitignore/бінарні
rg -l 'BEGIN RSA PRIVATE KEY' /home             # файли з приватними ключами
rg -o "$FR" /home /opt 2>/dev/null              # той самий flag-regex ($FR — нижче), швидше
```

## strings — секрети/флаги у бінарях і дампах
```bash
strings -n8 /usr/local/bin/app | grep -iE 'pass|key|flag|http'   # рядки з бінара
strings core.dump | grep -aoE "$FR"                               # прапорці у core/дампі ($FR — нижче)
```

## find — пошук за іменем/властивостями
```bash
find / -name '*flag*' 2>/dev/null
find / -iname '*.conf' 2>/dev/null                # -iname без регістру
find / -type f -newermt '2026-11-01' 2>/dev/null  # нові файли
find / -writable -type d 2>/dev/null              # куди можу писати
find / -perm -4000 -type f 2>/dev/null            # SUID (довідково)
find /home -name 'id_rsa' 2>/dev/null             # SSH-ключі
find / -name '*.bak' -o -name '*.sql' 2>/dev/null # бекапи/дампи
find / -perm -o+w -type f 2>/dev/null             # world-writable файли (hijack/крон)
find / -user root -perm -4000 2>/dev/null         # root-SUID (priv-esc кандидати)
find /home -user www-data 2>/dev/null             # файли конкретного юзера
find / -newermt '2026-11-14 09:00' ! -newermt '2026-11-14 21:00' 2>/dev/null  # змінені під час гри
# find + grep (вміст у знайдених)
find / -name '*.php' -exec grep -l 'password' {} \; 2>/dev/null
```

## Корисні комбінації для прапорців
```bash
FR='b[-_.]*e[-_.]*s[-_.]*t[-_.]*C[-_.]*T[-_.]*F[-_.]*\{[[:alnum:]_]+\}:[A-Za-z0-9]+'
# у гарячих директоріях
grep -raoHE "$FR" /home /root /var/www /opt /srv 2>/dev/null | sort -u
# env процесів
cat /proc/*/environ 2>/dev/null | tr '\0' '\n' | grep -aoE "$FR"
```

## Пастки
- Завжди `2>/dev/null` — інакше вивід тоне в «Permission denied».
- `grep -r /` довго — починати з «гарячих» директорій (`/home`, `/var/www`, `/opt`).
- Сепаратори `-_.` → regex вище або [flags_searcher_obf.sh](../05-scripts/flags_searcher_obf.sh).
