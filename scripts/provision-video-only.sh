#!/bin/bash
# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║   🎬 AI KINGS COMFYUI - VIDEO WORKFLOW PROVISIONER v1.0                       ║
# ║                                                                               ║
# ║   ✓ Optimized for Video Generation (Wan 2.2 / LTX-2 / AnimateDiff)            ║
# ║   ✓ NSFW Quality Optimized (Remix Models)                                     ║
# ║   ✓ Single GPU Targeted (24GB budget / 40GB+ mid-cost)                        ║
# ║   ✓ Auto-Swap & TCMalloc Hardening                                             ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

VERSION="v1.0"
PROVISIONER_SIGNATURE="🎬 AI KINGS COMFYUI - MASTER VIDEO PROVISIONER ${VERSION}"

set -uo pipefail

# Allow provisioning to continue even when some non-critical assets fail to download.
PROVISION_ALLOW_MISSING_ASSETS=${PROVISION_ALLOW_MISSING_ASSETS:-true}

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════
LOG_FILE="/tmp/provision_video.log"
log() { echo "$(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE"; }
log_err() { echo "$(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE" >&2; }
log_section() { log ""; log "═══════════════════════════════════════════════════════════════"; log "$*"; log "═══════════════════════════════════════════════════════════════"; }

# Cleanup handler
cleanup_on_exit() {
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        echo "   ✅ Provisioning script completed"
        return 0
    fi
    echo "⚠️  Error detected (exit code: $exit_code) - cleaning up..."
    for p in $(jobs -p); do kill -15 "$p" 2>/dev/null || true; done
    sleep 2
    for p in $(jobs -p); do kill -9 "$p" 2>/dev/null || true; done
    exit $exit_code
}
trap cleanup_on_exit EXIT INT TERM

# ═══════════════════════════════════════════════════════════════════════════════
# VIDEO MODEL DEFINITIONS (NSFW Optimized)
# Format: "PRIMARY_URL|FALLBACK_URL|filename"
# ═══════════════════════════════════════════════════════════════════════════════

# --- CORE VIDEO MODELS (Wan 2.1 & LTX-2) ---
VIDEO_MODELS=(
    # Wan 2.1 T2V 14B (Stable)
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_t2v_14B_bf16.safetensors|https://huggingface.co/wangkanai/wan21-bf16/resolve/main/wan2.1_t2v_14B_bf16.safetensors|wan2.1_t2v_14B_bf16.safetensors"
    
    # LTX-2 19B Dev (Public Mirror) - filename matches workflow
    "https://huggingface.co/Comfy-Org/ltx-2/resolve/main/ltx-2-19b-v0.9.safetensors|https://huggingface.co/Lightricks/LTX-Video-2/resolve/main/ltx-2-19b-dev-fp8.safetensors|ltx-2-19b-dev-fp8.safetensors"
)

# --- TEXT ENCODERS (UMT5 + CLIP) ---
TEXT_ENCODERS=(
    # Wan UMT5-XXL FP8 Scaled
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors|https://huggingface.co/wangkanai/wan21-fp8-encoders/resolve/main/umt5-xxl-encoder-fp8.safetensors|umt5_xxl_fp8_scaled.safetensors"
    
    # CLIP-L
    "https://huggingface.co/comfyanonymous/ensemble-default-models/resolve/main/clip_l.safetensors|https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/pytorch_model.bin|clip_l.safetensors"
)

# --- LoRAs & Specialized (Lightning) ---
LIGHTNING_LORAS=(
    # Wan 2.1 Lightning
    "https://huggingface.co/lightx2v/Wan2.1-Lightning/resolve/main/wan2.1_t2v_1.3B_lightx2v_4steps_lora_v1.0.safetensors||wan2_lightning_t2v.safetensors"
)

# --- VIDEO VAE ---
VAE_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/wan_2.1_vae.safetensors|https://huggingface.co/wangkanai/wan21-vae/resolve/main/wan_2.1_vae.safetensors|wan_vae.safetensors"
    "https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors||vae-ft-mse-840000-ema-pruned.safetensors"
)

# --- ADDITIONAL ASSETS ---
UPSCALER_MODELS=(
    "https://huggingface.co/Lightricks/LTX-Video-2/resolve/main/ltx-2-spatial-upscaler-x2-1.0.safetensors||ltx-2-spatial-upscaler-x2-1.0.safetensors"
)

DEPTH_MODELS=(
    "https://huggingface.co/P-E-T-E-R-P/Lotus-Depth-D-V1-1/resolve/main/lotus-depth-d-v1-1.safetensors||lotus-depth-d-v1-1.safetensors"
)

