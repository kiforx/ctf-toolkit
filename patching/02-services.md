# Patching: Сервіси (SSH / FTP / SMB / Redis / БД / SNMP / NFS)

**Навіщо:** зайшов через сервіс (дефолт-креди, anon-доступ, відкрита БД) → закрий саме цей шлях: змінити креди, вимкнути анонімність, прив'язати до localhost, прибрати небезпечні права. Сервіс лишається **робочим**.
**Коли:** вектор входу — сервіс, а не веб-код.
← [README](README.md) · [00-method](00-method.md) · атаки: [service-enum](../02-workflows/service-enum.md) · [databases](../03-cheatsheets/databases.md)

> **Завжди:** бекап конфігу → зміна → перевірка конфігу (`-t`) → **reload** → сервіс живий + діра закрита. Жодного фаєрвол-блоку (правила).

---

## SSH (22)
**Як зайшов:** знайдений пароль/ключ, слабкий пароль, root-логін.
**Конфіг:** `/etc/ssh/sshd_config`.
**Патч:**
```bash
cp -a /etc/ssh/sshd_config /root/backups/sshd_config.bak
# 1) змінити пароль юзера, яким зайшли (щоб суперник з тим же паролем не ввійшов):
passwd <user>                           # напр. той, чий пароль витік із config.php
# 2) якщо зайшли ЧУЖИМ ключем — прибрати його з authorized_keys:
nano /home/<user>/.ssh/authorized_keys  # видалити лишній/чужий публічний ключ
# 3) заборонити root-логін і (за можливості) парольний вхід:
#    у sshd_config:
#      PermitRootLogin no
#      PasswordAuthentication no      # ТІЛЬКИ якщо легітимний доступ по ключах! інакше лишиться лише ключ
sshd -t && systemctl reload sshd        # перевірити конфіг і м'яко застосувати
```
**Перевірка:** `systemctl is-active sshd` = active, порт 22 слухає; старий пароль/ключ більше не пускає; **ти сам ще маєш доступ** (не замкни себе!).
**Пастка:** `PasswordAuthentication no` замкне всіх без ключів — застосовуй, лише якщо точно є робочий ключ. `reload`, не `restart` (не рве активні сесії). **Не замкни власний доступ.**
**Джерело:** man sshd_config · https://www.ssh.com/academy/ssh/sshd_config

---

## FTP (21)
**Як зайшов:** anonymous-логін, завантаження конфігів/бекапів, або **запис у веб-корінь** (залив webshell через FTP).
**Конфіг:** `/etc/vsftpd.conf` (vsftpd) або `/etc/proftpd/proftpd.conf`.
**Патч (vsftpd):**
```bash
cp -a /etc/vsftpd.conf /root/backups/vsftpd.conf.bak
# вимкнути анонімний доступ і анонімний запис:
#   anonymous_enable=NO
#   anon_upload_enable=NO
#   anon_mkdir_write_enable=NO
# якщо FTP писав у веб-корінь — прибрати право запису або змінити корінь:
#   write_enable=NO                 # якщо запис не потрібен легітимно
systemctl restart vsftpd
```
**Перевірка:** `ftp 127.0.0.1` з `anonymous` → відмова; легітимний юзер (якщо є) працює; сервіс active.
**Пастка:** якщо анонімний доступ — частина завдання (сервіс має «жити»), не вимикай його повністю, а **прибери лише запис** (`anon_upload_enable=NO`) і винеси FTP-корінь за межі веб-кореня, щоб залите не виконувалось.
**Джерело:** man vsftpd.conf · https://security.appspot.com/vsftpd.html

---

## SMB (139/445)
**Як зайшов:** null/guest-сесія, читабельні/записувані шари.
**Конфіг:** `/etc/samba/smb.conf`.
**Патч:**
```bash
cp -a /etc/samba/smb.conf /root/backups/smb.conf.bak
# у [global]:  вимкнути гостьовий доступ
#   map to guest = never
#   restrict anonymous = 2
# у вразливій [share]:  прибрати запис/гостя
#   guest ok = no
#   read only = yes               # якщо запис не потрібен
#   valid users = @потрібнагрупа  # обмежити коло
testparm -s && systemctl restart smbd    # testparm перевіряє конфіг
```
**Перевірка:** `smbclient -L //127.0.0.1 -N` → вже без відкритих шар; легітимний доступ з кредами працює.
**Пастка:** `testparm` перед рестартом; не прибирай шару, якщо її наявність — частина сервісу, лише закрий запис/гостя.

---

