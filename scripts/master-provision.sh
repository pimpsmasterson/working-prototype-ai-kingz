#!/bin/bash
# AI KINGS - Master Provisioning Orchestrator
# This is the main entry point for Vast.ai instances

set -e

# --- CONFIGURATION ---
WORKSPACE="/workspace"
GIT_ROOT="/workspace/aikings-scripts" # Assuming we clone the scripts repo here
SCRIPTS_ROOT="/workspace/scripts"
LOG_FILE="/workspace/logs/master_provision.log"

mkdir -p /workspace/logs
echo "--- Provisioning started at $(date) ---" | tee -a "$LOG_FILE"

# --- HELPER: Fetch Module ---
# In a real setup, we might fetch these from a URL or a git clone
# For now, we assume SCRIPTS_ROOT is already populated by the main setup stage
run_module() {
    local module_path=$1
    echo "▶️ Running module: $(basename $module_path)" | tee -a "$LOG_FILE"
    bash "$module_path" 2>&1 | tee -a "$LOG_FILE"
}

# --- STAGE 0: Self-Setup ---
# If this is the very first run, we might need to clone the scripts
# (This logic would be added once we decide on the hosting repo)

# --- EXECUTION PIPELINE ---
source "${SCRIPTS_ROOT}/tools/state-manager.sh"

run_module "${SCRIPTS_ROOT}/modules/01-system-deps.sh"
run_module "${SCRIPTS_ROOT}/modules/02-custom-nodes.sh"
run_module "${SCRIPTS_ROOT}/modules/03-models-core.sh"
run_module "${SCRIPTS_ROOT}/modules/04-models-wan.sh"
run_module "${SCRIPTS_ROOT}/modules/05-workflows.sh"

echo "🏁 All provisioning modules processed at $(date)." | tee -a "$LOG_FILE"

# --- FINAL STARTUP ---
echo "🚀 Starting ComfyUI..." | tee -a "$LOG_FILE"
# Add your startup command here
