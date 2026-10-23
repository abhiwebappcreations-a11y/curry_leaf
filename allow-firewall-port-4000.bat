@echo off
title Hinopt POS - Windows Firewall Port 4000 Configuration
color 0A

echo ========================================================
echo   HINOPT RESTAURANT POS - LOCAL LAN FIREWALL SETUP
echo ========================================================
echo.
echo Opening Inbound TCP Port 4000 for Captain Tablet Orders...
echo.

netsh advfirewall firewall delete rule name="Hinopt POS Local API (Port 4000)" >nul 2>&1

netsh advfirewall firewall add rule name="Hinopt POS Local API (Port 4000)" dir=in action=allow protocol=TCP localport=4000 profile=private,domain

if %errorlevel% equ 0 (
    echo.
    echo [SUCCESS] Windows Firewall Inbound Port 4000 has been opened!
    echo Captain Android tablets on your Wi-Fi can now connect seamlessly.
    echo.
) else (
    echo.
    echo [ERROR] Failed to modify firewall rules.
    echo Please right-click this batch file and select "Run as administrator".
    echo.
)

pause
