# One-Click: Rent (Prewarm) but DO NOT Provision
Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   AI KINGS RENT + PREWARM (NO PROVISION)                      ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/7] Checking prerequisites..." -ForegroundColor Yellow
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "❌ ERROR: Node.js is not installed!" -ForegroundColor Red
    exit 1
}

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "❌ ERROR: npm is not installed!" -ForegroundColor Red
    exit 1
}

Write-Host "   ✅ Node.js: $(node --version)" -ForegroundColor Green

# Load .env if present (silently)
if (Test-Path ".env") {
    Get-Content ".env" | Where-Object { $_ -match '^[^#].*=' } | ForEach-Object {
        $parts = $_ -split '=', 2
        $key = $parts[0].Trim()
        $value = $parts[1].Trim()
        Set-Item -Path "env:$key" -Value $value
    }
}

# Require only these for a rent/prewarm operation
$requiredVars = @('VASTAI_API_KEY','ADMIN_API_KEY')
$missingVars = @()
foreach ($var in $requiredVars) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($var))) { $missingVars += $var }
}
if ($missingVars.Count -gt 0) {
    Write-Host "❌ Missing environment variables: $($missingVars -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host "   ✅ Required env vars present" -ForegroundColor Green

Write-Host "[2/7] Minimal cleanup (ports/processes)" -ForegroundColor Yellow
$usedPorts = @(3000,8080,8188)
foreach ($port in $usedPorts) {
    $portProcesses = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Listen' } | ForEach-Object { Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue }
    if ($portProcesses) { $portProcesses | Stop-Process -ErrorAction SilentlyContinue }
}

Write-Host "[2.5/7] Clearing database completely..." -ForegroundColor Yellow
$dbClearCmd = @"
const db = require('./server/db');
const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');

// Reset the database state but preserve desiredSize for warm pool
const state = db.getState();
state.instance = null;
state.lastAction = null;
state.isPrewarming = false;
state.safeMode = false;  // Ensure safe mode is disabled
db.saveState(state);

// Also clear any jobs that might be stuck
try {
    db.db.exec('DELETE FROM generated_content');
    db.db.exec('DELETE FROM admin_audit');
} catch (e) {
    // Ignore errors if tables don't exist
}

console.log('Database completely cleared and reset');
"@
& node -e $dbClearCmd

Write-Host "[3/7] Ensure SSH key for future manual SSH (id_rsa_vast)" -ForegroundColor Yellow
$sshDir = Join-Path $env:USERPROFILE '.ssh'
if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir -Force | Out-Null }
$privateKeyPath = Join-Path $sshDir 'id_rsa_vast'
if (-not (Test-Path $privateKeyPath)) {
    if (Get-Command ssh-keygen -ErrorAction SilentlyContinue) {
        & ssh-keygen -t rsa -b 4096 -f $privateKeyPath -N '""' -C "ai-kings-vastai" 2>&1 | Out-Null
        Write-Host "   ✅ Generated SSH key: $privateKeyPath" -ForegroundColor Green
    } else { Write-Host "   ⚠️  ssh-keygen not found; continue and create key later" -ForegroundColor Yellow }
} else { Write-Host "   ✅ Using existing SSH key: $privateKeyPath" -ForegroundColor Green }
$env:VASTAI_SSH_KEY_PATH = $privateKeyPath

Write-Host "[4/7] Start server (PM2 preferred)" -ForegroundColor Yellow
if (Get-Command pm2 -ErrorAction SilentlyContinue) {
    if (Test-Path "config/ecosystem.config.js") {
        & pm2 start config/ecosystem.config.js --update-env 2>&1 | Out-Null
        & pm2 save 2>&1 | Out-Null
        Write-Host "   ✅ Server started under PM2" -ForegroundColor Green
    } else {
        Start-Job -ScriptBlock { param($w) Set-Location $w; & "$w\scripts\powershell\start-server.ps1" } -ArgumentList (Get-Location).Path | Out-Null
        Start-Sleep -Seconds 5
        Write-Host "   ✅ Server job started" -ForegroundColor Green
    }
} else {
    Start-Job -ScriptBlock { param($w) Set-Location $w; & "$w\scripts\powershell\start-server.ps1" } -ArgumentList (Get-Location).Path | Out-Null
    Start-Sleep -Seconds 5
    Write-Host "   ✅ Server job started (no PM2)" -ForegroundColor Green
}

