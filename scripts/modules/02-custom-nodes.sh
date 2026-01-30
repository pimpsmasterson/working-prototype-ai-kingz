#!/bin/bash
# AI KINGS - Module 02: Custom Nodes (Production-Grade)
# Features: Memory monitoring, individual package installs, dependency resolution, pip cache management

set -uo pipefail
source /workspace/scripts/tools/state-manager.sh

MODULE_NAME="custom-nodes"

if check_module "$MODULE_NAME"; then
    echo "✅ Module $MODULE_NAME already completed. Skipping."
    exit 0
fi

# Configuration
PIP_TIMEOUT=900  # 15 minutes per package
MAX_MEMORY_USAGE=85  # Max memory % before throttling
MIN_DISK_SPACE_MB=2048  # 2GB minimum
PIP_CACHE_DIR="/workspace/.pip_cache"

# Logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [CUSTOM-NODES] $*" >&2
}

error_log() {
    log "$1" "ERROR"
}

warn_log() {
    log "$1" "WARN"
}

# Memory and resource monitoring
check_memory() {
    local avail_mem
    avail_mem=$(free -m | grep '^Mem:' | awk '{print $7}')
    local mem_usage
    mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')

    if (( mem_usage > MAX_MEMORY_USAGE )); then
        warn_log "High memory usage: ${mem_usage}% (${avail_mem}MB available)"
        return 1
    fi

    if (( avail_mem < 1024 )); then  # Less than 1GB available
        warn_log "Low available memory: ${avail_mem}MB"
        return 1
    fi

    return 0
}

check_disk_space() {
    local avail_mb
    avail_mb=$(df /workspace | tail -1 | awk '{print $4}')
    avail_mb=$((avail_mb / 1024))  # Convert to MB

    if (( avail_mb < MIN_DISK_SPACE_MB )); then
        error_log "Insufficient disk space: ${avail_mb}MB available, need ${MIN_DISK_SPACE_MB}MB"
        return 1
    fi

    return 0
}

# Enhanced pip installation with memory management
install_package_safe() {
    local package=$1
    local description=${2:-$package}

    log "Installing $description..."

    # Pre-install checks
    if ! check_memory; then
        warn_log "Skipping $description due to memory constraints"
        return 1
    fi

    if ! check_disk_space; then
        error_log "Cannot install $description - insufficient disk space"
        return 1
    fi

    # Set pip cache directory
    export PIP_CACHE_DIR="$PIP_CACHE_DIR"
    mkdir -p "$PIP_CACHE_DIR"

    # Install with comprehensive options
    local pip_cmd=(
        pip install
        --no-cache-dir
        --timeout "$PIP_TIMEOUT"
        --retries 3
        --progress-bar off
        --quiet
    )

    # Add memory-conscious options
    pip_cmd+=(--no-binary :all:)  # Prefer source builds for better memory usage

    # Execute installation with timeout and error handling
    if timeout "$PIP_TIMEOUT" "${pip_cmd[@]}" "$package" 2>&1; then
        log "✅ Successfully installed $description"
        return 0
    else
        local exit_code=$?
        if (( exit_code == 124 )); then
            error_log "Installation of $description timed out after ${PIP_TIMEOUT}s"
        else
            error_log "Failed to install $description (exit code: $exit_code)"
        fi
        return 1
    fi
}

