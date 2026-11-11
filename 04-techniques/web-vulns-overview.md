# Technique: Web Vulnerabilities (огляд)

**Навіщо:** швидко впізнати тип вразливості за ознаками й перейти до потрібного cheatsheet.
← [web-enum](../01-roadmaps/web-enum.md) · [web-enum workflow](../02-workflows/web-enum.md)

---

## Карта «ознака → вразливість → документ»
| Ознака у додатку | Ймовірна вразливість | Документ |
|---|---|---|
| `?file=`,`?page=`,`?path=`,`?lang=` | LFI / path traversal | [lfi-traversal](../03-cheatsheets/lfi-traversal.md) |
| поле вводу → ОС-дія (ping, dns, convert) | command injection | [command-injection](../03-cheatsheets/command-injection.md) |
| `id=1` у БД-запиті, login-форма | SQL injection | [sqlmap-sqli](../03-cheatsheets/sqlmap-sqli.md) |
| ввід відображається у сторінці/листі, `{{ }}`/`${ }` | SSTI → RCE | [ssti](../03-cheatsheets/ssti.md) |
| ендпоінт приймає XML/SOAP/SAML, upload `.svg`/`.docx` | XXE → file read/SSRF | [xxe](../03-cheatsheets/xxe.md) |
| JWT-токен, cookie з `role`/`isAdmin`, login | auth bypass / JWT | [auth-jwt](../03-cheatsheets/auth-jwt.md) |
| login без помилок SQL, JSON-логін, `$`-оператори | NoSQL injection | [нижче](#nosqli) |
| форма завантаження файлів | unrestricted upload → webshell | [webshells](../03-cheatsheets/webshells-revshells.md) |
| `?url=`,`?next=`,`?img=` з повним URL | SSRF | [нижче](#ssrf) |
| зміна `?id=2`→`?id=3` показує чужі дані | IDOR | [нижче](#idor) |
| серіалізований об'єкт у cookie/параметрі (`O:`,`rO0`,`gASV`) | deserialization → RCE | [нижче](#deser) |
| ввід відображається у HTML без екранування | XSS (крадіжка cookie/прапорця) | [нижче](#xss) |
| відоме ПЗ+версія (CMS/плагін) | known CVE | `searchsploit` |

## Коротко по кожній

### LFI / Traversal
Параметр керує шляхом до файлу → читаєш `/etc/passwd`, конфіги, ключі; інколи LFI→RCE (log poisoning, php-wrappers). → [cheatsheet](../03-cheatsheets/lfi-traversal.md)

### Command Injection
Поле потрапляє в ОС-команду → дописуєш свою через `;`,`|`,`$()`. Blind → sleep/ping. → [cheatsheet](../03-cheatsheets/command-injection.md)

### SQL Injection
Вхід у SQL-запит → auth bypass (`' OR 1=1-- -`), дамп таблиць (креди/прапорці). → [cheatsheet](../03-cheatsheets/sqlmap-sqli.md)

### SSTI
Ввід потрапляє у шаблонізатор → `{{7*7}}`=49 підтверджує; Jinja2/Twig/Freemarker → RCE. → [cheatsheet](../03-cheatsheets/ssti.md)

### XXE
Парсер XML читає зовнішні сутності → `file:///etc/passwd`, SSRF, blind-OOB exfil. → [cheatsheet](../03-cheatsheets/xxe.md)

### Auth / JWT
Default creds, `alg:none`, слабкий HS256-секрет, `kid`-injection → адмінка/чужі дані. → [cheatsheet](../03-cheatsheets/auth-jwt.md)

### File Upload
Немає перевірки типу → залити `.php` webshell. Обходи: `.phtml`, подвійне розширення, підміна `Content-Type`, magic bytes. → [webshells](../03-cheatsheets/webshells-revshells.md)

### <a id="ssrf"></a>SSRF
Сервер робить запит за наданим URL → доступ до внутрішніх сервісів/метаданих.
```
?url=http://127.0.0.1:8080/        # внутрішній сервіс
?url=http://localhost/admin
?url=file:///etc/passwd            # інколи читає файли
```
Сканування внутрішніх портів через різні URL; поєднуй з [pivoting](../02-workflows/pivoting-portforward.md).

### <a id="idor"></a>IDOR
Пряме посилання на обʼєкт без перевірки прав. Перебір `id`, `user`, `file`:
```bash
curl -b cookie 'http://$TARGET/profile?id=1'   # → id=2,3... чужі дані/прапорці
```

### <a id="nosqli"></a>NoSQL Injection
Ввід іде у Mongo-подібний запит без санітизації → обхід логіну та дамп. Оператори у JSON або у query-string:
```
# JSON-логін (Content-Type: application/json):
{"user":{"$ne":null},"pass":{"$ne":null}}       # обійти перевірку пароля
{"user":"admin","pass":{"$gt":""}}              # зайти як admin
# query-string (Express/PHP):
user[$ne]=0&pass[$ne]=0
# JS-injection у $where:
'||'1'=='1   ;   admin'/*
```
Blind-витяг по символу: `pass[$regex]=^a` → перебір, якщо відповідь різниться. Пряма БД: [databases: MongoDB](../03-cheatsheets/databases.md).

### <a id="deser"></a>Insecure Deserialization
Серіалізований об'єкт приходить від клієнта → RCE через gadget-ланцюг. Впізнати за префіксом:
```
O:8:"stdClass"...        # PHP serialize()  → POP-ланцюг / phpggc
rO0AB...                 # Java (base64 'аced0005') → ysoserial
gASV / gAJ9              # Python pickle   → __reduce__ RCE
{"__proto__":...}        # Node prototype pollution → інколи RCE
```
PoC-генератори офлайн: `phpggc <gadget> system id`, `ysoserial CommonsCollections5 'id'`. З деструктивними — обережно; пробувати на СВОЇЙ цілі.

### <a id="xss"></a>XSS
Ввід у HTML без екранування → крадіжка cookie/сесії адміна або читання прапорця з чужої/адмін-сторінки. `"><svg onload=alert(1)>` підтверджує; Stored (коментар/профіль) спрацьовує, коли сторінку відкриє бот/адмін. → [cheatsheet](../03-cheatsheets/xss.md)

### Known CVE
`whatweb`/банер → версія → `searchsploit <продукт версія>` → PoC офлайн. З деструктивними PoC обережно — перед запуском перевірити, що робить (зразок `hardc0d3d_4pp_s3cr3t`).

## Загальний підхід
1. Визначити ознаку → 2. відкрити cheatsheet → 3. підтвердити вразливість простим тестом → 4. експлуатація для читання файлів / RCE / кредів → 5. flag-hunt.
