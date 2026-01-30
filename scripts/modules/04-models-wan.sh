#!/bin/bash
# AI KINGS - Module 04: Wan Video Models
# Downloads Wan 2.1 and 2.2 models for next-gen video generation

set -e
source /workspace/scripts/tools/state-manager.sh
DOWNLOADER="/workspace/scripts/tools/download.sh"

MODULE_NAME="models-wan"

if check_module "$MODULE_NAME"; then
    echo "✅ Module $MODULE_NAME already completed. Skipping."
    exit 0
fi

echo "🚀 Starting $MODULE_NAME..."

COMFYUI_DIR="/workspace/ComfyUI"

# Wan 2.1 Models (HuggingFace)
echo "📦 Downloading Wan 2.1 models..."
"$DOWNLOADER" "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_t2v_1.3B_fp16.safetensors" \
              "$COMFYUI_DIR/models/diffusion_models" "wan2.1_t2v_1.3B_fp16.safetensors"

"$DOWNLOADER" "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
              "$COMFYUI_DIR/models/text_encoders" "umt5_xxl_fp8_e4m3fn_scaled.safetensors"

"$DOWNLOADER" "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan2.1_vae.safetensors" \
              "$COMFYUI_DIR/models/vae" "wan2.1_vae.safetensors"

# Wan 2.2 Models (HuggingFace - High Noise / Low Noise MoE)
echo "📦 Downloading Wan 2.2 models..."
"$DOWNLOADER" "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors" \
              "$COMFYUI_DIR/models/diffusion_models" "wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors"

"$DOWNLOADER" "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors" \
              "$COMFYUI_DIR/models/diffusion_models" "wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors"

"$DOWNLOADER" "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors" \
              "$COMFYUI_DIR/models/vae" "wan2.2_vae.safetensors"

# Mark complete
mark_module_complete "$MODULE_NAME"
echo "✅ Finished $MODULE_NAME."