Write-Host "[5/7] Wait for local server health" -ForegroundColor Yellow
$maxAttempts = 60; $attempt = 0; $healthy = $false
while ($attempt -lt $maxAttempts -and -not $healthy) {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/health" -Method GET -TimeoutSec 5 -ErrorAction Stop
        if ($response -and $response.status -and $response.status -ne 'down') { $healthy = $true; break }
    } catch { $attempt++; Start-Sleep -Seconds 5 }
}
if (-not $healthy) { Write-Host "❌ Server did not become healthy" -ForegroundColor Red; exit 1 }
Write-Host "   ✅ Server healthy" -ForegroundColor Green

Write-Host "[6/7] Trigger prewarm (desiredSize=1) — WILL NOT provision or upload scripts" -ForegroundColor Yellow
$setDesired = @"
const db = require('./server/db');
const state = db.getState();
state.desiredSize = 1;
db.saveState(state);
console.log('Desired size set to 1');
"@
& node -e $setDesired

try {
    $result = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool/prewarm" -Headers @{ 'x-admin-key' = $env:ADMIN_API_KEY } -Method POST -TimeoutSec 1800 -ErrorAction Stop
    Write-Host "   ✅ Prewarm initiated" -ForegroundColor Green
    if ($result.instance) { Write-Host "   - Contract ID: $($result.instance.contractId)" -ForegroundColor Gray }
} catch {
    Write-Host "   ⚠️  Prewarm request failed or timed out; check warm-pool status manually" -ForegroundColor Yellow
}

Write-Host "[7/7] Display warm-pool status and instructions" -ForegroundColor Yellow
# Wait briefly and show current warm-pool status and SSH info (if any). Do NOT attempt automatic uploads.
Start-Sleep -Seconds 5
try {
    $status = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool/status" -Headers @{ 'x-admin-key' = $env:ADMIN_API_KEY } -Method GET -TimeoutSec 15 -ErrorAction Stop
    if ($status.instances -and $status.instances.Count -gt 0) {
        $inst = $status.instances[0]
        Write-Host ""; Write-Host "Prewarm Instance Summary:" -ForegroundColor Cyan
        Write-Host "   Contract: $($inst.contractId)" -ForegroundColor Gray
        Write-Host "   Status:   $($inst.actual_status)" -ForegroundColor Gray
        if ($inst.ssh_host) { Write-Host "   SSH:      root@$($inst.ssh_host) : $($inst.ssh_port)" -ForegroundColor Gray }
    } else { Write-Host "   No instance present yet in warm-pool status" -ForegroundColor Yellow }
} catch {
    Write-Host "   Could not retrieve warm-pool status: $($_.Exception.Message)" -ForegroundColor DarkGray
}

Write-Host ""; Write-Host "IMPORTANT: This script intentionally stops BEFORE provisioning/uploading any scripts." -ForegroundColor Cyan
Write-Host "   You can now manually deploy your Dropbox instance to the rented VM." -ForegroundColor Cyan
Write-Host "   Example manual steps:" -ForegroundColor White
Write-Host "     scp -P <port> -r path/to/your/dropbox root@<ssh_host>:/workspace" -ForegroundColor Gray
Write-Host "     ssh -p <port> root@<ssh_host> 'cd /workspace && ./start-dropbox.sh'" -ForegroundColor Gray
Write-Host ""; Write-Host "To inspect warm-pool status at any time:" -ForegroundColor Cyan
Write-Host "   Invoke-RestMethod -Uri 'http://localhost:3000/api/proxy/admin/warm-pool/status' -Headers @{ 'x-admin-key'='$($env:ADMIN_API_KEY)' }" -ForegroundColor White

Write-Host ""; Write-Host "Done — prewarm requested, provisioning skipped." -ForegroundColor Green
