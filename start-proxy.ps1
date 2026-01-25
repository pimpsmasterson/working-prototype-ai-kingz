# Start Vast.ai Proxy Server
# Usage: .\start-proxy.ps1

Write-Host "Starting Vast.ai Proxy Server..." -ForegroundColor Cyan

# Kill any stale node.exe processes (optional - comment out if you want to keep other node processes)
Write-Host "Cleaning up stale node processes..." -ForegroundColor Yellow
taskkill /IM node.exe /F 2>$null
Start-Sleep -Milliseconds 500

# Set required environment variables
$env:ADMIN_API_KEY = if ($env:ADMIN_API_KEY) { $env:ADMIN_API_KEY } else { "secure_admin_key_2026" }
$env:VASTAI_API_KEY = if ($env:VASTAI_API_KEY) { $env:VASTAI_API_KEY } else { "dummy_key_set_real_one" }

Write-Host "Admin API Key: $env:ADMIN_API_KEY" -ForegroundColor Green
Write-Host "Vast.ai API Key: $($env:VASTAI_API_KEY.Substring(0, [Math]::Min(10, $env:VASTAI_API_KEY.Length)))..." -ForegroundColor Green

# Start the proxy server
Write-Host "Launching server on http://localhost:3000 ..." -ForegroundColor Cyan
node server/vastai-proxy.js
