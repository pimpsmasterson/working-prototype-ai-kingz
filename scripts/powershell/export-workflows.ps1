# Export all workflows from running ComfyUI instance to local config/workflows folder
# Usage: .\export-workflows.ps1

Write-Host "Exporting workflows from ComfyUI..." -ForegroundColor Cyan

# Ensure tunnel is running (check if localhost:8188 is accessible)
try {
    $testConnection = Invoke-WebRequest -Uri "http://localhost:8188/system_stats" -Method GET -TimeoutSec 3 -UseBasicParsing
    Write-Host "✓ ComfyUI connection verified" -ForegroundColor Green
} catch {
    Write-Host "✗ Cannot reach ComfyUI at localhost:8188" -ForegroundColor Red
    Write-Host "Make sure the SSH tunnel is running: .\start-tunnel.bat" -ForegroundColor Yellow
    exit 1
}

# Get current workflow from ComfyUI (if one is loaded)
Write-Host "Fetching current workflow..." -ForegroundColor Cyan

# Create workflows directory if it doesn't exist
$workflowDir = "$PSScriptRoot\config\workflows"
if (-not (Test-Path $workflowDir)) {
    New-Item -ItemType Directory -Path $workflowDir -Force | Out-Null
    Write-Host "Created workflows directory: $workflowDir" -ForegroundColor Green
}

# Prompt user to save workflow in ComfyUI first
Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "INSTRUCTIONS:" -ForegroundColor Yellow
Write-Host "1. Go to ComfyUI web interface (http://localhost:8188)" -ForegroundColor White
Write-Host "2. Click 'Save (API Format)' button in the menu" -ForegroundColor White
Write-Host "3. Right-click on the canvas and select 'Save Workflow'" -ForegroundColor White
Write-Host "4. OR use the 'Export' button and copy the JSON" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

# Offer to save pasted workflow
Write-Host "Paste your workflow JSON below (press Ctrl+Z then Enter when done):" -ForegroundColor Cyan
$workflowJson = @()
while ($line = Read-Host) {
    if ($line -match '\x1a') { break }  # Ctrl+Z
    $workflowJson += $line
}

if ($workflowJson.Count -gt 0) {
    $workflowContent = $workflowJson -join "`n"
    
    # Validate JSON
    try {
        $jsonTest = $workflowContent | ConvertFrom-Json
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $filename = "workflow_$timestamp.json"
        $filepath = Join-Path $workflowDir $filename
        
        Set-Content -Path $filepath -Value $workflowContent -Encoding UTF8
        Write-Host "✓ Workflow saved: $filename" -ForegroundColor Green
        Write-Host "Location: $filepath" -ForegroundColor Cyan
    } catch {
        Write-Host "✗ Invalid JSON format: $_" -ForegroundColor Red
    }
} else {
    Write-Host "No workflow provided. Manual steps required:" -ForegroundColor Yellow
    Write-Host "1. In ComfyUI, click the gear icon → 'Export (API)'" -ForegroundColor White
    Write-Host "2. Save the JSON file to: $workflowDir" -ForegroundColor White
}

Write-Host ""
Write-Host "All workflows in folder:" -ForegroundColor Cyan
Get-ChildItem -Path $workflowDir -Filter "*.json" | ForEach-Object {
    Write-Host "  - $($_.Name)" -ForegroundColor White
}
