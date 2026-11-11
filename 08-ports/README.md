# Довідник портів (поширені + незвичні)

**Навіщо:** швидко зорієнтуватись, що за сервіс на знайденому порту й з чого почати, коли банер неочевидний або порт нетиповий.
**Коли відкривати:** nmap/`nc` показав порт, якого немає у звичних гілках [recon](../01-roadmaps/recon.md). Приклад: на змаганні траплявся `31337` — тут за секунду видно, що це зазвичай кастомний сервіс і куди копати.
← [recon](../01-roadmaps/recon.md) · [service-enum](../02-workflows/service-enum.md) · [nmap](../03-cheatsheets/nmap.md)

> Правило: **жоден порт не ігнорувати** — кожен це потенційний вхід або прапорець.

---

## Алгоритм для невідомого порту
```bash
P=31337; TARGET=10.0.N0.10
nmap -sCV -p $P $TARGET                 # версія + дефолтні скрипти
nc -nv $TARGET $P                       # banner; інколи треба надіслати \n або 'help'
curl -sv http://$TARGET:$P/             # раптом HTTP → web-enum
openssl s_client -connect $TARGET:$P    # раптом TLS-обгортка
# є назва/версія → офлайн-пошук експлойтів:
searchsploit <продукт версія>
```
Банер «говорить» → у [service-enum](../02-workflows/service-enum.md); відповідає HTTP → [web-enum](../01-roadmaps/web-enum.md); мовчить → надіслати `help`/`version`/`\n`, глянути на поведінку.

---

