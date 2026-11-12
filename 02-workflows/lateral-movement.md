# Workflow: Lateral Movement (рух між юзерами/сервісами)

**Для чого:** з одного доступу дотягнутись до інших юзерів і сервісів (де лежать нові прапорці).
**Коли:** є креди/ключ або shell як обмежений юзер.
← [post-exploitation](../01-roadmaps/post-exploitation.md) · [credential-hunting](credential-hunting.md) · [credentials reuse](../04-techniques/credentials-reuse.md)


---

## Крок 1. Хто ще є в системі
```bash
cat /etc/passwd | grep -vE 'nologin|false'      # юзери з shell
ls -la /home                                     # домашні директорії
```

## Крок 2. Способи стати іншим юзером
```bash
# А) той самий пароль (credential reuse)
su <user>                     # знайдений пароль

# Б) SSH-ключ
chmod 600 id_rsa; ssh -i id_rsa <user>@localhost
ssh -i id_rsa <user>@$TARGET

# В) sudo дозволяє запуск від іншого юзера
sudo -l                       # "(user2) NOPASSWD: /path/cmd" → sudo -u user2 /path/cmd

# Г) пароль у history/конфігу → spraying по юзерах
bash cred-spray-local.sh '<pass>'    # скрипт перевірки пароля на локальних юзерах
```

## Крок 3. Внутрішні сервіси (localhost)
```bash
ss -tlnp     # напр. 3306/8080 слухає тільки 127.0.0.1
```
Сервіс недоступний ззовні → пробросити на локальну машину → [pivoting](pivoting-portforward.md), далі enum як звичайний сервіс (зразок `1nt3rnal_ap1_l0calh0st`).

## Крок 4. Після зміни юзера — повтор
```bash
id; sudo -l; cat ~/.bash_history; ls -la ~
bash flags_searcher_obf.sh --key /tmp/.k --directory ~ 2>/dev/null   # flag-hunt у новій домівці (/tmp/.k = ключ)
```
→ [flag-hunting](../01-roadmaps/flag-hunting.md)

## Розгалуження
| Наявне | → |
|---|---|
| Пароль БД | спробувати як системний пароль юзерів (reuse) |
| Ключ `id_rsa` user2 | `ssh -i` → новий доступ → flag-hunt |
| `sudo -u user2 <cmd>` | виконання від user2, читання його файлів |
| Внутрішній сервіс | [pivoting](pivoting-portforward.md) → [service-enum](service-enum.md) |
| Cron від іншого юзера | [cron/services](../04-techniques/cron-services.md) |

## Пастки
- Отримані креди не перевірені на інших юзерах — втрата половини прапорців.
- Забуті сервіси на localhost.
- У tracker — граф «юзер → як отримано → що знайдено».
