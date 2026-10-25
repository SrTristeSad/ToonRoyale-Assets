@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Iniciar-Servidor-Lua.ps1" %*
if errorlevel 1 (
  echo.
  echo Nao foi possivel iniciar. Confira README-LEIA-ME.md
  pause
)
