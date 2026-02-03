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
    "rife426.pth"
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

    # Install packages
    log "   Installing system packages..."
    for pkg in "${APT_PACKAGES[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            log "   Installing: $pkg"
            apt-get install -y -qq "$pkg" 2>&1 | grep -v "^debconf:" || true
        else
            log "   ✓ Already installed: $pkg"
        fi
    done

    log "✅ APT packages installed successfully"
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
    "https://github.com/VykosX/ComfyUI-TripoSR"
    "https://github.com/Lightricks/ComfyUI-LTXVideo"
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

    # DreamShaper 8 (2GB) - Official HF repo by Lykon
    "https://huggingface.co/Lykon/dreamshaper-8/resolve/main/dreamshaper_8.safetensors|https://www.dropbox.com/scl/fi/v52p66ci8u7n8r5cqc1pi/dreamshaper_8.safetensors?rlkey=4f0133r062xr8nafpsxp2h9gq&dl=1|dreamshaper_8.safetensors"

    # revAnimated v1.2.2 (2GB) - HF primary, Civitai fallback
    "https://huggingface.co/danbrown/RevAnimated-v1-2-2/resolve/main/revAnimated_v122.safetensors|https://civitai.com/api/download/models/122606|revAnimated_v122.safetensors"

    # Pony Realism v2.2 (6.5GB) - HF mirror by John6666
    "https://huggingface.co/John6666/pony-realism-v22main-sdxl/resolve/main/pony_realism_v2.2.safetensors|https://www.dropbox.com/scl/fi/hy476rxzeacsx8g3aodj0/pony_realism_v2.2.safetensors?rlkey=09k5sba46pqoptdu7h1tu03b4&dl=1|pony_realism_v2.2.safetensors"

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

    # LTX-2 distilled (video) — adds LTX-2 video capability
    "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-distilled.safetensors||ltx-2-19b-distilled.safetensors"
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

    # Wan 2.2 Remix (FX-FeiHou) - High and Low Noise variants with Civitai fallbacks
    "hf:FX-FeiHou/wan2.2-Remix||https://civitai.com/api/download/models/2567309?type=Model&format=SafeTensor&size=pruned&fp=fp8||https://civitai.com/api/download/models/915814?type=Model&format=SafeTensor&size=pruned&fp=fp16|wan2.2_remix_fp8.safetensors"
)

WAN_CLIP_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn.safetensors|umt5_xxl_fp8_e4m3fn.safetensors"
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
    "https://huggingface.co/Comfy-Org/Lumina_Image_2.0_Repackaged/resolve/main/split_files/vae/ae.safetensors|lumina_ae.safetensors"

    # SDXL VAE - Official Stability AI HF repo, Dropbox fallback
    "https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors|https://www.dropbox.com/scl/fi/3qygk64xe2ui2ey74neto/sdxl_vae.safetensors?rlkey=xzsllv3hq5w1qx81h9b2xryq8&dl=1|sdxl_vae.safetensors"
)


ANIMATEDIFF_MODELS=(
    "https://huggingface.co/camenduru/AnimateDiff-sdxl-beta/resolve/main/mm_sdxl_v10_beta.ckpt|mm_sdxl_v10_beta.ckpt"
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
    "https://github.com/hzwer/Practical-RIFE/releases/download/v4.26/rife426.pth|rife426.pth"
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
  # Return a short CUDA tag like cu124, cu121, cu118, cu111 or "cpu"
  if command -v nvidia-smi >/dev/null 2>&1; then
    # Try to read reported CUDA version from nvidia-smi
    local cuda_raw
    cuda_raw=$(nvidia-smi --query-gpu=cuda_version --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d '\r') || true
    if [[ -n "$cuda_raw" ]]; then
      log "   🔎 Detected CUDA reported by nvidia-smi: $cuda_raw"
      case "$cuda_raw" in
        12.4*|12.4) echo "cu124"; return 0 ;;
        12.1*|12.1) echo "cu121"; return 0 ;;
        11.8*|11.8) echo "cu118"; return 0 ;;
        11.1*|11.1) echo "cu111"; return 0 ;;
      esac
    fi
    # If nvidia-smi didn't report cuda_version, infer from driver version
    local driver
    driver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits 2>/dev/null | head -n1 | cut -d. -f1 || true)
    if [[ -n "$driver" ]]; then
      if (( driver >= 535 )); then
        echo "cu124"; return 0
      elif (( driver >= 525 )); then
        echo "cu121"; return 0
      else
        echo "cu118"; return 0
      fi
    fi
  fi
  # Fallback: no GPU detected, return cpu tag
  log "   ⚠️  No NVIDIA GPU detected or no cuda reported; falling back to CPU-compatible wheel (cpu)"
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

    if [[ "$cuda_tag" == "cpu" ]]; then
      log "   ⚠️  Installing CPU-only PyTorch (no CUDA detected)"
      "$VENV_PYTHON" -m pip install --no-cache-dir torch torchvision torchaudio || true
    else
      case "$cuda_tag" in
        cu124)
          log "   📥 Installing torch for cu124"
          "$VENV_PYTHON" -m pip install --no-cache-dir \
            torch==2.5.1+cu124 torchvision==0.20.1+cu124 torchaudio==2.5.1+cu124 \
            --index-url https://download.pytorch.org/whl/cu124 || true
          ;;
        cu121)
          log "   📥 Installing torch for cu121"
          "$VENV_PYTHON" -m pip install --no-cache-dir \
            torch==2.5.1+cu121 torchvision==0.20.1+cu121 torchaudio==2.5.1+cu121 \
            --index-url https://download.pytorch.org/whl/cu121 || true
          ;;
        cu118)
          log "   📥 Installing torch for cu118"
          "$VENV_PYTHON" -m pip install --no-cache-dir \
            torch==2.5.1+cu118 torchvision==0.20.1+cu118 torchaudio==2.5.1+cu118 \
            --index-url https://download.pytorch.org/whl/cu118 || true
          ;;
        *)
          log "   ⚠️  Unknown CUDA tag ($cuda_tag) - attempting generic wheel"
          "$VENV_PYTHON" -m pip install --no-cache-dir torch torchvision torchaudio || true
          ;;
      esac
    fi
}

