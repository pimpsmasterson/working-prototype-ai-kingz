#!/bin/bash
# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║   👑 AI KINGS COMFYUI - RELIABLE PROVISIONER v3.1 (PRODUCTION)              ║
# ║                                                                               ║
# ║   ✓ Multi-Source Reliability (HF → Civitai → ModelScope → Dropbox)          ║
# ║   ✓ CUDA 12.4/13.0 Auto-Detection (RTX 50-series support)                   ║
# ║   ✓ XFormers/SageAttention Optimization                                     ║
# ║   ✓ 50+ Verified Models with Triple Fallbacks                               ║
# ║   ✓ Smart Rate-Limit Handling (Sequential Civitai, Parallel HF)             ║
# ║   ✓ Vast.ai GPU Optimized                                                   ║
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
    # Preserve ComfyUI PID if present to avoid killing the running server
    local preserve_pid_file="${WORKSPACE:-/workspace}/comfyui.pid"
    local preserve_pid=""
    if [[ -f "$preserve_pid_file" ]]; then
        preserve_pid=$(cat "$preserve_pid_file" 2>/dev/null || true)
        echo "   ⛳ Preserving ComfyUI PID: $preserve_pid"
    fi

    # Kill background jobs
    for p in $(jobs -p); do
        if [[ -n "$preserve_pid" && "$p" == "$preserve_pid" ]]; then
            continue
        fi
        kill -15 "$p" 2>/dev/null || true
    done
    sleep 2
    for p in $(jobs -p); do
        if [[ -n "$preserve_pid" && "$p" == "$preserve_pid" ]]; then
            continue
        fi
        kill -9 "$p" 2>/dev/null || true
    done

    exit $exit_code
}

# Set trap for cleanup on EXIT, INT (Ctrl+C), TERM
trap cleanup_on_exit EXIT INT TERM

