#!/bin/bash
# AI KINGS - Remote Bootstrapper
# This script is the single URL you put into COMFYUI_PROVISION_SCRIPT
# It downloads the modular system and launches the master-provisioner.

set -e

# --- Configuration ---
SCRIPTS_DIR="/workspace/scripts"
BASE_URL="${SCRIPTS_BASE_URL:-https://raw.githubusercontent.com/pimpsmasterson/working-prototype-ai-kingz/main/scripts}"

echo "🌟 AI KINGS Modular Provisioner Bootstrapping..."

# Create structure
mkdir -p "$SCRIPTS_DIR/modules"
mkdir -p "$SCRIPTS_DIR/tools"
mkdir -p "/workspace/logs"

# Function to fetch script
fetch_script() {
    local path=$1
    local target="$SCRIPTS_DIR/$path"
    echo "  📥 Fetching $path..."
    curl -fsSL "$BASE_URL/$path" -o "$target"
    chmod +x "$target"
}

# Fetch core scripts
fetch_script "tools/download.sh"
fetch_script "tools/state-manager.sh"
fetch_script "modules/01-system-deps.sh"
fetch_script "modules/02-custom-nodes.sh"
fetch_script "modules/03-models-core.sh"
fetch_script "modules/04-models-wan.sh"
fetch_script "modules/05-workflows.sh"
fetch_script "master-provision.sh"

# Launch Master
echo "🚀 Launching Master Provisioner..."
bash "$SCRIPTS_DIR/master-provision.sh"
