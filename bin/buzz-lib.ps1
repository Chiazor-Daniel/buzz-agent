# Shared boot for buzz / buzz-code on Windows (PowerShell).
# Mirrors bin/lib-pi: banner, proxy ensure, then hand off to pi.

if ($env:BUZZ_ENGINE) { $script:BUZZ_ENGINE = $env:BUZZ_ENGINE }
else { $script:BUZZ_ENGINE = "NVIDIA Nemotron Lightning" }

function Test-Subcommand([string]$cmd) {
    return $cmd -in @(
        "update", "install", "remove", "uninstall", "list", "config",
        "auth", "show", "get", "set", "onboard",
        "-h", "--help", "-V", "--version"
    )
}

function Show-Banner {
    if ($env:BUZZ_NO_BANNER -eq "1") { return }
    if (-not $Host.UI.RawUI) { return }
    Write-Host ""
    Write-Host "  BUZZ" -ForegroundColor Cyan
    Write-Host "  your AI coding agent  .  engine: $script:BUZZ_ENGINE"
    Write-Host "  tools: read . bash . edit . write . grep . find . ls"
    Write-Host ""
}

function Ensure-Proxy {
    $proxyUrl = "http://127.0.0.1:8888"
    if ($env:NVIDIA_PROXY_URL) { $proxyUrl = $env:NVIDIA_PROXY_URL }

    # Guard first: no key file means re-run setup, never silently reuse a proxy.
    $keyFile = Join-Path $HOME ".config\nvidia\api.key"
    if (-not (Test-Path $keyFile)) {
        Write-Host "ERROR: no API key found. Run setup.ps1 (or save one to $keyFile)." -ForegroundColor Red
        exit 1
    }

    try {
        $r = Invoke-WebRequest -Uri "$proxyUrl/health" -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
        if ($r.StatusCode -eq 200) { return }
    } catch { }

    $proxyDir = Join-Path $HOME "bin\nvidia-proxy"
    if (-not (Test-Path (Join-Path $proxyDir "main.py"))) {
        $proxyDir = Join-Path $PSScriptRoot "nvidia-proxy"
    }
    if (-not (Test-Path (Join-Path $proxyDir "main.py"))) {
        Write-Host "ERROR: nvidia-proxy not found. Run setup.ps1 first." -ForegroundColor Red
        exit 1
    }

    $logDir = Join-Path $HOME ".config\nvidia"
    $outLog = Join-Path $logDir "proxy.out.log"
    $errLog = Join-Path $logDir "proxy.err.log"

    $py = Join-Path $HOME ".buzz-proxy-venv\Scripts\python.exe"
    if (-not (Test-Path $py)) { $py = "python" }

    Write-Host "starting key-hiding proxy on $proxyUrl ..." -ForegroundColor DarkGray
    $null = Start-Process -FilePath $py `
        -ArgumentList (Join-Path $proxyDir "main.py") `
        -WindowStyle Hidden `
        -RedirectStandardOutput $outLog -RedirectStandardError $errLog

    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 500
        try {
            $r = Invoke-WebRequest -Uri "$proxyUrl/health" -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
            if ($r.StatusCode -eq 200) { return }
        } catch { }
    }
    Write-Host "ERROR: proxy failed to start. See $errLog" -ForegroundColor Red
    exit 1
}