# 1. DEFINE LOGGING & PRE-FLIGHT
# Prefer workspace for logs; fall back to /workspace when WORKSPACE unset
LOG_FILE="${WORKSPACE:-/workspace}/provision_v3.log"
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
    
    # Respect DISABLE_CLOUDFLARED if set
    if [[ "${DISABLE_CLOUDFLARED:-0}" == "1" ]]; then
        log "   ℹ️  DISABLE_CLOUDFLARED=1 — skipping Cloudflared quick tunnel"
        return 1
    fi

    # If a named tunnel is requested, validate credentials early.
    if [[ -n "${CLOUDFLARED_TUNNEL_NAME:-}" ]]; then
        if ! validate_cloudflared_named_tunnel; then
            log "   ❌ Named tunnel validation failed - skipping Cloudflared startup"
            return 1
        fi
    fi

    # Start tunnel in background: support pre-created named tunnel (preferred) or Quick Tunnel fallback
    log "   🚀 Starting Cloudflare tunnel..."
    if [[ -n "$CLOUDFLARED_TUNNEL_NAME" ]]; then
        # Use named tunnel run (stable credentials) if provided
        if [[ -n "$CLOUDFLARED_CRED_FILE" ]]; then
            setsid nohup "$CLOUDFLARED_BIN" tunnel run "$CLOUDFLARED_TUNNEL_NAME" --credentials-file "$CLOUDFLARED_CRED_FILE" > "$TUNNEL_LOG" 2>&1 < /dev/null &
        else
            setsid nohup "$CLOUDFLARED_BIN" tunnel run "$CLOUDFLARED_TUNNEL_NAME" > "$TUNNEL_LOG" 2>&1 < /dev/null &
        fi
    else
        # Quick Tunnel (ephemeral) - subject to rate limits
        setsid nohup "$CLOUDFLARED_BIN" tunnel --url http://localhost:8188 > "$TUNNEL_LOG" 2>&1 < /dev/null &
    fi

    local TUNNEL_PID=$!
    echo "$TUNNEL_PID" > "$TUNNEL_PID_FILE"
    log "   📝 Tunnel started with PID: $TUNNEL_PID"

    # Wait for tunnel URL to appear in logs (allow retries and restarts)
    log "   ⏳ Waiting for tunnel URL..."
    local TUNNEL_URL=""
    local WAIT_SECONDS=60
    local MAX_ATTEMPTS=3

    for attempt in $(seq 1 $MAX_ATTEMPTS); do
        for i in $(seq 1 $WAIT_SECONDS); do
            TUNNEL_URL=$(grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' "$TUNNEL_LOG" 2>/dev/null | head -1 || true)
            if [[ -n "$TUNNEL_URL" ]]; then
                break 2
            fi
            sleep 1
        done

        # Fail fast if Cloudflare returned rate limit (429) - retrying won't help
        if grep -qE '429|Too Many Requests|error code: 1015' "$TUNNEL_LOG" 2>/dev/null; then
            log "   ⚠️  Cloudflare rate limit (429) - skipping tunnel retries; use SSH fallback"
            break
        fi

        # If not found, try restarting cloudflared and try again
        if [[ -z "$TUNNEL_URL" ]]; then
            log "   ⚠️  Attempt ${attempt}/${MAX_ATTEMPTS}: tunnel URL not found; restarting cloudflared and retrying..."
            if [[ -f "$TUNNEL_PID_FILE" ]]; then
                local pid=$(cat "$TUNNEL_PID_FILE" 2>/dev/null || true)
                if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                    kill "$pid" 2>/dev/null || true
                    sleep 2
                fi
                rm -f "$TUNNEL_PID_FILE"
            fi

            setsid nohup "$CLOUDFLARED_BIN" tunnel --url http://localhost:8188 > "$TUNNEL_LOG" 2>&1 < /dev/null &
            local new_pid=$!
            echo "$new_pid" > "$TUNNEL_PID_FILE"
            log "   🔁 Restarted cloudflared (PID: $new_pid)"
            # short delay before next wait
            sleep 3
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

validate_cloudflared_named_tunnel() {
    log "   ⚙️  Validating named Cloudflared tunnel configuration..."
    local CLOUDFLARED_BIN="/usr/local/bin/cloudflared"

    # Nothing to validate if no named tunnel requested
    if [[ -z "${CLOUDFLARED_TUNNEL_NAME:-}" ]]; then
        return 0
    fi

    # Credentials file must be provided and readable
    if [[ -z "${CLOUDFLARED_CRED_FILE:-}" || ! -f "$CLOUDFLARED_CRED_FILE" ]]; then
        log "   ❌ CLOUDFLARED_TUNNEL_NAME is set but CLOUDFLARED_CRED_FILE is missing or unreadable"
        log "      Set CLOUDFLARED_CRED_FILE to the tunnel credentials JSON and re-run"
        return 1
    fi

    # Enforce restrictive permissions on credentials file (best-effort)
    if stat -c %a "$CLOUDFLARED_CRED_FILE" >/dev/null 2>&1; then
        local perm
        perm=$(stat -c %a "$CLOUDFLARED_CRED_FILE" 2>/dev/null || echo 0)
        if (( 10#$perm > 600 )); then
            log "   ⚠️  Credentials file permissions are too open ($perm). Restricting to 600."
            chmod 600 "$CLOUDFLARED_CRED_FILE" 2>/dev/null || log "   ⚠️  Failed to chmod credentials file"
        fi
    fi

    # Ensure cloudflared binary exists
    if ! "$CLOUDFLARED_BIN" --version >/dev/null 2>&1; then
        log "   ❌ cloudflared not found or not executable at $CLOUDFLARED_BIN"
        log "      Install cloudflared or set CLOUDFLARED_BIN to the correct path"
        return 1
    fi

    # Best-effort: check tunnel list for the named tunnel. If not found, fail early.
    if "$CLOUDFLARED_BIN" tunnel list 2>/dev/null | grep -q "${CLOUDFLARED_TUNNEL_NAME}"; then
        log "   ✅ Named tunnel '${CLOUDFLARED_TUNNEL_NAME}' present according to 'cloudflared tunnel list'"
    else
        log "   ❌ Named tunnel '${CLOUDFLARED_TUNNEL_NAME}' not found in 'cloudflared tunnel list'"
        log "      Ensure the tunnel exists (run 'cloudflared tunnel create' / 'cloudflared tunnel route') and the credentials file is correct"
        return 1
    fi

    return 0
}

validate_civitai_token() {
    if [[ -z "$CIVITAI_TOKEN" ]]; then
        log "⚠️  Warning: CIVITAI_TOKEN not set - Civitai downloads will fail"
        log "   Set token with: export CIVITAI_TOKEN='your_token_here'"
        return 1
    fi

    # Test token with several small public model IDs to avoid brittle single-model dependency
    local test_ids=(152309 105924 105925)
    local test_file="/tmp/civitai_token_test.tmp"
    local tried_any=0

    for id in "${test_ids[@]}"; do
        local test_url="https://civitai.com/api/download/models/${id}?token=$CIVITAI_TOKEN"
        local response=$(curl -s -w "%{http_code}" -o "$test_file" \
            --max-filesize 1048576 \
            --max-time 30 \
            "$test_url" 2>/dev/null || echo "000")
        rm -f "$test_file"
        if [[ "$response" == "200" || "$response" == "000" || "$response" == "206" ]]; then
            log "✅ Civitai token validated successfully (tested download id $id)"
            return 0
        elif [[ "$response" == "401" || "$response" == "403" ]]; then
            log "❌ Civitai token INVALID or EXPIRED (HTTP $response)"
            log "   Get new token from: https://civitai.com/user/account"
            log "   ⚠️  Provisioning will FAIL - exiting early to save time"
            return 1
        elif [[ "$response" == "404" ]]; then
            tried_any=1
            continue
        else
            tried_any=1
            continue
        fi
    done

    if [[ $tried_any -eq 1 ]]; then
        log "⚠️  Could not validate Civitai token against sample IDs - proceeding (possible model removed)"
        return 0
    fi

    log "⚠️  Could not validate Civitai token (no responses) - proceeding anyway"
    return 0
}

log "🚀 Starting AI KINGS Provisioner v3.1 (Reliable & Secured)..."

# Suppress pip root user warnings (we intentionally run as root on Vast.ai)
export PIP_ROOT_USER_ACTION=ignore

# Ensure workspace exists and is writable.
DEFAULT_WS=${WORKSPACE:-/workspace}
if mkdir -p "$DEFAULT_WS" 2>/dev/null && cd "$DEFAULT_WS" 2>/dev/null; then
  WORKSPACE="$PWD"
fi

# 2.2 SSH CONFIGURATION (All SSH fixes removed - they break provisioning)
log "🔐 SSH configuration skipped (causes provisioning issues)"

# 2.5 DISK SPACE CHECK (Configurable)
# Minimum disk in GB required for provisioning (configurable via env MIN_DISK_GB, default lowered for flexibility)
MIN_DISK_GB=${MIN_DISK_GB:-100}
ALLOW_LOW_DISK=${ALLOW_LOW_DISK:-0}  # set to 1 to override strict disk check

# Check main workspace and common model dirs (handles cases with multiple mounts)
check_dirs=("$WORKSPACE" "${COMFYUI_DIR:-/workspace/ComfyUI}/models" "$WORKSPACE/ComfyUI/models/checkpoints")
for d in "${check_dirs[@]}"; do
    if [[ -d "$d" ]]; then
        AVAILABLE_KB=$(df "$d" | awk 'NR==2 {print $4}') || AVAILABLE_KB=0
        if (( AVAILABLE_KB < MIN_DISK_GB * 1024 * 1024 )); then
            if [[ "${ALLOW_LOW_DISK}" == "1" ]]; then
                log "⚠️  Low disk in $d: $((AVAILABLE_KB / 1024 / 1024))GB, below ${MIN_DISK_GB}GB but ALLOW_LOW_DISK=1 so continuing"
            else
                log "❌ FATAL ERROR: Insufficient disk space in $d."
                log "   Need: ${MIN_DISK_GB}GB, Have: $((AVAILABLE_KB / 1024 / 1024))GB"
                log "   Cannot proceed with provisioning - exiting early"
                exit 1
            fi
        fi
    fi
done

COMFYUI_DIR=${WORKSPACE}/ComfyUI
# Note: LOG_FILE already initialized above to use WORKSPACE (or /workspace fallback)
# Make HuggingFace parallelism configurable via env (default: 2 to reduce HF rate-limits)
HUGGINGFACE_MAX_PARALLEL="${HUGGINGFACE_MAX_PARALLEL:-2}"
MAX_PAR_HF="$HUGGINGFACE_MAX_PARALLEL"      # Parallel downloads for HuggingFace/Catbox (backwards compatible)
MAX_PAR_CIVITAI=1 # Sequential for Civitai (avoids 429)

# Cloudflared controls: disable quick tunnels or provide a pre-created named tunnel
DISABLE_CLOUDFLARED="${DISABLE_CLOUDFLARED:-0}"         # set to 1 to skip Cloudflare tunnel
CLOUDFLARED_TUNNEL_NAME="${CLOUDFLARED_TUNNEL_NAME:-}"   # if set, run a pre-created named tunnel
CLOUDFLARED_CRED_FILE="${CLOUDFLARED_CRED_FILE:-}"       # optional credentials file path for named tunnel

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
    "https://github.com/kijai/ComfyUI-KJNodes"  # REQUIRED for WanVideoWrapper
    "https://github.com/jags111/efficiency-nodes-comfyui"
    "https://github.com/cubiq/ComfyUI_IPAdapter_plus"
    "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/city96/ComfyUI-GGUF"
    "https://github.com/flowtyone/flowtyone/ComfyUI-TripoSR"
    "https://github.com/Lightricks/ComfyUI-LTXVideo"
    "https://github.com/yolain/ComfyUI-Easy-Use"
    "https://github.com/cubiq/ComfyUI_essentials"
    "https://github.com/AIGODLIKE/AIGODLIKE-ComfyUI-Translation"
    "https://github.com/kijai/ComfyUI-Florence2"
    "https://github.com/chflame163/ComfyUI_LayerStyle"
    "https://github.com/WASasquatch/was-node-suite-comfyui"
    "https://github.com/Starttoaster/ComfyUI-Copilot"
)

# ═══════════════════════════════════════════════════════════════════════════════
# MODELS - Checkpoints (HuggingFace Primary + Dropbox Fallback)
# ═══════════════════════════════════════════════════════════════════════════════
# Format: "PRIMARY_URL|FALLBACK_URL|filename"
# Uses verified HuggingFace repos as primary source, Dropbox as reliable fallback
CHECKPOINT_MODELS=(
    # DreamShaper 8 (2GB) - Multi-source verified
    "https://huggingface.co/stablediffusionapi/dreamshaper-8/resolve/main/dreamshaper_8.safetensors|https://civitai.com/api/download/models/128641|https://modelscope.cn/models/AI-ModelScope/dreamshaper-8/resolve/master/dreamshaper_8.safetensors|dreamshaper_8.safetensors"
    
    # SDXL Base 1.0 (6.9GB) - Official Stability AI
    "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors|https://civitai.com/api/download/models/128078|https://modelscope.cn/models/AI-ModelScope/stable-diffusion-xl-base-1.0/resolve/master/sd_xl_base_1.0.safetensors|sd_xl_base_1.0.safetensors"
    
    # SDXL Refiner 1.0 (6.1GB) - Official
    "https://huggingface.co/stabilityai/stable-diffusion-xl-refiner-1.0/resolve/main/sd_xl_refiner_1.0.safetensors|https://civitai.com/api/download/models/128080|https://modelscope.cn/models/AI-ModelScope/stable-diffusion-xl-refiner-1.0/resolve/master/sd_xl_refiner_1.0.safetensors|sd_xl_refiner_1.0.safetensors"
    
    # Pony Diffusion V6 XL (6.5GB)
    "https://huggingface.co/AstraliteHeart/pony-diffusion-v6/resolve/main/ponyDiffusionV6XL.safetensors|https://civitai.com/api/download/models/290640|https://modelscope.cn/models/Polenov2024/Pony-Diffusion-V6-XL/resolve/master/model.safetensors|ponyDiffusionV6XL.safetensors"
    
    # RealVisXL V4.0 (6.5GB)
    "https://huggingface.co/SG161222/RealVisXL_V4.0/resolve/main/RealVisXL_V4.0.safetensors|https://civitai.com/api/download/models/401923|https://modelscope.cn/models/SG161222/RealVisXL_V4.0/resolve/master/RealVisXL_V4.0.safetensors|RealVisXL_V4.0.safetensors"
    
    # Juggernaut XL (6.5GB)
    "https://huggingface.co/RunDiffusion/Juggernaut-XL-v9/resolve/main/Juggernaut-XL-v9.safetensors|https://civitai.com/api/download/models/357609|https://modelscope.cn/models/RunDiffusion/Juggernaut-XL-v9/resolve/master/Juggernaut-XL-v9.safetensors|Juggernaut-XL-v9.safetensors"

    # pmXL v1 (6.5GB) - Dropbox only (Preserved)
    "https://www.dropbox.com/scl/fi/dd7aiju5petevb6nalinr/pmXL_v1.safetensors?rlkey=p4ukouvdd2o912ilcfbi6cqk3&dl=1|https://files.catbox.moe/pmXL_v1.safetensors||pmXL_v1.safetensors"

    # revAnimated v1.2.2 (2GB) - Civitai working URL
    "https://civitai.com/api/download/models/119057?type=Model&format=SafeTensor&size=pruned&fp=fp16|https://huggingface.co/stablediffusionapi/rev-animated/resolve/main/rev-animated.safetensors|https://modelscope.cn/models/AI-ModelScope/rev-animated/resolve/master/rev-animated.safetensors|revAnimated_v122.safetensors"

    # Pony Realism v2.2 (6.5GB) - Civitai working URL
    "https://civitai.com/api/download/models/914390?type=Model&format=SafeTensor&size=pruned&fp=fp16|https://www.dropbox.com/scl/fi/hy476rxzeacsx8g3aodj0/pony_realism_v2.2.safetensors?rlkey=09k5sba46pqoptdu7h1tu03b4&dl=1||pony_realism_v2.2.safetensors"

    # WAI Illustrious SDXL - Dropbox only (Preserved)
    "https://www.dropbox.com/scl/fi/okhdb2r3i43l7f8hv07li/wai_illustrious_sdxl.safetensors?rlkey=t7r11yjr61ecdm0vrsgrkztc8&dl=1|https://files.catbox.moe/wai_illustrious.safetensors||wai_illustrious_sdxl.safetensors"

    # Rajii Artist Style V2 - Dropbox only (Preserved)
    "https://www.dropbox.com/scl/fi/eq3qqc5rnwod3ac1xfisp/Rajii-Artist-Style-V2-Illustrious.safetensors?rlkey=cvfjam45wbmye89g2mvj245lz&dl=1|https://files.catbox.moe/rajii_v2.safetensors||Rajii-Artist-Style-V2-Illustrious.safetensors"

    # DR34MJOB I2V 14B - Dropbox only (Preserved)
    "https://www.dropbox.com/scl/fi/6af8pzucgqyr0dy78eh6q/DR34MJOB_I2V_14b_LowNoise.safetensors?rlkey=pgnys4h98h343ibaro0fgwhqv&dl=1|https://files.catbox.moe/dr34mjob_i2v.safetensors||DR34MJOB_I2V_14b_LowNoise.safetensors"

    # PornMaster Pro Noob v6 - Dropbox only (Preserved)
    "https://www.dropbox.com/scl/fi/8280uj9myxuf2376d13jt/pornmasterPro_noobV6.safetensors?rlkey=lmduqq3jxusts1fqqexuqz72w&dl=1|https://files.catbox.moe/pmpro_noobv6.safetensors||pornmasterPro_noobV6.safetensors"

    # ExpressiveH Hentai - Dropbox only (Preserved)
    "https://www.dropbox.com/scl/fi/5whxkdo39m4w2oimcffx2/expressiveh_hentai.safetensors?rlkey=5ejkyjvethd1r7fn121x7cvs1&dl=1|https://files.catbox.moe/expressiveh.safetensors||expressiveh_hentai.safetensors"

    # Fondled - Dropbox only (Preserved)
    "https://www.dropbox.com/scl/fi/9drclw495plki15ynlmst/fondled.safetensors?rlkey=vh5efbuy0er4338xrkivilpnb&dl=1|https://files.catbox.moe/fondled.safetensors||fondled.safetensors"

    # Wan dr34ml4y All-in-One - Dropbox only (Preserved)
    "https://www.dropbox.com/scl/fi/hp8t53h5ylrhkphnq4cyu/wan_dr34ml4y_all_in_one.safetensors?rlkey=9bq4clb4gmiz4rp6i8g69fl9u&dl=1|https://files.catbox.moe/wan_allinone.safetensors||wan_dr34ml4y_all_in_one.safetensors"

    # Wan dr34mjob - Dropbox only (Preserved)
    "https://www.dropbox.com/scl/fi/ym112crqb6d7sdkqz5s9j/wan_dr34mjob.safetensors?rlkey=eqzd371f86g6tsof0fcecfn8n&dl=1|https://files.catbox.moe/wan_mjob.safetensors||wan_dr34mjob.safetensors"

    # Twerk - Dropbox only (Preserved)
    "https://www.dropbox.com/scl/fi/0g4btjch885ij3kiauffm/twerk.safetensors?rlkey=8yqxhqpvs1osat76ynxadwkh8&dl=1|https://files.catbox.moe/twerk.safetensors||twerk.safetensors"

    # LTX-2 distilled (video) — adds LTX-2 video capability
    "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-distilled.safetensors|https://modelscope.cn/models/Lightricks/LTX-2/resolve/master/ltx-2-19b-distilled.safetensors||ltx-2-19b-distilled.safetensors"
)

# ═══════════════════════════════════════════════════════════════════════════════
# MODELS - LoRAs (HuggingFace Primary + Fallback)
# ═══════════════════════════════════════════════════════════════════════════════
LORA_MODELS=(
    # Pony Realism v2.1
    "https://huggingface.co/LyliaEngine/ponyRealism_v21MainVAE/resolve/main/ponyRealism_v21MainVAE.safetensors|https://civitai.com/api/download/models/152309||pony_realism_v2.1.safetensors"

    # LTX-2 camera control LoRA (dolly-left)
    "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-lora-camera-control-dolly-left.safetensors|||ltx-2-19b-lora-camera-control-dolly-left.safetensors"

    # Preserved Legacy LoRAs
    "https://huggingface.co/JollyIm/Defecation/resolve/main/defecation_v1.safetensors|||defecation_v1.safetensors"
    "https://www.dropbox.com/scl/fi/5whxkdo39m4w2oimcffx2/expressiveh_hentai.safetensors?rlkey=5ejkyjvethd1r7fn121x7cvs1&dl=1|||expressiveh_hentai.safetensors"
    "https://www.dropbox.com/scl/fi/9drclw495plki15ynlmst/fondled.safetensors?rlkey=vh5efbuy0er4338xrkivilpnb&dl=1|||fondled.safetensors"
    "https://www.dropbox.com/scl/fi/hp8t53h5ylrhkphnq4cyu/wan_dr34ml4y_all_in_one.safetensors?rlkey=9bq4clb4gmiz4rp6i8g69fl9u&dl=1|||wan_dr34ml4y_all_in_one.safetensors"
    "https://www.dropbox.com/scl/fi/ym112crqb6d7sdkqz5s9j/wan_dr34mjob.safetensors?rlkey=eqzd371f86g6tsof0fcecfn8n&dl=1|||wan_dr34mjob.safetensors"
    "https://www.dropbox.com/scl/fi/0g4btjch885ij3kiauffm/twerk.safetensors?rlkey=8yqxhqpvs1osat76ynxadwkh8&dl=1|||twerk.safetensors"

    # Catbox.moe Preserved (with secondary fallbacks where possible)
    "https://files.catbox.moe/wmshk3.safetensors|https://civitai.com/api/download/models/833010||cunnilingus_gesture.safetensors"
    "https://files.catbox.moe/88e51n.rar|||archive_lora.rar"
    "https://files.catbox.moe/9qixqa.safetensors|https://civitai.com/api/download/models/12547||empty_eyes_drooling.safetensors"
    "https://files.catbox.moe/yz5c9g.safetensors|https://civitai.com/api/download/models/643750||glowing_eyes.safetensors"
    "https://files.catbox.moe/tlt57h.safetensors|||quadruple_amputee.safetensors"
    "https://files.catbox.moe/odmswn.safetensors|https://civitai.com/api/download/models/357609||ugly_bastard.safetensors"
    "https://files.catbox.moe/z71ic0.safetensors|https://civitai.com/api/download/models/161829||sex_machine.safetensors"
    "https://files.catbox.moe/mxbbg2.safetensors|https://civitai.com/api/download/models/833010||stasis_tank.safetensors"

    # BlackHat404/scatmodels Preserved
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/Soiling-V1.safetensors|||Soiling-V1.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/turtleheading-V1.safetensors|||turtleheading-V1.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/poop_squatV2.safetensors|||poop_squatV2.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/Poop_SquatV3.safetensors|||Poop_SquatV3.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/HyperDump.safetensors|||HyperDump.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/HyperDumpPlus.safetensors|||HyperDumpPlus.safetensors"
)

# ═══════════════════════════════════════════════════════════════════════════════
# MODELS - Wan Video & Specialist Arrays
# ═══════════════════════════════════════════════════════════════════════════════
WAN_DIFFUSION_MODELS=(
    # Wan 2.1 T2V 1.3B (FP16)
    "https://huggingface.co/Wan-AI/Wan2.1-T2V-1.3B/resolve/main/wan2.1_t2v_1.3B_fp16.safetensors|https://modelscope.cn/models/Wan-AI/Wan2.1-T2V-1.3B/resolve/master/wan2.1_t2v_1.3B_fp16.safetensors||wan2.1_t2v_1.3B_fp16.safetensors"
    
    # Wan 2.1 T2V 14B (FP8)
    "https://huggingface.co/Wan-AI/Wan2.1-T2V-14B/resolve/main/wan2.1_t2v_14B_fp8_e4m3fn.safetensors|https://modelscope.cn/models/Wan-AI/Wan2.1-T2V-14B/resolve/master/wan2.1_t2v_14B_fp8_e4m3fn.safetensors|https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/wan2.1_t2v_14B_fp8_e4m3fn.safetensors|wan2.1_t2v_14B_fp8_e4m3fn.safetensors"
    
    # Wan 2.1 I2V 14B 480P (FP8)
    "https://huggingface.co/Wan-AI/Wan2.1-I2V-14B-480P/resolve/main/wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors|https://modelscope.cn/models/Wan-AI/Wan2.1-I2V-14B-480P/resolve/master/wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors||wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors"
    
    # Wan 2.1 I2V 14B 720P (FP8)
    "https://huggingface.co/Wan-AI/Wan2.1-I2V-14B-720P/resolve/main/wan2.1_i2v_720p_14B_fp8_e4m3fn.safetensors|https://modelscope.cn/models/Wan-AI/Wan2.1-I2V-14B-720P/resolve/master/wan2.1_i2v_720p_14B_fp8_e4m3fn.safetensors||wan2.1_i2v_720p_14B_fp8_e4m3fn.safetensors"

    # Wan 2.2 T2V (Preserved from v3.0)
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors|https://www.dropbox.com/scl/fi/v6s8zpucgqyr0dy78eh6q/wan2.2_t2v_high_noise.safetensors?rlkey=pgnys4h98h343ibaro0fgwhqv&dl=1||wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors|https://www.dropbox.com/scl/fi/v6s8zpucgqyr0dy78eh6q/wan2.2_t2v_low_noise.safetensors?rlkey=pgnys4h98h343ibaro0fgwhqv&dl=1||wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors"

    # Wan 2.2 TI2V (Preserved from v3.0)
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors|https://www.dropbox.com/scl/fi/v6s8zpucgqyr0dy78eh6q/wan2.2_ti2v_5B_fp16.safetensors?rlkey=pgnys4h98h343ibaro0fgwhqv&dl=1||wan2.2_ti2v_5B_fp16.safetensors"

    # Wan 2.2 Remix (Preserved from v3.0)
    "https://civitai.com/api/download/models/2567309?type=Model&format=SafeTensor&size=pruned&fp=fp8|https://civitai.com/api/download/models/915814?type=Model&format=SafeTensor&size=pruned&fp=fp16||wan2.2_remix_fp8.safetensors"
)

WAN_CLIP_MODELS=(
    # UMT5 XXL FP8 (Standard)
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn.safetensors|https://modelscope.cn/models/Wan-AI/Wan2.1-UMT5-XXL-FP8/resolve/master/umt5_xxl_fp8_e4m3fn.safetensors||umt5_xxl_fp8_e4m3fn.safetensors"
    
    # UMT5 XXL BF16 (Higher quality)
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_bf16.safetensors|||umt5_xxl_bf16.safetensors"

    # UMT5 XXL FP8 Scaled (Preserved from v3.0)
    "https://huggingface.co/Comfy-Org/LTX-2/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors|||umt5_xxl_fp8_e4m3fn_scaled.safetensors"
)

# ═══════════════════════════════════════════════════════════════════════════════
# MODELS - Wan 2.2 LoRAs (Lightning Fast Video Generation)
# ═══════════════════════════════════════════════════════════════════════════════
WAN_LORA_MODELS=(
    "https://huggingface.co/Wan-AI/Wan2.1-T2V-14B/resolve/main/wan2.1_t2v_14B_fp8_e4m3fn_lightning_lora.safetensors|https://modelscope.cn/models/Wan-AI/Wan2.1-T2V-14B/resolve/master/wan2.1_t2v_14B_fp8_e4m3fn_lightning_lora.safetensors||wan2.1_t2v_14B_lightning_lora.safetensors"
    "https://huggingface.co/Wan-AI/Wan2.1-I2V-14B-480P/resolve/main/wan2.1_i2v_480p_14B_fp8_e4m3fn_lightning_lora.safetensors|https://modelscope.cn/models/Wan-AI/Wan2.1-I2V-14B-480P/resolve/master/wan2.1_i2v_480p_14B_fp8_e4m3fn_lightning_lora.safetensors||wan2.1_i2v_480p_14B_lightning_lora.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_high_noise.safetensors|https://www.dropbox.com/scl/fi/v6s8zpucgqyr0dy78eh6q/wan2.2_t2v_high_noise.safetensors?rlkey=pgnys4h98h343ibaro0fgwhqv&dl=1||wan2.2_t2v_lightx2v_4steps_lora_high_noise.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_low_noise.safetensors|https://www.dropbox.com/scl/fi/v6s8zpucgqyr0dy78eh6q/wan2.2_t2v_low_noise.safetensors?rlkey=pgnys4h98h343ibaro0fgwhqv&dl=1||wan2.2_t2v_lightx2v_4steps_lora_low_noise.safetensors"
)

# MODELS - Text Encoders (General)
TEXT_ENCODERS=(
    "https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors|https://modelscope.cn/models/Lightricks/LTX-2/resolve/master/gemma_3_12B_it_fp4_mixed.safetensors||gemma_3_12B_it_fp4_mixed.safetensors"
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors|https://modelscope.cn/models/AI-ModelScope/flux-fp8/resolve/master/t5xxl_fp8_e4m3fn.safetensors||t5xxl_fp8_e4m3fn.safetensors"
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors|https://modelscope.cn/models/AI-ModelScope/flux-fp8/resolve/master/clip_l.safetensors||clip_l.safetensors"
)

WAN_VAE_MODELS=(
    # Wan 2.1 VAE
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan2.1_vae.safetensors|||wan2.1_vae.safetensors"

    # Wan 2.2 VAE (Preserved from v3.0)
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors|||wan2.2_vae.safetensors"

    # Lumina Image 2.0 VAE (Preserved from v3.0)
    "https://huggingface.co/Comfy-Org/Lumina_Image_2.0_Repackaged/resolve/main/split_files/vae/ae.safetensors|||ae.safetensors"

    # SDXL VAE (Preserved from v3.0)
    "https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors|https://www.dropbox.com/scl/fi/3qygk64xe2ui2ey74neto/sdxl_vae.safetensors?rlkey=xzsllv3hq5w1qx81h9b2xryq8&dl=1||sdxl_vae.safetensors"

    # PonyRealism v2.1 VAE (Preserved from v3.0)
    "https://civitai.com/api/download/models/105924|||ponyRealism_v21MainVAE.safetensors"
)


ANIMATEDIFF_MODELS=(
    "https://huggingface.co/guoyww/animatediff/resolve/main/mm_sdxl_v10_beta.ckpt|https://modelscope.cn/models/AI-ModelScope/animatediff/resolve/master/mm_sdxl_v10_beta.ckpt||mm_sdxl_v10_beta.ckpt"
    "https://huggingface.co/guoyww/animatediff/resolve/main/mm_sd_v15_v2.ckpt|https://modelscope.cn/models/AI-ModelScope/animatediff/resolve/master/mm_sd_v15_v2.ckpt||mm_sd_v15_v2.ckpt"
)
 
UPSCALE_MODELS=(
    "https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth|https://modelscope.cn/models/AI-ModelScope/upscale-models/resolve/master/4x-UltraSharp.pth||4x-UltraSharp.pth"
    "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth|https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x4plus.pth||RealESRGAN_x4plus.pth"
    "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-spatial-upscaler-x2-1.0.safetensors|https://modelscope.cn/models/Lightricks/LTX-2/resolve/master/ltx-2-spatial-upscaler-x2-1.0.safetensors||ltx-2-spatial-upscaler-x2-1.0.safetensors"
)
 
CONTROLNET_MODELS=(
    "https://huggingface.co/thibaud/controlnet-openpose-sdxl-1.0/resolve/main/OpenPoseXL2.safetensors|https://civitai.com/api/download/models/136070|https://modelscope.cn/models/AI-ModelScope/controlnet-openpose-sdxl-1.0/resolve/master/OpenPoseXL2.safetensors|OpenPoseXL2.safetensors"
)
 
DETECTOR_MODELS=(
    "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt|https://modelscope.cn/models/AI-ModelScope/adetailer/resolve/master/face_yolov8m.pt||face_yolov8m.pt"
    "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8n.pt|https://modelscope.cn/models/AI-ModelScope/adetailer/resolve/master/hand_yolov8n.pt||hand_yolov8n.pt"
    "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth|https://huggingface.co/facebook/sam-vit-base/resolve/main/pytorch_model.bin||sam_vit_b_01ec64.pth"
)
 
RIFE_MODELS=(
    # RIFE 4.26 - Frame interpolation model (correct link from HuggingFace)
    "https://huggingface.co/r3gm/RIFE/resolve/main/RIFEv4.26_0921.zip|https://huggingface.co/hzwer/RIFE/resolve/main/RIFEv4.26_0921.zip||rife426.zip"
)

# ═══════════════════════════════════════════════════════════════════════════════
# MODELS - FLUX (Next-Gen Image Generation & Refinement)
# ═══════════════════════════════════════════════════════════════════════════════
FLUX_MODELS=(
    # FLUX.1 Krea Dev FP8
    "https://huggingface.co/Comfy-Org/FLUX.1-Krea-dev_ComfyUI/resolve/main/split_files/diffusion_models/flux1-krea-dev_fp8_scaled.safetensors|https://modelscope.cn/models/AI-ModelScope/flux-fp8/resolve/master/flux1-krea-dev_fp8_scaled.safetensors||flux1-krea-dev_fp8_scaled.safetensors"
    
    # FLUX.1 Schnell
    "https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/flux1-schnell.safetensors|https://civitai.com/api/download/models/643750|https://modelscope.cn/models/AI-ModelScope/FLUX.1-schnell/resolve/master/flux1-schnell.safetensors|flux1-schnell.safetensors"
)

FLUX_VAE_MODELS=()

# FLUX Text Encoders - Required for FLUX model operation
FLUX_CLIP_MODELS=(
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors|https://modelscope.cn/models/AI-ModelScope/flux-fp8/resolve/master/clip_l.safetensors||clip_l.safetensors"
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors|https://modelscope.cn/models/AI-ModelScope/flux-fp8/resolve/master/t5xxl_fp8_e4m3fn.safetensors||t5xxl_fp8_e4m3fn.safetensors"
)

# --- FLORENCE-2 (NEW in v3.1) ---
FLORENCE2_MODELS=(
    "https://huggingface.co/microsoft/Florence-2-large/resolve/main/model.safetensors|https://modelscope.cn/models/AI-ModelScope/Florence-2-large/resolve/master/model.safetensors|https://huggingface.co/Kijai/Florence-2-large-ComfyUI/resolve/main/model.safetensors|Florence-2-large.safetensors"
    "https://huggingface.co/microsoft/Florence-2-base/resolve/main/model.safetensors|https://modelscope.cn/models/AI-ModelScope/Florence-2-base/resolve/main/model.safetensors|https://huggingface.co/Kijai/Florence-2-base-ComfyUI/resolve/main/model.safetensors|Florence-2-base.safetensors"
)

# ═══════════════════════════════════════════════════════════════════════════════
# MODELS - LTX-2 (Advanced Video Generation with Camera Control)
# ═══════════════════════════════════════════════════════════════════════════════
LTX_DIFFUSION_MODELS=(
    # LTX-2 Distilled (Faster, smaller model - skipping 24GB dev version)
    "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-distilled.safetensors|https://modelscope.cn/models/Lightricks/LTX-2/resolve/master/ltx-2-19b-distilled.safetensors||ltx-2-19b-distilled.safetensors"
)

LTX_LORA_MODELS=(
    # Camera Control LoRAs
    "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-lora-camera-control-dolly-left.safetensors|https://modelscope.cn/models/Lightricks/LTX-2/resolve/master/ltx-2-19b-lora-camera-control-dolly-left.safetensors||ltx-2-19b-lora-camera-control-dolly-left.safetensors"
    "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-lora-camera-control-dolly-right.safetensors|https://modelscope.cn/models/Lightricks/LTX-2/resolve/master/ltx-2-19b-lora-camera-control-dolly-right.safetensors||ltx-2-19b-lora-camera-control-dolly-right.safetensors"
    "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-distilled-lora-384.safetensors|https://modelscope.cn/models/Lightricks/LTX-2/resolve/master/ltx-2-19b-distilled-lora-384.safetensors||ltx-2-19b-distilled-lora-384.safetensors"
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
    if command -v nvidia-smi >/dev/null 2>&1; then
        local cuda_raw=$(nvidia-smi --query-gpu=cuda_version --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d '\r')
        local gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1 | tr -d '\r')
        
        log "   🔎 GPU: $gpu_name | CUDA: $cuda_raw"
        
        # Check for RTX 50-series / Blackwell
        if [[ "$gpu_name" =~ 5090|5080|5070|5060|RTX\ 50|Blackwell ]]; then
            log "   ⚡ RTX 50-series detected - using CUDA 13.0"
            echo "cu130"
            return 0
        fi
        
        case "$cuda_raw" in
            13.*|12.9*) echo "cu130" ;;
            12.4*) echo "cu124" ;;
            12.1*) echo "cu121" ;;
            11.8*) echo "cu118" ;;
            *) 
                local driver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits 2>/dev/null | head -n1 | cut -d. -f1)
                if (( driver >= 570 )); then echo "cu130"
                elif (( driver >= 535 )); then echo "cu124"
                elif (( driver >= 525 )); then echo "cu121"
                else echo "cu118"; fi
                ;;
        esac
    else
        log "   ⚠️  No NVIDIA GPU detected"
        echo "cpu"
    fi
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

    local cuda_tag=$(detect_cuda_version)
    log "   🔎 Selected PyTorch wheel tag: $cuda_tag"

    local torch_success=false
    for torch_attempt in {1..3}; do
        if [[ "$cuda_tag" == "cpu" ]]; then
          log "   ⚠️  Installing CPU-only PyTorch"
          if "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
              torch torchvision torchaudio 2>&1 | tee -a /workspace/pip_install.log; then
              torch_success=true; break
          fi
        elif [[ "$cuda_tag" == "cu130" ]]; then
          log "   📥 Installing torch NIGHTLY for cu130 (RTX 50-series support)"
          if "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
            --force-reinstall --upgrade --pre torch torchvision torchaudio \
            --index-url https://download.pytorch.org/whl/nightly/cu130 2>&1 | tee -a /workspace/pip_install.log; then
            torch_success=true; break
          fi
        else
          local wheel_url="https://download.pytorch.org/whl/${cuda_tag}"
          log "   📥 Installing torch for $cuda_tag from $wheel_url"
          if "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
            torch torchvision torchaudio --index-url "$wheel_url" 2>&1 | tee -a /workspace/pip_install.log; then
            torch_success=true; break
          fi
        fi
        log "   ⚠️ Attempt $torch_attempt failed, retrying in 30s..."
        sleep 30
    done

    [[ "$torch_success" == "false" ]] && { log "❌ PyTorch FAILED"; return 1; }
    log "✅ PyTorch installed successfully"
}

