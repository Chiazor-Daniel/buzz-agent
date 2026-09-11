<#!
.SYNOPSIS
    One-shot setup for the buzz agent on Windows (PowerShell).

.DESCRIPTION
    Installs Node.js 22, Python 3, and the proxy's Python packages automatically
    via winget.  After setup, open a new terminal and type "buzz".

    If you prefer Linux compatibility, install via WSL and use setup.sh instead.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# ── helpers ───────────────────────────────────────────────────────────────────

function Refresh-Path {
    $m = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $u = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$m;$u"
}

function Require-Command([string]$cmd, [string]$wingetId, [string]$label) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) { return }
    Write-Host "Installing $label..." -ForegroundColor Yellow
    try {
        winget install --id $wingetId -e --silent `
            --accept-package-agreements --accept-source-agreements `
            --disable-interactivity
        Refresh-Path
    } catch {
        Write-Host "winget failed to install $label.`n  Install $label manually from https://$label, then re-run setup.ps1." -ForegroundColor Red
        exit 1
    }
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "winget installed $label but it is still not on PATH.`n  Close and reopen your terminal, then re-run setup.ps1." -ForegroundColor Red
        exit 1
    }
}

# ── 0. prereqs ────────────────────────────────────────────────────────────────

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "winget not found. Windows 10 (1709+) / 11 is required (App Installer from the Store)." -ForegroundColor Red
    exit 1
}

Write-Host "==> buzz agent setup" -ForegroundColor Green

# ── 1. Node.js 22 ────────────────────────────────────────────────────────────

$needNode = {
    $v = node -e "const p=process.versions.node.split('.').map(Number); process.exit(p[0]>22||(p[0]===22&&p[1]>=19)?0:1)" 2>$null
    return $LASTEXITCODE -eq 0
}
$nodeOk = Get-Command node -ErrorAction SilentlyContinue
if ($nodeOk) { $nodeOk = & $needNode }
if (-not $nodeOk) {
    Require-Command "node" "OpenJS.NodeJS.LTS" "Node.js"
}

# ── 2. engine ─────────────────────────────────────────────────────────────────

if (-not (Get-Command pi -ErrorAction SilentlyContinue)) {
    Write-Host "Installing the code agent engine..." -ForegroundColor Yellow
    npm install -g @earendil-works/pi-coding-agent --no-audit --no-fund --no-progress
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Engine install failed." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Code agent engine already installed."
}

# ── 3. Python 3 + proxy venv ─────────────────────────────────────────────────

Require-Command "python" "Python.Python.3.12" "Python 3"

$VENV = Join-Path $HOME ".buzz-proxy-venv"
$VENV_PYTHON = Join-Path $VENV "Scripts\python.exe"

if (-not (Test-Path $VENV_PYTHON)) {
    Write-Host "Setting up the proxy's Python environment..." -ForegroundColor Yellow
    python -m venv $VENV
    if ($LASTEXITCODE -ne 0) {
        Write-Host "venv failed. Installing proxy packages into user site-packages instead." -ForegroundColor Yellow
        python -m pip install --user -q -r (Join-Path $SCRIPT_DIR "bin\nvidia-proxy\requirements.txt")
    }
}

if (Test-Path $VENV_PYTHON) {
    & $VENV_PYTHON -m pip install -q --disable-pip-version-check -r (Join-Path $SCRIPT_DIR "bin\nvidia-proxy\requirements.txt")
}
Write-Host "Proxy Python environment ready."

# ── 4. branding + help-text scrub ────────────────────────────────────────────

& python (Join-Path $SCRIPT_DIR "bin\brand-engine.py")

# ── 5. copy scripts + proxy into ~/bin ────────────────────────────────────────

$BIN = Join-Path $HOME "bin"
New-Item -ItemType Directory -Force $BIN | Out-Null
Copy-Item "$SCRIPT_DIR\bin\*" -Destination $BIN -Recurse -Force
Write-Host "==> Scripts installed to $BIN" -ForegroundColor Green

# Make sure ~/bin is on this user's PATH.
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$HOME\bin*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$HOME\bin", "User")
    $env:Path = "$env:Path;$HOME\bin"
    Write-Host "Added $BIN to your PATH (new terminals pick it up automatically)."
}

# ── 6. NVIDIA API key ─────────────────────────────────────────────────────────

$KEY_FILE = Join-Path $HOME ".config\nvidia\api.key"
if (-not (Test-Path $KEY_FILE)) {
    Write-Host "NVIDIA API key not found." -ForegroundColor Yellow
    Write-Host "1. Get a FREE key at: https://build.nvidia.com"
    Write-Host "   (pick any model -> 'Get API Key' -> copy the nvapi-... value)"
    $KEY = $env:BUZZ_SETUP_KEY
    if (-not $KEY) { $KEY = Read-Host "2. Paste your key" }
    if (-not $KEY) {
        Write-Host "No key entered. Aborting (re-run setup.ps1 when ready)."
        exit 1
    }
    $keyDir = Split-Path $KEY_FILE
    New-Item -ItemType Directory -Force $keyDir | Out-Null
    Set-Content -Path $KEY_FILE -Value $KEY -NoNewline -Force
    # Lock to current user only (Windows ACL).
    icacls $KEY_FILE /inheritance:r /grant:r "$($env:USERNAME):(F)" | Out-Null
    Write-Host "Key saved to $KEY_FILE"
} else {
    Write-Host "Key already present at $KEY_FILE."
}

# ── 7. theme + engine config (proxy URL + default theme) ─────────────────────

$THEMES = Join-Path $HOME ".pi\agent\themes"
New-Item -ItemType Directory -Force $THEMES | Out-Null
Copy-Item (Join-Path $SCRIPT_DIR "theme\buzz.json") (Join-Path $THEMES "buzz.json") -Force
Write-Host "==> Installed buzz theme" -ForegroundColor Green

& $VENV_PYTHON (Join-Path $SCRIPT_DIR "bin\configure-engine.py")

# ── done ──────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "==> Done!" -ForegroundColor Green
Write-Host ""
Write-Host "Try it (in a NEW terminal, or after refreshing your PATH):"
Write-Host '  buzz "write a one-line hello world"'
Write-Host '  buzz-code "review this project for bugs"'
Write-Host '  buzz-chat "what is a TLS handshake?"'
Write-Host ""
Write-Host "How it works: your key lives only in $KEY_FILE"
Write-Host "The proxy on :8888 reads it and forwards to NVIDIA's free cloud."
Write-Host "buzz talks to the proxy and never sees the key."