@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM  IT PJPARAWOOD - Computer Inventory + GLPI Agent Installer
REM  Version: 2025
REM  Author: Natthawat R. (Modified & Improved by Gemini)
REM ============================================================

:: --- Display Banner ---
echo ================================================
echo    IT PJPARAWOOD Computer Inventory 2025
echo ================================================
echo.

:: --- Force Run as Administrator (UAC elevation) ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Requesting administrative privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: --- Ask for Lark account ---
set /p LARK_ACCOUNT=Enter your Lark account: 

:: --- Display "Please wait" ---
echo.
echo Please wait...

:: --- Output folder and file ---
set "OUTPUT_FOLDER=\\YOUR_SERVER_IP\Users\Public\IT_inventory\Output"
set "OUTPUT_FILE=%OUTPUT_FOLDER%\%LARK_ACCOUNT%.txt"

:: --- Ensure output folder exists ---
if not exist "%OUTPUT_FOLDER%" (
    echo [INFO] Creating output folder...
    mkdir "%OUTPUT_FOLDER%"
)

:: --- Save Lark account to file ---
echo Lark Account: %LARK_ACCOUNT% > "%OUTPUT_FILE%"


echo ===========================================
echo Installing GLPI Agent 1.4 (x64)...
echo ===========================================

:: --- Installer Path (Network) ---
set "MSI_PATH=\\YOUR_SERVER_IP\Department-Information Technology\0001\GLPI-Agent-1.4\GLPI-Agent-1.4-x64.msi"

:: --- GLPI Server URL (Updated) ---
set "GLPI_SERVER_URL=http://YOUR_SERVER_IP/front/inventory.php"

:: --- Local Temp Variables ---
set "LOCAL_DIR=%TEMP%\GLPI_Installer"
set "LOCAL_MSI=%LOCAL_DIR%\GLPI-Agent-1.4-x64.msi"
set "LOG_FILE=%LOCAL_DIR%\GLPI_Agent_Install.log"

:: --- Create local temp dir ---
if not exist "%LOCAL_DIR%" (
    mkdir "%LOCAL_DIR%"
)

:: --- Copy MSI from network share ---
echo [INFO] Copying installer from network share...
copy "%MSI_PATH%" "%LOCAL_MSI%" /Y >nul
if %errorlevel% neq 0 (
    echo [ERROR] Failed to copy installer from "%MSI_PATH%"
    echo Please check the network path and permissions.
    pause
    exit /b %errorlevel%
)

set "PS_SCRIPT=%TEMP%\Get-PCInfo.ps1"

copy "\\YOUR_SERVER_IP\Users\Public\IT_inventory\Get-PCInfo.ps1" "%PS_SCRIPT%" /Y >nul
if %errorlevel% neq 0 (
    echo [ERROR] Failed to copy PowerShell script.
    pause
    exit /b %errorlevel%
)

echo [INFO] Collecting computer information...
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%PS_SCRIPT%'" >> "%OUTPUT_FILE%" 2>&1
if %errorlevel% neq 0 (
    echo [WARNING] PowerShell script failed. Check output file: %OUTPUT_FILE%
)

:: --- Run installer silently ---
echo [INFO] Running silent install and configuring the agent...
msiexec /i "%LOCAL_MSI%" /qn /norestart ^
    /L*v "%LOG_FILE%" ^
    SERVER="%GLPI_SERVER_URL%" RUNNOW=1

:: --- Check result ---
if %errorlevel%==0 (
    echo [SUCCESS] GLPI Agent installed and configured successfully.
    echo Log file: %LOG_FILE%
) else (
    echo [ERROR] Installation failed with exit code %errorlevel%.
    echo Please check log file: %LOG_FILE%
)

echo.
echo [DONE] Installation process finished.
pause
exit /b
