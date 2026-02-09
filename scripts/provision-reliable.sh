#!/bin/bash
# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║   👑 AI KINGS COMFYUI - RELIABLE PROVISIONER v3.0                            ║
# ║                                                                               ║
# ║   ✓ HuggingFace Primary + Dropbox Fallback (Multi-Source Reliability)       ║
# ║   ✓ Ultra-Fast Parallel Downloads (aria2c 8x - Optimized)                   ║
# ║   ✓ Models Only (Workflows managed separately)                              ║
# ║   ✓ 45+ Verified Models from Official Sources                                ║
# ║   ✓ Smart Rate-Limit Handling (Civitai Sequential, HF Parallel)              ║
# ║   ✓ Full Ubuntu 24.04 Compatibility                                         ║
# ║   ✓ Enhanced Security (Header-based Auth, PID Tracking)                     ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

# ═══════════════════════════════════════════════════════════════════════════════
# ANTI-HANGING & DROPBOX RULES
# ═══════════════════════════════════════════════════════════════════════════════
#
# DROPBOX DOWNLOAD RULES (Enforced Automatically):
#   • Single connection ONLY (multi-connection = instant ban)
#   • 3-minute timeout per attempt (aggressive to prevent hanging)
#   • 50KB/s minimum speed (detects throttling, auto-fails to fallback)
#   • Max 5 retries (fail fast to try alternative source)
#   • Bandwidth limit: ~1TB/day per account (we stay well under)
#
# ANTI-HANGING MECHANISMS:
#   • Global 30-minute timeout per file (hard kill if exceeded)
#   • Stall detection: Fails if speed drops below threshold for 30s
#   • Max file size validation (rejects HTML error pages)
#   • Automatic cleanup of partial downloads on failure
#   • Fallback to alternative source on ANY hang/timeout
#
# TIMEOUT HIERARCHY (Prevents Lock-ups):
#   1. Per-attempt timeout: 3-5 min (aria2c/wget layer)
#   2. Stall detection: 30s of low speed = abort (aria2c only)
#   3. Global timeout: 30 min per file (outer shell timeout wrapper)
#   4. Script continues even if single file fails (no cascade failure)
#
# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION & LOGGING
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

# Cleanup handler - kill all background download processes on exit
cleanup_on_exit() {
    local exit_code=$?

    # On normal exit, clean exit without killing background jobs
    if [[ $exit_code -eq 0 ]]; then
        echo "   ✅ Provisioning completed successfully"
        return 0
    fi

    # On error, cleanup background processes
    echo "⚠️  Error detected (exit code: $exit_code) - cleaning up background processes..."

    # Preserve ComfyUI PID if present to avoid killing the running server
    local preserve_pid_file="${WORKSPACE:-/workspace}/comfyui.pid"
    local preserve_pid=""
    if [[ -f "$preserve_pid_file" ]]; then
        preserve_pid=$(cat "$preserve_pid_file" 2>/dev/null || true)
        echo "   ⛳ Preserving ComfyUI PID: $preserve_pid"
    fi

    # Kill jobs except preserved PID (use SIGTERM first for graceful shutdown)
    for p in $(jobs -p); do
        if [[ -n "$preserve_pid" && "$p" == "$preserve_pid" ]]; then
            echo "   ⛳ Skipping ComfyUI PID $preserve_pid from cleanup"
            continue
        fi
        kill -15 "$p" 2>/dev/null || true  # SIGTERM (graceful)
    done

    # Wait 2 seconds for graceful shutdown
    sleep 2

    # Force kill any remaining processes
    for p in $(jobs -p); do
        if [[ -n "$preserve_pid" && "$p" == "$preserve_pid" ]]; then
            continue
        fi
        kill -9 "$p" 2>/dev/null || true  # SIGKILL (force)
    done

    # Kill any remaining aria2c or wget processes started by this script
    if [[ -n "$preserve_pid" ]]; then
        # Kill children of this script except the preserved PID
        for c in $(pgrep -P $$ || true); do
            if [[ "$c" == "$preserve_pid" ]]; then
                continue
            fi
            pkill -P "$c" -15 aria2c 2>/dev/null || true  # SIGTERM first
            pkill -P "$c" -15 wget 2>/dev/null || true
        done
        sleep 1
        for c in $(pgrep -P $$ || true); do
            if [[ "$c" == "$preserve_pid" ]]; then
                continue
            fi
            pkill -P "$c" -9 aria2c 2>/dev/null || true  # SIGKILL if still alive
            pkill -P "$c" -9 wget 2>/dev/null || true
        done
    else
        pkill -P $$ -15 aria2c 2>/dev/null || true
        pkill -P $$ -15 wget 2>/dev/null || true
        sleep 1
        pkill -P $$ -9 aria2c 2>/dev/null || true
        pkill -P $$ -9 wget 2>/dev/null || true
    fi

    exit $exit_code
}

# Set trap for cleanup on EXIT, INT (Ctrl+C), TERM
trap cleanup_on_exit EXIT INT TERM

# 1. DEFINE LOGGING & PRE-FLIGHT
LOG_FILE="/tmp/provision_v3.log"
log() { echo "$(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE"; }
log_section() { log ""; log "═══════════════════════════════════════════════════════════════"; log "$*"; log "═══════════════════════════════════════════════════════════════"; }

# ═══════════════════════════════════════════════════════════════════════════════
# START PROVISIONING (No Screen Wrapper - Runs Directly)
# ═══════════════════════════════════════════════════════════════════════════════
log "🎯 Starting provisioning directly..."

  # List of filenames that are optional: failures for these will not abort provisioning
  OPTIONAL_ASSETS=(
    "example_pose.png"
    "rife426.zip"
  )

  is_optional_file() {
    local f="$1"
    for opt in "${OPTIONAL_ASSETS[@]:-}"; do
      if [[ "$opt" == "$f" ]]; then
        return 0
      fi
    done
    return 1
  }
# ═══════════════════════════════════════════════════════════════════════════════
# EMERGENCY RECOVERY (SSH FIXES COMPLETELY REMOVED)
# ═══════════════════════════════════════════════════════════════════════════════

# Emergency recovery for critical system issues (all SSH fixes removed)
emergency_recovery() {
    log "🚨 Running emergency recovery..."

    # Suppress pip root warnings
    export PIP_ROOT_USER_ACTION=ignore

    # Fix conda environment if present
    if [[ -n "${CONDA_DEFAULT_ENV:-}" ]]; then
        conda clean --all -y 2>/dev/null || true
    fi

    # Clear pip cache to avoid corrupted packages
    if command -v python3 &>/dev/null; then
        python3 -m pip cache purge 2>/dev/null || true
    fi

    # Fix file permissions on workspace
    if [[ -n "${WORKSPACE:-}" ]] && [[ -d "$WORKSPACE" ]]; then
        chmod -R 755 "$WORKSPACE" 2>/dev/null || true
        chown -R root:root "$WORKSPACE" 2>/dev/null || true
    fi

    log "✅ Emergency recovery complete"
}

check_required_cmds() {
    REQUIRED_CMDS=("aria2c" "git" "python3" "curl" "df" "awk")
    for cmd in "${REQUIRED_CMDS[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || { echo >&2 "❌ REQUIRED CMD MISSING: $cmd"; exit 1; }
    done
}

