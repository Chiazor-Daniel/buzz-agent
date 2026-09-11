@echo off
rem buzz agent -- daily driver on NVIDIA Nemotron Lightning (free cloud).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0buzz.ps1" %*
exit /b %ERRORLEVEL%