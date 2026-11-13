# Patching: Web-вектори

**Навіщо:** веб — найчастіший шлях входу, тож і патчити доведеться переважно його. Для кожного вектора: де вразливе місце, патч «до/після», перевірка живий-сервіс + закрито-діру.
**Коли:** зайшов через веб.
← [README](README.md) · [00-method](00-method.md) · атаки: [exploit-chains](../03-cheatsheets/exploit-chains.md)

> Приклади — PHP (найчастіший стек). Логіка переноситься на Python/Node. **Завжди спершу бекап** (`cp -a file file.bak`) і дві перевірки ([00-method §5](00-method.md#5-перевірити-дві-перевірки--обовязково-обидві)).

---

## 1. Webshell (залитий файл)
**Як зайшов:** залив `s.php` (`<?php system($_GET['c']);?>`) → `?c=id`.
**Знайти:** усі підозрілі файли у веб-корені (не лише свій — суперники могли залити теж):
```bash
grep -rlE 'system\(|passthru\(|shell_exec\(|exec\(|eval\(|proc_open\(|`.*`' /var/www 2>/dev/null
find /var/www -name '*.php' -newermt '2026-11-14' 2>/dev/null   # файли, створені під час гри
ls -lat /var/www/html/uploads 2>/dev/null | head               # свіжі завантаження
```
**Патч:** видалити **лише залиті шели** (не системні/легітимні файли коду!):
```bash
rm /var/www/html/uploads/s.php        # свій шел
# чужі шели — видаляй обережно, тільки якщо впевнений що це шел (grep показав system/eval + дивне ім'я)
```
**Перевірка:** `curl http://127.0.0.1/uploads/s.php?c=id` → 404; сайт відкривається.
**Пастка:** не видали легітимний код сайту (там теж буває `exec`). Звіряй: шел — це короткий файл з прямим `system($_GET...)` і стороннім ім'ям. **Закрий і причину** — як шел потрапив (upload нижче).

---

## 2. Upload без перевірки
**Як зайшов:** форма завантаження прийняла `.php`/`.phtml` → виконався.
**Знайти:** код обробки завантаження (`move_uploaded_file`):
```bash
grep -rn 'move_uploaded_file\|\$_FILES' /var/www 2>/dev/null
```
**Патч (у коді) — whitelist розширень + перейменування:**
```php
// ДО (вразливо): приймає будь-що
move_uploaded_file($_FILES['f']['tmp_name'], "uploads/".$_FILES['f']['name']);

// ПІСЛЯ: лише дозволені розширення, своє ім'я, заборона виконання
$ext = strtolower(pathinfo($_FILES['f']['name'], PATHINFO_EXTENSION));
$allow = ['jpg','jpeg','png','gif','pdf','txt'];
if (!in_array($ext, $allow)) { http_response_code(400); die("bad type"); }
$name = bin2hex(random_bytes(8)).".".$ext;          // своє безпечне ім'я
move_uploaded_file($_FILES['f']['tmp_name'], "uploads/".$name);
```
**Патч (швидкий, без коду) — заборонити виконання PHP у теці завантажень:**
```apache
# /var/www/html/uploads/.htaccess  (Apache)
php_admin_flag engine off
<FilesMatch "\.(php|phtml|php[0-9]|phar)$">
  Require all denied
</FilesMatch>
```
```nginx
# nginx: у server{} —
location ^~ /uploads/ { location ~ \.php$ { return 403; } }
```
**Перевірка:** завантаж нормальний `.jpg` → ок; залий `.php` → відхилено / не виконується (`curl .../uploads/x.php` не дає RCE); сайт живий.
**Пастка:** не прибери право запису повністю, якщо аплоуд — частина легітимного функціоналу (сервіс має працювати). `.htaccess` діє лише з `AllowOverride` — інакше патч у коді/конфігу.
**Джерело:** OWASP File Upload — https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html

---

## 3. LFI / Path Traversal
**Як зайшов:** `?file=../../../../etc/passwd` → читав/виконував файли.
**Знайти:** параметр у `include`/`require`/`file_get_contents`:
```bash
grep -rn 'include\|require\|file_get_contents\|readfile\|fopen' /var/www 2>/dev/null | grep '\$_'
```
**Патч (у коді) — basename + whitelist:**
```php
// ДО (вразливо):
include($_GET['page'].".php");

// ПІСЛЯ-варіант А: whitelist дозволених сторінок (найнадійніше)
$pages = ['home','about','contact'];
$p = in_array($_GET['page'], $pages) ? $_GET['page'] : 'home';
include("pages/".$p.".php");

// ПІСЛЯ-варіант Б: прибрати traversal (коли список динамічний)
$p = basename($_GET['page']);          // відкидає ../ і шляхи
$p = str_replace(["\0","."], "", $p);  // прибрати null-байт і крапки (за потреби)
include("pages/".$p.".php");
```
**Патч (мітигація конфігом PHP) — прибрати обгортки/віддалене включення:**
```ini
; /etc/php/*/apache2/php.ini  (або fpm/php.ini)
allow_url_include = Off        ; блокує php://input, data://, http:// у include (RFI/RCE-wrapper)
allow_url_fopen  = Off         ; за потреби
```
**Перевірка:** нормальна сторінка (`?page=about`) відкривається; `?file=../../etc/passwd` і `php://filter...` → вже не читає; перезапуск php/apache після зміни ini.
**Пастка:** `basename` не рятує від абсолютних шляхів до дозволеної теки — whitelist надійніший. Log poisoning закривається тим самим (код не включає лог).

---

## 4. Command Injection
**Як зайшов:** `127.0.0.1; id` у полі ping/lookup → виконав команду.
**Знайти:** shell-виклики з вводом:
```bash
grep -rn 'system(\|exec(\|shell_exec(\|passthru(\|popen(\|proc_open(\|`' /var/www 2>/dev/null | grep '\$_'
```
**Патч (у коді) — не передавати ввід у shell; екранувати; whitelist:**
```php
// ДО (вразливо):
system("ping -c1 ".$_GET['ip']);

// ПІСЛЯ-варіант А: валідація вводу (ідеально — суворий формат)
$ip = $_GET['ip'];
if (!filter_var($ip, FILTER_VALIDATE_IP)) { die("invalid ip"); }
system("ping -c1 ".escapeshellarg($ip));     // + екранування аргумента

// ПІСЛЯ-варіант Б: якщо формат складніший — escapeshellarg на КОЖЕН аргумент
system("ping -c1 ".escapeshellarg($_GET['ip']));
```
> `escapeshellarg()` бере весь аргумент у лапки й екранує — `;`,`|`,`$()`,backticks стають безпечними. **Не** використовуй `escapeshellcmd` замість нього (слабший).
**Перевірка:** нормальний `?ip=127.0.0.1` пінгує; `?ip=127.0.0.1;id` → «invalid» або просто пінг без виконання `id`; сайт живий.
**Пастка:** валідуй **формат** (IP/домен), а не «забороняй `;`» — чорні списки обходяться (`%0a`, `$IFS`...). Білий список символів/формату надійніший.
**Джерело:** OWASP OS Command Injection Defense — https://cheatsheetseries.owasp.org/cheatsheets/OS_Command_Injection_Defense_Cheat_Sheet.html

---

## 5. SQL Injection
**Як зайшов:** `' OR 1=1-- -` / `UNION SELECT` → обхід логіну / дамп.
**Знайти:** запити зі склеюванням вводу:
```bash
grep -rn 'SELECT\|INSERT\|UPDATE\|mysqli_query\|->query\|mysql_query' /var/www 2>/dev/null | grep '\$_'
```
**Патч (у коді) — параметризовані запити (prepared statements):**
```php
// ДО (вразливо):
$q = "SELECT * FROM users WHERE name='".$_POST['u']."' AND pass='".$_POST['p']."'";
$r = mysqli_query($con, $q);

// ПІСЛЯ: prepared statement (ввід не стає частиною SQL)
$st = $con->prepare("SELECT * FROM users WHERE name=? AND pass=?");
$st->bind_param("ss", $_POST['u'], $_POST['p']);   // ss = два рядки
$st->execute();
$r = $st->get_result();
```
**Патч (мітигація БД, якщо код правити ніколи) — зрізати потужність інʼєкції:**
```sql
-- прибрати читання/запис файлів через SQLi (INTO OUTFILE / LOAD_FILE):
-- у /etc/mysql/.../mysqld.cnf:  secure_file_priv = /dev/null   (далі restart mysql)
REVOKE FILE ON *.* FROM 'webuser'@'localhost';           -- веб-юзер БД без FILE
-- дати веб-юзеру лише потрібне (не root!):
REVOKE ALL ON *.* FROM 'webuser'@'localhost';
GRANT SELECT,INSERT,UPDATE ON appdb.* TO 'webuser'@'localhost'; FLUSH PRIVILEGES;
```
**Перевірка:** нормальний логін працює; `' OR 1=1-- -` → вже не пускає; `UNION SELECT ... INTO OUTFILE` → заборонено.
**Пастка:** код-патч (prepared) — справжнє рішення; мітигація БД лише зменшує збиток (дамп даних може лишитись можливим). Хоч щось одне зроби **швидко** — SQLi популярний вектор у суперників.
**Джерело:** OWASP SQLi Prevention — https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html

---

## 6. SSTI
**Як зайшов:** `{{7*7}}`=49 → RCE через шаблонізатор (Jinja2/Twig...).
**Знайти:** де ввід потрапляє в шаблон (рендер рядком, а не з файлу):
```bash
grep -rn 'render_template_string\|Template(\|->render(\|{{' /var/www /opt 2>/dev/null | grep '\$_\|request'
```
**Патч (у коді) — не рендерити ввід як шаблон:**
```python
# ДО (вразливо, Flask/Jinja2):
return render_template_string("Hi " + request.args.get('name'))

# ПІСЛЯ: ввід як ДАНІ, не як шаблон
return render_template("hi.html", name=request.args.get('name'))   # autoescape увімкнено
# або просто:
return "Hi " + escape(request.args.get('name'))
```
```php
// Twig ДО: $twig->createTemplate($_GET['x'])->render();   // вразливо
// ПІСЛЯ: передавай ввід змінною в готовий шаблон, не компілюй ввід як шаблон
echo $twig->render('page.twig', ['name' => $_GET['x']]);
```
**Перевірка:** `?name=John` показує «Hi John»; `?name={{7*7}}` показує буквально `{{7*7}}` (не 49); сайт живий.
**Пастка:** суть — **ніколи не компілювати користувацький ввід як шаблон**. Передавай його параметром у заздалегідь написаний шаблон.

---

## 7. XXE
**Як зайшов:** ендпоінт парсив XML → `file:///etc/passwd` / SSRF.
**Знайти:** парсинг XML:
```bash
grep -rn 'simplexml_load\|DOMDocument\|loadXML\|XMLReader\|lxml\|etree' /var/www /opt 2>/dev/null
```
**Патч (у коді) — вимкнути зовнішні сутності:**
```php
// PHP (libxml): вимкнути завантаження зовнішніх сутностей
libxml_set_external_entity_loader(null);        // PHP 8+: головний захист
// (на старих PHP<8: libxml_disable_entity_loader(true);)
$dom = new DOMDocument();
$dom->loadXML($data, LIBXML_NONET);             // LIBXML_NONET = без мережі; НЕ додавай LIBXML_NOENT (воно РОЗГОРТАЄ сутності)
```
```python
# Python: використовувати defusedxml замість стандартного парсера
# ДО:  from xml.etree import ElementTree ; ElementTree.fromstring(data)
# ПІСЛЯ:
from defusedxml.ElementTree import fromstring
fromstring(data)                 # блокує external entities / DTD
```
```java
// Java: вимкнути DTD
factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
```
**Перевірка:** нормальний XML-запит обробляється; payload з `<!ENTITY ... SYSTEM "file://...">` → сутність не розкривається (у відповіді порожньо/помилка, не вміст файлу); сервіс живий.
**Пастка:** головне — **вимкнути DOCTYPE/external entities**, а не фільтрувати рядки. `defusedxml` (Python) робить це за замовчуванням.

---

## 8. Auth bypass / IDOR / SSRF (коротко)
| Вектор | Патч |
|---|---|
| **Default creds** у додатку | змінити пароль адмінки в БД/конфігу на свій; див. [02-services](02-services.md) |
| **JWT `alg:none`/слабкий секрет** | у коді вимагати конкретний `alg` (HS256/RS256), сильний секрет; перевіряти підпис завжди |
| **IDOR** (`?id=2` → чужі дані) | додати перевірку власника: `WHERE id=? AND owner=current_user` |
| **SSRF** (`?url=`) | whitelist дозволених хостів/схем; блок `127.0.0.1`/`169.254.169.254`/внутрішніх діапазонів у коді |
```php
// IDOR ПІСЛЯ:
$st=$con->prepare("SELECT * FROM docs WHERE id=? AND user_id=?");
$st->bind_param("ii",$_GET['id'],$_SESSION['uid']);
```
**Перевірка:** свій обʼєкт доступний; чужий `?id=` → 403; нормальні URL ходять, внутрішні — ні.

## Загальна перевірка після веб-патчу
```bash
curl -s -o /dev/null -w "сайт: %{http_code}\n" http://127.0.0.1/     # 200 = живий
# повтори свій експлойт → має провалитись (див. кожен розділ)
```

## Джерела
- OWASP Cheat Sheets (Upload/SQLi/CmdInj/XXE/SSRF): https://cheatsheetseries.owasp.org/
- HackTricks (вектори й мітигації): https://book.hacktricks.wiki/
- PHP security (escapeshellarg/prepared): https://www.php.net/manual/en/function.escapeshellarg.php
