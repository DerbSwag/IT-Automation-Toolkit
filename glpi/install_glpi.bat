@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "ROOT_DIR=%SCRIPT_DIR%.."
set "CONFIG_FILE=%ROOT_DIR%\config\toolkit.ini"

if not exist "%CONFIG_FILE%" (
    echo [ERROR] Missing config file: %CONFIG_FILE%
    exit /b 20
)

call :LoadConfig
if errorlevel 1 exit /b %errorlevel%
call :EnsureLogDir
call :Log INFO "GLPI install script started"

call :RequireAdmin
if "%ERRORLEVEL%"=="200" exit /b 0
if errorlevel 1 exit /b %errorlevel%

if not exist "%INSTALLER_DIR%\%MSI_NAME%" (
    call :Log ERROR "Installer missing: %INSTALLER_DIR%\%MSI_NAME%"
    exit /b 21
)

ping -n 1 %PING_HOST% >nul 2>&1
if errorlevel 1 (
    call :Log WARN "GLPI host is unreachable: %PING_HOST%"
)

reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /f "GLPI Agent" >nul 2>&1
if "%ERRORLEVEL%"=="0" (
    call :Log INFO "GLPI Agent already installed; skipping MSI"
    goto :SendInventory
)

call :Log INFO "Installing GLPI Agent from %INSTALLER_DIR%\%MSI_NAME%"
msiexec /i "%INSTALLER_DIR%\%MSI_NAME%" /quiet /norestart RUNNOW=1 SERVER=%SERVER_URL%
set "MSI_EXIT=%ERRORLEVEL%"
if "%MSI_EXIT%"=="0" (
    call :Log INFO "GLPI Agent installed successfully"
) else if "%MSI_EXIT%"=="3010" (
    call :Log WARN "GLPI install succeeded; reboot required (3010)"
) else (
    call :Log ERROR "GLPI install failed with exit code %MSI_EXIT%"
    exit /b %MSI_EXIT%
)

:SendInventory
set "GLPI_EXE=C:\Program Files\GLPI-Agent\glpi-agent.bat"
if exist "%GLPI_EXE%" (
    call :Log INFO "Triggering GLPI inventory"
    call "%GLPI_EXE%" --server "%SERVER_URL%" --force
    if errorlevel 1 (
        call :Log WARN "Inventory trigger failed, but install step completed"
    )
) else (
    call :Log WARN "GLPI agent executable not found: %GLPI_EXE%"
)

echo [SUCCESS] GLPI deployment workflow completed
call :Log INFO "GLPI deployment workflow completed"
exit /b 0

:LoadConfig
for /f "tokens=1,* delims==" %%A in ('findstr /r /c:"^[A-Za-z_][A-Za-z0-9_]*=" "%CONFIG_FILE%"') do (
    if /I "%%A"=="SERVER_URL" set "SERVER_URL=%%B"
    if /I "%%A"=="MSI_NAME" set "MSI_NAME=%%B"
    if /I "%%A"=="INSTALLER_PATH" set "INSTALLER_PATH=%%B"
    if /I "%%A"=="PING_HOST" set "PING_HOST=%%B"
    if /I "%%A"=="LOG_DIR" set "LOG_DIR=%ROOT_DIR%\%%B"
    if /I "%%A"=="LOG_FILE" set "LOG_FILE=%%B"
)

if not defined SERVER_URL exit /b 22
if not defined MSI_NAME exit /b 23
if not defined INSTALLER_PATH exit /b 24
if not defined PING_HOST set "PING_HOST=localhost"
if not defined LOG_DIR exit /b 25
if not defined LOG_FILE exit /b 26

set "INSTALLER_DIR=%ROOT_DIR%\%INSTALLER_PATH%"
set "LOG_PATH=%LOG_DIR%\%LOG_FILE%"
exit /b 0

:EnsureLogDir
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
exit /b 0

:Log
set "LEVEL=%~1"
set "MESSAGE=%~2"
>>"%LOG_PATH%" echo [%date% %time%] [%LEVEL%] [glpi] %MESSAGE%
exit /b 0

:RequireAdmin
net session >nul 2>&1
if "%ERRORLEVEL%"=="0" exit /b 0

call :Log WARN "Script not running as admin. Attempting self-elevation"
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
if errorlevel 1 (
    call :Log ERROR "Self-elevation canceled or failed"
    exit /b 27
)
exit /b 200
