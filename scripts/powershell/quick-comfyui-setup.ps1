# Quick ComfyUI Setup (Minimal Provisioning)
# Purpose: Get a basic ComfyUI instance up with minimal upfront provisioning (core ComfyUI + SDXL base + VAE).
# Intended usage: Run locally to start the server (if needed) and trigger a minimal prewarm on the running proxy server.

Write-Host "🚀 Quick ComfyUI Setup (Minimal)" -ForegroundColor Cyan

# Load .env file into PowerShell environment (non-destructive)
if (-not (Test-Path ".env")) {
    Write-Host "❌ ERROR: .env file not found! Create a .env with VASTAI_API_KEY and HUGGINGFACE_HUB_TOKEN" -ForegroundColor Red
    exit 1
}
$envLines = Get-Content ".env" | Where-Object { $_ -match '^[^#].*=' }
Write-Host "   .env lines matched: $($envLines.Count)" -ForegroundColor Gray
$envLines | ForEach-Object {
    $parts = $_ -split '=', 2
    $key = $parts[0].Trim()
    $value = $parts[1].Trim()
    # Remove inline comments and surrounding quotes
    $value = $value -replace '\s+#.*$',''
    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) { if ($value.Length -ge 2) { $value = $value.Substring(1, $value.Length - 2) } }
    # Set in PowerShell env: drive for immediate availability in this process
    Set-Item -Path "env:$key" -Value $value -ErrorAction SilentlyContinue
    Write-Host "   set: $key" -ForegroundColor DarkGray
} 


# Required environment variables
$required = @('VASTAI_API_KEY','HUGGINGFACE_HUB_TOKEN')
# Debug: report which required vars are now present
foreach ($r in $required) {
    $val = (Get-Item -Path "env:$r" -ErrorAction SilentlyContinue).Value
    if (-not [string]::IsNullOrWhiteSpace($val)) { Write-Host "   $r loaded" -ForegroundColor Gray } else { Write-Host "   $r MISSING" -ForegroundColor Yellow }
}
$missing = @()
foreach ($r in $required) {
    $val = (Get-Item -Path "env:$r" -ErrorAction SilentlyContinue).Value
    if ([string]::IsNullOrWhiteSpace($val)) {
        $missing += $r
    }
}
if ($missing.Count -gt 0) {
    Write-Host "❌ Missing required env vars: $($missing -join ', ')" -ForegroundColor Red
    exit 1
}

# Optional admin key used to call admin endpoints
if (-not $env:ADMIN_API_KEY) { Write-Host "⚠️ ADMIN_API_KEY not set; you will be asked to provide it for admin endpoints" -ForegroundColor Yellow }

# Set minimal provisioning flags (informational; the server's provisioning script should honor these)
$env:COMFYUI_MINIMAL_SETUP = '1'          # Signals minimal install: core ComfyUI only
$env:WARM_POOL_SAFE_MODE = '1'            # Prevent aggressive prewarm behavior
$env:WARM_POOL_IDLE_MINUTES = '5'         # Shorter idle timeout for cost control

Write-Host "   ✅ Environment loaded. Minimal provisioning flags set." -ForegroundColor Green

# Ensure the proxy server is running (start if not)
$healthUrl = 'http://localhost:3000/api/proxy/health'
$maxWait = 60
$wait = 0
$healthy = $false
Write-Host "[1/3] Ensuring local proxy server is running..." -ForegroundColor Yellow
while ($wait -lt $maxWait -and -not $healthy) {
    try {
        $resp = Invoke-RestMethod -Uri $healthUrl -Method GET -TimeoutSec 5 -ErrorAction Stop
        if ($resp -and $resp.status -and $resp.status -ne 'down') { $healthy = $true; break }
    } catch {
        if ($wait -eq 0) {
            Write-Host "   Server not responding; attempting to start via start-ai-kings.ps1" -ForegroundColor Gray
            if (Test-Path '.\start-ai-kings.ps1') { Start-Process -NoNewWindow -FilePath 'powershell' -ArgumentList '-ExecutionPolicy Bypass -File .\start-ai-kings.ps1' }
        }
        Start-Sleep -Seconds 3
        $wait++
    }
}
if (-not $healthy) { Write-Host "❌ Server failed to become healthy after waiting" -ForegroundColor Red; exit 1 }
Write-Host "   ✅ Server healthy" -ForegroundColor Green

# Trigger a minimal prewarm (POST) to admin endpoint
Write-Host "[2/3] Triggering minimal prewarm (core ComfyUI + SDXL base + VAE)..." -ForegroundColor Yellow
$adminKey = $env:ADMIN_API_KEY
if (-not $adminKey) {
    $adminKey = Read-Host -Prompt 'Enter ADMIN_API_KEY (will not be stored)'
}
$body = @{ mode = 'minimal'; models = @('sdxl-base','sdxl-vae') } | ConvertTo-Json
try {
    $result = Invoke-RestMethod -Uri 'http://localhost:3000/api/proxy/admin/warm-pool/prewarm' -Method POST -Body $body -Headers @{ 'x-admin-key' = $adminKey; 'Content-Type' = 'application/json' } -TimeoutSec 300 -ErrorAction Stop
    Write-Host "   ✅ Prewarm request accepted" -ForegroundColor Green
    if ($result.instance) {
        Write-Host "   Instance: Contract $($result.instance.contractId) | GPU: $($result.instance.gpu_name) | Status: $($result.instance.actual_status)" -ForegroundColor Cyan
    }
} catch {
    Write-Host "   ⚠️ Prewarm request failed: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "   You can retry manually after checking server health: Invoke-RestMethod -Uri 'http://localhost:3000/api/proxy/admin/warm-pool/prewarm' -Headers @{ 'x-admin-key'='$adminKey' } -Method POST -Body '$body' -ContentType 'application/json'" -ForegroundColor Yellow
}

# Wait briefly for instance to register
Write-Host "[3/3] Waiting short window for instance SSH/ComfyUI details..." -ForegroundColor Yellow
Start-Sleep -Seconds 10
try {
    $status = Invoke-RestMethod -Uri 'http://localhost:3000/api/proxy/admin/warm-pool/status' -Method GET -Headers @{ 'x-admin-key' = $adminKey } -TimeoutSec 10 -ErrorAction Stop
    if ($status.instance -and $status.instance.comfy_url) {
        Write-Host "   ✅ ComfyUI available at: $($status.instance.comfy_url)" -ForegroundColor Green
    } elseif ($status.instance -and $status.instance.ssh_host -and $status.instance.ssh_port) {
        Write-Host "   ✅ Instance SSH: $($status.instance.ssh_host):$($status.instance.ssh_port)" -ForegroundColor Green
        Write-Host "   You can SSH using: ssh -i ~/.ssh/id_rsa_vast -p $($status.instance.ssh_port) root@$($status.instance.ssh_host)" -ForegroundColor White
    } else {
        Write-Host "   ⚠️ Instance details not yet available. Check status endpoint later." -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ⚠️ Could not query status: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""; Write-Host "✅ Quick setup completed. Next steps: open ComfyUI manager and manually install nodes/models as needed (see docs/COMFYUI_POST_SETUP.md)" -ForegroundColor Cyan

Exit 0
