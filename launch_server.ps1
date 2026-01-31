# Launch helper (sanitized)
# Copy your secrets to a local .env (gitignored) and source them instead of hardcoding
# Example:
# $env:VASTAI_API_KEY = 'YOUR_VASTAI_API_KEY'
# $env:ADMIN_API_KEY = 'YOUR_ADMIN_API_KEY'
# $env:HUGGINGFACE_HUB_TOKEN = 'YOUR_HUGGINGFACE_HUB_TOKEN'
# $env:CIVITAI_TOKEN = 'YOUR_CIVITAI_TOKEN'
# $env:AUDIT_SALT = 'YOUR_AUDIT_SALT'
# $env:COMFYUI_PROVISION_SCRIPT = 'https://raw.githubusercontent.com/pimpsmasterson/working-prototype-ai-kingz/main/scripts/provision.sh'
# $env:PORT = '3000'
# $env:WARM_POOL_DISK_GB = '300'
# $env:WARM_POOL_SAFE_MODE = '0'
# $env:WARM_POOL_IDLE_MINUTES = '15'

# Start the proxy (no secrets):
Stop-Process -Name node -ErrorAction SilentlyContinue
node server/vastai-proxy.js
