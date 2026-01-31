#!/bin/bash
# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║   👑 AI KINGS COMFYUI - PRODUCTION PROVISIONER v2.1                          ║
# ║                                                                               ║
# ║   ✓ Ultra-Fast Parallel Downloads (aria2c 16x)                               ║
# ║   ✓ All 10+ Production NSFW Workflows (Embedded)                            ║
# ║   ✓ 30+ Curated LoRAs & Models (Pony, Wan, Flux)                             ║
# ║   ✓ Smart Rate-Limit Handling (Civitai Sequential, HF Parallel)              ║
# ║   ✓ Full Ubuntu 24.04 Compatibility                                         ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION & LOGGING
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

# 1. DEFINE LOGGING & PRE-FLIGHT
LOG_FILE="/tmp/provision_v2.log"
log() { echo "$(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE"; }
log_section() { log ""; log "═══════════════════════════════════════════════════════════════"; log "$*"; log "═══════════════════════════════════════════════════════════════"; }

REQUIRED_CMDS=("aria2c" "git" "python3" "curl" "df" "awk")
for cmd in "${REQUIRED_CMDS[@]}"; do
    command -v "$cmd" >/dev/null 2>&1 || { echo >&2 "❌ REQUIRED CMD MISSING: $cmd"; exit 1; }
done

log "🚀 Starting AI KINGS Provisioner v2.1 (Ironclad Edition)..."

# Ensure workspace exists and is writable.
DEFAULT_WS=${WORKSPACE:-/workspace}
if mkdir -p "$DEFAULT_WS" 2>/dev/null && cd "$DEFAULT_WS" 2>/dev/null; then
  WORKSPACE="$PWD"
fi

# 2.5 DISK SPACE CHECK (Ironclad)
REQUIRED_GB=50
AVAILABLE_KB=$(df "$WORKSPACE" | awk 'NR==2 {print $4}')
if (( AVAILABLE_KB < REQUIRED_GB * 1024 * 1024 )); then
    log "❌ ERROR: Insufficient disk space in $WORKSPACE."
    log "   Need: ${REQUIRED_GB}GB, Have: $((AVAILABLE_KB / 1024 / 1024))GB"
    # exit 1 # Warning only for now to allow partial progress
fi

COMFYUI_DIR=${WORKSPACE}/ComfyUI
# Finalize the log file to the chosen workspace
LOG_FILE="${WORKSPACE}/provision_v2.log"
MAX_PAR_HF=4      # Parallel downloads for HuggingFace/Catbox
MAX_PAR_CIVITAI=1 # Sequential for Civitai (avoids 429)

# Tokens (passed via environment)
CIVITAI_TOKEN="${CIVITAI_TOKEN:-}"
HUGGINGFACE_HUB_TOKEN="${HUGGINGFACE_HUB_TOKEN:-}"

log "📍 Working in: $WORKSPACE"

# ═══════════════════════════════════════════════════════════════════════════════
# APT PACKAGES (Cross-Ubuntu Compatible)
# ═══════════════════════════════════════════════════════════════════════════════
APT_PACKAGES=(
    "unrar" "p7zip-full" "unzip" "ffmpeg" "libgl1" "git-lfs" "file" "aria2" "curl"
    "python3-pip" "python3-dev" "build-essential" "libssl-dev" "libffi-dev"
    "libglib2.0-0" "libfreetype-dev" "libjpeg-dev" "libpng-dev" "libtiff-dev"
)

# ═══════════════════════════════════════════════════════════════════════════════
# CUSTOM NODES (Clean URLs)
# ═══════════════════════════════════════════════════════════════════════════════
NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
    "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
    "https://github.com/ssitu/ComfyUI_UltimateSDUpscale"
    "https://github.com/kijai/ComfyUI-DepthAnythingV2"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
    "https://github.com/kijai/ComfyUI-WanVideoWrapper"
    "https://github.com/jags111/efficiency-nodes-comfyui"
    "https://github.com/cubiq/ComfyUI_IPAdapter_plus"
    "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/city96/ComfyUI-GGUF"
)

# ═══════════════════════════════════════════════════════════════════════════════
# MODELS - Checkpoints
# ═══════════════════════════════════════════════════════════════════════════════
CHECKPOINT_MODELS=(
    "https://civitai.com/api/download/models/290640|ponyDiffusionV6XL.safetensors"
    "https://civitai.com/api/download/models/206536|pmXL_v1.safetensors"
    "https://civitai.com/api/download/models/128713|dreamshaper_8.safetensors"
    "https://civitai.com/api/download/models/914390|pony_realism_v2.2.safetensors"
    "https://civitai.com/api/download/models/2514310|wai_illustrious_sdxl.safetensors"
)

# ═══════════════════════════════════════════════════════════════════════════════
# MODELS - LoRAs (Cleaned Collection - Removed unwanted catbox models)
# ═══════════════════════════════════════════════════════════════════════════════
LORA_MODELS=(
    "https://civitai.com/api/download/models/152309|pony_realism_v2.1.safetensors"
    "https://civitai.com/api/download/models/382152|expressiveh_hentai.safetensors"
    # Removed: fondled.safetensors, wan_dr34ml4y_all_in_one.safetensors, wan_dr34mjob.safetensors
    # Removed all catbox.moe downloads: shared_clothes, xray_glasses, cunnilingus_gesture, etc.
)

# ═══════════════════════════════════════════════════════════════════════════════
# MODELS - Wan Video & Specialist Arrays
# ═══════════════════════════════════════════════════════════════════════════════
WAN_DIFFUSION_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_t2v_1.3B_fp16.safetensors|wan2.1_t2v_1.3B_fp16.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors|wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors|wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors"
)

WAN_CLIP_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn.safetensors|umt5_xxl_fp8_e4m3fn_scaled.safetensors"
)

WAN_VAE_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan2.1_vae.safetensors|wan_2.1_vae.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors|wan2.2_vae.safetensors"
)


ANIMATEDIFF_MODELS=(
    "https://huggingface.co/camenduru/AnimateDiff-sdxl-beta/resolve/main/mm_sdxl_v10_beta.ckpt|mm_sdxl_v1_beta.ckpt"
    "https://huggingface.co/guoyww/animatediff/resolve/main/mm_sd_v15_v2.ckpt|mm_sd_v15_v2.ckpt"
)

UPSCALE_MODELS=(
    "https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth|4x-UltraSharp.pth"
    "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth|RealESRGAN_x4plus.pth"
)

CONTROLNET_MODELS=(
    "https://huggingface.co/thibaud/controlnet-openpose-sdxl-1.0/resolve/main/OpenPoseXL2.safetensors|OpenPoseXL2.safetensors"
)

DETECTOR_MODELS=(
    "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt|face_yolov8m.pt"
    "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8n.pt|hand_yolov8n.pt"
    "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth|sam_vit_b_01ec64.pth"
)

RIFE_MODELS=(
    "https://github.com/hzwer/Practical-RIFE/releases/download/v4.26/rife426.pth|rife47.pth"
)

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

VENV_PYTHON="python3"
activate_venv() {
    # If already inside a virtualenv (VIRTUAL_ENV set), prefer that
    if [[ -n "${VIRTUAL_ENV:-}" ]]; then
        VENV_PYTHON="$(python3 -c 'import sys;print(sys.executable)')"
        log "✅ Using existing virtual env: ${VIRTUAL_ENV}"
        return 0
    fi

    if [[ -f "/venv/main/bin/activate" ]]; then
        source /venv/main/bin/activate
        VENV_PYTHON="/venv/main/bin/python3"
        log "✅ Activated venv: /venv/main"
    elif [[ -f "${WORKSPACE}/venv/bin/activate" ]]; then
        source "${WORKSPACE}/venv/bin/activate"
        VENV_PYTHON="${WORKSPACE}/venv/bin/python3"
        log "✅ Activated venv: ${WORKSPACE}/venv"
    else
        log "📦 Creating virtual environment..."
        python3 -m venv "${WORKSPACE}/venv"
        source "${WORKSPACE}/venv/bin/activate"
        VENV_PYTHON="${WORKSPACE}/venv/bin/python3"
        log "✅ Created/Activated venv: ${WORKSPACE}/venv"
    fi
} 

install_torch() {
    log_section "🧠 INSTALLING PYTORCH"
    activate_venv
    "$VENV_PYTHON" -m pip install --no-cache-dir \
        torch==2.1.2 torchvision==0.16.2 torchaudio==2.1.2 \
        --index-url https://download.pytorch.org/whl/cu118
}

install_essential_deps() {
    log_section "📦 INSTALLING ESSENTIAL DEPENDENCIES"
    activate_venv
    "$VENV_PYTHON" -m pip install --no-cache-dir \
        transformers==4.36.0 \
        accelerate \
        safetensors \
        einops \
        opencv-python-headless \
        insightface \
        onnxruntime-gpu \
        xformers \
        sentencepiece
}



