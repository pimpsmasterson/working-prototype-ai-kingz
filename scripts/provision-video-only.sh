#!/bin/bash
# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║   🎬 AI KINGS COMFYUI - VIDEO WORKFLOW PROVISIONER v3.5                       ║
# ║                                                                               ║
# ║   v3.5 NEW:                                                                   ║
# ║   ✓ torchaudio Fix: Auto-detects PyTorch version & installs matching torchaudio║
# ║   ✓ UMT5 Compatibility: Creates symlinks for all naming variants              ║
# ║   ✓ PyTorch 2.10 Support: Fixes "undefined symbol" errors on newer images     ║
# ║                                                                               ║
# ║   v3.4 CHANGES:                                                               ║
# ║   ✓ Token Validation: HF tokens validated at startup (prevents 401 blocking)  ║
# ║   ✓ Smart Auth: Invalid tokens skipped for public repos (fixes Kijai access)  ║
# ║   ✓ Token Cleanup: Auto-strips whitespace/newlines from tokens                ║
# ║                                                                               ║
# ║   v3.3 CHANGES:                                                               ║
# ║   ✓ NSFW Refactoring: Organized NSFW & Flux models into standardized arrays   ║
# ║   ✓ Batch Standardization: Standardized all model categories via download_batch║
# ║   ✓ Audit Compliance: Verified all filenames against Video Workflow Audit     ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

VERSION="v3.5"
PROVISIONER_SIGNATURE="🎬 AI KINGS COMFYUI - MASTER VIDEO PROVISIONER ${VERSION}"

set -uo pipefail

PROVISION_ALLOW_MISSING_ASSETS=${PROVISION_ALLOW_MISSING_ASSETS:-true}

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════
LOG_FILE="/tmp/provision_video.log"
log() { echo "$(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE"; }
log_err() { echo "$(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE" >&2; }
log_section() { log ""; log "═══════════════════════════════════════════════════════════════"; log "$*"; log "═══════════════════════════════════════════════════════════════"; }

display_banner() {
    echo -e "\e[1;36m"
    echo "  ╔═══════════════════════════════════════════════════════════════════════════╗"
    echo "  ║                                                                           ║"
    echo "  ║   🎬 AI KINGS COMFYUI - MASTER VIDEO PROVISIONER ${VERSION}             ║"
    echo "  ║                                                                           ║"
    echo "  ╚═══════════════════════════════════════════════════════════════════════════╝"
    echo -e "\e[0m"
}

cleanup_on_exit() {
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        echo "   ✅ Provisioning script completed"
        return 0
    fi
    echo "⚠️  Error detected (exit code: $exit_code) - cleaning up..."
    for p in $(jobs -p); do kill -15 "$p" 2>/dev/null || true; done
    sleep 2
    for p in $(jobs -p); do kill -9 "$p" 2>/dev/null || true; done
    exit $exit_code
}
trap cleanup_on_exit EXIT INT TERM

# ═══════════════════════════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════════════════════════
# MODEL DEFINITIONS - v3.2 PRODUCTION (ALL VARIANTS)
# ═══════════════════════════════════════════════════════════════════════════════
#
# URL FORMAT: "PRIMARY|FALLBACK1|FALLBACK2|DROPBOX|filename"
#
# To add Dropbox fallback links:
# 1. Upload models to Dropbox: /AI_KINGS_HUB_2026/
# 2. Generate links: node scripts/dropbox_create_links.js /AI_KINGS_HUB_2026/folder
# 3. Add link to 4th slot (before filename)
#
# Dropbox links use single-connection mode (multi-connection = account ban)
# ═══════════════════════════════════════════════════════════════════════════════

# Wan 2.1 T2V - fp16 (Best Quality) & fp8 (Speed/Low VRAM)
WAN_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_t2v_14B_fp16.safetensors|https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-T2V-14B_fp16.safetensors|https://modelscope.cn/api/v1/models/Wan-AI/Wan2.1-T2V-14B/repo?Revision=master&FilePath=diffusion_pytorch_model.fp16.safetensors||wan2.1_t2v_14B_fp16.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_t2v_14B_fp8_e4m3fn.safetensors|https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-T2V-14B_fp8_e4m3fn.safetensors|||wan2.1_t2v_14B_fp8.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_t2v_1.3B_fp16.safetensors|||https://www.dropbox.com/scl/fi/ne4jz4ctfs3st69q7l7an/wan2.1_t2v_1.3B_fp16.safetensors?rlkey=8ynhktmzvwr2cw5j5cn6yt8kb&dl=1|wan2.1_t2v_1.3B_fp16.safetensors"
)

# Wan 2.2 T2V (High/Low Noise)
WAN22_T2V_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors|||https://www.dropbox.com/scl/fi/f8zh8wow6zp4ykwww739l/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors?rlkey=9pb3q3d1ztflf3rj9uxpqgt7b&dl=1|wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors|||https://www.dropbox.com/scl/fi/89t087ntbjn655euhb7tm/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors?rlkey=2dpggbsykt5ojkmgsvcfuc4zf&dl=1|wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors"
)

# Wan 2.1 & 2.2 I2V / TI2V
# NOTE: I2V models have RESOLUTION in the filename (480p/720p) unlike T2V
WAN_I2V_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_i2v_480p_14B_fp16.safetensors|https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors|||wan2.1_i2v_480p_14B_fp16.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_i2v_720p_14B_fp16.safetensors|https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-720P_fp8_e4m3fn.safetensors|||wan2.1_i2v_720p_14B_fp16.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors|||https://www.dropbox.com/scl/fi/khl8cgdoo2sfitmcs4936/wan2.2_ti2v_5B_fp16.safetensors?rlkey=t7ov4j7m272kw0ht8cn7tex3n&dl=1|wan2.2_ti2v_5B_fp16.safetensors"
    # Wan 2.2 I2V High/Low Noise (for dual-stage I2V workflows)
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors||||wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors||||wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors"
)

