# Cheatsheet: Nmap

Швидка розвідка портів/сервісів. ← [network-enum](../02-workflows/network-enum.md)

```bash
TARGET=10.0.N0.10
```

## Основне
```bash
nmap -sC -sV -T4 --open $TARGET -oN quick.txt     # скрипти+версії, старт
nmap -p- -T4 --min-rate 2000 --open $TARGET -oN all.txt   # ВСІ 65535 портів
nmap -sCV -p 22,80,445 $TARGET                    # деталі по конкретних
sudo nmap -sU --top-ports 50 $TARGET              # UDP топ-50
nmap -Pn $TARGET                                  # не пінгувати (ціль «мертва»)
```

## Корисні прапорці
| Прапорець | Значення |
|---|---|
| `-sC` | дефолтні NSE-скрипти |
| `-sV` | версія сервісу |
| `-p-` | усі порти (інакше тільки топ-1000) |
| `-A` | агресивно (OS+версії+скрипти+traceroute) |
| `--min-rate 2000` | пакетів/с — швидше |
| `-T4` | таймінг (на VPN не `-T5`) |
| `-Pn` | пропустити ping |
| `-oN / -oA` | зберегти (normal / усі формати) |
| `--open` | показувати лише відкриті |

## NSE-скрипти (цільові)
```bash
nmap -p21 --script ftp-anon $TARGET
nmap -p445 --script smb-enum-shares,smb-enum-users,smb-os-discovery $TARGET
nmap -p80 --script http-enum,http-title $TARGET
nmap --script vuln $TARGET          # відомі вразливості (повільно)
```

## Читання виводу
- `open` — робочий; `filtered` — фаєрвол/VPN → `-Pn`; `closed` — нема сервісу.
- Версія → `searchsploit <продукт версія>`.

## Пастка
Найчастіша помилка — відсутній `-p-`. Сервіс на 8080/50000 без нього невидимий.
