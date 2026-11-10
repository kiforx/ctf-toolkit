# Roadmap: Initial Access

**Для чого:** перетворити знайдену вразливість/креди на виконання команд або валідну сесію.
**Коли:** є LFI/RCE/upload/SQLi/креди.
← [MASTER](MASTER-ROADMAP.md) · [webshells/revshells](../03-cheatsheets/webshells-revshells.md) · [lateral](../02-workflows/lateral-movement.md)

> Готові повні ланцюжки «вхід → shell» одним місцем: [exploit-chains](../03-cheatsheets/exploit-chains.md).

---

## Шляхи до доступу
| Наявне | Крок до доступу |
|---|---|
| Command injection | одразу reverse shell ([revshells](../03-cheatsheets/webshells-revshells.md)) |
| Upload | залити `.php` webshell → reverse shell |
| LFI | читати конфіги/`id_rsa`/`authorized_keys`; LFI→RCE (log/wrapper) — [lfi](../03-cheatsheets/lfi-traversal.md) |
| SQLi | auth bypass, дамп таблиці users → креди → login/SSH |
| Default/знайдені креди | `ssh user@$TARGET`, веб-панель, DB, SMB |

## Reverse shell — чекліст (часта причина «не працює»)
1. Listener **там, де піднятий VPN** (у віртуалці, якщо VPN у віртуалці) — інакше shell не дійде.
2. `nc -lvnp 4444` на VPN-адресі `10.8.N.x`, не на `127.0.0.1`.
3. У payload — VPN-адреса, не localhost цілі.
4. Bash-shell не проходить → `python`, `nc`, `mkfifo`, інші порти (80/443).

→ повний набір: [netcat/socat](../03-cheatsheets/netcat-socat.md), [revshells](../03-cheatsheets/webshells-revshells.md)

## Отримано shell → одразу:
```bash
# 1. Стабілізація (повноцінний TTY)
python3 -c 'import pty;pty.spawn("/bin/bash")'
# Ctrl+Z → stty raw -echo; fg → Enter → export TERM=xterm

# 2. Хто і що дозволено
id; hostname; pwd; sudo -l 2>/dev/null

# 3. Швидкий flag-check на місці
grep -raoHE 'b[-_.]*e[-_.]*s[-_.]*t[-_.]*C[-_.]*T[-_.]*F[-_.]*\{[[:alnum:]_]+\}:[0-9]+' . ~ 2>/dev/null
```
→ далі [Post-Exploitation](post-exploitation.md)

## Отримано тільки креди (без shell)
Найцінніше в цьому CTF. Перевірити креди на **всіх** сервісах (SSH, DB, SMB, веб, інші юзери):
→ [credential-hunting](../02-workflows/credential-hunting.md) · [lateral-movement](../02-workflows/lateral-movement.md)

## Правила-нагадування
Жодних деструктивних дій (не видаляти, не ламати сервіс). Shell — для enum і пошуку прапорців.