## Redis (6379)
**Як зайшов:** Redis **без автентифікації** → webshell через `CONFIG SET dir`/`SAVE` або SSH-ключ.
**Конфіг:** `/etc/redis/redis.conf` (або `CONFIG SET` на льоту).
**Патч:**
```bash
cp -a /etc/redis/redis.conf /root/backups/redis.conf.bak
# на льоту (без рестарту) — поставити пароль і прибрати можливість запису файлів:
redis-cli CONFIG SET requirepass 'Tv@yMiцнийПароль123'
redis-cli -a 'Tv@yMiцнийПароль123' CONFIG SET dir /var/lib/redis      # повернути безпечну робочу теку
# закрити небезпечні команди, якими робили foothold:
redis-cli -a '...' CONFIG SET protected-mode yes
# у redis.conf (щоб пережило рестарт):
#   requirepass Tv@yMiцнийПароль123
#   bind 127.0.0.1 ::1            # слухати лише локально (якщо ззовні не потрібен)
#   protected-mode yes
#   rename-command CONFIG ""      # або rename-command FLUSHALL "" — прибрати небезпечні
systemctl restart redis           # застосувати конфіг-файл (перевір, що додаток ще конектиться!)
```
**Перевірка:** `redis-cli -h <ваш-ip> ping` без пароля → `NOAUTH`; з паролем — `PONG`; **додаток, що користується Redis, ще працює** (онови пароль і в його конфігу!).
**Пастка:** якщо веб-додаток конектиться до Redis — після `requirepass` онови пароль **і в конфігу додатка**, інакше зламаєш сервіс. `bind 127.0.0.1` лише якщо Redis не має бути доступний ззовні.
**Джерело:** Redis Security — https://redis.io/docs/latest/operate/oss_and_stack/management/security/

---

## Бази даних
**Як зайшов:** `root` без/зі слабким паролем; `LOAD_FILE`/`INTO OUTFILE`; `COPY ... TO PROGRAM`.

### MySQL / MariaDB (3306)
```bash
# змінити слабкий/дефолтний пароль:
mysql -u root -p -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'Нов1йСильнийПароль!';"
# прибрати файлові примітиви (SQLi/прямий доступ → читання/запис файлів):
#   у /etc/mysql/mysql.conf.d/mysqld.cnf:  secure_file_priv = /dev/null   (restart mysql)
mysql -u root -p -e "REVOKE FILE ON *.* FROM 'webuser'@'localhost'; FLUSH PRIVILEGES;"
# слухати лише локально (якщо ззовні не треба):
#   bind-address = 127.0.0.1   (у mysqld.cnf → restart)
```
### PostgreSQL (5432)
```bash
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'Нов1йПароль!';"
# прибрати RCE через COPY ... TO PROGRAM (потребує superuser) — не давати веб-юзеру superuser:
sudo -u postgres psql -c "ALTER ROLE webuser NOSUPERUSER;"
# доступ: /etc/postgresql/*/main/pg_hba.conf (хто звідки) + listen_addresses='localhost' у postgresql.conf
```
### MongoDB (27017)
```bash
# увімкнути автентифікацію: у /etc/mongod.conf →
#   security:
#     authorization: enabled
#   net:
#     bindIp: 127.0.0.1
# створити адмін-юзера ДО увімкнення auth, інакше замкнешся:
mongosh --eval "db.getSiblingDB('admin').createUser({user:'admin',pwd:'Пароль!',roles:['root']})"
systemctl restart mongod
```
**Перевірка (усі БД):** під'єднання без пароля/дефолтом → відмова; з новим паролем — ок; **додаток, що ходить у БД, працює** (онови креди в його конфігу!).
**Пастка:** онови пароль БД **і в конфігу веб-додатка** (`config.php`/`.env`) — інакше сайт впаде (мертвий сервіс = мінус бали). Це найчастіша помилка патчингу БД.

---

## SNMP (161/udp)
**Як зайшов:** community `public` → витік конфігів/процесів/паролів.
```bash
# /etc/snmp/snmpd.conf: прибрати дефолтний community, обмежити:
#   замінити  rocommunity public   →  rocommunity СкладнаСтрока 127.0.0.1
systemctl restart snmpd
```
**Перевірка:** `snmpwalk -v2c -c public <ip>` → таймаут/відмова.

## NFS (2049)
**Як зайшов:** експорт з `no_root_squash` / широкий доступ → читання файлів / root через SUID.
```bash
cp -a /etc/exports /root/backups/exports.bak
# у /etc/exports:  прибрати no_root_squash і звузити хост:
#   /export  10.0.N0.0/24(ro,root_squash)      # ro + root_squash (не rw,no_root_squash!)
exportfs -ra        # застосувати без рестарту
```
**Перевірка:** `showmount -e <ip>` — лише потрібне; `no_root_squash` прибрано (SUID-трюк не працює).

## Загальна перевірка після сервіс-патчу
```bash
systemctl is-active <сервіс>                 # active
ss -tlnp | grep <порт>                        # досі слухає
# повтори свій вектор (anon/дефолт-пароль/без-auth) → має провалитись
```

## Джерела
- HackTricks — pentesting services (там і дефолтні конфіги): https://book.hacktricks.wiki/
- Офіційні: sshd_config, vsftpd.conf, redis.io/security, MySQL/PostgreSQL/MongoDB security docs.
