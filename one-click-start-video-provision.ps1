# one-click-start-video-provision.ps1
# Bulletproof Video Provisioning Launcher for AI KINGS
# Version 1.9 - Fastest 4-Stage Fallback & Gist 404 Fix

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  AI KINGS - VIDEO PROVISIONER v1.9" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

# 1. Environment Check
Write-Host "[1/6] Loading Environment..." -ForegroundColor Yellow
$envPath = Join-Path $root ".env"
if (-not (Test-Path $envPath)) {
    Write-Host "  ERROR: .env file not found at $envPath" -ForegroundColor Red
    return
}

$envVars = @{}
foreach ($line in Get-Content $envPath) {
    if ($line.Trim().StartsWith("#") -or -not $line.Contains("=")) { continue }
    $eq = $line.IndexOf("=")
    if ($eq -gt 0) {
        $k = $line.Substring(0, $eq).Trim()
        $v = $line.Substring($eq + 1).Trim() -replace '\s+#.*$', ''
        if ($v.Length -ge 2 -and (($v[0] -eq '"' -and $v[-1] -eq '"') -or ($v[0] -eq "'" -and $v[-1] -eq "'"))) {
            $v = $v.Substring(1, $v.Length - 2)
        }
        $envVars[$k] = $v
        Set-Item -Path "env:$k" -Value $v -ErrorAction SilentlyContinue
    }
}

$vastKey = $env:VASTAI_API_KEY
if ([string]::IsNullOrWhiteSpace($vastKey)) {
    Write-Host "  ERROR: VASTAI_API_KEY missing in .env" -ForegroundColor Red
    return
}

$dropboxToken = $env:DROPBOX_TOKEN
if ([string]::IsNullOrWhiteSpace($dropboxToken)) {
    Write-Host "  WARNING: DROPBOX_TOKEN missing. Videos will not sync to cloud automatically." -ForegroundColor Yellow
}

Write-Host "  OK" -ForegroundColor Green

# 2. Search for GPUs (with Accelerated 4-Stage Persistence)
$vastApiBase = "https://console.vast.ai/api/v0"
$headers = @{
    "Authorization" = "Bearer $vastKey"
    "Content-Type"  = "application/json"
}

$candidates = New-Object System.Collections.Generic.List[PSCustomObject]
$retryCount = 0

while ($candidates.Count -eq 0) {
    # 4-STAGE DYNAMIC LOGIC (FASTEST ENGAGEMENT)
    $midCap = 0.85
    $bandwidthFloor = 2000
    $reliabilityFloor = 0.90
    $diskFloor = 400
    
    if ($retryCount -lt 2) {
        # Try 1, 2: Elite performance
        $budgetCap = 0.55
        $stageText = "ELITE"
    }
    elseif ($retryCount -lt 3) {
        # Try 3: Market Relaxed
        $budgetCap = 0.75
        $stageText = "MARKET RELAXED"
        Write-Host "  [STAGE 2] Relaxing price target to `$0.75 (Try 3)..." -ForegroundColor Cyan
    }
    elseif ($retryCount -lt 4) {
        # Try 4: High Speed Budget
        $budgetCap = 0.65
        $bandwidthFloor = 1000
        $stageText = "SPEED BUDGET"
        Write-Host "  [STAGE 3] Relaxing bandwidth to 1Gbps floor (Try 4)..." -ForegroundColor Cyan
    }
    else {
        # Try 5+: Ultimate Catch (Requested fallback behavior)
        $budgetCap = 0.70
        $bandwidthFloor = 500
        $reliabilityFloor = 0.85
        $diskFloor = 300
        $stageText = "ULTIMATE CATCH"
        Write-Host "  [STAGE 4] Ultimate Catch Engaged: 16GB+ @ `$0.70, 500Mbps, 85% Reliability..." -ForegroundColor Magenta
    }

    Write-Host "[2/6] Searching for optimal GPUs on Vast.ai (Attempt $($retryCount + 1) - $stageText)..." -ForegroundColor Yellow

    $searchParams = @{
        order = , @("dph_total", "asc")
        type  = "ask"
    }
    $searchBody = $searchParams | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri "$vastApiBase/bundles/" -Method Post -Headers $headers -Body $searchBody -TimeoutSec 30
        $offers = $response.offers
    }
    catch {
        Write-Host "  ERROR: Failed to query Vast.ai API. Retrying in 10s..." -ForegroundColor Red
        Start-Sleep -Seconds 10
        continue
    }

    if ($null -ne $offers -and $offers.Count -gt 0) {
        foreach ($o in $offers) {
            # Basic filters
            if (-not $o.rentable -or $o.rented) { continue }
            if ($o.disk_space -lt $diskFloor) { continue } 

            # Reliability Hardening
            $reliability = if ($null -eq $o.reliability) { 0 } else { [float]$o.reliability }
            $verification = if ($null -eq $o.verification) { "unverified" } else { $o.verification }
            $isVerified = ($verification -eq "verified") -or ($o.verified -eq $true)

            if (-not $isVerified) { continue }
            if ($reliability -lt $reliabilityFloor) { continue }

            # Bandwidth check (Dynamic Floor)
            $bandwidthOk = $false
            if ($o.internet_down_cost_per_tb -le 0.1 -or $o.inet_down -ge $bandwidthFloor) {
                $bandwidthOk = $true
            }
            if (-not $bandwidthOk) { continue }

            $numGpus = if ($null -eq $o.num_gpus) { 1 } else { $o.num_gpus }
            $totalVram = $o.gpu_ram * $numGpus
            $price = $o.dph_total

            $tier = ""
            if ($totalVram -ge 40000 -and $price -le $midCap) {
                $tier = "Mid-Cost (40GB+)"
            }
            elseif ($totalVram -ge 16000 -and $price -le $budgetCap) {
                $tier = "Budget (16GB+)"
            }

            if ($tier -ne "") {
                $candidates.Add([PSCustomObject]@{
                        Index          = $candidates.Count
                        ID             = $o.id
                        GPU            = $o.gpu_name
                        VRAM           = "$($totalVram / 1000)GB"
                        Price          = "$($price.ToString('F2'))/hr"
                        PriceRaw       = $price
                        Bandwidth      = "$($o.inet_down) Mbps"
                        BandwidthRaw   = $o.inet_down
                        Tier           = $tier
                        Reliability    = "$([Math]::Round($reliability * 100, 1))%"
                        ReliabilityRaw = $reliability
                        Verification   = $verification
                    })
            }
        }
    }

    if ($candidates.Count -eq 0) {
        $nextSleep = if ($retryCount -lt 4) { 10 } else { 30 }
        Write-Host "  No matches yet. Waiting $($nextSleep)s for market update..." -ForegroundColor Gray
        $retryCount++
        Start-Sleep -Seconds $nextSleep
    }
}

