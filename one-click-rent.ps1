# one-click-rent.ps1
# Single script: restart server (loads latest code + .env), clear stale state, rent GPU. No manual steps.
# Use only ASCII so it runs on any Windows PowerShell.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  AI KINGS - ONE CLICK RENT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Prerequisites
Write-Host "[1/7] Prerequisites..." -ForegroundColor Yellow
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "  ERROR: Node.js not installed." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path ".env")) {
    Write-Host "  ERROR: .env not found." -ForegroundColor Red
    exit 1
}
Write-Host "  OK" -ForegroundColor Green

# 2. Load .env (strip quotes)
Write-Host "[2/7] Loading .env..." -ForegroundColor Yellow
Get-Content ".env" | Where-Object { $_ -match '^[^#].*=' } | ForEach-Object {
    $line = $_.Trim()
    $eq = $line.IndexOf('=')
    if ($eq -gt 0) {
        $k = $line.Substring(0, $eq).Trim()
        $v = $line.Substring($eq + 1).Trim() -replace '\s+#.*$', ''
        if ($v.Length -ge 2 -and (($v[0] -eq '"' -and $v[-1] -eq '"') -or ($v[0] -eq "'" -and $v[-1] -eq "'"))) {
            $v = $v.Substring(1, $v.Length - 2)
        }
        Set-Item -Path "env:$k" -Value $v -ErrorAction SilentlyContinue
    }
}
foreach ($r in @('VASTAI_API_KEY','ADMIN_API_KEY')) {
    if ([string]::IsNullOrWhiteSpace((Get-Item "env:$r" -ErrorAction SilentlyContinue).Value)) {
        Write-Host "  ERROR: Missing $r in .env" -ForegroundColor Red
        exit 1
    }
}
# Keep COMFYUI_PROVISION_SCRIPT from .env (server loads .env from disk on restart)
Write-Host "  OK" -ForegroundColor Green

# 3. Free ports
Write-Host "[3/7] Freeing ports..." -ForegroundColor Yellow
foreach ($port in @(3000, 8080, 8188)) {
    try {
        $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        if ($conn) {
            foreach ($procId in ($conn | Select-Object -ExpandProperty OwningProcess -Unique)) {
                $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
                if ($p) { Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue }
            }
        }
    } catch { }
}
Start-Sleep -Seconds 2
Write-Host "  OK" -ForegroundColor Green

# 4. Restart server (loads latest code and .env; ensures your provision script is used)
Write-Host "[4/7] Restarting server (latest code + .env)..." -ForegroundColor Yellow
$usePm2 = $false
if ((Get-Command pm2 -ErrorAction SilentlyContinue) -and (Test-Path "config\ecosystem.config.js")) {
    try {
        pm2 delete vastai-proxy 2>$null
    } catch {
        Write-Host "  (pm2 delete failed/skipped)" -ForegroundColor Gray
    }
    try {
        pm2 start config/ecosystem.config.js --update-env 2>$null
        pm2 save 2>$null
        $usePm2 = $true
    } catch {
        Write-Host "  (pm2 start failed)" -ForegroundColor Yellow
    }
}
if (-not $usePm2) {
    $envHash = @{}
    Get-ChildItem env: | ForEach-Object { $envHash[$_.Name] = $_.Value }
    Start-Job -ScriptBlock {
        param($dir, $envHash)
        Set-Location $dir
        foreach ($key in $envHash.Keys) { Set-Item "env:$key" -Value $envHash[$key] }
        & node server/vastai-proxy.js
    } -ArgumentList (Get-Location).Path, $envHash | Out-Null
}
Start-Sleep -Seconds 5
Write-Host "  OK" -ForegroundColor Green

# 5. Health
Write-Host "[5/7] Waiting for server..." -ForegroundColor Yellow
$ok = $false
for ($i = 1; $i -le 30; $i++) {
    try {
        $r = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/health" -Method GET -TimeoutSec 5
        if ($r.ok) { $ok = $true; break }
    } catch { }
    Start-Sleep -Seconds 2
}
if (-not $ok) {
    Write-Host "  ERROR: Server not healthy. Check: pm2 logs vastai-proxy" -ForegroundColor Red
    exit 1
}
Write-Host "  OK" -ForegroundColor Green

# 6. Reset state so we don't get "already present" from stale DB
Write-Host "[6/7] Clearing stale instance state..." -ForegroundColor Yellow
try {
    Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/reset-state" `
        -Method POST -Headers @{ "x-admin-key" = $env:ADMIN_API_KEY } -ContentType "application/json" -Body "{}" -TimeoutSec 10 | Out-Null
    Write-Host "  OK" -ForegroundColor Green
} catch {
    Write-Host "  Warning: reset-state failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 7. Prewarm = actually rent
Write-Host "[7/7] Renting GPU from Vast.ai (prewarm)..." -ForegroundColor Yellow
try {
    $prewarm = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool/prewarm" `
        -Method POST -Headers @{ "x-admin-key" = $env:ADMIN_API_KEY } -ContentType "application/json" -Body "{}" -TimeoutSec 600
    if ($prewarm.status -eq 'started') {
        Write-Host "  OK Rented. Contract: $($prewarm.instance.contractId)" -ForegroundColor Green
    } elseif ($prewarm.status -eq 'already_present' -or $prewarm.status -eq 'already_prewarming') {
        Write-Host "  OK Instance already present. Contract: $($prewarm.instance.contractId)" -ForegroundColor Green
    } else {
        Write-Host "  Status: $($prewarm.status)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Check Vast.ai and .env (VASTAI_API_KEY, ADMIN_API_KEY)." -ForegroundColor Gray
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  DONE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Studio: http://localhost:3000/pages/studio.html" -ForegroundColor White
Write-Host "  Admin:  http://localhost:3000/admin/warm-pool" -ForegroundColor White
Write-Host "  Logs:   pm2 logs vastai-proxy" -ForegroundColor Gray
Write-Host ""
