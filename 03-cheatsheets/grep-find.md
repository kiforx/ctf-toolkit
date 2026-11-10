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
grep -raoHE 'b[-_.]*e[-_.]*s[-_.]*t[-_.]*C[-_.]*T[-_.]*F[-_.]*\{[[:alnum:]_]+\}:[0-9]+' / 2>/dev/null | sort -u
```
Готовий скрипт із дедупом і фільтрами: [flagscan.sh](../05-scripts/flagscan.sh).
> Увага: літери флагу розбиті сепараторами, тож пошук літерального `bestCTF` реальні флаги НЕ ловить — лише regex вище.

## find — пошук за іменем/властивостями
```bash
find / -name '*flag*' 2>/dev/null
find / -iname '*.conf' 2>/dev/null                # -iname без регістру
find / -type f -newermt '2026-11-01' 2>/dev/null  # нові файли
find / -writable -type d 2>/dev/null              # куди можу писати
find / -perm -4000 -type f 2>/dev/null            # SUID (довідково)
find /home -name 'id_rsa' 2>/dev/null             # SSH-ключі
find / -name '*.bak' -o -name '*.sql' 2>/dev/null # бекапи/дампи
# find + grep (вміст у знайдених)
find / -name '*.php' -exec grep -l 'password' {} \; 2>/dev/null
```

## Корисні комбінації для прапорців
```bash
FR='b[-_.]*e[-_.]*s[-_.]*t[-_.]*C[-_.]*T[-_.]*F[-_.]*\{[[:alnum:]_]+\}:[0-9]+'
# у гарячих директоріях
grep -raoHE "$FR" /home /root /var/www /opt /srv 2>/dev/null | sort -u
# env процесів
cat /proc/*/environ 2>/dev/null | tr '\0' '\n' | grep -aoE "$FR"
```

## Пастки
- Завжди `2>/dev/null` — інакше вивід тоне в «Permission denied».
- `grep -r /` довго — починати з «гарячих» директорій (`/home`, `/var/www`, `/opt`).
- Сепаратори `-_.` → regex вище або [flagscan.sh](../05-scripts/flagscan.sh).
