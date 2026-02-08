#!/bin/bash
# REPAIR SCRIPT FOR COMFYUI INSTANCE
# Fixes NumPy version and downloads missing models

LOG_FILE="/tmp/repair_instance.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "🛠️  STARTING INSTANCE REPAIR..."
echo "---------------------------------------------------"

# 1. FIX NUMPY (Downgrade to <2)
echo "📦 Fixing NumPy version..."
source /workspace/venv/bin/activate
pip install "numpy<2" --force-reinstall
pip show numpy | grep Version
echo "✅ NumPy fixed."

# 2. DOWNLOAD MISSING MODELS
COMFY_DIR="/workspace/ComfyUI"

download_file() {
    local url="$1"
    local dir="$2"
    local filename="$3"
    local token="${HUGGINGFACE_HUB_TOKEN}"
    
    mkdir -p "$dir"
    echo "📥 Downloading $filename..."
    
    if curl -L -H "Authorization: Bearer $token" -o "${dir}/${filename}" "$url"; then
        echo "   ✅ Success: $filename"
    else
        echo "   ❌ Failed: $filename"
    fi
}

# Clip Vision H (Critical for I2V)
download_file "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" \
    "${COMFY_DIR}/models/clip_vision" "clip_vision_h.safetensors"

# Lotus Depth (Critical for Depth Control)
download_file "https://huggingface.co/Comfy-Org/lotus/resolve/main/lotus-depth-d-v1-1.safetensors" \
    "${COMFY_DIR}/models/diffusion_models" "lotus-depth-d-v1-1.safetensors"

# LTX Upscaler (Spatial)
download_file "https://huggingface.co/Lightricks/ltxv-spatial-upscaler-0.9.7/resolve/main/ltxv_spatial_upscaler_0.9.7.safetensors" \
    "${COMFY_DIR}/models/latent_upscale_models" "ltxv_spatial_upscaler_0.9.7.safetensors"

# MISSING MODELS FROM ERROR LOGS:
# 1. CLIP Text Encoder (clip_l.safetensors)
download_file "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors" \
    "${COMFY_DIR}/models/text_encoders" "clip_l.safetensors"

# 2. Wan VAE (wan_vae.safetensors)
download_file "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
    "${COMFY_DIR}/models/vae" "wan_vae.safetensors"

# 3. UMT5 Encoder (umt5_xxl_fp8_scaled.safetensors)
download_file "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
    "${COMFY_DIR}/models/text_encoders" "umt5_xxl_fp8_scaled.safetensors"

# 3. RESTART COMFYUI
echo "🔄 Restarting ComfyUI..."
pkill -f "python.*main.py"
sleep 2
nohup python3 main.py --listen 0.0.0.0 --port 8188 --enable-cors-header > /workspace/comfyui.log 2>&1 &
echo "✅ ComfyUI Restarted (PID: $!)"

echo "---------------------------------------------------"
echo "🎉 REPAIR COMPLETE!"
