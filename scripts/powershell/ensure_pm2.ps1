# AI Kings PM2 watchdog
# Checks that PM2 and 'vastai-proxy' app are running; restarts if necessary.

$logDir = Join-Path (Get-Location) 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$log = Join-Path $logDir 'pm2_watchdog.log'
function Log($m) { "$((Get-Date).ToString('o')) - $m" | Out-File -FilePath $log -Append }

# Run as non-fatal check
if (-not (Get-Command pm2 -ErrorAction SilentlyContinue)) {
    Log "pm2 not found in PATH; watchdog cannot manage PM2 on this host"
    exit 0
}

Log "Watchdog started"

# Get pm2 process list as JSON
$jlistRaw = & pm2 jlist 2>&1
if ($LASTEXITCODE -ne 0) {
    Log "pm2 jlist failed: $jlistRaw"
    # Try to resurrect pm2 saved processes
    try {
        & pm2 resurrect 2>&1 | Out-File -FilePath $log -Append
        Log "Attempted pm2 resurrect"
    } catch {
        Log ("pm2 resurrect failed: " + $_)
    }
    exit 0
}

$jRawStr = $jlistRaw | Out-String
if ($jRawStr -notmatch '^[\s\r\n]*\[') {
    Log ("pm2 jlist didn't return JSON: " + $jRawStr)
    try {
        & pm2 resurrect 2>&1 | Out-File -FilePath $log -Append
        Log "Attempted pm2 resurrect after non-JSON jlist"
    } catch {
        Log ("pm2 resurrect failed: " + $_)
    }
    exit 0
}

try {
    $j = $jRawStr | ConvertFrom-Json
} catch {
    Log ("Failed to parse pm2 jlist JSON: " + $_)
    try {
        & pm2 resurrect 2>&1 | Out-File -FilePath $log -Append
        Log "Attempted pm2 resurrect after JSON parse failure"
    } catch {
        Log ("pm2 resurrect failed: " + $_)
    }
    exit 0
}

$app = $j | Where-Object { $_.name -eq 'vastai-proxy' }

if (-not $app) {
    Log "vastai-proxy not found in PM2 process list - attempting to start from ecosystem.config.js"
    if (Test-Path 'config\ecosystem.config.js') {
        & pm2 start config\ecosystem.config.js --update-env --only vastai-proxy 2>&1 | Out-File -FilePath $log -Append
        & pm2 save 2>&1 | Out-File -FilePath $log -Append
        Log "Started vastai-proxy via ecosystem and saved PM2 state"
    } else {
        Log "ecosystem.config.js not found; attempting to start node process directly"
        & pm2 start server\vastai-proxy.js --name vastai-proxy 2>&1 | Out-File -FilePath $log -Append
        & pm2 save 2>&1 | Out-File -FilePath $log -Append
        Log "Started vastai-proxy directly and saved PM2 state"
    }
    exit 0
}

$status = $app.pm2_env.status
Log "vastai-proxy pm2 status: $status"

if ($status -ne 'online') {
    Log "vastai-proxy not online (status=$status) - restarting via pm2"
    & pm2 restart vastai-proxy 2>&1 | Out-File -FilePath $log -Append
    exit 0
}

# Check health endpoint
try {
    $h = Invoke-RestMethod -Uri 'http://localhost:3000/api/proxy/health' -Method GET -TimeoutSec 5 -ErrorAction Stop
    if (-not $h -or $h.status -eq 'down') {
        Log ("Health check returned down or invalid: " + ($h | ConvertTo-Json -Compress) + " - restarting")
        & pm2 restart vastai-proxy 2>&1 | Out-File -FilePath $log -Append
    } else {
        Log "Health check OK: $($h.status)"
    }
} catch {
    Log ("Health check failed: " + $_ + " - restarting PM2 process")
    & pm2 restart vastai-proxy 2>&1 | Out-File -FilePath $log -Append
}