install_apt_packages() {
    log_section "📦 INSTALLING SYSTEM PACKAGES"
    apt-get update -qq
    apt-get install -y -qq "${APT_PACKAGES[@]}" || {
        log "❌ CRITICAL: Failed to install system packages"
        exit 1
    }
    git lfs install --skip-repo 2>/dev/null || true
}

install_comfyui() {
    log_section "🖥️  INSTALLING COMFYUI"
    if [[ ! -d "${COMFYUI_DIR}" ]]; then
        git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}"
        cd "${COMFYUI_DIR}"
        install_torch
        install_essential_deps
        "$VENV_PYTHON" -m pip install -q -r requirements.txt
        cd "${WORKSPACE}"
        log "✅ ComfyUI installed"
    else
        log "   ✅ ComfyUI already installed"
    fi
}

install_nodes() {
    log_section "🧩 INSTALLING CUSTOM NODES"
    activate_venv
    
    for repo in "${NODES[@]}"; do
        # Robust trimming of spaces and hidden characters
        repo=$(echo "$repo" | tr -d '[:space:]')
        local dir="${repo##*/}"
        local path="${COMFYUI_DIR}/custom_nodes/${dir}"
        
        if [[ -d "$path" ]]; then
            log "   ✅ $dir exists"
        else
            log "   📥 Cloning $dir..."
            # Shallow clone first. Some repos use submodules which don't interact well with --depth=1 + --recursive.
            git clone --depth 1 "$repo" "$path" || {
                log "   ⚠️  Failed to clone $dir"
                continue
            }
            # If the repo declares submodules, initialize them properly
            if [[ -f "${path}/.gitmodules" ]]; then
                log "   🔁 Initializing submodules for $dir"
                (cd "$path" && git submodule update --init --recursive) || log "   ⚠️  Submodule init failed for $dir"
            fi
        fi
        
        # Install requirements
        if [[ -f "${path}/requirements.txt" ]]; then
            "$VENV_PYTHON" -m pip install --no-cache-dir -q -r "${path}/requirements.txt" || true
        fi 
    done
    
    # Core high-performance dependencies
    "$VENV_PYTHON" -m pip install --no-cache-dir -q einops accelerate transformers opencv-python-headless sageattention huggingface-hub 2>/dev/null || true
}

# Advanced Downloader (aria2c)
download_file() {
    local url="$1"
    local dir="$2"
    local filename="$3"
    local filepath="${dir}/${filename}"
    
    # 1. Validation (Skip if valid)
    if [[ -f "$filepath" ]]; then
        local size=$(stat -c%s "$filepath" 2>/dev/null || echo 0)
        [[ $size -gt 1000000 ]] && { log "   ✅ $filename"; return 0; }
        rm -f "$filepath"
    fi
    
    mkdir -p "$dir"
    local download_url="$url"
    local header_value=""

    # 2. Auth Handling (Security & Redirect Robustness)
    if [[ -n "$CIVITAI_TOKEN" && "$url" == *"civitai.com"* ]]; then
        # Use URL token for Civitai to ensure redirects (R2) preserve auth; avoid sending Authorization header.
        [[ "$url" == *"?"* ]] && download_url="${url}&token=$CIVITAI_TOKEN" || download_url="${url}?token=$CIVITAI_TOKEN"
        # Do NOT set header_value for Civitai to avoid duplicate/misapplied auth
    elif [[ -n "$HUGGINGFACE_HUB_TOKEN" && "$url" == *"huggingface.co"* ]]; then
        header_value="Authorization: Bearer $HUGGINGFACE_HUB_TOKEN"
    fi 

    log "   📥 $filename"

    # 3. IRONCLAD DOWNLOAD (aria2c with session file to hide tokens)
    if command -v aria2c &>/dev/null; then
        local session_file=$(mktemp)
        echo "$download_url" > "$session_file"
        echo "  dir=$dir" >> "$session_file"
        echo "  out=$filename" >> "$session_file"
        # Hide header in session file to prevent 'ps aux' visibility
        [[ -n "$header_value" ]] && echo "  header=$header_value" >> "$session_file"

        # Increased timeouts and retries for massive 14B models
        aria2c -i "$session_file" -x16 -s16 -j1 --max-connection-per-server=16 \
               --timeout=300 --retry-wait=10 --max-tries=10 \
               --file-allocation=none --continue=true \
               --quiet=true --log-level=error 2>/dev/null
        
        local exit_code=$?
        rm -f "$session_file"
        
        if [[ $exit_code -eq 0 && -f "$filepath" && $(stat -c%s "$filepath") -gt 1000000 ]]; then
            return 0
        fi
    fi

    # 4. FALLBACK (wget - last resort)
    local wget_opts=("-c" "-q" "--show-progress" "--timeout=600" "--tries=10" "-O" "$filepath")
    [[ -n "$header_value" ]] && wget_opts+=("--header=$header_value")
    wget "${wget_opts[@]}" "$download_url" 2>/dev/null
     
    if [[ ! -f "$filepath" || $(stat -c%s "$filepath") -lt 1000000 ]]; then
        log "   ❌ $filename failed"
        rm -f "$filepath"
        return 1
    fi
}

smart_download_parallel() {
    local dir="$1"
    local max_p="$2"
    shift 2
    local arr=("$@")
    
    local pids=()
    local count=0
    
    for entry in "${arr[@]}"; do
        local url="${entry%%|*}"
        local filename="${entry##*|}"
        [[ "$filename" == "$url" ]] && filename="${url##*/}" && filename="${filename%%\?*}"
        
        # If it's Civitai, don't parallelize to respect rate limits (429 prevention)
        if [[ "$url" == *"civitai.com"* ]]; then
            download_file "$url" "$dir" "$filename" || true
        else
            download_file "$url" "$dir" "$filename" &
            pids+=($!)
            ((count++))
            if (( count >= max_p )); then
                wait -n 2>/dev/null || true
                ((count--))
            fi
        fi
    done
    wait 2>/dev/null || true
}

install_models() {
    log_section "📦 DOWNLOADING MODELS (STAGED)"
    
    # Checkpoints & LoRAs
    smart_download_parallel "${COMFYUI_DIR}/models/checkpoints" 1 "${CHECKPOINT_MODELS[@]}"
    smart_download_parallel "${COMFYUI_DIR}/models/loras" 2 "${LORA_MODELS[@]}"
    
    # WAN Video (Specialized Directories)
    smart_download_parallel "${COMFYUI_DIR}/models/diffusion_models" 2 "${WAN_DIFFUSION_MODELS[@]}"
    smart_download_parallel "${COMFYUI_DIR}/models/clip" 2 "${WAN_CLIP_MODELS[@]}"
    smart_download_parallel "${COMFYUI_DIR}/models/vae" 2 "${WAN_VAE_MODELS[@]}"
    
    # Others
    smart_download_parallel "${COMFYUI_DIR}/models/animatediff_models" 2 "${ANIMATEDIFF_MODELS[@]}"
    smart_download_parallel "${COMFYUI_DIR}/models/upscale_models" 2 "${UPSCALE_MODELS[@]}"
    smart_download_parallel "${COMFYUI_DIR}/models/controlnet" 2 "${CONTROLNET_MODELS[@]}"
    smart_download_parallel "${COMFYUI_DIR}/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife" 2 "${RIFE_MODELS[@]}"
    smart_download_parallel "${COMFYUI_DIR}/models/ultralytics/bbox" 2 "${DETECTOR_MODELS[@]:0:2}"
    smart_download_parallel "${COMFYUI_DIR}/models/sams" 2 "${DETECTOR_MODELS[@]:2:1}"

    # ControlNet Assets
    download_file "https://huggingface.co/spaces/hysts/ControlNet/resolve/main/images/pose.png" \
        "${COMFYUI_DIR}/user/default" "example_pose.png"
}

verify_installation() {
    log_section "🔍 VERIFYING INSTALLATION"
    local critical_nodes=(
        "${COMFYUI_DIR}/custom_nodes/ComfyUI-WanVideoWrapper"
        "${COMFYUI_DIR}/custom_nodes/ComfyUI-AnimateDiff-Evolved"
        "${COMFYUI_DIR}/custom_nodes/ComfyUI-Impact-Pack"
        "${COMFYUI_DIR}/custom_nodes/ComfyUI-Frame-Interpolation"
    )
    
    for node in "${critical_nodes[@]}"; do
        if [[ -d "$node" ]]; then
            log "   ✅ $(basename "$node") exists"
        else
            log "   ❌ $(basename "$node") MISSING"
        fi
    done
}