# ═══════════════════════════════════════════════════════════════════════════════
# CUSTOM NODES (Video-focused only)
# ═══════════════════════════════════════════════════════════════════════════════
NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/kijai/ComfyUI-WanVideoWrapper"
    "https://github.com/Lightricks/ComfyUI-LTXVideo"
    "https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
    "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/ssitu/ComfyUI_UltimateSDUpscale"
)

# ═══════════════════════════════════════════════════════════════════════════════

setup_swap() {
    log_section "🧠 CONFIGURE SWAP (OOM Protection)"
    if swapon --show | grep -q "/workspace/swapfile"; then
        log "   ✅ Swap already active"
        return 0
    fi
    local total_ram=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $total_ram -lt 40 ]]; then # Higher threshold for video
        log "   ⚠️  Low RAM detected ($total_ram GB). Creating 32GB swapfile..."
        swapoff -a 2>/dev/null || true
        fallocate -l 32G /workspace/swapfile || dd if=/dev/zero of=/workspace/swapfile bs=1M count=32768
        chmod 600 /workspace/swapfile && mkswap /workspace/swapfile && swapon /workspace/swapfile
        log "   ✅ 32GB Swap activated"
    fi
}

detect_cuda_version() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-gpu=cuda_version --format=csv,noheader,nounits | head -n1 | tr -d '\r'
    else
        echo "unknown"
    fi
}

install_apt_packages() {
    log_section "📦 INSTALLING SYSTEM PACKAGES"
    apt-get update
    apt-get install -y apt-utils aria2 wget curl git git-lfs ffmpeg libgl1 \
        python3-pip python3-venv build-essential libtcmalloc-minimal4 \
        libjpeg-dev libpng-dev libtiff-dev rclone
    log "✅ System packages ready"
}

activate_venv() {
    if [[ -f "${WORKSPACE}/venv/bin/activate" ]]; then
        source "${WORKSPACE}/venv/bin/activate"
        VENV_PYTHON="${WORKSPACE}/venv/bin/python3"
    else
        log "📦 Creating virtual environment (using system pkgs)..."
        python3 -m venv --system-site-packages "${WORKSPACE}/venv"
        source "${WORKSPACE}/venv/bin/activate"
        VENV_PYTHON="${WORKSPACE}/venv/bin/python3"
    fi
}

install_torch() {
    log_section "🧠 INSTALLING BLACKWELL-READY PYTORCH (v2.1)"
    activate_venv
    # Blackwell GPUs (RTX 50-series) require experimental/nightly torch for sm_120 support
    log "   🚀 Installing Torch with Nightly/Experimental CUDA support..."
    "$VENV_PYTHON" -m pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128
}

install_dependencies() {
    log_section "📦 INSTALLING PYTHON DEPENDENCIES"
    activate_venv
    local deps=(
        "transformers>=4.38.0" "accelerate>=0.26.0" "safetensors>=0.4.0"
        "einops>=0.7.0" "opencv-python-headless" "huggingface-hub"
        "timm" "scipy" "numpy<2" "pillow" "tqdm" "sqlalchemy>=2.0.0"
        "aiohttp>=3.9.0" "typing-extensions>=4.8.0" "moviepy" "imageio-ffmpeg"
        "onnxruntime-gpu" "opencv-contrib-python-headless"
        "gguf" "scikit-image" "sentencepiece" "cupy-cuda12x"
    )
    log "   🚀 Installing core dependencies..."
    "$VENV_PYTHON" -m pip install "${deps[@]}"
    log "   ✅ Core dependencies ready"
}

attempt_download() {
    local url="$1" dir="$2" filename="$3" min_size="${4:-1000000}"
    local filepath="${dir}/${filename}"
    mkdir -p "$dir"
    
    # Inject tokens for authentication
    if [[ -n "${CIVITAI_TOKEN:-}" && "$url" == *"civitai.com"* ]]; then
        url="${url}?token=$CIVITAI_TOKEN"
    fi
    
    # HuggingFace token support (critical for gated models)
    local HF_TOKEN="${HUGGINGFACE_HUB_TOKEN:-${HF_TOKEN:-}}"
    if [[ -n "$HF_TOKEN" && "$url" == *"huggingface.co"* ]]; then
        # Add token as header for aria2c (CRITICAL: Proper quoting for authentication)
        log "      ⏳ Downloading $filename (authenticated)..."
        if aria2c "$url" --header="Authorization: Bearer $HF_TOKEN" -d "$dir" -o "$filename" -x8 -s8 --continue=true --allow-overwrite=true --summary-interval=30 2>&1 | tee -a "$LOG_FILE" | grep -v "Downloaded"; then
            if [[ -f "$filepath" && $(stat -c%s "$filepath" 2>/dev/null) -ge "$min_size" ]]; then
                log "      ✅ Finished $filename"
                return 0
            fi
        fi
    else
        log "      ⏳ Downloading $filename..."
        if aria2c "$url" -d "$dir" -o "$filename" -x8 -s8 --continue=true --allow-overwrite=true --summary-interval=30 2>&1 | tee -a "$LOG_FILE" | grep -v "Downloaded"; then
            if [[ -f "$filepath" && $(stat -c%s "$filepath" 2>/dev/null) -ge "$min_size" ]]; then
                log "      ✅ Finished $filename"
                return 0
            fi
        fi
    fi
    
    log_err "      ❌ Failed to download $filename (or size too small)"
    return 1
}