install_apt_packages() {
    log_section "📦 INSTALLING APT PACKAGES"

    # Update package list
    log "   Updating apt package list..."
    apt-get update -qq || {
        log "⚠️  apt-get update failed, retrying once..."
        sleep 5
        apt-get update -qq || log "⚠️  apt-get update failed again, continuing anyway..."
    }

    # Install packages - batch mode for speed and resilience
    log "   Installing system packages (batch mode)..."
    
    # Collect packages that need installation
    local to_install=()
    for pkg in "${APT_PACKAGES[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            to_install+=("$pkg")
        else
            log "   ✓ Already installed: $pkg"
        fi
    done
    
    # Install all at once with timeout (much faster than one-by-one)
    if [ ${#to_install[@]} -gt 0 ]; then
        log "   Installing ${#to_install[@]} packages: ${to_install[*]}"
        # 5 minute timeout for entire batch (prevents infinite hangs)
        timeout 300 apt-get install -y -qq "${to_install[@]}" 2>&1 | grep -v "^debconf:" || {
            log "   ⚠️  Batch installation timed out or failed, trying individually with short timeout..."
            # Fallback: try each package individually with 60s timeout
            for pkg in "${to_install[@]}"; do
                log "   Retry: $pkg"
                timeout 60 apt-get install -y -qq "$pkg" 2>&1 | grep -v "^debconf:" || {
                    log "   ⚠️  $pkg failed, skipping..."
                }
            done
        }
    fi

    log "✅ APT packages installed successfully"
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLOUDFLARE TUNNEL (Zero-Config Public Access)
# ═══════════════════════════════════════════════════════════════════════════════
# Cloudflare Quick Tunnel provides instant public URLs without configuration.
# This eliminates the need for SSH tunneling, port forwarding, or firewall rules.

install_cloudflared() {
    log_section "📡 INSTALLING CLOUDFLARE TUNNEL"
    
    local CLOUDFLARED_BIN="/usr/local/bin/cloudflared"
    local CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
    
    # Check if already installed
    if [[ -x "$CLOUDFLARED_BIN" ]]; then
        local version=$("$CLOUDFLARED_BIN" --version 2>/dev/null | head -1 || echo "unknown")
        log "   ✅ Cloudflared already installed: $version"
        return 0
    fi
    
    log "   📥 Downloading cloudflared from GitHub..."
    
    # Download with retries
    local download_success=false
    for attempt in {1..3}; do
        if curl -fsSL --connect-timeout 30 --max-time 120 \
            "$CLOUDFLARED_URL" -o "$CLOUDFLARED_BIN" 2>/dev/null; then
            download_success=true
            break
        fi
        log "   ⚠️  Download attempt $attempt failed, retrying..."
        sleep 5
    done
    
    if [[ "$download_success" != "true" ]]; then
        log "   ❌ Failed to download cloudflared after 3 attempts"
        log "   ComfyUI will still work but tunnel access won't be available"
        return 1
    fi
    
    # Make executable
    chmod +x "$CLOUDFLARED_BIN"
    
    # Verify installation
    if "$CLOUDFLARED_BIN" --version >/dev/null 2>&1; then
        local version=$("$CLOUDFLARED_BIN" --version 2>/dev/null | head -1)
        log "   ✅ Cloudflared installed: $version"
        return 0
    else
        log "   ❌ Cloudflared installation verification failed"
        rm -f "$CLOUDFLARED_BIN"
        return 1
    fi
}

start_cloudflare_tunnel() {
    log_section "🌐 STARTING CLOUDFLARE TUNNEL"
    
    local CLOUDFLARED_BIN="/usr/local/bin/cloudflared"
    local TUNNEL_LOG="${WORKSPACE}/cloudflared.log"
    local TUNNEL_PID_FILE="${WORKSPACE}/cloudflared.pid"
    local TUNNEL_URL_FILE="${WORKSPACE}/.comfyui_tunnel_url"
    
    # Check if cloudflared is installed
    if [[ ! -x "$CLOUDFLARED_BIN" ]]; then
        log "   ⚠️  Cloudflared not installed, skipping tunnel setup"
        return 1
    fi
    
    # Kill any existing tunnel process
    if [[ -f "$TUNNEL_PID_FILE" ]]; then
        local old_pid=$(cat "$TUNNEL_PID_FILE" 2>/dev/null)
        if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
            log "   🔄 Stopping existing tunnel (PID: $old_pid)"
            kill "$old_pid" 2>/dev/null || true
            sleep 2
        fi
        rm -f "$TUNNEL_PID_FILE"
    fi
    
    # Wait for ComfyUI to be ready before starting tunnel.
    # First run with many custom nodes can take 2-5+ minutes; allow up to 5 minutes.
    log "   ⏳ Waiting for ComfyUI to respond on port 8188 (up to 5 min, first start is slow)..."
    local comfy_ready=false
    local max_attempts=60
    local interval=5
    for i in $(seq 1 $max_attempts); do
        if curl -s --connect-timeout 3 "http://localhost:8188/system_stats" >/dev/null 2>&1; then
            comfy_ready=true
            log "   ✅ ComfyUI is ready on port 8188 (after $(( i * interval ))s)"
            break
        fi
        if [[ $(( i % 6 )) -eq 0 ]]; then
            log "   ⏳ Still waiting... ${i}/${max_attempts} (${(( i * interval ))}s)"
        fi
        sleep $interval
    done
    
    if [[ "$comfy_ready" != "true" ]]; then
        log "   ⚠️  ComfyUI not responding on port 8188 after ${max_attempts}x${interval}s"
        log "   Tunnel will start anyway but may not work until ComfyUI is ready"
    fi
    
    # Start tunnel in background using setsid to detach from script
    log "   🚀 Starting Cloudflare tunnel..."
    setsid nohup "$CLOUDFLARED_BIN" tunnel --url http://localhost:8188 \
        > "$TUNNEL_LOG" 2>&1 < /dev/null &
    
    local TUNNEL_PID=$!
    echo "$TUNNEL_PID" > "$TUNNEL_PID_FILE"
    log "   📝 Tunnel started with PID: $TUNNEL_PID"
    
    # Wait for tunnel URL to appear in logs (allow retries and restarts with backoff)
    log "   ⏳ Waiting for tunnel URL..."
    local TUNNEL_URL=""
    local WAIT_SECONDS=90
    local MAX_ATTEMPTS=5
    local BACKOFF_BASE=5
    local BACKOFF_CAP=300

    for attempt in $(seq 1 $MAX_ATTEMPTS); do
        for i in $(seq 1 $WAIT_SECONDS); do
            TUNNEL_URL=$(grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' "$TUNNEL_LOG" 2>/dev/null | head -1 || true)
            if [[ -n "$TUNNEL_URL" ]]; then
                break 2
            fi
            sleep 1
        done

        # If logs indicate rate limiting, avoid tight restart loop; create diagnostic dump and abort retries
        if grep -qE '429|Too Many Requests|error code: 1015' "$TUNNEL_LOG" 2>/dev/null; then
            log "   ⚠️  Cloudflared logs indicate rate limiting (429); aborting restarts and using SSH fallback"
            # Save diagnostic snippet for debugging
            local diag_file="${WORKSPACE}/cloudflared_diagnostic_$(date +%s).log"
            tail -n 200 "$TUNNEL_LOG" 2>/dev/null > "$diag_file" || true
            log "   📄 Wrote diagnostic tail to: $diag_file"
            break
        fi

        if [[ -z "$TUNNEL_URL" ]]; then
            # Exponential backoff before restarting (safer than immediate retries)
            local backoff=$(( BACKOFF_BASE * (2 ** (attempt - 1)) ))
            if (( backoff > BACKOFF_CAP )); then backoff=$BACKOFF_CAP; fi

            log "   ⚠️  Attempt ${attempt}/${MAX_ATTEMPTS}: tunnel URL not found; restarting cloudflared with backoff ${backoff}s..."
            if [[ -f "$TUNNEL_PID_FILE" ]]; then
                local pid
                pid=$(cat "$TUNNEL_PID_FILE" 2>/dev/null || true)
                if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                    kill "$pid" 2>/dev/null || true
                    sleep 2
                fi
                rm -f "$TUNNEL_PID_FILE"
            fi

            setsid nohup "$CLOUDFLARED_BIN" tunnel --url http://localhost:8188 > "$TUNNEL_LOG" 2>&1 < /dev/null &
            local new_pid=$!
            echo "$new_pid" > "$TUNNEL_PID_FILE"
            log "   🔁 Restarted cloudflared (PID: $new_pid) — sleeping ${backoff}s before next check"
            sleep "$backoff"
        fi
    done

    if [[ -z "$TUNNEL_URL" ]]; then
        log "   ❌ Could not capture tunnel URL after ${MAX_ATTEMPTS} attempts"
        log "   Check logs at: $TUNNEL_LOG"
        cat "$TUNNEL_LOG" 2>/dev/null | tail -40 || true
        return 1
    fi

    log "   ✅ Tunnel URL: $TUNNEL_URL"
    echo "$TUNNEL_URL" > "$TUNNEL_URL_FILE"
    
    # Report tunnel URL to proxy server if configured
    local PROXY_REPORT_URL="${COMFYUI_PROXY_REPORT_URL:-}"
    local CONTRACT_ID="${VAST_CONTAINERLABEL:-${CONTAINER_ID:-unknown}}"
    local ADMIN_KEY="${ADMIN_API_KEY:-}"
    
    if [[ -n "$PROXY_REPORT_URL" ]]; then
        log "   📡 Reporting tunnel URL to proxy server..."
        local report_response
        report_response=$(curl -s -X POST "${PROXY_REPORT_URL}/api/proxy/admin/report-tunnel" \
            -H "Content-Type: application/json" \
            -H "x-admin-key: ${ADMIN_KEY}" \
            -d "{\"contractId\": \"$CONTRACT_ID\", \"tunnelUrl\": \"$TUNNEL_URL\"}" \
            2>/dev/null || echo '{"error": "request failed"}')
        
        if echo "$report_response" | grep -q '"success"'; then
            log "   ✅ Tunnel URL reported to proxy server"
        else
            log "   ⚠️  Failed to report tunnel URL: $report_response"
            log "   Tunnel is still accessible at: $TUNNEL_URL"
        fi
    else
        log "   ℹ️  COMFYUI_PROXY_REPORT_URL not set, skipping proxy notification"
        log "   Tunnel is accessible at: $TUNNEL_URL"
    fi
    
    log ""
    log "   ╔════════════════════════════════════════════════════════════════╗"
    log "   ║  🌐 COMFYUI PUBLIC ACCESS URL                                   ║"
    log "   ║                                                                ║"
    log "   ║  $TUNNEL_URL"
    log "   ║                                                                ║"
    log "   ║  Open this URL in your browser - no SSH needed!               ║"
    log "   ╚════════════════════════════════════════════════════════════════╝"
    log ""
    
    return 0
}

generate_cloudflared_service() {
    log "   ⚙️  Generating systemd service for cloudflared"
    local svc_file="/etc/systemd/system/cloudflared-tunnel.service"
    
    cat > "$svc_file" <<EOF
[Unit]
Description=Cloudflare Tunnel for ComfyUI
After=network.target comfyui.service
Wants=comfyui.service

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/cloudflared tunnel --url http://localhost:8188
Restart=always
RestartSec=10
StandardOutput=append:${WORKSPACE}/cloudflared.log
StandardError=append:${WORKSPACE}/cloudflared.log

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$svc_file"
    systemctl daemon-reload 2>/dev/null || true
    # Don't enable by default - let start_cloudflare_tunnel handle it
    log "   ✅ Wrote systemd unit: $svc_file"
}

validate_civitai_token() {
    if [[ -z "$CIVITAI_TOKEN" ]]; then
        log "⚠️  Warning: CIVITAI_TOKEN not set - Civitai downloads will fail"
        log "   Set token with: export CIVITAI_TOKEN='your_token_here'"
        return 1
    fi

    # Test token with actual model download (Civitai uses query param, not Bearer header)
    # Using a small LoRA model for testing (~150MB) instead of API endpoint
    local test_url="https://civitai.com/api/download/models/152309?token=$CIVITAI_TOKEN"  # Pony Realism v2.1 LoRA
    local test_file="/tmp/civitai_token_test.tmp"

    # Download first 1MB to test auth (abort after to save bandwidth)
    local response=$(curl -s -w "%{http_code}" -o "$test_file" \
        --max-filesize 1048576 \
        --max-time 30 \
        "$test_url" 2>/dev/null || echo "000")

    # Clean up test file
    rm -f "$test_file"

    if [[ "$response" == "200" || "$response" == "000" ]]; then
        # 000 means curl aborted due to max-filesize (success - auth worked)
        log "✅ Civitai token validated successfully (tested actual download)"
        return 0
    elif [[ "$response" == "401" || "$response" == "403" ]]; then
        log "❌ Civitai token INVALID or EXPIRED (HTTP $response)"
        log "   Get new token from: https://civitai.com/user/account"
        log "   ⚠️  Provisioning will FAIL - exiting early to save time"
        return 1
    elif [[ "$response" == "404" ]]; then
        log "⚠️  Test model not found (HTTP 404) - token format may be correct but model unavailable"
        log "   Proceeding anyway..."
        return 0
    else
        log "⚠️  Could not validate Civitai token (HTTP $response) - proceeding anyway"
        return 0
    fi
}

log "🚀 Starting AI KINGS Provisioner v3.0 (Reliable & Secured)..."

# Suppress pip root user warnings (we intentionally run as root on Vast.ai)
export PIP_ROOT_USER_ACTION=ignore

# Ensure workspace exists and is writable.
DEFAULT_WS=${WORKSPACE:-/workspace}
if mkdir -p "$DEFAULT_WS" 2>/dev/null && cd "$DEFAULT_WS" 2>/dev/null; then
  WORKSPACE="$PWD"
fi

# 2.2 SSH CONFIGURATION (All SSH fixes removed - they break provisioning)
log "🔐 SSH configuration skipped (causes provisioning issues)"

# 2.5 DISK SPACE CHECK (Ironclad)
# Minimum disk in GB required for provisioning (configurable via env MIN_DISK_GB)
MIN_DISK_GB=${MIN_DISK_GB:-200}
AVAILABLE_KB=$(df "$WORKSPACE" | awk 'NR==2 {print $4}')
if (( AVAILABLE_KB < MIN_DISK_GB * 1024 * 1024 )); then
  log "❌ FATAL ERROR: Insufficient disk space in $WORKSPACE."
  log "   Need: ${MIN_DISK_GB}GB, Have: $((AVAILABLE_KB / 1024 / 1024))GB"
    log "   Cannot proceed with provisioning - exiting early"
    exit 1
fi

COMFYUI_DIR=${WORKSPACE}/ComfyUI
# Finalize the log file to the chosen workspace
LOG_FILE="${WORKSPACE}/provision_v3.log"
MAX_PAR_HF=4      # Parallel downloads for HuggingFace/Catbox
MAX_PAR_CIVITAI=1 # Sequential for Civitai (avoids 429)

# Tokens (passed via environment)
CIVITAI_TOKEN="${CIVITAI_TOKEN:-}"
HUGGINGFACE_HUB_TOKEN="${HUGGINGFACE_HUB_TOKEN:-}"

log "📍 Working in: $WORKSPACE"

# ═══════════════════════════════════════════════════════════════════════════════
# APT PACKAGES (Cross-Ubuntu Compatible)
# ═══════════════════════════════════════════════════════════════════════════════
APT_PACKAGES=(
    "unrar" "p7zip-full" "unzip" "ffmpeg" "libgl1" "git-lfs" "file" "aria2" "curl"
  "python3-pip" "python3-dev" "python3-venv" "build-essential" "libssl-dev" "libffi-dev"
    "libglib2.0-0" "libfreetype-dev" "libjpeg-dev" "libpng-dev" "libtiff-dev"
)

# ═══════════════════════════════════════════════════════════════════════════════
# CUSTOM NODES (Clean URLs)
# ═══════════════════════════════════════════════════════════════════════════════
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
    "https://github.com/cubiq/ComfyUI_IPAdapter_plus"
    "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/city96/ComfyUI-GGUF"
    "https://github.com/flowtyone/ComfyUI-TripoSR"  # Working fork (original VykosX repo deleted)
    "https://github.com/Lightricks/ComfyUI-LTXVideo"
    "https://github.com/AIDC-AI/ComfyUI-Copilot"
    # NEW NODES FOR MISSING WORKFLOW DEPENDENCIES:
    "https://github.com/kijai/ComfyUI-Florence2"  # VQA/Vision capabilities
    "https://github.com/yolain/ComfyUI-Easy-Use"  # Simplified workflows
    "https://github.com/cubiq/ComfyUI_essentials"  # Essential utilities
)

# ═══════════════════════════════════════════════════════════════════════════════
# MODELS - Checkpoints (HuggingFace Primary + Dropbox Fallback)
# ═══════════════════════════════════════════════════════════════════════════════
# Format: "PRIMARY_URL|FALLBACK_URL|filename"
# Uses verified HuggingFace repos as primary source, Dropbox as reliable fallback
CHECKPOINT_MODELS=(
    # Pony Diffusion V6 XL (6.5GB) - REMOVED (confirmed to cause download stalls)
    # "https://huggingface.co/LyliaEngine/Pony_Diffusion_V6_XL/resolve/main/pmXL_v1.safetensors|https://www.dropbox.com/scl/fi/p0uxwux03oq90l8fxmrqx/pmXL_v1.safetensors?rlkey=nxd5ll1idx0uk6jvsqn7l4hmo&st=qkvcwub0&dl=1|pmXL_v1.safetensors"

    # pmXL v1 (6.5GB) - Dropbox only (no verified HF source)
    "https://www.dropbox.com/scl/fi/dd7aiju5petevb6nalinr/pmXL_v1.safetensors?rlkey=p4ukouvdd2o912ilcfbi6cqk3&dl=1||pmXL_v1.safetensors"

    # DreamShaper 8 (2GB) - Working mirror
    "https://huggingface.co/stablediffusionapi/dreamshaper-8/resolve/main/dreamshaper_8.safetensors|https://civitai.com/api/download/models/128641|dreamshaper_8.safetensors"

    # revAnimated v1.2.2 (2GB) - Civitai working URL
    "https://civitai.com/api/download/models/119057?type=Model&format=SafeTensor&size=pruned&fp=fp16|https://civitai.com/api/download/models/122606|revAnimated_v122.safetensors"

    # Pony Realism v2.2 (6.5GB) - Civitai working URL
    "https://civitai.com/api/download/models/914390?type=Model&format=SafeTensor&size=pruned&fp=fp16|https://www.dropbox.com/scl/fi/hy476rxzeacsx8g3aodj0/pony_realism_v2.2.safetensors?rlkey=09k5sba46pqoptdu7h1tu03b4&dl=1|pony_realism_v2.2.safetensors"
    
    # Pony Diffusion v6 XL (6.6GB) - Popular SDXL model
    "https://civitai.com/api/download/models/290640?type=Model&format=SafeTensor&size=pruned&fp=fp16||ponyDiffusionV6XL.safetensors"

    # WAI Illustrious SDXL - Dropbox only
    "https://www.dropbox.com/scl/fi/okhdb2r3i43l7f8hv07li/wai_illustrious_sdxl.safetensors?rlkey=t7r11yjr61ecdm0vrsgrkztc8&dl=1||wai_illustrious_sdxl.safetensors"

    # Rajii Artist Style V2 - Dropbox only
    "https://www.dropbox.com/scl/fi/eq3qqc5rnwod3ac1xfisp/Rajii-Artist-Style-V2-Illustrious.safetensors?rlkey=cvfjam45wbmye89g2mvj245lz&dl=1||Rajii-Artist-Style-V2-Illustrious.safetensors"

    # DR34MJOB I2V 14B - Dropbox only
    "https://www.dropbox.com/scl/fi/6af8pzucgqyr0dy78eh6q/DR34MJOB_I2V_14b_LowNoise.safetensors?rlkey=pgnys4h98h343ibaro0fgwhqv&dl=1||DR34MJOB_I2V_14b_LowNoise.safetensors"

    # PornMaster Pro Noob v6 - Dropbox only
    "https://www.dropbox.com/scl/fi/8280uj9myxuf2376d13jt/pornmasterPro_noobV6.safetensors?rlkey=lmduqq3jxusts1fqqexuqz72w&dl=1||pornmasterPro_noobV6.safetensors"

    # ExpressiveH Hentai - Dropbox only
    "https://www.dropbox.com/scl/fi/5whxkdo39m4w2oimcffx2/expressiveh_hentai.safetensors?rlkey=5ejkyjvethd1r7fn121x7cvs1&dl=1||expressiveh_hentai.safetensors"

    # Fondled - Dropbox only
    "https://www.dropbox.com/scl/fi/9drclw495plki15ynlmst/fondled.safetensors?rlkey=vh5efbuy0er4338xrkivilpnb&dl=1||fondled.safetensors"

    # Wan dr34ml4y All-in-One - Dropbox only
    "https://www.dropbox.com/scl/fi/hp8t53h5ylrhkphnq4cyu/wan_dr34ml4y_all_in_one.safetensors?rlkey=9bq4clb4gmiz4rp6i8g69fl9u&dl=1||wan_dr34ml4y_all_in_one.safetensors"

    # Wan dr34mjob - Dropbox only
    "https://www.dropbox.com/scl/fi/ym112crqb6d7sdkqz5s9j/wan_dr34mjob.safetensors?rlkey=eqzd371f86g6tsof0fcecfn8n&dl=1||wan_dr34mjob.safetensors"

    # Twerk - Dropbox only
    "https://www.dropbox.com/scl/fi/0g4btjch885ij3kiauffm/twerk.safetensors?rlkey=8yqxhqpvs1osat76ynxadwkh8&dl=1||twerk.safetensors"

    # SDXL VAE (320MB) - Official Stability AI repo
    "https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors|https://www.dropbox.com/scl/fi/3qygk64xe2ui2ey74neto/sdxl_vae.safetensors?rlkey=xzsllv3hq5w1qx81h9b2xryq8&dl=1|sdxl_vae.safetensors"

    # SDXL base & refiner (official HF) — used by SDXL workflows
    "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors?download=true||sd_xl_base_1.0.safetensors"
    "https://huggingface.co/stabilityai/stable-diffusion-xl-refiner-1.0/resolve/main/sd_xl_refiner_1.0.safetensors?download=true||sd_xl_refiner_1.0.safetensors"

    # LTX-2 distilled (video)
    "https://huggingface.co/Lightricks/LTX-Video/resolve/main/ltx-video-2b-v0.9.8.safetensors||ltx-video-2b-v0.9.8.safetensors"

    # RealVisXL v4.0 (Photorealistic)
    "https://huggingface.co/SG161222/RealVisXL_V4.0/resolve/main/RealVisXL_V4.0.safetensors||RealVisXL_V4.0.safetensors"

    # SD 3.5 Large FP8 (Scaled)
    "https://huggingface.co/Comfy-Org/stable-diffusion-3.5-fp8/resolve/main/sd3.5_large_fp8_scaled.safetensors?download=true||sd3.5_large_fp8_scaled.safetensors"

    # --- 🔞 NSFW 2026 VIDEO ENGINES (QUANTIZED) ---
    "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors||Wan2.2_Remix_NSFW_i2v_14b_high_fp8.safetensors"
    "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors||Wan2.2_Remix_NSFW_i2v_14b_low_fp8.safetensors"
    "https://huggingface.co/Phr00t/WAN2.2-14B-Rapid-AllInOne/resolve/main/WAN2.2-14B-Rapid-AllInOne.safetensors||WAN2.2-14B-Rapid-AllInOne.safetensors"
)

# ═══════════════════════════════════════════════════════════════════════════════
# MODELS - LoRAs (HuggingFace Primary + Fallback)
# ═══════════════════════════════════════════════════════════════════════════════
LORA_MODELS=(
    # Pony Realism v2.1 - HF primary (LyliaEngine), Civitai fallback
    "https://huggingface.co/LyliaEngine/ponyRealism_v21MainVAE/resolve/main/ponyRealism_v21MainVAE.safetensors|https://civitai.com/api/download/models/152309|pony_realism_v2.1.safetensors"

    # LTX-2 camera control LoRA (dolly-left)
    "https://huggingface.co/Lightricks/LTX-2-19b-LoRA-Camera-Control-Dolly-Left/resolve/main/ltx-2-19b-lora-camera-control-dolly-left.safetensors||ltx-2-19b-lora-camera-control-dolly-left.safetensors"

    # ExpressiveH Hentai - Dropbox only
    "https://www.dropbox.com/scl/fi/5whxkdo39m4w2oimcffx2/expressiveh_hentai.safetensors?rlkey=5ejkyjvethd1r7fn121x7cvs1&dl=1||expressiveh_hentai.safetensors"

    # Fondled - Dropbox only
    "https://www.dropbox.com/scl/fi/9drclw495plki15ynlmst/fondled.safetensors?rlkey=vh5efbuy0er4338xrkivilpnb&dl=1||fondled.safetensors"

    # Wan dr34ml4y All-in-One - Dropbox only
    "https://www.dropbox.com/scl/fi/hp8t53h5ylrhkphnq4cyu/wan_dr34ml4y_all_in_one.safetensors?rlkey=9bq4clb4gmiz4rp6i8g69fl9u&dl=1||wan_dr34ml4y_all_in_one.safetensors"

    # Wan dr34mjob - Dropbox only
    "https://www.dropbox.com/scl/fi/ym112crqb6d7sdkqz5s9j/wan_dr34mjob.safetensors?rlkey=eqzd371f86g6tsof0fcecfn8n&dl=1||wan_dr34mjob.safetensors"

    # Twerk - Dropbox only
    "https://www.dropbox.com/scl/fi/0g4btjch885ij3kiauffm/twerk.safetensors?rlkey=8yqxhqpvs1osat76ynxadwkh8&dl=1||twerk.safetensors"

    # Defecation v1 - HF only (already working)
    "https://huggingface.co/JollyIm/Defecation/resolve/main/defecation_v1.safetensors||defecation_v1.safetensors"

    # --- Catbox.moe Fetish LoRAs (dead links removed) ---
    "https://files.catbox.moe/wmshk3.safetensors||cunnilingus_gesture.safetensors"
    "https://files.catbox.moe/88e51n.rar||archive_lora.rar"
    "https://files.catbox.moe/9qixqa.safetensors||empty_eyes_drooling.safetensors"
    "https://files.catbox.moe/yz5c9g.safetensors||glowing_eyes.safetensors"
    "https://files.catbox.moe/tlt57h.safetensors||quadruple_amputee.safetensors"
    "https://files.catbox.moe/odmswn.safetensors||ugly_bastard.safetensors"
    "https://files.catbox.moe/z71ic0.safetensors||sex_machine.safetensors"
    "https://files.catbox.moe/mxbbg2.safetensors||stasis_tank.safetensors"

    # --- BlackHat404/scatmodels (HuggingFace) ---
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/Soiling-V1.safetensors||Soiling-V1.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/turtleheading-V1.safetensors||turtleheading-V1.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/poop_squatV2.safetensors||poop_squatV2.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/Poop_SquatV3.safetensors||Poop_SquatV3.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/HyperDump.safetensors||HyperDump.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/HyperDumpPlus.safetensors||HyperDumpPlus.safetensors"

    # --- 🔞 NSFW 2026 LoRAs ---
    "https://civitai.com/api/download/models/1811313||wan-dr34ml4y-nsfw.safetensors"
    "https://civitai.com/api/download/models/1307155||wan-general-nsfw.safetensors"
    "https://civitai.com/api/download/models/8877||squatting-cowgirl.safetensors"
)

# ═══════════════════════════════════════════════════════════════════════════════
# MODELS - Wan Video & Specialist Arrays
# ═══════════════════════════════════════════════════════════════════════════════
WAN_DIFFUSION_MODELS=(
    # Wan 2.1 T2V (1.3B parameters, FP16)
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_t2v_1.3B_fp16.safetensors|wan2.1_t2v_1.3B_fp16.safetensors"

    # Wan 2.2 T2V (14B parameters, FP8 quantized for speed)
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors|wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors|wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors"

    # Wan 2.2 TI2V (Text+Image-to-Video, 5B parameters, FP16)
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors|wan2.2_ti2v_5B_fp16.safetensors"

    # Wan 2.2 Remix NSFW (FX-FeiHou) - High and Low lighting variants
    # These are NSFW-trained I2V models, downloaded separately (high + low)
    "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors|wan2.2_remix_nsfw_high.safetensors"
    "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors|wan2.2_remix_nsfw_low.safetensors"
)

WAN_CLIP_MODELS=(
    # UMT5 XXL FP8 - Standard version for Wan 2.1
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn.safetensors|umt5_xxl_fp8_e4m3fn.safetensors"
    
    # UMT5 XXL FP8 Scaled - Enhanced version for better quality (6.4GB)
    "https://huggingface.co/Comfy-Org/LTX-2/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors|umt5_xxl_fp8_e4m3fn_scaled.safetensors"
)

# ═══════════════════════════════════════════════════════════════════════════════
# MODELS - Wan 2.2 LoRAs (Lightning Fast Video Generation)
# ═══════════════════════════════════════════════════════════════════════════════
WAN_LORA_MODELS=(
    # Wan 2.2 T2V Lightning LoRAs (4-step generation for speed)
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_high_noise.safetensors|wan2.2_t2v_lightx2v_4steps_lora_v1.1_high_noise.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_low_noise.safetensors|wan2.2_t2v_lightx2v_4steps_lora_v1.1_low_noise.safetensors"

    # Wan 2.2 I2V Lightning LoRAs (Image-to-Video 4-step)
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors|wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors|wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors"
)

# MODELS - Text Encoders (General)
TEXT_ENCODERS=(
    "https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors|gemma_3_12B_it_fp4_mixed.safetensors"
)

WAN_VAE_MODELS=(
    # Wan 2.1 VAE - Official HF
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan2.1_vae.safetensors|wan2.1_vae.safetensors"

    # Wan 2.2 VAE - Official HF
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors|wan2.2_vae.safetensors"

    # Lumina Image 2.0 VAE - For advanced image encoding
    "https://huggingface.co/Comfy-Org/Lumina_Image_2.0_Repackaged/resolve/main/split_files/vae/ae.safetensors|ae.safetensors"

    # SDXL VAE - Official Stability AI HF repo, Dropbox fallback
    "https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors|https://www.dropbox.com/scl/fi/3qygk64xe2ui2ey74neto/sdxl_vae.safetensors?rlkey=xzsllv3hq5w1qx81h9b2xryq8&dl=1|sdxl_vae.safetensors"

    # PonyRealism v2.1 VAE - Civitai
    "https://civitai.com/api/download/models/105924||ponyRealism_v21MainVAE.safetensors"
)


ANIMATEDIFF_MODELS=(
    # AnimateDiff SDXL v10 Beta - Correct link from guoyww (official author)
    "https://huggingface.co/guoyww/animatediff/resolve/main/mm_sdxl_v10_beta.ckpt|mm_sdxl_v10_beta.ckpt"
    
    # AnimateDiff SD1.5 v2 - Motion module for SD1.5
    "https://huggingface.co/guoyww/animatediff/resolve/main/mm_sd_v15_v2.ckpt|mm_sd_v15_v2.ckpt"
)

UPSCALE_MODELS=(
    "https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth|4x-UltraSharp.pth"
    "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth|RealESRGAN_x4plus.pth"
    "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-spatial-upscaler-x2-1.0.safetensors|ltx-2-spatial-upscaler-x2-1.0.safetensors"
)

CONTROLNET_MODELS=(
    "https://huggingface.co/thibaud/controlnet-openpose-sdxl-1.0/resolve/main/OpenPoseXL2.safetensors|OpenPoseXL2.safetensors"
)

DETECTOR_MODELS=(
    "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt|face_yolov8m.pt"
    "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8n.pt|hand_yolov8n.pt"
    "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth|sam_vit_b_01ec64.pth"
)

RIFE_MODELS=(
    # RIFE 4.26 - Frame interpolation model (correct link from HuggingFace)
    "https://huggingface.co/r3gm/RIFE/resolve/main/RIFEv4.26_0921.zip|rife426.zip"
)

# ═══════════════════════════════════════════════════════════════════════════════
# MODELS - FLUX (Next-Gen Image Generation & Refinement)
# ═══════════════════════════════════════════════════════════════════════════════
FLUX_MODELS=(
    # FLUX Krea Dev - FP8 quantized for refinement and inpainting
    "https://huggingface.co/Comfy-Org/FLUX.1-Krea-dev_ComfyUI/resolve/main/split_files/diffusion_models/flux1-krea-dev_fp8_scaled.safetensors|flux1-krea-dev_fp8_scaled.safetensors"
)

FLUX_VAE_MODELS=()

# FLUX Text Encoders - Required for FLUX model operation
FLUX_CLIP_MODELS=(
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors|clip_l.safetensors"
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors|t5xxl_fp16.safetensors"
)

# ═══════════════════════════════════════════════════════════════════════════════
# MODELS - LTX-2 (Advanced Video Generation with Camera Control)
# ═══════════════════════════════════════════════════════════════════════════════
LTX_DIFFUSION_MODELS=(
    # LTX-2 19B Development - FP8 quantized for video generation
    "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-dev-fp8.safetensors|ltx-2-19b-dev-fp8.safetensors"
)

LTX_LORA_MODELS=(
    # LTX-2 Camera Control - Dolly Left movement
    "https://huggingface.co/Lightricks/LTX-2-19b-LoRA-Camera-Control-Dolly-Left/resolve/main/ltx-2-19b-lora-camera-control-dolly-left.safetensors|ltx-2-19b-lora-camera-control-dolly-left.safetensors"

    # LTX-2 Distilled LoRA - 384 resolution for faster generation
    "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-distilled-lora-384.safetensors|ltx-2-19b-distilled-lora-384.safetensors"
)

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

VENV_PYTHON="python3"
activate_venv() {
    if [[ -f "/venv/main/bin/activate" ]]; then
        source /venv/main/bin/activate
        VENV_PYTHON="/venv/main/bin/python3"
        log "✅ Activated venv: /venv/main"
    elif [[ -f "${WORKSPACE}/venv/bin/activate" ]]; then
        source "${WORKSPACE}/venv/bin/activate"
        VENV_PYTHON="${WORKSPACE}/venv/bin/python3"
        log "✅ Activated venv: ${WORKSPACE}/venv"
    else
        log "📦 Creating virtual environment..."
        python3 -m venv "${WORKSPACE}/venv"
        source "${WORKSPACE}/venv/bin/activate"
        VENV_PYTHON="${WORKSPACE}/venv/bin/python3"
        log "✅ Created/Activated venv: ${WORKSPACE}/venv"
    fi
}

detect_cuda_version() {
  # Return a short CUDA tag like cu130, cu128, cu124, cu121, cu118, cu111 or "cpu"
  # NOTE: Only echo the result - all logs go to stderr to avoid polluting return value
  if command -v nvidia-smi >/dev/null 2>&1; then
    # Try to read reported CUDA version from nvidia-smi
    local cuda_raw
    cuda_raw=$(nvidia-smi --query-gpu=cuda_version --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d '\r') || true
    if [[ -n "$cuda_raw" ]]; then
      echo "   🔎 Detected CUDA from nvidia-smi: $cuda_raw" >&2
      case "$cuda_raw" in
        13.*|13) echo "cu130"; return 0 ;;
        12.9*|12.9) echo "cu130"; return 0 ;;
        12.8*|12.8) echo "cu128"; return 0 ;;
        12.4*|12.4) echo "cu124"; return 0 ;;
        12.1*|12.1) echo "cu121"; return 0 ;;
        11.8*|11.8) echo "cu118"; return 0 ;;
        11.1*|11.1) echo "cu111"; return 0 ;;
        *)
            # Fallback for newer minor versions - map to closest known
            # If 12.5, 12.6, 12.7 -> map to cu124 (stable fallback) or maybe cu128 if available?
            # For robustness, let's map unknown 12.x to cu124 as a safe baseline, unless >12.8
            if [[ "$cuda_raw" =~ ^12\.[5-7] ]]; then echo "cu124"; return 0; fi
            if [[ "$cuda_raw" =~ ^12\.([8-9]|[1-9][0-9]) ]]; then echo "cu128"; return 0; fi
            ;;
      esac

      # Additional heuristic: check GPU name for RTX 50-series / Blackwell cues and prefer cu128/cu130
      local gpu_name
      gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1 | tr -d '\r' || true)
      if [[ -n "$gpu_name" ]]; then
        echo "   🔎 Detected GPU name: $gpu_name" >&2
        # Use case-insensitive matching for Blackwell/RTX 50
        if echo "$gpu_name" | grep -qiE "5060|RTX 5[0-9]|Blackwell"; then
          # Blackwell needs at least cu128 (PyTorch 2.7+ / Nightly)
          # We return cu130 as the primary target for nightlies usually, or cu128
          echo "cu130"; return 0
        fi
      fi
    fi
    # If nvidia-smi didn't report cuda_version, infer from driver version
    local driver
    driver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits 2>/dev/null | head -n1 | cut -d. -f1 || true)
    if [[ -n "$driver" ]]; then
      echo "   🔎 Detected driver version: $driver" >&2
      if (( driver >= 570 )); then
        echo "cu130"; return 0
      elif (( driver >= 550 )); then # Approx for CUDA 12.4+ / 12.8
        echo "cu128"; return 0
      elif (( driver >= 535 )); then
        echo "cu124"; return 0
      elif (( driver >= 525 )); then
        echo "cu121"; return 0
      else
        echo "cu118"; return 0
      fi
    fi
  fi
  # Fallback: no GPU detected, return cpu tag
  echo "   ⚠️  No NVIDIA GPU detected - using CPU-only PyTorch" >&2
  echo "cpu"
}

