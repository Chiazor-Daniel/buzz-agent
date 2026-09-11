# buzz agent -- daily driver on NVIDIA Nemotron Lightning (free cloud).
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "buzz-lib.ps1")

if ($args.Count -gt 0 -and (Test-Subcommand $args[0])) {
    & pi @args
    exit $LASTEXITCODE
}

$env:BUZZ_ENGINE = "NVIDIA Nemotron Lightning 30B"
Show-Banner
Ensure-Proxy
& pi --provider nvidia --model "nvidia/nemotron-3.5-lightning-30b-a3b" @args
exit $LASTEXITCODE