validate_workflows() {
    log_section "🔍 VALIDATING WORKFLOW JSON"
    local workflows_dir="${COMFYUI_DIR}/user/default/workflows"
    if [[ ! -d "$workflows_dir" ]]; then
        log "   ⚠️  Workflows directory not found: $workflows_dir"
        return 0
    fi
    for wf in "$workflows_dir"/*.json; do
        [[ ! -f "$wf" ]] && continue
        if python3 -m json.tool "$wf" >/dev/null 2>&1; then
            log "   ✅ $(basename "$wf") is valid JSON"
        else
            log "   ❌ $(basename "$wf") is invalid JSON"
            python3 -m json.tool "$wf" 2>&1 | head -n 5
            exit 1
        fi
    done
}


install_workflows() {
    log_section "📝 INSTALLING PRODUCTION WORKFLOWS"
    local workflows_dir="${COMFYUI_DIR}/user/default/workflows"
    mkdir -p "$workflows_dir"

# NSFW IMAGE WORKFLOW (Pony XL - Fully Connected)
    # ═══════════════════════════════════════════════════════════════════════
    # ═══════════════════════════════════════════════════════════════════════
    # NSFW ULTIMATE IMAGE WORKFLOW (Pony XL + FaceDetailer + Upscale)
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_ultimate_image_workflow.json" << 'ULTIMGWORKFLOW'
{
  "last_node_id": 101,
  "last_link_id": 104,
  "nodes": [
    {
      "id": 1,
      "class_type": "CheckpointLoaderSimple",
      "pos": [50, 100],
      "size": [315, 98],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1, 21, 31], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [100], "slot_index": 1},
        {"name": "VAE", "type": "VAE", "links": [6, 23, 33], "slot_index": 2}
      ],
      "widgets_values": ["pmXL_v1.safetensors"]
    },
    {
      "id": 99,
      "class_type": "CLIPSetLastLayer",
      "pos": [50, 250],
      "size": [315, 58],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 100}],
      "outputs": [{"name": "CLIP", "type": "CLIP", "links": [2, 3, 22, 101, 102], "slot_index": 0}],
      "widgets_values": [-2]
    },
    {
      "id": 2,
      "class_type": "CLIPTextEncode",
      "pos": [400, 50],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 2}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [4, 34], "slot_index": 0}],
      "widgets_values": ["score_9, score_8_up, score_7_up, source_anime, rating_explicit, 1girl, beautiful detailed face, beautiful detailed eyes, high quality, nsfw, masterpiece, best quality, photorealistic, cinematic lighting"]
    },
    {
      "id": 3,
      "class_type": "CLIPTextEncode",
      "pos": [400, 200],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 3}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [5, 35], "slot_index": 0}],
      "widgets_values": ["score_6, score_5, score_4, source_pony, source_furry, low quality, worst quality, blurry, censored, watermark, ugly, bad anatomy, deformed, extra limbs, bad hands, bad fingers"]
    },
    {
      "id": 100,
      "class_type": "CLIPTextEncode",
      "pos": [1200, 550],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 101}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [50], "slot_index": 0}],
      "widgets_values": ["detailed face, sharp eyes, high quality, masterpiece"]
    },
    {
      "id": 101,
      "class_type": "CLIPTextEncode",
      "pos": [1200, 700],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 102}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [51], "slot_index": 0}],
      "widgets_values": ["blurry, deformed, ugly, messy, bad anatomy, low quality"]
    },
    {
      "id": 4,
      "class_type": "EmptyLatentImage",
      "pos": [400, 350],
      "size": [315, 106],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [7], "slot_index": 0}],
      "widgets_values": [832, 1216, 1]
    },
    {
      "id": 5,
      "class_type": "KSampler",
      "pos": [850, 100],
      "size": [315, 262],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1},
        {"name": "positive", "type": "CONDITIONING", "link": 4},
        {"name": "negative", "type": "CONDITIONING", "link": 5},
        {"name": "latent_image", "type": "LATENT", "link": 7}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [8], "slot_index": 0}],
      "widgets_values": [11223344, "randomize", 30, 7.0, "dpmpp_2m_sde", "karras", 1]
    },
    {
      "id": 6,
      "class_type": "VAEDecode",
      "pos": [1200, 100],
      "size": [210, 46],
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 8},
        {"name": "vae", "type": "VAE", "link": 6}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [20], "slot_index": 0}]
    },
    {
      "id": 10,
      "class_type": "UltralyticsDetectorProvider",
      "pos": [1200, 250],
      "size": [315, 100],
      "outputs": [{"name": "BBOX_DETECTOR", "type": "BBOX_DETECTOR", "links": [24], "slot_index": 0}],
      "widgets_values": ["face_yolov8m.pt"]
    },
    {
      "id": 11,
      "class_type": "SAMLoader",
      "pos": [1200, 400],
      "size": [315, 100],
      "outputs": [{"name": "SAM_MODEL", "type": "SAM_MODEL", "links": [25], "slot_index": 0}],
      "widgets_values": ["sam_vit_b_01ec64.pth"]
    },
    {
      "id": 12,
      "class_type": "FaceDetailer",
      "pos": [1600, 100],
      "size": [315, 500],
      "inputs": [
        {"name": "image", "type": "IMAGE", "link": 20},
        {"name": "model", "type": "MODEL", "link": 21},
        {"name": "clip", "type": "CLIP", "link": 22},
        {"name": "vae", "type": "VAE", "link": 23},
        {"name": "positive", "type": "CONDITIONING", "link": 50},
        {"name": "negative", "type": "CONDITIONING", "link": 51},
        {"name": "bbox_detector", "type": "BBOX_DETECTOR", "link": 24},
        {"name": "sam_model_opt", "type": "SAM_MODEL", "link": 25}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [32], "slot_index": 0}],
      "widgets_values": [384, 1024, 0.4, 20, 0.5, "randomize", "dpmpp_2m", "karras", 1, 0.4]
    },
    {
      "id": 13,
      "class_type": "UpscaleModelLoader",
      "pos": [1600, 650],
      "size": [315, 58],
      "outputs": [{"name": "UPSCALE_MODEL", "type": "UPSCALE_MODEL", "links": [36], "slot_index": 0}],
      "widgets_values": ["4x-UltraSharp.pth"]
    },
    {
      "id": 14,
      "class_type": "UltimateSDUpscale",
      "pos": [2000, 100],
      "size": [315, 600],
      "inputs": [
        {"name": "image", "type": "IMAGE", "link": 32},
        {"name": "model", "type": "MODEL", "link": 31},
        {"name": "positive", "type": "CONDITIONING", "link": 34},
        {"name": "negative", "type": "CONDITIONING", "link": 35},
        {"name": "vae", "type": "VAE", "link": 33},
        {"name": "upscale_model", "type": "UPSCALE_MODEL", "link": 36}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [40], "slot_index": 0}],
      "widgets_values": [2, 1024, 0.35, 20, "dpmpp_2m", "karras", 1, 512, 0, 1, 64, 32, 2, true, false]
    },
    {
      "id": 7,
      "class_type": "SaveImage",
      "pos": [2400, 100],
      "size": [315, 270],
      "inputs": [{"name": "images", "type": "IMAGE", "link": 40}],
      "widgets_values": ["aikings_ultimate"]
    }
  ],
  "links": [
    [1, 1, 0, 5, 0, "MODEL"],
    [100, 1, 1, 99, 0, "CLIP"],
    [2, 99, 0, 2, 0, "CLIP"],
    [3, 99, 0, 3, 0, "CLIP"],
    [101, 99, 0, 100, 0, "CLIP"],
    [102, 99, 0, 101, 0, "CLIP"],
    [4, 2, 0, 5, 1, "CONDITIONING"],
    [5, 3, 0, 5, 2, "CONDITIONING"],
    [6, 1, 2, 6, 1, "VAE"],
    [7, 4, 0, 5, 3, "LATENT"],
    [8, 5, 0, 6, 0, "LATENT"],
    [20, 6, 0, 12, 0, "IMAGE"],
    [21, 1, 0, 12, 1, "MODEL"],
    [22, 99, 0, 12, 2, "CLIP"],
    [23, 1, 2, 12, 3, "VAE"],
    [50, 100, 0, 12, 4, "CONDITIONING"],
    [51, 101, 0, 12, 5, "CONDITIONING"],
    [24, 10, 0, 12, 6, "BBOX_DETECTOR"],
    [25, 11, 0, 12, 7, "SAM_MODEL"],
    [31, 1, 0, 14, 1, "MODEL"],
    [32, 12, 0, 14, 0, "IMAGE"],
    [33, 1, 2, 14, 4, "VAE"],
    [34, 2, 0, 14, 2, "CONDITIONING"],
    [35, 3, 0, 14, 3, "CONDITIONING"],
    [36, 13, 0, 14, 5, "UPSCALE_MODEL"],
    [40, 14, 0, 7, 0, "IMAGE"]
  ],
  "version": 0.4
}
ULTIMGWORKFLOW

    # ═══════════════════════════════════════════════════════════════════════
    # NSFW VIDEO WORKFLOW (AnimateDiff SDXL - Fully Connected)
    # Uses: ADE_AnimateDiffLoaderGen1 + VHS_VideoCombine
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_video_workflow.json" << 'VIDWORKFLOW'
{
  "last_node_id": 99,
  "last_link_id": 100,
  "nodes": [
    {
      "id": 1,
      "class_type": "CheckpointLoaderSimple",
      "pos": [50, 100],
      "size": [315, 98],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [100], "slot_index": 1},
        {"name": "VAE", "type": "VAE", "links": [9], "slot_index": 2}
      ],
      "widgets_values": ["ponyDiffusionV6XL.safetensors"]
    },
    {
      "id": 99,
      "class_type": "CLIPSetLastLayer",
      "pos": [50, 250],
      "size": [315, 58],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 100}],
      "outputs": [{"name": "CLIP", "type": "CLIP", "links": [2, 3], "slot_index": 0}],
      "widgets_values": [-2]
    },
    {
      "id": 2,
      "class_type": "ADE_AnimateDiffLoaderGen1",
      "pos": [50, 350],
      "size": [315, 98],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1}
      ],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [4], "slot_index": 0}
      ],
      "widgets_values": ["mm_sdxl_v1_beta.ckpt", "linear (AnimateDiff-SDXL)"]
    },
    {
      "id": 3,
      "class_type": "CLIPTextEncode",
      "pos": [450, 50],
      "size": [400, 100],
      "inputs": [
        {"name": "clip", "type": "CLIP", "link": 2}
      ],
      "outputs": [
        {"name": "CONDITIONING", "type": "CONDITIONING", "links": [5], "slot_index": 0}
      ],
      "widgets_values": ["score_9, score_8_up, score_7_up, source_anime, rating_explicit, 1girl, dancing, dynamic motion, beautiful detailed face, high quality, nsfw, masterpiece, best quality, smooth animation"]
    },
    {
      "id": 4,
      "class_type": "CLIPTextEncode",
      "pos": [450, 200],
      "size": [400, 100],
      "inputs": [
        {"name": "clip", "type": "CLIP", "link": 3}
      ],
      "outputs": [
        {"name": "CONDITIONING", "type": "CONDITIONING", "links": [6], "slot_index": 0}
      ],
      "widgets_values": ["score_6, score_5, score_4, source_pony, source_furry, static, frozen, choppy, low quality, worst quality, blurry, censored, watermark, bad anatomy, deformed"]
    },
    {
      "id": 5,
      "class_type": "EmptyLatentImage",
      "pos": [450, 350],
      "size": [315, 106],
      "outputs": [
        {"name": "LATENT", "type": "LATENT", "links": [7], "slot_index": 0}
      ],
      "widgets_values": [512, 512, 16]
    },
    {
      "id": 6,
      "class_type": "KSampler",
      "pos": [900, 100],
      "size": [315, 262],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 4},
        {"name": "positive", "type": "CONDITIONING", "link": 5},
        {"name": "negative", "type": "CONDITIONING", "link": 6},
        {"name": "latent_image", "type": "LATENT", "link": 7}
      ],
      "outputs": [
        {"name": "LATENT", "type": "LATENT", "links": [8], "slot_index": 0}
      ],
      "widgets_values": [987654321, "randomize", 25, 7, "dpmpp_2m_sde", "karras", 1]
    },
    {
      "id": 7,
      "class_type": "VAEDecode",
      "pos": [1250, 100],
      "size": [210, 46],
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 8},
        {"name": "vae", "type": "VAE", "link": 9}
      ],
      "outputs": [
        {"name": "IMAGE", "type": "IMAGE", "links": [10], "slot_index": 0}
      ]
    },
    {
      "id": 8,
      "class_type": "VHS_VideoCombine",
      "pos": [1500, 100],
      "size": [315, 290],
      "inputs": [
        {"name": "images", "type": "IMAGE", "link": 10}
      ],
      "widgets_values": ["aikings_video", 8, 0, "image/webp", false, true, ""]
    }
  ],
  "links": [
    [1, 1, 0, 2, 0, "MODEL"],
    [100, 1, 1, 99, 0, "CLIP"],
    [2, 99, 0, 3, 0, "CLIP"],
    [3, 99, 0, 4, 0, "CLIP"],
    [4, 2, 0, 6, 0, "MODEL"],
    [5, 3, 0, 6, 1, "CONDITIONING"],
    [6, 4, 0, 6, 2, "CONDITIONING"],
    [7, 5, 0, 6, 3, "LATENT"],
    [8, 6, 0, 7, 0, "LATENT"],
    [9, 1, 2, 7, 1, "VAE"],
    [10, 7, 0, 8, 0, "IMAGE"]
  ],
  "version": 0.4
}
VIDWORKFLOW

    # ═══════════════════════════════════════════════════════════════════════
    # NSFW ULTIMATE VIDEO WORKFLOW (AnimateDiff + RIFE + Upscale)
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_ultimate_video_workflow.json" << 'ULTVIDWORKFLOW'
{
  "last_node_id": 99,
  "last_link_id": 100,
  "nodes": [
    {
      "id": 1,
      "class_type": "CheckpointLoaderSimple",
      "pos": [50, 100],
      "size": [315, 98],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [100], "slot_index": 1},
        {"name": "VAE", "type": "VAE", "links": [9], "slot_index": 2}
      ],
      "widgets_values": ["pmXL_v1.safetensors"]
    },
    {
      "id": 99,
      "class_type": "CLIPSetLastLayer",
      "pos": [50, 250],
      "size": [315, 58],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 100}],
      "outputs": [{"name": "CLIP", "type": "CLIP", "links": [2, 3], "slot_index": 0}],
      "widgets_values": [-2]
    },
    {
      "id": 2,
      "class_type": "ADE_AnimateDiffLoaderGen1",
      "pos": [50, 350],
      "size": [315, 98],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1}
      ],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [4], "slot_index": 0}
      ],
      "widgets_values": ["mm_sdxl_v1_beta.ckpt", "linear (AnimateDiff-SDXL)"]
    },
    {
      "id": 3,
      "class_type": "CLIPTextEncode",
      "pos": [450, 50],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 2}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [5], "slot_index": 0}],
      "widgets_values": ["score_9, score_8_up, score_7_up, source_anime, rating_explicit, beautiful woman dancing, smooth motion, cinematic lighting, high quality, nsfw, masterpiece, best quality, dynamic camera"]
    },
    {
      "id": 4,
      "class_type": "CLIPTextEncode",
      "pos": [450, 200],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 3}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [6], "slot_index": 0}],
      "widgets_values": ["score_6, score_5, score_4, source_pony, source_furry, static, frozen, choppy, blurry, low quality, worst quality, watermark, deformed, bad anatomy"]
    },
    {
      "id": 5,
      "class_type": "EmptyLatentImage",
      "pos": [450, 350],
      "size": [315, 106],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [7], "slot_index": 0}],
      "widgets_values": [512, 768, 24]
    },
    {
      "id": 6,
      "class_type": "KSampler",
      "pos": [900, 100],
      "size": [315, 262],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 4},
        {"name": "positive", "type": "CONDITIONING", "link": 5},
        {"name": "negative", "type": "CONDITIONING", "link": 6},
        {"name": "latent_image", "type": "LATENT", "link": 7}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [8], "slot_index": 0}],
      "widgets_values": [99887766, "randomize", 25, 7, "dpmpp_2m_sde", "karras", 1]
    },
    {
      "id": 7,
      "class_type": "VAEDecode",
      "pos": [1250, 100],
      "size": [210, 46],
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 8},
        {"name": "vae", "type": "VAE", "link": 9}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [10], "slot_index": 0}]
    },
    {
      "id": 9,
      "class_type": "RIFE VFI",
      "pos": [1500, 100],
      "size": [315, 150],
      "inputs": [{"name": "frames", "type": "IMAGE", "link": 10}],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [12], "slot_index": 0}],
      "widgets_values": ["rife47.pth", 12, 2, true, false, 1.0]
    },
    {
      "id": 13,
      "class_type": "UpscaleModelLoader",
      "pos": [1500, 300],
      "size": [315, 58],
      "outputs": [{"name": "UPSCALE_MODEL", "type": "UPSCALE_MODEL", "links": [20], "slot_index": 0}],
      "widgets_values": ["4x-UltraSharp.pth"]
    },
    {
      "id": 14,
      "class_type": "ImageUpscaleWithModel",
      "pos": [1900, 100],
      "size": [240, 46],
      "inputs": [
        {"name": "upscale_model", "type": "UPSCALE_MODEL", "link": 20},
        {"name": "image", "type": "IMAGE", "link": 12}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [21], "slot_index": 0}]
    },
    {
      "id": 10,
      "class_type": "VHS_VideoCombine",
      "pos": [2200, 100],
      "size": [315, 290],
      "inputs": [{"name": "images", "type": "IMAGE", "link": 21}],
      "widgets_values": ["aikings_ultimate_video", 24, 0, "video/h264-mp4", false, true, ""]
    }
  ],
  "links": [
    [1, 1, 0, 2, 0, "MODEL"],
    [100, 1, 1, 99, 0, "CLIP"],
    [2, 99, 0, 3, 0, "CLIP"],
    [3, 99, 0, 4, 0, "CLIP"],
    [4, 2, 0, 6, 0, "MODEL"],
    [5, 3, 0, 6, 1, "CONDITIONING"],
    [6, 4, 0, 6, 2, "CONDITIONING"],
    [7, 5, 0, 6, 3, "LATENT"],
    [8, 6, 0, 7, 0, "LATENT"],
    [9, 1, 2, 7, 1, "VAE"],
    [10, 7, 0, 9, 0, "IMAGE"],
    [12, 9, 0, 14, 1, "IMAGE"],
    [20, 13, 0, 14, 0, "UPSCALE_MODEL"],
    [21, 14, 0, 10, 0, "IMAGE"]
  ],
  "version": 0.4
}
ULTVIDWORKFLOW

    # ═══════════════════════════════════════════════════════════════════════
    # LORA-FOCUSED IMAGE WORKFLOW (With LoRA Loader - Fully Connected)
    # For using the specialized fetish LoRAs
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_lora_image_workflow.json" << 'LORAWORKFLOW'
{
  "last_node_id": 99,
  "last_link_id": 100,
  "nodes": [
    {
      "id": 1,
      "class_type": "CheckpointLoaderSimple",
      "pos": [50, 100],
      "size": [315, 98],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [100], "slot_index": 1},
        {"name": "VAE", "type": "VAE", "links": [10], "slot_index": 2}
      ],
      "widgets_values": ["ponyDiffusionV6XL.safetensors"]
    },
    {
      "id": 99,
      "class_type": "CLIPSetLastLayer",
      "pos": [50, 250],
      "size": [315, 58],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 100}],
      "outputs": [{"name": "CLIP", "type": "CLIP", "links": [2], "slot_index": 0}],
      "widgets_values": [-2]
    },
    {
      "id": 2,
      "class_type": "LoraLoader",
      "pos": [400, 100],
      "size": [315, 126],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1},
        {"name": "clip", "type": "CLIP", "link": 2}
      ],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [3], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [4, 5], "slot_index": 1}
      ],
      "widgets_values": ["pony_realism_v2.1.safetensors", 0.8, 0.8]
    },
    {
      "id": 3,
      "class_type": "CLIPTextEncode",
      "pos": [750, 50],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 4}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [6], "slot_index": 0}],
      "widgets_values": ["score_9, score_8_up, score_7_up, 1girl, detailed face, beautiful eyes, high quality, nsfw, masterpiece, photorealistic"]
    },
    {
      "id": 4,
      "class_type": "CLIPTextEncode",
      "pos": [750, 200],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 5}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [7], "slot_index": 0}],
      "widgets_values": ["score_6, score_5, score_4, low quality, blurry, censored, watermark, ugly, cartoon, anime"]
    },
    {
      "id": 5,
      "class_type": "EmptyLatentImage",
      "pos": [750, 350],
      "size": [315, 106],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [8], "slot_index": 0}],
      "widgets_values": [1024, 1024, 1]
    },
    {
      "id": 6,
      "class_type": "KSampler",
      "pos": [1200, 100],
      "size": [315, 262],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 3},
        {"name": "positive", "type": "CONDITIONING", "link": 6},
        {"name": "negative", "type": "CONDITIONING", "link": 7},
        {"name": "latent_image", "type": "LATENT", "link": 8}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [9], "slot_index": 0}],
      "widgets_values": [111222333, "randomize", 30, 7.0, "dpmpp_2m_sde", "karras", 1]
    },
    {
      "id": 7,
      "class_type": "VAEDecode",
      "pos": [1550, 100],
      "size": [210, 46],
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 9},
        {"name": "vae", "type": "VAE", "link": 10}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [11], "slot_index": 0}]
    },
    {
      "id": 8,
      "class_type": "SaveImage",
      "pos": [1800, 100],
      "size": [315, 270],
      "inputs": [{"name": "images", "type": "IMAGE", "link": 11}],
      "widgets_values": ["aikings_lora_nsfw"]
    }
  ],
  "links": [
    [1, 1, 0, 2, 0, "MODEL"],
    [100, 1, 1, 99, 0, "CLIP"],
    [2, 99, 0, 2, 1, "CLIP"],
    [3, 2, 0, 6, 0, "MODEL"],
    [4, 2, 1, 3, 0, "CLIP"],
    [5, 2, 1, 4, 0, "CLIP"],
    [6, 3, 0, 6, 1, "CONDITIONING"],
    [7, 4, 0, 6, 2, "CONDITIONING"],
    [8, 5, 0, 6, 3, "LATENT"],
    [9, 6, 0, 7, 0, "LATENT"],
    [10, 1, 2, 7, 1, "VAE"],
    [11, 7, 0, 8, 0, "IMAGE"]
  ],
  "version": 0.4
}
LORAWORKFLOW

    # ═══════════════════════════════════════════════════════════════════════
    # PORNMASTER PHOTOREALISTIC WORKFLOW (Fully Connected)
    # Optimized for photorealistic NSFW content
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_pornmaster_workflow.json" << 'PORNMASTERWORKFLOW'
{
  "last_node_id": 99,
  "last_link_id": 100,
  "nodes": [
    {
      "id": 1,
      "class_type": "CheckpointLoaderSimple",
      "pos": [50, 100],
      "size": [315, 98],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [100], "slot_index": 1},
        {"name": "VAE", "type": "VAE", "links": [6], "slot_index": 2}
      ],
      "widgets_values": ["pmXL_v1.safetensors"]
    },
    {
      "id": 99,
      "class_type": "CLIPSetLastLayer",
      "pos": [50, 250],
      "size": [315, 58],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 100}],
      "outputs": [{"name": "CLIP", "type": "CLIP", "links": [2, 3], "slot_index": 0}],
      "widgets_values": [-2]
    },
    {
      "id": 2,
      "class_type": "CLIPTextEncode",
      "pos": [450, 50],
      "size": [450, 120],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 2}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [4], "slot_index": 0}],
      "widgets_values": ["score_9, score_8_up, score_7_up, photorealistic, professional photography, beautiful woman, detailed skin texture, natural lighting, high resolution, sharp focus, 8k uhd, dslr quality, nsfw"]
    },
    {
      "id": 3,
      "class_type": "CLIPTextEncode",
      "pos": [450, 220],
      "size": [450, 120],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 3}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [5], "slot_index": 0}],
      "widgets_values": ["cartoon, anime, illustration, 3d render, fake, plastic, low quality, blurry, censored, watermark, text, ugly, deformed"]
    },
    {
      "id": 4,
      "class_type": "EmptyLatentImage",
      "pos": [450, 400],
      "size": [315, 106],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [7], "slot_index": 0}],
      "widgets_values": [832, 1216, 1]
    },
    {
      "id": 5,
      "class_type": "KSampler",
      "pos": [950, 100],
      "size": [315, 262],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1},
        {"name": "positive", "type": "CONDITIONING", "link": 4},
        {"name": "negative", "type": "CONDITIONING", "link": 5},
        {"name": "latent_image", "type": "LATENT", "link": 7}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [8], "slot_index": 0}],
      "widgets_values": [444555666, "randomize", 30, 7, "dpmpp_2m_sde", "karras", 1]
    },
    {
      "id": 6,
      "class_type": "VAEDecode",
      "pos": [1300, 100],
      "size": [210, 46],
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 8},
        {"name": "vae", "type": "VAE", "link": 6}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [9], "slot_index": 0}]
    },
    {
      "id": 7,
      "class_type": "SaveImage",
      "pos": [1550, 100],
      "size": [315, 270],
      "inputs": [{"name": "images", "type": "IMAGE", "link": 9}],
      "widgets_values": ["aikings_pornmaster"]
    }
  ],
  "links": [
    [1, 1, 0, 5, 0, "MODEL"],
    [100, 1, 1, 99, 0, "CLIP"],
    [2, 99, 0, 2, 0, "CLIP"],
    [3, 99, 0, 3, 0, "CLIP"],
    [4, 2, 0, 5, 1, "CONDITIONING"],
    [5, 3, 0, 5, 2, "CONDITIONING"],
    [6, 1, 2, 6, 1, "VAE"],
    [7, 4, 0, 5, 3, "LATENT"],
    [8, 5, 0, 6, 0, "LATENT"],
    [9, 6, 0, 7, 0, "IMAGE"]
  ],
  "version": 0.4
}
PORNMASTERWORKFLOW

    # ═══════════════════════════════════════════════════════════════════════
    # CONTROLNET OPENPOSE WORKFLOW (Pose-Guided Generation)
    # Uses: ControlNetLoader + Apply ControlNet + OpenPose
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_controlnet_pose_workflow.json" << 'POSEWORKFLOW'
{
  "last_node_id": 99,
  "last_link_id": 100,
  "nodes": [
    {
      "id": 1,
      "class_type": "CheckpointLoaderSimple",
      "pos": [50, 100],
      "size": [315, 98],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [100], "slot_index": 1},
        {"name": "VAE", "type": "VAE", "links": [10], "slot_index": 2}
      ],
      "widgets_values": ["pmXL_v1.safetensors"]
    },
    {
      "id": 99,
      "class_type": "CLIPSetLastLayer",
      "pos": [50, 250],
      "size": [315, 58],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 100}],
      "outputs": [{"name": "CLIP", "type": "CLIP", "links": [2, 3], "slot_index": 0}],
      "widgets_values": [-2]
    },
    {
      "id": 2,
      "class_type": "CLIPTextEncode",
      "pos": [400, 50],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 2}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [4], "slot_index": 0}],
      "widgets_values": ["score_9, score_8_up, score_7_up, 1girl, beautiful face, detailed eyes, high quality, nsfw, masterpiece, photorealistic, dynamic pose"]
    },
    {
      "id": 3,
      "class_type": "CLIPTextEncode",
      "pos": [400, 200],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 3}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [5], "slot_index": 0}],
      "widgets_values": ["score_6, score_5, score_4, low quality, blurry, censored, watermark, ugly, bad anatomy, deformed"]
    },
    {
      "id": 4,
      "class_type": "LoadImage",
      "pos": [50, 300],
      "size": [315, 314],
      "outputs": [
        {"name": "IMAGE", "type": "IMAGE", "links": [6], "slot_index": 0},
        {"name": "MASK", "type": "MASK", "links": null, "slot_index": 1}
      ],
      "widgets_values": ["example_pose.png", "image"]
    },
    {
      "id": 5,
      "class_type": "ControlNetLoader",
      "pos": [400, 400],
      "size": [315, 58],
      "outputs": [{"name": "CONTROL_NET", "type": "CONTROL_NET", "links": [7], "slot_index": 0}],
      "widgets_values": ["OpenPoseXL2.safetensors"]
    },
    {
      "id": 6,
      "class_type": "ControlNetApplyAdvanced",
      "pos": [800, 100],
      "size": [315, 186],
      "inputs": [
        {"name": "positive", "type": "CONDITIONING", "link": 4},
        {"name": "negative", "type": "CONDITIONING", "link": 5},
        {"name": "control_net", "type": "CONTROL_NET", "link": 7},
        {"name": "image", "type": "IMAGE", "link": 6}
      ],
      "outputs": [
        {"name": "positive", "type": "CONDITIONING", "links": [8], "slot_index": 0},
        {"name": "negative", "type": "CONDITIONING", "links": [9], "slot_index": 1}
      ],
      "widgets_values": [0.85, 0.0, 1.0]
    },
    {
      "id": 7,
      "class_type": "EmptyLatentImage",
      "pos": [800, 350],
      "size": [315, 106],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [11], "slot_index": 0}],
      "widgets_values": [832, 1216, 1]
    },
    {
      "id": 8,
      "class_type": "KSampler",
      "pos": [1200, 100],
      "size": [315, 262],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1},
        {"name": "positive", "type": "CONDITIONING", "link": 8},
        {"name": "negative", "type": "CONDITIONING", "link": 9},
        {"name": "latent_image", "type": "LATENT", "link": 11}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [12], "slot_index": 0}],
      "widgets_values": [55667788, "randomize", 30, 7.0, "dpmpp_2m_sde", "karras", 1]
    },
    {
      "id": 9,
      "class_type": "VAEDecode",
      "pos": [1550, 100],
      "size": [210, 46],
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 12},
        {"name": "vae", "type": "VAE", "link": 10}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [13], "slot_index": 0}]
    },
    {
      "id": 10,
      "class_type": "SaveImage",
      "pos": [1800, 100],
      "size": [315, 270],
      "inputs": [{"name": "images", "type": "IMAGE", "link": 13}],
      "widgets_values": ["aikings_pose"]
    }
  ],
  "links": [
    [1, 1, 0, 8, 0, "MODEL"],
    [100, 1, 1, 99, 0, "CLIP"],
    [2, 99, 0, 2, 0, "CLIP"],
    [3, 99, 0, 3, 0, "CLIP"],
    [4, 2, 0, 6, 0, "CONDITIONING"],
    [5, 3, 0, 6, 1, "CONDITIONING"],
    [6, 4, 0, 6, 3, "IMAGE"],
    [7, 5, 0, 6, 2, "CONTROL_NET"],
    [8, 6, 0, 8, 1, "CONDITIONING"],
    [9, 6, 1, 8, 2, "CONDITIONING"],
    [10, 1, 2, 9, 1, "VAE"],
    [11, 7, 0, 8, 3, "LATENT"],
    [12, 8, 0, 9, 0, "LATENT"],
    [13, 9, 0, 10, 0, "IMAGE"]
  ],
  "version": 0.4
}
POSEWORKFLOW

    # ═══════════════════════════════════════════════════════════════════════
    # WAN 2.1 TEXT-TO-VIDEO WORKFLOW (Repackaged Native Implementation)
    # Optimized for: 1.3B/14B Wan models, 480p/720p cinematic motion
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_wan21_video_workflow.json" << 'WANWORKFLOW'
{
  "last_node_id": 10,
  "last_link_id": 10,
  "nodes": [
    {
      "id": 1,
      "class_type": "WanVideoModelLoader",
      "pos": [50, 100],
      "size": [315, 82],
      "outputs": [{"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0}],
      "widgets_values": ["wan2.1_t2v_1.3B_fp16.safetensors", "fp16"]
    },
    {
      "id": 2,
      "class_type": "WanVideoT5TextEncode",
      "pos": [50, 250],
      "size": [315, 82],
      "outputs": [{"name": "CLIP", "type": "CLIP", "links": [2, 3], "slot_index": 0}],
      "widgets_values": ["umt5_xxl_fp8_e4m3fn_scaled.safetensors"]
    },
    {
      "id": 3,
      "class_type": "CLIPTextEncode",
      "pos": [450, 50],
      "size": [400, 150],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 2}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [4], "slot_index": 0}],
      "widgets_values": ["score_9, score_8_up, score_7_up, rating_explicit, masterpiece, best quality, cinematic, 1girl, full body, nsfw, realistic motion"]
    },
    {
      "id": 4,
      "class_type": "CLIPTextEncode",
      "pos": [450, 250],
      "size": [400, 150],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 3}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [5], "slot_index": 0}],
      "widgets_values": ["score_6, score_5, score_4, low quality, worst quality, blurry, watermark, bad anatomy"]
    },
    {
      "id": 5,
      "class_type": "WanVideoSampler",
      "pos": [900, 100],
      "size": [315, 450],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1},
        {"name": "positive", "type": "CONDITIONING", "link": 4},
        {"name": "negative", "type": "CONDITIONING", "link": 5},
        {"name": "latent_image", "type": "LATENT", "link": 9}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [6], "slot_index": 0}],
      "widgets_values": [30, 7.0, 11223344, "randomize"]
    },
    {
      "id": 9,
      "class_type": "EmptyWanVideoLatent",
      "pos": [900, 600],
      "size": [315, 106],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [9], "slot_index": 0}],
      "widgets_values": [832, 480, 81]
    },
    {
      "id": 6,
      "class_type": "WanVideoVaeLoader",
      "pos": [900, 750],
      "size": [315, 58],
      "outputs": [{"name": "VAE", "type": "VAE", "links": [7], "slot_index": 0}],
      "widgets_values": ["wan_2.1_vae.safetensors"]
    },
    {
      "id": 7,
      "class_type": "VAEDecode",
      "pos": [1250, 100],
      "size": [210, 46],
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 6},
        {"name": "vae", "type": "VAE", "link": 7}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [8], "slot_index": 0}]
    },
    {
      "id": 8,
      "class_type": "VHS_VideoCombine",
      "pos": [1500, 100],
      "size": [315, 350],
      "inputs": [{"name": "images", "type": "IMAGE", "link": 8}],
      "widgets_values": ["aikings_wan", 16, 0, "video/h264-mp4", false, true, "", 6]
    }
  ],
  "links": [
    [1, 1, 0, 5, 0, "MODEL"],
    [2, 2, 0, 3, 0, "CLIP"],
    [3, 2, 0, 4, 0, "CLIP"],
    [4, 3, 0, 5, 1, "CONDITIONING"],
    [5, 4, 0, 5, 2, "CONDITIONING"],
    [9, 9, 0, 5, 3, "LATENT"],
    [6, 5, 0, 7, 0, "LATENT"],
    [7, 6, 0, 7, 1, "VAE"],
    [8, 7, 0, 8, 0, "IMAGE"]
  ],
  "version": 0.4
}
WANWORKFLOW

    # ═══════════════════════════════════════════════════════════════════════
    # MASTER FURRY REALISTIC VIDEO WORKFLOW (SDXL + LoRA Stacker)
    # Optimized for: Realistic furry NSFW, skin/fur texture, heavy LoRA use
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_realistic_furry_video_workflow.json" << 'FURRYWORKFLOW'
{
  "last_node_id": 99,
  "last_link_id": 100,
  "nodes": [
    {
      "id": 1,
      "class_type": "CheckpointLoaderSimple",
      "pos": [50, 100],
      "size": [315, 98],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [100], "slot_index": 1},
        {"name": "VAE", "type": "VAE", "links": [3], "slot_index": 2}
      ],
      "widgets_values": ["pony_realism_v2.2.safetensors"]
    },
    {
      "id": 99,
      "class_type": "CLIPSetLastLayer",
      "pos": [50, 250],
      "size": [315, 58],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 100}],
      "outputs": [{"name": "CLIP", "type": "CLIP", "links": [2], "slot_index": 0}],
      "widgets_values": [-2]
    },
    {
      "id": 2,
      "class_type": "LoraStacker",
      "pos": [50, 350],
      "size": [315, 300],
      "outputs": [{"name": "LORA_STACK", "type": "LORA_STACK", "links": [4], "slot_index": 0}],
      "widgets_values": [
        "Enabled", "pony_realism_v2.1.safetensors", 0.6, 0.6,
        "Enabled", "defecation_v1.safetensors", 0.5, 0.5,
        "Disabled", "None", 0.0, 0.0,
        "Disabled", "None", 0.0, 0.0,
        "Disabled", "None", 0.0, 0.0
      ]
    },
    {
      "id": 3,
      "class_type": "ApplyLoraStack",
      "pos": [400, 100],
      "size": [315, 120],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1},
        {"name": "clip", "type": "CLIP", "link": 2},
        {"name": "lora_stack", "type": "LORA_STACK", "link": 4}
      ],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [5], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [6], "slot_index": 1}
      ]
    },
    {
      "id": 4,
      "class_type": "ADE_AnimateDiffLoaderGen1",
      "pos": [400, 300],
      "size": [315, 98],
      "inputs": [{"name": "model", "type": "MODEL", "link": 5}],
      "outputs": [{"name": "MODEL", "type": "MODEL", "links": [7], "slot_index": 0}],
      "widgets_values": ["mm_sdxl_v1_beta.ckpt", "linear (AnimateDiff-SDXL)"]
    },
    {
      "id": 5,
      "class_type": "CLIPTextEncode",
      "pos": [750, 50],
      "size": [400, 150],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 6}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [8], "slot_index": 0}],
      "widgets_values": ["score_9, score_8_up, score_7_up, source_anime, rating_explicit, masterpiece, best quality, cinematic, furry, anthropomorphic, realistic fur texture, detailed skin, 1girl, full body, wide shot, nsfw, explicit"]
    },
    {
      "id": 6,
      "class_type": "CLIPTextEncode",
      "pos": [750, 250],
      "size": [400, 150],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 30}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [9], "slot_index": 0}],
      "widgets_values": ["score_6, score_5, score_4, source_pony, low quality, worst quality, blurry, watermark, bad anatomy, deformed, human eyes on furry"]
    },

    {
      "id": 7,
      "class_type": "EmptyLatentImage",
      "pos": [750, 450],
      "size": [315, 106],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [10], "slot_index": 0}],
      "widgets_values": [832, 1216, 16]
    },
    {
      "id": 8,
      "class_type": "KSampler",
      "pos": [1200, 100],
      "size": [315, 262],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 7},
        {"name": "positive", "type": "CONDITIONING", "link": 8},
        {"name": "negative", "type": "CONDITIONING", "link": 9},
        {"name": "latent_image", "type": "LATENT", "link": 10}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [11], "slot_index": 0}],
      "widgets_values": [44556677, "randomize", 30, 7.0, "dpmpp_2m_sde", "karras", 1]
    },
    {
      "id": 9,
      "class_type": "VAEDecode",
      "pos": [1550, 100],
      "size": [210, 46],
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 11},
        {"name": "vae", "type": "VAE", "link": 3}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [12], "slot_index": 0}]
    },
    {
      "id": 10,
      "class_type": "VHS_VideoCombine",
      "pos": [1800, 100],
      "size": [315, 350],
      "inputs": [{"name": "images", "type": "IMAGE", "link": 12}],
      "widgets_values": ["aikings_furry_realistic", 12, 0, "video/h264-mp4", false, true, "", 6]
    }
  ],
  "links": [
    [1, 1, 0, 3, 0, "MODEL"],
    [100, 1, 1, 99, 0, "CLIP"],
    [2, 99, 0, 3, 1, "CLIP"],
    [3, 1, 2, 9, 1, "VAE"],
    [4, 2, 0, 3, 2, "LORA_STACK"],
    [5, 3, 0, 4, 0, "MODEL"],
    [6, 3, 1, 5, 0, "CLIP"],
    [30, 3, 1, 6, 0, "CLIP"],
    [7, 4, 0, 8, 0, "MODEL"],
    [8, 5, 0, 8, 1, "CONDITIONING"],
    [9, 6, 0, 8, 2, "CONDITIONING"],
    [10, 7, 0, 8, 3, "LATENT"],
    [11, 8, 0, 9, 0, "LATENT"],
    [12, 9, 0, 10, 0, "IMAGE"]
  ],
  "version": 0.4
}
FURRYWORKFLOW

    # ═══════════════════════════════════════════════════════════════════════
    # ULTIMATE CINEMA PRODUCTION WORKFLOW (Full Scene, Multiple Subjects)
    # Optimized for: Wide shots, full body, realistic motion, NSFW scenes
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_cinema_production_workflow.json" << 'CINEMAWORKFLOW'
{
  "last_node_id": 99,
  "last_link_id": 100,
  "nodes": [
    {
      "id": 1,
      "class_type": "CheckpointLoaderSimple",
      "pos": [50, 100],
      "size": [315, 98],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [100], "slot_index": 1},
        {"name": "VAE", "type": "VAE", "links": [15], "slot_index": 2}
      ],
      "widgets_values": ["pmXL_v1.safetensors"]
    },
    {
      "id": 99,
      "class_type": "CLIPSetLastLayer",
      "pos": [50, 250],
      "size": [315, 58],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 100}],
      "outputs": [{"name": "CLIP", "type": "CLIP", "links": [2, 3], "slot_index": 0}],
      "widgets_values": [-2]
    },
    {
      "id": 2,
      "class_type": "ADE_AnimateDiffLoaderGen1",
      "pos": [50, 350],
      "size": [315, 98],
      "inputs": [{"name": "model", "type": "MODEL", "link": 1}],
      "outputs": [{"name": "MODEL", "type": "MODEL", "links": [4], "slot_index": 0}],
      "widgets_values": ["mm_sdxl_v1_beta.ckpt", "linear (AnimateDiff-SDXL)"]
    },
    {
      "id": 3,
      "class_type": "CLIPTextEncode",
      "pos": [400, 50],
      "size": [500, 120],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 2}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [5], "slot_index": 0}],
      "widgets_values": ["score_9, score_8_up, score_7_up, source_anime, rating_explicit, masterpiece, best quality, cinematic, wide shot, full body, multiple girls, 2girls, detailed background, interior room, professional lighting, realistic proportions, detailed faces, beautiful eyes, nsfw, explicit, dynamic pose, interaction"]
    },
    {
      "id": 4,
      "class_type": "CLIPTextEncode",
      "pos": [400, 220],
      "size": [500, 120],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 3}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [6], "slot_index": 0}],
      "widgets_values": ["score_6, score_5, score_4, source_pony, source_furry, low quality, worst quality, blurry, censored, watermark, ugly, bad anatomy, deformed, extra limbs, bad hands, bad fingers, close-up, cropped, out of frame, jpeg artifacts, duplicate, mutation"]
    },
    {
      "id": 5,
      "class_type": "ADE_AnimateDiffUniformContextOptions",
      "pos": [400, 400],
      "size": [315, 150],
      "outputs": [{"name": "CONTEXT_OPTIONS", "type": "CONTEXT_OPTIONS", "links": [7], "slot_index": 0}],
      "widgets_values": [16, 1, 4, "uniform", false, "flat", false, 0, 1.0]
    },
    {
      "id": 6,
      "class_type": "EmptyLatentImage",
      "pos": [750, 400],
      "size": [315, 106],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [8], "slot_index": 0}],
      "widgets_values": [576, 1024, 32]
    },
    {
      "id": 7,
      "class_type": "KSamplerAdvanced",
      "pos": [1100, 100],
      "size": [315, 400],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 4},
        {"name": "positive", "type": "CONDITIONING", "link": 5},
        {"name": "negative", "type": "CONDITIONING", "link": 6},
        {"name": "latent_image", "type": "LATENT", "link": 8}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [9], "slot_index": 0}],
      "widgets_values": ["enable", 44556677, "randomize", 30, 7.0, "dpmpp_2m_sde", "karras", 0, 30, "disable"]
    },
    {
      "id": 8,
      "class_type": "VAEDecode",
      "pos": [1450, 100],
      "size": [210, 46],
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 9},
        {"name": "vae", "type": "VAE", "link": 15}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [10], "slot_index": 0}]
    },
    {
      "id": 9,
      "class_type": "RIFE VFI",
      "pos": [1700, 100],
      "size": [315, 150],
      "inputs": [{"name": "frames", "type": "IMAGE", "link": 10}],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [11], "slot_index": 0}],
      "widgets_values": ["rife47.pth", 12, 2, true, true, 1.0]
    },
    {
      "id": 10,
      "class_type": "UpscaleModelLoader",
      "pos": [1700, 300],
      "size": [315, 58],
      "outputs": [{"name": "UPSCALE_MODEL", "type": "UPSCALE_MODEL", "links": [20], "slot_index": 0}],
      "widgets_values": ["4x-UltraSharp.pth"]
    },
    {
      "id": 11,
      "class_type": "ImageUpscaleWithModel",
      "pos": [2050, 100],
      "size": [240, 46],
      "inputs": [
        {"name": "upscale_model", "type": "UPSCALE_MODEL", "link": 20},
        {"name": "image", "type": "IMAGE", "link": 11}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [21], "slot_index": 0}]
    },
    {
      "id": 12,
      "class_type": "ImageScaleBy",
      "pos": [2050, 200],
      "size": [240, 80],
      "inputs": [{"name": "image", "type": "IMAGE", "link": 21}],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [22], "slot_index": 0}],
      "widgets_values": ["lanczos", 0.5]
    },
    {
      "id": 13,
      "class_type": "VHS_VideoCombine",
      "pos": [2350, 100],
      "size": [315, 350],
      "inputs": [{"name": "images", "type": "IMAGE", "link": 22}],
      "widgets_values": ["aikings_cinema", 24, 0, "video/h264-mp4", false, true, "", 6]
    }
  ],
  "links": [
    [1, 1, 0, 2, 0, "MODEL"],
    [100, 1, 1, 99, 0, "CLIP"],
    [2, 99, 0, 3, 0, "CLIP"],
    [3, 99, 0, 4, 0, "CLIP"],
    [4, 2, 0, 7, 0, "MODEL"],
    [5, 3, 0, 7, 1, "CONDITIONING"],
    [6, 4, 0, 7, 2, "CONDITIONING"],
    [7, 5, 0, 2, 1, "CONTEXT_OPTIONS"],
    [8, 6, 0, 7, 3, "LATENT"],
    [9, 7, 0, 8, 0, "LATENT"],
    [15, 1, 2, 8, 1, "VAE"],
    [10, 8, 0, 9, 0, "IMAGE"],
    [11, 9, 0, 11, 1, "IMAGE"],
    [20, 10, 0, 11, 0, "UPSCALE_MODEL"],
    [21, 11, 0, 12, 0, "IMAGE"],
    [22, 12, 0, 13, 0, "IMAGE"]
  ],
  "version": 0.4
}
CINEMAWORKFLOW

    # ═══════════════════════════════════════════════════════════════════════
    # WAN 2.2 MASTER MoE WORKFLOW (Expert Chaining)
    # Optimized for: 14B High/Low noise mixture-of-experts, cinema motion
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_wan22_master_video_workflow.json" << 'WAN22WORKFLOW'
{
  "last_node_id": 15,
  "last_link_id": 20,
  "nodes": [
    {
      "id": 1,
      "class_type": "WanVideoModelLoader",
      "pos": [50, 100],
      "size": [315, 82],
      "outputs": [{"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0}],
      "widgets_values": ["wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors", "fp8_e4m3fn"]
    },
    {
      "id": 2,
      "class_type": "WanVideoModelLoader",
      "pos": [50, 200],
      "size": [315, 82],
      "outputs": [{"name": "MODEL", "type": "MODEL", "links": [2], "slot_index": 0}],
      "widgets_values": ["wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors", "fp8_e4m3fn"]
    },
    {
      "id": 3,
      "class_type": "WanVideoT5TextEncode",
      "pos": [50, 350],
      "size": [315, 82],
      "outputs": [{"name": "CLIP", "type": "CLIP", "links": [3, 4], "slot_index": 0}],
      "widgets_values": ["umt5_xxl_fp8_e4m3fn_scaled.safetensors"]
    },
    {
      "id": 4,
      "class_type": "CLIPTextEncode",
      "pos": [450, 50],
      "size": [400, 150],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 3}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [5, 6], "slot_index": 0}],
      "widgets_values": ["score_9, score_8_up, rating_explicit, masterpiece, best quality, cinematic, 1girl, full body, realistic texture, mo-e motion"]
    },
    {
      "id": 5,
      "class_type": "CLIPTextEncode",
      "pos": [450, 250],
      "size": [400, 150],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 4}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [7, 8], "slot_index": 0}],
      "widgets_values": ["score_6, score_5, low quality, worst quality, watermark"]
    },
    {
      "id": 6,
      "class_type": "EmptyWanVideoLatent",
      "pos": [450, 450],
      "size": [315, 106],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [9], "slot_index": 0}],
      "widgets_values": [832, 480, 81]
    },
    {
      "id": 7,
      "class_type": "WanVideoSampler",
      "pos": [900, 50],
      "size": [315, 450],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1},
        {"name": "positive", "type": "CONDITIONING", "link": 5},
        {"name": "negative", "type": "CONDITIONING", "link": 7},
        {"name": "latent_image", "type": "LATENT", "link": 9}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [10], "slot_index": 0}],
      "widgets_values": [25, 7.0, 5566, "randomize"]
    },
    {
      "id": 8,
      "class_type": "WanVideoSampler",
      "pos": [1250, 50],
      "size": [315, 450],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 2},
        {"name": "positive", "type": "CONDITIONING", "link": 6},
        {"name": "negative", "type": "CONDITIONING", "link": 8},
        {"name": "latent_image", "type": "LATENT", "link": 10}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [11], "slot_index": 0}],
      "widgets_values": [10, 7.0, 5566, "randomize"]
    },
    {
      "id": 9,
      "class_type": "WanVideoVaeLoader",
      "pos": [1250, 600],
      "size": [315, 58],
      "outputs": [{"name": "VAE", "type": "VAE", "links": [12], "slot_index": 0}],
      "widgets_values": ["wan2.2_vae.safetensors"]
    },
    {
      "id": 10,
      "class_type": "VAEDecode",
      "pos": [1600, 50],
      "size": [210, 46],
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 11},
        {"name": "vae", "type": "VAE", "link": 12}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [13], "slot_index": 0}]
    },
    {
      "id": 11,
      "class_type": "VHS_VideoCombine",
      "pos": [1850, 50],
      "size": [315, 350],
      "inputs": [{"name": "images", "type": "IMAGE", "link": 13}],
      "widgets_values": ["aikings_wan22_moe", 24, 0, "video/h264-mp4", false, true, "", 6]
    }
  ],
  "links": [
    [1, 1, 0, 7, 0, "MODEL"],
    [2, 2, 0, 8, 0, "MODEL"],
    [3, 3, 0, 4, 0, "CLIP"],
    [4, 3, 0, 5, 0, "CLIP"],
    [5, 4, 0, 7, 1, "CONDITIONING"],
    [6, 4, 0, 8, 1, "CONDITIONING"],
    [7, 5, 0, 7, 2, "CONDITIONING"],
    [8, 5, 0, 8, 2, "CONDITIONING"],
    [9, 6, 0, 7, 3, "LATENT"],
    [10, 7, 0, 8, 3, "LATENT"],
    [11, 8, 0, 10, 0, "LATENT"],
    [12, 9, 0, 10, 1, "VAE"],
    [13, 10, 0, 11, 0, "IMAGE"]
  ],
  "version": 0.4
}
WAN22WORKFLOW


    # printf "   ✅ nsfw_wan22_master_video_workflow.json (Wan 2.2 MoE Expert Chain)\n"
    log "✅ Workflows complete"
}

install_cloudflared() {
    log_section "🌐 INSTALLING CLOUDFLARE TUNNEL"
    if [[ ! -f "/usr/local/bin/cloudflared" ]]; then
        curl -L --output /usr/local/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
        chmod +x /usr/local/bin/cloudflared
        log "✅ cloudflared installed"
    else
        log "   ✅ cloudflared already installed"
    fi
}

start_comfyui() {
    log_section "🚀 STARTING COMFYUI & PUBLIC TUNNEL"
    cd "${COMFYUI_DIR}"
    activate_venv
    
    # Start ComfyUI in background
    nohup "$VENV_PYTHON" main.py --listen 0.0.0.0 --port 8188 --enable-cors-header > "${WORKSPACE}/comfyui.log" 2>&1 &
    log "✅ ComfyUI started on port 8188"

    # Start Cloudflare Tunnel (Quick Tunnel)
    log "🌐 Launching Cloudflare Tunnel..."
    nohup cloudflared tunnel --url http://127.0.0.1:8188 > "${WORKSPACE}/tunnel.log" 2>&1 &
    
    # Wait for URL to appear in logs
    sleep 5
    local tunnel_url=$(grep -o 'https://[-a-z0-9.]*trycloudflare.com' "${WORKSPACE}/tunnel.log" | head -n 1)
    if [[ -n "$tunnel_url" ]]; then
        log "🚀 PUBLIC URL READY: $tunnel_url"
        echo "************************************************"
        echo "🔗 ACCESS YOUR STUDIO AT: $tunnel_url"
        echo "************************************************"
    else
        log "⚠️  Tunnel URL not found yet, check ${WORKSPACE}/tunnel.log manually"
    fi
}


main() {
    log "--- Provisioning Start ---"
    install_apt_packages
    install_comfyui
    install_nodes
    install_models
    install_workflows
    validate_workflows
    install_cloudflared
    verify_installation
    start_comfyui
    log "--- Provisioning Complete ---"
}



main "$@"
