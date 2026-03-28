@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "ROOT_DIR=%SCRIPT_DIR%.."
set "CONFIG_FILE=%ROOT_DIR%\config\toolkit.ini"

if not exist "%CONFIG_FILE%" (
    echo [ERROR] Missing config file: %CONFIG_FILE%
    exit /b 10
)

call :LoadConfig
if errorlevel 1 exit /b %errorlevel%

call :EnsureLogDir
call :Log INFO "Inventory script started"

call :RequireAdmin
if "%ERRORLEVEL%"=="200" exit /b 0
if errorlevel 1 exit /b %errorlevel%

where powershell >nul 2>&1
if errorlevel 1 (
    call :Log ERROR "PowerShell not found in PATH"
    exit /b 11
)

set "INV_SCRIPT=%ROOT_DIR%\inventory\Get-PCInfo.ps1"
if not exist "%INV_SCRIPT%" (
    call :Log ERROR "Missing inventory script: %INV_SCRIPT%"
    exit /b 12
)

if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
set "OUT_FILE=%OUTPUT_DIR%\%COMPUTERNAME%_%USERNAME%_%DATE:~-4%%DATE:~4,2%%DATE:~7,2%.txt"

call :Log INFO "Collecting inventory to %OUT_FILE%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%INV_SCRIPT%" -OutputPath "%OUT_FILE%"
set "PS_EXIT=%ERRORLEVEL%"
if not "%PS_EXIT%"=="0" (
    call :Log ERROR "Inventory collection failed with exit code %PS_EXIT%"
    exit /b %PS_EXIT%
)

call :Log INFO "Inventory collection completed"
echo [SUCCESS] Inventory complete: %OUT_FILE%
exit /b 0

:LoadConfig
for /f "tokens=1,* delims==" %%A in ('findstr /r /c:"^[A-Za-z_][A-Za-z0-9_]*=" "%CONFIG_FILE%"') do (
    if /I "%%A"=="OUTPUT_DIR" set "OUTPUT_DIR=%ROOT_DIR%\%%B"
    if /I "%%A"=="LOG_DIR" set "LOG_DIR=%ROOT_DIR%\%%B"
    if /I "%%A"=="LOG_FILE" set "LOG_FILE=%%B"
)

if not defined OUTPUT_DIR (
    echo [ERROR] OUTPUT_DIR not found in config
    exit /b 13
)
if not defined LOG_DIR (
    echo [ERROR] LOG_DIR not found in config
    exit /b 14
)
if not defined LOG_FILE (
    echo [ERROR] LOG_FILE not found in config
    exit /b 15
)
set "LOG_PATH=%LOG_DIR%\%LOG_FILE%"
exit /b 0

:EnsureLogDir
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
exit /b 0

:Log
set "LEVEL=%~1"
set "MESSAGE=%~2"
>>"%LOG_PATH%" echo [%date% %time%] [%LEVEL%] [inventory] %MESSAGE%
exit /b 0

:RequireAdmin
net session >nul 2>&1
if "%ERRORLEVEL%"=="0" exit /b 0

call :Log WARN "Script not running as admin. Attempting self-elevation"
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
if errorlevel 1 (
    call :Log ERROR "Self-elevation canceled or failed"
    exit /b 16
)
exit /b 200
