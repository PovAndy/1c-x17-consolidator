@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0decompile.win.ps1"
exit /b %errorlevel%
