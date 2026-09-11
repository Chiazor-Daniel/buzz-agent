@echo off
rem buzz-chat -- one-shot question to NVIDIA via the local key-hiding proxy.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0buzz-chat.ps1" %*
exit /b %ERRORLEVEL%