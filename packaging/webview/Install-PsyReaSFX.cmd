@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Install-PsyReaSFX.ps1" -ChooseResourcePath %*
if errorlevel 1 echo Installation failed. See the message above.
pause
