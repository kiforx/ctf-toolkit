# Workflow: Network Enumeration

**Для чого:** знайти всі відкриті порти/сервіси та їхні версії.
**Коли:** старт + після кожного доступу (внутрішні порти).
← [recon roadmap](../01-roadmaps/recon.md) · [nmap cheatsheet](../03-cheatsheets/nmap.md)

---

## Крок 1. Ping + швидкий скан
```bash
TARGET=10.0.N0.10
ping -c2 $TARGET                                  # жива?  ні → nmap -Pn
nmap -sC -sV -T4 --open $TARGET -oN nmap-quick.txt
```
`-sC` дефолтні скрипти · `-sV` версії · `--open` лише відкриті · `-oN` зберегти.

## Крок 2. Повний скан портів (обов'язково)
```bash
nmap -p- -T4 --min-rate 2000 --open $TARGET -oN nmap-all.txt
# нові порти → догнати деталі:
nmap -sCV -p 8080,50000 $TARGET -oN nmap-extra.txt
```
**Навіщо:** багато сервісів сидять не на дефолтних портах. Без `-p-` їх не видно.

## Крок 3. UDP (швидко, топ-50)
```bash
sudo nmap -sU --top-ports 50 -T4 $TARGET -oN nmap-udp.txt
```
Цікаве в UDP: 53 DNS, 69 TFTP, 161 SNMP, 123 NTP.

## Інтерпретація виводу
| Поле | На що дивитись |
|---|---|
| `PORT STATE` | `open` — працювати; `filtered` — фаєрвол/VPN, спробувати `-Pn` |
| `SERVICE / VERSION` | точна версія → `searchsploit <продукт версія>` |
| `http-title` | підказка про додаток/CMS |
| скрипт-вивід (`\|`) | nmap уже знайшов anon-FTP, SMB-шари тощо |

## Куди далі
| Порт | → |
|---|---|
| 80/443/8080 | [web-enum](web-enum.md) |
| 21/22/139/445/3306/6379/5432/27017 | [service-enum](service-enum.md) |
| 3389/5985/135 | [windows/](../windows/README.md) ([enum](../windows/01-enumeration.md)) |

## Нотатки в tracker
Кожен порт+сервіс+версія → findings-tracker, щоб уникнути повторного скану.

## Пастки
- `filtered` на все → VPN не піднятий або потрібен `-Pn`.
- Повільно → `--min-rate 2000`; `-T5` на нестабільному VPN дає втрати пакетів і хибні результати.
