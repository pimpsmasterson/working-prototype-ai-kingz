#!/bin/bash
# AI KINGS - Module 01: System Dependencies
# Installs APT packages and sets up Python environment

set -e
source /workspace/scripts/tools/state-manager.sh

MODULE_NAME="system-deps"

if check_module "$MODULE_NAME"; then
    echo "✅ Module $MODULE_NAME already completed. Skipping."
    exit 0
fi

echo "🚀 Starting $MODULE_NAME..."

# 1. Update APT and install base packages
APT_PACKAGES=(
    "unrar" "p7zip-full" "unzip" "ffmpeg" "libgl1" "libglib2.0-0" 
    "git-lfs" "file" "aria2" "curl" "python3-pip"
)

sudo apt-get update
sudo apt-get install -y "${APT_PACKAGES[@]}"

# 2. Setup Git LFS
git lfs install

# 3. Create necessary directories
mkdir -p /workspace/logs
mkdir -p /workspace/ComfyUI/models/checkpoints
mkdir -p /workspace/ComfyUI/models/loras
mkdir -p /workspace/ComfyUI/user/default/workflows

# 4. Mark complete
mark_module_complete "$MODULE_NAME"
echo "✅ Finished $MODULE_NAME."
