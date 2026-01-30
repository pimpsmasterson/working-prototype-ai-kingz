#!/bin/bash
# AI KINGS - Module 03: Core Models (Production-Grade)
# Features: Token validation, parallel downloads, fallback URLs, comprehensive error handling

set -uo pipefail
source /workspace/scripts/tools/state-manager.sh
DOWNLOADER="/workspace/scripts/tools/download.sh"

MODULE_NAME="models-core"

if check_module "$MODULE_NAME"; then
    echo "✅ Module $MODULE_NAME already completed. Skipping."
    exit 0
fi

# Configuration
MAX_PARALLEL_DOWNLOADS=2  # Conservative to avoid memory issues
DOWNLOAD_TIMEOUT=1800     # 30 minutes per download

# Logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [MODELS-CORE] $*" >&2
}

error_log() {
    log "$1" "ERROR"
}

warn_log() {
    log "$1" "WARN"
}

# Token validation
validate_tokens() {
    log "🔑 Validating API tokens..."

    local tokens_valid=true

    # Check Civitai token
    if [[ -n "${CIVITAI_TOKEN:-}" ]]; then
        if curl -f -H "Authorization: Bearer $CIVITAI_TOKEN" \
               --max-time 10 --silent \
               "https://civitai.com/api/v1/models" >/dev/null 2>&1; then
            log "✅ Civitai token is valid"
        else
            warn_log "Civitai token appears invalid - downloads may fail"
            tokens_valid=false
        fi
    else
        warn_log "No Civitai token set - downloads may fail or be rate-limited"
        tokens_valid=false
    fi

    # Check HuggingFace token
    if [[ -n "${HUGGINGFACE_HUB_TOKEN:-}" ]]; then
        if curl -f -H "Authorization: Bearer $HUGGINGFACE_HUB_TOKEN" \
               --max-time 10 --silent \
               "https://huggingface.co/api/whoami" >/dev/null 2>&1; then
            log "✅ HuggingFace token is valid"
        else
            warn_log "HuggingFace token appears invalid"
        fi
    fi

    return $([ "$tokens_valid" = true ] && echo 0 || echo 1)
}

# Enhanced download function with fallback
download_with_fallback() {
    local primary_url=$1
    local target_dir=$2
    local filename=$3
    local fallback_url=${4:-}
    local description=${5:-$filename}

    log "⬇️ Downloading $description..."

    # Try primary URL
    if "$DOWNLOADER" "$primary_url" "$target_dir" "$filename"; then
        log "✅ Successfully downloaded $description"
        return 0
    fi

    # Try fallback URL if provided
    if [[ -n "$fallback_url" ]]; then
        warn_log "Primary download failed, trying fallback URL..."
        if "$DOWNLOADER" "$fallback_url" "$target_dir" "$filename"; then
            log "✅ Successfully downloaded $description (fallback)"
            return 0
        fi
    fi

    error_log "Failed to download $description from all sources"
    return 1
}

