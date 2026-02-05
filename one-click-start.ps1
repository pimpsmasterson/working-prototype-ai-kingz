# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║   👑 AI KINGS ONE-CLICK START v4.0 (FIXED)                                   ║
# ║   Simplified, reliable startup with tunnel URL support                       ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   👑 AI KINGS ONE-CLICK START v4.0                           ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: Prerequisites Check
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "[1/6] Checking prerequisites..." -ForegroundColor Yellow

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "   ❌ Node.js not installed! Download from: https://nodejs.org/" -ForegroundColor Red
    exit 1
}

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "   ❌ npm not installed!" -ForegroundColor Red
    exit 1
}

Write-Host "   ✅ Node.js $(node --version)" -ForegroundColor Green
Write-Host "   ✅ npm $(npm --version)" -ForegroundColor Green

# Check if .env exists
if (-not (Test-Path ".env")) {
    Write-Host "   ❌ .env file not found! Please create it from .env.example" -ForegroundColor Red
    exit 1
}

Write-Host "   ✅ .env file found" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: Load Environment Variables
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "[2/6] Loading environment variables..." -ForegroundColor Yellow

# Load .env file
Get-Content ".env" | Where-Object { $_ -match '^[^#].*=' } | ForEach-Object {
    $parts = $_ -split '=', 2
    if ($parts.Count -eq 2) {
        $key = $parts[0].Trim()
        $value = $parts[1].Trim()
        Set-Item -Path "env:$key" -Value $value
    }
}

# Verify critical variables
$requiredVars = @('VASTAI_API_KEY', 'ADMIN_API_KEY')
$missing = @()
foreach ($var in $requiredVars) {
    if (-not (Test-Path "env:$var") -or [string]::IsNullOrWhiteSpace((Get-Item "env:$var").Value)) {
        $missing += $var
    }
}

if ($missing.Count -gt 0) {
    Write-Host "   ❌ Missing required variables: $($missing -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host "   ✅ Environment variables loaded" -ForegroundColor Green

# Display token previews (safely)
try {
    if ($env:CIVITAI_TOKEN -and $env:CIVITAI_TOKEN.Length -ge 8) {
        Write-Host "   ✅ Civitai token: $($env:CIVITAI_TOKEN.Substring(0,8))..." -ForegroundColor Green
    }
    if ($env:HUGGINGFACE_HUB_TOKEN -and $env:HUGGINGFACE_HUB_TOKEN.Length -ge 12) {
        Write-Host "   ✅ HuggingFace token: $($env:HUGGINGFACE_HUB_TOKEN.Substring(0,12))..." -ForegroundColor Green
    }
} catch {
    # Ignore display errors
}

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: Stop Existing Processes
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "[3/6] Cleaning up existing processes..." -ForegroundColor Yellow

# Kill processes on our ports
$ports = @(3000, 8080, 8188)
foreach ($port in $ports) {
    try {
        $connections = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        if ($connections) {
            $pids = $connections | Select-Object -ExpandProperty OwningProcess -Unique
            foreach ($pid in $pids) {
                $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
                if ($proc) {
                    Write-Host "   Stopping process on port ${port}: $($proc.Name) (PID: $pid)" -ForegroundColor Gray
                    Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
                }
            }
        }
    } catch {
        # Ignore errors
    }
}

# Wait for ports to be freed
Start-Sleep -Seconds 2

Write-Host "   ✅ Cleanup completed" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: Start Server
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "[4/6] Starting server..." -ForegroundColor Yellow

# Check if PM2 is available
$usePm2 = $false
if (Get-Command pm2 -ErrorAction SilentlyContinue) {
    $usePm2 = $true
    Write-Host "   Using PM2 for process management" -ForegroundColor Gray
    
    # Stop existing PM2 processes
    try {
        & pm2 delete vastai-proxy 2>&1 | Out-Null
    } catch {
        # Ignore if not running
    }
    
    # Start with PM2
    if (Test-Path "config/ecosystem.config.js") {
        & pm2 start config/ecosystem.config.js --update-env 2>&1 | Out-Null
        & pm2 save 2>&1 | Out-Null
        Write-Host "   ✅ Server started with PM2" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  ecosystem.config.js not found, using direct start" -ForegroundColor Yellow
        $usePm2 = $false
    }
}

if (-not $usePm2) {
    Write-Host "   Starting server directly with Node.js" -ForegroundColor Gray
    
    # Start server in background job
    $serverJob = Start-Job -ScriptBlock {
        param($workDir, $envVars)
        Set-Location $workDir
        
        # Set environment variables in job context
        foreach ($key in $envVars.Keys) {
            Set-Item -Path "env:$key" -Value $envVars[$key]
        }
        
        # Start server
        & node server/vastai-proxy.js
    } -ArgumentList (Get-Location).Path, (Get-ChildItem env: | ForEach-Object { @{$_.Name = $_.Value} } | Merge-HashTable)
    
    Write-Host "   ✅ Server started (Job ID: $($serverJob.Id))" -ForegroundColor Green
}

# Wait for server to start
Start-Sleep -Seconds 5

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5: Verify Server Health
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "[5/6] Verifying server health..." -ForegroundColor Yellow

$maxAttempts = 30
$healthy = $false

for ($i = 1; $i -le $maxAttempts; $i++) {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/health" -Method GET -TimeoutSec 5 -ErrorAction Stop
        if ($response.ok) {
            $healthy = $true
            Write-Host "   ✅ Server is healthy!" -ForegroundColor Green
            break
        }
    } catch {
        if ($i % 5 -eq 0) {
            Write-Host "   Waiting for server... ($i/$maxAttempts)" -ForegroundColor Gray
        }
        Start-Sleep -Seconds 2
    }
}

