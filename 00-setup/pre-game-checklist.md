# Setup: Pre-Game Checklist (офлайн-підготовка)

**Для чого:** на цілі немає інтернету, AI заборонений — усе потрібне має бути завантажено й перевірено до гри.
← [vpn](vpn-wireguard.md) · [scripts](../05-scripts/) · [MASTER](../01-roadmaps/MASTER-ROADMAP.md)

> Пріоритет: P1 критично · P2 бажано · P3 за наявності місця/часу.

---

## 1. Робоче середовище
- [ ] P1 Kali з інструментами (краще у **віртуалці**, де й VPN — див. [vpn](vpn-wireguard.md))
- [ ] P1 WireGuard встановлено й перевірено
- [ ] P2 Запасний інтернет (хотспот) — для власних девайсів, НЕ для цілі
- [ ] P1 Цей репозиторій локально, перевірена навігація

## 2. Інструменти (перевірка наявності)
```bash
for t in nmap ffuf gobuster curl wget nc socat sqlmap nikto whatweb \
         smbclient smbmap enum4linux-ng netexec hydra john searchsploit \
         python3 git evil-winrm xfreerdp proxychains; do
  command -v "$t" >/dev/null && echo "[+] $t" || echo "[-] $t ВІДСУТНІЙ"; done
```
| Інструмент | Призначення | Пріоритет |
|---|---|---|
| nmap | скан портів/сервісів | P1 |
| ffuf/gobuster | веб-фаззинг | P1 |
| curl/wget | HTTP вручну, передача файлів | P1 |
| nc/socat | listener, revshell, передача | P1 |
| sqlmap | SQLi | P1 |
| netexec/smbclient/smbmap/enum4linux-ng | SMB | P1 |
| nikto/whatweb | веб-відбиток | P2 |
| searchsploit (exploit-db) | офлайн-експлойти | P1 |
| john/hashcat | крек хешів | P2 |
| evil-winrm/xfreerdp | Windows-доступ | P2 |
| chisel/proxychains | пивотинг | P2 |

## 3. Wordlists (перевірка наявності та вибір) <a id="wordlists-перевірка-наявності-та-вибір"></a>
Wordlists у репо не кладемо (завеликі) — вони стандартно є в Kali. Перед грою переконатися, що на місці:
```bash
ls /usr/share/seclists >/dev/null 2>&1 && echo "[+] SecLists" || echo "[-] sudo apt install seclists"
ls /usr/share/wordlists/rockyou.txt   >/dev/null 2>&1 && echo "[+] rockyou" || \
  (ls /usr/share/wordlists/rockyou.txt.gz >/dev/null 2>&1 && echo "[!] rockyou.gz — розпакувати: sudo gunzip -k /usr/share/wordlists/rockyou.txt.gz" || echo "[-] rockyou відсутній")
```
- [ ] P1 **SecLists** у `/usr/share/seclists`
- [ ] P1 **rockyou.txt** розпакований у `/usr/share/wordlists/`

### Який список під яку задачу
| Задача | Список | Шлях |
|---|---|---|
| Директорії (веб) | `directory-list-2.3-medium.txt` | `/usr/share/seclists/Discovery/Web-Content/` |
| Файли + розширення | `raft-medium-files.txt` | `/usr/share/seclists/Discovery/Web-Content/` |
| Піддомени / vhost | `subdomains-top1million-5000.txt` | `/usr/share/seclists/Discovery/DNS/` |
| Імена параметрів | `burp-parameter-names.txt` | `/usr/share/seclists/Discovery/Web-Content/` |
| LFI | `LFI-Jhaddix.txt` | `/usr/share/seclists/Fuzzing/LFI/` |
| Паролі — швидко | `10k-most-common.txt`, `best1050.txt` | `/usr/share/seclists/Passwords/Common-Credentials/` |
| Паролі — повний крек | `rockyou.txt` | `/usr/share/wordlists/rockyou.txt` |

Правило: спершу короткі списки (швидко), повний `rockyou` — лише коли без нього не обійтись. Приклади використання — у [ffuf/gobuster](../03-cheatsheets/ffuf-gobuster.md) та [sqlmap/SQLi](../03-cheatsheets/sqlmap-sqli.md).

## 4. Тули для заливки на ціль (уже в репо: [tools/](../tools/README.md))
Бінарники й скрипти вже лежать у репо — завантажувати з інтернету не треба. Перевірити наявність і роздати:
```bash
ls -la tools/linux tools/windows tools/webshells   # на місці?
cd tools/linux && python3 -m http.server 8000        # роздача на ціль
```
- [ ] P1 `tools/linux/linpeas.sh`, `pspy64` — enum Linux / процеси без рута
- [ ] P1 `tools/linux/chisel` (або `ligolo-agent`) — пивотинг
- [ ] P1 `tools/linux/socat`, `ncat` — shell/передача, якщо на цілі бракує
- [ ] P2 `tools/windows/*` — якщо можливий Windows
- [ ] P3 GTFOBins офлайн-копія (sudo/SUID зловживання) — за бажанням
> Linux-бінарники — amd64 (ELF x86-64). Під іншу архітектуру цілі знадобиться відповідний білд.

## 6. Фінальна перевірка
- [ ] P1 `sudo wg-quick up ./bestctf26.conf` → `sudo wg show` має `latest handshake`
- [ ] P1 `ip a` → `10.8.N.x`; `ping 10.0.N0.10`
- [ ] P1 Listener-тест: `nc -lvnp 4444` на VPN-адресі, тобто на тій машині де запущений vpn конфіг, для того, щоб reverse shell міг доходити