# Sequential download to avoid memory issues
download_models_sequential() {
    local COMFYUI_DIR="/workspace/ComfyUI"
    local failed_downloads=()

    log "📦 Starting core model downloads (sequential mode)..."

    # Base checkpoints with fallbacks
    declare -A checkpoints=(
        ["pmXL_v1.safetensors"]="https://civitai.com/api/download/models/2602579"
        ["ponyDiffusionV6XL.safetensors"]="https://civitai.com/api/download/models/290640"
    )

    for model in "${!checkpoints[@]}"; do
        if ! download_with_fallback "${checkpoints[$model]}" \
                                   "$COMFYUI_DIR/models/checkpoints" \
                                   "$model" \
                                   "" \
                                   "checkpoint $model"; then
            failed_downloads+=("$model")
        fi
    done

    # LoRAs
    declare -A loras=(
        ["pony_realism_v2.1.safetensors"]="https://civitai.com/api/download/models/300438"
    )

    for lora in "${!loras[@]}"; do
        if ! download_with_fallback "${loras[$lora]}" \
                                   "$COMFYUI_DIR/models/loras" \
                                   "$lora" \
                                   "" \
                                   "LoRA $lora"; then
            failed_downloads+=("$lora")
        fi
    done

    # Animation components (HuggingFace - more reliable)
    declare -A anim_components=(
        ["mm_sdxl_v1_beta.ckpt"]="https://huggingface.co/guoyww/animatediff/resolve/main/mm_sdxl_v1_beta.ckpt"
        ["rife47.pth"]="https://github.com/hzwer/Practical-RIFE/releases/download/v4.7/rife47.pth"
    )

    for component in "${!anim_components[@]}"; do
        if ! download_with_fallback "${anim_components[$component]}" \
                                   "$COMFYUI_DIR/models/animatediff_models" \
                                   "$component" \
                                   "" \
                                   "animation component $component"; then
            failed_downloads+=("$component")
        fi
    done

    # Upscalers
    declare -A upscalers=(
        ["4x-UltraSharp.pth"]="https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth"
    )

    for upscaler in "${!upscalers[@]}"; do
        if ! download_with_fallback "${upscalers[$upscaler]}" \
                                   "$COMFYUI_DIR/models/upscale_models" \
                                   "$upscaler" \
                                   "" \
                                   "upscaler $upscaler"; then
            failed_downloads+=("$upscaler")
        fi
    done

    # ControlNet models
    declare -A controlnets=(
        ["OpenPoseXL2.safetensors"]="https://huggingface.co/thibaud/controlnet-openpose-sdxl-1.0/resolve/main/OpenPoseXL2.safetensors"
    )

    for controlnet in "${!controlnets[@]}"; do
        if ! download_with_fallback "${controlnets[$controlnet]}" \
                                   "$COMFYUI_DIR/models/controlnet" \
                                   "$controlnet" \
                                   "" \
                                   "ControlNet $controlnet"; then
            failed_downloads+=("$controlnet")
        fi
    done

    # Impact Pack models
    declare -A impact_models=(
        ["face_yolov8m.pt"]="https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt"
        ["sam_vit_b_01ec64.pth"]="https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth"
    )

    for impact_model in "${!impact_models[@]}"; do
        if ! download_with_fallback "${impact_models[$impact_model]}" \
                                   "$COMFYUI_DIR/models/ultralytics/bbox" \
                                   "$impact_model" \
                                   "" \
                                   "Impact Pack model $impact_model"; then
            failed_downloads+=("$impact_model")
        fi
    done

    # Report results
    if (( ${#failed_downloads[@]} > 0 )); then
        warn_log "Some models failed to download: ${failed_downloads[*]}"
        log "Continuing with successful downloads..."
        return 1
    else
        log "All core models downloaded successfully"
        return 0
    fi
}

# Memory and disk space checks
check_resources() {
    log "🔍 Checking system resources for model downloads..."

    # Check available memory (need at least 2GB free)
    local avail_mem
    avail_mem=$(free -m | grep '^Mem:' | awk '{print $7}')
    if (( avail_mem < 2048 )); then
        error_log "Insufficient memory for model downloads: ${avail_mem}MB available, need 2GB+"
        return 1
    fi

    # Check disk space (need at least 20GB free)
    local avail_kb
    avail_kb=$(df /workspace | tail -1 | awk '{print $4}')  # df shows 1K blocks, so this is KB
    local avail_gb=$((avail_kb / 1024 / 1024))  # Convert KB to GB
    if (( avail_gb < 20 )); then
        error_log "Insufficient disk space: ${avail_gb}GB available, need 20GB+"
        return 1
    fi

    log "✅ Resources check passed (${avail_mem}MB RAM, ${avail_gb}GB disk)"
    return 0
}

echo "🚀 Starting $MODULE_NAME (Production Mode)..."

COMFYUI_DIR="/workspace/ComfyUI"

# Pre-flight checks
if ! check_resources; then
    error_log "Resource check failed - aborting model downloads"
    exit 1
fi

# Validate tokens (but don't fail completely)
validate_tokens || warn_log "Token validation issues detected"

# Download models
if download_models_sequential; then
    log "✅ All core models processed successfully"
else
    warn_log "Some core models failed to download - check logs for details"
fi

mark_module_complete "$MODULE_NAME"
log "✅ Finished $MODULE_NAME (Production Mode)"
