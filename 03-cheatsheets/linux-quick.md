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

## Якщо команда відсутня
- Нема `ss` → `netstat`; нема `sudo` → `doas`; нема `python3` → `python`.
- Обмежений shell (rbash)? → `bash -i`, `python pty`, vi `:!/bin/bash`.

→ детальні механізми: [perms/SUID/cap](../04-techniques/linux-perms-suid-cap.md), [cron/services](../04-techniques/cron-services.md)
