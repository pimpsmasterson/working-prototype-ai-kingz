#!/bin/bash
set -e

# ---------------------------------------------------------------------------------------------------------------------
# 🔞 Wan 2.2 Remix NSFW I2V Provisioning Script
# ---------------------------------------------------------------------------------------------------------------------
# This script provisions a ComfyUI environment specifically for the Wan 2.2 Remix NSFW I2V workflow.
# It downloads:
#   1. Wan 2.2 Remix Models (High & Low Lighting) from 'FX-FeiHou/wan2.2-Remix/NSFW'
#   2. Wan 2.1 VAE and UMT5 Text Encoder from 'Comfy-Org/Wan_2.1_ComfyUI_repackaged'
#   3. ComfyUI-WanVideoWrapper and other essential nodes.
# ---------------------------------------------------------------------------------------------------------------------

cd /workspace

# 1. System Packages & Python Dependencies
echo "📦 Installing system dependencies..."
apt-get update && apt-get install -y aria2 p7zip-full
pip install --no-cache-dir huggingface_hub

# 2. ComfyUI Setup
if [ ! -d "ComfyUI" ]; then
    echo "🎨 Cloning ComfyUI..."
    git clone https://github.com/comfyanonymous/ComfyUI.git
fi

# 3. Model Downloads (The Critical Part)
echo "⬇️  Downloading Wan 2.2 Remix Models..."
mkdir -p ComfyUI/models/diffusion_models
mkdir -p ComfyUI/models/text_encoders
mkdir -p ComfyUI/models/vae

# Function to download with aria2
download_file() {
    local url="$1"
    local dir="$2"
    local filename="$3"
    
    if [ -f "${dir}/${filename}" ]; then
        echo "✅ ${filename} already exists."
    else
        echo "⏳ Downloading ${filename}..."
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
# Text Encoder (Required for Wan)
download_file "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/nsfw_wan_umt5-xxl_fp8_scaled.safetensors" \
    "ComfyUI/models/text_encoders" \
    "nsfw_wan_umt5-xxl_fp8_scaled.safetensors"

# VAE (Wan 2.1 VAE - 36 channels)
download_file "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
    "ComfyUI/models/vae" \
    "wan_2.1_vae.safetensors"

# 4. Custom Nodes
echo "🧩 Installing Custom Nodes..."
cd ComfyUI/custom_nodes

# Kijai's Wrapper (CRITICAL)
if [ ! -d "ComfyUI-WanVideoWrapper" ]; then
    git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git
    cd ComfyUI-WanVideoWrapper
    pip install -r requirements.txt
    cd ..
fi

# Frame Interpolation (Recommended in tutorial)
if [ ! -d "ComfyUI-Frame-Interpolation" ]; then
    git clone https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git
    cd ComfyUI-Frame-Interpolation
    pip install -r requirements.txt
    cd ..
fi

# KJNodes (Support)
if [ ! -d "ComfyUI-KJNodes" ]; then
    git clone https://github.com/kijai/ComfyUI-KJNodes.git
    cd ComfyUI-KJNodes
    pip install -r requirements.txt
    cd ..
fi

# VideoHelperSuite
if [ ! -d "ComfyUI-VideoHelperSuite" ]; then
     git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
     cd ComfyUI-VideoHelperSuite
     pip install -r requirements.txt
     cd ..
fi

echo "✅ Provisioning Complete! Start ComfyUI to use Wan 2.2 Remix."
