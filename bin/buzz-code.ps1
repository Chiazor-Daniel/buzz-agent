# buzz agent -- heavyweight on NVIDIA Nemotron Ultra (free cloud).
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "buzz-lib.ps1")

if ($args.Count -gt 0 -and (Test-Subcommand $args[0])) {
    & pi @args
    exit $LASTEXITCODE
}

$env:BUZZ_ENGINE = "NVIDIA Nemotron Ultra 550B"
Show-Banner
Ensure-Proxy
& pi --provider nvidia --model "nvidia/nemotron-3-ultra-550b-a55b" @args
exit $LASTEXITCODE