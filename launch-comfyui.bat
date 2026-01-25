@echo off
REM Vast.ai ComfyUI Automation Launcher
REM Usage: launch-comfyui.bat

cd /d "%~dp0"
echo 🚀 Launching automated ComfyUI instance on Vast.ai...
node vastai-auto.js launch
pause