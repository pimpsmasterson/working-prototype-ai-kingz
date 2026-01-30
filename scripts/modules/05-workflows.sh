#!/bin/bash
# AI KINGS - Module 05: Workflows
# Installs and validates pre-configured ComfyUI workflows

set -e
source /workspace/scripts/tools/state-manager.sh
DOWNLOADER="/workspace/scripts/tools/download.sh"

MODULE_NAME="workflows"

if check_module "$MODULE_NAME"; then
    echo "✅ Module $MODULE_NAME already completed. Skipping."
    exit 0
fi

echo "🚀 Starting $MODULE_NAME..."

WORKFLOWS_DIR="/workspace/ComfyUI/user/default/workflows"
mkdir -p "$WORKFLOWS_DIR"

# List of workflows to fetch from the scripts repository
# These should be hosted in the same 'scripts/workflows' directory relative to BASE_URL
WORKFLOWS=(
    "nsfw_ultimate_image_workflow.json"
    "nsfw_video_workflow.json"
    "nsfw_ultimate_video_workflow.json"
    "nsfw_lora_image_workflow.json"
    "nsfw_pornmaster_workflow.json"
    "nsfw_controlnet_pose_workflow.json"
    "nsfw_wan21_video_workflow.json"
    "nsfw_realistic_furry_video_workflow.json"
    "nsfw_cinema_production_workflow.json"
    "nsfw_wan22_master_video_workflow.json"
    "nsfw_wan25_preview_video_workflow.json"
)

# Base URL for workflows (passed via env or inherited)
WF_BASE_URL="${SCRIPTS_BASE_URL%/*}/workflows"

for wf in "${WORKFLOWS[@]}"; do
    echo "  📥 Installing $wf..."
    # We use curl directly for workflows as they are small and don't need aria2c
    curl -fsSL "$WF_BASE_URL/$wf" -o "$WORKFLOWS_DIR/$wf"
    
    # Simple JSON validation check
    if ! python3 -c "import json; json.load(open('$WORKFLOWS_DIR/$wf'))" 2>/dev/null; then
        echo "  ❌ Failed to validate $wf. Possible corrupt download."
        exit 1
    fi
done

mark_module_complete "$MODULE_NAME"
echo "✅ Finished $MODULE_NAME."
