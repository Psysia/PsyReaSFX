@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Install-PsyReaSFX.ps1" -ChooseResourcePath -AllowUnverifiedRuntime %*
if errorlevel 1 echo Beta installation failed. See the message above.
pause
