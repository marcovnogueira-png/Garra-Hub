@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo Instalando Claude oficial + 9router...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar.ps1"
echo.
echo ------------------------------------------------
echo Se apareceu algo em vermelho, tire um print desta janela.
echo ------------------------------------------------
pause