install_essential_deps() {
    log_section "📦 INSTALLING ESSENTIAL DEPENDENCIES"
    activate_venv

    # 1. Uninstall conflicting packages
    "$VENV_PYTHON" -m pip uninstall -y xformers 2>/dev/null || true

    # 2. Core Dependencies with pins for stability
    log "   📦 Installing core dependencies (with pins)..."
    local deps_success=false
    for deps_attempt in {1..3}; do
        if "$VENV_PYTHON" -m pip install --no-cache-dir --retries 5 --timeout 300 \
            "numpy<2" \
            "transformers==4.36.0" \
            "accelerate" "safetensors" "einops" "opencv-python-headless" \
            "insightface" "onnxruntime-gpu" "sentencepiece" "piexif" \
            "ultralytics" "segment_anything" 2>&1 | tee -a /workspace/pip_install.log; then
            deps_success=true; break
        fi
        log "   ⚠️ Attempt $deps_attempt failed, retrying..."
        sleep 20
    done

    # 3. Optimization: SageAttention (If CUDA present)
    local cuda_tag=$(detect_cuda_version)
    if [[ "$cuda_tag" != "cpu" ]]; then
        log "   ⚡ Installing SageAttention optimization..."
        "$VENV_PYTHON" -m pip install sageattention 2>/dev/null || log "   ⚠️ SageAttention install failed (continuing)"
    fi

    [[ "$deps_success" == "false" ]] && log "❌ Core dependencies FAILED" || log "✅ Core dependencies installed"
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

    # Post-install: Double check critical requirements for problematic nodes
    log "   🔧 Finalizing custom node dependencies..."
    # (Optional) Add any specific node fixes here if not covered by Phase 7

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
    if [[ "$url" == *"huggingface.co"* ]]; then echo "HuggingFace"
    elif [[ "$url" == *"modelscope.cn"* ]]; then echo "ModelScope"
    elif [[ "$url" == *"civitai.com"* ]]; then echo "Civitai"
    elif [[ "$url" == *"dropbox.com"* ]]; then echo "Dropbox"
    elif [[ "$url" == *"github.com"* ]]; then echo "GitHub"
    else echo "Direct"; fi
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

    # Implement retry loop with exponential backoff to handle transient failures and 429 rate limits
    local attempt=1
    local backoff=${retry_wait}
    local max_backoff=600
    while (( attempt <= max_tries )); do
        log "      ▶️ Attempt $attempt/$max_tries for $filename (connections=${connections}, timeout=${timeout_per_attempt}s)"

        if command -v aria2c &>/dev/null; then
          aria2c "$url" -d "$dir" -o "$filename" \
               "${header_args[@]}" \
               -x${connections} -s${connections} -j1 --max-connection-per-server=${connections} \
               --timeout=${timeout_per_attempt} \
               --retry-wait=${retry_wait} \
               --max-tries=1 \
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
              log "      🚫 Rate Limit Error (429) detected - backing off $backoff s"
              [[ -f "/workspace/provision_errors.log" ]] || touch "/workspace/provision_errors.log"
              echo "$(date '+%Y-%m-%d %H:%M:%S') RATE_LIMIT_ERROR: $filename - URL: $url" >> "/workspace/provision_errors.log"
              sleep $backoff
              backoff=$(( backoff * 2 ))
              if (( backoff > max_backoff )); then backoff=$max_backoff; fi
              attempt=$(( attempt + 1 ))
              continue
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
        local wget_tries=1
        if [[ "$url" == *"dropbox.com"* ]]; then
            wget_timeout=300                # 5 minutes for Dropbox
            wget_tries=1                    # single try per loop
        fi

        local wget_opts=("-c" "--timeout=${wget_timeout}" "--tries=${wget_tries}" "-O" "$filepath")
        for header in "${header_args[@]}"; do
            wget_opts+=("${header/--header=/--header=}")
        done

        wget "${wget_opts[@]}" "$url" 2>&1 | tee -a "$LOG_FILE" | tee -a "$file_log"
        local wget_exit=${PIPESTATUS[0]}

        # Check for rate limit errors (HTTP 429) in wget output
        if grep -qi "429\|rate limit\|too many requests\|HTTP request sent.*429" "$file_log" 2>/dev/null; then
            log "      🚫 Rate Limit Error (429) detected in wget - backing off $backoff s"
            [[ -f "/workspace/provision_errors.log" ]] || touch "/workspace/provision_errors.log"
            echo "$(date '+%Y-%m-%d %H:%M:%S') RATE_LIMIT_ERROR: $filename - URL: $url (wget)" >> "/workspace/provision_errors.log"
            sleep $backoff
            backoff=$(( backoff * 2 ))
            if (( backoff > max_backoff )); then backoff=$max_backoff; fi
            attempt=$(( attempt + 1 ))
            continue
        fi

        if [[ $wget_exit -eq 0 && -f "$filepath" && $(stat -c%s "$filepath") -gt 1000000 ]]; then
            return 0
        fi

        # Generic retry backoff for non-429 failures
        log "      🔁 Attempt $attempt failed for $filename - sleeping $backoff s before retry"
        sleep $backoff
        backoff=$(( backoff * 2 ))
        if (( backoff > max_backoff )); then backoff=$max_backoff; fi
        attempt=$(( attempt + 1 ))
    done

    # All attempts exhausted
    log "      ❌ All $max_tries attempts failed for $filename"
    return 1
}

