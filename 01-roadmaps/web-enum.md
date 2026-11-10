# Roadmap: Web Enumeration

**Для чого:** веб — найчастіший вектор входу. Знайти точку, де можна читати файли або виконувати команди.
**Коли:** знайдено HTTP(S) порт.
← [MASTER](MASTER-ROADMAP.md) · деталі: [web-enum workflow](../02-workflows/web-enum.md) · [ffuf](../03-cheatsheets/ffuf-gobuster.md)

---

## Порядок дій
1. **Відбиток:** `whatweb http://$TARGET` — сервер, фреймворк, CMS.
2. **Перегляд:** сайт у браузері + **View Source** (коментарі, шляхи, приховані поля, JS з ендпоінтами).
3. **robots.txt / sitemap.xml** — часто вказують приховані шляхи.
4. **Директорії:** `ffuf`/`gobuster` з розширеннями `.php,.txt,.html,.bak,.zip,.old`.
5. **vhosts / subdomains** за наявності імені хоста (`FUZZ.target`).
6. Знайдено додаток/логін/параметр → гілка нижче.

## Розгалуження (знахідка → куди)
| Знахідка | Техніка | Документ |
|---|---|---|
| Login-форма | default creds → SQLi auth bypass | [sqlmap/SQLi](../03-cheatsheets/sqlmap-sqli.md) |
| `?file=`, `?page=`, `?lang=`, `?doc=` | LFI / path traversal | [lfi-traversal](../03-cheatsheets/lfi-traversal.md) |
| `?cmd=`, `?ip=`, ping/lookup форма | command injection | [command-injection](../03-cheatsheets/command-injection.md) |
| Форма upload файлів | webshell → RCE | [webshells](../03-cheatsheets/webshells-revshells.md) |
| Параметр з повним URL | SSRF | [web-vulns](../04-techniques/web-vulns-overview.md#ssrf) |
| `GET id=1` у БД-запиті | SQL injection | [sqlmap/SQLi](../03-cheatsheets/sqlmap-sqli.md) |
| WordPress/Joomla/Drupal | версія+плагіни → searchsploit | [web-vulns](../04-techniques/web-vulns-overview.md) |
| Доступ до `.git/`, `.svn/` | завантажити сорси, шукати креди | [web-enum workflow](../02-workflows/web-enum.md#git-dump) |
| API / JSON ендпоінт | методи, IDOR, параметри | [curl](../03-cheatsheets/curl.md) |

## Що вважати "цікавим"
- Будь-який параметр, що керує **файлом**, **командою** або **URL**.
- Повідомлення про помилку з **шляхом/версією/SQL** — витік інформації.
- Функція, доступна без автентифікації, якої не мало б бути.
- Коментарі в HTML/JS з кредами, TODO, посиланнями.

## Якщо нічого (анти-rabbit-hole)
Ширший wordlist → інші розширення → інші порти → vhosts → повторний перегляд сорс-коду.
Затик > 20 хв на одному — позначити й переключитись ([5-hour-plan](../07-koth-strategy/5-hour-plan.md)).
