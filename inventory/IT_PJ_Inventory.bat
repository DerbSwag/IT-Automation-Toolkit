@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM  IT PJPARAWOOD - Computer Inventory + GLPI Agent Installer
REM  Version: 2025 (Merged)
REM  Reads config from config\toolkit.ini
REM  Replaces: IT_PJ_Computer Inventory.bat, IT_PJ_Inven.bat,
REM            IT pjparawood computer inventory.bat
REM ============================================================

set "SCRIPT_DIR=%~dp0"
set "ROOT_DIR=%SCRIPT_DIR%.."
set "CONFIG_FILE=%ROOT_DIR%\config\toolkit.ini"

if not exist "%CONFIG_FILE%" (
    echo [ERROR] Missing config file: %CONFIG_FILE%
    pause
    exit /b 1
)

call :LoadConfig
if errorlevel 1 (
    echo [ERROR] Failed to load config.
    pause
    exit /b %errorlevel%
)

echo ================================================
echo    IT PJPARAWOOD Computer Inventory 2025
echo ================================================
echo.

:: --- Force Run as Administrator ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Requesting administrative privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: --- Ask for Lark account ---
set /p LARK_ACCOUNT=Enter your Lark account: 
echo.
echo Please wait...

:: --- Output ---
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
set "OUTPUT_FILE=%OUTPUT_DIR%\%LARK_ACCOUNT%.txt"

echo Lark Account: %LARK_ACCOUNT% > "%OUTPUT_FILE%"

:: --- Run inventory PowerShell script ---
set "PS_SCRIPT=%ROOT_DIR%\inventory\Get-PCInfo.ps1"
if not exist "%PS_SCRIPT%" (
    echo [ERROR] Missing inventory script: %PS_SCRIPT%
    pause
    exit /b 2
)

echo [INFO] Collecting computer information...
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" >> "%OUTPUT_FILE%" 2>&1
if %errorlevel% neq 0 (
    echo [WARNING] Inventory collection had issues. Check: %OUTPUT_FILE%
)

:: --- Install GLPI Agent ---
echo.
echo ===========================================
echo Installing GLPI Agent...
echo ===========================================

set "LOCAL_DIR=%TEMP%\GLPI_Installer"
set "LOCAL_MSI=%LOCAL_DIR%\%MSI_NAME%"
set "LOG_FILE=%LOCAL_DIR%\GLPI_Agent_Install.log"

if not exist "%LOCAL_DIR%" mkdir "%LOCAL_DIR%"

echo [INFO] Downloading installer from %DOWNLOAD_URL%...
powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%LOCAL_MSI%' -UseBasicParsing -TimeoutSec 120"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to download installer.
    pause
    exit /b %errorlevel%
)

echo [INFO] Running silent install...
msiexec /i "%LOCAL_MSI%" /qn /norestart ^
    /L*v "%LOG_FILE%" ^
    SERVER="%SERVER_URL%" RUNNOW=1

if %errorlevel%==0 (
    echo [SUCCESS] GLPI Agent installed successfully.
) else (
    echo [ERROR] Installation failed with exit code %errorlevel%.
    echo Check log: %LOG_FILE%
)

echo.
echo [DONE] Inventory + GLPI Agent installation complete.
pause
exit /b

:LoadConfig
for /f "tokens=1,* delims==" %%A in ('findstr /r /c:"^[A-Za-z_][A-Za-z0-9_]*=" "%CONFIG_FILE%"') do (
    if /I "%%A"=="SERVER_URL" set "SERVER_URL=%%B"
    if /I "%%A"=="MSI_NAME" set "MSI_NAME=%%B"
    if /I "%%A"=="PING_HOST" set "PING_HOST=%%B"
    if /I "%%A"=="OUTPUT_DIR" set "OUTPUT_DIR=%ROOT_DIR%\%%B"
)
if not defined SERVER_URL exit /b 3
if not defined MSI_NAME exit /b 4
if not defined OUTPUT_DIR set "OUTPUT_DIR=%ROOT_DIR%\output\inventory"
if not defined PING_HOST set "PING_HOST=localhost"
set "DOWNLOAD_URL=http://%PING_HOST%/glpi-agent/%MSI_NAME%"
exit /b 0
