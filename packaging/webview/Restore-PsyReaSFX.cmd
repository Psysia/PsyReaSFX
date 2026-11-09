@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Restore-PsyReaSFX.ps1" -ChooseResourcePath %*
if errorlevel 1 echo Restore failed. See the message above.
pause
