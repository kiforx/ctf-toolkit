# Roadmap: Recon

**Для чого:** швидко зрозуміти, що є на цілі, й не пропустити жоден сервіс.
**Коли:** на старті та після кожного нового доступу (внутрішні порти).
← назад: [MASTER](MASTER-ROADMAP.md) · деталі команд: [network-enum workflow](../02-workflows/network-enum.md) · [nmap cheatsheet](../03-cheatsheets/nmap.md)

---

## Алгоритм (3 термінали паралельно)

```bash
TARGET=10.0.N0.10

# T1 — швидкий, робота через 60 сек
nmap -sC -sV -T4 --open $TARGET -oN nmap-quick.txt

# T2 — ВСІ порти (сервіс на 8080/50000 легко проґавити)
nmap -p- -T4 --min-rate 2000 --open $TARGET -oN nmap-all.txt
# нові порти → догнати версії:
# nmap -sCV -p <нові,порти> $TARGET -oN nmap-extra.txt

# T3 — UDP топ (SNMP/TFTP/DNS інколи дають вхід)
sudo nmap -sU --top-ports 50 -T4 $TARGET -oN nmap-udp.txt
```

## Що читати у виводі
- **Версія сервісу** → одразу `searchsploit <продукт версія>` (offline exploit-db).
- **HTTP title / redirect** → натякає на CMS/додаток.
- **Нестандартний порт** → `nc -nv $TARGET <port>`, подивитись banner.
- Відкриті `139/445`, `3389`, `5985` → ймовірно Windows.

## Інтерпретація → наступний крок
| Результат | Дія |
|---|---|
| Є 80/443/8080/… | → [web-enum](web-enum.md) (пріоритет №1) |
| Є 21/22/139/445/3306/6379… | → [service-enum](../02-workflows/service-enum.md) |
| Тільки SSH (22) | креди шукати деінде; SSH без кредів — глухо |
| Порожньо / фільтрується | перевірити VPN, спробувати без `--open`, `-Pn` |

## Часті помилки
- Зупинитись на `-sC -sV` без `-p-` → пропущений порт = пропущені прапорці.
- Не пересканувати `localhost` зсередини після доступу (`ss -tlnp`).
- Не записати порти в tracker → дубльований скан.
