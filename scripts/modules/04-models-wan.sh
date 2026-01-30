#!/bin/bash
# AI KINGS - Module 04: Wan Video Models (Production-Grade)
# Features: Memory monitoring, sequential downloads, fallback handling, resource checks

set -uo pipefail
source /workspace/scripts/tools/state-manager.sh
DOWNLOADER="/workspace/scripts/tools/download.sh"

MODULE_NAME="models-wan"

if check_module "$MODULE_NAME"; then
    echo "✅ Module $MODULE_NAME already completed. Skipping."
    exit 0
fi

# Configuration
DOWNLOAD_TIMEOUT=3600  # 1 hour for large Wan models

# Logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [MODELS-WAN] $*" >&2
}

error_log() {
    log "$1" "ERROR"
}

warn_log() {
    log "$1" "WARN"
}

# Resource validation for large model downloads
check_resources_for_wan() {
    log "🔍 Checking resources for large Wan model downloads..."

    # Need significant memory and disk space for Wan models
    local avail_mem
    avail_mem=$(free -m | grep '^Mem:' | awk '{print $7}')
    if (( avail_mem < 4096 )); then  # 4GB free minimum
        error_log "Insufficient memory for Wan models: ${avail_mem}MB available, need 4GB+"
        return 1
    fi

    # Check disk space (Wan models are huge - need 100GB+ free)
    local avail_disk
    avail_disk=$(df /workspace | tail -1 | awk '{print $4}')
    avail_disk=$((avail_disk / 1024 / 1024))  # Convert to GB
    if (( avail_disk < 100 )); then
        error_log "Insufficient disk space for Wan models: ${avail_disk}GB available, need 100GB+"
        return 1
    fi

    log "✅ Resources adequate for Wan models (${avail_mem}MB RAM, ${avail_disk}GB disk)"
    return 0
}

# Enhanced download with memory monitoring
download_wan_model() {
    local url=$1
    local target_dir=$2
    local filename=$3
    local description=${4:-$filename}

    log "🎬 Downloading large Wan model: $description"

    # Monitor memory during download
    local mem_check_pid
    (
        while true; do
            local mem_usage
            mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
            if (( mem_usage > 90 )); then
                warn_log "High memory usage during $description download: ${mem_usage}%"
            fi
            sleep 30
        done
    ) &
    mem_check_pid=$!

    # Perform download with extended timeout
    if timeout "$DOWNLOAD_TIMEOUT" "$DOWNLOADER" "$url" "$target_dir" "$filename"; then
        kill "$mem_check_pid" 2>/dev/null || true
        log "✅ Successfully downloaded $description"
        return 0
    else
        kill "$mem_check_pid" 2>/dev/null || true
        error_log "Failed to download $description within ${DOWNLOAD_TIMEOUT}s timeout"
        return 1
    fi
}

# Sequential download of Wan models to prevent memory exhaustion
download_wan_models_sequential() {
    local COMFYUI_DIR="/workspace/ComfyUI"
    local failed_downloads=()

    log "🎬 Starting Wan video model downloads (sequential, memory-conscious)..."

    # Wan 2.1 Models (smaller, more stable)
    declare -A wan21_models=(
        ["wan2.1_t2v_1.3B_fp16.safetensors"]="https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_t2v_1.3B_fp16.safetensors"
        ["umt5_xxl_fp8_e4m3fn_scaled.safetensors"]="https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
        ["wan2.1_vae.safetensors"]="https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan2.1_vae.safetensors"
    )

    log "📦 Downloading Wan 2.1 models..."
    for model in "${!wan21_models[@]}"; do
        local target_dir
        case "$model" in
            wan2.1_t2v_1.3B_fp16.safetensors)
                target_dir="$COMFYUI_DIR/models/diffusion_models"
                ;;
            umt5_xxl_fp8_e4m3fn_scaled.safetensors)
                target_dir="$COMFYUI_DIR/models/text_encoders"
                ;;
            wan2.1_vae.safetensors)
                target_dir="$COMFYUI_DIR/models/vae"
                ;;
        esac

        if ! download_wan_model "${wan21_models[$model]}" "$target_dir" "$model" "Wan 2.1 $model"; then
            failed_downloads+=("$model")
        fi

        # Brief pause between downloads to let system recover
        sleep 10
    done

    # Wan 2.2 Models (much larger - only download if resources allow)
    local avail_disk
    avail_disk=$(df /workspace | tail -1 | awk '{print $4}')
    avail_disk=$((avail_disk / 1024 / 1024))  # Convert to GB

    if (( avail_disk >= 150 )); then  # Need 150GB+ for Wan 2.2
        log "📦 Downloading Wan 2.2 models (large files)..."

        declare -A wan22_models=(
            ["wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors"]="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors"
            ["wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors"]="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors"
            ["wan2.2_vae.safetensors"]="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors"
        )

        for model in "${!wan22_models[@]}"; do
            local target_dir="$COMFYUI_DIR/models/diffusion_models"
            if [[ "$model" == *"vae"* ]]; then
                target_dir="$COMFYUI_DIR/models/vae"
            fi

            if ! download_wan_model "${wan22_models[$model]}" "$target_dir" "$model" "Wan 2.2 $model"; then
                failed_downloads+=("$model")
            fi

            # Longer pause for very large files
            sleep 30
        done
    else
        warn_log "Skipping Wan 2.2 models - insufficient disk space (${avail_disk}GB available, need 150GB+)"
    fi

    # Report results
    if (( ${#failed_downloads[@]} > 0 )); then
        warn_log "Some Wan models failed to download: ${failed_downloads[*]}"
        log "Continuing with successful downloads..."
        return 1
    else
        log "All Wan models downloaded successfully"
        return 0
    fi
}

# Optional: Clean up old/incomplete downloads
cleanup_partial_downloads() {
    log "🧹 Cleaning up any partial downloads..."

    local cleanup_dirs=(
        "$COMFYUI_DIR/models/diffusion_models"
        "$COMFYUI_DIR/models/text_encoders"
        "$COMFYUI_DIR/models/vae"
    )

    for dir in "${cleanup_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            # Remove files smaller than 100MB (likely incomplete)
            find "$dir" -name "*.safetensors" -o -name "*.pth" -o -name "*.ckpt" | while read -r file; do
                local size
                size=$(stat -c%s "$file" 2>/dev/null || echo "0")
                if (( size > 0 && size < 104857600 )); then  # Less than 100MB
                    warn_log "Removing likely incomplete file: $file (${size} bytes)"
                    rm -f "$file"
                fi
            done
        fi
    done
}

echo "🚀 Starting $MODULE_NAME (Production Mode)..."

COMFYUI_DIR="/workspace/ComfyUI"

# Pre-flight checks
if ! check_resources_for_wan; then
    error_log "Resource check failed - Wan models require significant resources"
    exit 1
fi

# Optional cleanup
cleanup_partial_downloads

# Download models sequentially
if download_wan_models_sequential; then
    log "✅ All Wan models processed successfully"
else
    warn_log "Some Wan models failed to download - check logs for details"
fi

mark_module_complete "$MODULE_NAME"
log "✅ Finished $MODULE_NAME (Production Mode)"