if (-not $healthy) {
    Write-Host "   ❌ Server failed to start within 60 seconds" -ForegroundColor Red
    Write-Host "   Check logs with: pm2 logs vastai-proxy" -ForegroundColor Yellow
    exit 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 6: Trigger Prewarm (Optional)
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "[6/6] Triggering GPU prewarm..." -ForegroundColor Yellow

try {
    $prewarmResult = Invoke-RestMethod `
        -Uri "http://localhost:3000/api/proxy/admin/warm-pool/prewarm" `
        -Headers @{ 'x-admin-key' = $env:ADMIN_API_KEY } `
        -Method POST `
        -TimeoutSec 10 `
        -ErrorAction Stop

    if ($prewarmResult.status -eq 'started') {
        Write-Host "   ✅ GPU prewarm initiated!" -ForegroundColor Green
        if ($prewarmResult.instance) {
            Write-Host "   Instance: $($prewarmResult.instance.contractId)" -ForegroundColor Gray
            Write-Host "   GPU: $($prewarmResult.instance.gpu_name)" -ForegroundColor Gray
        }
    } else {
        Write-Host "   ⚠️  Prewarm returned unexpected status: $($prewarmResult.status)" -ForegroundColor Yellow
    }
} catch {
    $err = $_.Exception.Message
    if ($err -match '403|forbidden') {
        Write-Host "   ❌ Prewarm failed: Invalid admin key" -ForegroundColor Red
    } else {
        Write-Host "   ⚠️  Prewarm failed: $err" -ForegroundColor Yellow
    }
    Write-Host "   You can manually prewarm later via the admin dashboard" -ForegroundColor Gray
}

# ═══════════════════════════════════════════════════════════════════════════════
# SUCCESS SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   ✅ AI KINGS STARTED SUCCESSFULLY!                           ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "🌐 Access Points:" -ForegroundColor Cyan
Write-Host "   Studio UI:        http://localhost:3000/pages/studio.html" -ForegroundColor White
Write-Host "   Admin Dashboard:  http://localhost:3000/pages/admin-warm-pool.html" -ForegroundColor White
Write-Host "   Health Check:     http://localhost:3000/api/proxy/health" -ForegroundColor White
Write-Host ""

Write-Host "📊 Useful Commands:" -ForegroundColor Cyan
if ($usePm2) {
    Write-Host "   View Logs:    pm2 logs vastai-proxy" -ForegroundColor White
    Write-Host "   Check Status: pm2 status" -ForegroundColor White
    Write-Host "   Stop Server:  pm2 stop vastai-proxy" -ForegroundColor White
    Write-Host "   Restart:      pm2 restart vastai-proxy" -ForegroundColor White
} else {
    Write-Host "   Stop Server:  Get-Process node | Stop-Process -Force" -ForegroundColor White
}
Write-Host ""

Write-Host "💡 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Open the Studio UI and create a Muse character" -ForegroundColor Gray
Write-Host "   2. Wait for GPU instance to be ready (~3-5 minutes)" -ForegroundColor Gray
Write-Host "   3. Start generating content!" -ForegroundColor Gray
Write-Host ""

Write-Host "🎉 Happy creating!" -ForegroundColor Magenta
Write-Host ""

# Helper function to merge hashtables (for PowerShell 5.1 compatibility)
function Merge-HashTable {
    param(
        [Parameter(ValueFromPipeline=$true)]
        [hashtable[]]$HashTables
    )
    
    $result = @{}
    foreach ($ht in $HashTables) {
        if ($ht) {
            foreach ($key in $ht.Keys) {
                $result[$key] = $ht[$key]
            }
        }
    }
    return $result
}
