# Presentation Pre-Flight Check
# Run this script before your presentation to verify everything is ready

Write-Host "`n==================================" -ForegroundColor Cyan
Write-Host "AI KINGS - Presentation Pre-Flight Check" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

$allGood = $true

# Check 1: PM2 Status
Write-Host "`n[1/6] Checking PM2 Server Status..." -ForegroundColor Yellow
try {
    $pm2Status = pm2 jlist 2>$null | ConvertFrom-Json
    $vastaiProxy = $pm2Status | Where-Object { $_.name -eq "vastai-proxy" }
    
    if ($vastaiProxy -and $vastaiProxy.pm2_env.status -eq "online") {
        Write-Host "  ✅ Server is running (PID: $($vastaiProxy.pid))" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Server is not running!" -ForegroundColor Red
        Write-Host "     Start it with: npm run start:pm2" -ForegroundColor Yellow
        $allGood = $false
    }
} catch {
    Write-Host "  ❌ PM2 not available or no processes running" -ForegroundColor Red
    Write-Host "     Start server with: npm run start:pm2" -ForegroundColor Yellow
    $allGood = $false
}

# Check 2: Health Endpoint
Write-Host "`n[2/6] Testing Health Endpoint..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/health" -Method Get -TimeoutSec 5
    if ($health.ok) {
        Write-Host "  ✅ Health check passed" -ForegroundColor Green
        Write-Host "     Message: $($health.message)" -ForegroundColor Gray
    } else {
        Write-Host "  ⚠️  Health check returned but not OK" -ForegroundColor Yellow
        $allGood = $false
    }
} catch {
    Write-Host "  ❌ Health check failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "     Is the server running on port 3000?" -ForegroundColor Yellow
    $allGood = $false
}

# Check 3: Admin Panel HTML
Write-Host "`n[3/6] Checking Admin Panel File..." -ForegroundColor Yellow
$adminPath = "pages\admin-warm-pool.html"
if (Test-Path $adminPath) {
    Write-Host "  ✅ Admin panel HTML exists" -ForegroundColor Green
    
    # Check if it has the admin panel link
    $content = Get-Content $adminPath -Raw
    if ($content -match "AI KINGS.*GPU Management Dashboard") {
        Write-Host "  ✅ Admin panel branding updated" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Admin panel branding might not be updated" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ❌ Admin panel HTML not found at $adminPath" -ForegroundColor Red
    $allGood = $false
}

# Check 4: Main Index Page
Write-Host "`n[4/6] Checking Main Index Page..." -ForegroundColor Yellow
$indexPath = "pages\index.html"
if (Test-Path $indexPath) {
    Write-Host "  ✅ Index page exists" -ForegroundColor Green
    
    # Check for admin link
    $content = Get-Content $indexPath -Raw
    if ($content -match "btn-admin-panel") {
        Write-Host "  ✅ Admin panel navigation icon added" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Admin panel icon might be missing" -ForegroundColor Yellow
    }
    
    # Check for studio embedding
    if ($content -match "hero-studio-wrapper") {
        Write-Host "  ✅ Studio embedding present" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Studio embedding might be missing" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ❌ Index page not found at $indexPath" -ForegroundColor Red
    $allGood = $false
}

# Check 5: Environment Variables
Write-Host "`n[5/6] Checking Environment Variables..." -ForegroundColor Yellow
$requiredVars = @("VASTAI_API_KEY", "ADMIN_API_KEY")
$missingVars = @()

foreach ($var in $requiredVars) {
    if ([string]::IsNullOrEmpty((Get-Item -Path Env:$var -ErrorAction SilentlyContinue).Value)) {
        $missingVars += $var
    }
}

if ($missingVars.Count -eq 0) {
    Write-Host "  ✅ All required environment variables are set" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Missing environment variables: $($missingVars -join ', ')" -ForegroundColor Yellow
    Write-Host "     Server might use .env file or these might be set elsewhere" -ForegroundColor Gray
}

# Check 6: Port Availability (if server not running)
Write-Host "`n[6/6] Checking Port 3000..." -ForegroundColor Yellow
try {
    $connections = Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue
    if ($connections) {
        Write-Host "  ✅ Port 3000 is in use (server should be running)" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Port 3000 is not in use" -ForegroundColor Yellow
        Write-Host "     Start server with: npm run start:pm2" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ℹ️  Could not check port status" -ForegroundColor Gray
}

# Final Summary
Write-Host "`n==================================" -ForegroundColor Cyan
if ($allGood) {
    Write-Host "✅ ALL SYSTEMS GO!" -ForegroundColor Green
    Write-Host "`nYou're ready for your presentation!" -ForegroundColor Green
    Write-Host "`nQuick Access URLs:" -ForegroundColor Cyan
    Write-Host "  Main Site:    http://localhost:3000/pages/index.html" -ForegroundColor White
    Write-Host "  Admin Panel:  http://localhost:3000/pages/admin-warm-pool.html" -ForegroundColor White
} else {
    Write-Host "⚠️  Some issues detected" -ForegroundColor Yellow
    Write-Host "`nPlease address the issues above before your presentation." -ForegroundColor Yellow
    Write-Host "`nQuick fixes:" -ForegroundColor Cyan
    Write-Host "  1. Start server:  npm run start:pm2" -ForegroundColor White
    Write-Host "  2. Check status:  pm2 status" -ForegroundColor White
    Write-Host "  3. View logs:     pm2 logs vastai-proxy" -ForegroundColor White
}
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