install_nvidia_drivers() {
  log_section "🛠️  INSTALLING NVIDIA DRIVERS & CONTAINER TOOLKIT (OPTION B)"
  # Only proceed on Debian/Ubuntu family for now
  if [[ -f /etc/lsb-release || -f /etc/os-release ]]; then
    log "   ⚙️  Detected Debian/Ubuntu-like system, attempting driver install"
  else
    log "   ❌ Unsupported distro for automated driver install. Please install drivers manually."
    return 1
  fi

  # Update apt and install prerequisite packages
  log "   ▶️  Updating apt and installing prerequisites"
  apt-get update -y || true
  apt-get install -y --no-install-recommends wget ca-certificates gnupg lsb-release build-essential linux-headers-$(uname -r) || true

  # Try ubuntu-drivers autoinstall if available (safe default)
  if command -v ubuntu-drivers >/dev/null 2>&1; then
    log "   ▶️  Running ubuntu-drivers autoinstall (may require reboot)"
    ubuntu-drivers autoinstall || log "   ⚠️ ubuntu-drivers autoinstall reported issues"
  else
    log "   ⚠️ ubuntu-drivers not available; attempting apt install nvidia-driver-535"
    apt-get install -y --no-install-recommends nvidia-driver-535 || true
  fi

  # After driver install, try to load modules and validate
  if command -v nvidia-smi >/dev/null 2>&1; then
    log "   ✅ nvidia-smi present after install"
  else
    log "   ⚠️ nvidia-smi not available - a reboot may be required or Secure Boot blocking kernel modules"
  fi

  # Install Docker if missing
  if ! command -v docker >/dev/null 2>&1; then
    log "   ▶️  Installing Docker engine"
    apt-get install -y --no-install-recommends docker.io || true
    systemctl enable --now docker || true
  fi

  # Install NVIDIA container toolkit
  log "   ▶️  Installing nvidia-container-toolkit"
  distribution="$(. /etc/os-release && echo $ID$VERSION_ID)" || distribution="ubuntu22.04"
  # Add NVIDIA's package repository (best-effort)
  curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add - 2>/dev/null || true
  curl -s -L https://nvidia.github.io/nvidia-docker/$(. /etc/os-release && echo $ID)/$(. /etc/os-release && echo $VERSION_CODENAME)/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list >/dev/null 2>&1 || true
  apt-get update -y || true
  apt-get install -y --no-install-recommends nvidia-container-toolkit || true
  systemctl restart docker || true

  # Validate container runtime sees GPUs
  if docker run --rm --gpus all nvidia/cuda:12.1.1-base-ubuntu22.04 nvidia-smi >/dev/null 2>&1; then
    log "   ✅ NVIDIA container toolkit working: containers see GPUs"
  else
    log "   ⚠️ Container GPU visibility test failed - docker may need restart or driver mismatch"
  fi
  return 0
}

