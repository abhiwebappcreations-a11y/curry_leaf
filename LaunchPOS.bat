@echo off
title Hinopt POS Complete Launcher
echo ========================================================
echo   Launching Hinopt Restaurant POS...
echo   1. Starting Local API Backend Server (Port 4000)...
echo   2. Opening Windows Counter POS App...
echo ========================================================

:: Start Local API in the background if not already running
netstat -ano | findstr :4000 >nul 2>&1
if %errorlevel% neq 0 (
    start "Hinopt POS Local Server" /min cmd /c "npm run dev:api"
    echo Local API server starting...
    timeout /t 3 /nobreak >nul
) else (
    echo Local API server is already running on port 4000.
)

:: Launch Counter POS Application
start "" "CounterPOS.exe"

exit
