Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Key = "nvapi-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
$script:PASS = 0; $script:FAIL = 0
function Pass([string]$m) { Write-Host "  PASS: $m"; $script:PASS++ }
function Fail([string]$m) { Write-Host "  FAIL: $m"; $script:FAIL++ }

# Make sure npm global bin and ~/bin are on PATH.
$npmPrefix = (npm prefix -g 2>$null).Trim()
$env:Path = "$npmPrefix;$HOME\bin;$env:Path"

# ── W1: setup runs to completion with a bogus key ──────────────────────────────

Write-Host "### W1: setup.ps1 with bogus key"
$env:BUZZ_SETUP_KEY = $Key
$all = (& powershell -NoProfile -ExecutionPolicy Bypass -File "$env:GITHUB_WORKSPACE\bin\setup.ps1" 2>&1 | Out-String)
Remove-Item Env:BUZZ_SETUP_KEY
if ($all -match "Done!") { Pass "W1 setup done" } else { Fail "W1 setup failed"; Write-Host $all | Select-Object -Last 30 }

# ── W2: engine branded to buzz ─────────────────────────────────────────────────

Write-Host "### W2: branding"
$brand = node -e "var p=require(require('path').join(require('child_process').execSync('npm root -g').toString().trim(),'@earendil-works/pi-coding-agent/package.json'));console.log(p.piConfig&&p.piConfig.name||'')" 2>$null
if ($brand -eq "buzz") { Pass "W2 piConfig.name=buzz" } else { Fail "W2 piConfig.name=$brand" }

# ── W3: help text fully branded ────────────────────────────────────────────────

Write-Host "### W3: help"
$env:BUZZ_NO_BANNER = "1"
$help = (buzz -h 2>&1 | Out-String)
Remove-Item Env:BUZZ_NO_BANNER
if ($help -match "buzz - AI coding assistant") { Pass "W3 help title" } else { Fail "W3 title: $help" }
if ($help -match "Update pi,|\[source\|self\|pi\]") { Fail "W3 pi leak: $help" } else { Pass "W3 no pi leaks" }

# ── W4: --version passthrough ──────────────────────────────────────────────────

Write-Host "### W4: --version"
$env:BUZZ_NO_BANNER = "1"
$ver = (buzz --version 2>&1 | Out-String).Trim()
Remove-Item Env:BUZZ_NO_BANNER
if ($ver -match "^[0-9]+\.[0-9]+\.[0-9]+") { Pass "W4 --version: $ver" } else { Fail "W4 --version: $ver" }

# ── W5: proxy boots + bogus key → friendly 403 ────────────────────────────────

Write-Host "### W5: proxy + 403"
$py = "$HOME\.buzz-proxy-venv\Scripts\python.exe"
if (-not (Test-Path $py)) { $py = "python" }

$logDir = Join-Path $HOME ".config\nvidia"
New-Item -ItemType Directory -Force $logDir | Out-Null
$null = Start-Process -FilePath $py `
    -ArgumentList (Join-Path $HOME "bin\nvidia-proxy\main.py") `
    -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $logDir "proxy.out.log") `
    -RedirectStandardError  (Join-Path $logDir "proxy.err.log")

for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Seconds 1
    try { $r = Invoke-WebRequest -Uri "http://127.0.0.1:8888/health" -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop; if ($r.StatusCode -eq 200) { break } } catch { }
}
try { Invoke-WebRequest -Uri "http://127.0.0.1:8888/health" -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop | Out-Null; Pass "W5 proxy healthy" } catch { Fail "W5 proxy dead" }

$chatResp = (buzz-chat "hi" 2>&1 | Out-String)
if ($chatResp -match "rejected your API key") { Pass "W5 friendly 403" } else { Fail "W5 403 output: $chatResp" }

# ── W6: missing-key guard fires before agent starts ────────────────────────────

Write-Host "### W6: missing-key guard"
$keyPath = Join-Path $HOME ".config\nvidia\api.key"
$backed = Join-Path $HOME ".config\nvidia\api.key.bak"
Move-Item $keyPath $backed -Force

$errFile = Join-Path $env:TEMP "buzz.guard.err.log"
$outFile = Join-Path $env:TEMP "buzz.guard.out.log"
$buzzPs = Join-Path $HOME "bin\buzz.ps1"
$p = Start-Process powershell `
    -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File","`"$buzzPs`"","ignored") `
    -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput $outFile -RedirectStandardError $errFile
if (-not $p.WaitForExit(30000)) { $p.Kill() }
Move-Item $backed $keyPath -Force

$out = (Get-Content $outFile -Raw -ErrorAction SilentlyContinue) + "`n" + (Get-Content $errFile -Raw -ErrorAction SilentlyContinue)
if ($out -match "no API key found") { Pass "W6 guard" } else { Fail "W6: $out" }

# ── done ───────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "RESULT: $script:PASS passed, $script:FAIL failed"
if ($script:FAIL -gt 0) { exit 1 }