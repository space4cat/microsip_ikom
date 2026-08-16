@echo off
rem Create a desktop shortcut to microsip.exe in this folder.
set "TARGET=%~dp0microsip.exe"
set "WORKDIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ws = New-Object -ComObject WScript.Shell; $desktop = [Environment]::GetFolderPath('Desktop'); $path = Join-Path $desktop 'MicroSIP Ikom.lnk'; $sc = $ws.CreateShortcut($path); $sc.TargetPath = $env:TARGET; $sc.WorkingDirectory = $env:WORKDIR; $sc.Description = 'MicroSIP Ikom'; $sc.Save(); Write-Host ('Shortcut created: ' + $path)"
echo.
pause
