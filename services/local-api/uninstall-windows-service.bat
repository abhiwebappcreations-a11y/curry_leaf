@echo off
title Hinopt POS - Uninstall Windows Service

:: Auto-elevate to Administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

echo.
echo  Stopping and removing Hinopt POS API Windows Service...
echo.

node uninstall-service.js

echo.
pause