# LTX-Video - v0.9.8 (Newest/Stable)
# NOTE: Filename changed from ltx-video-2b-v0.9.X to ltxv-2b-0.9.X-distilled
# NOTE: Comfy-Org/ltx-video is GATED (requires auth), avoid as primary
LTX_MODELS=(
    "https://huggingface.co/Lightricks/LTX-Video/resolve/main/ltxv-2b-0.9.8-distilled-fp8.safetensors|https://huggingface.co/Lightricks/LTX-Video/resolve/main/ltxv-2b-0.9.8-distilled.safetensors|https://huggingface.co/Lightricks/LTX-Video/resolve/main/ltx-video-2b-v0.9.5.safetensors|https://www.dropbox.com/scl/fi/h9f6rfcai1z773y1bh9vr/ltx-2-19b-dev-fp8.safetensors?rlkey=r174jxa1jyipl8mi0hg8pb8vp&dl=1|ltxv-2b-0.9.8-distilled-fp8.safetensors"
)

TEXT_ENCODERS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors|https://huggingface.co/wangkanai/wan21-fp8-encoders/resolve/main/umt5-xxl-encoder-fp8.safetensors||https://www.dropbox.com/scl/fi/uwj70pf0sjzdy1pj9tlwv/umt5_xxl_fp8_e4m3fn_scaled.safetensors?rlkey=q438pvj5dbpphofvciku3d00p&dl=1|umt5_xxl_fp8_e4m3fn_scaled.safetensors"
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors|https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/text_encoder/model.safetensors||https://www.dropbox.com/scl/fi/ywgwcq3ivazb32ffgkx4k/clip_l.safetensors?rlkey=rm1xyudlemcabaz6fio8mt66m&dl=1|clip_l.safetensors"
    "https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors|||https://www.dropbox.com/scl/fi/r1v099a5cy6xvco305x5l/gemma_3_12B_it_fp4_mixed.safetensors?rlkey=ssfhbiwzrodh99ygffidwlozj&dl=1|gemma_3_12B_it_fp4_mixed.safetensors"
)

CLIP_VISION=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors|https://huggingface.co/calcuis/wan-gguf/resolve/main/clip_vision_h.safetensors||https://www.dropbox.com/scl/fi/d5z92rjv3uvd8e4opjqa8/clip_vision_h.safetensors?rlkey=ifhvpdrvt8c0cbj6js4hk3fld&dl=1|clip_vision_h.safetensors"
)

LIGHTNING_LORAS=(
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/Wan21_T2V_14B_lightx2v_4steps_lora_v1.0.safetensors|https://huggingface.co/lightx2v/Wan2.1-Lightning/resolve/main/wan2.1_t2v_14B_lightx2v_4steps_lora_v1.0.safetensors||https://www.dropbox.com/scl/fi/4x7caiyps977bu7397kxy/wan2.2_t2v_lightx2v_4steps_lora_v1.1_high_noise.safetensors?rlkey=pgkweq8d0tte4moar52vxflmy&dl=1|wan2.1_lightning_t2v.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_low_noise.safetensors|||https://www.dropbox.com/scl/fi/cmiquju7wznfg8p0nxqfb/wan2.2_t2v_lightx2v_4steps_lora_v1.1_low_noise.safetensors?rlkey=wuxadzio6y4tx7plwhejzz4v5&dl=1|wan2.2_t2v_lightx2v_4steps_lora_v1.1_low_noise.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors|||https://www.dropbox.com/scl/fi/my7is5kcqyrawpskgv0wh/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors?rlkey=eszr3agmd8qj0eazolo1qs7zh&dl=1|wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors|||https://www.dropbox.com/scl/fi/um1aou5rco7yletairukw/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors?rlkey=q2tqcgc9ml6jar6qkvz49imxe&dl=1|wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors"
    "https://huggingface.co/Lightricks/LTX-2-19b-LoRA-Camera-Control-Dolly-Left/resolve/main/ltx-2-19b-lora-camera-control-dolly-left.safetensors|||https://www.dropbox.com/scl/fi/n7761g7gnt0mxqcirgq69/ltx-2-19b-lora-camera-control-dolly-left.safetensors?rlkey=gvwnv8hhsznqmjxi91237rgdu&dl=1|ltx-2-19b-lora-camera-control-dolly-left.safetensors"
    "https://huggingface.co/Lightricks/LTX-2-19b-distilled-LoRA-384/resolve/main/ltx-2-19b-distilled-lora-384.safetensors|||https://www.dropbox.com/scl/fi/s6as19wgpnh335it8m1tb/ltx-2-19b-distilled-lora-384.safetensors?rlkey=e8lcalz3lxrq8i608ufvk1k15&dl=1|ltx-2-19b-distilled-lora-384.safetensors"
)

VAE_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors|||https://www.dropbox.com/scl/fi/bde2ylv6hz9grfb0s28k9/wan2.2_vae.safetensors?rlkey=n0bz7aujhuy5ktca5okz8zqlo&dl=1|wan2.2_vae.safetensors"
    "https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors|https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors||https://www.dropbox.com/scl/fi/qcz53uu64i7ejrap4p833/sdxl_vae.safetensors?rlkey=67szydazzwgk5yc79mt177bfb&dl=1|sdxl_vae.safetensors"
    "https://huggingface.co/stabilityai/stable-diffusion-3-medium/resolve/main/sd3_medium_vae.safetensors|||https://www.dropbox.com/scl/fi/4x5n66inw1uv5a4secgha/ae.safetensors?rlkey=yfenqvov9my2flv58o03cvpz8&dl=1|ae.safetensors"
)

UPSCALER_MODELS=(
    "https://huggingface.co/Lightricks/LTX-Video-Playground/resolve/main/ltx-2-spatial-upscaler-x2-1.0.safetensors|||https://www.dropbox.com/scl/fi/gpsdpov5wdvt4jonvgb45/ltx-2-spatial-upscaler-x2-1.0.safetensors?rlkey=2hy1tzokmth7ofu7375vjabms&dl=1|ltx-2-spatial-upscaler-x2-1.0.safetensors"
)

# Depth models
DEPTH_MODELS=(
    "https://huggingface.co/Comfy-Org/lotus/resolve/main/lotus-depth-d-v1-1.safetensors|https://huggingface.co/TTPlanet/TTPLanet_SDXL_Controlnet_Tile_Realistic/resolve/main/TTPLANET_Controlnet_Tile_realistic_v2_fp16.safetensors|||lotus-depth-d-v1-1.safetensors"
)

