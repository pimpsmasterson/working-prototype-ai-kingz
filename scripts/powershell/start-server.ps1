# AI KINGS Server Start Script
# Set your keys here or ensure they are in your environment variables

# Use existing environment variables if present, otherwise set placeholders
if (-not $env:VASTAI_API_KEY) { $env:VASTAI_API_KEY = "REPLACE_WITH_YOUR_VAST_API_KEY" }
if (-not $env:ADMIN_API_KEY) { $env:ADMIN_API_KEY = "REPLACE_WITH_SECURE_ADMIN_KEY" }
if (-not $env:HUGGINGFACE_HUB_TOKEN) { $env:HUGGINGFACE_HUB_TOKEN = "REPLACE_WITH_HF_TOKEN" }
if (-not $env:CIVITAI_TOKEN) { $env:CIVITAI_TOKEN = "REPLACE_WITH_CIVITAI_TOKEN" }
if (-not $env:AUDIT_SALT) { $env:AUDIT_SALT = "REPLACE_WITH_SECURE_SALT" }

# --- PROVISIONING CONFIGURATION ---
# Base URL for modular scripts (e.g. GitHub raw URL)
if (-not $env:SCRIPTS_BASE_URL) { $env:SCRIPTS_BASE_URL = "https://raw.githubusercontent.com/pimpsmasterson/working-prototype-ai-kingz/main/scripts/" }
# The main entry point script URL (points to the modular setup.sh)
$env:COMFYUI_PROVISION_SCRIPT = "https://gist.githubusercontent.com/pimpsmasterson/5a3dc3d4b9151081f3dab111d741a1e7/raw"

$env:WARM_POOL_SAFE_MODE = "0"
$env:WARM_POOL_IDLE_MINUTES = "15"
$env:WARM_POOL_DISK_GB = "300"  # Minimum 300GB disk space for instances
$env:PORT = "3000"
$env:COMFYUI_TUNNEL_URL = "http://localhost:8188"

Write-Host "Checking for API keys..."
if ($env:VASTAI_API_KEY -match "REPLACE_WITH") {
    Write-Host "⚠️  Warning: Some API keys are using placeholders. Server may not function correctly." -ForegroundColor Yellow
}

Write-Host "Starting server with environment variables..."
node server/vastai-proxy.js