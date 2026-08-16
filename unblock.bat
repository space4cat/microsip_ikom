@echo off
rem Remove the "downloaded from the internet" mark from microsip.exe
rem so Windows SmartScreen no longer blocks it.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Unblock-File -LiteralPath '%~dp0microsip.exe'"