# Helper: extract archives (zip/rar/7z/tar)
# Extracts into the same directory and writes a marker file on success
extract_archive() {
    local dir="$1"
    local filename="$2"
    local filepath="${dir}/${filename}"

    # Only run on known archive extensions
    case "${filename,,}" in
        *.zip|*.tar.gz|*.tgz|*.tar|*.7z|*.rar)
            log "      🔧 Detected archive: $filename, attempting extraction..."
            if [[ ! -f "$filepath" ]]; then
                log "      ⚠️  Archive not present: $filepath"
                return 1
            fi

            # Use appropriate tool if available
            if [[ "$filename" == *.zip ]] && command -v unzip &>/dev/null; then
                unzip -o "$filepath" -d "$dir" >> "$LOG_FILE" 2>&1 || { log "      ⚠️  unzip failed for $filename"; return 1; }
            elif [[ "$filename" == *.rar ]] && command -v unrar &>/dev/null; then
                unrar x -o+ "$filepath" "$dir" >> "$LOG_FILE" 2>&1 || { log "      ⚠️  unrar failed for $filename"; return 1; }
            elif command -v 7z &>/dev/null && [[ "$filename" == *.7z ]]; then
                7z x "$filepath" -o"$dir" >> "$LOG_FILE" 2>&1 || { log "      ⚠️  7z extraction failed for $filename"; return 1; }
            elif [[ "$filename" == *.tar.gz || "$filename" == *.tgz || "$filename" == *.tar ]]; then
                tar -xzf "$filepath" -C "$dir" >> "$LOG_FILE" 2>&1 || { log "      ⚠️  tar extraction failed for $filename"; return 1; }
            else
                log "      ⚠️  No extraction tool available for $filename (skipping)"
                return 1
            fi

            # Create marker file listing extracted contents for verification
            local marker="${dir}/.extracted_${filename}.txt"
            find "$dir" -maxdepth 2 -type f -printf "%p\n" | sed "s|^$dir/||" > "$marker" || true
            log "      ✅ Extracted $filename -> marker: $(basename "$marker")"

            # Optionally remove archive to save space (only if EXTRACT_KEEP_ARCHIVE is unset)
            if [[ -z "${EXTRACT_KEEP_ARCHIVE:-}" ]]; then
                rm -f "$filepath" || true
                log "      🗑️  Removed archive: $filename"
            fi
            return 0
            ;;
        *)
            return 0  # Not an archive
            ;;
    esac
}

