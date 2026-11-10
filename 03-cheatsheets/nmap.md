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
nmap -p21  --script ftp-anon $TARGET                                   # анонімний FTP
nmap -p445 --script smb-enum-shares,smb-enum-users,smb-os-discovery $TARGET  # SMB шари/юзери
nmap -p445 --script smb-vuln* $TARGET                                   # відомі SMB CVE
nmap -p80,443 --script http-enum,http-title,http-headers $TARGET        # веб-огляд
nmap -p80 --script http-shellshock --script-args uri=/cgi-bin/x $TARGET # shellshock
nmap -p3306 --script mysql-empty-password,mysql-info $TARGET            # MySQL дефолт
nmap -p6379 --script redis-info $TARGET                                  # Redis
nmap -p25  --script smtp-enum-users,smtp-commands $TARGET               # SMTP юзери
nmap -sU -p161 --script snmp-info,snmp-brute $TARGET                     # SNMP
nmap --script vuln $TARGET          # усі відомі вразливості (повільно)
```

## Корисні one-liner-и
```bash
nmap -p- --min-rate 5000 -T4 $TARGET -oG - | grep '/open/'   # усі порти, grep-friendly
nmap -sn 10.0.N0.0/24                                        # хто живий у підмережі (якщо дозволено)
nmap -Pn -n -p- -oA scan $TARGET                             # без DNS, усі формати (scan.*)
```

## Читання виводу
- `open` — робочий; `filtered` — фаєрвол/VPN → `-Pn`; `closed` — нема сервісу.
- Версія → `searchsploit <продукт версія>`.
- `-oG`/`-oA` зручні, щоб швидко витягти порти в нотатник або згодувати іншим тулам.

## Пастка
Найчастіша помилка — відсутній `-p-`. Сервіс на 8080/50000 без нього невидимий.
