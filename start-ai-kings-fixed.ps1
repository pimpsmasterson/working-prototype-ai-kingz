# AI Kings Automated Startup Script (fixed copy)
# This script kills existing processes, cleans the DB, starts PM2 server in a new window, waits for health, and triggers prewarm.

Write-Host "Starting AI Kings setup..."

# Load environment variables from .env file
Write-Host "Loading environment variables from .env file..."
if (Test-Path ".env") {
    Get-Content ".env" | Where-Object { $_ -match '^[^#].*=' } | ForEach-Object {
        $key, $value = $_ -split '=', 2
        $key = $key.Trim()
        $value = $value.Trim()
        # Remove inline comments and surrounding quotes
        $value = $value -replace '\s+#.*$',''
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) { if ($value.Length -ge 2) { $value = $value.Substring(1, $value.Length - 2) } }
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
Write-Host ""

# Assign admin key for later use and helper to mask secrets for output
$adminKey = $env:ADMIN_API_KEY
function Mask-Secret($s) {
    if (-not $s) { return '<missing>' }
    if ($s.Length -le 8) { return ('*' * ($s.Length - 4) + $s.Substring($s.Length - 4)) }
    return ('****' + $s.Substring($s.Length - 4))
}
Write-Host "Admin key loaded: $(Mask-Secret $adminKey)"

# Check if PM2 is available
if (-not (Get-Command pm2 -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: PM2 is not installed or not in PATH!" -ForegroundColor Red
    Write-Host "Install with: npm install -g pm2" -ForegroundColor Yellow
    exit 1
}

# Check if Node.js is available
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Node.js is not installed or not in PATH!" -ForegroundColor Red
    exit 1
}

# Step 1: Kill any existing node processes
Write-Host "Killing existing Node.js processes..."
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force

# Step 2: Clean DB
Write-Host "Cleaning database..."
node -e "const db=require('./server/db'); const s=db.getState(); s.instance=null; s.useDefaultScript=false; s.provisionAttempt=0; s.isPrewarming=false; db.saveState(s); console.log('DB cleared');"

# Step 3: Launch PM2 server in new PowerShell window (ensure env vars are present)
Write-Host "Starting PM2 server in new window..."
# Pass environment variables by creating a temporary script to avoid nested-quoting problems
$escapedVast = $env:VASTAI_API_KEY -replace "'","''"
$escapedAdmin = $env:ADMIN_API_KEY -replace "'","''"
$tempScript = Join-Path $env:TEMP ("start_pm2_vastai_{0}.ps1" -f ([guid]::NewGuid().ToString()))
$tempScriptLines = @()
$tempScriptLines += ('$env:VASTAI_API_KEY = ' + "'" + $escapedVast + "'")
$tempScriptLines += ('$env:ADMIN_API_KEY = ' + "'" + $escapedAdmin + "'")
$tempScriptLines += ("Set-Location -Path '$PWD'")
$tempScriptLines += 'pm2 delete vastai-proxy 2>$null'
$tempScriptLines += 'pm2 start config/ecosystem.config.js --update-env'
$tempScriptLines += 'pm2 save'
$tempScriptLines += "Write-Host 'PM2 server started. Press Ctrl+C to stop.'"
Set-Content -Path $tempScript -Value $tempScriptLines -Encoding UTF8
Start-Process powershell -ArgumentList '-NoExit', '-File', $tempScript

# Give PM2 a few seconds to register the process, then verify the pm2-managed env
Start-Sleep -Seconds 4
try {
    $pm2info = pm2 jlist | ConvertFrom-Json | Where-Object { $_.name -eq 'vastai-proxy' }
    if ($pm2info) {
        $pm2env = $pm2info.pm2_env
        $pmAdmin = $pm2env.ADMIN_API_KEY
        Write-Host "PM2 reports ADMIN_API_KEY: $(Mask-Secret $pmAdmin)"
        if ($pmAdmin -ne $adminKey) {
            Write-Host "Warning: ADMIN_API_KEY in PM2 does not match loaded key." -ForegroundColor Yellow
        }
    } else {
        Write-Host "PM2 process 'vastai-proxy' not found yet." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Could not verify PM2 env: $_" -ForegroundColor Yellow
}

# Step 4: Wait for server to be ready
Write-Host "Waiting for server to start..."
Start-Sleep -Seconds 10

# Step 5: Check health
try {
    $health = Invoke-WebRequest -Uri "http://localhost:3000/api/proxy/health" -Method GET -TimeoutSec 10
    if ($health.StatusCode -eq 200) {
        Write-Host "Server is healthy. Triggering prewarm..." -ForegroundColor Green
        Write-Host "Note: Prewarm searches for GPU offers and rents an instance - this takes 2-3 minutes" -ForegroundColor Cyan

        # Step 6: Run prewarm with retries and exponential backoff
        $attempts = 3
        $delay = 2
        $prewarmResult = $null
        for ($i = 1; $i -le $attempts; $i++) {
            try {
                Write-Host "Prewarm attempt $i/$attempts (this may take 2-3 minutes)..."
                $prewarmResult = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool/prewarm" -Headers @{ 'x-admin-key' = $adminKey } -Method POST -TimeoutSec 300 -ErrorAction Stop

                # Check if we got stuck in 'already_prewarming' from a previous failed attempt
                if ($prewarmResult.status -eq 'already_prewarming' -and $i -eq 1) {
                    Write-Host "Detected stuck 'already_prewarming' state - cleaning DB and retrying..." -ForegroundColor Yellow
                    node -e "const db=require('./server/db'); const s=db.getState(); s.isPrewarming=false; s.instance=null; db.saveState(s); console.log('Reset isPrewarming flag');"
                    Start-Sleep -Seconds 2
                    continue
                }

                Write-Host "Prewarm successful on attempt $i"
                break
            } catch {
                Write-Host "Prewarm attempt $i failed: $_" -ForegroundColor Yellow
                if ($i -lt $attempts) {
                    Write-Host "Retrying in $delay seconds..."
                    Start-Sleep -Seconds $delay
                    $delay = [Math]::Min($delay * 2, 30)
                }
            }
        }

        if ($prewarmResult) {
            Write-Host "Prewarm result:" -ForegroundColor Green
            $prewarmResult | ConvertTo-Json -Depth 6

            # Explain the status
            if ($prewarmResult.status -eq 'searching') {
                Write-Host "`n✓ Instance rental started - searching for GPU offers..." -ForegroundColor Green
            } elseif ($prewarmResult.status -eq 'already_present') {
                Write-Host "`n✓ Warm instance already running" -ForegroundColor Green
            } elseif ($prewarmResult.status -eq 'already_prewarming') {
                Write-Host "`nℹ Another prewarm operation is in progress" -ForegroundColor Yellow
            } else {
                Write-Host "`nStatus: $($prewarmResult.status)" -ForegroundColor Cyan
            }

            Write-Host "`nCheck status with:" -ForegroundColor Cyan
            Write-Host "Invoke-RestMethod -Uri 'http://localhost:3000/api/proxy/admin/warm-pool/status' -Headers @{ 'x-admin-key'='$(Mask-Secret $adminKey)' }"
        } else {
            Write-Host "Prewarm failed after $attempts attempts." -ForegroundColor Red
        }
    } else {
        Write-Host "Server health check failed." -ForegroundColor Red
    }
} catch {
    Write-Host "Server not ready or health check failed: $_"
}

Write-Host ""
Write-Host "=== AI Kings Setup Complete ===" -ForegroundColor Green
Write-Host "Server is running at: http://localhost:3000"
Write-Host "Studio UI: http://localhost:3000/pages/studio.html"
Write-Host "Admin UI: http://localhost:3000/pages/admin-warm-pool.html"
Write-Host ""
Write-Host "To check warm-pool status:"
Write-Host "Invoke-RestMethod -Uri 'http://localhost:3000/api/proxy/admin/warm-pool/status' -Headers @{ 'x-admin-key'='$adminKey' }"
Write-Host ""
Write-Host "To stop the server: pm2 stop vastai-proxy"
