<#
flags_searcher.ps1 — пошук прапорців на Windows-цілі (аналог flags_searcher_obf.sh для Linux).

Формат прапорця на машині (літери best+CTF розбиті шумом -_. , суфікс :<буква><номер>):
    be-.s-tCT.F--{h1dd3n_r0b0ts}:A3
Скрипт знаходить такі рядки у файлах (і за потреби в ADS/реєстрі/Event Logs/env),
дедуплікує й за замовчуванням ОДРАЗУ нормалізує у формат платформи:
    bestCTF{h1dd3n_r0b0ts}  slot=A3      (на платформу вносити лише bestCTF{...})

ЗАПУСК (ExecutionPolicy обходиться прапорцем -ep bypass):
    powershell -ep bypass -f flags_searcher.ps1
    powershell -ep bypass -f flags_searcher.ps1 -Path C:\Users -ADS -Registry
    powershell -ep bypass -f flags_searcher.ps1 -Raw            # сирі збіги без нормалізації
    powershell -ep bypass -f flags_searcher.ps1 | Set-Content loot.txt

ПАРАМЕТРИ:
    -Path <шляхи>   де шукати (за замовч. C:\). Можна кілька: -Path C:\Users,C:\inetpub
    -Raw            вивід сирих збігів ("джерело: сире"), без нормалізації
    -ADS            додатково сканувати альтернативні потоки даних (повільніше)
    -Registry       додатково сканувати HKLM/HKCU:\SOFTWARE (повільно)
    -EventLogs      додатково сканувати Application/System/PowerShell-Operational
    -AllFiles       читати ВСІ файли, а не лише текстові розширення (повільно)
    -MaxFileMB <n>  пропускати файли більші за n МБ (за замовч. 20)

Код навмисно читабельний — за потреби правити FLAG_REGEX нижче, якщо формат зміниться.
Безпечний: лише читання (Get-*/Select-String), без мережі/запису/персистенції.
#>

[CmdletBinding()]
param(
    [string[]]$Path = @('C:\'),
    [switch]$Raw,
    [switch]$ADS,
    [switch]$Registry,
    [switch]$EventLogs,
    [switch]$AllFiles,
    [int]$MaxFileMB = 20
)

$ErrorActionPreference = 'SilentlyContinue'

# --- Формат прапорця (шум -_. між літерами; тіло {...}; суфікс :<буква><номер>) ---
$FLAG_REGEX = 'b[-_.]*e[-_.]*s[-_.]*t[-_.]*C[-_.]*T[-_.]*F[-_.]*\{[A-Za-z0-9_]+\}:[A-Za-z0-9]+'
$rx   = [regex]$FLAG_REGEX                 # case-sensitive (best — малі, CTF — великі), як у Linux
$body = [regex]'\{[^}]*\}'                 # тіло
$slot = [regex]'\}:([A-Za-z0-9]+)'         # суфікс-слот

$seen = [System.Collections.Generic.HashSet[string]]::new()

# Нормалізація сирого збігу → "bestCTF{...}  slot=XY"
function Convert-Flag([string]$rawFlag) {
    $b = $body.Match($rawFlag).Value
    if (-not $b) { return $null }
    $s = $slot.Match($rawFlag).Groups[1].Value
    if (-not $s) { $s = '?' }
    return "bestCTF$b`tslot=$s"
}

# Обробити один знайдений збіг (дедуп + вивід)
function Emit([string]$rawFlag, [string]$source) {
    if (-not $seen.Add($rawFlag)) { return }      # вже бачили
    if ($Raw) {
        "{0}: {1}" -f $source, $rawFlag
    } else {
        $norm = Convert-Flag $rawFlag
        if ($norm) { "{0}`t<= {1}" -f $norm, $source } else { "{0}: {1}" -f $source, $rawFlag }
    }
}

# Прогнати текст через regex і віддати всі збіги
function Scan-Text([string]$text, [string]$source) {
    if (-not $text) { return }
    foreach ($m in $rx.Matches($text)) { Emit $m.Value $source }
}

$textExt = @('*.txt','*.config','*.xml','*.ini','*.log','*.ps1','*.bat','*.cmd','*.html',
             '*.htm','*.json','*.csv','*.md','*.yml','*.yaml','*.sql','*.bak','*.old',
             '*.conf','*.properties','*.vbs','*.asp','*.aspx','*.php')
$maxBytes = $MaxFileMB * 1MB

Write-Host "[*] flags_searcher.ps1 — пошук у: $($Path -join ', ')  (Raw=$Raw ADS=$ADS Registry=$Registry EventLogs=$EventLogs)" -ForegroundColor Cyan

# --- 1. Вміст файлів ---
foreach ($root in $Path) {
    $gci = if ($AllFiles) {
        Get-ChildItem -LiteralPath $root -Recurse -File -Force
    } else {
        Get-ChildItem -LiteralPath $root -Recurse -File -Force -Include $textExt
    }
    foreach ($f in $gci) {
        if ($f.Length -gt $maxBytes) { continue }
        $text = Get-Content -LiteralPath $f.FullName -Raw
        Scan-Text $text $f.FullName

        # --- 2. ADS (альтернативні потоки даних) цього файлу ---
        if ($ADS) {
            foreach ($st in (Get-Item -LiteralPath $f.FullName -Stream * )) {
                if ($st.Stream -eq ':$DATA') { continue }
                $sv = Get-Content -LiteralPath $f.FullName -Stream $st.Stream -Raw
                Scan-Text $sv ("{0}:{1} (ADS)" -f $f.FullName, $st.Stream)
            }
        }
    }
}

# --- 3. Змінні оточення ---
Get-ChildItem Env: | ForEach-Object { Scan-Text ("{0}={1}" -f $_.Name, $_.Value) "env:$($_.Name)" }

# --- 4. Реєстр (опційно) ---
if ($Registry) {
    Write-Host "[*] скан реєстру HKLM/HKCU:\SOFTWARE ..." -ForegroundColor Cyan
    foreach ($hive in 'HKLM:\SOFTWARE','HKCU:\SOFTWARE') {
        Get-ChildItem -Path $hive -Recurse -Force | ForEach-Object {
            $key = $_
            foreach ($vn in $key.GetValueNames()) {
                $val = [string]$key.GetValue($vn)
                Scan-Text ("{0} {1}" -f $vn, $val) ("{0}\{1}" -f $key.Name, $vn)
            }
        }
    }
}

# --- 5. Event Logs (опційно) ---
if ($EventLogs) {
    Write-Host "[*] скан Event Logs ..." -ForegroundColor Cyan
    foreach ($log in 'Application','System','Microsoft-Windows-PowerShell/Operational') {
        Get-WinEvent -LogName $log -MaxEvents 3000 | ForEach-Object {
            Scan-Text $_.Message ("EventLog:$log/#$($_.Id)")
        }
    }
}

if ($seen.Count -eq 0) {
    Write-Host "[-] збігів не знайдено (спробуй -ADS -Registry -EventLogs -AllFiles або інший -Path)" -ForegroundColor Yellow
} else {
    Write-Host "[+] унікальних прапорців: $($seen.Count). На платформу вносити ЛИШЕ bestCTF{...} (слот = куди здавати)." -ForegroundColor Green
}
