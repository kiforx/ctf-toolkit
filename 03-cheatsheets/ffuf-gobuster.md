# Cheatsheet: FFUF / Gobuster (web fuzzing)

Пошук директорій, файлів, параметрів, vhosts, значень. ← [web-enum](../02-workflows/web-enum.md)

## Gobuster
```bash
gobuster dir -u http://$TARGET -w <wl> -x php,txt,html,bak,zip -t 50   # дир+розширення
gobuster dir -u http://$TARGET -w <wl> -s 200,204,301,302,403 -b ''    # лише ці коди
gobuster dns -d $DOMAIN -w <subs>                                       # піддомени (DNS)
gobuster vhost -u http://$TARGET -w <subs> --append-domain              # vhosts
gobuster dir -u https://$TARGET -k ...                                  # -k ігнорувати SSL
```
`<wl>` = `/usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt`.

## FFUF — базове
```bash
ffuf -u http://$TARGET/FUZZ -w <wl> -mc 200,301,302,403            # директорії
ffuf -u http://$TARGET/FUZZ -w <wl> -e .php,.txt,.bak,.old,.zip    # з розширеннями
ffuf -u http://$TARGET/FUZZ -w <wl> -recursion -recursion-depth 2  # рекурсія у знайдені теки
ffuf -u http://$TARGET/FUZZ -w <wl> -ac                            # авто-калібрування шуму
```

## FFUF — фільтри й матчери (прибрати шум)
| Прапор | Значення |
|---|---|
| `-mc 200,403` | показувати лише ці коди |
| `-fc 404,400` | сховати ці коди |
| `-fs 1234` | сховати за розміром відповіді |
| `-fw 12` | сховати за кількістю слів |
| `-fl 5` | сховати за кількістю рядків |
| `-mr 'regex'` | показати, лише якщо тіло метчить regex |
| `-ac` | авто-калібрування (само визначить шум) |
| `-t 50` | потоки · `-rate 100` обмежити швидкість |
| `-maxtime 120` | обмежити час (с) |

## FFUF — що ще фаззити
```bash
# vhost (фільтр за розміром дефолтної сторінки)
ffuf -u http://$TARGET -H "Host: FUZZ.$DOMAIN" -w <subs> -fs <дефолт>
# імена GET-параметрів
ffuf -u "http://$TARGET/page?FUZZ=1" -w /usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt -fs 0
# значення параметра (напр. LFI / id перебір)
ffuf -u "http://$TARGET/?file=FUZZ" -w /usr/share/seclists/Fuzzing/LFI/LFI-Jhaddix.txt
# POST-дані (напр. логін/пошук)
ffuf -u http://$TARGET/login -X POST -d 'user=admin&pass=FUZZ' \
     -H 'Content-Type: application/x-www-form-urlencoded' -w <passwords> -fc 200
# заголовок / кука
ffuf -u http://$TARGET/ -H 'X-Forwarded-For: FUZZ' -w <ips>
ffuf -u http://$TARGET/ -b 'session=FUZZ' -w <wl>
# дві точки фаззингу (W1/W2)
ffuf -u "http://$TARGET/W1?id=W2" -w dirs.txt:W1 -w nums.txt:W2
# через проксі Burp
ffuf -u http://$TARGET/FUZZ -w <wl> -x http://127.0.0.1:8080
```

## Wordlists (офлайн, SecLists)
- Директорії: `directory-list-2.3-medium.txt`, `raft-medium-directories.txt`
- Файли: `raft-medium-files.txt` · Параметри: `burp-parameter-names.txt`
- Піддомени: `subdomains-top1million-5000.txt` · LFI: `Fuzzing/LFI/LFI-Jhaddix.txt`
→ який список під що: [pre-game-checklist](../00-setup/pre-game-checklist.md#wordlists-перевірка-наявності-та-вибір)

## Читання
- `403` = є, але закрито (варто копнути: інші методи, `/` в кінці, обхід). `301/302` = куди редірект?
- Усі відповіді однакового розміру → `-ac` або `-fs <розмір>`.
- Рекурсія знаходить вкладені теки автоматично — зручно для глибоких шляхів.
