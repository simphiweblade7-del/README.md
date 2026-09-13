@echo off
setlocal EnableExtensions
title SystemBoost Installer
cd /d "%~dp0"

echo.
echo  ============================================================
echo   SYSTEMBOOST - Install to this PC
echo  ============================================================
echo.

rem --- Elevate if needed ------------------------------------------------
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo   Installing requires Administrator rights.
    echo   A User Account Control prompt will appear - click Yes.
    echo.
    set "args=%*"
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%args%' -Verb RunAs"
    exit /b
)

set "DATA=%ProgramData%\SystemBoost"
echo   Installing to %DATA% ...
if not exist "%DATA%" mkdir "%DATA%"

echo   Copying files ...
xcopy /E /I /Y /Q "%~dp0." "%DATA%\SystemBoost\" >nul 2>&1
if errorlevel 1 (
    echo   [!!] Could not copy files. Check permissions and try again.
    pause
    exit /b 1
)

rem --- Create shortcuts --------------------------------------------------
echo   Creating shortcuts ...
set "DESKTOP=%USERPROFILE%\Desktop"
set "PROGMENU=%ProgramData%\Microsoft\Windows\Start Menu\Programs\SystemBoost"

if not exist "%PROGMENU%" mkdir "%PROGMENU%"
cscript //nologo //E:vbscript "%DATA%\SystemBoost\make-shortcuts.vbs" "%DATA%\SystemBoost\SystemBoost.bat" "%DESKTOP%\SystemBoost.lnk" "%PROGMENU%\SystemBoost.lnk" >nul 2>&1

echo   Running a first quick-clean to test the install ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%DATA%\SystemBoost\SystemBoost.ps1" /quickclean /yes /norestore

echo.
echo  ------------------------------------------------------------
echo   SystemBoost installed successfully.
echo
echo   - A "SystemBoost" shortcut was added to your Desktop and Start menu.
echo   - Run it any time to free space and speed up Windows.
echo   - To remove it, run  Uninstall.bat  in the install folder.
echo  ------------------------------------------------------------
echo.
pause
endlocal
