# Workflow: Service Enumeration (не-веб сервіси)

**Для чого:** витягнути максимум з FTP/SSH/SMB/БД та інших сервісів.
**Коли:** nmap показав відповідні порти.
← [recon](../01-roadmaps/recon.md) · [smb cheatsheet](../03-cheatsheets/smb-enum.md) · [credential-hunting](credential-hunting.md)

---

## <a id="ftp"></a>FTP (21)
```bash
nmap -p21 --script ftp-anon,ftp-syst $TARGET
ftp $TARGET            # login: anonymous / anonymous  (пароль — будь-що)
# ls -la ; get <file> ; binary ; mget *
```
Цікаве: анонімний вхід, завантажувані конфіги/бекапи/ключі, права на upload (→ webshell, якщо FTP=веб-корінь). Зразки прапорців: `ftp_an0n_r3adm3`, `ftp_h1dd3n_d0tf1l3`.

## SSH (22)
Без кредів — глухо (брут цілі лише помірно; **брут платформи заборонений**).
Повернення сюди з кредами/ключами з інших сервісів → [lateral-movement](lateral-movement.md).
```bash
ssh user@$TARGET
ssh -i id_rsa user@$TARGET          # знайдений ключ (chmod 600 id_rsa)
```

## <a id="smb"></a>SMB (139/445)
```bash
nmap -p445 --script smb-os-discovery,smb-enum-shares,smb-enum-users $TARGET
netexec smb $TARGET -u '' -p ''           # null session
netexec smb $TARGET --shares -u '' -p ''
smbclient -L //$TARGET/ -N                # список шар
smbclient //$TARGET/<share> -N            # зайти; get/mget файли
smbmap -H $TARGET -u '' -p ''             # права на шари
enum4linux-ng -A $TARGET                  # повний enum (юзери, шари, політики)
```
Цікаве: читабельні шари, список юзерів (→ spraying), конфіги/скрипти у шарах.
→ деталі: [smb cheatsheet](../03-cheatsheets/smb-enum.md)

## <a id="бази-даних"></a>Бази даних
```bash
mysql -h $TARGET -u root -p                # root без/з простим паролем
psql -h $TARGET -U postgres                # PostgreSQL 5432
redis-cli -h $TARGET                        # Redis 6379 (часто без автентифікації)
# > INFO ; KEYS * ; GET <key>
mongosh --host $TARGET                       # MongoDB 27017: show dbs; use <db>; db.<col>.find()
```
Усередині БД: `SHOW DATABASES; USE x; SHOW TABLES; SELECT * FROM users;` — креди, нотатки, **прапорці** (зразки `sql_r0w_b1ll1ng`, `sql1_un10n_dump`).

## Інші
| Порт | Сервіс | Швидка дія |
|---|---|---|
| 25/110/143 | SMTP/POP3/IMAP | banner, VRFY юзери; читати пошту з кредами |
| 161 UDP | SNMP | `snmpwalk -v2c -c public $TARGET` |
| 2049 | NFS | `showmount -e $TARGET`; mount шару |
| 3000/5000/8000/8080 | app | це веб → [web-enum](web-enum.md) |

## Загальний принцип
Для кожного сервісу: (1) banner/версія → `searchsploit`; (2) anon/default creds; (3) читабельні файли/дані; (4) список юзерів для перевірки кредів деінде.
Усе → [findings-tracker](../07-koth-strategy/findings-tracker.md).
