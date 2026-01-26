# Test the running proxy server
Write-Host "Testing proxy server..." -ForegroundColor Cyan

Write-Host "`n1. Testing health endpoint..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/health"
    Write-Host "✅ Health check passed!" -ForegroundColor Green
    $health | ConvertTo-Json -Depth 5 | Write-Host
} catch {
    Write-Host "❌ Health check failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n2. Testing prewarm endpoint with admin key..." -ForegroundColor Yellow
try {
    $adminKey = "secure_admin_key_change_me"  # From .env file
    $prewarm = Invoke-RestMethod -Method POST -Uri "http://localhost:3000/api/proxy/warm-pool/prewarm" -Headers @{ "x-admin-key" = $adminKey }
    Write-Host "✅ Prewarm request succeeded!" -ForegroundColor Green
    $prewarm | ConvertTo-Json -Depth 5 | Write-Host
} catch {
    Write-Host "❌ Prewarm request failed: $_" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n3. Checking warm-pool status..." -ForegroundColor Yellow
try {
    $status = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/warm-pool"
    Write-Host "✅ Status check passed!" -ForegroundColor Green
    $status | ConvertTo-Json -Depth 5 | Write-Host
} catch {
    Write-Host "❌ Status check failed: $_" -ForegroundColor Red
}

Write-Host "`nTests complete!" -ForegroundColor Cyan
