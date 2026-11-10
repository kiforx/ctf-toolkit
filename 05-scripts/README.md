# Scripts

Допоміжні скрипти. Усі працюють офлайн (локальна ціль у VPN). Запуск через `bash <script>`.
← [MASTER](../01-roadmaps/MASTER-ROADMAP.md)

| Скрипт | Де запускати | Що робить | Приклад |
|---|---|---|---|
| [flagscan.sh](flagscan.sh) | на цілі (у shell) | пошук прапорців за форматом, дедуп, фільтри | `bash flagscan.sh --key=KEY /` |
| [quick-recon.sh](quick-recon.sh) | на Kali | швидкий + повний nmap-скан | `bash quick-recon.sh 10.0.N0.10` |
| [cred-spray-local.sh](cred-spray-local.sh) | на цілі (у shell) | перевірка 1 пароля по локальних юзерах | `bash cred-spray-local.sh 'Pass123'` |

## flagscan.sh — детальніше
Автор — тімейт. Перевірено: ловить усі відомі зразки прапорців (сепаратори `-` `_` `.`, зокрема кратні й відсутні), дедуплікує, пропускає бінарні файли.

```bash
bash flagscan.sh --key=KEY DIRECTORY        # усі знайдені прапорці
bash flagscan.sh --key=KEY --include=1,5,7 /    # лише номери 1,5,7
bash flagscan.sh --key=KEY --exclude=2 /        # крім номера 2 (exclude виграє)
bash flagscan.sh --key=KEY --output=flags.txt / # у файл (0600)
bash flagscan.sh --help                          # довідка
```
- `--key` обов'язковий: у скрипті змінна `EXPECTED_KEY` (замінити плейсхолдер на реальний ключ перед грою).
- Коди виходу: `0` є прапорці · `1` нема / неправильний ключ · `2` помилка використання/вводу.
- Формат прапорця: `b`+`e`+`s`+`t`+`C`+`T`+`F` з шумом `[-_.]*`, тіло `{[[:alnum:]_]+}`, хвіст `:N`.
- Інший формат на основному етапі → змінити `FLAG_REGEX`/`NOISE` у скрипті.

### Швидкий keyless-варіант (без скрипта)
```bash
grep -raoHE 'b[-_.]*e[-_.]*s[-_.]*t[-_.]*C[-_.]*T[-_.]*F[-_.]*\{[[:alnum:]_]+\}:[0-9]+' / 2>/dev/null | sort -u
```

## Перевірка перед грою
```bash
bash -n flagscan.sh quick-recon.sh cred-spray-local.sh    # синтаксис OK?
printf 'be_s_t_CTF-_{t3st}:1\n' > /tmp/t && bash flagscan.sh --key=KEY /tmp   # має знайти (з реальним ключем)
```

## Зовнішні інструменти (НЕ в репо — завантажити заздалегідь)
`linpeas.sh`, `pspy64`, `chisel` — залежать від завантаження до гри, див. [pre-game-checklist](../00-setup/pre-game-checklist.md).