download_file() {
    local entry="$1" dir="$2" min_size="${3:-1000000}"
    local primary fallback filename
    IFS='|' read -r primary fallback filename <<< "$entry"
    local filepath="${dir}/${filename}"
    if [[ -f "$filepath" && $(stat -c%s "$filepath" 2>/dev/null) -ge $min_size ]]; then
        return 0
    fi
    log "   📥 $filename"
    attempt_download "$primary" "$dir" "$filename" "$min_size" || \
    attempt_download "$fallback" "$dir" "$filename" "$min_size" || return 1
}

download_batch() {
    local dir="$1" min_size="$2"
    shift 2
    local arr=("$@")
    for entry in "${arr[@]}"; do
        download_file "$entry" "$dir" "$min_size" || true
    done
}

install_comfyui() {
    log_section "🖥️  INSTALLING COMFYUI"
    [[ ! -d "${COMFY_DIR}" ]] && git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "${COMFY_DIR}"
    cd "${COMFY_DIR}"
    install_torch && install_dependencies
    log "   📦 Installing ComfyUI requirements..."
    "$VENV_PYTHON" -m pip install -r requirements.txt
}

install_nodes() {
    log_section "🧩 INSTALLING VIDEO NODES"
    activate_venv
    
    # 1. Clone all nodes
    log "   📦 Cloning custom nodes..."
    for repo in "${NODES[@]}"; do
        local dir="${repo##*/}"
        local path="${COMFY_DIR}/custom_nodes/${dir}"
        if [[ ! -d "$path" ]]; then
            log "      🔗 Cloning $dir..."
            git clone --depth 1 "$repo" "$path" --recursive
        fi
    done

    # 2. Combine all requirements correctly (with newlines)
    local combined_reqs="${COMFY_DIR}/all_requirements.txt"
    > "$combined_reqs"
    find "${COMFY_DIR}/custom_nodes" -name "requirements.txt" -exec sh -c 'cat "$1"; echo ""' _ {} >> "$combined_reqs"
    
    # 3. Fast Install into VENV (No --system flag!)
    log "   🚀 Installing node dependencies..."
    if command -v uv &> /dev/null; then
        uv pip install -r "$combined_reqs" --python "$VENV_PYTHON"
    else
        "$VENV_PYTHON" -m pip install -r "$combined_reqs"
    fi

    # Re-repair SQLAlchemy
    "$VENV_PYTHON" -m pip install --upgrade "sqlalchemy>=2.0.0"
}

install_models() {
    log_section "📦 DOWNLOADING VIDEO MODELS (v2.0)"
    # Folder mapping to match graph expectations
    download_batch "${COMFY_DIR}/models/checkpoints" "1000000000" "${VIDEO_MODELS[@]}"
    download_batch "${COMFY_DIR}/models/text_encoders" "100000000" "${TEXT_ENCODERS[@]}"
    download_batch "${COMFY_DIR}/models/loras" "10000000" "${LIGHTNING_LORAS[@]}"
    download_batch "${COMFY_DIR}/models/vae" "100000000" "${VAE_MODELS[@]}"
    download_batch "${COMFY_DIR}/models/latent_upscale_models" "10000000" "${UPSCALER_MODELS[@]}"
    download_batch "${COMFY_DIR}/models/diffusion_models" "100000000" "${DEPTH_MODELS[@]}"
}