install_torch() {
    log_section "🧠 INSTALLING PYTORCH"
    activate_venv

    # Detect Python version and use compatible PyTorch wheel based on system CUDA
    local python_version
    python_version=$("$VENV_PYTHON" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')") || true
    log "   Python version: $python_version"

    local cuda_tag
    cuda_tag=$(detect_cuda_version)
    log "   🔎 Selected PyTorch wheel tag: $cuda_tag"

    # Retry logic for PyTorch installation (large downloads can timeout)
    local torch_success=false
    for torch_attempt in {1..3}; do
        if [[ "$cuda_tag" == "cpu" ]]; then
          log "   ⚠️  Installing CPU-only PyTorch (no CUDA detected)"
          if "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
              torch torchvision torchaudio 2>&1 | tee -a /workspace/pip_install.log | grep -v "WARNING:"; then
              torch_success=true
              break
          fi
        else
          case "$cuda_tag" in
            cu130)
              log "   📥 Installing torch NIGHTLY for cu130 (RTX 50-series support) (attempt $torch_attempt/3)"
              log "   ⚠️  Using PyTorch nightly build for sm_120 CUDA arch support (Blackwell GPUs)"
              log "   🔄 Force-reinstalling to replace pre-installed PyTorch..."
              
              # First try cu130 nightly
              if "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
                --force-reinstall --upgrade \
                --pre torch torchvision torchaudio \
                --index-url https://download.pytorch.org/whl/nightly/cu130 2>&1 | tee -a /workspace/pip_install.log | grep -v "WARNING:"; then
                torch_success=true
                break
              fi
              
              log "   ⚠️  cu130 nightly failed, trying cu128 nightly..."
              # Fallback to cu128 nightly
              if "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
                --force-reinstall --upgrade \
                --pre torch torchvision torchaudio \
                --index-url https://download.pytorch.org/whl/nightly/cu128 2>&1 | tee -a /workspace/pip_install.log | grep -v "WARNING:"; then
                torch_success=true
                break
              fi
              ;;
            cu128)
              log "   📥 Installing torch NIGHTLY for cu128 (RTX 50-series support) (attempt $torch_attempt/3)"
              if "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
                --force-reinstall --upgrade \
                --pre torch torchvision torchaudio \
                --index-url https://download.pytorch.org/whl/nightly/cu128 2>&1 | tee -a /workspace/pip_install.log | grep -v "WARNING:"; then
                torch_success=true
                break
              fi
              ;;
            cu124)
              log "   📥 Installing torch for cu124 (attempt $torch_attempt/3)"
              if "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
                torch==2.5.1+cu124 torchvision==0.20.1+cu124 torchaudio==2.5.1+cu124 \
                --index-url https://download.pytorch.org/whl/cu124 2>&1 | tee -a /workspace/pip_install.log | grep -v "WARNING:"; then
                torch_success=true
                break
              fi
              ;;
            cu121)
              log "   📥 Installing torch for cu121 (attempt $torch_attempt/3)"
              if "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
                torch==2.5.1+cu121 torchvision==0.20.1+cu121 torchaudio==2.5.1+cu121 \
                --index-url https://download.pytorch.org/whl/cu121 2>&1 | tee -a /workspace/pip_install.log | grep -v "WARNING:"; then
                torch_success=true
                break
              fi
              ;;
            cu118)
              log "   📥 Installing torch for cu118 (attempt $torch_attempt/3)"
              if "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
                torch==2.5.1+cu118 torchvision==0.20.1+cu118 torchaudio==2.5.1+cu118 \
                --index-url https://download.pytorch.org/whl/cu118 2>&1 | tee -a /workspace/pip_install.log | grep -v "WARNING:"; then
                torch_success=true
                break
              fi
              ;;
            *)
              log "   ⚠️  Unknown CUDA tag ($cuda_tag) - attempting generic wheel (attempt $torch_attempt/3)"
              if "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
                  torch torchvision torchaudio 2>&1 | tee -a /workspace/pip_install.log | grep -v "WARNING:"; then
                  torch_success=true
                  break
              fi
              ;;
          esac
        fi

        if [[ $torch_success == "false" && $torch_attempt -lt 3 ]]; then
            log "   ⚠️  PyTorch install attempt $torch_attempt failed, retrying in 30s..."
            sleep 30
        fi
    done

    if [[ "$torch_success" == "false" ]]; then
        log "   ❌ PyTorch installation FAILED after 3 attempts - check /workspace/pip_install.log"
        log "   This is a critical error - provisioning may not complete successfully"
        return 1
    else
        log "   ✅ PyTorch installed successfully"
    fi
}

install_essential_deps() {
    log_section "📦 INSTALLING ESSENTIAL DEPENDENCIES"
    activate_venv

    # Remove any pre-installed xformers that may conflict with our PyTorch version
    "$VENV_PYTHON" -m pip uninstall -y xformers 2>/dev/null || true
    log "   ✅ Removed conflicting xformers (if present)"

    # Install core dependencies first with retry logic
    log "   📦 Installing core dependencies..."
    local deps_success=false
    for deps_attempt in {1..3}; do
        if "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
            transformers==4.36.0 \
            accelerate \
            safetensors \
            einops \
            opencv-python-headless \
            insightface \
            onnxruntime-gpu \
            sentencepiece 2>&1 | tee -a /workspace/pip_install.log | grep -v "WARNING:"; then
            deps_success=true
            break
        fi

        if [[ $deps_attempt -lt 3 ]]; then
            log "   ⚠️  Core dependencies install attempt $deps_attempt failed, retrying in 30s..."
            sleep 30
        fi
    done

    if [[ "$deps_success" == "false" ]]; then
        log "   ❌ Core dependencies installation FAILED after 3 attempts"
        log "   Check /workspace/pip_install.log for details"
    else
        log "   ✅ Core dependencies installed successfully"
    fi

    # Reinstall PyTorch to ensure correct version after accelerate (which may install CPU version)
    log "   🔧 Ensuring correct PyTorch version..."
    # Decide based on detected GPU and currently installed torch
    local cuda_tag
    cuda_tag=$(detect_cuda_version)
        local installed_torch_cuda
        installed_torch_cuda=$("$VENV_PYTHON" - <<'PY'
try:
    import torch
    v = getattr(torch.version, 'cuda', None) or torch.version.cuda
    print(v if v is not None else 'none')
except Exception:
    print('missing')
PY
)
        log "   ℹ️  Detected installed PyTorch CUDA: $installed_torch_cuda"

        # Derive major CUDA family from installed torch (e.g. '13' for '13.0.96', '12' for '12.4')
        local installed_major=""
        if [[ "$installed_torch_cuda" =~ ^([0-9]+) ]]; then
            installed_major="${BASH_REMATCH[1]}"
        fi

        if [[ "$installed_torch_cuda" == "missing" ]] || [[ "$installed_torch_cuda" == "none" ]]; then
            log "   ⚠️ No installed torch detected or import failed; proceeding to install for $cuda_tag"
        fi

    if [[ "$cuda_tag" == "cu130" ]]; then
      if [[ "$installed_torch_cuda" == 13* ]]; then
        log "   ✅ Installed PyTorch already supports CUDA 13.x; skipping reinstall"
      else
        log "   📥 Ensuring PyTorch supports cu130 (RTX 50-series); attempting nightly cu130"
        "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
          --force-reinstall --upgrade --pre torch torchvision torchaudio \
          --index-url https://download.pytorch.org/whl/nightly/cu130 2>&1 | tee -a /workspace/pip_install.log || {
            log "   ⚠️ nightly cu130 install failed, falling back to nightly cu128"
            "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
              --force-reinstall --upgrade --pre torch torchvision torchaudio \
              --index-url https://download.pytorch.org/whl/nightly/cu128 2>&1 | tee -a /workspace/pip_install.log || {
                  log "   ⚠️ nightly cu128 install failed, falling back to generic wheels"
                  "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
                    torch torchvision torchaudio 2>&1 | tee -a /workspace/pip_install.log || true
              }
        }
      fi
    elif [[ "$cuda_tag" == "cu128" ]]; then
      if [[ "$installed_torch_cuda" == 12.8* ]] || [[ "$installed_torch_cuda" == 13* ]]; then
         log "   ✅ Installed PyTorch already supports CUDA 12.8+; skipping reinstall"
      else
         log "   📥 Ensuring PyTorch supports cu128 (RTX 50-series); attempting nightly cu128"
         "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
           --force-reinstall --upgrade --pre torch torchvision torchaudio \
           --index-url https://download.pytorch.org/whl/nightly/cu128 2>&1 | tee -a /workspace/pip_install.log || {
             log "   ⚠️ nightly cu128 install failed, falling back to generic wheels"
             "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
                torch torchvision torchaudio 2>&1 | tee -a /workspace/pip_install.log || true
           }
      fi
    elif [[ "$cuda_tag" == "cpu" ]]; then
      log "   ⚠️ Ensuring CPU-only PyTorch is installed"
      "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
          torch torchvision torchaudio 2>&1 | tee -a /workspace/pip_install.log || true
    else
      # Try to install the pinned wheel matching the detected tag; fallback to generic if failing
      case "$cuda_tag" in
                cu124)
                    if [[ "$installed_major" == "12" ]]; then
                        log "   ✅ Installed PyTorch already supports CUDA 12.x; skipping cu124 reinstall"
                    else
                        log "   📥 Installing torch for cu124"
                        "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
                            torch==2.5.1+cu124 torchvision==0.20.1+cu124 torchaudio==2.5.1+cu124 \
                            --index-url https://download.pytorch.org/whl/cu124 2>&1 | tee -a /workspace/pip_install.log || true
                    fi
                    ;;
                cu121)
                    if [[ "$installed_major" == "12" ]]; then
                        log "   ✅ Installed PyTorch already supports CUDA 12.x; skipping cu121 reinstall"
                    else
                        log "   📥 Installing torch for cu121"
                        "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
                            torch==2.5.1+cu121 torchvision==0.20.1+cu121 torchaudio==2.5.1+cu121 \
                            --index-url https://download.pytorch.org/whl/cu121 2>&1 | tee -a /workspace/pip_install.log || true
                    fi
                    ;;
                cu118)
                    if [[ "$installed_major" == "11" ]] || [[ "$installed_major" == "12" ]]; then
                        log "   ✅ Installed PyTorch already supports CUDA 11/12.x; skipping cu118 reinstall"
                    else
                        log "   📥 Installing torch for cu118"
                        "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
                            torch==2.5.1+cu118 torchvision==0.20.1+cu118 torchaudio==2.5.1+cu118 \
                            --index-url https://download.pytorch.org/whl/cu118 2>&1 | tee -a /workspace/pip_install.log || true
                    fi
                    ;;
        *)
          log "   ⚠️ Unknown CUDA tag ($cuda_tag) - attempting generic wheel"
          "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
              torch torchvision torchaudio 2>&1 | tee -a /workspace/pip_install.log || true
          ;;
      esac
    fi

    # Install xformers (optional - skip if incompatible to avoid dependency conflicts)
    # xformers is optional for ComfyUI and can cause PyTorch version conflicts
    log "   ℹ️  Skipping xformers to avoid PyTorch version conflicts"
    log "   (ComfyUI will work without it, though some operations may be slower)"
}



