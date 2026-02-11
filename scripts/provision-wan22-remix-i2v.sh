#!/bin/bash
set -e

# ---------------------------------------------------------------------------------------------------------------------
# 🔞 Wan 2.2 Remix NSFW I2V Provisioning Script (One-Click Edition)
# ---------------------------------------------------------------------------------------------------------------------
# This script provisions A AND STARTS a ComfyUI environment specifically for the Wan 2.2 Remix NSFW I2V workflow.
# It downloads:
#   1. Wan 2.2 Remix Models (High & Low Lighting) from 'FX-FeiHou/wan2.2-Remix/NSFW'
#   2. Wan 2.1 VAE and UMT5 Text Encoder from 'Comfy-Org/Wan_2.1_ComfyUI_repackaged'
#   3. ComfyUI-WanVideoWrapper and other essential nodes.
#   4. CREATES A VENV, STARTS ComfyUI, and STARTS a Cloudflare Tunnel.
# ---------------------------------------------------------------------------------------------------------------------

WORKSPACE="/workspace"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"

# --- LOGGING HELPER ---
log() { echo "$(date '+%H:%M:%S') $*"; }

# 1. System Packages
log "📦 Installing system dependencies..."
apt-get update && apt-get install -y aria2 p7zip-full python3-venv
pip install --no-cache-dir huggingface_hub

# 2. ComfyUI Setup
if [ ! -d "ComfyUI" ]; then
    log "🎨 Cloning ComfyUI..."
    git clone https://github.com/comfyanonymous/ComfyUI.git
fi

# 3. Virtual Environment (Critical for "One-Click" Run)
if [ ! -d "ComfyUI/venv" ]; then
    log "🐍 Creating Virtual Environment..."
    python3 -m venv ComfyUI/venv
fi
VENV_PYTHON="${WORKSPACE}/ComfyUI/venv/bin/python"

# Install ComfyUI Dependencies
log "📥 Installing Python dependencies..."
"$VENV_PYTHON" -m pip install --upgrade pip
"$VENV_PYTHON" -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
"$VENV_PYTHON" -m pip install -r ComfyUI/requirements.txt
"$VENV_PYTHON" -m pip install huggingface_hub

# 4. Model Downloads
log "⬇️  Downloading Wan 2.2 Remix Models..."
mkdir -p ComfyUI/models/diffusion_models
mkdir -p ComfyUI/models/text_encoders
mkdir -p ComfyUI/models/vae

# Function to download with aria2
download_file() {
    local url="$1"
    local dir="$2"
    local filename="$3"
    
    if [ -f "${dir}/${filename}" ]; then
        log "✅ ${filename} already exists."
    else
        log "⏳ Downloading ${filename}..."
        aria2c -x 16 -s 16 -k 1M --console-log-level=error -d "$dir" -o "$filename" "$url"
    fi
}

# --- Core Remix Models (From FX-FeiHou) ---
# High Lighting
download_file "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors" \
    "ComfyUI/models/diffusion_models" \
    "Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors"

# Low Lighting
download_file "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors" \
    "ComfyUI/models/diffusion_models" \
    "Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors"

# --- Support Models (From Comfy-Org) ---
# Text Encoder
download_file "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
    "ComfyUI/models/text_encoders" \
    "umt5_xxl_fp8_e4m3fn_scaled.safetensors"

# VAE
download_file "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
    "ComfyUI/models/vae" \
    "wan_2.1_vae.safetensors"

# 5. Custom Nodes
log "🧩 Installing Custom Nodes..."
cd ComfyUI/custom_nodes

# Helper to install node
install_node() {
    local url="$1"
    local dir_name="$2"
    if [ ! -d "$dir_name" ]; then
        git clone "$url"
        cd "$dir_name"
        if [ -f "requirements.txt" ]; then
            "$VENV_PYTHON" -m pip install -r requirements.txt
        fi
        cd ..
    fi
}

install_node "https://github.com/kijai/ComfyUI-WanVideoWrapper.git" "ComfyUI-WanVideoWrapper"
install_node "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git" "ComfyUI-Frame-Interpolation"
install_node "https://github.com/kijai/ComfyUI-KJNodes.git" "ComfyUI-KJNodes"
install_node "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" "ComfyUI-VideoHelperSuite"
install_node "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git" "ComfyUI-Custom-Scripts"
install_node "https://github.com/yolain/ComfyUI-Easy-Use.git" "ComfyUI-Easy-Use"

cd ../..

# ---------------------------------------------------------------------------------------------------------------------
# 🚀 STARTUP LOGIC (The "One-Click" Magic)
# ---------------------------------------------------------------------------------------------------------------------

start_comfyui() {
    log "🚀 Starting ComfyUI..."
    cd "${WORKSPACE}/ComfyUI"
    
    # Kill any existing ComfyUI
    pkill -f "python.*main.py" 2>/dev/null || true
    sleep 2

    setsid nohup "$VENV_PYTHON" main.py --listen 0.0.0.0 --port 8188 > "${WORKSPACE}/comfyui.log" 2>&1 < /dev/null &
    echo "$!" > "${WORKSPACE}/comfyui.pid"
    log "✅ ComfyUI started (PID: $!)"
}

start_cloudflare_tunnel() {
    log "☁️  Starting Cloudflare Tunnel..."
    local cf_bin="/usr/local/bin/cloudflared"
    if [[ ! -x "$cf_bin" ]]; then
        log "   📥 cloudflared not present; attempting download..."
        curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" -o "$cf_bin"
        chmod +x "$cf_bin"
    fi

    local TUNNEL_LOG="${WORKSPACE}/cloudflared.log"
    local TUNNEL_PID_FILE="${WORKSPACE}/cloudflared.pid"
    
    pkill -f "cloudflared" 2>/dev/null || true
    
    setsid nohup "$cf_bin" tunnel --url http://localhost:8188 > "$TUNNEL_LOG" 2>&1 < /dev/null &
    echo "$!" > "$TUNNEL_PID_FILE"

    log "   ⏳ Waiting for Tunnel URL..."
    local TUNNEL_URL=""
    for i in {1..30}; do
        TUNNEL_URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$TUNNEL_LOG" 2>/dev/null | head -n1 || true)
        [[ -n "$TUNNEL_URL" ]] && break
        sleep 1
    done

    if [[ -n "$TUNNEL_URL" ]]; then
        echo ""
        log "✅ ========================================================"
        log "✅ TUNNEL URL: $TUNNEL_URL"
        log "✅ ========================================================"
        echo "$TUNNEL_URL" > "${WORKSPACE}/tunnel_url.txt"
    else
        log "❌ Could not capture tunnel URL. Check ${TUNNEL_LOG}"
    fi
}

# --- MAIN EXECUTION ---
start_comfyui
start_cloudflare_tunnel

log "🎉 Provisioning & Startup Complete! Keep this terminal open if you want to see logs."
log "🌐 Monitor ${WORKSPACE}/comfyui.log for ComfyUI output."

# Simple Watchdog to keep script running and monitor processes
while true; do
    sleep 60
done
