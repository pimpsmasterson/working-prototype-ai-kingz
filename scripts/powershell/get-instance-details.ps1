# Get current Vast.ai instance details
# This will help you get the SSH host and port for uploading models

Write-Host "Getting current Vast.ai instance details..." -ForegroundColor Cyan

# Load environment variables
$env:VASTAI_API_KEY = "4986d1c01dc3eb354816dfe693384b7f81fe5f4bf048ee78db68f203d4101360"
$env:ADMIN_API_KEY = "secure_admin_key_change_me"

# Get running instances
try {
    $instances = Invoke-RestMethod -Uri "https://console.vast.ai/api/v0/instances" -Method GET -Headers @{
        "Accept" = "application/json"
        "Authorization" = "Bearer $env:VASTAI_API_KEY"
    }

    $runningInstances = $instances.instances | Where-Object { $_.actual_status -eq "running" }

    if ($runningInstances.Count -eq 0) {
        Write-Host "❌ No running instances found" -ForegroundColor Red
        exit 1
    }

    Write-Host "Running instances:" -ForegroundColor Green
    foreach ($inst in $runningInstances) {
        Write-Host "  ID: $($inst.id)" -ForegroundColor Cyan
        Write-Host "  Host: $($inst.ssh_host)" -ForegroundColor Cyan
        Write-Host "  Port: $($inst.ssh_port)" -ForegroundColor Cyan
        Write-Host "  Status: $($inst.actual_status)" -ForegroundColor Green
        Write-Host "  Uptime: $($inst.uptime)" -ForegroundColor Gray
        Write-Host ""
    }

    # Export the first running instance details for use in other scripts
    $firstInstance = $runningInstances[0]
    Write-Host "Using first instance for upload scripts:" -ForegroundColor Yellow
    Write-Host "  SSH_HOST=$($firstInstance.ssh_host)" -ForegroundColor Yellow
    Write-Host "  SSH_PORT=$($firstInstance.ssh_port)" -ForegroundColor Yellow

    # Create a temp file with instance details for other scripts
    $instanceDetails = @{
        id = $firstInstance.id
        ssh_host = $firstInstance.ssh_host
        ssh_port = $firstInstance.ssh_port
    } | ConvertTo-Json

    $instanceDetails | Out-File -FilePath "$PSScriptRoot\current_instance.json" -Encoding UTF8
    Write-Host "💾 Instance details saved to current_instance.json" -ForegroundColor Green

} catch {
    Write-Host "❌ Failed to get instances: $($_.Exception.Message)" -ForegroundColor Red
}