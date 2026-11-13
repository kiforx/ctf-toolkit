# Patching: Cheatsheet (швидко під час гри)

Таблиця «вектор → мінімальний патч → перевірка». Деталі/код — за посиланнями.
← [README](README.md) · метод [00](00-method.md) · web [01](01-web.md) · services [02](02-services.md) · system [03](03-system.md)

> **Завжди:** `cp -a file file.bak` → патч → **сервіс живий?** (`curl` 200 / `systemctl is-active`) + **діра закрита?** (повтори експлойт). Жодного фаєрвол-блоку/видалення сервісу (правила).

---

## Алгоритм (кожен патч)
```
1. бекап:  cp -a <file> <file>.bak
2. патч:   мінімальна зміна коду/конфігу
3. застосуй: код PHP — одразу; конфіг — (-t перевірка) → systemctl reload/restart
4. живий:  curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1/   → 200
5. закрито: повтори свій експлойт → провал
6. нотатка: вектор → як пропатчив  (для організаторів)
```

## Web
| Вектор | Мінімальний патч | Перевірка | Деталі |
|---|---|---|---|
| Webshell | `rm /var/www/html/uploads/s.php` (лише шел!) | `curl .../s.php?c=id` → 404 | [01](01-web.md#1-webshell-залитий-файл) |
| Upload | whitelist розширень у коді; **Apache** `.htaccess` `php_admin_flag engine off`; **nginx** `location ~ \.php$ {deny all}` у uploads | `.php` відхилено, `.jpg` ок | [01](01-web.md#2-upload-без-перевірки) |
| **Nginx** (веб-сервер) | uploads→deny .php; **jpg→php RCE**: `try_files $uri =404`+`cgi.fix_pathinfo=0`; `autoindex off`; alias-слеші; deny `.git`/`.env`/`.bak` → `nginx -t && reload` | `/uploads/x.jpg/y.php`→404; `/.git/`→403 | [01](01-web.md#9-nginx-патчі-рівня-веб-сервера) |
| LFI | `basename()`+whitelist; `allow_url_include=Off` | `?file=../../etc/passwd` → ні | [01](01-web.md#3-lfi--path-traversal) |
| Cmd injection | `escapeshellarg()` + валідація формату | `?ip=1;id` → без RCE | [01](01-web.md#4-command-injection) |
| SQLi | prepared statements; `REVOKE FILE`, `secure_file_priv` | `' OR 1=1--` → ні | [01](01-web.md#5-sql-injection) |
| SSTI | не рендерити ввід як шаблон (параметром у шаблон) | `{{7*7}}` → буквально | [01](01-web.md#6-ssti) |
| XXE | `libxml_set_external_entity_loader(null)` / defusedxml | `file://` сутність не читає | [01](01-web.md#7-xxe) |
| IDOR | `WHERE id=? AND owner=?` | чужий `?id=` → 403 | [01](01-web.md#8-auth-bypass--idor--ssrf-коротко) |

## Services
| Вектор | Мінімальний патч | Перевірка | Деталі |
|---|---|---|---|
| SSH (креди/ключ) | `passwd <user>`; прибрати чужий `authorized_keys`; `PermitRootLogin no` → `sshd -t && reload` | старий пароль/ключ → ні, ти ще маєш доступ | [02](02-services.md#ssh-22) |
| FTP (anon/запис) | `anonymous_enable=NO`/`anon_upload_enable=NO` → restart | anon → відмова | [02](02-services.md#ftp-21) |
| SMB (null/guest) | `map to guest=never`; `guest ok=no`; `read only=yes` → `testparm && restart smbd` | null-сесія → ні | [02](02-services.md#smb-139445) |
| Redis (no-auth) | `CONFIG SET requirepass ...` + оновити пароль у додатку; `protected-mode yes` | `ping` без пароля → NOAUTH | [02](02-services.md#redis-6379) |
| MySQL (дефолт/FILE) | `ALTER USER`; `REVOKE FILE`; `secure_file_priv` + оновити `config.php` | дефолт → ні, сайт живий | [02](02-services.md#бази-даних) |
| Postgres | `ALTER USER PASSWORD`; `NOSUPERUSER` веб-ролі | `COPY..PROGRAM` → ні | [02](02-services.md#бази-даних) |
| Mongo | `authorization: enabled` + bindIp 127.0.0.1 + оновити додаток | без auth → ні | [02](02-services.md#бази-даних) |
| SNMP | `rocommunity` ≠ public, обмежити хостом | `snmpwalk -c public` → таймаут | [02](02-services.md#snmp-161udp) |
| NFS | прибрати `no_root_squash`, `ro`, звузити хост → `exportfs -ra` | SUID-трюк → ні | [02](02-services.md#nfs-2049) |

## System (privesc)
| Вектор | Мінімальний патч | Перевірка | Деталі |
|---|---|---|---|
| Слабкий/витеклий пароль | `passwd <user>` + оновити конфіги, де лежав | `su` старим → ні | [03](03-system.md#1-слабкі--витеклі-паролі) |
| SUID-бінар (нетиповий!) | `chmod u-s /path/bin` | не дає root; стандартні SUID не чіпати | [03](03-system.md#2-suid-бінар) |
| Cron writable-скрипт | прибрати чужі рядки; `chown root:root`+`chmod 755/700` | не допишеш; cron працює | [03](03-system.md#3-cron--writable-скрипт) |
| Sudo misconfig | `visudo` → прибрати небезпечний рядок | `sudo -l` → без escape | [03](03-system.md#4-sudo-misconfig) |
| Writable-файл | `chmod o-w /path` точково | без `w` для others | [03](03-system.md#5-writable-файли--world-writable) |
| Чужий SSH-ключ | видалити з `authorized_keys` | чужий ключ → ні | [03](03-system.md#6-чужий-ssh-ключ--доступ) |
| Старе ядро | **не** ребутати; закрий інші вектори до kernel-кроку | — | [03](03-system.md#7-старе-ядро-kernel-exploit) |

## Утримання вершини
```bash
id ; echo '<НАЗВА_КОМАНДИ>' > /king.txt ; passwd root    # root + king.txt + закрити свій вектор
```

## ⚠️ Чого НЕ робити (бан)
- **Не** блокувати фаєрволом (`iptables DROP`) — патчимо діру, не доступ.
- **Не** вимикати/видаляти сервіс, не ребутати, не чіпати прапорці/системні файли.
- **Не** «вбивати» сервіс патчем — мертвий сервіс гірший за непатчений.
