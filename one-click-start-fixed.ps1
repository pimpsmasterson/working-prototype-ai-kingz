# AI Kings One-Click Start Script (v3.0)
# This script provides a complete one-click startup with:
# - Environment validation
# - Clean state reset
# - PM2 server startup with fresh env
# - Automated prewarm
# - SSH log collection

Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   👑 AI KINGS ONE-CLICK START v3.0                           ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: Verify Prerequisites
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "[1/8] Checking prerequisites..." -ForegroundColor Yellow

# Check if Node.js is installed
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "❌ ERROR: Node.js is not installed!" -ForegroundColor Red
    Write-Host "   Download from: https://nodejs.org/" -ForegroundColor Red
    exit 1
}

# Check if npm is installed
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "❌ ERROR: npm is not installed!" -ForegroundColor Red
    exit 1
}

Write-Host "   ✅ Node.js: $(node --version)" -ForegroundColor Green
Write-Host "   ✅ npm: $(npm --version)" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: Load Environment Variables from .env
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "[2/8] Loading environment variables..." -ForegroundColor Yellow

if (-not (Test-Path ".env")) {
    Write-Host "❌ ERROR: .env file not found!" -ForegroundColor Red
    Write-Host "   Create .env file with your API keys" -ForegroundColor Red
    exit 1
}

# Load .env file into PowerShell environment
Get-Content ".env" | Where-Object { $_ -match '^[^#].*=' } | ForEach-Object {
    $parts = $_ -split '=', 2
    $key = $parts[0].Trim()
    $value = $parts[1].Trim()
    Set-Item -Path "env:$key" -Value $value
}

# Verify required environment variables
$requiredVars = @('VASTAI_API_KEY', 'ADMIN_API_KEY', 'HUGGINGFACE_HUB_TOKEN', 'CIVITAI_TOKEN')
$missingVars = @()
foreach ($var in $requiredVars) {
    $val = [Environment]::GetEnvironmentVariable($var)
    if ([string]::IsNullOrWhiteSpace($val)) {
        $missingVars += $var
    }
}

if ($missingVars.Count -gt 0) {
    Write-Host "❌ ERROR: Missing required environment variables:" -ForegroundColor Red
    foreach ($var in $missingVars) {
        Write-Host "   - $var" -ForegroundColor Red
    }
    exit 1
}

Write-Host "   ✅ All required environment variables loaded" -ForegroundColor Green

# Safely display token previews (extract values first to avoid null reference errors)
$civitaiToken = $env:CIVITAI_TOKEN
$hfToken = $env:HUGGINGFACE_HUB_TOKEN

if ($civitaiToken -and $civitaiToken.Length -ge 8) {
    $tokenPreview = $civitaiToken.Substring(0, 8)
    Write-Host "   ✅ Civitai token: ${tokenPreview}..." -ForegroundColor Green
}

if ($hfToken -and $hfToken.Length -ge 12) {
    $tokenPreview = $hfToken.Substring(0, 12)
    Write-Host "   ✅ HuggingFace token: ${tokenPreview}..." -ForegroundColor Green
}

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: Clean Existing State (AGGRESSIVE CLEANUP)
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "[3/8] Performing aggressive cleanup of all processes and database..." -ForegroundColor Yellow

# Kill ALL related processes aggressively
Write-Host "   🔪 Killing all related processes..." -ForegroundColor Red

# NOTE: Avoid killing all Node.js processes (this can kill the PM2 daemon). Instead, rely on targeted port-based cleanup further below.
# (If you really need to remove a stray Node process not bound to our ports, inspect it manually.)

# Port-based cleanup will handle any local ComfyUI or proxy instances.
# Global process killing of 'python' or 'ssh' is skipped to avoid disrupting the IDE's background services.

