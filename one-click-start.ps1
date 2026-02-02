param(
    [switch]$InstallDependencies
)

Write-Host "One-Click Start (npx pm2) — starting checks..." -ForegroundColor Cyan

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

# Ensure Node and npm exist
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Fail 'Node.js not found in PATH. Install Node.js from https://nodejs.org/' }
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { Write-Host 'Warning: npm not found in PATH; some steps may fail.' -ForegroundColor Yellow }

# Load .env if present
$envFile = Join-Path (Get-Location) '.env'
if (Test-Path $envFile) {
    Write-Host "Loading .env..." -ForegroundColor Green
    Get-Content $envFile | Where-Object { $_ -match '^[^#].*=' } | ForEach-Object {
        $parts = $_ -split '=', 2
        $k = $parts[0].Trim()
        $v = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }
        if ($k) { Set-Item -Path "env:$k" -Value $v }
    }
} else {
    Write-Host ".env not found — will prompt for required values if missing." -ForegroundColor Yellow
}

# Prompt for required env vars
if ([string]::IsNullOrWhiteSpace($env:VASTAI_API_KEY)) {
    $val = Read-Host -Prompt 'Enter VASTAI_API_KEY (required)'
    if ([string]::IsNullOrWhiteSpace($val)) { Fail 'VASTAI_API_KEY is required.' }
    $env:VASTAI_API_KEY = $val
}
if ([string]::IsNullOrWhiteSpace($env:ADMIN_API_KEY)) {
    $val = Read-Host -Prompt 'Enter ADMIN_API_KEY (required)'
    if ([string]::IsNullOrWhiteSpace($val)) { Fail 'ADMIN_API_KEY is required.' }
    $env:ADMIN_API_KEY = $val
}

Write-Host "Using VASTAI_API_KEY and ADMIN_API_KEY (hidden)" -ForegroundColor Cyan

# Optionally write .env for convenience
$writeEnv = Read-Host -Prompt 'Save these values to .env for future runs? (y/N)'
if ($writeEnv -and $writeEnv.ToLower().StartsWith('y')) {
    $lines = @()
    $lines += "VASTAI_API_KEY=$($env:VASTAI_API_KEY)"
    $lines += "ADMIN_API_KEY=$($env:ADMIN_API_KEY)"
    if ($env:HUGGINGFACE_HUB_TOKEN) { $lines += "HUGGINGFACE_HUB_TOKEN=$($env:HUGGINGFACE_HUB_TOKEN)" }
    if ($env:CIVITAI_TOKEN) { $lines += "CIVITAI_TOKEN=$($env:CIVITAI_TOKEN)" }
    Set-Content -Path $envFile -Value $lines -Encoding UTF8
    Write-Host ".env written to $envFile" -ForegroundColor Green
}

# Optionally install dependencies
if ($InstallDependencies -or -not (Test-Path (Join-Path (Get-Location) 'node_modules'))) {
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host 'Running npm install... (this may take a while)'
        & npm install
        if ($LASTEXITCODE -ne 0) { Write-Host 'npm install failed — continuing but startup may fail.' -ForegroundColor Yellow }
    } else {
        Write-Host 'npm not found; skipping npm install.' -ForegroundColor Yellow
    }
}

# Start process via npx pm2
Write-Host 'Starting application via npx pm2 (this uses the existing config/ecosystem.config.js if present)...' -ForegroundColor Cyan

$ecConfig = Join-Path (Get-Location) 'config\ecosystem.config.js'
if (Test-Path $ecConfig) {
    Write-Host 'Using config/ecosystem.config.js' -ForegroundColor Gray
    & npx --yes pm2 start $ecConfig --env production --update-env
} else {
    Write-Host 'ecosystem.config.js not found; starting server directly' -ForegroundColor Gray
    & npx --yes pm2 start server/vastai-proxy.js --name ai-kings --update-env
}

if ($LASTEXITCODE -ne 0) { Write-Host 'pm2 start returned non-zero exit code; check output above.' -ForegroundColor Yellow }

