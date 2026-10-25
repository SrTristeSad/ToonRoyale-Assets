@echo off
setlocal
if "%~1"=="" (
  echo Arraste um arquivo .json sobre este instalador do Moo-IO.
  pause
  exit /b 1
)
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0scripts\import-json-pack.ps1" -Source "%~1" -Kind map
if errorlevel 1 (
  echo.
  echo Importacao recusada. Consulte a mensagem acima.
  pause
  exit /b 1
)
echo.
pause