# Install heavy packages individually with dependency management
install_heavy_packages() {
    log "🔧 Installing heavy packages individually..."

    local heavy_packages=(
        "torch>=2.0.0"
        "torchvision"
        "torchaudio"
        "transformers>=4.30.0"
        "accelerate>=0.20.0"
        "diffusers>=0.20.0"
        "opencv-python-headless>=4.8.0"
        "numpy>=1.24.0"
        "scipy>=1.10.0"
        "Pillow>=9.0.0"
        "einops>=0.6.0"
        "timm>=0.9.0"
        "huggingface-hub>=0.15.0"
        "safetensors>=0.3.0"
        "tokenizers>=0.13.0"
    )

    local failed_packages=()

    for package in "${heavy_packages[@]}"; do
        # Special handling for OpenCV which often fails to compile
        if [[ "$package" == "opencv-python-headless>=4.8.0" ]]; then
            log "Installing $package (with special handling)..."
            if ! install_package_safe "$package" "--only-binary=all" 2>/dev/null; then
                warn_log "OpenCV pip install failed, trying system package..."
                # Try installing system opencv packages
                if command -v apt-get >/dev/null 2>&1; then
                    apt-get update && apt-get install -y python3-opencv libopencv-dev 2>/dev/null || true
                fi
                # Try one more time with pip, but don't fail the whole process
                if ! install_package_safe "opencv-python-headless" "--only-binary=all" 2>/dev/null; then
                    warn_log "OpenCV installation failed completely - some video features may not work"
                    failed_packages+=("$package")
                fi
            fi
        else
            if ! install_package_safe "$package"; then
                failed_packages+=("$package")
            fi
        fi

        # Brief pause between heavy installs
        sleep 2
    done

    if (( ${#failed_packages[@]} > 0 )); then
        warn_log "Some heavy packages failed: ${failed_packages[*]}"
        return 1
    fi

    return 0
}

# Install video-specific packages
install_video_packages() {
    log "🎬 Installing video processing packages..."

    local video_packages=(
        "imageio-ffmpeg>=0.4.0"
        "imageio>=2.25.0"
        "av>=10.0.0"
        "decord>=0.6.0"
        "moviepy>=1.0.0"
    )

    local failed_packages=()

    for package in "${video_packages[@]}"; do
        # Special handling for packages that commonly fail
        if [[ "$package" == "decord>=0.6.0" ]]; then
            # decord is often not available, skip it
            warn_log "Skipping $package - not available in pip, will use alternative video processing"
            continue
        elif [[ "$package" == "moviepy>=1.0.0" ]]; then
            # moviepy requires many build dependencies, try with --only-binary
            if ! install_package_safe "$package" "--only-binary=all" 2>/dev/null; then
                warn_log "moviepy failed to install - video editing features may be limited"
                failed_packages+=("$package")
            fi
        else
            if ! install_package_safe "$package"; then
                failed_packages+=("$package")
            fi
        fi
    done

    if (( ${#failed_packages[@]} > 0 )); then
        warn_log "Some video packages failed: ${failed_packages[*]}"
        return 1
    fi

    return 0
}

# Clone and setup custom nodes with error handling
setup_custom_node() {
    local repo_url=$1
    local node_name
    node_name=$(basename "$repo_url" .git)
    local target_path="$COMFYUI_DIR/custom_nodes/$node_name"

    if [[ -d "$target_path" ]]; then
        log "✅ $node_name already exists"
        return 0
    fi

    log "📥 Cloning $node_name..."

    # Check disk space before cloning
    if ! check_disk_space; then
        error_log "Cannot clone $node_name - insufficient disk space"
        return 1
    fi

    if git clone --depth 1 --single-branch "$repo_url" "$target_path" 2>&1; then
        log "✅ Successfully cloned $node_name"
        return 0
    else
        error_log "Failed to clone $node_name"
        return 1
    fi
}

# Install requirements for a custom node
install_node_requirements() {
    local node_path=$1
    local node_name
    node_name=$(basename "$node_path")
    local req_file="$node_path/requirements.txt"

    if [[ ! -f "$req_file" ]]; then
        log "No requirements.txt for $node_name"
        return 0
    fi

    log "🔧 Installing requirements for $node_name..."

    # Read requirements and install one by one for better error isolation
    while IFS= read -r requirement || [[ -n "$requirement" ]]; do
        # Skip comments and empty lines
        [[ "$requirement" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$requirement" ]] && continue

        # Extract package name (remove version specifiers)
        local package_name
        package_name=$(echo "$requirement" | sed 's/[>=<].*//')

        if ! install_package_safe "$requirement" "$package_name (for $node_name)"; then
            warn_log "Failed to install $requirement for $node_name"
            # Continue with other requirements
        fi
    done < "$req_file"
}

echo "🚀 Starting $MODULE_NAME (Production Mode)..."

COMFYUI_DIR="/workspace/ComfyUI"
CUSTOM_NODES_DIR="${COMFYUI_DIR}/custom_nodes"

# Pre-flight checks
if ! check_memory; then
    error_log "Insufficient memory to start custom nodes installation"
    exit 1
fi

if ! check_disk_space; then
    error_log "Insufficient disk space for custom nodes installation"
    exit 1
fi

# Create directories
mkdir -p "$CUSTOM_NODES_DIR"
mkdir -p "$PIP_CACHE_DIR"

# Activate virtual environment
activate_venv() {
    if [[ -f "/venv/main/bin/activate" ]]; then
        source "/venv/main/bin/activate"
        log "Activated conda/uv virtual environment"
    elif [[ -f "/workspace/venv/bin/activate" ]]; then
        source "/workspace/venv/bin/activate"
        log "Activated local virtual environment"
    else
        warn_log "No virtual environment found - using system Python"
    fi
}

activate_venv

# Install heavy packages first
if ! install_heavy_packages; then
    warn_log "Some heavy packages failed - continuing with custom nodes..."
fi

# Install video packages
if ! install_video_packages; then
    warn_log "Some video packages failed - continuing..."
fi

# Custom nodes to install
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
)

failed_nodes=()

for repo in "${NODES[@]}"; do
    if ! setup_custom_node "$repo"; then
        failed_nodes+=("$(basename "$repo" .git)")
        continue
    fi

    node_name=$(basename "$repo" .git)
    node_path="$CUSTOM_NODES_DIR/$node_name"

    # Install requirements with individual package handling
    install_node_requirements "$node_path"
done

# Final status
if (( ${#failed_nodes[@]} > 0 )); then
    warn_log "Some custom nodes failed to install: ${failed_nodes[*]}"
    log "Continuing with successful installations..."
else
    log "All custom nodes processed successfully"
fi

# Clean up pip cache if it's getting large
if [[ -d "$PIP_CACHE_DIR" ]]; then
    local cache_size
    cache_size=$(du -sm "$PIP_CACHE_DIR" 2>/dev/null | awk '{print $1}' || echo "0")
    if (( cache_size > 1024 )); then  # More than 1GB
        log "Cleaning up large pip cache (${cache_size}MB)"
        rm -rf "${PIP_CACHE_DIR:?}"/*
    fi
fi

mark_module_complete "$MODULE_NAME"
log "✅ Finished $MODULE_NAME (Production Mode)"