# 🔞 NSFW 2026 VIDEO ENGINES
NSFW_MODELS=(
    "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors|||https://www.dropbox.com/scl/fi/ozryt7gspxc4ntyox1p5x/Wan2.2_Remix_NSFW_i2v_14b_low_fp8.safetensors?rlkey=uuyzswq52nvh7t0fnevbfjx3n&dl=1|Wan2.2_Remix_NSFW_i2v_14b_low_fp8.safetensors"
    "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors|||https://www.dropbox.com/scl/fi/o2szjmtrastb6wns1c3ry/Wan2.2_Remix_NSFW_i2v_14b_high_fp8.safetensors?rlkey=blueoxw5tmmim5d849jc6pu2x&dl=1|Wan2.2_Remix_NSFW_i2v_14b_high_fp8.safetensors"
    "https://huggingface.co/Phr00t/WAN2.2-14B-Rapid-AllInOne/resolve/main/wan2.2-i2v-rapid-aio.safetensors||||wan2.2-i2v-rapid-aio.safetensors"
)

# FLUX.1 Models
FLUX_MODELS=(
    "https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/flux1-dev-fp8.safetensors|||https://www.dropbox.com/scl/fi/r7p77wp4b0nkg5gccb02p/flux1-dev-fp8.safetensors?rlkey=3isee9i8b124mdyr0ah73114l&dl=1|flux1-dev-fp8.safetensors"
)

NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/kijai/ComfyUI-WanVideoWrapper"
    "https://github.com/Lightricks/ComfyUI-LTXVideo"
    "https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
    "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/ssitu/ComfyUI_UltimateSDUpscale"
    "https://github.com/kijai/ComfyUI-Florence2"
    "https://github.com/yolain/ComfyUI-Easy-Use"
    "https://github.com/cubiq/ComfyUI_essentials"
)

# ═══════════════════════════════════════════════════════════════════════════════

setup_swap() {
    log_section "🧠 CONFIGURE SWAP (OOM Protection)"
    if swapon --show | grep -q "/workspace/swapfile"; then
        log "   ✅ Swap already active"
        return 0
    fi
    local total_ram=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $total_ram -lt 40 ]]; then
        log "   ⚠️  Low RAM detected ($total_ram GB). Creating 32GB swapfile..."
        swapoff -a 2>/dev/null || true
        fallocate -l 32G /workspace/swapfile || dd if=/dev/zero of=/workspace/swapfile bs=1M count=32768
        chmod 600 /workspace/swapfile && mkswap /workspace/swapfile && swapon /workspace/swapfile
        log "   ✅ 32GB Swap activated"
    fi
}

install_apt_packages() {
    log_section "📦 INSTALLING SYSTEM PACKAGES"
    apt-get update
    # Try both package names: Ubuntu 24.04+ uses t64 suffix
    apt-get install -y apt-utils aria2 wget curl git git-lfs ffmpeg libgl1 \
        python3-pip python3-venv build-essential \
        libjpeg-dev libpng-dev libtiff-dev rclone
    apt-get install -y libtcmalloc-minimal4t64 2>/dev/null || \
        apt-get install -y libtcmalloc-minimal4 2>/dev/null || \
        log "   ⚠️  TCMalloc not available in apt repos"
    log "✅ System packages ready"
}

activate_venv() {
    if [[ -f "${WORKSPACE}/venv/bin/activate" ]]; then
        source "${WORKSPACE}/venv/bin/activate"
        VENV_PYTHON="${WORKSPACE}/venv/bin/python3"
    else
        log "📦 Creating virtual environment..."
        python3 -m venv --system-site-packages "${WORKSPACE}/venv"
        source "${WORKSPACE}/venv/bin/activate"
        VENV_PYTHON="${WORKSPACE}/venv/bin/python3"
    fi
}

install_torch() {
    log_section "🧠 INSTALLING PYTORCH + TORCHAUDIO (Version-Matched)"
    activate_venv

    # v3.5 FIX: Detect existing PyTorch version and install MATCHING torchaudio
    # This prevents the "undefined symbol" error when torchaudio mismatches torch

    local EXISTING_TORCH_VERSION=""
    EXISTING_TORCH_VERSION=$("$VENV_PYTHON" -c "import torch; print(torch.__version__.split('+')[0])" 2>/dev/null || echo "")

    if [[ -n "$EXISTING_TORCH_VERSION" ]]; then
        log "   📦 Detected existing PyTorch: $EXISTING_TORCH_VERSION"

        # Extract major.minor version for torchaudio matching
        local TORCH_MAJOR_MINOR=$(echo "$EXISTING_TORCH_VERSION" | grep -oE '^[0-9]+\.[0-9]+')

        # If PyTorch 2.10.x is installed (from base image), use matching torchaudio
        if [[ "$TORCH_MAJOR_MINOR" == "2.10" ]]; then
            log "   🔧 PyTorch 2.10.x detected - installing matching torchaudio..."
            "$VENV_PYTHON" -m pip uninstall torchaudio -y 2>/dev/null || true
            "$VENV_PYTHON" -m pip install torchaudio --index-url https://download.pytorch.org/whl/cu128 --force-reinstall 2>&1 | tee -a "$LOG_FILE" || {
                log "   ⚠️  torchaudio install failed, trying cu124..."
                "$VENV_PYTHON" -m pip install torchaudio --index-url https://download.pytorch.org/whl/cu124 --force-reinstall 2>&1 | tee -a "$LOG_FILE"
            }
        elif [[ "$TORCH_MAJOR_MINOR" == "2.6" ]]; then
            log "   ✅ PyTorch 2.6.x detected - installing matching torchaudio 2.6.0..."
            "$VENV_PYTHON" -m pip uninstall torchaudio -y 2>/dev/null || true
            "$VENV_PYTHON" -m pip install torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu124 --force-reinstall 2>&1 | tee -a "$LOG_FILE"
        else
            log "   ⚠️  Unknown PyTorch version ($EXISTING_TORCH_VERSION) - installing latest matching torchaudio..."
            "$VENV_PYTHON" -m pip uninstall torchaudio -y 2>/dev/null || true
            "$VENV_PYTHON" -m pip install torchaudio --force-reinstall 2>&1 | tee -a "$LOG_FILE"
        fi
    else
        # No existing PyTorch - fresh install
        log "   🚀 No PyTorch found - installing PyTorch 2.6.0 stable with CUDA 12.4..."
        "$VENV_PYTHON" -m pip uninstall torch torchvision torchaudio -y 2>/dev/null || true
        "$VENV_PYTHON" -m pip install torch==2.6.0 torchvision==0.21.0 torchaudio==2.6.0 \
            --index-url https://download.pytorch.org/whl/cu124 \
            --force-reinstall || {
            log_err "   ❌ PyTorch stable install failed, trying latest stable..."
            "$VENV_PYTHON" -m pip install torch torchvision torchaudio \
                --index-url https://download.pytorch.org/whl/cu124 || {
                log_err "   ❌ PyTorch installation failed completely"
                return 1
            }
        }
    fi

    # Verify installation
    "$VENV_PYTHON" -c "import torch; print(f'✅ PyTorch {torch.__version__}, CUDA {torch.version.cuda}, Available: {torch.cuda.is_available()}')" | tee -a "$LOG_FILE"
    "$VENV_PYTHON" -c "import torchaudio; print(f'✅ torchaudio {torchaudio.__version__}')" 2>&1 | tee -a "$LOG_FILE" || log "   ⚠️  torchaudio verification failed"
}

