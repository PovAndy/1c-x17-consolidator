@echo off
set SCRIPT=%~dp0open-base.win.ps1
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%SCRIPT%' %*"
