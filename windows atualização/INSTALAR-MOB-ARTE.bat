@echo off
setlocal
if "%~1"=="" (
  echo Arraste uma imagem PNG estatica da nova especie sobre este instalador.
  pause
  exit /b 1
)
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0scripts\import-animation.ps1" -Source "%~1" -Kind static
if errorlevel 1 (
  echo Importacao recusada.
  pause
  exit /b 1
)
echo.
pause
