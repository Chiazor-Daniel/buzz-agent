# buzz-chat -- one-shot question to NVIDIA via the local key-hiding proxy.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$chat = Join-Path $PSScriptRoot "buzz-chat"
$py = Join-Path $HOME ".buzz-proxy-venv\Scripts\python.exe"
if (-not (Test-Path $py)) { $py = "python" }

& $py $chat @args
exit $LASTEXITCODE