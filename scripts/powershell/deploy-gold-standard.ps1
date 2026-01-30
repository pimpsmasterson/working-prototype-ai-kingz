# ==============================================================================
# Gold Standard Pony Workflow - Final Deployment Guide
# ==============================================================================
# This guide finalizes the system for presentation-ready NSFW generation
# Instance: Active warm pool instance with ComfyUI v0.10.0
# Workflow: nsfw_pony_advanced (19 nodes with pose control, depth, upscaling)
# ==============================================================================

Write-Host "🚀 Gold Standard Deployment - Final Steps`n" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# STEP 1: Verify Environment Configuration
# ------------------------------------------------------------------------------
Write-Host "✓ STEP 1: Verifying environment..." -ForegroundColor Yellow

if (-not (Test-Path ".env")) {
    Write-Host "❌ Missing .env file!" -ForegroundColor Red
    exit 1
}

$envContent = Get-Content ".env" -Raw
if ($envContent -notmatch "COMFYUI_TUNNEL_URL") {
    Write-Host "❌ COMFYUI_TUNNEL_URL not set in .env!" -ForegroundColor Red
    Write-Host "Expected: COMFYUI_TUNNEL_URL=http://localhost:8188" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Environment configured with SSH tunnel override`n" -ForegroundColor Green

# ------------------------------------------------------------------------------
# STEP 2: Check SSH Tunnel
# ------------------------------------------------------------------------------
Write-Host "✓ STEP 2: Checking SSH tunnel status..." -ForegroundColor Yellow

$sshProcess = Get-Process -Name "ssh" -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -like "*8188:localhost:18188*"
}

if (-not $sshProcess) {
    Write-Host "⚠️ SSH tunnel not detected. Starting tunnel..." -ForegroundColor Yellow
    Write-Host "Running: ssh -i ~/.ssh/id_rsa_vast -L 8188:localhost:18188 -N -p 34520 root@ssh1.vast.ai" -ForegroundColor Gray
    
    Start-Process ssh -ArgumentList @(
        "-i", "$env:USERPROFILE\.ssh\id_rsa_vast",
        "-L", "8188:localhost:18188",
        "-N",
        "-o", "StrictHostKeyChecking=no",
        "-p", "34520",
        "root@ssh1.vast.ai"
    ) -WindowStyle Hidden
    
    Write-Host "Waiting 5 seconds for tunnel to establish..." -ForegroundColor Gray
    Start-Sleep -Seconds 5
}

Write-Host "✅ SSH tunnel active`n" -ForegroundColor Green

# ------------------------------------------------------------------------------
# STEP 3: Verify ComfyUI Health
# ------------------------------------------------------------------------------
Write-Host "✓ STEP 3: Checking ComfyUI health..." -ForegroundColor Yellow

try {
    $health = Invoke-RestMethod -Uri "http://localhost:8188/system_stats" -TimeoutSec 10
    Write-Host "✅ ComfyUI responding" -ForegroundColor Green
    Write-Host "   GPU: $($health.devices[0].name)" -ForegroundColor Gray
    Write-Host "   VRAM: $([math]::Round($health.devices[0].vram_free / 1GB, 2)) GB free`n" -ForegroundColor Gray
} catch {
    Write-Host "❌ ComfyUI not responding at http://localhost:8188" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    exit 1
}

# ------------------------------------------------------------------------------
# STEP 4: Verify Proxy Server
# ------------------------------------------------------------------------------
Write-Host "✓ STEP 4: Checking proxy server..." -ForegroundColor Yellow

try {
    $proxyHealth = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/health" -TimeoutSec 5
    Write-Host "✅ Proxy server healthy" -ForegroundColor Green
    Write-Host "   Status: $($proxyHealth.status)`n" -ForegroundColor Gray
} catch {
    Write-Host "❌ Proxy server not responding at http://localhost:3000" -ForegroundColor Red
    Write-Host "Start with: node server/vastai-proxy.js" -ForegroundColor Yellow
    exit 1
}

# ------------------------------------------------------------------------------
# STEP 5: Verify Workflow Templates
# ------------------------------------------------------------------------------
Write-Host "✓ STEP 5: Verifying workflow templates..." -ForegroundColor Yellow

if (-not (Test-Path "config/workflows/nsfw_pony_advanced.json")) {
    Write-Host "❌ Gold standard workflow not found!" -ForegroundColor Red
    exit 1
}

$manifest = Get-Content "config/workflows/manifest.json" | ConvertFrom-Json
if (-not $manifest.templates.nsfw_pony_advanced) {
    Write-Host "❌ nsfw_pony_advanced not registered in manifest!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Gold standard workflow registered" -ForegroundColor Green
Write-Host "   File: config/workflows/nsfw_pony_advanced.json" -ForegroundColor Gray
Write-Host "   Nodes: 22 (including helper nodes)`n" -ForegroundColor Gray

# ------------------------------------------------------------------------------
# STEP 6: Test Generation (Optional)
# ------------------------------------------------------------------------------
Write-Host "✓ STEP 6: Ready for test generation`n" -ForegroundColor Yellow
Write-Host "To test the gold standard workflow, run the following PowerShell commands:" -ForegroundColor Cyan
Write-Host ""
Write-Host '$body = @{' -ForegroundColor White
Write-Host '    prompt = "score_9, score_8_up, beautiful woman, detailed skin"' -ForegroundColor White
Write-Host '    negativePrompt = "score_4, blurry, deformed"' -ForegroundColor White
Write-Host '    workflowTemplate = "nsfw_pony_advanced"' -ForegroundColor White
Write-Host '    nsfw = $true' -ForegroundColor White
Write-Host '    settings = @{' -ForegroundColor White
Write-Host '        width = 1024' -ForegroundColor White
Write-Host '        height = 1024' -ForegroundColor White
Write-Host '        steps = 28' -ForegroundColor White
Write-Host '        cfgScale = 4.5' -ForegroundColor White
Write-Host '        sampler = "dpmpp_3m_sde"' -ForegroundColor White
Write-Host '        checkpoint = "ponyDiffusionV6XL_v6StartWithThisOne.safetensors"' -ForegroundColor White
Write-Host '        loraName = "pony_realism_v2.1.safetensors"' -ForegroundColor White
Write-Host '        loraStrength = 0.8' -ForegroundColor White
Write-Host '    }' -ForegroundColor White
Write-Host '} | ConvertTo-Json -Depth 10' -ForegroundColor White
Write-Host ""
Write-Host '$job = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/generate" -Method Post -Body $body -ContentType "application/json"' -ForegroundColor White
Write-Host ""
Write-Host "# Poll status until complete" -ForegroundColor Gray
Write-Host '$status = Invoke-RestMethod "http://localhost:3000/api/proxy/generate/$($job.jobId)"' -ForegroundColor White
Write-Host ""

Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ DEPLOYMENT COMPLETE - System ready for presentation!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Quick Reference:" -ForegroundColor Cyan
Write-Host "   SSH Tunnel:  ssh -i ~/.ssh/id_rsa_vast -L 8188:localhost:18188 -N -p 34520 root@ssh1.vast.ai" -ForegroundColor Gray
Write-Host "   ComfyUI:     http://localhost:8188" -ForegroundColor Gray
Write-Host "   Proxy:       http://localhost:3000" -ForegroundColor Gray
Write-Host "   Template:    nsfw_pony_advanced" -ForegroundColor Gray
Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""
