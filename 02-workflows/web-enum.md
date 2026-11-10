# Workflow: Web Enumeration

**Для чого:** знайти на вебсайті точку входу (файл/команда/креди).
**Коли:** відкритий HTTP(S).
← [web-enum roadmap](../01-roadmaps/web-enum.md) · [ffuf](../03-cheatsheets/ffuf-gobuster.md) · [curl](../03-cheatsheets/curl.md)

---

## Крок 1. Відбиток
```bash
whatweb http://$TARGET
curl -sI http://$TARGET            # заголовки: Server, X-Powered-By, Set-Cookie, redirects
```
Шукати: CMS/фреймворк, версію, мову (PHP/Python/Node), нестандартні заголовки.

## Крок 2. Перегляд + сорс
- Сайт у браузері: функціонал (login, upload, пошук, параметри в URL).
- **View Source / DevTools**: HTML-коментарі, приховані `input`, JS із ендпоінтами й ключами.
- `curl -s http://$TARGET/robots.txt`, `/sitemap.xml`, `/.git/`, `/backup/`.

## Крок 3. Директорії та файли
```bash
gobuster dir -u http://$TARGET -w /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt -x php,txt,html,bak,zip -t 50
ffuf -u http://$TARGET/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt -e .php,.txt,.bak,.old,.zip -mc 200,301,302,403
```
Коди: `200` є · `301/302` редірект (куди?) · `403` існує, але закрите (варто копнути).

## Крок 4. Vhosts / піддомени (за наявності імені хоста)
```bash
ffuf -u http://$TARGET -H "Host: FUZZ.$DOMAIN" -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -fs <розмір-дефолт>
```
Ім'я додати в `/etc/hosts` (`<TARGET> site.local`).

## <a id="git-dump"></a>Крок 5. Git/бекап витік
```bash
wget -r http://$TARGET/.git/ 2>/dev/null   # або git-dumper офлайн
grep -rEi 'pass|secret|key|token' .         # у завантажених сорсах
```
`.bak`, `.old`, `index.php~`, `config.php.save` — читати через браузер/curl.

## Інтерпретація → техніка
| Знайдено | → |
|---|---|
| `?file=`,`?page=`,`?path=` | [LFI/traversal](../03-cheatsheets/lfi-traversal.md) |
| `?cmd=`, ping/dns-форма | [command-injection](../03-cheatsheets/command-injection.md) |
| login-форма | default creds → [SQLi](../03-cheatsheets/sqlmap-sqli.md) |
| upload | [webshells](../03-cheatsheets/webshells-revshells.md) |
| `?url=`,`?next=` | SSRF → [web-vulns](../04-techniques/web-vulns-overview.md#ssrf) |
| CMS+версія | `searchsploit`, вразливі плагіни |

## Пастки
- `403` і дивні параметри не ігнорувати — там часто вхід.
- Один дефолтний wordlist мало — змінити wordlist, перш ніж робити висновок «нічого нема».
- Знайдені шляхи/параметри → tracker.
