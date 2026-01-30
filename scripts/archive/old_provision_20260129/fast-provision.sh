#!/bin/bash
set -e
echo "🚀 AI KINGS Fast Provisioning v3.0 - Essential Models Only"

# Directories
WORKSPACE="/workspace"
CHECKPOINTS_DIR="$WORKSPACE/ComfyUI/models/checkpoints"
VAE_DIR="$WORKSPACE/ComfyUI/models/vae"
UPSCALE_DIR="$WORKSPACE/ComfyUI/models/upscale_models"

mkdir -p "$CHECKPOINTS_DIR" "$VAE_DIR" "$UPSCALE_DIR"

# HuggingFace token from environment
HF_TOKEN="${HUGGINGFACE_HUB_TOKEN:-}"

echo "📦 [1/3] Downloading Flux.1 Dev (23.8GB)..."
if [ -n "$HF_TOKEN" ]; then
    wget -c --progress=bar:force:noscroll --header="Authorization: Bearer $HF_TOKEN" \
        "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors" \
        -O "$CHECKPOINTS_DIR/flux1-dev.safetensors" || echo "Flux download failed"
else
    echo "⚠️  No HuggingFace token, skipping Flux"
fi

echo "📦 [2/3] Downloading SDXL Base (6.46GB)..."
wget -c --progress=bar:force:noscroll \
    "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors" \
    -O "$CHECKPOINTS_DIR/sd_xl_base_1.0.safetensors" || echo "SDXL download failed"

echo "📦 [3/3] Downloading VAE..."
wget -c --progress=bar:force:noscroll \
    "https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors" \
    -O "$VAE_DIR/vae-ft-mse-840000-ema-pruned.safetensors" || echo "VAE download failed"

echo "✅ Essential models downloaded!"
echo "📊 Disk usage: $(du -sh $CHECKPOINTS_DIR 2>/dev/null | cut -f1 || echo '0')"
echo "🎯 Checkpoint count: $(ls -1 $CHECKPOINTS_DIR/*.safetensors 2>/dev/null | wc -l)"

# Start ComfyUI
echo "🚀 Starting ComfyUI..."
cd $WORKSPACE/ComfyUI
python main.py --listen 0.0.0.0 --port 18188 --enable-cors-header
