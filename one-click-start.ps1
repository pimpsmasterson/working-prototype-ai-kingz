# AI KINGS ONE-CLICK START - Start server and rent a GPU instance (prewarm)
# All output is ASCII so the script runs on any Windows PowerShell encoding.

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  AI KINGS ONE-CLICK START" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- Step 1: Prerequisites ---
Write-Host "[1/6] Prerequisites..." -ForegroundColor Yellow
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "  ERROR: Node.js not installed. Get it from https://nodejs.org/" -ForegroundColor Red
    exit 1
}
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "  ERROR: npm not installed." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path ".env")) {
    Write-Host "  ERROR: .env not found. Copy from .env.example and fill in keys." -ForegroundColor Red
    exit 1
}
Write-Host "  OK Node $(node -v), npm $(npm -v), .env found" -ForegroundColor Green

# --- Step 2: Load .env (strip quotes so admin key works) ---
Write-Host "[2/6] Loading .env..." -ForegroundColor Yellow
Get-Content ".env" | Where-Object { $_ -match '^[^#].*=' } | ForEach-Object {
    $line = $_.Trim()
    $idx = $line.IndexOf('=')
    if ($idx -gt 0) {
        $key = $line.Substring(0, $idx).Trim()
        $value = $line.Substring($idx + 1).Trim() -replace '\s+#.*$', ''
        if ($value.Length -ge 2 -and (($value[0] -eq '"' -and $value[-1] -eq '"') -or ($value[0] -eq "'" -and $value[-1] -eq "'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        Set-Item -Path "env:$key" -Value $value -ErrorAction SilentlyContinue
    }
}
$required = @('VASTAI_API_KEY', 'ADMIN_API_KEY')
$missing = $required | Where-Object { [string]::IsNullOrWhiteSpace((Get-Item "env:$_" -ErrorAction SilentlyContinue).Value) }
if ($missing) {
    Write-Host "  ERROR: Missing in .env: $($missing -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host "  OK Env loaded" -ForegroundColor Green

# --- Step 3: Free ports (optional; use procId not pid) ---
Write-Host "[3/6] Freeing ports 3000, 8080, 8188..." -ForegroundColor Yellow
foreach ($port in @(3000, 8080, 8188)) {
    try {
        $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        if ($conn) {
            $conn | Select-Object -ExpandProperty OwningProcess -Unique | ForEach-Object {
                $procId = $_
                $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
                if ($p) { Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue; Write-Host "  Stopped PID $procId on port $port" -ForegroundColor Gray }
            }
        }
    } catch { }
}
Start-Sleep -Seconds 2
Write-Host "  OK" -ForegroundColor Green

# --- Step 4: Start server (PM2 or node) ---
Write-Host "[4/6] Starting server..." -ForegroundColor Yellow
$usePm2 = $false
if (Get-Command pm2 -ErrorAction SilentlyContinue) {
    if (Test-Path "config\ecosystem.config.js") {
        pm2 delete vastai-proxy 2>$null
        $out = pm2 start config/ecosystem.config.js --update-env 2>&1
        pm2 save 2>$null
        if ($LASTEXITCODE -eq 0 -and $out -notmatch 'error|Error|ERR') {
            $usePm2 = $true
            Write-Host "  OK PM2 started vastai-proxy" -ForegroundColor Green
        }
    }
}
if (-not $usePm2) {
    $envHash = @{}
    Get-ChildItem env: | ForEach-Object { $envHash[$_.Name] = $_.Value }
    $job = Start-Job -ScriptBlock {
        param($dir, $envHash)
        Set-Location $dir
        foreach ($k in $envHash.Keys) { Set-Item -Path "env:$k" -Value $envHash[$k] }
        & node server/vastai-proxy.js
    } -ArgumentList (Get-Location).Path, $envHash
    Write-Host "  OK Server started (Job $($job.Id))" -ForegroundColor Green
}
Start-Sleep -Seconds 5

# --- Step 5: Health check ---
Write-Host "[5/6] Waiting for server health..." -ForegroundColor Yellow
$healthy = $false
for ($i = 1; $i -le 30; $i++) {
    try {
        $r = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/health" -Method GET -TimeoutSec 5
        if ($r.ok) { $healthy = $true; break }
    } catch { }
    if ($i % 5 -eq 0) { Write-Host "  Waiting... $i/30" -ForegroundColor Gray }
    Start-Sleep -Seconds 2
}
if (-not $healthy) {
    Write-Host "  ERROR: Server did not become healthy. Check: pm2 logs vastai-proxy" -ForegroundColor Red
    exit 1
}
Write-Host "  OK Server healthy" -ForegroundColor Green

# --- Step 6: Trigger prewarm (RENT + provision on server) ---
Write-Host "[6/6] Triggering prewarm (rent GPU instance)..." -ForegroundColor Yellow
try {
    $prewarm = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool/prewarm" `
        -Method POST -Headers @{ "x-admin-key" = $env:ADMIN_API_KEY } -TimeoutSec 15
    if ($prewarm.status -eq 'started') {
        Write-Host "  OK Prewarm started. Contract: $($prewarm.instance.contractId)" -ForegroundColor Green
    } elseif ($prewarm.status -eq 'already_present' -or $prewarm.status -eq 'already_prewarming') {
        Write-Host "  OK Instance already present or prewarm in progress." -ForegroundColor Green
        if ($prewarm.instance) { Write-Host "  Contract: $($prewarm.instance.contractId)" -ForegroundColor Gray }
    } else {
        Write-Host "  Prewarm status: $($prewarm.status)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Prewarm request failed: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  You can prewarm from the admin dashboard: http://localhost:3000/admin/warm-pool" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  READY" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Studio:    http://localhost:3000/pages/studio.html" -ForegroundColor White
Write-Host "  Admin:     http://localhost:3000/admin/warm-pool" -ForegroundColor White
Write-Host "  Health:    http://localhost:3000/api/proxy/health" -ForegroundColor White
Write-Host ""
if ($usePm2) {
    Write-Host "  Logs: pm2 logs vastai-proxy" -ForegroundColor Gray
}
Write-Host ""