# Save pm2 list
& npx --yes pm2 save

# Show pm2 startup instructions (user must run the printed command as Administrator to enable startup)
Write-Host 'To enable pm2 startup persistence, run the following command as Administrator:' -ForegroundColor Cyan
$startupOut = & npx --yes pm2 startup | Out-String
Write-Host $startupOut -ForegroundColor Yellow

# Poll health endpoint
Write-Host 'Waiting for server health at http://localhost:3000/api/proxy/health ...' -ForegroundColor Cyan
$maxAttempts = 60
$attempt = 0
$healthy = $false
while ($attempt -lt $maxAttempts -and -not $healthy) {
    Start-Sleep -Seconds 3
    try {
        $attempt++
        $resp = Invoke-RestMethod -Uri 'http://localhost:3000/api/proxy/health' -Method Get -ErrorAction Stop
        if ($resp -and $resp.status -and $resp.status -ne 'down') {
            Write-Host "Server healthy: $($resp.status)" -ForegroundColor Green
            $healthy = $true
            break
        } else {
            Write-Host "Health: $($resp | ConvertTo-Json -Depth 2)" -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "Attempt $($attempt)/$($maxAttempts): server not ready yet..." -ForegroundColor Yellow
    }
}

if (-not $healthy) { Write-Host 'Server did not become healthy within timeout.' -ForegroundColor Red; exit 1 }

Write-Host 'Server started and healthy. Use `npx pm2 status` and `npx pm2 logs <name>` to inspect.' -ForegroundColor Green
# AI Kings One-Click Start Script
# This script kills existing processes, cleans DB, starts server, waits for health, and prewarms.

Write-Host "Starting AI Kings One-Click Setup..."

# Load environment variables from .env file
Write-Host "Loading environment variables from .env file..."
if (Test-Path ".env") {
    Get-Content ".env" | Where-Object { $_ -match '^[^#].*=' } | ForEach-Object {
        $key, $value = $_ -split '=', 2
        $key = $key.Trim()
        $value = $value.Trim()
        Set-Item -Path "env:$key" -Value $value
        Write-Host "Set $key"
    }
} else {
    Write-Host "ERROR: .env file not found!" -ForegroundColor Red
    exit 1
}

# Check for required environment variables
if (-not $env:VASTAI_API_KEY) {
    Write-Host "ERROR: VASTAI_API_KEY not found in .env file!" -ForegroundColor Red
    exit 1
}

if (-not $env:ADMIN_API_KEY) {
    Write-Host "ERROR: ADMIN_API_KEY not found in .env file!" -ForegroundColor Red
    exit 1
}

Write-Host "Environment variables loaded successfully."

# Kill existing Node.js processes
Write-Host "Killing existing Node.js processes..."
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force

# Clean DB
Write-Host "Cleaning database..."
node -e "const db=require('./server/db'); const s=db.getState(); s.instance=null; s.useDefaultScript=false; s.provisionAttempt=0; s.isPrewarming=false; db.saveState(s); console.log('DB cleared');"

# Start server in background under PM2 (use startOrRestart to update code/env)
Write-Host "Starting server under PM2 (startOrRestart + --update-env)..."

# Ensure PM2 is updated to local version if mismatch (helps avoid in-memory vs installed mismatch warnings)
try {
    $pm2Ver = (& npx -y pm2 -v) -join '' 2>$null
} catch {
    $pm2Ver = $null
}

# Use startOrRestart so PM2 picks up updated ecosystem and env
if (Get-Command npx -ErrorAction SilentlyContinue) {
    Write-Host "Starting via: npx pm2 startOrRestart config/ecosystem.config.js --update-env"
    cmd /c "npx pm2 startOrRestart config/ecosystem.config.js --update-env"
} else {
    Write-Host "npx not available; attempting npm script 'start:pm2'"
    cmd /c "npm run start:pm2 --silent"
}

Start-Sleep -Seconds 3

# Wait for server to be ready (longer timeout to accommodate provisioning under PM2)
Write-Host "Waiting for server to start (up to 5 minutes)..."
$maxAttempts = 60
$attempt = 0
$healthy = $false
while ($attempt -lt $maxAttempts -and -not $healthy) {
    try {
        # Use Invoke-RestMethod to avoid HTML parsing/script execution prompt and to directly get JSON
        $response = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/health" -Method GET -TimeoutSec 5 -ErrorAction Stop
        if ($response -and $response.status -ne 'down') {
            $healthy = $true
            Write-Host "Server is healthy."
            break
        }
    } catch {
        Write-Host "Waiting for server... ($($attempt + 1)/$maxAttempts)"
        Start-Sleep -Seconds 5
        $attempt++
    }
}

if (-not $healthy) {
    Write-Host "ERROR: Server failed to start within timeout." -ForegroundColor Red
    exit 1
}

# Prewarm with retries. If forbidden (admin key mismatch), restart PM2 with --update-env and retry.
Write-Host "Triggering prewarm..."
$prewarmAttempts = 3
$prewarmAttempt = 0
$prewarmSuccess = $false
while ($prewarmAttempt -lt $prewarmAttempts -and -not $prewarmSuccess) {
    try {
        $prewarmAttempt++
        Write-Host "Prewarm attempt #$prewarmAttempt"
        # Use Invoke-RestMethod (returns parsed JSON) and avoid parsing HTML/script
        $result = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool/prewarm" -Headers @{ 'x-admin-key' = $env:ADMIN_API_KEY } -Method POST -TimeoutSec 300 -ErrorAction Stop
        Write-Host "Prewarm initiated:" -ForegroundColor Green
        $result | ConvertTo-Json -Depth 3
        $prewarmSuccess = $true
        break
    } catch {
        $err = $_.Exception.Message
        Write-Host "Prewarm attempt #$prewarmAttempt failed: $err" -ForegroundColor Yellow
        if ($err -match '403' -or $err -match 'forbidden') {
            Write-Host "Admin key rejected. Restarting PM2 process with updated environment and retrying..." -ForegroundColor Yellow
            Start-Process -NoNewWindow -FilePath "cmd" -ArgumentList "/c npx pm2 restart config/ecosystem.config.js --update-env" -WorkingDirectory (Get-Location) -Wait
            Start-Sleep -Seconds 5
            continue
        }
        Start-Sleep -Seconds 5
    }
}

if (-not $prewarmSuccess) {
    Write-Host "Prewarm failed after $prewarmAttempts attempts." -ForegroundColor Red
}

# Automated SSH & log collection (best-effort):
# - Generate SSH keypair at ~/.ssh/vast_ai_key if missing
# - Ensure the public key will be registered by the server during prewarm
# - Poll warm-pool status until `ssh_host` and `ssh_port` are present, then start the log collector
function Ensure-SSHKey {
    $sshDir = Join-Path $env:USERPROFILE '.ssh'
    if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir | Out-Null }
    $privateKeyPath = Join-Path $sshDir 'vast_ai_key'
    $publicKeyPath = "$privateKeyPath.pub"

    if (-not (Test-Path $privateKeyPath -PathType Leaf)) {
        Write-Host "SSH keypair not found. Generating: $privateKeyPath"
        & ssh-keygen -t rsa -b 4096 -f $privateKeyPath -N '' | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Host "ssh-keygen failed" -ForegroundColor Red; return $null }
    } else {
        Write-Host "Using existing SSH key: $privateKeyPath"
    }

    # Return paths
    return @{ private = $privateKeyPath; public = $publicKeyPath }
}

