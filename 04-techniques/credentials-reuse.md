# Technique: Credentials & Reuse

**Навіщо:** у цьому CTF (root не потрібен, багато пост-експлойту) перевикористання знайдених кредів — головний двигун прогресу. Один пароль часто відкриває кількох юзерів/сервісів і кілька прапорців.
← [credential-hunting](../02-workflows/credential-hunting.md) · [lateral-movement](../02-workflows/lateral-movement.md)

---

## Принцип
Люди (і вразливі конфіги) повторюють паролі. Один знайдений секрет → **систематична** перевірка всюди, перш ніж шукати новий вектор.

## Матриця перевірки (знайдений пароль/ключ → перевірити)
| Сервіс | Команда |
|---|---|
| Інший системний юзер | `su <user>` (той самий пароль) |
| SSH | `ssh <user>@$TARGET` · `ssh -i key <user>@$TARGET` |
| MySQL/Postgres | `mysql -u <user> -p` · `psql -U <user>` |
| SMB | `netexec smb $TARGET -u <user> -p '<pass>'` |
| Веб-панель | форма логіну / basic-auth |
| Redis/Mongo | `-a <pass>` / auth |

```bash
# швидкий spray знайденого пароля по локальних юзерах (акуратно, не брут!)
for u in $(cut -d: -f1 /etc/passwd); do echo "=== $u ==="; echo '<PASS>' | su - "$u" -c id 2>/dev/null; done
```

## Де креди живуть
- Конфіги додатків: `config.php`, `.env`, `wp-config.php`, `settings.py`, `tomcat-users.xml`
- Історії: `.bash_history`, `.mysql_history`, `.psql_history`
- Ключі: `~/.ssh/id_rsa`, `authorized_keys`
- Дампи/бекапи БД: `*.sql`, `/var/backups`
- Env процесів: `/proc/<pid>/environ`
→ повний список: [credential-hunting](../02-workflows/credential-hunting.md)

## Типи та що з ними робити
| Знахідка | Дія |
|---|---|
| plaintext пароль | reuse по матриці вище |
| `id_rsa` без пароля | `chmod 600 id_rsa; ssh -i` |
| `id_rsa` з паролем | `ssh2john id_rsa > h; john h` (лише якщо швидко) |
| хеш `$6$/$1$/$y$` | `john`/`hashcat` офлайн, але спершу plaintext поруч |
| токен/API-ключ | у заголовок `Authorization`, у відповідний сервіс |

## Пастки
- Пароль БД не перевірений як системний пароль юзера — класична втрата доступу.
- Не зафіксовано «де спрацював» → плутанина в команді.
- Таблиця `секрет → джерело → де підійшов` у tracker.
- Крек хешів з rockyou — лише якщо швидко; не марнувати годину, якщо plaintext поруч.
