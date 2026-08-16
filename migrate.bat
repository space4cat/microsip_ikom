@echo off
rem Migrate settings and sound files from the installed MicroSIP
rem to this portable folder, preserving all accounts and settings,
rem and add the control numbers list URL (attentionNumbersUrl).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0migrate.ps1"
echo.
pause
