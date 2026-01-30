#!/bin/bash
# AI KINGS Essential Model Provisioning - No Failures
# Downloads only working, essential models for ComfyUI

echo "🚀 AI KINGS Essential Provisioning v1.0"
echo "📍 No set -e = script continues on errors"

# CRITICAL: Create and enter workspace directory
echo "📁 Ensuring /workspace exists..."
mkdir -p /workspace || { echo "ERROR: Cannot create /workspace"; exit 1; }
cd /workspace || { echo "ERROR: Cannot cd to /workspace"; exit 1; }
echo "✅ Working directory: $(pwd)"

# Directories
WORKSPACE="/workspace"
COMFY_DIR="$WORKSPACE/ComfyUI"
CHECKPOINTS_DIR="$COMFY_DIR/models/checkpoints"
VAE_DIR="$COMFY_DIR/models/vae"
UPSCALE_DIR="$COMFY_DIR/models/upscale_models"
LORAS_DIR="$COMFY_DIR/models/loras"

# Install ComfyUI if missing
if [ ! -d "$COMFY_DIR" ]; then
    echo "📥 Installing ComfyUI..."
    cd "$WORKSPACE" || { echo "ERROR: Cannot cd to $WORKSPACE"; exit 1; }
    if ! git clone https://github.com/comfyanonymous/ComfyUI.git; then
        echo "ERROR: ComfyUI git clone failed"
        exit 1
    fi
    cd "$COMFY_DIR" || { echo "ERROR: Cannot cd to $COMFY_DIR"; exit 1; }
    if ! pip3 install -r requirements.txt; then
        echo "ERROR: ComfyUI pip install failed"
        exit 1
    fi
    echo "✅ ComfyUI installed"
fi

# Create directories
mkdir -p "$CHECKPOINTS_DIR" "$VAE_DIR" "$UPSCALE_DIR" "$LORAS_DIR" || {
    echo "ERROR: Cannot create model directories"
    exit 1
}

# Tokens from environment
HF_TOKEN="${HUGGINGFACE_HUB_TOKEN:-}"
CIVITAI_TOKEN="${CIVITAI_TOKEN:-}"

SUCCESS=0
FAILED=0

# Download helper - continues on failure
download_file() {
    local url="$1"
    local output="$2"
    local name="$3"

    if [ -f "$output" ]; then
        echo "✅ $name already exists, skipping"
        return 0
    fi

    echo "⬇️  Downloading: $name"
    # Create output directory if it doesn't exist
    local output_dir=$(dirname "$output")
    mkdir -p "$output_dir" 2>/dev/null || {
        echo "❌ Cannot create directory: $output_dir"
        return 1
    }

    # Use curl instead of wget for better reliability
    if command -v curl >/dev/null 2>&1; then
        if curl -L --retry 3 --retry-delay 5 --max-time 1800 --progress-bar "$url" -o "$output"; then
            echo "✅ $name downloaded successfully"
            SUCCESS=$((SUCCESS + 1))
            return 0
        fi
    else
        # Fallback to wget
        if wget -c --progress=bar:force:noscroll --timeout=300 --tries=3 "$url" -O "$output"; then
            echo "✅ $name downloaded successfully"
            SUCCESS=$((SUCCESS + 1))
            return 0
        fi
    fi

    echo "❌ $name failed, continuing..."
    rm -f "$output" 2>/dev/null
    FAILED=$((FAILED + 1))
    return 1
}

echo ""
echo "📦 [1/6] Downloading SDXL Base 1.0 (6.46GB)..."
download_file \
    "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors" \
    "$CHECKPOINTS_DIR/sd_xl_base_1.0.safetensors" \
    "SDXL Base 1.0"

echo ""
echo "📦 [2/6] Downloading Realistic Vision v5.1 (2.13GB)..."
download_file \
    "https://huggingface.co/SG161222/Realistic_Vision_V5.1_noVAE/resolve/main/Realistic_Vision_V5.1_fp16-no-ema.safetensors" \
    "$CHECKPOINTS_DIR/realistic_vision_v5.1.safetensors" \
    "Realistic Vision v5.1"

echo ""
echo "📦 [3/6] Downloading Flux.1 Dev (23.8GB)..."
if [ -n "$HF_TOKEN" ]; then
    wget -c --progress=bar:force:noscroll --timeout=600 --tries=3 \
        --header="Authorization: Bearer $HF_TOKEN" \
        "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors" \
        -O "$CHECKPOINTS_DIR/flux1-dev.safetensors" && SUCCESS=$((SUCCESS + 1)) || { echo "❌ Flux failed (gated model)"; FAILED=$((FAILED + 1)); }
else
    echo "⚠️  No HuggingFace token, skipping Flux (gated model)"
    FAILED=$((FAILED + 1))
fi

echo ""
echo "📦 [4/6] Downloading VAE (334MB)..."
download_file \
    "https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors" \
    "$VAE_DIR/vae-ft-mse-840000-ema-pruned.safetensors" \
    "VAE MSE"

echo ""
echo "📦 [5/6] Downloading ESRGAN 4x Upscaler (67MB)..."
download_file \
    "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth" \
    "$UPSCALE_DIR/RealESRGAN_x4plus.pth" \
    "ESRGAN 4x"

echo ""
echo "📦 [6/6] Downloading Detail Tweaker LoRA (144MB)..."
if [ -n "$CIVITAI_TOKEN" ]; then
    download_file \
        "https://civitai.com/api/download/models/135867?token=$CIVITAI_TOKEN" \
        "$LORAS_DIR/add_detail.safetensors" \
        "Detail Tweaker LoRA"
else
    echo "⚠️  No Civitai token, skipping Detail LoRA"
    FAILED=$((FAILED + 1))
fi

echo ""
echo "✅ ==============================================="
echo "✅ PROVISIONING COMPLETE"
echo "✅ ==============================================="
echo "📊 Success: $SUCCESS downloads"
echo "❌ Failed: $FAILED downloads"
echo "💾 Disk usage: $(du -sh $CHECKPOINTS_DIR 2>/dev/null | cut -f1 || echo '0')"
echo "🎯 Checkpoints: $(ls -1 $CHECKPOINTS_DIR/*.safetensors 2>/dev/null | wc -l)"
echo "🎨 VAEs: $(ls -1 $VAE_DIR/*.safetensors 2>/dev/null | wc -l)"
echo "⬆️  Upscalers: $(ls -1 $UPSCALE_DIR/*.pth 2>/dev/null | wc -l)"
echo "🎭 LoRAs: $(ls -1 $LORAS_DIR/*.safetensors 2>/dev/null | wc -l)"
echo ""
echo "🚀 Starting ComfyUI on port 18188..."

# Ensure we're in the ComfyUI directory
if [ ! -d "$COMFY_DIR" ]; then
    echo "ERROR: ComfyUI directory not found at $COMFY_DIR"
    exit 1
fi

cd "$COMFY_DIR" || {
    echo "ERROR: Cannot cd to $COMFY_DIR"
    exit 1
}

# Check if main.py exists
if [ ! -f "main.py" ]; then
    echo "ERROR: main.py not found in $COMFY_DIR"
    exit 1
fi

# Find python executable
PYTHON_CMD=""
if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_CMD="python"
else
    echo "ERROR: No python executable found. Install python3."
    exit 1
fi

echo "Using Python: $PYTHON_CMD"
echo "Starting ComfyUI with: $PYTHON_CMD main.py --listen 0.0.0.0 --port 18188 --enable-cors-header"

# Start ComfyUI
exec "$PYTHON_CMD" main.py --listen 0.0.0.0 --port 18188 --enable-cors-header
