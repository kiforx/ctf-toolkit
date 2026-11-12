# Scripts

Допоміжні скрипти. Запуск через `bash <script>`.
← [MASTER](../01-roadmaps/MASTER-ROADMAP.md)

| Скрипт | Де запускати | Що робить | Приклад |
|---|---|---|---|
| [flags_searcher_obf.sh](flags_searcher_obf.sh) | на **Linux**-цілі (shell) | пошук прапорців (обфускований) | `bash flags_searcher_obf.sh --key K --directory /` |
| [flags_searcher.ps1](flags_searcher.ps1) | на **Windows**-цілі (PowerShell) | пошук прапорців + нормалізація | `powershell -ep bypass -f flags_searcher.ps1 -Path C:\` |
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

## flags_searcher.ps1 (Windows-ціль)
Пошук прапорців на **Windows** (аналог `flags_searcher_obf.sh` для Linux). Читабельний PowerShell, той самий шумо-стійкий формат; **за замовчуванням одразу нормалізує** у `bestCTF{FLAG}` + слот (не треба тягнути на Kali). Залити на ціль через [file-transfer](../02-workflows/file-transfer.md), далі:
```powershell
powershell -ep bypass -f flags_searcher.ps1                        # за замовч. C:\ , нормалізований вивід
powershell -ep bypass -f flags_searcher.ps1 -Path C:\Users,C:\inetpub
powershell -ep bypass -f flags_searcher.ps1 -ADS -Registry -EventLogs   # повільніші джерела (потоки/реєстр/логи)
powershell -ep bypass -f flags_searcher.ps1 -Raw | Set-Content loot.txt # сирі збіги
```
| Параметр | Значення |
|---|---|
| `-Path <шляхи>` | де шукати (за замовч. `C:\`); кілька через кому |
| `-Raw` | сирі збіги без нормалізації |
| `-ADS` | + альтернативні потоки даних (NTFS, повільніше) |
| `-Registry` | + `HKLM/HKCU:\SOFTWARE` (повільно) |
| `-EventLogs` | + Application/System/PowerShell-Operational |
| `-AllFiles` | читати всі файли, не лише текстові розширення |
| `-MaxFileMB <n>` | пропускати файли > n МБ (за замовч. 20) |

Вивід (нормалізований): `bestCTF{...}  slot=XY  <= джерело`. Дедуплікується. `-ep bypass` обходить ExecutionPolicy (не потребує адмін-прав). Сумісний з Windows PowerShell **5.1+** (дефолт на Windows) і PowerShell 7.
> Перевірено на PowerShell 7.7 (Linux): regex/нормалізація/дедуп/крайові випадки (неправильний регістр і флаг без слота відкидаються). Гілки ADS/Registry/EventLogs — Windows-only, синтаксично валідні, у цьому середовищі не виконувались.
> Крос-лінк: швидкий інлайн-варіант і місця пошуку — [windows/cheatsheet](../windows/cheatsheet.md#пошук-прапорців).

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
bash -n flag-encode.sh quick-recon.sh cred-spray-local.sh   # синтаксис .sh OK?
bash flag-encode.sh 'be-.s-tCT.F--{t3st}:A1'                             # → bestCTF{t3st}  slot=A1
# ps1 (якщо є pwsh на Kali): перевірка синтаксису
pwsh -NoProfile -c "[Management.Automation.Language.Parser]::ParseFile('flags_searcher.ps1',[ref]\$null,[ref]\$null)" && echo "ps1 OK"
```
На Windows-цілі скрипт під'їде готовим (PowerShell 5.1+ вбудований). Готові бінарники (linpeas, pspy64, chisel тощо) — у [tools/](../tools/README.md).
