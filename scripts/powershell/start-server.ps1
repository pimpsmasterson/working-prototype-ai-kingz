# AI KINGS Server Start Script
# Set your keys here or ensure they are in your environment variables

# Use existing environment variables if present, otherwise set placeholders
if (-not $env:VASTAI_API_KEY) { $env:VASTAI_API_KEY = "REPLACE_WITH_YOUR_VAST_API_KEY" }
if (-not $env:ADMIN_API_KEY) { $env:ADMIN_API_KEY = "REPLACE_WITH_SECURE_ADMIN_KEY" }
if (-not $env:HUGGINGFACE_HUB_TOKEN) { $env:HUGGINGFACE_HUB_TOKEN = "REPLACE_WITH_HF_TOKEN" }
if (-not $env:CIVITAI_TOKEN) { $env:CIVITAI_TOKEN = "REPLACE_WITH_CIVITAI_TOKEN" }
if (-not $env:AUDIT_SALT) { $env:AUDIT_SALT = "REPLACE_WITH_SECURE_SALT" }

# --- PROVISIONING CONFIGURATION ---
# Base URL for modular scripts (enforced to use the official gist raw URL)
if (-not $env:SCRIPTS_BASE_URL) { $env:SCRIPTS_BASE_URL = "https://gist.githubusercontent.com/pimpsmasterson/5a3dc3d4b9151081f3dab111d741a1e7/raw" }
# The main entry point script URL (points to the modular setup.sh)
if (-not $env:COMFYUI_PROVISION_SCRIPT) { $env:COMFYUI_PROVISION_SCRIPT = "https://gist.githubusercontent.com/pimpsmasterson/5a3dc3d4b9151081f3dab111d741a1e7/raw" }
# Default enforce: only allow the official gist and abort provisioning if it fails
$env:PROVISION_ALLOWED_SCRIPTS = if ($env:PROVISION_ALLOWED_SCRIPTS) { $env:PROVISION_ALLOWED_SCRIPTS } else { "https://gist.githubusercontent.com/pimpsmasterson/5a3dc3d4b9151081f3dab111d741a1e7/raw" }
# Leave PROVISION_ALLOWED_HOSTS empty by default to skip host-level validation (set if you want explicit host checks)
$env:PROVISION_ALLOWED_HOSTS = if ($env:PROVISION_ALLOWED_HOSTS) { $env:PROVISION_ALLOWED_HOSTS } else { "" }
$env:PROVISION_STRICT = if ($env:PROVISION_STRICT) { $env:PROVISION_STRICT } else { "true" }

$env:WARM_POOL_SAFE_MODE = "0"
$env:WARM_POOL_IDLE_MINUTES = "15"
$env:WARM_POOL_DISK_GB = "600"  # Minimum 600GB disk space for instances
$env:PORT = "3000"
$env:COMFYUI_TUNNEL_URL = "http://localhost:8188"

Write-Host "Checking for API keys..."
if ($env:VASTAI_API_KEY -match "REPLACE_WITH") {
    Write-Host "⚠️  Warning: Some API keys are using placeholders. Server may not function correctly." -ForegroundColor Yellow
}

Write-Host "Starting server with environment variables..."

if (Get-Command pm2 -ErrorAction SilentlyContinue) {
    Write-Host "   PM2 detected - managing server via PM2 (recommended)" -ForegroundColor Gray
    if (Test-Path "config/ecosystem.config.js") {
        & pm2 start config/ecosystem.config.js --update-env --only vastai-proxy 2>&1 | Out-Null
        & pm2 save 2>&1 | Out-Null
        Write-Host "   ✅ Server started under PM2 and PM2 process list saved" -ForegroundColor Green

        # Attempt to ensure PM2 will resurrect on reboot (best-effort; may require elevation)
        try {
            & pm2 startup -u $env:USERNAME --hp $env:USERPROFILE 2>&1 | Out-Null
            Write-Host "   ⚙️  pm2 startup configured (best-effort)" -ForegroundColor Gray
        } catch {
            Write-Host "   ⚠️  pm2 startup command failed or requires elevated privileges; run 'pm2 startup' manually if you want auto-start after reboot" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ⚠️  No ecosystem.config.js found; falling back to direct server start" -ForegroundColor Yellow
        node server/vastai-proxy.js
    }
} else {
    Write-Host "   PM2 not installed; starting server directly (not daemonized)" -ForegroundColor Yellow
    node server/vastai-proxy.js
}