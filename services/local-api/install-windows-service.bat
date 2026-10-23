@echo off
:: ============================================================
::  Hinopt POS API - Install as Windows Service
::  Run this ONCE on the client's PC to set up auto-start.
:: ============================================================
title Hinopt POS - Install Windows Service

:: ── Auto-elevate to Administrator if not already ──────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

:: ── Move to the script directory ──────────────────────────────
cd /d "%~dp0"

echo.
echo  ============================================================
echo    Hinopt POS API - Windows Service Installer
echo  ============================================================
echo.
echo  Step 1: Building production bundle...
echo.

call npm run build
if %errorlevel% neq 0 (
    echo.
    echo  ERROR: Build failed. Fix TypeScript errors and try again.
    pause
    exit /b 1
)

echo.
echo  Step 2: Registering Windows Service (HinoptPosApi)...
echo.

node install-service.js

echo.
echo  ============================================================
echo    Done! The Hinopt POS API will now start automatically
echo    every time this PC boots - no manual action needed.
echo.
echo    To manage:  Open services.msc and look for HinoptPosApi
echo    To remove:  Run uninstall-windows-service.bat as Admin
echo  ============================================================
echo.
pause
