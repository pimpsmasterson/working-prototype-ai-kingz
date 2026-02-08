# destroy-instance.ps1
# Safe Instance Destruction for AI KINGS

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

Write-Host ""
Write-Host "========================================" -ForegroundColor Red
Write-Host "  AI KINGS - SAFE INSTANCE DESTRUCTOR" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""

# 1. Load Environment
if (-not (Test-Path ".env")) {
    Write-Host "  ERROR: .env not found." -ForegroundColor Red
    exit 1
}

$vastKey = ""
Get-Content ".env" | Where-Object { $_ -match '^VASTAI_API_KEY=' } | ForEach-Object {
    $vastKey = $_.Split('=')[1].Trim().Trim('"').Trim("'")
}

if ([string]::IsNullOrWhiteSpace($vastKey)) {
    Write-Host "  ERROR: VASTAI_API_KEY missing in .env" -ForegroundColor Red
    exit 1
}

# 2. Get active instances
Write-Host "[1/2] Fetching active instances from Vast.ai..." -ForegroundColor Yellow
$vastApiBase = "https://console.vast.ai/api/v0"
$headers = @{
    "Authorization" = "Bearer $vastKey"
}

try {
    $instances = Invoke-RestMethod -Uri "$vastApiBase/instances/" -Method Get -Headers $headers
    $active = $instances.instances | Where-Object { $_.actual_status -ne "deleted" }
}
catch {
    Write-Host "  ERROR: Failed to connect to Vast.ai." -ForegroundColor Red
    exit 1
}

if ($active.Count -eq 0) {
    Write-Host "  No active instances found." -ForegroundColor Green
    exit 0
}

Write-Host "  Found $($active.Count) active instances:" -ForegroundColor Gray
$i = 0
$active | ForEach-Object {
    Write-Host "  [$i] ID: $($_.id) | GPU: $($_.gpu_name) | Status: $($_.actual_status)" -ForegroundColor White
    $i++
}
Write-Host ""

# 3. Selection and Confirmation
$selectedIndex = -1
while ($selectedIndex -lt 0 -or $selectedIndex -ge $active.Count) {
    $userInput = Read-Host "Select instance to DESTROY (0 to $($active.Count - 1)) or 'q' to quit"
    if ($userInput -eq 'q') { exit 0 }
    if ($null -ne ($userInput -as [int])) {
        $selectedIndex = [int]$userInput
    }
}

$selectedInstance = $active[$selectedIndex]
$contractId = $selectedInstance.id

Write-Host ""
Write-Host "WARNING: You are about to DESTROY instance $contractId ($($selectedInstance.gpu_name))" -ForegroundColor Red
Write-Host "This will STOP all billing and delete all non-synced data on the GPU." -ForegroundColor Red
$confirm = Read-Host "Are you absolutely sure? Type 'YES' to confirm"

if ($confirm -eq "YES") {
    Write-Host "Terminating instance $contractId..." -ForegroundColor Red
    try {
        $resp = Invoke-RestMethod -Uri "$vastApiBase/instances/$contractId/" -Method Delete -Headers $headers
        Write-Host "  Done. Instance scheduled for deletion." -ForegroundColor Green
    }
    catch {
        Write-Host "  ERROR: Termination failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "Aborted. No changes made." -ForegroundColor Yellow
}

Write-Host ""