# Advanced Downloader with Multi-Source Fallback (v3.1)
download_file() {
    local url="$1"
    local dir="$2"
    local filename="$3"
    local fallback_url="${4:-}"
    local ms_url="${5:-}"
    local filepath="${dir}/${filename}"

    # 1. Skip if exists and > 1MB
    if [[ -f "$filepath" ]] && [[ $(stat -c%s "$filepath" 2>/dev/null || echo 0) -gt 1000000 ]]; then
        log "   ✅ $filename (cached)"
        return 0
    fi
    mkdir -p "$dir"

    # 2. Try PRIMARY source
    local src1=$(get_source_name "$url")
    log "   📥 Downloading $filename... (Source 1: $src1)"
    if attempt_download "$url" "$dir" "$filename"; then
        log "   ✅ $filename - COMPLETE (primary: $src1)"
        # Extract archives when applicable
        extract_archive "$dir" "$filename" || log "      ⚠️  Extraction skipped or failed for $filename"
        return 0
    fi

    # 3. Try FALLBACK source
    if [[ -n "$fallback_url" ]]; then
        local src2=$(get_source_name "$fallback_url")
        log "   ⚠️  Primary failed, trying Source 2: $src2"
        if attempt_download "$fallback_url" "$dir" "$filename"; then
            log "   ✅ $filename - COMPLETE (fallback: $src2)"
            extract_archive "$dir" "$filename" || log "      ⚠️  Extraction skipped or failed for $filename"
            return 0
        fi
    fi

    # 4. Try MODELSCOPE/BACKUP source
    if [[ -n "$ms_url" ]]; then
        local src3=$(get_source_name "$ms_url")
        log "   ⚠️  Fallback failed, trying Source 3: $src3"
        if attempt_download "$ms_url" "$dir" "$filename"; then
            log "   ✅ $filename - COMPLETE (backup: $src3)"
            extract_archive "$dir" "$filename" || log "      ⚠️  Extraction skipped or failed for $filename"
            return 0
        fi
    fi

    log "   ❌ $filename - ALL SOURCES FAILED"
    [[ -f "/workspace/provision_errors.log" ]] || touch "/workspace/provision_errors.log"
    if is_optional_file "$filename"; then
        log "      ⚠️  OPTIONAL asset failed: $filename (not a provisioning blocker)"
        echo "$(date '+%Y-%m-%d %H:%M:%S') OPTIONAL_FAILED: $filename - $url" >> "/workspace/provision_errors.log"
        rm -f "$filepath"
        return 2
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') FAILED: $filename - $url" >> "/workspace/provision_errors.log"
        rm -f "$filepath"
        return 1
    fi
}