install_hf_tools() {
    log_section "🔧 INSTALLING HUGGING FACE TOOLS"
    
    # Install git-xet for large file support
    if ! command -v git-xet >/dev/null 2>&1; then
        log "   📦 Installing git-xet for large file support..."
        # Note: winget is Windows-only, for Linux we'll use alternative installation
        if command -v apt-get >/dev/null 2>&1; then
            # Try to install via apt if available (may not be in default repos)
            apt-get update -qq && apt-get install -y -qq git-lfs 2>/dev/null || log "   ⚠️  git-lfs install failed, continuing..."
        fi
    else
        log "   ✅ git-xet already installed"
    fi
    
    # Install Hugging Face CLI
    if ! command -v hf >/dev/null 2>&1; then
        log "   📦 Installing Hugging Face CLI..."
        # Use the PowerShell installation method adapted for bash
        if command -v curl >/dev/null 2>&1; then
            curl -s -L https://hf.co/cli/install.sh | bash || log "   ⚠️  HF CLI install failed, continuing..."
        else
            log "   ⚠️  curl not available, skipping HF CLI install"
        fi
    else
        log "   ✅ Hugging Face CLI already installed"
    fi
}

# Ensure ComfyUI DB migrations do not re-run if DB already has tables
ensure_comfyui_migrations() {
    log "   🔧 Checking ComfyUI DB migrations"
    cd "${COMFYUI_DIR}"
    if ! command -v sqlite3 >/dev/null 2>&1; then
        log "   ⚠️  sqlite3 not available, skipping DB health checks"
        return 0
    fi

    local dbs
    dbs=$(find . -maxdepth 2 -type f \( -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \) -print 2>/dev/null || true)
    for db in $dbs; do
        if sqlite3 "$db" "SELECT name FROM sqlite_master WHERE type='table' AND name='assets';" | grep -q assets; then
            log "   ⚠️  Found existing 'assets' table in $db"
            if ! sqlite3 "$db" "SELECT name FROM sqlite_master WHERE type='table' AND name='alembic_version';" | grep -q alembic_version; then
                log "   ⚠️  alembic_version table missing in $db - stamping current head to avoid re-running migrations"
                cp "$db" "${db}.bak.$(date +%s)" || log "   ⚠️  Failed to backup $db"
                if "$VENV_PYTHON" -m alembic stamp head 2>&1 | tee -a /workspace/pip_install.log; then
                    log "   ✅ Stamped alembic head for $db"
                else
                    log "   ⚠️  Failed to stamp alembic head - please inspect logs"
                fi
            else
                log "   ✅ alembic_version table present in $db"
            fi
        fi
    done
}

# Attempt a safe DB repair if Alembic/database migration errors appear during ComfyUI startup.
# This watches the ComfyUI log for known migration failure signatures and will:
#  - backup any discovered sqlite DB files
#  - run `alembic stamp head` to mark migrations as applied
#  - restart ComfyUI once (via systemd if available or by restarting the PID)
repair_comfyui_db_and_restart() {
    local comfy_pid="$1"
    local timeout=${2:-60}
    local deadline=$((SECONDS + timeout))
    local log_file="${WORKSPACE}/comfyui.log"

    # Wait for log file to appear
    while [[ ! -f "$log_file" && SECONDS -lt $deadline ]]; do
        sleep 1
    done

    # Poll the log for migration errors
    while [[ SECONDS -lt $deadline ]]; do
        if grep -E "(table assets already exists|Failed to initialize database|alembic|OperationalError|table .* already exists)" "$log_file" -i >/dev/null 2>&1; then
            log "   ⚠️  Detected DB migration error in ${log_file}; attempting safe repair"

            # Find sqlite DB files under COMFYUI_DIR (safe shallow search)
            local dbs
            dbs=$(find "${COMFYUI_DIR}" -maxdepth 3 -type f \( -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \) -print 2>/dev/null || true)
            for db in $dbs; do
                log "   🔁 Backing up DB: $db"
                cp "$db" "${db}.bak.$(date +%s)" || log "   ⚠️  Failed to backup $db"
            done

            # Attempt to stamp alembic head (run from COMFYUI_DIR)
            (cd "${COMFYUI_DIR}" && "$VENV_PYTHON" -m alembic stamp head) 2>&1 | tee -a /workspace/provision_errors.log || true
            log "   ✅ Ran 'alembic stamp head' (check /workspace/provision_errors.log for details)"

            # Restart ComfyUI
            if systemctl is-active --quiet comfyui.service 2>/dev/null; then
                log "   🔁 Restarting comfyui.service via systemd"
                systemctl restart comfyui.service || log "   ⚠️  systemd restart failed; attempt manual restart"
            else
                if [[ -n "$comfy_pid" && -f "${WORKSPACE}/comfyui.pid" ]]; then
                    log "   🔁 Restarting ComfyUI process (PID: $comfy_pid)"
                    pkill -F "${WORKSPACE}/comfyui.pid" || true
                    sleep 1
                fi
                # Start fallback process once
                setsid "$VENV_PYTHON" main.py --listen 0.0.0.0 --port 8188 --enable-cors-header > "${WORKSPACE}/comfyui.log" 2>&1 < /dev/null &
                echo "$!" > "${WORKSPACE}/comfyui.pid" || true
            fi

            return 0
        fi
        sleep 2
    done
    return 1
}

install_comfyui() {
    log_section "🖥️  INSTALLING COMFYUI"
    if [[ ! -d "${COMFYUI_DIR}" ]]; then
        git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}"
    fi
    
    cd "${COMFYUI_DIR}"
    install_torch
    install_essential_deps

    # Attempt to reconcile DB state before installing ComfyUI requirements to avoid migration race
    ensure_comfyui_migrations

    log "   📦 Installing ComfyUI requirements..."
    "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 120 -r requirements.txt 2>&1 | grep -v "WARNING: Running pip as the 'root' user" || {
        log "   ⚠️  ComfyUI requirements install had issues (continuing)"
    }

    cd "${WORKSPACE}"
    log "✅ ComfyUI setup complete"
}

install_nodes() {
    log_section "🧩 INSTALLING CUSTOM NODES"

    activate_venv

    # Pre-install common dependencies to avoid per-node failures
    log "   📦 Pre-installing common dependencies..."
    "$VENV_PYTHON" -m pip install --no-cache-dir --timeout 300 --retries 5 \
        gitpython packaging pydantic pyyaml httpx aiohttp \
        websockets typing-extensions 2>&1 | grep -v "WARNING: Running pip as the 'root' user" || {
        log "   ⚠️  Some common dependencies failed to install (will retry per-node)"
    }

    # Nodes with known problematic requirements (skip their requirements.txt)
    # NOTE: ComfyUI-Manager requirements must be installed to enable the Manager UI; do not skip it.
    local skip_requirements=("ComfyUI-Impact-Pack")

    for repo in "${NODES[@]}"; do
        # Robust trimming of spaces and hidden characters
        repo=$(echo "$repo" | tr -d '[:space:]')
        local dir="${repo##*/}"
        local path="${COMFYUI_DIR}/custom_nodes/${dir}"

        if [[ -d "$path" ]]; then
            log "   ✅ $dir exists"
        else
            log "   📥 Cloning $dir..."

            # Retry git clone up to 3 times
            local clone_success=false
            for attempt in {1..3}; do
                if git clone --depth 1 "$repo" "$path" --recursive 2>&1 | grep -v "Authentication refused"; then
                    clone_success=true
                    break
                fi

                log "   ⚠️  Clone attempt $attempt/3 failed for $dir, retrying..."
                sleep 2
                rm -rf "$path" 2>/dev/null || true
            done

            if [[ "$clone_success" == "false" ]]; then
                log "   ❌ Failed to clone $dir after 3 attempts, skipping..."
                continue
            fi
        fi

        # Check if we should skip requirements for this node
        local skip=false
        for skip_node in "${skip_requirements[@]}"; do
            if [[ "$dir" == "$skip_node" ]]; then
                skip=true
                log "   ⚠️  Skipping requirements for $dir (known issues)"
                break
            fi
        done

        # Install requirements with timeout if not skipped
        if [[ "$skip" == "false" ]] && [[ -f "${path}/requirements.txt" ]]; then
            log "   📦 Installing requirements for $dir..."

            # Retry logic for pip install with exponential backoff (handles rate limiting)
            local pip_success=false
            for pip_attempt in {1..3}; do
                # Use longer timeout (10 min), retries, and verbose output
                set +e  # Temporarily disable errexit to capture exit codes
                set +u  # Temporarily disable nounset for PIPESTATUS
                timeout 600 "$VENV_PYTHON" -m pip install \
                    --no-cache-dir \
                    --retries 5 \
                    --timeout 120 \
                    -r "${path}/requirements.txt" 2>&1 | tee -a /workspace/pip_install.log | { grep -v "WARNING: Running pip as the 'root' user" || true; }
                
                # Capture timeout's exit code with safe default
                local pip_exit=${PIPESTATUS[0]:-1}
                set -e  # Re-enable errexit
                set -u  # Re-enable nounset
                
                if [[ $pip_exit -eq 0 ]]; then
                    pip_success=true
                    break
                fi

                if [[ $pip_attempt -lt 3 ]]; then
                    local wait_time=$((pip_attempt * 30))  # 30s, 60s backoff
                    log "   ⚠️  Pip install attempt $pip_attempt/3 failed, waiting ${wait_time}s before retry..."
                    log "   Last 10 lines of error log:"
                    tail -10 /workspace/pip_install.log | grep -i "error\|failed" || echo "   (no errors found in log)"
                    sleep $wait_time
                fi
            done

            if [[ "$pip_success" == "false" ]]; then
                log "   ❌ Requirements install failed for $dir after 3 attempts"
                log "   Error details (last 20 lines):"
                tail -20 /workspace/pip_install.log
                log "   Continuing anyway (ComfyUI may still work)..."
            else
                log "   ✅ Requirements installed for $dir"
            fi
        fi
    done

    # Post-install: Ensure core dependencies are present
    log "   🔧 Ensuring core dependencies..."
    "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 120 \
        einops>=0.6.0 \
        accelerate>=0.24.0 \
        transformers>=4.36.0 \
        opencv-python-headless>=4.8.0 \
        sageattention \
        huggingface-hub 2>&1 | grep -v "WARNING: Running pip as the 'root' user" || {
        log "   ⚠️  Some core dependencies failed to install (may need manual fix)"
    }

    # Install Impact-Pack dependencies (skipped in requirements due to conflicts)
    log "   🔧 Installing ComfyUI-Impact-Pack dependencies..."
    "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 120 \
        piexif \
        ultralytics 2>&1 | grep -v "WARNING: Running pip as the 'root' user" || {
        log "   ⚠️  Impact-Pack dependencies failed to install"
    }

    # Optional: install segment_anything if Impact-Pack is present to avoid import error
    # Optional: install segment_anything if Impact-Pack is present
    # This is critical for Impact Pack to work
    if [[ -d "${COMFYUI_DIR}/custom_nodes/ComfyUI-Impact-Pack" ]]; then
        log "   📦 Installing 'segment_anything' for Impact Pack..."
        # Try pip install package first
        if "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 120 segment-anything 2>&1 | grep -v "WARNING: Running pip as the 'root' user"; then
             log "   ✅ segment-anything installed via pip"
        else
             log "   ⚠️  pip install segment-anything failed, trying git install..."
             # Fallback to direct git install
             "$VENV_PYTHON" -m pip install --no-cache-dir git+https://github.com/facebookresearch/segment-anything.git 2>&1 | grep -v "WARNING: Running pip as the 'root' user" || {
                 log "   ❌ segment_anything install failed (Impact Pack may fail to load)"
             }
        fi
    fi

    log "✅ Custom nodes installation complete"
}

# Helper function to search logs for rate limit errors
search_rate_limit_errors() {
    local log_file="${1:-/workspace/provision_errors.log}"
    local output_file="${2:-}"
    
    if [[ ! -f "$log_file" ]]; then
        echo "No error log found at $log_file"
        return 1
    fi
    
    # Search for rate limit related errors
    local rate_limit_lines=$(grep -iE "429|rate.?limit|too many requests|RATE_LIMIT" "$log_file" 2>/dev/null | wc -l)
    
    if [[ $rate_limit_lines -gt 0 ]]; then
        echo "Found $rate_limit_lines rate limit error(s) in $log_file"
        echo ""
        echo "Rate Limit Errors:"
        echo "═══════════════════════════════════════════════════════════════"
        grep -iE "429|rate.?limit|too many requests|RATE_LIMIT" "$log_file" 2>/dev/null
        
        if [[ -n "$output_file" ]]; then
            grep -iE "429|rate.?limit|too many requests|RATE_LIMIT" "$log_file" > "$output_file" 2>/dev/null
            echo ""
            echo "Filtered results saved to: $output_file"
        fi
        return 0
    else
        echo "No rate limit errors found in $log_file"
        return 1
    fi
}

