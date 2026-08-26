@echo off
setlocal EnableExtensions
:: IT Automation Toolkit - Open Asset Registration Page

:: ตรวจ Network Gateway
set "GW="
for /f "tokens=3" %%g in ('route print 0.0.0.0 ^| findstr " 0.0.0.0 "') do (
    if not defined GW set "GW=%%g"
)

if not defined GW (
    echo.
    echo  [!] Cannot detect network gateway.
    echo      Please connect to company network and try again.
    echo.
    pause
    exit /b 1
)

ping -n 1 %GW% >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  [!] Not connected to company network.
    echo      Please connect to WiFi or LAN and try again.
    echo.
    pause
    exit /b 1
)

:: เปิดหน้าลงทะเบียน พร้อมส่ง Computer Name
set "URL=http://YOUR_SERVER_IP/register.php?hn=%COMPUTERNAME%"
start "" "%URL%"
exit
