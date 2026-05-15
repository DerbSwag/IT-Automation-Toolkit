@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM  Uninstall GLPI Agent + Cleanup
REM  Removes GLPI Agent, scheduled tasks, and local data
REM ============================================================

echo.
echo =============================================
echo   GLPI Agent Uninstall / Rollback
echo =============================================
echo.

REM --- Check admin ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Please run as Administrator.
    pause
    exit /b 1
)

REM --- Find GLPI Agent MSI product code ---
set "FOUND="
for /f "tokens=*" %%i in ('wmic product where "name like '%%GLPI Agent%%'" get IdentifyingNumber /value 2^>nul ^| findstr "IdentifyingNumber"') do (
    for /f "tokens=2 delims==" %%j in ("%%i") do (
        set "PRODUCT_CODE=%%j"
        set "FOUND=1"
    )
)

if not defined FOUND (
    echo [INFO] GLPI Agent not found via WMI. Trying registry...
    for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /f "GLPI Agent" 2^>nul ^| findstr "UninstallString"') do (
        set "UNINSTALL_CMD=%%b"
        set "FOUND=1"
    )
)

if not defined FOUND (
    echo [WARN] GLPI Agent installation not found. May already be uninstalled.
) else (
    echo [INFO] Uninstalling GLPI Agent...
    if defined PRODUCT_CODE (
        msiexec /x !PRODUCT_CODE! /qn /norestart
    ) else (
        !UNINSTALL_CMD! /S
    )
    if !errorlevel! equ 0 (
        echo [OK] GLPI Agent uninstalled.
    ) else (
        echo [WARN] Uninstall returned code: !errorlevel!
    )
)

REM --- Remove scheduled task ---
schtasks /query /tn "GLPI-Agent" >nul 2>&1
if %errorlevel% equ 0 (
    schtasks /delete /tn "GLPI-Agent" /f
    echo [OK] Scheduled task removed.
) else (
    echo [INFO] No GLPI-Agent scheduled task found.
)

REM --- Remove program files ---
if exist "C:\Program Files\GLPI-Agent" (
    rmdir /s /q "C:\Program Files\GLPI-Agent"
    echo [OK] Program files removed.
)

REM --- Remove local data ---
if exist "%ProgramData%\GLPI-Agent" (
    rmdir /s /q "%ProgramData%\GLPI-Agent"
    echo [OK] ProgramData removed.
)

echo.
echo =============================================
echo   Uninstall complete.
echo =============================================
pause