install_dependencies() {
    log_section "📦 INSTALLING PYTHON DEPENDENCIES"
    activate_venv

    # Force numpy<2 first to avoid conflicts with system numpy 2.4
    log "   🚀 Pinning numpy<2 to avoid compatibility issues..."
    "$VENV_PYTHON" -m pip install "numpy<2" --force-reinstall --quiet 2>&1 | tee -a "$LOG_FILE"

    local deps=(
        "transformers>=4.38.0" "accelerate>=0.26.0" "safetensors>=0.4.0"
        "einops>=0.7.0" "opencv-python-headless" "huggingface-hub"
        "timm" "scipy" "pillow" "tqdm" "sqlalchemy>=2.0.0"
        "aiohttp>=3.9.0" "typing-extensions>=4.8.0" "moviepy" "imageio-ffmpeg"
        "onnxruntime-gpu" "opencv-contrib-python-headless"
        "gguf" "scikit-image" "sentencepiece" "cupy-cuda12x"
        "diffusers>=0.32.0"
        "av>=14.2.0"
    )
    log "   🚀 Installing core dependencies..."
    "$VENV_PYTHON" -m pip install "${deps[@]}" 2>&1 | tee -a "$LOG_FILE"

    # Install xformers separately (optional but recommended for memory efficiency)
    # v3.1.1: REMOVED xformers (Causes Torch 2.10 conflict/timeout)
    # "$VENV_PYTHON" -m pip install xformers 2>&1 | tee -a "$LOG_FILE" || log "   ⚠️  xformers failed, continuing..."

    # CRITICAL: Force numpy<2 again at the very end to overwrite any upgrades from other packages
    log "   🔧 Enforcing numpy<2 compatibility..."
    "$VENV_PYTHON" -m pip install "numpy<2" --force-reinstall 2>&1 | tee -a "$LOG_FILE"

    # v3.5 FIX: Verify torchaudio still works after dependency installs
    # Some packages can break torchaudio by pulling incompatible versions
    log "   🔧 Verifying torchaudio compatibility..."
    if ! "$VENV_PYTHON" -c "import torchaudio" 2>/dev/null; then
        log "   ⚠️  torchaudio broken - reinstalling matched version..."
        local TORCH_VER=$("$VENV_PYTHON" -c "import torch; print(torch.__version__.split('+')[0])" 2>/dev/null || echo "2.6.0")
        local TORCH_MAJOR_MINOR=$(echo "$TORCH_VER" | grep -oE '^[0-9]+\.[0-9]+')

        "$VENV_PYTHON" -m pip uninstall torchaudio -y 2>/dev/null || true

        if [[ "$TORCH_MAJOR_MINOR" == "2.10" ]]; then
            "$VENV_PYTHON" -m pip install torchaudio --index-url https://download.pytorch.org/whl/cu128 --force-reinstall --quiet 2>&1 | tee -a "$LOG_FILE"
        else
            "$VENV_PYTHON" -m pip install torchaudio==${TORCH_VER} --index-url https://download.pytorch.org/whl/cu124 --force-reinstall --quiet 2>&1 | tee -a "$LOG_FILE" || \
            "$VENV_PYTHON" -m pip install torchaudio --force-reinstall --quiet 2>&1 | tee -a "$LOG_FILE"
        fi
    fi

    # Final verification
    "$VENV_PYTHON" -c "import torch; import torchaudio; print(f'✅ torch={torch.__version__}, torchaudio={torchaudio.__version__}')" 2>&1 | tee -a "$LOG_FILE" || \
        log_err "   ⚠️  torchaudio still broken - audio nodes will not load"

    log "   ✅ Core dependencies ready"
}

# ═══════════════════════════════════════════════════════════════════════════════
# TOKEN VALIDATION & DOWNLOAD FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

# Global flag: Set to "invalid" if HF token fails validation
HF_TOKEN_STATUS="unknown"

validate_hf_token() {
    local HF_TOKEN="${HUGGINGFACE_HUB_TOKEN:-${HF_TOKEN:-}}"

    if [[ -z "$HF_TOKEN" ]]; then
        log "   ⚠️  No Hugging Face token set (HUGGINGFACE_HUB_TOKEN)"
        log "      Public models will work, gated models will fail"
        HF_TOKEN_STATUS="none"
        return 0
    fi

    # Clean token (remove whitespace/newlines that break auth)
    HF_TOKEN=$(echo "$HF_TOKEN" | tr -d '[:space:]')
    export HUGGINGFACE_HUB_TOKEN="$HF_TOKEN"
    export HF_TOKEN="$HF_TOKEN"

    log "   🔑 Validating Hugging Face token..."

    # Test against the whoami endpoint
    local response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer ${HF_TOKEN}" \
        "https://huggingface.co/api/whoami" 2>/dev/null)

    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')

    if [[ "$http_code" == "200" ]]; then
        local username=$(echo "$body" | grep -oP '"name"\s*:\s*"\K[^"]+' | head -1)
        log "   ✅ HF Token valid (user: ${username:-unknown})"
        HF_TOKEN_STATUS="valid"
        return 0
    elif [[ "$http_code" == "401" ]]; then
        log_err "   ❌ HF Token INVALID (401 Unauthorized)"
        log_err "      Get a new token at: https://huggingface.co/settings/tokens"
        HF_TOKEN_STATUS="invalid"
        # Don't fail - we'll try without auth for public repos
        return 0
    else
        log "   ⚠️  HF Token check returned HTTP $http_code (may still work)"
        HF_TOKEN_STATUS="unknown"
        return 0
    fi
}

