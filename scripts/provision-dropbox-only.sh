#!/usr/bin/env bash
set -euo pipefail

# Load project .env file (if present) so tokens and folder settings don't need to be passed directly.
# Use a safe parser because some .env values may contain spaces (unquoted) and should not be executed.
ENV_FILE="$(dirname "$0")/../.env"
if [ -f "$ENV_FILE" ]; then
    echo "Sourcing environment from $ENV_FILE (safe mode)"
    # Read key=value pairs, ignore comments/empty lines, preserve values with spaces
    while IFS='=' read -r key val; do
        # Trim leading/trailing whitespace from key
        key=$(echo "${key}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        # Skip empty or commented lines
        case "$key" in
            ''|\#*) continue ;;
        esac
        # Remove possible leading whitespace from value
        val="$(echo "${val}" | sed -e 's/^[[:space:]]*//')"
        # Export the variable safely (export accepts an arg like KEY=value)
        export "${key}=${val}"
    done < "$ENV_FILE"
fi

# Allow DROPBOX_FOLDER (project .env) to map to DROPBOX_PATH expected by this script
DROPBOX_PATH=${DROPBOX_FOLDER:-${DROPBOX_PATH:-}}

# Minimal provision script: download a full workspace from Dropbox and start ComfyUI
# Assumes DROPBOX_TOKEN and DROPBOX_PATH (or DROPBOX_FOLDER in .env) are set in the environment
# Usage:
#   DROPBOX_TOKEN="sl.xxxxx" DROPBOX_PATH="/workspace/pornmaster100" bash scripts/provision-dropbox-only.sh
#   OR (recommended): set DROPBOX_FOLDER in .env and run: bash scripts/provision-dropbox-only.sh

LOG=/tmp/provision-dropbox-only.log
function log(){ echo "$(date -u '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG"; }

WORKSPACE=${WORKSPACE:-/workspace}
DROPBOX_TOKEN=${DROPBOX_TOKEN:-}
COMFYUI_DIR=${COMFYUI_DIR:-$WORKSPACE/ComfyUI}
ZIP_TMP=/tmp/workspace.zip
MIN_ZIP_BYTES=${MIN_ZIP_BYTES:-500000}
RETRIES=${RETRIES:-3}
SLEEP_BETWEEN_RETRIES=${SLEEP_BETWEEN_RETRIES:-5}
PORT=${PORT:-8188}
SKIP_TORCH=${SKIP_TORCH:-0}
DROPBOX_API_URL="https://content.dropboxapi.com/2/files/download_zip"
DROPBOX_LIST_URL="https://api.dropboxapi.com/2/files/list_folder"

# If DRY_RUN is set, print environment summary and exit (safe test mode).
if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "DRY RUN: environment variables (sensitive values hidden)"
    echo "  DROPBOX_PATH=$DROPBOX_PATH"
    if [ -n "${DROPBOX_TOKEN:-}" ]; then
        echo "  DROPBOX_TOKEN=<present>"
    else
        echo "  DROPBOX_TOKEN=<missing>"
    fi
    echo "  WORKSPACE=$WORKSPACE"
    echo "  COMFYUI_DIR=$COMFYUI_DIR"
    echo "  ZIP_TMP=$ZIP_TMP"
    echo "  PORT=$PORT"
    exit 0
fi

# Helpers
bail() { log "ERROR: $*"; exit 1; }
command_exists(){ command -v "$1" >/dev/null 2>&1; }

# 1) Sanity checks
log "Starting Dropbox-only provision"
if [[ -z "$DROPBOX_TOKEN" ]]; then
    bail "DROPBOX_TOKEN is not set"
fi
if [[ -z "$DROPBOX_PATH" ]]; then
    bail "DROPBOX_PATH is not set (e.g. '/workspace/pornmaster100')"
fi

# 2) Minimal system packages if needed (best-effort, will not fail if apt missing)
install_system_pkgs() {
    if command_exists apt-get; then
        log "Checking minimal system packages (apt-get available)"
        apt-get update -qq || true
        for pkg in python3 python3-venv unzip curl; do
            if ! dpkg -l | grep -q "^ii  $pkg "; then
                log "Installing $pkg"
                apt-get install -y -qq "$pkg" || true
            fi
        done
    else
        log "No apt-get found; assuming runtime has python/unzip/curl"
    fi
}

install_system_pkgs

# 3) Validate Dropbox token and path by calling a lightweight endpoint
log "Validating Dropbox token and path"
VALIDATE_RESPONSE=$(curl -sS -w "\n%{http_code}" -H "Authorization: Bearer $DROPBOX_TOKEN" -H "Content-Type: application/json" -d '{"path": "'"$DROPBOX_PATH"'"}' "https://api.dropboxapi.com/2/files/list_folder" 2>&1)
HTTP_CODE=$(echo "$VALIDATE_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$VALIDATE_RESPONSE" | sed '$d')
if [ "$HTTP_CODE" != "200" ]; then
    log "ERROR: Dropbox validation failed with HTTP $HTTP_CODE"
    log "Response: $RESPONSE_BODY"
    if echo "$RESPONSE_BODY" | grep -q "path/not_found"; then
        bail "Dropbox path '$DROPBOX_PATH' does not exist. Check your DROPBOX_FOLDER setting."
    elif echo "$RESPONSE_BODY" | grep -q "invalid_access_token\|expired_access_token"; then
        bail "Dropbox token is invalid or expired. Generate a new token at https://www.dropbox.com/developers/apps"
    else
        log "Warning: Validation failed but continuing anyway. Error: $RESPONSE_BODY"
    fi
else
    log "Dropbox token and path validated successfully"
fi

# 4) Download workspace ZIP via Dropbox download_zip
attempt=1
while [ $attempt -le $RETRIES ]; do
    log "Downloading workspace (attempt $attempt/$RETRIES) from Dropbox path: $DROPBOX_PATH"
    # Capture both output and error response
    DOWNLOAD_RESPONSE=$(curl -sS -w "\n%{http_code}" -L -X POST "https://content.dropboxapi.com/2/files/download_zip" \
        -H "Authorization: Bearer $DROPBOX_TOKEN" \
        -H "Dropbox-API-Arg: {\"path\": \"$DROPBOX_PATH\"}" \
        --output "$ZIP_TMP" \
        --connect-timeout 30 \
        --max-time 600 \
        2>&1)
    HTTP_CODE=$(echo "$DOWNLOAD_RESPONSE" | tail -n1)
    ERROR_BODY=$(echo "$DOWNLOAD_RESPONSE" | sed '$d' | grep -v "^#" | head -n 5)
    
    if [ "$HTTP_CODE" = "200" ] && [ -f "$ZIP_TMP" ]; then
        filesize=$(stat -c%s "$ZIP_TMP" 2>/dev/null || echo 0)
        if (( filesize >= MIN_ZIP_BYTES )); then
            log "Downloaded ZIP ($filesize bytes)"
            break
        else
            log "Downloaded file present but too small ($filesize bytes)"
            if [ -f "$ZIP_TMP" ]; then
                log "Error response: $(head -c 500 "$ZIP_TMP" 2>/dev/null || echo 'Unable to read file')"
            fi
        fi
    else
        log "Download attempt $attempt failed (HTTP $HTTP_CODE)"
        if [ -n "$ERROR_BODY" ]; then
            log "Dropbox error: $ERROR_BODY"
        fi
        if [ -f "$ZIP_TMP" ]; then
            ERROR_CONTENT=$(head -c 500 "$ZIP_TMP" 2>/dev/null || echo 'Unable to read')
            log "Response content: $ERROR_CONTENT"
            rm -f "$ZIP_TMP"
        fi
    fi
    attempt=$((attempt+1))
    sleep $SLEEP_BETWEEN_RETRIES
done

if [[ ! -f "$ZIP_TMP" ]]; then
    bail "Failed to download workspace from Dropbox after $RETRIES attempts"
fi
filesize=$(stat -c%s "$ZIP_TMP" 2>/dev/null || echo 0)
if (( filesize < MIN_ZIP_BYTES )); then
    bail "Downloaded ZIP too small ($filesize bytes); aborting"
fi

# 5) Extract workspace
log "Extracting workspace to $WORKSPACE"
mkdir -p "$WORKSPACE"
unzip -q -o "$ZIP_TMP" -d "$WORKSPACE" || bail "Failed to unzip $ZIP_TMP"
rm -f "$ZIP_TMP"

# 6) Locate ComfyUI directory
# Dropbox ZIP may extract with /home/workspace/pornmaster100 structure
# Check multiple possible locations
if [[ -d "$COMFYUI_DIR" ]]; then
    log "Found ComfyUI at configured path: $COMFYUI_DIR"
else
    # Try common extraction paths
    POSSIBLE_PATHS=(
        "$WORKSPACE/ComfyUI"
        "$WORKSPACE/pornmaster100/ComfyUI"
        "$WORKSPACE/home/workspace/pornmaster100/ComfyUI"
        "$WORKSPACE/workspace/pornmaster100/ComfyUI"
    )
    
    FOUND_COMFYUI=""
    for test_path in "${POSSIBLE_PATHS[@]}"; do
        if [[ -d "$test_path" ]] && [[ -f "$test_path/main.py" ]]; then
            COMFYUI_DIR="$test_path"
            FOUND_COMFYUI="$test_path"
            log "Found ComfyUI at: $COMFYUI_DIR"
            break
        fi
    done
    
    # If still not found, try to locate ComfyUI by finding a folder containing main.py
    if [[ -z "$FOUND_COMFYUI" ]]; then
        found=$(find "$WORKSPACE" -maxdepth 5 -type f -name main.py -print -quit 2>/dev/null || true)
        if [[ -n "$found" ]]; then
            COMFYUI_DIR=$(dirname "$found")
            log "Auto-detected ComfyUI at $COMFYUI_DIR"
        else
            log "ComfyUI not found in extracted workspace; attempting to continue assuming files are in place"
        fi
    fi
fi

# 7) Ensure virtualenv exists (create if missing)
if [[ -d "$COMFYUI_DIR/venv" ]]; then
    log "Virtualenv found: $COMFYUI_DIR/venv"
else
    if command_exists python3; then
        log "Creating virtualenv at $COMFYUI_DIR/venv"
        python3 -m venv "$COMFYUI_DIR/venv" || bail "Failed to create venv"
        source "$COMFYUI_DIR/venv/bin/activate"
        if [[ -f "$COMFYUI_DIR/requirements.txt" ]]; then
            log "Installing requirements from requirements.txt"
            pip install -q -U pip setuptools wheel
            pip install -q -r "$COMFYUI_DIR/requirements.txt" || log "pip install returned non-zero status"
        else
            log "No requirements.txt found; skipping pip install"
        fi
        deactivate || true
    else
        bail "python3 not found; cannot create virtualenv"
    fi
fi

# 8) Optional: install torch if missing and not skipped
if [[ "$SKIP_TORCH" != "1" ]]; then
    # Try to detect torch in venv
    source "$COMFYUI_DIR/venv/bin/activate"
    if python -c "import torch; print(torch.__version__)" >/dev/null 2>&1; then
        log "PyTorch already installed in venv"
    else
        log "Installing PyTorch (best-effort). This may take a while."
        pip install -q -U pip setuptools wheel
        # Recommended wheel -- adjust if your GPU requires a different CUDA version
        pip install -q "torch==2.5.1+cu124" "torchvision==0.16.0+cu124" --index-url https://download.pytorch.org/whl/cu124 || log "PyTorch install failed or partial"
    fi
    deactivate || true
else
    log "SKIP_TORCH=1 set; skipping PyTorch installation"
fi

# 9) Start ComfyUI
log "Starting ComfyUI from $COMFYUI_DIR"
if [[ -f "$COMFYUI_DIR/main.py" ]]; then
    source "$COMFYUI_DIR/venv/bin/activate" || true
    nohup python "$COMFYUI_DIR/main.py" --listen 0.0.0.0 --port "$PORT" --enable-cors-header > "$COMFYUI_DIR/comfyui.log" 2>&1 &
    echo $! > /tmp/comfyui.pid
else
    log "main.py not found in $COMFYUI_DIR; cannot start ComfyUI"
fi

# 10) Wait for health
log "Waiting for ComfyUI to respond on port $PORT"
for i in $(seq 1 60); do
    if curl -sS --connect-timeout 2 "http://localhost:$PORT/system_stats" >/dev/null 2>&1; then
        log "ComfyUI responding on http://localhost:$PORT"
        exit 0
    fi
    sleep 2
done

log "ComfyUI did not respond within expected time; check $COMFYUI_DIR/comfyui.log and $LOG"
exit 2
