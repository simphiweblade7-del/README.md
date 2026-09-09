@echo off
setlocal EnableExtensions
title SystemBoost - Free Space & Speed Up Windows
cd /d "%~dp0"

rem --- If not running as admin, try to elevate automatically ---------------
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo.
    echo   SystemBoost needs Administrator rights.
    echo   A User Account Control prompt will appear - click Yes.
    echo.
    set "args=%*"
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%args%' -Verb RunAs"
    exit /b
)

rem --- Run the PowerShell engine, passing through any arguments ------------
echo.
echo   SYSTEMBOOST v1.0.0
echo   Freeing space & speeding up Windows ...
echo.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0SystemBoost.ps1" %*

echo.
echo   Process finished.
pause
endlocal
