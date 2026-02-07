# Start Vast.ai Proxy Server
# Usage: .\start-proxy.ps1

Write-Host "Starting Vast.ai Proxy Server..." -ForegroundColor Cyan

# Kill any stale node.exe processes (optional - comment out if you want to keep other node processes)
Write-Host "Cleaning up stale node processes..." -ForegroundColor Yellow
taskkill /IM node.exe /F 2>$null
Start-Sleep -Milliseconds 500

# Load environment variables from .env file if not already set
if (Test-Path ".env") {
    Write-Host "Loading .env file..." -ForegroundColor Cyan
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)\s*=\s*(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            # Strip inline comments and surrounding quotes
            $value = $value -replace '\s+#.*$',''
            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) { if ($value.Length -ge 2) { $value = $value.Substring(1, $value.Length - 2) } }
            if (-not [string]::IsNullOrEmpty($name) -and -not (Test-Path "env:$name")) {
                Set-Item -Path "env:$name" -Value $value
                Write-Host "  Set $name from .env" -ForegroundColor Gray
            }
        }
    }
}

# Set fallback values only if not in .env
$env:ADMIN_API_KEY = if ($env:ADMIN_API_KEY) { $env:ADMIN_API_KEY } else { "secure_admin_key_2026" }
$env:VASTAI_API_KEY = if ($env:VASTAI_API_KEY) { $env:VASTAI_API_KEY } else { "VASTAI_API_KEY_PLACEHOLDER" }
$env:HUGGINGFACE_HUB_TOKEN = if ($env:HUGGINGFACE_HUB_TOKEN) { $env:HUGGINGFACE_HUB_TOKEN } else { "HUGGINGFACE_HUB_TOKEN_PLACEHOLDER" }
$env:CIVITAI_TOKEN = if ($env:CIVITAI_TOKEN) { $env:CIVITAI_TOKEN } else { "CIVITAI_TOKEN_PLACEHOLDER" }
$env:COMFYUI_PROVISION_SCRIPT = if ($env:COMFYUI_PROVISION_SCRIPT) { $env:COMFYUI_PROVISION_SCRIPT } else { "https://gist.githubusercontent.com/pimpsmasterson/002d4121626567402b4c59febbc1297d/raw/gistfile1.txt" }
$env:SCRIPTS_BASE_URL = if ($env:SCRIPTS_BASE_URL) { $env:SCRIPTS_BASE_URL } else { "https://gist.githubusercontent.com/pimpsmasterson/002d4121626567402b4c59febbc1297d/raw" }

Write-Host "Admin API Key: $env:ADMIN_API_KEY" -ForegroundColor Green
Write-Host "Vast.ai API Key: $($env:VASTAI_API_KEY.Substring(0, [Math]::Min(10, $env:VASTAI_API_KEY.Length)))..." -ForegroundColor Green

if ($env:HUGGINGFACE_HUB_TOKEN) {
    Write-Host "Hugging Face Token: SET ✓" -ForegroundColor Green
}
if ($env:CIVITAI_TOKEN) {
    Write-Host "Civitai Token: SET ✓" -ForegroundColor Green
}
if ($env:COMFYUI_PROVISION_SCRIPT) {
    Write-Host "Custom Provision Script: $env:COMFYUI_PROVISION_SCRIPT" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "📋 GIST SETUP (one-time, 30 seconds):" -ForegroundColor Yellow
Write-Host "   1. Open: https://gist.github.com" -ForegroundColor Cyan
Write-Host "   2. Paste contents from: scripts/comfyui-nsfw-provision.sh" -ForegroundColor Cyan
Write-Host "   3. Click 'Create public gist'" -ForegroundColor Cyan
Write-Host "   4. Click 'Raw' button → Copy URL" -ForegroundColor Cyan
Write-Host "   5. Update this file and set:" -ForegroundColor Cyan
Write-Host "      `$env:COMFYUI_PROVISION_SCRIPT = 'YOUR_RAW_GIST_URL'" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

# Start the proxy server
Write-Host "Launching server on http://localhost:3000 ..." -ForegroundColor Cyan
node server/vastai-proxy.js

