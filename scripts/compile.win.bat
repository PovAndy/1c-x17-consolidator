@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0compile.win.ps1"
exit /b %errorlevel%
