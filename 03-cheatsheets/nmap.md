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

## NSE — ще скрипти
```bash
nmap -p80,443 --script http-methods,http-robots.txt,http-webdav-scan $TARGET  # методи/robots/PUT
nmap -p443 --script ssl-cert,ssl-enum-ciphers $TARGET                   # CN/SAN у сертифікаті (vhosts!), слабкі шифри
nmap -p389 --script ldap-rootdse,ldap-search $TARGET                    # LDAP дерево (анон-bind)
nmap -p53  --script dns-nsid,dns-recursion $TARGET                      # DNS
nmap -p2049 --script nfs-showmount,nfs-ls $TARGET                       # NFS експорти/файли
nmap -p11211 --script memcached-info $TARGET                            # Memcached (unauth)
nmap -p9200 --script http-elasticsearch-head $TARGET                    # Elasticsearch
nmap --script-help http-enum                                           # що робить скрипт (офлайн-довідка)
ls /usr/share/nmap/scripts/ | grep <сервіс>                            # які скрипти є локально
```

## Версія / банер глибше
```bash
nmap -sV --version-intensity 9 -p <port> $TARGET    # максимум зондів для версії
nmap -sV --version-all -p <port> $TARGET            # не зупинятись на першому збігу
nmap -sV --script banner -p <port> $TARGET          # витягнути сирий banner
```

## Таймінг / обхід фільтра (своя ціль)
```bash
nmap -Pn $TARGET                         # host seems down → не пінгувати
nmap --source-port 53 -p- $TARGET        # прикинутись DNS-трафіком (фільтр по src-порту)
nmap -f $TARGET                          # фрагментувати пакети
nmap --scan-delay 100ms $TARGET          # повільніше, якщо скан «гасять»
nmap -sT $TARGET                         # full-connect (без root, надійніше через VPN)
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
