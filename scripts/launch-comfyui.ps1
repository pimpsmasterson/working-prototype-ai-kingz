# Vast.ai ComfyUI Automation Launcher
# Usage: .\launch-comfyui.ps1

param(
    [string]$Action = "launch",
    [string]$ContractId = ""
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

Write-Host "🚀 Vast.ai ComfyUI Automation" -ForegroundColor Cyan

switch ($Action) {
    "launch" {
        Write-Host "Launching automated ComfyUI instance..." -ForegroundColor Green
        & node vastai-auto.js launch
    }
    "stop" {
        if (-not $ContractId) {
            Write-Host "Usage: .\launch-comfyui.ps1 -Action stop -ContractId <id>" -ForegroundColor Red
            exit 1
        }
        Write-Host "Stopping instance $ContractId..." -ForegroundColor Yellow
        & node vastai-auto.js stop $ContractId
    }
    "status" {
        if (-not $ContractId) {
            Write-Host "Usage: .\launch-comfyui.ps1 -Action status -ContractId <id>" -ForegroundColor Red
            exit 1
        }
        Write-Host "Checking status of instance $ContractId..." -ForegroundColor Blue
        & node vastai-auto.js status $ContractId
    }
    default {
        Write-Host "Usage:" -ForegroundColor White
        Write-Host "  .\launch-comfyui.ps1 -Action launch              # Launch new instance" -ForegroundColor Gray
        Write-Host "  .\launch-comfyui.ps1 -Action stop -ContractId <id>   # Stop instance" -ForegroundColor Gray
        Write-Host "  .\launch-comfyui.ps1 -Action status -ContractId <id> # Check status" -ForegroundColor Gray
    }
}

Read-Host "Press Enter to exit"