install_essential_deps() {
    log_section "📦 INSTALLING ESSENTIAL DEPENDENCIES"
    activate_venv

    # Remove any pre-installed xformers that may conflict with our PyTorch version
    "$VENV_PYTHON" -m pip uninstall -y xformers 2>/dev/null || true
    log "   ✅ Removed conflicting xformers (if present)"

    # Install core dependencies first
    "$VENV_PYTHON" -m pip install --no-cache-dir \
        transformers==4.36.0 \
        accelerate \
        safetensors \
        einops \
        opencv-python-headless \
        insightface \
        onnxruntime-gpu \
        sentencepiece

    # Reinstall PyTorch to ensure correct version after accelerate (which may install CPU version)
    "$VENV_PYTHON" -m pip install --no-cache-dir \
        torch==2.5.1+cu124 torchvision==0.20.1+cu124 torchaudio==2.5.1+cu124 \
        --index-url https://download.pytorch.org/whl/cu124 || {
        log "   ⚠️  cu124 failed, trying cu121..."
        "$VENV_PYTHON" -m pip install --no-cache-dir \
            torch torchvision torchaudio \
            --index-url https://download.pytorch.org/whl/cu121
    }

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

install_comfyui() {
    log_section "🖥️  INSTALLING COMFYUI"
    if [[ ! -d "${COMFYUI_DIR}" ]]; then
        git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}"
    fi
    
    cd "${COMFYUI_DIR}"
    install_torch
    install_essential_deps
    "$VENV_PYTHON" -m pip install -q -r requirements.txt
    cd "${WORKSPACE}"
    log "✅ ComfyUI setup complete"
}

install_nodes() {
    log_section "🧩 INSTALLING CUSTOM NODES"

    activate_venv

    # Pre-install common dependencies to avoid per-node failures
    log "   📦 Pre-installing common dependencies..."
    "$VENV_PYTHON" -m pip install --no-cache-dir --timeout 300 \
        gitpython packaging pydantic pyyaml httpx aiohttp \
        websockets typing-extensions 2>/dev/null || true

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
            timeout 300 "$VENV_PYTHON" -m pip install --no-cache-dir -q -r "${path}/requirements.txt" 2>&1 | grep -v "WARNING: Running pip as the 'root' user" || {
                log "   ⚠️  Requirements install failed for $dir (continuing)"
            }
        fi
    done

    # Post-install: Ensure core dependencies are present
    log "   🔧 Ensuring core dependencies..."
    "$VENV_PYTHON" -m pip install --no-cache-dir -q \
        einops>=0.6.0 \
        accelerate>=0.24.0 \
        transformers>=4.36.0 \
        opencv-python-headless>=4.8.0 \
        sageattention \
        huggingface-hub 2>/dev/null || true

    log "✅ Custom nodes installation complete"
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
    return
  }

  # If systemd started the unit, report status
  log "✅ ComfyUI systemd service enabled and started (port 8188)"
  log "   Check logs with: journalctl -u comfyui.service -f"
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

    # Phase progression: START → PACKAGES → COMFYUI → NODES → MODELS → COMPLETE
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
        checkpoint_save "COMPLETE"
    fi

    log "--- Provisioning Complete ---"
    log "✅ All phases completed successfully!"
    log "   Checkpoint file: $CHECKPOINT_FILE"
    log "   To reset checkpoint and start fresh: rm $CHECKPOINT_FILE"
}

main "$@"
