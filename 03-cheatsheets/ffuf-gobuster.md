# Cheatsheet: FFUF / Gobuster (web fuzzing)

Пошук директорій, файлів, параметрів, vhosts. ← [web-enum](../02-workflows/web-enum.md)

## Gobuster
```bash
# директорії + розширення
gobuster dir -u http://$TARGET -w /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt -x php,txt,html,bak,zip -t 50
# піддомени (DNS)
gobuster dns -d $DOMAIN -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt
# vhosts
gobuster vhost -u http://$TARGET -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt --append-domain
```

## FFUF (гнучкіший)
```bash
# директорії
ffuf -u http://$TARGET/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt -mc 200,301,302,403
# файли з розширеннями
ffuf -u http://$TARGET/FUZZ -w <wordlist> -e .php,.txt,.bak,.old,.zip
# vhost (фільтр за розміром дефолтної сторінки)
ffuf -u http://$TARGET -H "Host: FUZZ.$DOMAIN" -w <subdomains> -fs 1234
# fuzzing GET-параметра
ffuf -u "http://$TARGET/page?FUZZ=1" -w /usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt -fs 0
# fuzzing значення параметра (напр. LFI)
ffuf -u "http://$TARGET/?file=FUZZ" -w /usr/share/seclists/Fuzzing/LFI/LFI-Jhaddix.txt
```

## Фільтри/матчери (прибрати шум)
| Прапор | Значення |
|---|---|
| `-mc 200,403` | matching codes (показати) |
| `-fc 404` | filter code (сховати) |
| `-fs 1234` | filter за розміром відповіді |
| `-fw 12` | filter за кількістю слів |
| `-ac` | авто-калібрування (сам визначить шум) |
| `-t 50` | потоки |
| `-e .php,.bak` | розширення |

## Wordlists (офлайн, SecLists)
- Директорії: `directory-list-2.3-medium.txt`, `raft-medium-directories.txt`
- Файли: `raft-medium-files.txt`
- Параметри: `burp-parameter-names.txt`
- Піддомени: `subdomains-top1million-5000.txt`

## Читання
`403` = є, але закрито (варто копнути). `301/302` = редірект (куди?). Однаковий розмір у всіх → `-ac`/`-fs`.