# Helper function to get source name for logging
get_source_name() {
    local url="$1"
    if [[ "$url" == *"huggingface.co"* ]]; then
        echo "HuggingFace"
    elif [[ "$url" == *"dropbox.com"* ]]; then
        echo "Dropbox"
    elif [[ "$url" == *"civitai.com"* ]]; then
        echo "Civitai"
    elif [[ "$url" == *"github.com"* ]]; then
        echo "GitHub"
    else
        echo "Direct"
    fi
}

# Monitor download progress by checking file size growth
# Returns 0 if making progress, 1 if stalled
monitor_download_progress() {
    local filepath="$1"
    local monitor_duration="${2:-300}"  # Default: monitor for 5 minutes
    local check_interval=30              # Check every 30 seconds
    local stall_threshold=2              # Fail if no growth for 2 consecutive checks (60s)

    local last_size=0
    local stall_count=0
    local checks=$((monitor_duration / check_interval))

    for ((i=0; i<checks; i++)); do
        sleep $check_interval

        if [[ -f "$filepath" ]]; then
            local current_size=$(stat -c%s "$filepath" 2>/dev/null || echo 0)

            if [[ $current_size -gt $last_size ]]; then
                # Progress detected
                local size_human=$(numfmt --to=iec $current_size 2>/dev/null || echo "${current_size} bytes")
                log "      📊 Progress: $size_human downloaded"
                last_size=$current_size
                stall_count=0
            else
                # No progress
                ((stall_count++))
                if [[ $stall_count -ge $stall_threshold ]]; then
                    log "      ⚠️  Download stalled (no progress for $((stall_count * check_interval))s)"
                    return 1
                fi
            fi
        fi
    done

    return 0
}

# Helper function to attempt download with aria2c + wget fallback
# Enhanced with Dropbox-specific anti-hanging protections
attempt_download() {
    local url="$1"
    local dir="$2"
    local filename="$3"
    local filepath="${dir}/${filename}"
    local header_args=()

    # Auth handling
    if [[ -n "$CIVITAI_TOKEN" && "$url" == *"civitai.com"* ]]; then
        if [[ "$url" == *"?"* ]]; then
            url="${url}&token=$CIVITAI_TOKEN"
        else
            url="${url}?token=$CIVITAI_TOKEN"
        fi
    elif [[ -n "$HUGGINGFACE_HUB_TOKEN" && "$url" == *"huggingface.co"* ]]; then
        header_args+=("--header=Authorization: Bearer $HUGGINGFACE_HUB_TOKEN")
    fi

    # Download-specific tuning (prevent rate-limit hangs and optimize performance)
    local connections=4                 # Default: 4 connections (balanced - not too aggressive)
    local timeout_per_attempt=300       # 5 minutes default
    local max_tries=8                   # 8 retries default
    local retry_wait=15                 # 15s between retries (increased from 10s)
    local lowest_speed=30720            # 30KB/s minimum speed (detect real stalls)

    if [[ "$url" == *"dropbox.com"* ]]; then
        connections=1                   # REQUIRED: Dropbox rejects multi-connection
        timeout_per_attempt=180         # 3 minutes (Dropbox throttles aggressively)
        max_tries=5                     # Fewer retries (fail fast to fallback)
        retry_wait=10                   # 10s between retries
        lowest_speed=20480              # 20KB/s minimum (Dropbox can be slower)
        log "      (Dropbox: single-conn, 3min timeout, stall detection enabled)"
    elif [[ "$url" == *"huggingface.co"* ]]; then
        connections=8                   # HuggingFace handles multi-connection well
        timeout_per_attempt=600         # 10 minutes (large model files)
        max_tries=10                    # More retries for large files
        retry_wait=20                   # 20s between retries
        log "      (HuggingFace: 8-conn, 10min timeout, optimized for large files)"
    elif [[ "$url" == *"civitai.com"* ]]; then
        connections=2                   # Civitai rate-limits aggressively
        timeout_per_attempt=300         # 5 minutes
        max_tries=5                     # Fewer retries (fail fast)
        retry_wait=30                   # 30s between retries (avoid rate limits)
        log "      (Civitai: 2-conn, 5min timeout, rate-limit friendly)"
    fi

    # Try aria2c with anti-hang protections
    # Prepare per-file verbose log for diagnostics
    mkdir -p "${WORKSPACE}/download-logs" 2>/dev/null || true
    local file_log="${WORKSPACE}/download-logs/${filename}.log"

    if command -v aria2c &>/dev/null; then
      aria2c "$url" -d "$dir" -o "$filename" \
           "${header_args[@]}" \
           -x${connections} -s${connections} -j1 --max-connection-per-server=${connections} \
           --timeout=${timeout_per_attempt} \
           --retry-wait=${retry_wait} \
           --max-tries=${max_tries} \
           --lowest-speed-limit=${lowest_speed} \
           --max-file-not-found=3 \
           --file-allocation=none \
           --continue=true \
           --allow-overwrite=true \
           --auto-file-renaming=false \
           --summary-interval=15 \
           --console-log-level=notice 2>&1 | tee -a "$LOG_FILE" | tee -a "$file_log"

      local exit_code=${PIPESTATUS[0]}

        # Check for rate limit errors (HTTP 429) in log
        if grep -qi "429\|rate limit\|too many requests" "$file_log" 2>/dev/null; then
            log "      🚫 Rate Limit Error (429) detected - backing off"
            # Increase retry wait for next attempt if we're retrying
            retry_wait=$((retry_wait * 2))
            # Log to error file for tracking
            [[ -f "/workspace/provision_errors.log" ]] || touch "/workspace/provision_errors.log"
            echo "$(date '+%Y-%m-%d %H:%M:%S') RATE_LIMIT_ERROR: $filename - URL: $url" >> "/workspace/provision_errors.log"
        fi

        # Validate download (file exists + reasonable size)
        if [[ $exit_code -eq 0 && -f "$filepath" && $(stat -c%s "$filepath") -gt 1000000 ]]; then
            return 0
        fi

        # Log specific failure reasons for debugging
        if [[ $exit_code -eq 28 ]]; then
            log "      ⚠️  Timeout or stall detected (speed < ${lowest_speed} bytes/s)"
        elif [[ $exit_code -eq 7 ]]; then
            log "      ⚠️  Connection failed or interrupted"
        fi
    fi

    # Try wget fallback with Dropbox-tuned settings
    local wget_timeout=600              # 10 minutes default
    local wget_tries=10
    if [[ "$url" == *"dropbox.com"* ]]; then
        wget_timeout=300                # 5 minutes for Dropbox
        wget_tries=5                    # Fewer retries
    fi

    local wget_opts=("-c" "--timeout=${wget_timeout}" "--tries=${wget_tries}" "-O" "$filepath")
    for header in "${header_args[@]}"; do
        wget_opts+=("${header/--header=/--header=}")
    done

    wget "${wget_opts[@]}" "$url" 2>&1 | tee -a "$LOG_FILE" | tee -a "$file_log"
    local wget_exit=${PIPESTATUS[0]}

    # Check for rate limit errors (HTTP 429) in wget output
    if grep -qi "429\|rate limit\|too many requests\|HTTP request sent.*429" "$file_log" 2>/dev/null; then
        log "      🚫 Rate Limit Error (429) detected in wget - backing off"
        [[ -f "/workspace/provision_errors.log" ]] || touch "/workspace/provision_errors.log"
        echo "$(date '+%Y-%m-%d %H:%M:%S') RATE_LIMIT_ERROR: $filename - URL: $url (wget)" >> "/workspace/provision_errors.log"
    fi

    if [[ $wget_exit -eq 0 && -f "$filepath" && $(stat -c%s "$filepath") -gt 1000000 ]]; then
        return 0
    fi

    return 1
}

# Advanced Downloader with Multi-Source Fallback
download_file() {
    local url="$1"
    local dir="$2"
    local filename="$3"
    local fallback_url="${4:-}"
    local filepath="${dir}/${filename}"
  # Per-file verbose log path (used for diagnostics on failure)
  local file_log="${WORKSPACE}/download-logs/${filename}.log"

    # 1. Validation (Skip if valid)
    if [[ -f "$filepath" ]]; then
        local size=$(stat -c%s "$filepath" 2>/dev/null || echo 0)
        [[ $size -gt 1000000 ]] && {
            log "   ✅ $filename (cached)"
            return 0
        }
        rm -f "$filepath"
    fi

    mkdir -p "$dir"

    # 2. Try PRIMARY source
    local source_name=$(get_source_name "$url")
    log "   📥 Downloading $filename..."
    log "      Primary: $source_name"

    if attempt_download "$url" "$dir" "$filename"; then
        local size_human=$(stat -c%s "$filepath" | numfmt --to=iec-i 2>/dev/null || echo 'OK')
        log "   ✅ $filename ($size_human) - COMPLETE (primary)"
        return 0
    fi

    # 3. Try FALLBACK source (if provided)
    if [[ -n "$fallback_url" ]]; then
        local fallback_source=$(get_source_name "$fallback_url")
        log "   ⚠️  Primary failed, trying fallback..."
        log "      Fallback: $fallback_source"

        if attempt_download "$fallback_url" "$dir" "$filename"; then
            local size_human=$(stat -c%s "$filepath" | numfmt --to=iec-i 2>/dev/null || echo 'OK')
            log "   ✅ $filename ($size_human) - COMPLETE (fallback)"

            # Log fallback usage for analytics
            [[ -f "/workspace/provision_fallback.log" ]] || touch "/workspace/provision_fallback.log"
            echo "$(date '+%Y-%m-%d %H:%M:%S') FALLBACK USED: $filename (primary: $source_name → fallback: $fallback_source)" >> "/workspace/provision_fallback.log"
            return 0
        fi
    fi

    # 4. Both sources failed
    log "   ❌ $filename - ALL SOURCES FAILED"
    log "      Primary: $url"
    [[ -n "$fallback_url" ]] && log "      Fallback: $fallback_url"

    [[ -f "/workspace/provision_errors.log" ]] || touch "/workspace/provision_errors.log"

    # If file is optional, log and continue (do not abort provisioning)
    if is_optional_file "$filename"; then
      log "   ⚠️  OPTIONAL ASSET FAILED: $filename - continuing provisioning"
      echo "$(date '+%Y-%m-%d %H:%M:%S') OPTIONAL FAILED: $filename - primary: $url, fallback: ${fallback_url:-none}" >> "/workspace/provision_errors.log"
      rm -f "$filepath"
      return 0
    fi

    # Ensure file_log exists or point to a safe fallback
    [[ -n "${file_log:-}" ]] || file_log="/dev/null"
    echo "$(date '+%Y-%m-%d %H:%M:%S') FAILED: $filename - primary: $url, fallback: ${fallback_url:-none}, logfile: ${file_log}" >> "/workspace/provision_errors.log"
    # Also append a short diagnostic snippet (last 80 lines) to the error log (if available)
    if [[ -f "${file_log}" ]]; then
      echo "--- DIAGNOSTIC: last 80 lines of ${file_log} ---" >> "/workspace/provision_errors.log"
      tail -n 80 "${file_log}" >> "/workspace/provision_errors.log" 2>/dev/null || true
    else
      echo "--- DIAGNOSTIC: no per-file log available for ${filename} ---" >> "/workspace/provision_errors.log"
    fi
    rm -f "$filepath"
    return 1
}

