# Cheatsheet: SMB Enumeration (139/445)

Шари, юзери, читабельні файли. ← [service-enum](../02-workflows/service-enum.md)

## Швидкий огляд
```bash
nmap -p139,445 --script smb-os-discovery,smb-enum-shares,smb-enum-users $TARGET
```

## netexec (ex-crackmapexec) — головний інструмент
```bash
netexec smb $TARGET                              # ОС, домен, ім'я
netexec smb $TARGET -u '' -p ''                  # null session
netexec smb $TARGET -u 'guest' -p ''             # guest
netexec smb $TARGET --shares -u '' -p ''         # перелік шар + права
netexec smb $TARGET --users  -u '' -p ''         # юзери
netexec smb $TARGET -u user -p pass              # перевірка кредів
netexec smb $TARGET -u user -p pass --shares     # що читає цей юзер
```
`(nxc` або `crackmapexec` — ті самі команди залежно від версії Kali.)

## smbclient (зайти у шару, качати)
```bash
smbclient -L //$TARGET/ -N                       # список шар, без пароля
smbclient //$TARGET/share -N                     # зайти анонімно
smbclient //$TARGET/share -U user                # з юзером
# у сесії:  ls ; cd dir ; get file ; mget * ; prompt off ; recurse on
# викачати ВСЮ шару рекурсивно одним рухом:
smbclient //$TARGET/share -N -c 'prompt OFF; recurse ON; mget *'
```

## RID brute (юзери, коли enum шар закритий)
```bash
netexec smb $TARGET -u guest -p '' --rid-brute        # перелік через RID
netexec smb $TARGET -u '' -p '' --rid-brute           # спробувати null
```

## smbmap (права доступу)
```bash
smbmap -H $TARGET -u '' -p ''                     # мапа прав (READ/WRITE)
smbmap -H $TARGET -u user -p pass -R share        # рекурсивний лістинг
smbmap -H $TARGET -u user -p pass --download 'share/file'
```

## enum4linux-ng (повний dump)
```bash
enum4linux-ng -A $TARGET                           # юзери, групи, шари, політики
```

## Монтування (зручно для grep)
```bash
sudo mkdir /mnt/s; sudo mount -t cifs //$TARGET/share /mnt/s -o username=user
grep -rEi 'pass|flag|bestCTF' /mnt/s 2>/dev/null
```

## Що шукати
- Шари `READ`: конфіги, скрипти з кредами, бекапи, нотатки, **прапорці**.
- Список юзерів → перевірка паролів на SSH/інших сервісах ([credential-hunting](../02-workflows/credential-hunting.md)).
- Шара з `WRITE` + веб-корінь → webshell.

## Пастки
- `NT_STATUS_ACCESS_DENIED` на null → потрібні креди (шукати деінде).
- Адмінські шари (`C$`, `ADMIN$`) не плутати з користувацькими.
