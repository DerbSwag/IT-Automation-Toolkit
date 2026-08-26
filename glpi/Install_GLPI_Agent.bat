@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM  IT Automation Toolkit - GLPI Agent Installer
REM  Version: 2025 (HTTP Download)
REM  Reads config from config\toolkit.ini
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
echo    IT Automation Toolkit - GLPI Agent Installer 2025
echo ================================================
echo.

:: --- Force Run as Administrator ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Requesting administrative privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo Please wait...

set "LOCAL_DIR=%TEMP%\GLPI_Installer"
set "LOCAL_MSI=%LOCAL_DIR%\%MSI_NAME%"
set "LOG_FILE=%LOCAL_DIR%\GLPI_Agent_Install.log"

:: --- Create local temp dir ---
if not exist "%LOCAL_DIR%" mkdir "%LOCAL_DIR%"

:: --- Download MSI via HTTP ---
echo [INFO] Downloading installer from %DOWNLOAD_URL%...
powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%LOCAL_MSI%' -UseBasicParsing -TimeoutSec 120"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to download installer.
    pause
    exit /b %errorlevel%
)

:: --- Verify checksum ---
set "CHECKSUM_URL=%DOWNLOAD_URL%.sha256"
set "CHECKSUM_FILE=%LOCAL_DIR%\checksum.sha256"
powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri '%CHECKSUM_URL%' -OutFile '%CHECKSUM_FILE%' -UseBasicParsing -TimeoutSec 30 } catch { exit 0 }"
if exist "%CHECKSUM_FILE%" (
    powershell -NoProfile -Command "$expected=(Get-Content '%CHECKSUM_FILE%' -First 1).Split(' ')[0]; $actual=(Get-FileHash '%LOCAL_MSI%' -Algorithm SHA256).Hash; if($expected -ne $actual){Write-Host '[ERROR] Checksum mismatch'; exit 1}"
    if %errorlevel% neq 0 (
        echo [ERROR] Downloaded file failed integrity check. Aborting.
        del "%LOCAL_MSI%" 2>nul
        pause
        exit /b 50
    )
    echo [OK] Checksum verified.
) else (
    echo [WARN] No checksum file available at %CHECKSUM_URL% - skipping verification.
)

:: --- Run silent install ---
echo [INFO] Installing GLPI Agent...
msiexec /i "%LOCAL_MSI%" /qn /norestart ^
    /L*v "%LOG_FILE%" ^
    SERVER="%SERVER_URL%" RUNNOW=1

if %errorlevel% neq 0 (
    echo [ERROR] Installation failed. Check log: %LOG_FILE%
    pause
    exit /b %errorlevel%
)

echo [SUCCESS] GLPI Agent installed successfully.

:: --- Wait for agent service to start ---
echo [INFO] Waiting for GLPI Agent service to start...
timeout /t 10 /nobreak >nul

:: --- Trigger inventory via local agent port ---
echo [INFO] Triggering inventory run...
powershell -NoProfile -Command "Invoke-WebRequest -Uri 'http://localhost:62354/now' -UseBasicParsing -TimeoutSec 10" >nul 2>&1

if %errorlevel%==0 (
    echo [SUCCESS] Inventory triggered successfully.
) else (
    echo [WARNING] Could not trigger inventory automatically.
    echo           You can run it manually at: http://localhost:62354/
)

echo.
echo [DONE] Press any key to close.
pause
exit /b

:LoadConfig
for /f "tokens=1,* delims==" %%A in ('findstr /r /c:"^[A-Za-z_][A-Za-z0-9_]*=" "%CONFIG_FILE%"') do (
    if /I "%%A"=="SERVER_URL" set "SERVER_URL=%%B"
    if /I "%%A"=="MSI_NAME" set "MSI_NAME=%%B"
    if /I "%%A"=="PING_HOST" set "PING_HOST=%%B"
)
if not defined SERVER_URL (
    echo [ERROR] SERVER_URL not found in config
    exit /b 2
)
if not defined MSI_NAME (
    echo [ERROR] MSI_NAME not found in config
    exit /b 3
)
:: Build download URL from PING_HOST
if not defined PING_HOST set "PING_HOST=localhost"
set "DOWNLOAD_URL=http://%PING_HOST%/glpi-agent/%MSI_NAME%"
exit /b 0
