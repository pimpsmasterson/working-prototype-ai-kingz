@echo off
setlocal EnableDelayedExpansion
title AI Kings - ComfyUI Tunnel
color 0A

echo.
echo   ============================================
echo      AI KINGS - OPEN COMFYUI (Double-Click)
echo   ============================================
echo.

REM --- Get SSH port ---
set PORTFILE=%~dp0OPEN-COMFY-PORT.txt
set PORT=

if exist "%PORTFILE%" (
    set /p PORT=<"%PORTFILE%"
    set PORT=!PORT: =!
)

if "%PORT%"=="" (
    echo   First time? Enter your SSH port from Vast.ai
    echo   ^(Example: 32678 - find it in your instance's SSH panel^)
    echo.
    set /p PORT="   Type the port number and press Enter: "
)

if "%PORT%"=="" (
    echo.
    echo   ERROR: No port entered. Edit OPEN-COMFY-PORT.txt and put
    echo   your SSH port on the first line ^(e.g. 32678^), then double-click again.
    echo.
    pause
    exit /b 1
)

REM Save port for next time
echo %PORT%>"%PORTFILE%"

REM --- Find SSH key ---
set KEY=%USERPROFILE%\.ssh\id_vast
if not exist "%KEY%" set KEY=%USERPROFILE%\.ssh\id_rsa_vast
if not exist "%KEY%" set KEY=%USERPROFILE%\.ssh\id_rsa
if not exist "%KEY%" set KEY=%USERPROFILE%\.ssh\id_ed25519

if not exist "%KEY%" (
    echo.
    echo   ERROR: No SSH key found. You need to add your SSH key to Vast.ai.
    echo   Run one-click-start-fixed.ps1 first - it creates the key for you.
    echo.
    pause
    exit /b 1
)

echo   Port: %PORT%
echo   Key:  %KEY%
echo.
echo   Starting tunnel... KEEP THIS WINDOW OPEN while using ComfyUI.
echo   Browser will open in 5 seconds.
echo.
echo   When done, close this window to disconnect.
echo   ============================================
echo.

REM Open browser after 5 seconds (runs in background)
start /b cmd /c "timeout /t 5 /nobreak >nul && start http://localhost:8080"

REM Run SSH tunnel (this keeps window open)
ssh -i "%KEY%" -p %PORT% -L 8080:localhost:8188 -o StrictHostKeyChecking=no -o UserKnownHostsFile=nul root@ssh2.vast.ai -N

pause
