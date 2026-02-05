@echo off
title AI Kings - Create Key
color 0B

cd /d "%~dp0"

echo.
echo ========================================
echo   AI Kings - Creating Your SSH Key
echo ========================================
echo.
echo   This will:
echo   1. Create an SSH key on your computer
echo   2. Add it to your Vast.ai account automatically
echo.
echo   You only need to do this ONCE.
echo.
echo ========================================
echo.

node setup-key.js

echo.
pause
