@echo off
rem buzz agent -- heavyweight on NVIDIA Nemotron Ultra (free cloud).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0buzz-code.ps1" %*
exit /b %ERRORLEVEL%