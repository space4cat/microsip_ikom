@echo off
rem Migrate settings and sound files from the installed MicroSIP
rem to this portable folder, preserving all accounts and settings,
rem and add the control numbers list URL (attentionNumbersUrl).
rem
rem If microsip.ini does not exist yet, copy it from microsip.ini.example.

if not exist "%~dp0microsip.ini" (
    if exist "%~dp0microsip.ini.example" (
        echo Copying microsip.ini.example to microsip.ini...
        copy /Y "%~dp0microsip.ini.example" "%~dp0microsip.ini" >nul
        echo.
    )
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0migrate.ps1"
echo.
pause
