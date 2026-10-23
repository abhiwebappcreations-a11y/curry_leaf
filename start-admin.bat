@echo off
title Hinopt Cloud Admin Console
echo ========================================================
echo   Launching Hinopt Cloud Admin Console...
echo   URL: http://localhost:5000
echo ========================================================
start http://localhost:5000
node apps/hinopt_admin/server.js
pause
