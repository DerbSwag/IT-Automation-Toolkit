@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "ROOT_DIR=%SCRIPT_DIR%.."
set "CONFIG_FILE=%ROOT_DIR%\config\toolkit.ini"

if not exist "%CONFIG_FILE%" (
    echo [ERROR] Missing config file: %CONFIG_FILE%
    exit /b 30
)

call :LoadConfig
if errorlevel 1 exit /b %errorlevel%
call :EnsureLogDir
call :Log INFO "Endpoint toolkit started"

call :RequireAdmin
if "%ERRORLEVEL%"=="200" exit /b 0
if errorlevel 1 exit /b %errorlevel%

set "INV_BAT=%ROOT_DIR%\inventory\inventory.bat"
set "GLPI_BAT=%ROOT_DIR%\glpi\install_glpi.bat"

if not exist "%INV_BAT%" (
    call :Log ERROR "Missing inventory module: %INV_BAT%"
    exit /b 31
)
if not exist "%GLPI_BAT%" (
    call :Log ERROR "Missing GLPI module: %GLPI_BAT%"
    exit /b 32
)

echo ==========================================
echo Endpoint Automation Toolkit (Production)
echo ==========================================

call :Log INFO "Step 1/2 - inventory"
call "%INV_BAT%"
set "INV_EXIT=%ERRORLEVEL%"
if not "%INV_EXIT%"=="0" (
    call :Log ERROR "Inventory step failed with code %INV_EXIT%"
    exit /b %INV_EXIT%
)

call :Log INFO "Step 2/2 - GLPI deployment"
call "%GLPI_BAT%"
set "GLPI_EXIT=%ERRORLEVEL%"
if not "%GLPI_EXIT%"=="0" (
    call :Log WARN "GLPI step failed with code %GLPI_EXIT%"
    echo [WARN] Inventory done, GLPI deployment failed with code %GLPI_EXIT%.
    exit /b %GLPI_EXIT%
)

call :Log INFO "Endpoint toolkit completed successfully"
echo [SUCCESS] Endpoint onboarding workflow complete.
exit /b 0

:LoadConfig
for /f "tokens=1,* delims==" %%A in ('findstr /r /c:"^[A-Za-z_][A-Za-z0-9_]*=" "%CONFIG_FILE%"') do (
    if /I "%%A"=="LOG_DIR" set "LOG_DIR=%ROOT_DIR%\%%B"
    if /I "%%A"=="LOG_FILE" set "LOG_FILE=%%B"
)
if not defined LOG_DIR exit /b 33
if not defined LOG_FILE exit /b 34
set "LOG_PATH=%LOG_DIR%\%LOG_FILE%"
exit /b 0

:EnsureLogDir
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
exit /b 0

:Log
set "LEVEL=%~1"
set "MESSAGE=%~2"
>>"%LOG_PATH%" echo [%date% %time%] [%LEVEL%] [portable] %MESSAGE%
exit /b 0

:RequireAdmin
net session >nul 2>&1
if "%ERRORLEVEL%"=="0" exit /b 0

call :Log WARN "Script not running as admin. Attempting self-elevation"
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
if errorlevel 1 (
    call :Log ERROR "Self-elevation canceled or failed"
    exit /b 35
)
exit /b 200
