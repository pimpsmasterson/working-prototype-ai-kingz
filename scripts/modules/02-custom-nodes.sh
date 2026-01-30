#!/bin/bash
# AI KINGS - Module 02: Custom Nodes
# Clones and installs dependencies for ComfyUI custom nodes

set -e
source /workspace/scripts/tools/state-manager.sh

MODULE_NAME="custom-nodes"

if check_module "$MODULE_NAME"; then
    echo "✅ Module $MODULE_NAME already completed. Skipping."
    exit 0
fi

echo "🚀 Starting $MODULE_NAME..."

COMFYUI_DIR="/workspace/ComfyUI"
CUSTOM_NODES_DIR="${COMFYUI_DIR}/custom_nodes"

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

# Function to activate venv if it exists
activate_venv() {
    if [ -f "/venv/main/bin/activate" ]; then
        source /venv/main/bin/activate
    elif [ -f "/workspace/venv/bin/activate" ]; then
        source "/workspace/venv/bin/activate"
    fi
}

activate_venv

for repo in "${NODES[@]}"; do
    node_name=$(basename "$repo")
    target_path="${CUSTOM_NODES_DIR}/${node_name}"
    
    if [ ! -d "$target_path" ]; then
        echo "📥 Cloning $node_name..."
        git clone --depth 1 "$repo" "$target_path"
    else
        echo "✅ $node_name already exists."
    fi
    
    # Install requirements if they exist
    if [ -f "${target_path}/requirements.txt" ]; then
        echo "🔧 Installing requirements for $node_name..."
        pip install --no-cache-dir -r "${target_path}/requirements.txt"
    fi
done

# High-performance video dependencies
echo "🔧 Installing high-performance video dependencies..."
pip install --no-cache-dir -q einops accelerate transformers opencv-python-headless sageattention huggingface-hub

mark_module_complete "$MODULE_NAME"
echo "✅ Finished $MODULE_NAME."
