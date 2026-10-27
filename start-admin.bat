@echo off
title Hinopt Cloud Admin Console
echo ========================================================
echo   Launching Hinopt Cloud Admin Console...
echo   URL: http://localhost:5000
echo ========================================================

set "URL=http://localhost:5000"

rem Check for Microsoft Edge or Google Chrome to launch in standalone desktop app mode
set "EDGE_EXE=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
if not exist "%EDGE_EXE%" set "EDGE_EXE=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"

set "CHROME_EXE=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME_EXE%" set "CHROME_EXE=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME_EXE%" set "CHROME_EXE=%LocalAppData%\Google\Chrome\Application\chrome.exe"

if exist "%EDGE_EXE%" (
    start "" "%EDGE_EXE%" --app=%URL% --window-size=1366,860
) else if exist "%CHROME_EXE%" (
    start "" "%CHROME_EXE%" --app=%URL% --window-size=1366,860
) else (
    start %URL%
)

node apps/hinopt_admin/server.js
pause