function Wait-For-SSH-Details {
    param([int]$timeoutSec = 600)
    $start = Get-Date
    while (((Get-Date) - $start).TotalSeconds -lt $timeoutSec) {
        try {
            $status = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool/status" -Headers @{ 'x-admin-key' = $env:ADMIN_API_KEY } -Method GET -TimeoutSec 10 -ErrorAction Stop
            if ($status.instance -and $status.instance.ssh_host -and $status.instance.ssh_port) {
                return $status.instance
            }
        } catch {
            # ignore transient errors
        }
        Start-Sleep -Seconds 5
    }
    return $null
}

if ($prewarmSuccess) {
    $keys = Ensure-SSHKey
    if ($keys -ne $null) {
        Write-Host "Waiting up to 10 minutes for instance SSH details..."
        $inst = Wait-For-SSH-Details -timeoutSec 600
        if ($inst -ne $null) {
            Write-Host "SSH details detected: $($inst.ssh_host):$($inst.ssh_port)"
            # Start collect_provision_logs.js to stream remote provisioning logs
            $outLog = Join-Path (Join-Path (Get-Location) 'logs') "provision_$($inst.contractId)_$((Get-Date -UFormat %s)).log"
            if (-not (Test-Path (Split-Path $outLog))) { New-Item -ItemType Directory -Path (Split-Path $outLog) -Force | Out-Null }
            $nodeCmd = "node"
            $scriptPath = 'scripts\collect_provision_logs.js'
            $args = @('--host', $inst.ssh_host, '--port', $inst.ssh_port.ToString(), '--key', (Resolve-Path $keys.private).Path, '--contract-id', $inst.contractId.ToString(), '--output', $outLog, '--timeout', '3600')
            Write-Host "Starting log collector: $nodeCmd $scriptPath $($args -join ' ')"
            Start-Process -NoNewWindow -FilePath $nodeCmd -ArgumentList $scriptPath + $args -WorkingDirectory (Get-Location)
            Write-Host "Log collector started; output -> $outLog"

            # --- Start persistent SSH tunnel managed by PM2 (comfy-tunnel) ---
            try {
                $pm2Name = 'comfy-tunnel'
                $sshCmd = "ssh -i `"$($keys.private)`" -o StrictHostKeyChecking=no -o UserKnownHostsFile=nul -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -L 8188:127.0.0.1:8188 -p $($inst.ssh_port) root@$($inst.ssh_host) -N"

                # Check if a pm2 process with this name exists
                $pm2List = & npx --yes pm2 list 2>$null | Out-String
                if ($pm2List -match $pm2Name) {
                    Write-Host "PM2 process '$pm2Name' exists; restarting with updated args..." -ForegroundColor Cyan
                    cmd /c "npx pm2 restart $pm2Name --update-env"
                } else {
                    Write-Host "Starting PM2-managed SSH tunnel as '$pm2Name'..." -ForegroundColor Cyan
                    # Start using bash -c so we can run ssh with complex args
                    cmd /c "npx pm2 start --name $pm2Name --interpreter bash -- -c \"$sshCmd\" --update-env"
                    Start-Sleep -Seconds 1
                    cmd /c "npx pm2 save"
                }

                Write-Host "Persistent SSH tunnel started and managed by PM2 as '$pm2Name'. You can view it with: npx pm2 status $pm2Name" -ForegroundColor Green
            } catch {
                Write-Host "Failed to start persistent SSH tunnel: $($_.Exception.Message)" -ForegroundColor Yellow
            }

        } else {
            Write-Host "No SSH details appeared within timeout; skipping automated log collection." -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "=== AI Kings Started ===" -ForegroundColor Green
Write-Host "Server is running at: http://localhost:3000"
Write-Host "Studio UI: http://localhost:3000/pages/studio.html"
Write-Host "Admin UI: http://localhost:3000/pages/admin-warm-pool.html"
Write-Host ""
Write-Host "To check warm-pool status:"
Write-Host "Invoke-WebRequest -Uri 'http://localhost:3000/api/proxy/admin/warm-pool/status' -Headers @{ 'x-admin-key'='$($env:ADMIN_API_KEY)' }"
Write-Host ""
Write-Host "To stop the server: Stop-Job -Id $($serverJob.Id); Remove-Job -Id $($serverJob.Id)"