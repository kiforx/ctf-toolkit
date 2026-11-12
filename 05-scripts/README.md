# Scripts

Допоміжні скрипти. Запуск через `bash <script>`.
← [MASTER](../01-roadmaps/MASTER-ROADMAP.md)

| Скрипт | Де запускати | Що робить | Приклад |
|---|---|---|---|
| [flags_searcher_obf.sh](flags_searcher_obf.sh) | на цілі (у shell) | пошук прапорців (обфускований) | `bash flags_searcher_obf.sh --key K --directory /` |
| [flag-encode.sh](flag-encode.sh) | будь-де | сире → `bestCTF{FLAG}` + слот | `bash flag-encode.sh 'be-.s-tCT.F--{x}:A3'` |
| [quick-recon.sh](quick-recon.sh) | на Kali | швидкий + повний nmap-скан | `bash quick-recon.sh 10.0.N0.10` |
| [cred-spray-local.sh](cred-spray-local.sh) | на цілі (у shell) | перевірка 1 пароля по локальних юзерах | `bash cred-spray-local.sh 'Pass123'` |

## flags_searcher_obf.sh (основний) — `flagsearch 2.0`
Обфускований шукач прапорців (всередині: `find` + `grep -E`). **Код навмисно обфускований — не редагувати.**
Перевірено на ізольованій машині: безпечний (лише `find/grep/mktemp/tr/printf`, без мережі/персистенції/деструктиву) і повністю робочий.

**Опції (тільки форма з ПРОБІЛОМ — `--opt=val` у цьому білді зламана):**
| Опція | Значення |
|---|---|
| `--key ФАЙЛ` | **обов'язково.** Файл із access-ключем. Ключ: `S@mEvEryC0olk3Y1414$` |
| `--directory ДИР` | **обов'язково.** Де рекурсивно шукати |
| `--include 1,2,3` | лише прапорці з цими номерами |
| `--exclude 7` | крім цих номерів |
| `--output ФАЙЛ` | дописати у файл (режим 0600) замість stdout |
| `--help` / `--version` | довідка / версія |

```bash
# 1) ключ у файл (один раз):
printf '%s' 'S@mEvEryC0olk3Y1414$' > /tmp/.k
# 2) пошук:
bash flags_searcher_obf.sh --key /tmp/.k --directory /
# 3) одразу у формат платформи:
bash flags_searcher_obf.sh --key /tmp/.k --directory / | bash flag-encode.sh   # → bestCTF{FLAG}  slot=A3
```
Вивід: `ФАЙЛ: сирий_флаг`. Дедуплікується. Коди виходу: `0` знайдено · `1` нема / невірний чи відсутній ключ · `2` помилка.

## flag-encode.sh (здача)
Нормалізує знайдений флаг у формат платформи:
```
вхід:  be-.s-tCT.F--{h1dd3n}:A3     (на машині, з сепараторами та суфіксом)
вихід: bestCTF{h1dd3n}   slot=A3    (на платформу — лише bestCTF{FLAG}; slot = куди здавати)
```
```bash
bash flag-encode.sh 'be-.s-tCT.F--{h1dd3n}:A3'     # з аргументу
<searcher> | bash flag-encode.sh                    # з піпа
```

## Fallback без скрипта (keyless grep)
Якщо `flags_searcher_obf.sh` не піде на цілі — той самий пошук за форматом, без ключа й без скрипта:
```bash
grep -raoHE 'b[-_.]*e[-_.]*s[-_.]*t[-_.]*C[-_.]*T[-_.]*F[-_.]*\{[[:alnum:]_]+\}:[A-Za-z0-9]+' / 2>/dev/null | sort -u
```

## Формат прапорця
`best`+`CTF` із шумом `[-_.]`, тіло `{...}`, суфікс `:<буква-категорія><номер>` (напр. `:A3`).
На платформу — лише `bestCTF{FLAG}`. Деталі: [flag-hunting](../01-roadmaps/flag-hunting.md).

## Перевірка перед грою
```bash
bash -n flag-encode.sh quick-recon.sh cred-spray-local.sh   # синтаксис OK?
bash flag-encode.sh 'be-.s-tCT.F--{t3st}:A1'                             # → bestCTF{t3st}  slot=A1
```
Готові бінарники (linpeas, pspy64, chisel тощо) — у [tools/](../tools/README.md).
