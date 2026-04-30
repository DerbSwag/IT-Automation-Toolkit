@echo off
REM ============================================================
REM  IT PJPARAWOOD - GLPI Agent Installer
REM  Version: 2025 (HTTP Download)
REM ============================================================

echo ================================================
echo    IT PJPARAWOOD - GLPI Agent Installer 2025
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

:: --- Paths ---
set "DOWNLOAD_URL=http://YOUR_SERVER_IP/glpi-agent/GLPI-Agent-1.4-x64.msi"
set "GLPI_SERVER_URL=http://YOUR_SERVER_IP/front/inventory.php"
set "LOCAL_DIR=%TEMP%\GLPI_Installer"
set "LOCAL_MSI=%LOCAL_DIR%\GLPI-Agent-1.4-x64.msi"
set "LOG_FILE=%LOCAL_DIR%\GLPI_Agent_Install.log"

:: --- Create local temp dir ---
if not exist "%LOCAL_DIR%" mkdir "%LOCAL_DIR%"

:: --- Download MSI via HTTP ---
echo [INFO] Downloading installer from GLPI server...
powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%LOCAL_MSI%' -UseBasicParsing -TimeoutSec 120"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to download installer.
    echo Please check network connection and try again.
    pause
    exit /b %errorlevel%
)

:: --- Run silent install ---
echo [INFO] Installing GLPI Agent...
msiexec /i "%LOCAL_MSI%" /qn /norestart ^
    /L*v "%LOG_FILE%" ^
    SERVER="%GLPI_SERVER_URL%" RUNNOW=1

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
