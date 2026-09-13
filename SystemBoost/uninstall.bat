@echo off
setlocal EnableExtensions
title SystemBoost Uninstaller
cd /d "%~dp0"

echo.
echo  ============================================================
echo   SYSTEMBOOST - Uninstall
echo  ============================================================
echo.

net session >nul 2>&1
if %errorlevel% NEQ 0 (
    set "args=%*"
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%args%' -Verb RunAs"
    exit /b
)

set "DATA=%ProgramData%\SystemBoost"

echo   This will remove SystemBoost from this PC and delete saved settings.
set /p go="   Continue? (y/n): "
if /i not "%go%"=="y" ( echo   Cancelled. & pause & exit /b )

echo   Removing shortcuts ...
del /f /q "%USERPROFILE%\Desktop\SystemBoost.lnk" >nul 2>&1
rd /s /q "%ProgramData%\Microsoft\Windows\Start Menu\Programs\SystemBoost" >nul 2>&1

echo   Removing files ...
rmdir /s /q "%DATA%" >nul 2>&1

echo.
echo   SystemBoost has been removed.
echo   Note: any System Restore points it created remain available.
echo.
pause
endlocal
