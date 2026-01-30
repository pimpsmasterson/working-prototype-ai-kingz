# AI Kings - Automatic SSH Tunnel to ComfyUI
# This script creates an SSH tunnel to the active Vast.ai instance

Write-Host "Starting SSH tunnel to ComfyUI..." -ForegroundColor Cyan

# Get the active instance SSH details
$headers = @{ 'Authorization' = "Bearer $env:VASTAI_API_KEY" }
try {
    $response = Invoke-RestMethod -Uri 'https://console.vast.ai/api/v0/instances/?owner=me' -Headers $headers -Method GET
    $inst = $response.instances | Where-Object { $_.actual_status -eq 'running' } | Select-Object -First 1
    
    if (-not $inst) {
        Write-Host "No running Vast.ai instance found!" -ForegroundColor Red
        Write-Host "Start a prewarm first: Invoke-RestMethod -Uri 'http://localhost:3000/api/proxy/admin/warm-pool/prewarm' -Headers @{ 'x-admin-key'='secure_admin_key_change_me' } -Method POST" -ForegroundColor Yellow
        exit 1
    }
    
    $sshHost = $inst.ssh_host
    $sshPort = $inst.ssh_port
    
    Write-Host "Instance ID: $($inst.id)" -ForegroundColor Green
    Write-Host "SSH Host: $sshHost" -ForegroundColor Green
    Write-Host "SSH Port: $sshPort" -ForegroundColor Green
    Write-Host ""
    Write-Host "Creating tunnel... (Keep this window open!)" -ForegroundColor Yellow
    Write-Host "Access ComfyUI at: http://localhost:8188" -ForegroundColor Cyan
    Write-Host ""
    
    # Create the tunnel (this will block and keep running)
    ssh -i "$env:USERPROFILE\.ssh\id_rsa_vast" -p $sshPort -N -L 8188:localhost:8188 root@$sshHost
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Make sure VASTAI_API_KEY environment variable is set!" -ForegroundColor Yellow
    exit 1
}