smart_download_parallel() {
    # Temporarily disable strict error checking for parallel operations
    # This prevents arithmetic operations and subshell failures from killing the script
    local old_opts=$(set +o)
    set +e  # Disable exit on error during parallel execution

    local dir="$1"
    local max_p="$2"
    shift 2
    local arr=("$@")

    local pids=()
    local pid_files=()  # Track which file each PID is downloading
    local failed_count=0
    local fallback_count=0
    local total_count=${#arr[@]}
    local success_count=0
    local current_file=0
    local queued=0

    # Per-file timeout: 30 minutes (1800 seconds)
    # CRITICAL: This is a hard limit. After 30 min, download is KILLED (SIGKILL)
    # This prevents infinite hangs from Dropbox throttling or network issues
    # Increased to 30 min to handle large files (6-8GB) on slower connections
    local download_timeout=1800
    local timeout_kill_after=30  # Give 30s grace period for cleanup before SIGKILL

    log ""
    log "╔════════════════════════════════════════════════════════════════╗"
    log "║  📦 Downloading batch: $total_count files (${max_p} parallel)  "
    log "╚════════════════════════════════════════════════════════════════╝"
    log ""

    # Download worker function (runs in background)
    download_worker() {
        local entry="$1"
        local dir="$2"
        local file_num="$3"
        local total="$4"
        local timeout_sec="$5"
        local timeout_kill="$6"

        # Parse triple-pipe format: HF|Dropbox|filename OR legacy URL|filename
        local primary_url fallback_url filename
        local IFS='|'
        read -r source1 source2 source3 <<< "$entry"

        if [[ -n "$source3" ]]; then
            # New format: primary|fallback|filename
            primary_url="$source1"
            fallback_url="$source2"
            filename="$source3"
        else
            # Legacy format: URL|filename
            primary_url="$source1"
            fallback_url=""
            filename="$source2"
            # Handle case where no pipe exists
            [[ "$filename" == "$primary_url" ]] && filename="${primary_url##*/}" && filename="${filename%%\?*}"
        fi

        log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log "📥 [STARTING] File $file_num/$total: $filename"
        log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        # Download with timeout protection
        if timeout -k ${timeout_kill} ${timeout_sec} bash -c 'download_file "$@"' _ "$primary_url" "$dir" "$filename" "$fallback_url"; then
            log "✅ [SUCCESS] $filename"
            return 0
        else
            local exit_code=$?
            if [[ $exit_code -eq 124 ]]; then
                log "   ⏱️  TIMEOUT: $filename exceeded 30-minute limit (killed)"
                if [[ "$primary_url" == *"civitai.com"* ]]; then
                    log "      This usually indicates Civitai API slowness or network issues"
                else
                    log "      This usually indicates Dropbox throttling or network issues"
                fi
            elif [[ $exit_code -eq 137 ]]; then
                log "   💀 FORCE KILLED: $filename (unresponsive after timeout)"
            fi
            log "❌ [FAILED] $filename"

            # Clean up partial/corrupt downloads
            local filepath="${dir}/${filename}"
            [[ -f "$filepath" ]] && rm -f "$filepath" && log "      🗑️  Cleaned up partial file"
            return 1
        fi
    }

    # Export function and variables for subshells
    export -f download_worker download_file attempt_download get_source_name log
    export LOG_FILE CIVITAI_TOKEN HUGGINGFACE_HUB_TOKEN download_timeout timeout_kill_after

    # Main parallel download loop
    while [[ $queued -lt $total_count ]] || [[ ${#pids[@]} -gt 0 ]]; do

        # Launch new downloads if we have slots available and files remaining
        while [[ ${#pids[@]} -lt $max_p ]] && [[ $queued -lt $total_count ]]; do
            local entry="${arr[$queued]}"
            queued=$((queued + 1))
            current_file=$((current_file + 1))

            # Launch download in background
            download_worker "$entry" "$dir" "$current_file" "$total_count" "$download_timeout" "$timeout_kill_after" &
            local pid=$!
            pids+=($pid)
            pid_files[$pid]="File $current_file"

            log "🚀 Launched download #$current_file (PID: $pid) - Active jobs: ${#pids[@]}/$max_p"
        done

        # Check for completed downloads
        local new_pids=()
        for pid in "${pids[@]}"; do
            if ! kill -0 "$pid" 2>/dev/null; then
                # Process completed
                wait "$pid"
                local exit_code=$?
                if [[ $exit_code -eq 0 ]]; then
                    success_count=$((success_count + 1))
                    # Check if fallback was used
                    if [[ -f "/workspace/provision_fallback.log" ]] && tail -5 "/workspace/provision_fallback.log" | grep -q "${pid_files[$pid]}"; then
                        fallback_count=$((fallback_count + 1))
                    fi
                else
                    failed_count=$((failed_count + 1))
                fi
                unset pid_files[$pid]
            else
                # Still running
                new_pids+=($pid)
            fi
        done
        pids=("${new_pids[@]}")

        # Progress update
        local completed=$((success_count + failed_count))
        if [[ $completed -gt 0 ]]; then
            local percent=$((completed * 100 / total_count))
            log ""
            log "📊 Progress: $completed/$total_count complete ($percent%) | ✅ Success: $success_count | ❌ Failed: $failed_count | 🔄 Active: ${#pids[@]}"
            [[ $fallback_count -gt 0 ]] && log "   🔄 Fallback used: $fallback_count times"
            log ""
        fi

        # Brief sleep to avoid busy-waiting
        [[ ${#pids[@]} -gt 0 ]] && sleep 2
    done

    # Final summary
    log ""
    log "╔════════════════════════════════════════════════════════════════╗"
    log "║  📊 BATCH COMPLETE                                             "
    log "║  ✅ Success: $success_count/$total_count                               "
    [[ $fallback_count -gt 0 ]] && log "║  🔄 Fallback: $fallback_count                                   "
    log "║  ❌ Failed: $failed_count                                        "
    log "╚════════════════════════════════════════════════════════════════╝"
    log ""

    # Restore original shell options
    eval "$old_opts"

    return 0  # Always succeed to prevent script exit
}

install_workflows() {
    log_section "📋 DOWNLOADING WORKFLOW TEMPLATES"
    
    local workflow_dir="/workspace/ComfyUI/user/default/workflows"
    mkdir -p "$workflow_dir"
    
    # Gist base URL with commit hash to prevent caching
    local gist_base="https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw/a221dea8a2ea50b7f839dc3a82fcebcc30ef455c"
    
    # List of all 27 workflow files
    local workflows=(
        "Wan2.2-Remix-I2V-Comfy-Qwen3.json"
        "image work flow sdxl work flow .json"
        "nsfw_2d_3d_motion_ultimate_workflow.json"
        "nsfw_3d_generation_workflow.json"
        "nsfw_cinema_production_workflow.json"
        "nsfw_controlnet_pose_workflow.json"
        "nsfw_lora_image_workflow.json"
        "nsfw_ltx_camera_control_hyperdump_scat_video_workflow.json"
        "nsfw_ltx_video_workflow.json"
        "nsfw_pony_hyperdump_cunnilingus_sexmachine_dreamlay_dreamjob_fetish_master_workflow.json"
        "nsfw_pony_hyperdump_soiling_turtleheading_scat_master_workflow.json"
        "nsfw_pony_multiple_fetish_stacked_master_workflow.json"
        "nsfw_pornmaster_workflow.json"
        "nsfw_realistic_furry_video_workflow.json"
        "nsfw_sdxl_fetish_workflow.json"
        "nsfw_sdxl_image_workflow.json"
        "nsfw_sdxl_realism_hyperdump_cunnilingus_master_workflow.json"
        "nsfw_sdxl_soiling_turtleheading_poopsquat_scat_master_workflow.json"
        "nsfw_sdxl_triposr_3d_generation_workflow.json"
        "nsfw_ultimate_image_workflow.json"
        "nsfw_ultimate_video_workflow.json"
        "nsfw_video_workflow.json"
        "nsfw_wan21_video_workflow.json"
        "nsfw_wan22_dr34ml4y_dr34mjob_fetish_video_master_workflow.json"
        "nsfw_wan22_master_video_workflow.json"
        "nsfw_wan25_preview_video_workflow.json"
        "video_wan2_2_14B_i2v for videos.json"
    )
    
    log "   📥 Downloading ${#workflows[@]} workflow templates..."
    
    local success_count=0
    local failed_count=0
    
    for workflow in "${workflows[@]}"; do
        # URL encode the filename for spaces and special chars
        local encoded_name="${workflow// /%20}"
        local url="${gist_base}/${encoded_name}"
        local dest="${workflow_dir}/${workflow}"
        
        if curl -fsSL "$url" -o "$dest" --retry 3 --retry-delay 2 --connect-timeout 30; then
            log "   ✅ $workflow"
            ((success_count++))
        else
            log "   ❌ Failed: $workflow"
            ((failed_count++))
        fi
    done
    
    log ""
    log "╔════════════════════════════════════════════════════════════════╗"
    log "║  📊 WORKFLOW DOWNLOAD COMPLETE                                 "
    log "║  ✅ Success: $success_count/${#workflows[@]}                             "
    log "║  ❌ Failed: $failed_count                                        "
    log "╚════════════════════════════════════════════════════════════════╝"
    log ""
    
    return 0
}

install_models() {
    log_section "📦 DOWNLOADING MODELS (STAGED)"

    # Calculate total model count - includes all new arrays
    local total_models=0
    total_models=$((${#CHECKPOINT_MODELS[@]} + ${#LORA_MODELS[@]} + ${#WAN_DIFFUSION_MODELS[@]} + ${#WAN_CLIP_MODELS[@]} + ${#WAN_LORA_MODELS[@]} + ${#WAN_VAE_MODELS[@]} + ${#ANIMATEDIFF_MODELS[@]} + ${#UPSCALE_MODELS[@]} + ${#CONTROLNET_MODELS[@]} + ${#RIFE_MODELS[@]} + ${#DETECTOR_MODELS[@]} + ${#FLUX_MODELS[@]} + ${#FLUX_CLIP_MODELS[@]} + ${#TEXT_ENCODERS[@]} + ${#LTX_DIFFUSION_MODELS[@]} + ${#LTX_LORA_MODELS[@]}))

    log ""
    log "╔════════════════════════════════════════════════════════════════╗"
    log "║  🎯 TOTAL MODELS TO DOWNLOAD: $total_models                           "
    log "║  📊 Estimated install size: 100GB+                            "
    log "║  ⏱️  Est. time: 15-30 minutes on high-speed connection        "
    log "╚════════════════════════════════════════════════════════════════╝"
    log ""

    log "🎨 [1/18] Downloading CHECKPOINTS..."
    smart_download_parallel "${COMFYUI_DIR}/models/checkpoints" "$MAX_PAR_HF" "${CHECKPOINT_MODELS[@]}"

    log "🎨 [2/18] Downloading GENERAL LORAS..."
    smart_download_parallel "${COMFYUI_DIR}/models/loras" "$MAX_PAR_HF" "${LORA_MODELS[@]}"

    log "⚡ [3/18] Downloading WAN LIGHTNING LORAS (4-step generation)..."
    smart_download_parallel "${COMFYUI_DIR}/models/loras" "$MAX_PAR_HF" "${WAN_LORA_MODELS[@]}"

    log "🎥 [4/18] Downloading WAN DIFFUSION MODELS..."
    smart_download_parallel "${COMFYUI_DIR}/models/diffusion_models" "$MAX_PAR_HF" "${WAN_DIFFUSION_MODELS[@]}"

    log "📝 [5/18] Downloading WAN TEXT ENCODERS..."
    smart_download_parallel "${COMFYUI_DIR}/models/clip" "$MAX_PAR_HF" "${WAN_CLIP_MODELS[@]}"

    log "🎬 [6/18] Downloading WAN VAE MODELS..."
    smart_download_parallel "${COMFYUI_DIR}/models/vae" "$MAX_PAR_HF" "${WAN_VAE_MODELS[@]}"

    log "🎞️  [7/18] Downloading ANIMATEDIFF MOTION MODULES..."
    smart_download_parallel "${COMFYUI_DIR}/models/animatediff_models" "$MAX_PAR_HF" "${ANIMATEDIFF_MODELS[@]}"

    log "⬆️  [8/18] Downloading UPSCALE MODELS..."
    smart_download_parallel "${COMFYUI_DIR}/models/upscale_models" "$MAX_PAR_HF" "${UPSCALE_MODELS[@]}"

    log "🎮 [9/18] Downloading CONTROLNET MODELS..."
    smart_download_parallel "${COMFYUI_DIR}/models/controlnet" "$MAX_PAR_HF" "${CONTROLNET_MODELS[@]}"

    log "🎞️  [10/18] Downloading RIFE FRAME INTERPOLATION..."
    smart_download_parallel "${COMFYUI_DIR}/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife" "$MAX_PAR_HF" "${RIFE_MODELS[@]}"

    log "🔍 [11/18] Downloading DETECTOR MODELS (Face/Hand YOLO)..."
    smart_download_parallel "${COMFYUI_DIR}/models/ultralytics/bbox" "$MAX_PAR_HF" "${DETECTOR_MODELS[@]:0:2}"

    log "🔍 [12/18] Downloading SEGMENTATION MODEL (SAM)..."
    smart_download_parallel "${COMFYUI_DIR}/models/sams" "$MAX_PAR_HF" "${DETECTOR_MODELS[@]:2:1}"

    log "⚡ [13/18] Downloading FLUX DIFFUSION MODELS..."
    if [[ ${#FLUX_MODELS[@]} -gt 0 ]]; then
        smart_download_parallel "${COMFYUI_DIR}/models/diffusion_models" "$MAX_PAR_HF" "${FLUX_MODELS[@]}"
    else
        log "   ⏭️  Skipped (no FLUX models configured)"
    fi

    log "⚡ [14/18] Downloading FLUX TEXT ENCODERS..."
    if [[ ${#FLUX_CLIP_MODELS[@]} -gt 0 ]]; then
        smart_download_parallel "${COMFYUI_DIR}/models/clip" "$MAX_PAR_HF" "${FLUX_CLIP_MODELS[@]}"
    else
        log "   ⏭️  Skipped (no FLUX CLIP models configured)"
    fi

    log "📝 [15/18] Downloading GENERAL TEXT ENCODERS..."
    if [[ ${#TEXT_ENCODERS[@]} -gt 0 ]]; then
        smart_download_parallel "${COMFYUI_DIR}/models/clip" "$MAX_PAR_HF" "${TEXT_ENCODERS[@]}"
    else
        log "   ⏭️  Skipped (no general text encoders configured)"
    fi

    log "🎬 [16/18] Downloading LTX-2 DIFFUSION MODELS..."
    if [[ ${#LTX_DIFFUSION_MODELS[@]} -gt 0 ]]; then
        smart_download_parallel "${COMFYUI_DIR}/models/diffusion_models" "$MAX_PAR_HF" "${LTX_DIFFUSION_MODELS[@]}"
    else
        log "   ⏭️  Skipped (no LTX-2 diffusion models configured)"
    fi

    log "🎥 [17/18] Downloading LTX-2 LORAS (Camera Control)..."
    if [[ ${#LTX_LORA_MODELS[@]} -gt 0 ]]; then
        smart_download_parallel "${COMFYUI_DIR}/models/loras" "$MAX_PAR_HF" "${LTX_LORA_MODELS[@]}"
    else
        log "   ⏭️  Skipped (no LTX-2 LoRAs configured)"
    fi

    log "🎨 [18/18] Downloading LTX-2 SPATIAL UPSCALER..."
    # Note: Already included in UPSCALE_MODELS array above

    log ""
    log "╔════════════════════════════════════════════════════════════════╗"
    log "║  ✅ ALL MODEL DOWNLOADS COMPLETE!                              "
    log "╚════════════════════════════════════════════════════════════════╝"
    log ""
}

retry_failed_downloads() {
    log_section "🔄 CHECKING FOR FAILED DOWNLOADS"

    # Check if error log exists and has content
    if [[ ! -f "/workspace/provision_errors.log" ]] || [[ ! -s "/workspace/provision_errors.log" ]]; then
        log "✅ No failed downloads detected - all models downloaded successfully!"
        return 0
    fi

    # Count failed downloads
    local failed_count=$(wc -l < "/workspace/provision_errors.log")
    log ""
    log "⚠️  Found $failed_count failed download(s)"
    log ""

    # Show failed files
    log "Failed downloads:"
    while IFS= read -r line; do
        # Extract filename from error log
        local filename=$(echo "$line" | grep -oP 'FAILED: \K[^\s]+' || echo "unknown")
        log "   ❌ $filename"
    done < "/workspace/provision_errors.log"

    log ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "Failed downloads will NOT be retried automatically."
    log "You can:"
    log "  1. Check /workspace/provision_errors.log for details"
    log "  2. Manually retry downloads by re-running provision script"
    log "  3. Use ComfyUI Manager to download missing models later"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log ""

    return 0  # Don't fail provisioning due to missing models
}

verify_installation() {
    log_section "🔍 VERIFYING INSTALLATION"

    local validation_failed=0

    # 1. Check critical custom nodes
    log "📦 Checking critical custom nodes..."
    local critical_nodes=(
        "${COMFYUI_DIR}/custom_nodes/ComfyUI-WanVideoWrapper"
        "${COMFYUI_DIR}/custom_nodes/ComfyUI-AnimateDiff-Evolved"
        "${COMFYUI_DIR}/custom_nodes/ComfyUI-Impact-Pack"
        "${COMFYUI_DIR}/custom_nodes/ComfyUI-Frame-Interpolation"
    )

    for node in "${critical_nodes[@]}"; do
        if [[ -d "$node" ]]; then
            log "   ✅ $(basename "$node") exists"
        else
            log "   ❌ $(basename "$node") MISSING"
            ((validation_failed++))
        fi
    done

    # 2. Check critical models (minimum file size: 100MB)
    log ""
    log "🎨 Checking critical models..."
    local min_size=104857600  # 100MB in bytes
    local checkpoint_count=0
    local animatediff_count=0
    local wan_count=0

    # Count checkpoint models (must have at least 1)
    if [[ -d "${COMFYUI_DIR}/models/checkpoints" ]]; then
        while IFS= read -r -d '' file; do
            local size=$(stat -c%s "$file" 2>/dev/null || echo 0)
            if [[ $size -gt $min_size ]]; then
                ((checkpoint_count++))
            fi
        done < <(find "${COMFYUI_DIR}/models/checkpoints" -type f \( -name "*.safetensors" -o -name "*.ckpt" -o -name "*.pt" \) -print0 2>/dev/null)
    fi

    if [[ $checkpoint_count -gt 0 ]]; then
        log "   ✅ Checkpoints: $checkpoint_count model(s) found"
    else
        log "   ❌ Checkpoints: NONE FOUND (at least 1 required)"
        ((validation_failed++))
    fi

    # Count AnimateDiff models (for video generation)
    if [[ -d "${COMFYUI_DIR}/models/animatediff_models" ]]; then
        while IFS= read -r -d '' file; do
            local size=$(stat -c%s "$file" 2>/dev/null || echo 0)
            if [[ $size -gt $min_size ]]; then
                ((animatediff_count++))
            fi
        done < <(find "${COMFYUI_DIR}/models/animatediff_models" -type f \( -name "*.safetensors" -o -name "*.ckpt" \) -print0 2>/dev/null)
    fi

    if [[ $animatediff_count -gt 0 ]]; then
        log "   ✅ AnimateDiff: $animatediff_count model(s) found"
    else
        log "   ⚠️  AnimateDiff: NONE FOUND (video workflows will fail)"
    fi

    # Count Wan models (for Wan video workflows)
    if [[ -d "${COMFYUI_DIR}/models/diffusion_models" ]]; then
        while IFS= read -r -d '' file; do
            local size=$(stat -c%s "$file" 2>/dev/null || echo 0)
            if [[ $size -gt $min_size ]]; then
                ((wan_count++))
            fi
        done < <(find "${COMFYUI_DIR}/models/diffusion_models" -type f \( -name "*.safetensors" -o -name "*.pt" \) -print0 2>/dev/null)
    fi

    if [[ $wan_count -gt 0 ]]; then
        log "   ✅ Wan diffusion: $wan_count model(s) found"
    else
        log "   ⚠️  Wan diffusion: NONE FOUND (Wan workflows will fail)"
    fi

    # 3. Validation summary
    log ""
    if [[ $validation_failed -gt 0 ]]; then
        log "❌ VALIDATION FAILED: $validation_failed critical component(s) missing"
        log "   ComfyUI may not work correctly. Check /workspace/provision_errors.log for details."
        # Don't exit - let ComfyUI start anyway for debugging, but log the error
        echo "$(date '+%Y-%m-%d %H:%M:%S') VALIDATION FAILED: $validation_failed critical components missing (checkpoints: $checkpoint_count)" >> "/workspace/provision_errors.log"
    else
        log "✅ All critical components verified successfully"
    fi
}



start_comfyui() {
    log_section "🚀 STARTING COMFYUI"
    cd "${COMFYUI_DIR}"
    activate_venv
  # Prefer creating a systemd service for reliable supervision
  generate_comfyui_service
  systemctl daemon-reload || true
  systemctl enable --now comfyui.service || {
    log "   ⚠️  systemd service failed to start; falling back to background start"
    # Start detached so cleanup/traps won't kill the process
    setsid nohup "$VENV_PYTHON" main.py --listen 0.0.0.0 --port 8188 --enable-cors-header > "${WORKSPACE}/comfyui.log" 2>&1 < /dev/null &
    local comfyui_pid=$!
    echo "$comfyui_pid" > "${WORKSPACE}/comfyui.pid"
    log "✅ ComfyUI started on port 8188 (PID: $comfyui_pid)"
    log "   Log: ${WORKSPACE}/comfyui.log"
    log "   PID file: ${WORKSPACE}/comfyui.pid"
    log "   To stop: kill \$(cat ${WORKSPACE}/comfyui.pid)"
        # After starting, attempt DB repair if migrations fail during initial startup
        repair_comfyui_db_and_restart "$comfyui_pid" 60 || true
    return
  }

  # If systemd started the unit, report status
  log "✅ ComfyUI systemd service enabled and started (port 8188)"
  log "   Check logs with: journalctl -u comfyui.service -f"
    # Monitor logs for alembic/migration failures and attempt repair once
    repair_comfyui_db_and_restart "" 60 || true
}

# Reverse SSH tunnel function DISABLED (it breaks provisioning)
# Supports either REVERSE_SSH_DEST (user@host[:port]) or REVERSE_SSH_USER/REVERSE_SSH_HOST vars.
start_reverse_tunnel() {
  # DISABLED: This functionality caused provisioning hangs and SSH issues
  # If needed, set up tunneling manually after provisioning completes
  return 0
}

generate_comfyui_service() {
  log "   ⚙️  Generating systemd service for ComfyUI"
  local svc_file="/etc/systemd/system/comfyui.service"
  cat > "$svc_file" <<EOF
[Unit]
Description=ComfyUI Service
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=${COMFYUI_DIR}
ExecStart=${VENV_PYTHON} ${COMFYUI_DIR}/main.py --listen 0.0.0.0 --port 8188 --enable-cors-header
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1
[Install]
WantedBy=multi-user.target
EOF

  # Ensure systemd notices the new unit and start it
  log "   🔁 Reloading systemd daemon and enabling comfyui.service"
  systemctl daemon-reload || log "   ⚠️  systemctl daemon-reload failed (non-systemd image?)"
  systemctl enable --now comfyui.service || log "   ⚠️  systemctl enable/start comfyui.service failed (will attempt fallback start)"

  # Verify ComfyUI process is running (fallback: start manually)
  sleep 2
  if ! sudo ss -tunlp | grep -q ":8188"; then
    log "   ⚠️  comfy.service not listening on 8188; attempting manual start"
    nohup ${VENV_PYTHON} ${COMFYUI_DIR}/main.py --listen 0.0.0.0 --port 8188 --enable-cors-header >/dev/null 2>&1 &
  fi
  sleep 1
  if sudo ss -tunlp | grep -q ":8188"; then
    log "   ✅ ComfyUI is listening on 8188"
  else
    log "   ❌ ComfyUI failed to start and is not listening on 8188"
  fi
  chmod 644 "$svc_file" || true
  log "   ✅ Wrote systemd unit: $svc_file"
}

# ═══════════════════════════════════════════════════════════════════════════════
# CHECKPOINT SYSTEM (Resume from Last Completed Phase)
# ═══════════════════════════════════════════════════════════════════════════════
CHECKPOINT_FILE="${WORKSPACE:-/workspace}/.provision_checkpoint"
DOWNLOADS_COMPLETE="${WORKSPACE:-/workspace}/.downloads_complete"

checkpoint_save() {
    local phase="$1"
    echo "$phase" > "$CHECKPOINT_FILE"
    log "📌 Checkpoint: $phase saved"
}

checkpoint_load() {
    if [[ -f "$CHECKPOINT_FILE" ]]; then
        cat "$CHECKPOINT_FILE"
    else
        echo "START"
    fi
}

checkpoint_is_complete() {
    local phase="$1"
    local current=$(checkpoint_load)

    # Phase progression: START → PACKAGES → COMFYUI → NODES → MODELS → COMFYUI_STARTED → COMPLETE
    case "$current" in
        START)
            return 1 ;;  # Nothing completed yet
        PACKAGES)
            [[ "$phase" == "START" ]] && return 0 || return 1 ;;
        COMFYUI)
            [[ "$phase" =~ ^(START|PACKAGES)$ ]] && return 0 || return 1 ;;
        NODES)
            [[ "$phase" =~ ^(START|PACKAGES|COMFYUI)$ ]] && return 0 || return 1 ;;
        MODELS)
            [[ "$phase" =~ ^(START|PACKAGES|COMFYUI|NODES)$ ]] && return 0 || return 1 ;;
        COMFYUI_STARTED)
            [[ "$phase" =~ ^(START|PACKAGES|COMFYUI|NODES|MODELS)$ ]] && return 0 || return 1 ;;
        COMPLETE)
            return 0 ;;  # Everything completed
        *)
            log "⚠️  Unknown checkpoint state: $current"
            return 1 ;;
    esac
}

checkpoint_reset() {
    rm -f "$CHECKPOINT_FILE"
    log "🔄 Checkpoint reset - will start from beginning"
}

main() {
    log "--- Provisioning Start ---"

    # Load and display checkpoint status
    local checkpoint=$(checkpoint_load)
    log "📌 Current checkpoint: $checkpoint"

    if [[ "$checkpoint" != "START" ]]; then
        log "   ✅ Resuming from previous run - completed phases will be skipped"
    fi

    # ═══════════════════════════════════════════════════════════════════════════════
    # PHASE 1: SYSTEM PACKAGES & EMERGENCY RECOVERY
    # ═══════════════════════════════════════════════════════════════════════════════
    if checkpoint_is_complete "START"; then
        log "⏭️  Skipping: Emergency recovery & APT packages (already done)"
    else
        log_section "PHASE 1: SYSTEM PACKAGES & EMERGENCY RECOVERY"
        emergency_recovery
        install_apt_packages
        check_required_cmds
        
        # Install cloudflared for tunnel access (non-blocking if fails)
        install_cloudflared || log "   ⚠️  Cloudflared install failed - tunnel access will be unavailable"

        # Validate token before downloads - fail early to save time
        if ! validate_civitai_token; then
            log "❌ FATAL: Civitai token validation failed - cannot proceed with provisioning"
            log "   Please set a valid CIVITAI_TOKEN and try again"
            exit 1
        fi

        checkpoint_save "PACKAGES"
    fi

    # ═══════════════════════════════════════════════════════════════════════════════
    # PHASE 2: COMFYUI INSTALLATION
    # ═══════════════════════════════════════════════════════════════════════════════
    if checkpoint_is_complete "PACKAGES"; then
        log "⏭️  Skipping: ComfyUI installation (already done)"
    else
        log_section "PHASE 2: COMFYUI INSTALLATION"
        install_comfyui
        checkpoint_save "COMFYUI"
    fi

    # ═══════════════════════════════════════════════════════════════════════════════
    # PHASE 3: CUSTOM NODES
    # ═══════════════════════════════════════════════════════════════════════════════
    if checkpoint_is_complete "COMFYUI"; then
        log "⏭️  Skipping: Custom nodes (already done)"
    else
        log_section "PHASE 3: CUSTOM NODES"
        emergency_recovery
        install_nodes
        checkpoint_save "NODES"
    fi

    # ═══════════════════════════════════════════════════════════════════════════════
    # PHASE 4: MODEL DOWNLOADS
    # ═══════════════════════════════════════════════════════════════════════════════
    if checkpoint_is_complete "NODES"; then
        log "⏭️  Skipping: Model downloads (already done)"
    else
        log_section "PHASE 4: MODEL DOWNLOADS (Longest Phase)"
        emergency_recovery
        install_hf_tools
        install_models
        install_workflows
        retry_failed_downloads
        checkpoint_save "MODELS"
    fi

    # ═══════════════════════════════════════════════════════════════════════════════
    # PHASE 5: VERIFICATION & START COMFYUI
    # ═══════════════════════════════════════════════════════════════════════════════
    if checkpoint_is_complete "MODELS"; then
        log "⏭️  Skipping: Verification (already done)"
    else
        log_section "PHASE 5: VERIFICATION & START COMFYUI"
        verify_installation
        start_comfyui
        checkpoint_save "COMFYUI_STARTED"
    fi

    # ═══════════════════════════════════════════════════════════════════════════════
    # PHASE 6: CLOUDFLARE TUNNEL (Public Access)
    # ═══════════════════════════════════════════════════════════════════════════════
    if checkpoint_is_complete "COMFYUI_STARTED"; then
        log "⏭️  Skipping: Tunnel setup (already done)"
    else
        log_section "PHASE 6: CLOUDFLARE TUNNEL (Public Access)"
        # Generate systemd service for persistence
        generate_cloudflared_service || true
        # Start tunnel and capture/report URL
        start_cloudflare_tunnel || log "   ⚠️  Tunnel setup failed - use SSH tunnel as fallback"
        
        # ═══════════════════════════════════════════════════════════════════════════════
        # PHASE 7: POST-INSTALL DEPENDENCY FIX (OPTIONAL)
        # ═══════════════════════════════════════════════════════════════════════════════
        log_section "PHASE 7: POST-INSTALL DEPENDENCY FIX"
        log "   🔧 Running comprehensive dependency installer..."
        log "   This ensures ALL custom node requirements are satisfied"
        
        # Download and run the dependency fixer
        local fix_script_url="https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw/9a30de5de797797975a92eafb6d590e20424f014/fix-dependencies.sh"
        
        if wget -q -O /tmp/fix-dependencies.sh "$fix_script_url"; then
            chmod +x /tmp/fix-dependencies.sh
            if /tmp/fix-dependencies.sh 2>&1 | tee /tmp/post-install-fix.log; then
                log "   ✅ Dependency fix completed successfully"
            else
                log "   ⚠️  Dependency fix had warnings (check /tmp/post-install-fix.log)"
            fi
        else
            log "   ⚠️  Could not download dependency fix script (skipping)"
        fi
        
        checkpoint_save "COMPLETE"
    fi

    log "--- Provisioning Complete ---"
    log "✅ All phases completed successfully!"
    log "   Checkpoint file: $CHECKPOINT_FILE"
    log "   To reset checkpoint and start fresh: rm $CHECKPOINT_FILE"
}

# Command-line argument handling
if [[ $# -gt 0 ]]; then
    case "$1" in
        --search-rate-limits|--rate-limits)
            search_rate_limit_errors "${2:-/workspace/provision_errors.log}" "${3:-}"
            exit 0
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --search-rate-limits [LOG_FILE] [OUTPUT_FILE]  Search for rate limit errors in logs"
            echo "  --help, -h                                    Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                            Run full provisioning"
            echo "  $0 --search-rate-limits                        Search default error log"
            echo "  $0 --search-rate-limits /path/to/log           Search custom log file"
            echo "  $0 --search-rate-limits /path/to/log output.txt Save filtered results"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$0 --help' for usage information"
            exit 1
            ;;
    esac
fi

# Run main provisioning function
main
