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
| форма завантаження файлів | unrestricted upload → webshell | [webshells](../03-cheatsheets/webshells-revshells.md) |
| `?url=`,`?next=`,`?img=` з повним URL | SSRF | [нижче](#ssrf) |
| зміна `?id=2`→`?id=3` показує чужі дані | IDOR | [нижче](#idor) |
| відоме ПЗ+версія (CMS/плагін) | known CVE | `searchsploit` |

## Коротко по кожній

### LFI / Traversal
Параметр керує шляхом до файлу → читаєш `/etc/passwd`, конфіги, ключі; інколи LFI→RCE (log poisoning, php-wrappers). → [cheatsheet](../03-cheatsheets/lfi-traversal.md)

### Command Injection
Поле потрапляє в ОС-команду → дописуєш свою через `;`,`|`,`$()`. Blind → sleep/ping. → [cheatsheet](../03-cheatsheets/command-injection.md)

### SQL Injection
Вхід у SQL-запит → auth bypass (`' OR 1=1-- -`), дамп таблиць (креди/прапорці). → [cheatsheet](../03-cheatsheets/sqlmap-sqli.md)

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

### Known CVE
`whatweb`/банер → версія → `searchsploit <продукт версія>` → PoC офлайн. З деструктивними PoC обережно — перед запуском перевірити, що робить (зразок `hardc0d3d_4pp_s3cr3t`).

## Загальний підхід
1. Визначити ознаку → 2. відкрити cheatsheet → 3. підтвердити вразливість простим тестом → 4. експлуатація для читання файлів / RCE / кредів → 5. flag-hunt.
