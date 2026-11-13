# Patching: Метод (загальний, з нуля)

**Навіщо:** перш ніж патчити конкретний вектор — спільні навички: знайти вразливий файл/конфіг, безпечно відредагувати, перезапустити сервіс, перевірити, що він живий і діра закрита, і мати змогу відкотити. Якщо ти ніколи не патчив — це база.
← [README](README.md) · далі: [01-web](01-web.md) · [02-services](02-services.md) · [03-system](03-system.md)

---

## 1. Знайти, ДЕ патчити

### Веб-додаток — знайти код
```bash
# типові веб-корені (де лежить код сайту):
ls -la /var/www/html /var/www /srv/www /usr/share/nginx/html 2>/dev/null
ls -la /opt /home/*/app /app 2>/dev/null
# який сервер і куди вказує:
cat /etc/apache2/sites-enabled/*.conf 2>/dev/null | grep -i documentroot
cat /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*.conf 2>/dev/null | grep -i root
ps aux | grep -E 'apache|nginx|php|python|node|gunicorn'   # що обслуговує сайт
# знайти конкретний вразливий файл (напр. що обробляє ?file=):
grep -rn 'include\|require\|file_get_contents\|system\|exec\|shell_exec' /var/www 2>/dev/null | grep -v Binary
```
**Інтерпретація:** `DocumentRoot /var/www/html` → код тут. Параметр із атаки (напр. `page`) шукай у коді: `grep -rn '\$_GET\[.page.\]' /var/www`.

### Сервіс — знайти конфіг
```bash
systemctl status <сервіс>                    # де бінар/юніт
systemctl cat <сервіс> | grep -i exec        # яка команда/конфіг запускається
# типові конфіги:
#   SSH      /etc/ssh/sshd_config
#   FTP      /etc/vsftpd.conf  /etc/proftpd/proftpd.conf
#   Redis    /etc/redis/redis.conf
#   MySQL    /etc/mysql/mysql.conf.d/mysqld.cnf
#   Samba    /etc/samba/smb.conf
#   NFS      /etc/exports
```

## 2. BACKUP перед будь-якою зміною (обов'язково!)
```bash
cp -a /var/www/html/vuln.php /var/www/html/vuln.php.bak      # -a зберігає права/власника/час
# або з міткою часу:
cp -a /etc/ssh/sshd_config /root/backups/sshd_config.$(date +%s)
mkdir -p /root/backups                                        # місце для бекапів
```
**Навіщо:** якщо патч зламає сервіс — миттєвий відкат `cp -a файл.bak файл`. Без бекапу зламаний сервіс = мінус бали й паніка.

## 3. Відредагувати файл
```bash
nano /var/www/html/vuln.php        # простий редактор (Ctrl+O зберегти, Ctrl+X вийти)
vi /var/www/html/vuln.php          # якщо тільки vi: i — вставка, Esc, :wq — зберегти
# точкова заміна без редактора (обережно, спершу бекап!):
sed -i.bak 's/ПОГАНО/ДОБРЕ/' файл  # -i.bak сам робить бекап файл.bak
```
> Для конфігів часто досить змінити/додати один рядок директиви. Для коду — додати перевірку вводу (приклади в [01-web](01-web.md)).

## 4. Застосувати зміну (перезапуск — ОБЕРЕЖНО)
- **Код PHP/скрипти** (інтерпретовані) — зміни діють **одразу**, рестарт **не потрібен** (наступний запит уже виконає новий код).
- **Конфіг сервісу** — потрібен reload/restart. **Reload м'якший за restart** (не рве з'єднання):
```bash
systemctl reload sshd        # застосувати конфіг без розриву сесій (де підтримується)
systemctl restart redis      # повний перезапуск (коротка недоступність — роби швидко)
# перевір ДО рестарту, що конфіг валідний (інакше сервіс не підніметься!):
sshd -t                      # перевірка sshd_config
nginx -t                     # перевірка nginx
apachectl configtest         # перевірка apache
redis-server /etc/redis/redis.conf --test-memory 1  # (або просто уважно)
```
> **Критично:** `sshd -t`/`nginx -t` ДО рестарту. Поганий конфіг + restart = сервіс не підніметься = мертвий сервіс = мінус бали. Reload краще за restart там, де можна.

## 5. Перевірити (дві перевірки — обов'язково обидві)
### 5a. Сервіс ЖИВИЙ (легітимний запит працює)
```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1/        # сайт віддає 200?
systemctl is-active <сервіс>                                      # active?
ss -tlnp | grep <порт>                                            # досі слухає?
# функціональна перевірка: відкрий сайт/залогінься/зроби нормальну дію
```
### 5b. Діра ЗАКРИТА (той самий експлойт не працює)
```bash
# повтори СВІЙ експлойт — має провалитись:
curl "http://127.0.0.1/?file=../../../../etc/passwd"   # LFI → вже не читає?
curl "http://127.0.0.1/uploads/shell.php?c=id"          # webshell → 404/не виконує?
```
**Інтерпретація:** сервіс 200 + експлойт не працює = **добрий патч**. Сервіс впав = відкоти (`cp -a файл.bak файл`), думай ще. Експлойт досі працює = патч не закрив, шукай інше місце.

## 6. Нотатка (для організаторів і для себе)
Тримай файл, напр. `/root/patch-notes.txt`:
```
[вектор]   LFI у index.php через ?file=
[як зайшов] curl "...?file=../../etc/passwd"
[патч]     basename() + whitelist у index.php:42 ; бекап index.php.bak
[перевірка] сайт 200 OK; ?file=../../ → "invalid"
```
Організатори можуть попросити пояснити рішення — ця нотатка рятує. Також це твій план відкату.

## 7. Відкат (якщо щось пішло не так)
```bash
cp -a /var/www/html/vuln.php.bak /var/www/html/vuln.php   # повернути код
cp -a /root/backups/sshd_config.<ts> /etc/ssh/sshd_config; systemctl reload sshd
systemctl restart <сервіс>                                 # підняти, якщо впав
```

## Золоті правила методу
- **Бекап завжди перед зміною.** Без винятків.
- **Reload > restart**, і **перевірка конфігу (`-t`) перед рестартом.**
- **Дві перевірки:** сервіс живий + діра закрита.
- **Мінімальний патч:** чіпай лише вразливе, не «покращуй» усе підряд (зламаєш функціонал).
- **Жодного фаєрволу/видалення сервісу** (правила).
- **Нотатка** на кожен патч.

## Джерела
- OWASP Secure Coding / Input Validation: https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html
- man sshd_config / nginx -t / apachectl — офіційні перевірки конфігів.
