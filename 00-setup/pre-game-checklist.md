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

## 3. Wordlists (критично — качати заздалегідь)
```bash
ls /usr/share/seclists >/dev/null 2>&1 && echo "[+] SecLists" || echo "[-] apt install seclists"
ls /usr/share/wordlists/rockyou.txt* >/dev/null 2>&1 && echo "[+] rockyou" || echo "[-] rockyou"
# розпакувати rockyou, якщо .gz:
# sudo gunzip -k /usr/share/wordlists/rockyou.txt.gz
```
- [ ] P1 **SecLists** (`apt install seclists`) — директорії, параметри, піддомени, LFI
- [ ] P1 **rockyou.txt** розпакований
- [ ] P2 `directory-list-2.3-medium`, `raft-*` під рукою

## 4. Інструменти для заливки на ціль (бінарі офлайн)
В одному каталозі для роздачі через `python3 -m http.server`:
- [ ] P1 `linpeas.sh` — автоenum Linux
- [ ] P1 `pspy64` — процеси/крон без рута
- [ ] P2 `chisel` (linux, потрібна архітектура) — пивотинг
- [ ] P3 `WinPEAS` — якщо можливий Windows
- [ ] P3 GTFOBins офлайн-копія (sudo/SUID зловживання)
> Ці файли залежать від завантаження з інтернету ДО гри. На цілі інтернету немає.

## 6. Фінальна перевірка
- [ ] P1 `sudo wg-quick up ./bestctf26.conf` → `sudo wg show` має `latest handshake`
- [ ] P1 `ip a` → `10.8.N.x`; `ping 10.0.N0.10`
- [ ] P1 Listener-тест: `nc -lvnp 4444` на VPN-адресі, тобто на тій машині де запущений vpn конфіг, для того, щоб reverse shell міг доходити
