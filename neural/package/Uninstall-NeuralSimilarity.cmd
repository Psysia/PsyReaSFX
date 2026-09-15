@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-NeuralSimilarity.ps1" %*
if errorlevel 1 (
  echo.
  echo Uninstallation failed. Review the message above.
  pause
  exit /b 1
)
echo.
pause
