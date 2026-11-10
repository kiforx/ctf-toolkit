# Cheatsheet: Linux Quick Reference

Базові команди для орієнтації на цілі (shell). ← [post-exploitation](../01-roadmaps/post-exploitation.md)

## Хто я / де я
```bash
id; whoami; hostname; pwd
uname -a; cat /etc/os-release           # ядро/дистрибутив
w; who; last                            # хто ще в системі
```

## Користувачі / доступ
```bash
cat /etc/passwd | grep -vE 'nologin|false'   # юзери з shell
ls -la /home /root 2>/dev/null
sudo -l                                       # що можу від root/інших
cat /etc/group
```

## Файлова система
```bash
ls -la            # приховані файли (крапка!)
ls -la /opt /srv /var/www 2>/dev/null
cat /etc/fstab; mount                         # змонтовані/NFS
df -h                                          # диски/розділи
find / -writable -type d 2>/dev/null | head
```

## Процеси / сервіси / мережа
```bash
ps aux                                         # хто що запустив
ps aux | grep -vE '\[' | grep root             # root-процеси (вектор)
ss -tlnp; netstat -tlnp 2>/dev/null            # слухаючі порти (localhost!)
systemctl list-units --type=service 2>/dev/null
crontab -l; cat /etc/crontab; ls -la /etc/cron.*
```

## Швидкий огляд цінного
```bash
cat ~/.bash_history
env
ls -la ~/.ssh 2>/dev/null
cat /var/mail/* 2>/dev/null
```

## Навігація по файлах
```bash
cat file; less file; head -20 file; tail -20 file
grep -i pass file
find / -name '*.conf' 2>/dev/null
strings binary | grep -i pass                  # рядки в бінарнику
base64 -d <<< 'aWQ='                           # декод
```

## Швидкі вектори (quick wins) — прогнати одразу
```bash
sudo -l 2>/dev/null                               # дозволені команди → escape
find / -perm -4000 -type f 2>/dev/null            # SUID
getcap -r / 2>/dev/null                           # capabilities
find / -writable -type f 2>/dev/null | grep -vE '^/proc|^/sys'   # файли з записом
find / -writable -type d 2>/dev/null | grep -vE '^/proc|^/tmp'   # теки з записом
cat /etc/crontab; ls -la /etc/cron.*              # cron (+ pspy64 без рута)
# креди у файлах
grep -rEi 'passw|secret|api[_-]?key|token|DB_' /var/www /opt /etc 2>/dev/null | grep -v Binary
find / \( -name '.env' -o -name 'config.php' -o -name 'wp-config.php' -o -name '*.bak' -o -name 'id_rsa' \) 2>/dev/null
cat /home/*/.bash_history ~/.*_history 2>/dev/null
ss -tlnp 2>/dev/null                              # внутрішні сервіси → pivoting
```
Інтерпретація знахідок: [perms/SUID/cap](../04-techniques/linux-perms-suid-cap.md) (escape-таблиця), [cron/services](../04-techniques/cron-services.md), [credentials](../04-techniques/credentials-reuse.md).

## Якщо команда відсутня
- Нема `ss` → `netstat`; нема `sudo` → `doas`; нема `python3` → `python`.
- Обмежений shell (rbash)? → `bash -i`, `python pty`, vi `:!/bin/bash`.

→ детальні механізми: [perms/SUID/cap](../04-techniques/linux-perms-suid-cap.md), [cron/services](../04-techniques/cron-services.md)