# Attempt download WITHOUT auth first (for public repos), then WITH auth
# This fixes the issue where an invalid token blocks public repo access
attempt_download_aria2() {
    local url="$1" dir="$2" filename="$3" min_size="${4:-1000000}"
    local filepath="${dir}/${filename}"
    
    [[ -z "$url" ]] && return 1
    mkdir -p "$dir"
    
    local HF_TOKEN="${HUGGINGFACE_HUB_TOKEN:-${HF_TOKEN:-}}"
    local auth_args=()
    local use_auth=false

    # Only use HF auth if token is valid AND this is a HuggingFace URL
    if [[ "$url" == *"huggingface.co"* ]]; then
        if [[ "$HF_TOKEN_STATUS" == "valid" && -n "$HF_TOKEN" ]]; then
            auth_args=(--header="Authorization: Bearer ${HF_TOKEN}")
            use_auth=true
            log "      [aria2c] Downloading $filename (authenticated)..."
        elif [[ "$HF_TOKEN_STATUS" == "invalid" ]]; then
            log "      [aria2c] Downloading $filename (no auth - token invalid)..."
        else
            log "      [aria2c] Downloading $filename..."
        fi
    else
        log "      [aria2c] Downloading $filename..."
    fi

    if [[ -n "${CIVITAI_TOKEN:-}" && "$url" == *"civitai.com"* ]]; then
        url="${url}?token=$CIVITAI_TOKEN"
    fi

    # CORRECT ORDER: auth args, then options, then URL last
    if aria2c ${auth_args[@]+"${auth_args[@]}"} \
        -d "$dir" -o "$filename" \
        -x16 -s16 -k1M \
        --continue=true \
        --allow-overwrite=true \
        --file-allocation=none \
        --max-tries=3 \
        --retry-wait=5 \
        --timeout=120 \
        --connect-timeout=30 \
        --summary-interval=30 \
        "$url" 2>&1 | tee -a "$LOG_FILE"; then
        
        if [[ -f "$filepath" ]]; then
            local actual_size=$(stat -c%s "$filepath" 2>/dev/null || echo 0)
            if [[ "$actual_size" -ge "$min_size" ]]; then
                log "      ✅ [aria2c] SUCCESS: $filename (${actual_size} bytes)"
                return 0
            else
                log "      ⚠️  [aria2c] File too small: $filename (${actual_size} < ${min_size})"
                rm -f "$filepath"
            fi
        fi
    fi
    
    return 1
}

attempt_download_curl() {
    local url="$1" dir="$2" filename="$3" min_size="${4:-1000000}"
    local filepath="${dir}/${filename}"
    
    [[ -z "$url" ]] && return 1
    mkdir -p "$dir"
    
    local HF_TOKEN="${HUGGINGFACE_HUB_TOKEN:-${HF_TOKEN:-}}"
    local curl_cmd="curl -fSL --progress-bar --retry 3 --retry-delay 5 --connect-timeout 30 --max-time 3600"

    # Only use HF auth if token is valid
    if [[ "$url" == *"huggingface.co"* ]]; then
        if [[ "$HF_TOKEN_STATUS" == "valid" && -n "$HF_TOKEN" ]]; then
            curl_cmd="$curl_cmd -H \"Authorization: Bearer ${HF_TOKEN}\""
            log "      [curl] FALLBACK: $filename (authenticated)..."
        elif [[ "$HF_TOKEN_STATUS" == "invalid" ]]; then
            log "      [curl] FALLBACK: $filename (no auth - token invalid)..."
        else
            log "      [curl] FALLBACK: $filename..."
        fi
    else
        log "      [curl] FALLBACK: $filename..."
    fi
    
    if [[ -n "${CIVITAI_TOKEN:-}" && "$url" == *"civitai.com"* ]]; then
        url="${url}?token=$CIVITAI_TOKEN"
    fi
    
    curl_cmd="$curl_cmd -o \"$filepath\" \"$url\""
    
    if eval "$curl_cmd" 2>&1 | tee -a "$LOG_FILE"; then
        if [[ -f "$filepath" ]]; then
            local actual_size=$(stat -c%s "$filepath" 2>/dev/null || echo 0)
            if [[ "$actual_size" -ge "$min_size" ]]; then
                log "      ✅ [curl] SUCCESS: $filename (${actual_size} bytes)"
                return 0
            else
                log "      ⚠️  [curl] File too small: $filename (${actual_size} < ${min_size})"
                rm -f "$filepath"
            fi
        fi
    fi
    
    return 1
}