# Kill any processes using our ports
$usedPorts = @(3000, 8080, 8188)
# Attempt graceful stop of processes listening on our ports, then force if still present
foreach ($port in $usedPorts) {
    $portProcesses = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Listen' } | ForEach-Object { Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue }
    if ($portProcesses) {
        Write-Host "   Stopping process(es) using port $port (graceful)..." -ForegroundColor Gray
        $portProcesses | Stop-Process -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        $stillListening = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Listen' } | ForEach-Object { Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue }
        if ($stillListening) {
            Write-Host "   Forcibly stopping remaining process(es) using port $port..." -ForegroundColor Gray
            $stillListening | Stop-Process -Force -ErrorAction SilentlyContinue
        }
    }
}

# Wait for processes to fully terminate
Start-Sleep -Seconds 3

# Ensure PM2 is used to manage the server if available (do NOT wipe global PM2 state)
if (Get-Command pm2 -ErrorAction SilentlyContinue) {
    Write-Host "   Ensuring PM2 is running and 'vastai-proxy' is managed by PM2..." -ForegroundColor Gray
    try {
        # If an existing app exists, remove only the named app so we can restart cleanly
        & pm2 describe vastai-proxy 2>$null | Out-Null
        Write-Host "   Restarting 'vastai-proxy' via PM2 (delete then start)..." -ForegroundColor Gray
        & pm2 delete vastai-proxy 2>&1 | Out-Null
    }
    catch {
        # If describe/delete fail, ignore and continue to start via ecosystem if available
    }

    if (Test-Path "config/ecosystem.config.js") {
        Write-Host "   Starting 'vastai-proxy' using PM2 ecosystem file and saving state..." -ForegroundColor Gray
        & pm2 start config/ecosystem.config.js --update-env 2>&1 | Out-Null
        & pm2 save 2>&1 | Out-Null
        Write-Host "   ✅ PM2 configured to manage 'vastai-proxy' and saved state" -ForegroundColor Green

        # Ensure a Windows scheduled-task watchdog is present to auto-heal PM2 / app failures
        # Check if running as administrator
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if ($isAdmin) {
            try {
                $taskName = "AIKings_PM2_Watchdog"
                $ensureScript = Join-Path (Get-Location) 'scripts\powershell\ensure_pm2.ps1'

                # Check if task exists using PowerShell cmdlet
                $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

                if (-not $existingTask) {
                    Write-Host "   Creating scheduled task '$taskName' to run every 5 minutes..." -ForegroundColor Gray

                    # Use PowerShell cmdlets (better path handling than schtasks)
                    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ensureScript`""
                    # Create trigger that repeats every 5 minutes indefinitely
                    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
                    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
                    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

                    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
                    Write-Host "   ✅ Scheduled task created: $taskName" -ForegroundColor Green
                }
                else {
                    Write-Host "   ✅ Scheduled task '$taskName' already exists" -ForegroundColor Gray
                }
            }
            catch {
                Write-Host "   ⚠️  Failed to create scheduled task: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Host "   💡 PM2 will still work, but watchdog won't auto-restart on failures" -ForegroundColor Gray
            }
        }
        else {
            Write-Host "   ⚠️  Not running as Administrator - skipping scheduled task creation" -ForegroundColor Yellow
            Write-Host "   💡 Scheduled task provides auto-restart for PM2 failures (optional)" -ForegroundColor Gray
            Write-Host "   💡 To enable: Right-click PowerShell → Run as Administrator" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "   ⚠️  PM2 available but no ecosystem.config.js found; skipping global state wipe" -ForegroundColor Yellow
    }
}
else {
    Write-Host "   PM2 not found; server will be started directly" -ForegroundColor Gray
}

# Clear database state COMPLETELY
Write-Host "   Clearing database completely..." -ForegroundColor Gray
# Delete database files first to avoid lock issues (especially with OneDrive sync)
$dbFiles = Get-ChildItem "data\warm_pool.db*" -ErrorAction SilentlyContinue
if ($dbFiles) {
    foreach ($file in $dbFiles) {
        Write-Host "   Deleting database file: $($file.Name)..." -ForegroundColor Gray
        Remove-Item -Force $file.FullName -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 1  # Brief pause to ensure files are released
}

# Now try to reset database state (will create new DB if files were deleted)
try {
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
    & node -e $dbClearCmd 2>&1 | Out-Null
}
catch {
    Write-Host "   ⚠️  Database reset skipped (will be recreated on server start)" -ForegroundColor Yellow
}

# Delete all cached files
$filesToDelete = @(
    ".proxy-tokens.json",
    "server.err",
    "nohup.out"
)

foreach ($file in $filesToDelete) {
    if (Test-Path $file) {
        Write-Host "   Deleting $file..." -ForegroundColor Gray
        Remove-Item -Force $file
    }
}

# Clear old provision logs (keep last 5)
$logFiles = Get-ChildItem "logs/provision_*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
if ($logFiles.Count -gt 5) {
    $filesToRemove = $logFiles | Select-Object -Skip 5
    foreach ($file in $filesToRemove) {
        Write-Host "   Deleting old log: $($file.Name)..." -ForegroundColor Gray
        Remove-Item -Force $file.FullName
    }
}

# Final verification - ensure no processes are running on our ports
$stillRunning = $false
foreach ($port in $usedPorts) {
    $portProcesses = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Listen' }
    if ($portProcesses) {
        Write-Host "   ⚠️  WARNING: Port $port still in use!" -ForegroundColor Yellow
        $stillRunning = $true
    }
}

if ($stillRunning) {
    Write-Host "   🔄 Attempting graceful shutdown of remaining processes..." -ForegroundColor Red
    foreach ($port in $usedPorts) {
        $portProcesses = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Listen' } | ForEach-Object { Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue }
        if ($portProcesses) {
            $portProcesses | Stop-Process -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            $remaining = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Listen' } | ForEach-Object { Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue }
            if ($remaining) {
                $remaining | Stop-Process -Force -ErrorAction SilentlyContinue
            }
        }
    }
    Start-Sleep -Seconds 2

    # Verify ports are actually free after force kill
    Start-Sleep -Seconds 3
    $stillBlocked = @()
    foreach ($port in $usedPorts) {
        $check = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Listen' }
        if ($check) {
            $stillBlocked += $port
        }
    }

    if ($stillBlocked.Count -gt 0) {
        Write-Host "   ⚠️  Ports still blocked: $($stillBlocked -join ', ')" -ForegroundColor Yellow
        Write-Host "   These may be system services - server will attempt to use alternate ports" -ForegroundColor Gray
    }
}

Write-Host "   ✅ Aggressive cleanup completed - all processes killed, database reset" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: Ensure SSH Key Exists
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "[4/8] Checking SSH key..." -ForegroundColor Yellow

$sshDir = Join-Path $env:USERPROFILE '.ssh'
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
}

# Use id_rsa_vast as default (matches our server-side defaults)
$privateKeyPath = Join-Path $sshDir 'id_rsa_happy'
$publicKeyPath = "$privateKeyPath.pub"

if (-not (Test-Path $privateKeyPath)) {
    Write-Host "   Generating new SSH keypair..." -ForegroundColor Gray
    if (Get-Command ssh-keygen -ErrorAction SilentlyContinue) {
        & ssh-keygen -t rsa -b 4096 -f $privateKeyPath -N "happy" -C "ai-kings-happy" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ SSH key generated: $privateKeyPath" -ForegroundColor Green
        }
        else {
            Write-Host "   ⚠️  ssh-keygen failed; log collection may not work" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "   ⚠️  ssh-keygen not found; log collection will be disabled" -ForegroundColor Yellow
    }
}
else {
    Write-Host "   ✅ Using existing SSH key: $privateKeyPath" -ForegroundColor Green
}

# Set environment variable for SSH key path
$env:VASTAI_SSH_KEY_PATH = $privateKeyPath

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5: Start Server with Fresh Environment
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "[5/8] Starting server..." -ForegroundColor Yellow

# Start server using PM2 when available; otherwise fall back to the PowerShell background job
if (Get-Command pm2 -ErrorAction SilentlyContinue) {
    Write-Host "   Starting server under PM2 (recommended) using config/ecosystem.config.js..." -ForegroundColor Gray
    if (Test-Path "config/ecosystem.config.js") {
        & pm2 start config/ecosystem.config.js --update-env 2>&1 | Out-Null
        & pm2 save 2>&1 | Out-Null
        Write-Host "   ✅ Server started and PM2 state saved" -ForegroundColor Green
    }
    else {
        Write-Host "   ⚠️  No ecosystem.config.js found; starting server directly via start-server.ps1" -ForegroundColor Yellow
        $serverJob = Start-Job -ScriptBlock {
            param($workDir)
            Set-Location $workDir
            & "$workDir\scripts\powershell\start-server.ps1"
        } -ArgumentList (Get-Location).Path
    }
}
else {
    Write-Host "   PM2 not installed; starting server in PowerShell background job..." -ForegroundColor Yellow
    $serverJob = Start-Job -ScriptBlock {
        param($workDir)
        Set-Location $workDir
        & "$workDir\scripts\powershell\start-server.ps1"
    } -ArgumentList (Get-Location).Path
}
Start-Sleep -Seconds 5

# Verify server is starting
$serverStarted = $false
for ($i = 0; $i -lt 10; $i++) {
    $nodeProc = Get-Process node -ErrorAction SilentlyContinue
    if ($nodeProc) {
        $serverStarted = $true
        break
    }
    Start-Sleep -Seconds 1
}

if (-not $serverStarted) {
    Write-Host "   ❌ Server failed to start!" -ForegroundColor Red
    Write-Host "   Check server logs for errors" -ForegroundColor Red
    exit 1
}

Write-Host "   ✅ Server process started" -ForegroundColor Green

# Verify PM2-managed process is running if we started under PM2
if (Get-Command pm2 -ErrorAction SilentlyContinue) {
    Write-Host "   Verifying PM2 process status for 'vastai-proxy'..." -ForegroundColor Gray
    $pm2Show = & pm2 show vastai-proxy 2>&1 | Out-String
    if ($pm2Show -match 'status\s*:\s*online' -or $pm2Show -match 'online') {
        Write-Host "   ✅ PM2 reports 'vastai-proxy' online" -ForegroundColor Green
    }
    else {
        Write-Host "   ⚠️  PM2 reports: `n$pm2Show" -ForegroundColor Yellow
        Write-Host "   Check with: pm2 logs vastai-proxy --lines 200" -ForegroundColor Yellow
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 6: Wait for Server to Be Healthy
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "[6/8] Waiting for server to be healthy..." -ForegroundColor Yellow

$maxAttempts = 60
$attempt = 0
$healthy = $false

while ($attempt -lt $maxAttempts -and -not $healthy) {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/health" -Method GET -TimeoutSec 5 -ErrorAction Stop
        if ($response -and $response.status -and $response.status -ne 'down') {
            $healthy = $true
            Write-Host "   ✅ Server is healthy (status: $($response.status))" -ForegroundColor Green
            break
        }
    }
    catch {
        $attempt++
        if ($attempt % 10 -eq 0) {
            Write-Host "   Waiting for server... ($attempt/$maxAttempts)" -ForegroundColor Gray
        }
        Start-Sleep -Seconds 5
    }
}

if (-not $healthy) {
    Write-Host "   ❌ Server failed to become healthy within 5 minutes" -ForegroundColor Red
    Write-Host "   Check the server logs for errors" -ForegroundColor Red
    exit 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 7: Trigger Prewarm
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "[7/8] Triggering prewarm..." -ForegroundColor Yellow

# Ensure desiredSize is set to 1 for the warm pool
$setDesiredSizeCmd = @"
const db = require('./server/db');
const state = db.getState();
state.desiredSize = 1;
db.saveState(state);
console.log('Desired size set to 1');
"@
& node -e $setDesiredSizeCmd

$prewarmAttempts = 3
$prewarmSuccess = $false

for ($i = 1; $i -le $prewarmAttempts; $i++) {
    try {
        Write-Host "   Prewarm attempt #$i/$prewarmAttempts..." -ForegroundColor Gray

        # Use longer timeout (30 minutes = 1800 seconds) to allow for full provisioning
        # Note: Provisioning can take 5-15 minutes depending on instance speed and network
        $result = Invoke-RestMethod `
            -Uri "http://localhost:3000/api/proxy/admin/warm-pool/prewarm" `
            -Headers @{ 'x-admin-key' = $env:ADMIN_API_KEY } `
            -Method POST `
            -TimeoutSec 1800 `
            -ErrorAction Stop

        Write-Host "   ✅ Prewarm initiated successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "   Instance Details:" -ForegroundColor Cyan
        if ($result.instance) {
            Write-Host "   - Contract ID: $($result.instance.contractId)" -ForegroundColor Gray
            Write-Host "   - Machine ID: $($result.instance.machine_id)" -ForegroundColor Gray
            Write-Host "   - GPU: $($result.instance.gpu_name)" -ForegroundColor Gray
            Write-Host "   - Status: $($result.instance.actual_status)" -ForegroundColor Gray

            # Store instance info for later use
            $global:instanceContractId = $result.instance.contractId
        }
        $prewarmSuccess = $true
        break
    }
    catch {
        $err = $_.Exception.Message
        Write-Host "   ⚠️  Prewarm attempt #$i failed: $err" -ForegroundColor Yellow

        if ($err -match '403|forbidden') {
            Write-Host "   Admin key rejected. This may be a caching issue." -ForegroundColor Yellow
        }
        elseif ($err -imatch 'timeout|timed out|canceled') {
            Write-Host "   Note: Prewarm was triggered but response timed out." -ForegroundColor Yellow
            Write-Host "   Checking if instance is actually provisioning..." -ForegroundColor Gray

            # Check status multiple times with increasing delays
            $statusCheckAttempts = 3
            for ($statusCheck = 1; $statusCheck -le $statusCheckAttempts; $statusCheck++) {
                try {
                    $waitTime = 3 + ($statusCheck * 2)  # 5s, 7s, 9s
                    Write-Host "   Status check attempt $statusCheck/$statusCheckAttempts (waiting ${waitTime}s)..." -ForegroundColor Gray
                    Start-Sleep -Seconds $waitTime

                    $statusResult = Invoke-RestMethod `
                        -Uri "http://localhost:3000/api/proxy/admin/warm-pool/status" `
                        -Headers @{ 'x-admin-key' = $env:ADMIN_API_KEY } `
                        -Method GET `
                        -TimeoutSec 15 `
                        -ErrorAction Stop

                    Write-Host "   Status response: $($statusResult | ConvertTo-Json -Depth 2 -Compress)" -ForegroundColor DarkGray

                    if ($statusResult.instances -and $statusResult.instances.Count -gt 0 -and $statusResult.instances[0].contractId) {
                        Write-Host "   ✅ Instance is provisioning! (Contract: $($statusResult.instances[0].contractId))" -ForegroundColor Green
                        $prewarmSuccess = $true
                        $global:instanceContractId = $statusResult.instances[0].contractId
                        break
                    }
                    elseif ($statusResult.instances -and $statusResult.instances.Count -gt 0) {
                        Write-Host "   Instance found but no contractId yet (status: $($statusResult.instances[0].actual_status))" -ForegroundColor Gray
                    }
                    else {
                        Write-Host "   No instance in status response yet" -ForegroundColor Gray
                    }
                }
                catch {
                    $statusErr = $_.Exception.Message
                    Write-Host "   Status check failed: $statusErr" -ForegroundColor DarkGray
                }

                if ($prewarmSuccess) { break }
            }

            if ($prewarmSuccess) { break }
        }

        if ($i -lt $prewarmAttempts) {
            Write-Host "   Retrying in 5 seconds..." -ForegroundColor Gray
            Start-Sleep -Seconds 5
        }
    }
}

# Final check: even if prewarm attempts failed, check if an instance is already running
if (-not $prewarmSuccess) {
    Write-Host "   Checking final status for any running instances..." -ForegroundColor Gray
    try {
        $finalStatus = Invoke-RestMethod `
            -Uri "http://localhost:3000/api/proxy/admin/warm-pool/status" `
            -Headers @{ 'x-admin-key' = $env:ADMIN_API_KEY } `
            -Method GET `
            -TimeoutSec 10 `
            -ErrorAction Stop

        if ($finalStatus.instances -and $finalStatus.instances.Count -gt 0 -and $finalStatus.instances[0].contractId) {
            Write-Host "   ✅ Found running instance! (Contract: $($finalStatus.instances[0].contractId))" -ForegroundColor Green
            $prewarmSuccess = $true
            $global:instanceContractId = $finalStatus.instances[0].contractId
        }
    }
    catch {
        Write-Host "   Final status check failed: $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

if (-not $prewarmSuccess) {
    Write-Host "   ❌ Prewarm failed after $prewarmAttempts attempts" -ForegroundColor Red
    Write-Host "   You can try manually:" -ForegroundColor Yellow
    Write-Host "   Invoke-RestMethod -Uri 'http://localhost:3000/api/proxy/admin/warm-pool/prewarm' -Headers @{ 'x-admin-key'='$($env:ADMIN_API_KEY)' } -Method POST" -ForegroundColor Yellow
}

# ═════════════════════════════════════════════════════════════════════════════=
# Upload provision script to instance (wait for SSH info, verify via sha256)
# ═════════════════════════════════════════════════════════════════════════════=
if ($prewarmSuccess) {
    Write-Host "   Checking for SSH details to upload provision script..." -ForegroundColor Gray

    $sshHost = $null
    $sshPort = $null
    # Wait up to 3 minutes for SSH details to appear
    for ($wait = 0; $wait -lt 36; $wait++) {
        try {
            $s = Invoke-RestMethod `
                -Uri "http://localhost:3000/api/proxy/admin/warm-pool/status" `
                -Headers @{ 'x-admin-key' = $env:ADMIN_API_KEY } `
                -Method GET `
                -TimeoutSec 10 `
                -ErrorAction Stop

            if ($s.instances -and $s.instances.Count -gt 0 -and $s.instances[0].ssh_host) {
                $sshHost = $s.instances[0].ssh_host
                $sshPort = $s.instances[0].ssh_port
                break
            }
        }
        catch {
            # transient - ignore
        }
        Start-Sleep -Seconds 5
    }

    if ($sshHost) {
        Write-Host "   ✅ SSH details found: $($sshHost):$($sshPort)" -ForegroundColor Green

        $localScript = Join-Path (Get-Location) 'scripts\provision-reliable.sh'
        if ($env:COMFYUI_PROVISION_SCRIPT -match 'provision-dropbox-only.sh') {
            $localScript = Join-Path (Get-Location) 'scripts\provision-dropbox-only.sh'
        }
        if (Test-Path $localScript) {
            $localHash = (Get-FileHash $localScript -Algorithm SHA256).Hash
            $uploadedOk = $false

            for ($attempt = 1; $attempt -le 5; $attempt++) {
                Write-Host "   Upload attempt #$attempt -> /tmp/provision.sh" -ForegroundColor Gray
                $scpArgs = @('-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=nul', $localScript, "root@$($sshHost):/tmp/provision.sh")
                try {
                    & scp @scpArgs 2>$null | Out-Null
                }
                catch {
                    # ignore, we'll verify below
                }

                # Give remote a moment then request remote sha
                Start-Sleep -Seconds 2
                try {
                    $remoteCmd = "sha256sum /tmp/provision.sh 2>/dev/null | awk '{print \$1}'"
                    $raw = & ssh -o StrictHostKeyChecking=no "root@$sshHost" $remoteCmd 2>$null
                    $remoteHash = ($raw -join "").Trim()
                }
                catch {
                    $remoteHash = ""
                }

                Write-Host "     local:  $localHash" -ForegroundColor DarkGray
                Write-Host "     remote: $remoteHash" -ForegroundColor DarkGray

                if ($remoteHash -and $remoteHash -eq $localHash) {
                    Write-Host "   ✅ Remote script verified (SHA256 match)" -ForegroundColor Green
                    # ensure unix line endings and executable
                    try {
                        & ssh -o StrictHostKeyChecking=no "root@$sshHost" "dos2unix /tmp/provision.sh 2>/dev/null || true; chmod +x /tmp/provision.sh; nohup bash /tmp/provision.sh > /workspace/provision_v3.log 2>&1 &" 2>$null
                        $uploadedOk = $true
                        break
                    }
                    catch {
                        Write-Host "   ⚠️  Failed to start remote script (attempt $attempt)" -ForegroundColor Yellow
                    }
                }
                else {
                    Write-Host "   ⚠️  Remote sha mismatch or not present (attempt $attempt)" -ForegroundColor Yellow

                    # After a few attempts, try a safer fallback: pipe file content via SSH
                    if ($attempt -ge 3) {
                        Write-Host "   ⚡ Attempting fallback upload via SSH (piping file content)..." -ForegroundColor Gray
                        try {
                            Get-Content $localScript -Raw | & ssh -o StrictHostKeyChecking=no "root@$sshHost" "cat > /tmp/provision.sh"
                        }
                        catch {
                            Write-Host "   ⚠️  Fallback upload failed" -ForegroundColor Yellow
                        }

                        Start-Sleep -Seconds 2
                        try {
                            $raw = & ssh -o StrictHostKeyChecking=no "root@$sshHost" $remoteCmd 2>$null
                            $remoteHash = ($raw -join "").Trim()
                        }
                        catch {
                            $remoteHash = ""
                        }

                        Write-Host "     remote (after fallback): $remoteHash" -ForegroundColor DarkGray

                        if ($remoteHash -and $remoteHash -eq $localHash) {
                            Write-Host "   ✅ Fallback upload verified" -ForegroundColor Green
                            try {
                                & ssh -o StrictHostKeyChecking=no "root@$sshHost" "dos2unix /tmp/provision.sh 2>/dev/null || true; chmod +x /tmp/provision.sh; nohup bash /tmp/provision.sh > /workspace/provision_v3.log 2>&1 &" 2>$null
                                $uploadedOk = $true
                                break
                            }
                            catch {
                                Write-Host "   ⚠️  Failed to start remote script after fallback" -ForegroundColor Yellow
                            }
                        }
                        else {
                            Write-Host "   ⚠️  Fallback did not produce matching remote hash" -ForegroundColor Yellow
                        }
                    }
                }

                Start-Sleep -Seconds (5 * $attempt)
            }

            if (-not $uploadedOk) {
                Write-Host "   ❌ Failed to reliably upload/verify provision script after multiple attempts" -ForegroundColor Red
                Write-Host "   You can manually upload and start the script with:" -ForegroundColor Yellow
                Write-Host "     scp $localScript root@$($sshHost):/tmp/provision.sh" -ForegroundColor Gray
                Write-Host "     ssh root@$($sshHost) 'dos2unix /tmp/provision.sh; chmod +x /tmp/provision.sh; nohup bash /tmp/provision.sh > /workspace/provision_v3.log 2>&1 &'" -ForegroundColor Gray
            }
        }
        else {
            Write-Host "   ❌ Local provision script not found: $localScript" -ForegroundColor Red
        }
    }
    else {
        Write-Host "   ⚠️  SSH details did not appear; will continue waiting for instance readiness" -ForegroundColor Yellow
    }
}


# ═══════════════════════════════════════════════════════════════════════════════
# STEP 8: Wait for Instance to Be Fully Ready (NEW STEP)
# ═══════════════════════════════════════════════════════════════════════════════
if ($prewarmSuccess) {
    Write-Host ""
    Write-Host "[8/8] Waiting for instance to be fully ready..." -ForegroundColor Yellow

    $readyWaitAttempts = 60  # 10 minutes total (60 * 10s)
    $instanceReady = $false
    $lastStatus = ""

    for ($attempt = 1; $attempt -le $readyWaitAttempts; $attempt++) {
        try {
            $statusResult = Invoke-RestMethod `
                -Uri "http://localhost:3000/api/proxy/admin/warm-pool/status" `
                -Headers @{ 'x-admin-key' = $env:ADMIN_API_KEY } `
                -Method GET `
                -TimeoutSec 10 `
                -ErrorAction Stop

            if ($statusResult.instances -and $statusResult.instances.Count -gt 0) {
                $instance = $statusResult.instances[0]
                $status = $instance.actual_status
                $contractId = $instance.contractId

                # Update status display every 6 attempts (60 seconds) or on status change
                if ($attempt % 6 -eq 1 -or $status -ne $lastStatus) {
                    Write-Host "   Instance $contractId status: $status" -ForegroundColor Gray
                    $lastStatus = $status
                }

                # Check if instance is running
                if ($status -eq 'running') {
                    Write-Host "   ✅ Instance is running! Checking ComfyUI..." -ForegroundColor Green

                    # Check if ComfyUI is accessible (try for up to 30 seconds)
                    $comfyReady = $false
                    for ($comfyCheck = 1; $comfyCheck -le 6; $comfyCheck++) {
                        try {
                            # Check ComfyUI health via the instance tunnel
                            $comfyHealth = Invoke-RestMethod `
                                -Uri "http://localhost:3000/api/proxy/health" `
                                -Method GET `
                                -TimeoutSec 5 `
                                -ErrorAction Stop

                            if ($comfyHealth.warmPool -and $comfyHealth.warmPool.instance) {
                                Write-Host "   ✅ ComfyUI is accessible!" -ForegroundColor Green
                                $comfyReady = $true
                                break
                            }
                        }
                        catch {
                            # ComfyUI not ready yet
                        }

                        if ($comfyCheck -lt 6) {
                            Start-Sleep -Seconds 5
                        }
                    }

                    if ($comfyReady) {
                        Write-Host "   🎉 Instance fully ready! ComfyUI is running and accessible." -ForegroundColor Green
                        $instanceReady = $true
                        break
                    }
                    else {
                        Write-Host "   ⚠️  Instance running but ComfyUI not accessible yet..." -ForegroundColor Yellow
                    }
                }
                elseif ($status -match 'exited|error|failed') {
                    Write-Host "   ❌ Instance failed with status: $status" -ForegroundColor Red
                    break
                }
                # Continue waiting for other statuses (loading, starting, etc.)
            }
            else {
                Write-Host "   No instance found in status response" -ForegroundColor Yellow
            }
        }
        catch {
            $statusErr = $_.Exception.Message
            if ($attempt % 6 -eq 1) {
                Write-Host "   Status check failed: $statusErr" -ForegroundColor DarkGray
            }
        }

        if (-not $instanceReady) {
            Start-Sleep -Seconds 10
        }
    }

    if (-not $instanceReady) {
        Write-Host "   ⚠️  Instance may still be provisioning. Check status manually:" -ForegroundColor Yellow
        Write-Host "   Invoke-RestMethod -Uri 'http://localhost:3000/api/proxy/admin/warm-pool/status' -Headers @{ 'x-admin-key'='$($env:ADMIN_API_KEY)' }" -ForegroundColor White
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# SUCCESS SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   ✅ AI KINGS STARTED SUCCESSFULLY!                           ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 Server URLs:" -ForegroundColor Cyan
Write-Host "   Health Check: http://localhost:3000/api/proxy/health" -ForegroundColor White
Write-Host "   Studio UI:    http://localhost:3000/pages/studio.html" -ForegroundColor White
Write-Host "   Admin UI:     http://localhost:3000/pages/admin-warm-pool.html" -ForegroundColor White
Write-Host ""
Write-Host "📊 Monitor Status:" -ForegroundColor Cyan
Write-Host "   Invoke-RestMethod -Uri 'http://localhost:3000/api/proxy/admin/warm-pool/status' -Headers @{ 'x-admin-key'='$($env:ADMIN_API_KEY)' }" -ForegroundColor White
Write-Host ""
Write-Host "To Stop Server:" -ForegroundColor Cyan
Write-Host "   Get-Process node | Stop-Process -Force" -ForegroundColor White
Write-Host ""
