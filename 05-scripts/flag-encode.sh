#!/usr/bin/env bash
# flag-encode.sh — перетворити знайдений (сирий) флаг у формат для платформи.
#
# На машині флаг лежить із рандомними сепараторами та суфіксом категорії/номера:
#     be-.s-tCT.F--{h1dd3n_r0b0ts}:A3
# На платформу вносимо ЛИШЕ:
#     bestCTF{h1dd3n_r0b0ts}          (букву+номер НЕ включаємо)
# Суфікс :A3 = куди здавати (буква-категорія + номер слота).
#
# ВИКОРИСТАННЯ:
#   bash flag-encode.sh 'be-.s-tCT.F--{h1dd3n}:A3'     # з аргументу
#   bash flags_searcher_obf.sh ... | bash flag-encode.sh   # з піпа (stdin)
#
# ВИВІД (TAB-розділений):
#   bestCTF{h1dd3n}   slot=A3

process() {
  line="$1"
  # тіло {...}
  body=$(printf '%s' "$line" | grep -oE '\{[^}]*\}' | head -n1)
  [ -z "$body" ] && return
  # слот після тіла: }:<буква><номер>
  slot=$(printf '%s' "$line" | grep -oE '\}:[A-Za-z0-9]+' | head -n1 | sed 's/^}://')
  printf 'bestCTF%s\tslot=%s\n' "$body" "${slot:-?}"
}

if [ "$#" -gt 0 ]; then
  for a in "$@"; do process "$a"; done
else
  while IFS= read -r l; do process "$l"; done
fi