attempt_download_wget() {
    local url="$1" dir="$2" filename="$3" min_size="${4:-1000000}"
    local filepath="${dir}/${filename}"
    
    [[ -z "$url" ]] && return 1
    mkdir -p "$dir"
    
    local HF_TOKEN="${HUGGINGFACE_HUB_TOKEN:-${HF_TOKEN:-}}"

    if [[ -n "${CIVITAI_TOKEN:-}" && "$url" == *"civitai.com"* ]]; then
        url="${url}?token=$CIVITAI_TOKEN"
    fi

    # Only use HF auth if token is valid
    if [[ "$url" == *"huggingface.co"* && "$HF_TOKEN_STATUS" == "valid" && -n "$HF_TOKEN" ]]; then
        log "      [wget] LAST RESORT: $filename (authenticated)..."
        wget --header="Authorization: Bearer ${HF_TOKEN}" \
            --tries=3 --timeout=120 --continue \
            -O "$filepath" "$url" 2>&1 | tee -a "$LOG_FILE"
    else
        log "      [wget] LAST RESORT: $filename..."
        wget --tries=3 --timeout=120 --continue \
            -O "$filepath" "$url" 2>&1 | tee -a "$LOG_FILE"
    fi
    
    if [[ -f "$filepath" ]]; then
        local actual_size=$(stat -c%s "$filepath" 2>/dev/null || echo 0)
        if [[ "$actual_size" -ge "$min_size" ]]; then
            log "      ✅ [wget] SUCCESS: $filename (${actual_size} bytes)"
            return 0
        else
            log "      ⚠️  [wget] File too small: $filename (${actual_size} < ${min_size})"
            rm -f "$filepath"
        fi
    fi
    
    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# DROPBOX-SPECIFIC DOWNLOAD (Single Connection Required - Multi-connection = Ban)
# ═══════════════════════════════════════════════════════════════════════════════
attempt_download_dropbox() {
    local url="$1" dir="$2" filename="$3" min_size="${4:-1000000}"
    local filepath="${dir}/${filename}"

    [[ -z "$url" ]] && return 1
    [[ "$url" != *"dropbox.com"* ]] && return 1
    mkdir -p "$dir"

    log "      [dropbox] Downloading $filename (single-connection mode)..."

    # Dropbox Rules: Single connection ONLY, 3min timeout, 50KB/s minimum speed
    if curl -fSL --progress-bar \
        --retry 5 \
        --retry-delay 10 \
        --connect-timeout 30 \
        --max-time 180 \
        --speed-limit 51200 \
        --speed-time 30 \
        -o "$filepath" "$url" 2>&1 | tee -a "$LOG_FILE"; then

        if [[ -f "$filepath" ]]; then
            local actual_size=$(stat -c%s "$filepath" 2>/dev/null || echo 0)
            if [[ "$actual_size" -ge "$min_size" ]]; then
                log "      ✅ [dropbox] SUCCESS: $filename (${actual_size} bytes)"
                return 0
            else
                log "      ⚠️  [dropbox] File too small: $filename (${actual_size} < ${min_size})"
                rm -f "$filepath"
            fi
        fi
    fi

    log "      ❌ [dropbox] Download failed: $filename"
    return 1
}

download_file() {
    local entry="$1" dir="$2" min_size="${3:-1000000}"

    local url1 url2 url3 url4 filename
    IFS='|' read -r url1 url2 url3 url4 filename <<< "$entry"
    
    local filepath="${dir}/${filename}"
    
    if [[ -f "$filepath" ]]; then
        local existing_size=$(stat -c%s "$filepath" 2>/dev/null || echo 0)
        if [[ "$existing_size" -ge "$min_size" ]]; then
            log "   ✅ Already exists: $filename (${existing_size} bytes)"
            return 0
        fi
    fi
    
    log "   📥 Downloading: $filename"
    
    local HF_TOKEN="${HUGGINGFACE_HUB_TOKEN:-${HF_TOKEN:-}}"
    if [[ -n "$HF_TOKEN" ]]; then
        log "      🔑 HF Token: Present (${#HF_TOKEN} chars)"
    else
        log "      ⚠️  HF Token: NOT SET"
    fi
    
    local urls=("$url1" "$url2" "$url3" "$url4")

    for url in "${urls[@]}"; do
        [[ -z "$url" ]] && continue

        # Dropbox URLs: Use dedicated single-connection handler
        if [[ "$url" == *"dropbox.com"* ]]; then
            if attempt_download_dropbox "$url" "$dir" "$filename" "$min_size"; then
                return 0
            fi
            log "      ❌ Dropbox download failed, trying next source..."
            continue
        fi

        # Standard URLs: Try aria2c (multi-connection), curl, wget
        if attempt_download_aria2 "$url" "$dir" "$filename" "$min_size"; then
            return 0
        fi

        if attempt_download_curl "$url" "$dir" "$filename" "$min_size"; then
            return 0
        fi

        if attempt_download_wget "$url" "$dir" "$filename" "$min_size"; then
            return 0
        fi

        log "      ❌ All methods failed for URL: ${url:0:80}..."
    done
    
    log_err "   ❌ FAILED ALL FALLBACKS: $filename"
    return 1
}

download_batch() {
    local dir="$1" min_size="$2"
    shift 2
    local arr=("$@")
    local success=0
    local failed=0
    
    for entry in "${arr[@]}"; do
        if download_file "$entry" "$dir" "$min_size"; then
            ((success++))
        else
            ((failed++))
            if [[ "${PROVISION_ALLOW_MISSING_ASSETS}" != "true" ]]; then
                log_err "   ❌ Aborting due to download failure (PROVISION_ALLOW_MISSING_ASSETS=false)"
                return 1
            fi
        fi
    done
    
    log "   📊 Batch complete: $success succeeded, $failed failed"
}

install_comfyui() {
    log_section "🖥️  INSTALLING COMFYUI"
    [[ ! -d "${COMFY_DIR}" ]] && git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "${COMFY_DIR}"
    cd "${COMFY_DIR}"
    install_torch && install_dependencies
    log "   📦 Installing ComfyUI requirements..."
    "$VENV_PYTHON" -m pip install -r requirements.txt
}

install_nodes() {
    log_section "🧩 INSTALLING VIDEO NODES"
    activate_venv

    log "   📦 Cloning custom nodes..."
    for repo in "${NODES[@]}"; do
        local dir="${repo##*/}"
        local path="${COMFY_DIR}/custom_nodes/${dir}"
        if [[ ! -d "$path" ]]; then
            log "      🔗 Cloning $dir..."
            git clone --depth 1 "$repo" "$path" --recursive || {
                log_err "      ❌ Failed to clone $dir"
                continue
            }
        fi
        
        # v3.0-SPECIFIC FIX: Force install LTX requirements to prevent loader issues
        if [[ "$dir" == "ComfyUI-LTXVideo" ]]; then
            log "      🔧 Forcing LTX dependencies..."
            cd "$path"
            "$VENV_PYTHON" -m pip install -r requirements.txt --force-reinstall --quiet 2>&1 | tee -a "$LOG_FILE"
            cd -
        fi
    done

    # Install requirements per-node individually
    log "   🚀 Installing node dependencies..."
    find "${COMFY_DIR}/custom_nodes" -name "requirements.txt" -type f | while read -r req_file; do
        local node_name
        node_name=$(basename "$(dirname "$req_file")")
        log "      📦 Installing deps for $node_name..."
        "$VENV_PYTHON" -m pip install -r "$req_file" --quiet 2>&1 | tee -a "$LOG_FILE" || {
            log_err "      ⚠️  Some deps failed for $node_name"
        }
    done

    # Fix SQLAlchemy version
    "$VENV_PYTHON" -m pip install --upgrade "sqlalchemy>=2.0.0" --quiet

    log "   ✅ Nodes installed"
}

verify_critical_models() {
    log_section "🔍 VERIFYING CRITICAL MODELS"
    local missing=0
    local critical_files=(
        "models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors:UMT5-XXL Text Encoder (Required for Wan)"
        "models/diffusion_models/wan2.1_t2v_14B_fp8.safetensors:Wan 2.1 T2V 14B (FP8)"
        "models/vae/wan2.2_vae.safetensors:Wan 2.2 VAE"
        "models/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors:UMT5 Symlink in clip folder"
    )

    for entry in "${critical_files[@]}"; do
        local filepath="${entry%%:*}"
        local desc="${entry#*:}"
        if [[ -f "${COMFY_DIR}/${filepath}" ]]; then
            local size=$(stat -c%s "${COMFY_DIR}/${filepath}" 2>/dev/null || echo 0)
            log "   ✅ $desc ($(numfmt --to=iec $size))"
        else
            log_err "   ❌ MISSING: $desc"
            log_err "      Expected: ${COMFY_DIR}/${filepath}"
            ((missing++))
        fi
    done

    if [[ $missing -gt 0 ]]; then
        log_err ""
        log_err "   ⚠️  $missing critical model(s) missing!"
        log_err "   Video generation may fail with matrix shape errors."
        log_err "   Check download logs above for failures."
    else
        log "   ✅ All critical models verified"
    fi
}

install_models() {
    log_section "📦 DOWNLOADING VIDEO MODELS"
    
    # Wan 2.1 & 2.2 -> diffusion_models (CRITICAL FIX)
    download_batch "${COMFY_DIR}/models/diffusion_models" "1000000000" "${WAN_MODELS[@]}"
    download_batch "${COMFY_DIR}/models/diffusion_models" "1000000000" "${WAN22_T2V_MODELS[@]}"
    download_batch "${COMFY_DIR}/models/diffusion_models" "1000000000" "${WAN_I2V_MODELS[@]}"
    
    # LTX-Video -> checkpoints (Standard)
    download_batch "${COMFY_DIR}/models/checkpoints" "1000000000" "${LTX_MODELS[@]}"
    
    download_batch "${COMFY_DIR}/models/text_encoders" "100000000" "${TEXT_ENCODERS[@]}"

    # Create symlinks for text encoder path compatibility (Wan nodes may look in models/clip/)
    log "   🔗 Creating text encoder symlinks for node compatibility..."
    mkdir -p "${COMFY_DIR}/models/clip"
    for f in "${COMFY_DIR}/models/text_encoders/"*.safetensors; do
        if [[ -f "$f" ]]; then
            local fname=$(basename "$f")
            ln -sf "$f" "${COMFY_DIR}/models/clip/${fname}" 2>/dev/null || true
            log "      ✅ Linked: ${fname}"
        fi
    done

    # v3.5 FIX: Create filename compatibility symlinks for UMT5 text encoder
    # Different ComfyUI versions and workflows use different naming conventions
    log "   🔗 Creating UMT5 filename compatibility symlinks..."
    local umt5_variants=(
        "umt5_xxl_fp8_e4m3fn_scaled.safetensors"
        "umt5_xxl_fp8_scaled.safetensors"
        "umt5-xxl-encoder-fp8.safetensors"
        "t5xxl_fp8_e4m3fn.safetensors"
    )
    local umt5_source=""

    # Find which UMT5 variant actually exists
    for variant in "${umt5_variants[@]}"; do
        if [[ -f "${COMFY_DIR}/models/text_encoders/${variant}" ]]; then
            umt5_source="${COMFY_DIR}/models/text_encoders/${variant}"
            log "      📄 Found UMT5 source: ${variant}"
            break
        fi
    done

    # Create symlinks for all naming variants in both text_encoders and clip folders
    if [[ -n "$umt5_source" ]]; then
        for variant in "${umt5_variants[@]}"; do
            if [[ ! -f "${COMFY_DIR}/models/text_encoders/${variant}" ]]; then
                ln -sf "$umt5_source" "${COMFY_DIR}/models/text_encoders/${variant}" 2>/dev/null || true
                log "      ✅ Created alias: text_encoders/${variant}"
            fi
            if [[ ! -f "${COMFY_DIR}/models/clip/${variant}" ]]; then
                ln -sf "$umt5_source" "${COMFY_DIR}/models/clip/${variant}" 2>/dev/null || true
                log "      ✅ Created alias: clip/${variant}"
            fi
        done
    else
        log_err "      ⚠️  No UMT5 text encoder found - Wan workflows may fail!"
    fi

    download_batch "${COMFY_DIR}/models/clip_vision" "100000000" "${CLIP_VISION[@]}"
    download_batch "${COMFY_DIR}/models/loras" "10000000" "${LIGHTNING_LORAS[@]}"
    download_batch "${COMFY_DIR}/models/vae" "100000000" "${VAE_MODELS[@]}"
    download_batch "${COMFY_DIR}/models/latent_upscale_models" "10000000" "${UPSCALER_MODELS[@]}"
    download_batch "${COMFY_DIR}/models/diffusion_models" "100000000" "${DEPTH_MODELS[@]}"

    log "   🔞 Downloading NSFW 2026 Engines..."
    download_batch "${COMFY_DIR}/models/diffusion_models" "1000000000" "${NSFW_MODELS[@]}"

    log "   ⚡ Downloading Flux.1 Models..."
    download_batch "${COMFY_DIR}/models/diffusion_models" "1000000000" "${FLUX_MODELS[@]}"

    # Verify critical models are present
    verify_critical_models
}

start_comfyui() {
    log_section "🚀 STARTING COMFYUI"
    cd "${COMFY_DIR}"
    activate_venv

    local sql_ver=$("$VENV_PYTHON" -c "import sqlalchemy; print(sqlalchemy.__version__)" 2>/dev/null || echo "0")
    [[ "${sql_ver:0:1}" -lt 2 ]] && "$VENV_PYTHON" -m pip install --upgrade "sqlalchemy>=2.0.0" >/dev/null 2>&1

    # Find correct TCMalloc library (Ubuntu 24.04 uses t64 suffix)
    local tcmalloc_paths=(
        "/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4t64"
        "/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4"
        "/usr/lib/libtcmalloc_minimal.so.4"
    )

    local tcmalloc_found=""
    for path in "${tcmalloc_paths[@]}"; do
        if [[ -f "$path" ]]; then
            tcmalloc_found="$path"
            break
        fi
    done

    if [[ -n "$tcmalloc_found" ]]; then
        export LD_PRELOAD="$tcmalloc_found"
        log "   🧠 Using TCMalloc: $tcmalloc_found"
    else
        log "   ⚠️  TCMalloc not found, proceeding without it"
    fi

    # Disable torch.compile/Triton to fix FP8 compatibility on older GPUs
    # (Prevents "fp8e4nv not supported" Triton compilation errors)
    export TORCHDYNAMO_DISABLE=1
    export TORCH_COMPILE_DISABLE=1
    log "   🔧 Disabled torch.compile/dynamo for GPU compatibility"

    # Kill any existing ComfyUI
    pkill -f "python.*main.py" 2>/dev/null || true
    sleep 2

    setsid nohup "$VENV_PYTHON" main.py --listen 0.0.0.0 --port 8188 --enable-cors-header > "${WORKSPACE}/comfyui.log" 2>&1 < /dev/null &
    echo "$!" > "${WORKSPACE}/comfyui.pid"
    log "✅ ComfyUI started (PID: $!)"

    # Verify it actually started
    sleep 5
    if ! kill -0 "$(cat "${WORKSPACE}/comfyui.pid")" 2>/dev/null; then
        log_err "❌ ComfyUI failed to start! Check ${WORKSPACE}/comfyui.log"
        tail -n 30 "${WORKSPACE}/comfyui.log" | tee -a "$LOG_FILE"
        return 1
    fi
}

start_cloudflare_tunnel() {
    log_section "☁️  STARTING CLOUDFLARE TUNNEL"
    local cf_bin="/usr/local/bin/cloudflared"
    if [[ ! -x "$cf_bin" ]]; then
        log "   📥 cloudflared not present; attempting download..."
        local CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
        if curl -fsSL --connect-timeout 15 --max-time 120 "$CLOUDFLARED_URL" -o "$cf_bin" 2>/dev/null; then
            chmod +x "$cf_bin" || true
            log "   ✅ Downloaded cloudflared"
        else
            log "   ❌ Failed to download cloudflared; skipping tunnel"
            return 1
        fi
    fi

    local TUNNEL_LOG="${WORKSPACE}/cloudflared.log"
    local TUNNEL_PID_FILE="${WORKSPACE}/cloudflared.pid"
    
    if [[ -f "$TUNNEL_PID_FILE" ]]; then
        local oldpid=$(cat "$TUNNEL_PID_FILE" 2>/dev/null || true)
        [[ -n "$oldpid" ]] && kill "$oldpid" 2>/dev/null || true
        rm -f "$TUNNEL_PID_FILE"
    fi

    log "   ⏳ Starting tunnel to localhost:8188..."
    setsid nohup "$cf_bin" tunnel --url http://localhost:8188 > "$TUNNEL_LOG" 2>&1 < /dev/null &
    echo "$!" > "$TUNNEL_PID_FILE"

    local TUNNEL_URL=""
    for i in {1..60}; do
        TUNNEL_URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$TUNNEL_LOG" 2>/dev/null | head -n1 || true)
        [[ -n "$TUNNEL_URL" ]] && break
        sleep 1
    done

    if [[ -n "$TUNNEL_URL" ]]; then
        log "   ✅ Tunnel URL: $TUNNEL_URL"
        echo "$TUNNEL_URL" > "${WORKSPACE}/tunnel_url.txt"
    else
        log "   ⚠️  Could not capture tunnel URL. Check ${TUNNEL_LOG}"
    fi
}

main() {
    display_banner
    log_section "🎬 VIDEO PROVISIONER STARTING"
    WORKSPACE=${WORKSPACE:-/workspace}
    mkdir -p "$WORKSPACE" && cd "$WORKSPACE"
    COMFY_DIR="${WORKSPACE}/ComfyUI"
    
    local available_kb=$(df "$WORKSPACE" | awk 'NR==2 {print $4}')
    if (( available_kb < 100 * 1024 * 1024 )); then
        log "❌ ERROR: Not enough disk space ($((available_kb/1024/1024))GB < 100GB)"
        exit 1
    fi

    setup_swap
    install_apt_packages

    # Validate tokens BEFORE downloading (prevents 401 errors blocking public repos)
    log_section "🔑 VALIDATING API TOKENS"
    validate_hf_token

    install_comfyui
    install_nodes
    install_models
    start_comfyui
    
    if [[ "${DISABLE_CLOUDFLARED:-0}" != "1" ]]; then
        start_cloudflare_tunnel
    fi
    
    log "--- ✅ VIDEO PROVISIONING COMPLETE ---"
    log "🌐 ComfyUI: Port 8188"

    log "🛠️  Starting Maintenance Watchdog..."
    while true; do
        if [[ "${DISABLE_CLOUDFLARED:-0}" != "1" ]]; then
            local cfpid_file="${WORKSPACE}/cloudflared.pid"
            if [[ -f "$cfpid_file" ]]; then
                if ! kill -0 $(cat "$cfpid_file") 2>/dev/null; then
                    log "   ⚠️  Cloudflare process died (PID $(cat "$cfpid_file")). Restarting..."
                    rm -f "$cfpid_file"
                    start_cloudflare_tunnel
                fi
            else
                log "   ⚠️  Cloudflare PID file missing. Restarting..."
                start_cloudflare_tunnel
            fi
        fi
        
        local cpid_file="${WORKSPACE}/comfyui.pid"
        if [[ -f "$cpid_file" ]]; then
            if ! kill -0 $(cat "$cpid_file") 2>/dev/null; then
                log "   ⚠️  ComfyUI died. Restarting..."
                start_comfyui
            fi
        fi
        
        sleep 30
    done
}

main "$@"