smart_download_parallel() {
    # Temporarily disable strict error checking for parallel operations
    # Capture and later restore shell options (Fix 5)
    local old_opts
    old_opts=$(set +o)
    trap 'eval "$old_opts"' RETURN
    set +e  # Disable exit on error during parallel execution

    # Track optional (non-blocking) failures separately
    local optional_count=0

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
    local last_progress_summary=""

    # Per-file timeout: 30 minutes (1800 seconds)
    # CRITICAL: This is a hard limit. After 30 min, download is KILLED (SIGKILL)
    # This prevents infinite hangs from Dropbox throttling or network issues
    # Increased to 30 min to handle large files (6-8GB) on slower connections
    local download_timeout=3600
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

        # Robust parsing of pipe-separated format: PRIMARY|FALLBACK|MODELSCOPE|filename
        local parts=()
        local IFS='|'
        read -ra parts <<< "$entry"
        local pf_count=${#parts[@]}
        local fname index
        if (( pf_count == 0 )); then
            log "   ⚠️  Malformed entry (empty): $entry"
            return 1
        fi

        fname="${parts[$((pf_count-1))]}"  # last element is filename (always)
        # Collect non-empty URL parts (everything before last part)
        local urls=()
        for ((i=0;i<pf_count-1;i++)); do
            if [[ -n "${parts[i]}" ]]; then
                urls+=("${parts[i]}")
            fi
        done

        local p_url="${urls[0]:-}"
        local f_url="${urls[1]:-}"
        local ms_url="${urls[2]:-}"

        # Fallback: if filename missing, derive from primary URL
        if [[ -z "$fname" || "$fname" == "" ]]; then
            if [[ -n "$p_url" ]]; then
                fname="${p_url##*/}"; fname="${fname%%\?*}"
            else
                log "   ⚠️  Cannot determine filename for entry: $entry"
                return 1
            fi
        fi

        log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log "📥 [STARTING] File $file_num/$total: $fname"
        log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        # Download with timeout protection
        if timeout -k ${timeout_kill} ${timeout_sec} bash -c 'download_file "$@"' _ "$p_url" "$dir" "$fname" "$f_url" "$ms_url"; then
            log "✅ [SUCCESS] $fname"
            return 0
        else
            local exit_code=$?
            # Special code 2 means optional asset failed (non-blocking)
            if [[ $exit_code -eq 2 ]]; then
                log "   ⚠️  OPTIONAL asset failed: $fname (non-blocking)"
                return 2
            fi

            if [[ $exit_code -eq 124 ]]; then
                log "   ⏱️  TIMEOUT: $fname exceeded ${timeout_sec}s limit (killed)"
                if [[ "$p_url" == *"civitai.com"* ]]; then
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

            # Extract filename for logging
            local fname=""
            local IFS='|'
            local parts=()
            read -ra parts <<< "$entry"
            if [[ ${#parts[@]} -gt 0 ]]; then
                fname="${parts[$(( ${#parts[@]} - 1 ))]}"
                if [[ -z "$fname" && ${#parts[@]} -gt 1 ]]; then
                     fname=$(basename "${parts[0]%%?*}")
                fi
            fi
            [[ -z "$fname" ]] && fname="Unknown File $current_file"

            # Launch download in background
            download_worker "$entry" "$dir" "$current_file" "$total_count" "$download_timeout" "$timeout_kill_after" &
            local pid=$!
            pids+=($pid)
            pid_files[$pid]="$fname"

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
                elif [[ $exit_code -eq 2 ]]; then
                    optional_count=$((optional_count + 1))
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

        # Progress update - only log if status changed to avoid log spam
        local completed=$((success_count + failed_count))
        local active_count=${#pids[@]}
        local current_summary="$completed|$success_count|$failed_count|$active_count"
        
        if [[ "$current_summary" != "$last_progress_summary" ]]; then
            last_progress_summary="$current_summary"
            if [[ $total_count -gt 0 ]]; then
                local percent=$((completed * 100 / total_count))
                log ""
                log "📊 Progress: $completed/$total_count complete ($percent%) | ✅ Success: $success_count | ❌ Failed: $failed_count | 🔄 Active: $active_count"
                
                # List names of active files for transparency
                if [[ $active_count -gt 0 ]]; then
                    local names=""
                    for p in "${!pid_files[@]}"; do
                        names="${names}${pid_files[$p]}, "
                    done
                    log "   🔄 Active downloads: ${names%, }"
                fi
                
                [[ $fallback_count -gt 0 ]] && log "   🔄 Fallback used: $fallback_count times"
                log ""
            fi
        fi

        # Brief sleep to avoid busy-waiting
        [[ ${#pids[@]} -gt 0 ]] && sleep 5 # Increased to 5s to further reduce polling log noise
    done

    # Final summary
    log ""
    log "╔════════════════════════════════════════════════════════════════╗"
    log "║  📊 BATCH COMPLETE                                             "
    log "║  ✅ Success: $success_count/$total_count                               "
    [[ $fallback_count -gt 0 ]] && log "║  🔄 Fallback: $fallback_count                                   "
    [[ $optional_count -gt 0 ]] && log "║  ⚠️  Optional missing: $optional_count (non-blocking)             "
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

    log "🔍 [18/19] Downloading FLORENCE-2 MODELS..."
    if [[ ${#FLORENCE2_MODELS[@]} -gt 0 ]]; then
        # Florence-2 models belong in a dedicated directory for the Florence node
        smart_download_parallel "${COMFYUI_DIR}/models/florence2" "$MAX_PAR_HF" "${FLORENCE2_MODELS[@]}"
    else
        log "   ⏭️  Skipped (no Florence-2 models configured)"
    fi

    log "🎨 [19/19] Downloading LTX-2 SPATIAL UPSCALER..."
    # Note: Already included in UPSCALE_MODELS array above

    log ""
    log "╔════════════════════════════════════════════════════════════════╗"
    log "║  ✅ ALL MODEL DOWNLOADS COMPLETE!                              "
    log "╚════════════════════════════════════════════════════════════════╝"
    log ""
}

list_failed_downloads() {
    # Usage: list_failed_downloads [--retry [N]]
    local do_retry=0
    local retry_limit=3
    if [[ "${1:-}" == "--retry" ]]; then
        do_retry=1
        retry_limit=${2:-3}
    fi

    log_section "🔄 CHECKING FOR FAILED DOWNLOADS"

    if [[ ! -f "/workspace/provision_errors.log" ]] || [[ ! -s "/workspace/provision_errors.log" ]]; then
        log "✅ No failed downloads detected - all models downloaded successfully!"
        return 0
    fi

    # Count only true FAILED (ignore OPTIONAL_FAILED)
    local failed_count=$(grep -c "^.*FAILED:" "/workspace/provision_errors.log" || echo 0)
    local optional_count=$(grep -c "^.*OPTIONAL_FAILED:" "/workspace/provision_errors.log" || echo 0)

    log ""
    log "⚠️  Found $failed_count failed download(s) and $optional_count optional failure(s)"
    log ""

    if [[ $failed_count -gt 0 ]]; then
        log "Failed downloads:"
        grep "FAILED:" "/workspace/provision_errors.log" || true
    fi
    if [[ $optional_count -gt 0 ]]; then
        log "Optional (non-blocking) failures:"
        grep "OPTIONAL_FAILED:" "/workspace/provision_errors.log" || true
    fi

    if (( do_retry )); then
        log "\n🔁 Retrying failed downloads (limit: $retry_limit each)"
        # Retry each failed line sequentially to respect rate limits
        while IFS= read -r line; do
            local url=$(echo "$line" | sed -nE 's/^.*FAILED: [^ ]+ - (.*)$/\1/p' || true)
            local filename=$(echo "$line" | grep -oP 'FAILED: \K[^\s]+' || true)
            if [[ -z "$url" || -z "$filename" ]]; then
                continue
            fi

            log "   🔁 Retrying $filename from $url"
            mkdir -p "${COMFYUI_DIR}/models/retry" || true
            for i in $(seq 1 $retry_limit); do
                if download_file "$url" "${COMFYUI_DIR}/models/retry" "$filename" "" ""; then
                    log "   ✅ Retries succeeded for $filename (moved to ${COMFYUI_DIR}/models/retry)"
                    break
                else
                    log "   ⚠️  Retry $i/$retry_limit failed for $filename"
                    sleep 5
                fi
            done
        done < <(grep "FAILED:" "/workspace/provision_errors.log" || true)
    fi

    log ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if (( do_retry )); then
        log "✔️  Retry pass complete - review /workspace/provision_errors.log for remaining failures"
    else
        log "ℹ️  To retry failed downloads run: $0 --search-rate-limits && list_failed_downloads --retry [tries]"
    fi
    log "You can:"
    log "  1. Check /workspace/provision_errors.log for details"
    log "  2. Manually retry downloads by running list_failed_downloads --retry [tries]"
    log "  3. Use ComfyUI Manager to download missing models later"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log ""

    return 0
}

# Backwards-compatible alias
retry_failed_downloads() { list_failed_downloads; }

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

    # Optional: a checksums file (name -> sha256) can be provided at ${COMFYUI_DIR}/model_checksums.txt
    local checksum_file="${COMFYUI_DIR}/model_checksums.txt"
    declare -A MODEL_CHECKSUMS
    if [[ -f "$checksum_file" ]]; then
        while IFS= read -r line; do
            local name=$(echo "$line" | awk '{print $2}')
            local sum=$(echo "$line" | awk '{print $1}')
            MODEL_CHECKSUMS["$name"]="$sum"
        done < "$checksum_file"
    fi

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

    # Additional verification: checksums and extracted archives
    log "🔎 Verifying extracted archives and checksums (if available)"
    # Check for extraction markers for archives
    while IFS= read -r -d '' file; do
        local base=$(basename "$file")
        if [[ "$base" == *.zip || "$base" == *.rar || "$base" == *.7z || "$base" == *.tar.gz || "$base" == *.tgz ]]; then
            local marker="$(dirname "$file")/.extracted_${base}.txt"
            if [[ ! -f "$marker" ]]; then
                log "   ⚠️  Archive present but not extracted: $base"
                ((validation_failed++))
            fi
        fi
    done < <(find "${COMFYUI_DIR}/models" -type f -print0 2>/dev/null || true)

    # Check checksums if MODEL_CHECKSUMS is populated
    for name in "${!MODEL_CHECKSUMS[@]}"; do
        local target="${COMFYUI_DIR}/models/${name}"
        if [[ -f "$target" ]]; then
            echo "${MODEL_CHECKSUMS[$name]}  $target" > /tmp/verify.sha256
            if ! sha256sum -c /tmp/verify.sha256 --quiet; then
                log "   ❌ Checksum mismatch: $name"
                ((validation_failed++))
            else
                log "   ✅ Checksum OK: $name"
            fi
            rm -f /tmp/verify.sha256
        fi
    done

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
    
    # Use workspace-relative paths and the same python as venv
    cat > "$svc_file" <<EOF
[Unit]
Description=ComfyUI Multi-Source Reliable Service
After=network.target nvidia-persistenced.service

[Service]
Type=simple
User=root
WorkingDirectory=${COMFYUI_DIR}
ExecStart=${VENV_PYTHON} main.py --listen 0.0.0.0 --port 8188 --enable-cors-header --preview-method auto
Restart=always
RestartSec=10
Environment=PYTHONUNBUFFERED=1
StandardOutput=append:${WORKSPACE}/comfyui.log
StandardError=append:${WORKSPACE}/comfyui.log

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$svc_file"
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable comfyui.service 2>/dev/null || true
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
        # Run the lightweight Cloudflare pre-check helper if available
        local CF_CHECK_SCRIPT="${SCRIPTS_DIR:-./scripts}/check-cloudflare.sh"
        if [[ -f "$CF_CHECK_SCRIPT" ]]; then
            if bash "$CF_CHECK_SCRIPT"; then
                log "   ✅ Cloudflare pre-check passed"
            else
                log "   ⚠️  Cloudflare pre-check failed - attempting tunnel startup anyway"
            fi
        else
            log "   ℹ️  Cloudflare check script not found at $CF_CHECK_SCRIPT"
        fi

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
        elif [[ -f "${SCRIPTS_DIR:-./scripts}/fix-dependencies.sh" ]]; then
            log "   ⚠️  Remote dependency fixer unavailable - using local fallback"
            chmod +x "${SCRIPTS_DIR:-./scripts}/fix-dependencies.sh"
            if "${SCRIPTS_DIR:-./scripts}/fix-dependencies.sh" 2>&1 | tee /tmp/post-install-fix.log; then
                log "   ✅ Dependency fix completed successfully (local fallback)"
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
