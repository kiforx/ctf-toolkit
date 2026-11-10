#!/usr/bin/env bash
# quick-recon.sh — стартова розвідка цілі: швидкий скан + повний скан портів у фоні.
#
# Приклад запуску:
#   bash quick-recon.sh 10.0.N0.10
#
# Очікуваний результат:
#   nmap-quick.txt  — швидкий -sC -sV (можна працювати одразу)
#   nmap-all.txt    — повний -p- (дописується у фоні)
# Залежність: nmap. Інтернет не потрібен (локальна ціль у VPN).

set -u
TARGET="${1:?Приклад: bash quick-recon.sh 10.0.N0.10}"
OUT="recon-${TARGET}"
mkdir -p "$OUT"; cd "$OUT" || exit 1

echo "[*] Ціль: $TARGET  (вивід у $(pwd))"
ping -c2 -W2 "$TARGET" >/dev/null 2>&1 && echo "[+] ping OK" || echo "[!] ping fail -> nmap -Pn"

echo "[*] Повний скан портів у ФОНІ -> nmap-all.txt"
nmap -p- -T4 --min-rate 2000 --open "$TARGET" -oN nmap-all.txt >/dev/null 2>&1 &
ALL_PID=$!

echo "[*] Швидкий скан -> nmap-quick.txt"
nmap -sC -sV -T4 --open "$TARGET" -oN nmap-quick.txt
echo "----- QUICK -----"; grep -E '^[0-9]+/' nmap-quick.txt

echo "[*] Очікування повного скану (PID $ALL_PID)..."
wait $ALL_PID
echo "----- ALL PORTS -----"; grep -E '^[0-9]+/' nmap-all.txt

echo
echo "[*] Нові порти (у all, яких нема у quick) — догнати версії вручну:"
comm -23 <(grep -oE '^[0-9]+' nmap-all.txt | sort -u) \
         <(grep -oE '^[0-9]+' nmap-quick.txt | sort -u) 2>/dev/null
echo "[*] Далі: 01-roadmaps/MASTER-ROADMAP.md (розгалуження за портами)."