## Поширені порти (швидкий довідник)
| Порт | Сервіс | З чого почати | Деталі |
|---|---|---|---|
| 21 | FTP | anon-логін, завантажити конфіги/бекапи | [service-enum: FTP](../02-workflows/service-enum.md#ftp) |
| 22 | SSH | без кредів глухо; повернутись з ключами/паролями | [service-enum](../02-workflows/service-enum.md) |
| 23 | Telnet | `nc`/`telnet`; дефолтні креди, відкритий shell | банер |
| 25/465/587 | SMTP | `VRFY`/`EXPN` юзери, відкритий relay | [service-enum: SMTP](../02-workflows/service-enum.md) |
| 53 | DNS | zone transfer `dig axfr @$TARGET domain` | [нижче: DNS](#53) |
| 80/443/8080/8000 | HTTP(S) | головний веб-вектор | [web-enum](../01-roadmaps/web-enum.md) |
| 110/143 | POP3/IMAP | читати пошту з кредами | [service-enum: SMTP/POP3](../02-workflows/service-enum.md) |
| 111 | rpcbind | `rpcinfo -p` → часто NFS (2049) | [нижче: NFS](#2049) |
| 139/445 | SMB | null-session, шари, юзери | [smb-enum](../03-cheatsheets/smb-enum.md) |
| 161/udp | SNMP | community `public` → конфіги/процеси/паролі | [service-enum: SNMP](../02-workflows/service-enum.md) |
| 1433 | MSSQL | `sa` + слабкий пароль → `xp_cmdshell` | [databases: MSSQL](../03-cheatsheets/databases.md) |
| 2049 | NFS | `showmount -e`, `no_root_squash` → root | [service-enum: NFS](../02-workflows/service-enum.md) |
| 3306 | MySQL | `root:` порожній/слабкий; `LOAD_FILE`/outfile | [databases: MySQL](../03-cheatsheets/databases.md) |
| 3389 | RDP | Windows → enum/креди | [windows-enum](../06-windows/windows-enum.md) |
| 5432 | PostgreSQL | `postgres:postgres`; `COPY ... TO PROGRAM` RCE | [databases: PostgreSQL](../03-cheatsheets/databases.md) |
| 5985/5986 | WinRM | креди → `evil-winrm` (shell) | [windows-enum](../06-windows/windows-enum.md) |
| 6379 | Redis | часто без автентифікації → webshell/SSH-ключ | [databases: Redis](../03-cheatsheets/databases.md#redis) |
| 27017 | MongoDB | часто без автентифікації → дамп колекцій | [databases: MongoDB](../03-cheatsheets/databases.md) |

---

## Рідші сервіси (знати в обличчя)
| Порт | Сервіс | З чого почати / у чому суть |
|---|---|---|
| 69/udp | TFTP | `tftp $TARGET` → get/put без автентифікації |
| 79 | Finger | `finger @$TARGET`; `user-enum` через finger |
| 389/636 | LDAP | `ldapsearch -x -H ldap://$TARGET -b '' -s base`; анон-bind → дерево юзерів/паролі |
| 512/513/514 | r-services | `rsh`/`rlogin`; `.rhosts` → вхід без пароля |
| 623/udp | IPMI | дамп хешів BMC → крек офлайн |
| 873 | rsync | `rsync rsync://$TARGET/` → лістинг модулів, викачати файли |
| 1099 | Java RMI | десеріалізація → RCE (ysoserial); обережно |
| 1521 | Oracle TNS | `odat` all; SID-brute локально, дефолтні креди |
| 2181 | Zookeeper | `echo envi | nc $TARGET 2181`; `dump`/`cons` — витік конфігів |
| 3000 | Grafana/Node | Grafana ≤8 LFI (CVE-2021-43798); інакше web-enum |
| 5000 | Flask/Registry | Flask debug PIN RCE; Docker Registry `/v2/_catalog` |
| 5601 | Kibana | версія → CVE (prototype pollution RCE); проксі до Elastic |
| 5900 | VNC | без пароля/слабкий → перегляд екрана, дефолтні креди |
| 9042 | Cassandra | `cqlsh $TARGET`; дефолт `cassandra:cassandra` |
| 9000 | PHP-FPM/App | FastCGI RCE; або SonarQube/Portainer — web-enum |
| 10000 | Webmin | версія → RCE CVE (1.890/1.920); дефолтні креди |
| 15672 | RabbitMQ | mgmt UI `guest:guest` → черги, конфіги |
| 50070 | Hadoop HDFS | web UI → перегляд/запис у HDFS, інколи RCE |
| 61616 | ActiveMQ | CVE-2023-46604 RCE; `/admin` `admin:admin` |

---

## Незвичні / високі / CTF-специфічні
| Порт | Ймовірно | З чого почати |
|---|---|---|
| 1337 / 31337 / 12345 | кастомний сервіс («leet»), саморобний бінар | `nc` banner, надіслати `help`/`\n`; версія → `searchsploit` |
| 4444 / 4445 / 1234 | чужий/залишковий listener, metasploit default | `nc` — раптом відкритий shell; не плутати зі своїм listener |
| 5555 | Android ADB | `adb connect $TARGET:5555` → `adb shell` |
| 6667 / 6697 | IRC | `nc`; інколи бот/C2-стиль, канали з підказками |
| 8009 | AJP (Tomcat) | Ghostcat CVE-2020-1938 → читання `WEB-INF` файлів |
| 8443 / 8834 | alt-HTTPS / Nessus | `curl -k https://$TARGET:PORT/` → web-enum |
| 8888 / 9001 | Jupyter / proxy / supervisor | Jupyter без токена → термінал = RCE |
| 9200 / 9300 | Elasticsearch | `curl $TARGET:9200/_cat/indices`, `/_search` → дамп даних |
| 11211 | Memcached | `stats`, `stats items`, `get <key>` через `nc` (unauth) |
| 2375 / 2376 | Docker API (unauth) | `docker -H tcp://$TARGET:2375 ps`; запустити привіл. контейнер → mount host → root |
| 50000 | SAP / DB2 / кастом | banner → `searchsploit`; інколи просто веб |

> Кастомний бінар/саморобний сервіс (1337/31337 тощо) → витягти з FTP/SMB/веб і глянути: [reversing](../03-cheatsheets/reversing.md).
> Memcached-приклад: `printf 'stats items\r\n' | nc -q1 $TARGET 11211` → перелік слабів → `stats cachedump <slab> 0` → `get <key>`.
> Docker-API-приклад (unauth 2375) → контейнер-escape до host: [containers](../04-techniques/containers.md).

---

## Куди далі
- Банер/версія знайдені → `searchsploit <продукт версія>` (offline exploit-db) → PoC.
- HTTP на будь-якому порту → [web-enum](../01-roadmaps/web-enum.md).
- Отримані креди/ключі → перевірити деінде: [credentials-reuse](../04-techniques/credentials-reuse.md).
- Сервіс лише на `127.0.0.1` (видно після доступу) → [pivoting/port-forward](../02-workflows/pivoting-portforward.md).

<a id="53"></a>
### DNS (53)
```bash
dig axfr @$TARGET internal.ctf           # zone transfer — вивалює всі записи/піддомени
nslookup; server $TARGET                 # інтерактивно
dig any @$TARGET $TARGET                  # усі записи
```
Знайдені піддомени/vhost → додати у `/etc/hosts` → [web-enum](../01-roadmaps/web-enum.md).

<a id="2049"></a>
### NFS (2049) / rpcbind (111)
```bash
rpcinfo -p $TARGET                        # які RPC-сервіси (чи є nfs)
showmount -e $TARGET                      # експортовані шари
```
Повний сценарій монтування й `no_root_squash` → root: [service-enum: NFS](../02-workflows/service-enum.md).