# Sort by Tier (Mid-Cost first), then Bandwidth (Highest first), then Reliability (Highest first), then Price (Cheapest first)
$candidates = $candidates | Sort-Object @{Expression = { $_.Tier }; Descending = $true }, 
@{Expression = { $_.BandwidthRaw }; Descending = $true }, 
@{Expression = { $_.ReliabilityRaw }; Descending = $true }, 
@{Expression = { $_.PriceRaw }; Ascending = $true }

Write-Host "  Found $($candidates.Count) matching GPUs." -ForegroundColor Green
Write-Host ""
$candidates | Format-Table -AutoSize
Write-Host ""

# 3. Automatic Selection
Write-Host "  Selecting best candidate automatically..." -ForegroundColor Yellow
$selectedIndex = 0
$selectedOffer = $candidates[$selectedIndex]
Write-Host "  Selected: $($selectedOffer.GPU) ($($selectedOffer.ID)) at $($selectedOffer.Reliability) reliability" -ForegroundColor Cyan

# 4. Rent GPU
Write-Host "[3/6] Renting GPU..." -ForegroundColor Yellow
# Using robust base raw URL to avoid Gist filename 404s
$provisionScriptUrl = "https://gist.githubusercontent.com/pimpsmasterson/cf06441f0ea9b657a459227d0334f2d0/raw/"

$rentBody = @{
    image        = "vastai/comfy:v0.10.0-cuda-12.9-py312"
    runtype      = "ssh"
    target_state = "running"
    onstart      = "bash -lc 'curl -fsSL $provisionScriptUrl -o /tmp/provision.sh && chmod +x /tmp/provision.sh && bash /tmp/provision.sh'"
    disk         = 400
    env          = @{
        DROPBOX_TOKEN  = $dropboxToken
        VASTAI_API_KEY = $vastKey
        COMFYUI_ARGS   = "--listen 0.0.0.0 --port 8188 --enable-cors-header"
    }
} | ConvertTo-Json

try {
    $rentResp = Invoke-RestMethod -Uri "$vastApiBase/asks/$($selectedOffer.ID)/" -Method Put -Headers $headers -Body $rentBody
    $contractId = $rentResp.new_contract
    Write-Host "  Success! Contract ID: $contractId" -ForegroundColor Green
}
catch {
    Write-Host "  ERROR: Rental failed." -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Gray
    return
}

# 5. Wait for Startup
Write-Host "[4/6] Waiting for instance to start..." -ForegroundColor Yellow
$instanceAddress = ""
$sshPort = 0

for ($i = 0; $i -lt 30; $i++) {
    try {
        $inst = Invoke-RestMethod -Uri "$vastApiBase/instances/$contractId/" -Method Get -Headers $headers
        $status = $inst.actual_status
        $ip = $inst.public_ipaddr
        $port = $inst.ssh_port

        if ($status -eq 'running' -and $ip) {
            $instanceAddress = $ip
            $sshPort = $port
            Write-Host "  OK: Instance is running at $($instanceAddress):$($sshPort)" -ForegroundColor Green
            break
        }
        Write-Host "  Waiting... (Status: $status / Progress: $($inst.status_msg))" -ForegroundColor Gray
    }
    catch { }
    Start-Sleep -Seconds 10
}

if ($instanceAddress -eq "") {
    Write-Host "  ERROR: Instance failed to start in time. Check Vast.ai console." -ForegroundColor Red
    return
}

# 6. Provisioning Status
Write-Host "[5/6] Provisioning is in progress. Check ComfyUI in a few minutes." -ForegroundColor Yellow
Write-Host "  SSH Access: ssh -p $($sshPort) root@$($instanceAddress)" -ForegroundColor Gray
Write-Host "  ComfyUI: http://$($instanceAddress):8188" -ForegroundColor Cyan
Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  PROVISIONING STARTED" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

# 7. Safe Destruction Prompt
Write-Host "[6/6] Safety Control" -ForegroundColor Yellow
Write-Host "This instance will remain active until manually destroyed." -ForegroundColor Red
Write-Host "Use .\destroy-instance.ps1 to terminate when finished." -ForegroundColor Cyan
Write-Host ""