start_comfyui() {
    log_section "🚀 STARTING COMFYUI"
    cd "${COMFY_DIR}"
    activate_venv
    # Dependency check
    local sql_ver=$("$VENV_PYTHON" -c "import sqlalchemy; print(sqlalchemy.__version__)" 2>/dev/null || echo "0")
    [[ "${sql_ver:0:1}" -lt 2 ]] && "$VENV_PYTHON" -m pip install --upgrade "sqlalchemy>=2.0.0" >/dev/null 2>&1
    
    export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4
    setsid nohup "$VENV_PYTHON" main.py --listen 0.0.0.0 --port 8188 --enable-cors-header > "${WORKSPACE}/comfyui.log" 2>&1 < /dev/null &
    echo "$!" > "${WORKSPACE}/comfyui.pid"
    log "✅ ComfyUI started (PID: $!)"
}

start_cloudflare_tunnel() {
    log_section "☁️  STARTING CLOUDFLARE TUNNEL"
    local cf_bin="/usr/local/bin/cloudflared"
    if [[ ! -x "$cf_bin" ]]; then
        log "   📥 cloudflared not present; attempting download..."
        local CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
        if curl -fsSL --connect-timeout 15 --max-time 120 "$CLOUDFLARED_URL" -o "$cf_bin" 2>/dev/null; then
            chmod +x "$cf_bin" || true
            log "   ✅ Downloaded cloudflared"
        else
            log "   ❌ Failed to download cloudflared; skipping tunnel"
            return 1
        fi
    fi

    local TUNNEL_LOG="${WORKSPACE}/cloudflared.log"
    local TUNNEL_PID_FILE="${WORKSPACE}/cloudflared.pid"
    
    # Stop any existing run
    if [[ -f "$TUNNEL_PID_FILE" ]]; then
        local oldpid=$(cat "$TUNNEL_PID_FILE" 2>/dev/null || true)
        [[ -n "$oldpid" ]] && kill "$oldpid" 2>/dev/null || true
        rm -f "$TUNNEL_PID_FILE"
    fi

    log "   ⏳ Starting tunnel to localhost:8188..."
    setsid nohup "$cf_bin" tunnel --url http://localhost:8188 > "$TUNNEL_LOG" 2>&1 < /dev/null &
    echo "$!" > "$TUNNEL_PID_FILE"

    # Capture URL
    local TUNNEL_URL=""
    for i in {1..60}; do
        TUNNEL_URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$TUNNEL_LOG" 2>/dev/null | head -n1 || true)
        [[ -n "$TUNNEL_URL" ]] && break
        sleep 1
    done

    if [[ -n "$TUNNEL_URL" ]]; then
        log "   ✅ Tunnel URL: $TUNNEL_URL"
        echo "$TUNNEL_URL" > "${WORKSPACE}/tunnel_url.txt"
    else
        log "   ⚠️  Could not capture tunnel URL. Check ${TUNNEL_LOG}"
    fi
}

main() {
    log_section "🎬 VIDEO PROVISIONER STARTING"
    WORKSPACE=${WORKSPACE:-/workspace}
    mkdir -p "$WORKSPACE" && cd "$WORKSPACE"
    COMFY_DIR="${WORKSPACE}/ComfyUI"
    
    # Disk check check
    local available_kb=$(df "$WORKSPACE" | awk 'NR==2 {print $4}')
    if (( available_kb < 100 * 1024 * 1024 )); then
        log "❌ ERROR: Not enough disk space ($((available_kb/1024/1024))GB < 100GB)"
        exit 1
    fi

    setup_swap
    install_apt_packages
    install_comfyui
    install_nodes
    install_models
    start_comfyui
    
    if [[ "${DISABLE_CLOUDFLARED:-0}" != "1" ]]; then
        start_cloudflare_tunnel
    fi
    
    log "--- ✅ VIDEO PROVISIONING COMPLETE ---"
    log "🌐 ComfyUI: Port 8188"

    # Maintenance loop
    log "🛠️  Starting Maintenance Watchdog..."
    while true; do
        # Keep Cloudflare alive
        if [[ "${DISABLE_CLOUDFLARED:-0}" != "1" ]]; then
            local cfpid_file="${WORKSPACE}/cloudflared.pid"
            if [[ -f "$cfpid_file" ]]; then
                if ! kill -0 $(cat "$cfpid_file") 2>/dev/null; then
                    log "   ⚠️  Cloudflare died. Restarting..."
                    start_cloudflare_tunnel
                fi
            fi
        fi
        
        # Keep Comfyalive
        local cpid_file="${WORKSPACE}/comfyui.pid"
        if [[ -f "$cpid_file" ]]; then
            if ! kill -0 $(cat "$cpid_file") 2>/dev/null; then
                log "   ⚠️  ComfyUI died. Restarting..."
                start_comfyui
            fi
        fi
        
        sleep 30
    done
}

main "$@"
