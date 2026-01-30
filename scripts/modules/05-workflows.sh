#!/bin/bash
# AI KINGS - Module 05: Workflows (Production-Grade)
# Features: Retry logic, JSON validation, error recovery, resource checks

set -uo pipefail
source /workspace/scripts/tools/state-manager.sh
DOWNLOADER="/workspace/scripts/tools/download.sh"

MODULE_NAME="workflows"

if check_module "$MODULE_NAME"; then
    echo "✅ Module $MODULE_NAME already completed. Skipping."
    exit 0
fi

# Configuration
DOWNLOAD_TIMEOUT=300  # 5 minutes for workflow files
MAX_RETRIES=3

# Logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WORKFLOWS] $*" >&2
}

error_log() {
    log "$1" "ERROR"
}

warn_log() {
    log "$1" "WARN"
}

# Resource validation for workflow downloads
check_resources_for_workflows() {
    log "🔍 Checking resources for workflow downloads..."

    # Workflows are small, but check basic connectivity
    if ! curl -fsSL --max-time 10 "https://www.google.com" > /dev/null 2>&1; then
        error_log "No internet connectivity detected"
        return 1
    fi

    # Check disk space (workflows are tiny - need 1GB+ free)
    local avail_kb
    avail_kb=$(df /workspace | tail -1 | awk '{print $4}')  # KB
    local avail_gb=$((avail_kb / 1024 / 1024))  # Convert to GB
    if (( avail_gb < 1 )); then
        error_log "Insufficient disk space for workflows: ${avail_gb}GB available, need 1GB+"
        return 1
    fi

    log "✅ Resources adequate for workflow downloads"
    return 0
}

# Enhanced workflow download with retry and validation
download_workflow_with_retry() {
    local url=$1
    local target_file=$2
    local workflow_name=$3
    local attempt=1

    while (( attempt <= MAX_RETRIES )); do
        log "📥 Downloading workflow: $workflow_name (attempt $attempt/$MAX_RETRIES)"

        if timeout "$DOWNLOAD_TIMEOUT" "$DOWNLOADER" "$url" "$(dirname "$target_file")" "$(basename "$target_file")"; then
            # Validate JSON immediately
            if validate_workflow_json "$target_file" "$workflow_name"; then
                log "✅ Successfully downloaded and validated $workflow_name"
                return 0
            else
                warn_log "JSON validation failed for $workflow_name, retrying..."
                rm -f "$target_file"
            fi
        else
            warn_log "Download failed for $workflow_name (attempt $attempt)"
        fi

        ((attempt++))
        if (( attempt <= MAX_RETRIES )); then
            local sleep_time=$((attempt * 5))  # Exponential backoff
            log "⏳ Waiting ${sleep_time}s before retry..."
            sleep "$sleep_time"
        fi
    done

    error_log "Failed to download $workflow_name after $MAX_RETRIES attempts"
    return 1
}

# Comprehensive JSON validation for workflows
validate_workflow_json() {
    local file=$1
    local name=$2

    if [[ ! -f "$file" ]]; then
        error_log "Workflow file does not exist: $file"
        return 1
    fi

    # Check file size (workflows should be reasonable size)
    local size
    size=$(stat -c%s "$file" 2>/dev/null || echo "0")
    if (( size < 100 || size > 10485760 )); then  # 100B to 10MB
        error_log "Invalid workflow file size: $size bytes for $name"
        return 1
    fi

    # Validate JSON syntax
    if ! python3 -c "import json; json.load(open('$file'))" 2>/dev/null; then
        error_log "Invalid JSON syntax in $name"
        return 1
    fi

    # Validate workflow structure (basic ComfyUI workflow checks)
    if ! python3 -c "
import json
try:
    with open('$file') as f:
        data = json.load(f)
    # Check for basic workflow structure
    if not isinstance(data, dict):
        print('ERROR: Root is not a dict')
        exit(1)
    # Check for nodes (most workflows have this)
    if 'nodes' in data and not isinstance(data['nodes'], list):
        print('ERROR: nodes is not a list')
        exit(1)
    # Check for links if nodes exist
    if 'links' in data and not isinstance(data['links'], list):
        print('ERROR: links is not a list')
        exit(1)
    print('VALID')
except Exception as e:
    print(f'ERROR: {e}')
    exit(1)
" 2>/dev/null | grep -q "VALID"; then
        error_log "Workflow structure validation failed for $name"
        return 1
    fi

    log "✅ Workflow $name passed all validation checks"
    return 0
}

# Download all workflows with error tracking
download_all_workflows() {
    local WORKFLOWS_DIR="/workspace/ComfyUI/user/default/workflows"
    local failed_workflows=()
    local success_count=0

    # Ensure directory exists
    if ! mkdir -p "$WORKFLOWS_DIR"; then
        error_log "Failed to create workflows directory: $WORKFLOWS_DIR"
        return 1
    fi

    # List of workflows to fetch from the scripts repository
    declare -a WORKFLOWS=(
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
    local WF_BASE_URL="${SCRIPTS_BASE_URL%/*}/workflows"

    log "📦 Starting workflow downloads from: $WF_BASE_URL"

    for wf in "${WORKFLOWS[@]}"; do
        local target_file="$WORKFLOWS_DIR/$wf"
        local wf_url="$WF_BASE_URL/$wf"

        if download_workflow_with_retry "$wf_url" "$target_file" "$wf"; then
            ((success_count++))
        else
            failed_workflows+=("$wf")
        fi
    done

    # Report results
    log "📊 Workflow download summary: $success_count successful, ${#failed_workflows[@]} failed"

    if (( ${#failed_workflows[@]} > 0 )); then
        warn_log "Failed workflows: ${failed_workflows[*]}"
        warn_log "Continuing with successful workflows..."
        return 1
    else
        log "✅ All workflows downloaded and validated successfully"
        return 0
    fi
}

# Optional: Clean up invalid workflow files
cleanup_invalid_workflows() {
    local WORKFLOWS_DIR="/workspace/ComfyUI/user/default/workflows"

    if [[ -d "$WORKFLOWS_DIR" ]]; then
        log "🧹 Cleaning up invalid workflow files..."

        find "$WORKFLOWS_DIR" -name "*.json" | while read -r file; do
            if ! validate_workflow_json "$file" "$(basename "$file")" 2>/dev/null; then
                warn_log "Removing invalid workflow file: $file"
                rm -f "$file"
            fi
        done
    fi
}

echo "🚀 Starting $MODULE_NAME (Production Mode)..."

# Pre-flight checks
if ! check_resources_for_workflows; then
    error_log "Resource check failed - cannot proceed with workflow downloads"
    exit 1
fi

# Optional cleanup
cleanup_invalid_workflows

# Download all workflows
if download_all_workflows; then
    log "✅ All workflows processed successfully"
else
    warn_log "Some workflows failed to download - check logs for details"
fi

mark_module_complete "$MODULE_NAME"
log "✅ Finished $MODULE_NAME (Production Mode)"
