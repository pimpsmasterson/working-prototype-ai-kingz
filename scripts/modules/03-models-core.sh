#!/bin/bash
# AI KINGS - Module 03: Core Models (Checkpoints, LoRAs, VAI)
# Downloads essential SDXL/Pony models and common dependencies

set -e
source /workspace/scripts/tools/state-manager.sh
DOWNLOADER="/workspace/scripts/tools/download.sh"

MODULE_NAME="models-core"

if check_module "$MODULE_NAME"; then
    echo "✅ Module $MODULE_NAME already completed. Skipping."
    exit 0
fi

echo "🚀 Starting $MODULE_NAME..."

COMFYUI_DIR="/workspace/ComfyUI"

# 1. Main Checkpoints
echo "📦 Downloading Base Checkpoints..."
"$DOWNLOADER" "https://civitai.com/api/download/models/2602579" \
              "$COMFYUI_DIR/models/checkpoints" "pmXL_v1.safetensors"

"$DOWNLOADER" "https://civitai.com/api/download/models/290640" \
              "$COMFYUI_DIR/models/checkpoints" "ponyDiffusionV6XL.safetensors"

# 2. Essential LoRAs
echo "📦 Downloading Core LoRAs..."
"$DOWNLOADER" "https://civitai.com/api/download/models/300438" \
              "$COMFYUI_DIR/models/loras" "pony_realism_v2.1.safetensors"

# 3. AnimateDiff & Video Components
echo "📦 Downloading Animation Components..."
"$DOWNLOADER" "https://huggingface.co/guoyww/animatediff/resolve/main/mm_sdxl_v1_beta.ckpt" \
              "$COMFYUI_DIR/models/animatediff_models" "mm_sdxl_v1_beta.ckpt"

"$DOWNLOADER" "https://github.com/hzwer/Practical-RIFE/releases/download/v4.7/rife47.pth" \
              "$COMFYUI_DIR/models/vfi" "rife47.pth"

# 4. Upscalers & ControlNet
echo "📦 Downloading Upscalers & ControlNet..."
"$DOWNLOADER" "https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth" \
              "$COMFYUI_DIR/models/upscale_models" "4x-UltraSharp.pth"

"$DOWNLOADER" "https://huggingface.co/thibaud/controlnet-openpose-sdxl-1.0/resolve/main/OpenPoseXL2.safetensors" \
              "$COMFYUI_DIR/models/controlnet" "OpenPoseXL2.safetensors"

# 5. Face Detailer / Impact Pack Models
echo "📦 Downloading Impact Pack Models..."
"$DOWNLOADER" "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt" \
              "$COMFYUI_DIR/models/ultralytics/bbox" "face_yolov8m.pt"

"$DOWNLOADER" "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth" \
              "$COMFYUI_DIR/models/sams" "sam_vit_b_01ec64.pth"

mark_module_complete "$MODULE_NAME"
echo "✅ Finished $MODULE_NAME."
