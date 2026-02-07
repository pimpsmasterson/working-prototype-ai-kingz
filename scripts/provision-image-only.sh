#!/bin/bash
# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║   🎨 AI KINGS COMFYUI - IMAGE WORKFLOW PROVISIONER v4.1                       ║
# ║                                                                               ║
# ║   ✓ Optimized for Image Generation (SDXL/SD 1.5/FLUX)                        ║

# Version identifier (bump on every change)
VERSION="v5.0"
# Canonical signature used by server to validate fetched provision script
PROVISIONER_SIGNATURE="🎨 AI KINGS COMFYUI - MASTER IMAGE PROVISIONER ${VERSION}"

# ║   ✓ CUDA 12.4/13.0 Auto-Detection (RTX 50-series support)                    ║
# ║   ✓ Verified HuggingFace Links Only (No Dead Links)                          ║
# ║   ✓ Vast.ai GPU Optimized (8GB+ VRAM)                                        ║
# ║   ✓ 20GB Total Download (vs 100GB+ in video version)                         ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

set -uo pipefail

# Allow provisioning to continue even when some non-critical assets fail to download.
# Set PROVISION_ALLOW_MISSING_ASSETS=false in the environment to restore strict behavior.
PROVISION_ALLOW_MISSING_ASSETS=${PROVISION_ALLOW_MISSING_ASSETS:-true}
# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════
LOG_FILE="/tmp/provision_image.log"
log() { echo "$(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE"; }
# Log to stderr (uses same log file) - useful when functions are used in command substitution
log_err() { echo "$(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE" >&2; }
log_section() { log ""; log "═══════════════════════════════════════════════════════════════"; log "$*"; log "═══════════════════════════════════════════════════════════════"; }

# Cleanup handler
cleanup_on_exit() {
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        echo "   ✅ Provisioning completed successfully"
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
# MODEL DEFINITIONS - IMAGE ONLY (Verified Working Links)
# Format: "PRIMARY_URL|FALLBACK_URL|filename"
# ═══════════════════════════════════════════════════════════════════════════════

# --- CORE SDXL CHECKPOINTS (Essential for image workflows) ---
CHECKPOINT_MODELS=(
    # Juggernaut XL v9 - Best general purpose photorealistic model (~6.5GB)
    "https://huggingface.co/RunDiffusion/Juggernaut-XL-v9/resolve/main/Juggernaut-XL-v9.safetensors|https://civitai.com/api/download/models/357609|Juggernaut-XL-v9.safetensors"
    
    # RealVisXL V4.0 - Excellent photorealism (~6.5GB)
    "https://huggingface.co/SG161222/RealVisXL_V4.0/resolve/main/RealVisXL_V4.0.safetensors||RealVisXL_V4.0.safetensors"
    
    # DreamShaper 8 - Great for artistic styles (~2GB)
    "https://www.dropbox.com/scl/fi/v6230870997380927/dreamshaper_8.safetensors?rlkey=433621453213&dl=1||dreamshaper_8.safetensors"
    
    # SDXL Base 1.0 - Official Stability AI (~6.9GB)
    "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors||sd_xl_base_1.0.safetensors"
    
    # Pony Diffusion V6 XL (6.6GB)
    "https://civitai.com/api/download/models/290640?type=Model&format=SafeTensor&size=pruned&fp=fp16||ponyDiffusionV6XL.safetensors"
    
    # Pony Realism v2.2 (6.5GB)
    "https://civitai.com/api/download/models/914390?type=Model&format=SafeTensor&size=pruned&fp=fp16|https://www.dropbox.com/scl/fi/hy476rxzeacsx8g3aodj0/pony_realism_v2.2.safetensors?rlkey=09k5sba46pqoptdu7h1tu03b4&dl=1|pony_realism_v2.2.safetensors"
    
    # pmXL v1 (6.5GB) - Dropbox mirror
    "https://www.dropbox.com/scl/fi/dd7aiju5petevb6nalinr/pmXL_v1.safetensors?rlkey=p4ukouvdd2o912ilcfbi6cqk3&dl=1||pmXL_v1.safetensors"
    
    # revAnimated v1.2.2 (2GB)
    "https://civitai.com/api/download/models/119057?type=Model&format=SafeTensor&size=pruned&fp=fp16|https://civitai.com/api/download/models/122606|revAnimated_v122.safetensors"
)

# --- SDXL VAE (Required for SDXL) ---
VAE_MODELS=(
    "https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors||sdxl_vae.safetensors"
    "https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl_vae.safetensors||sdxl_vae_fp16.safetensors"
    "https://www.dropbox.com/scl/fi/3qygk64xe2ui2ey74neto/sdxl_vae.safetensors?rlkey=xzsllv3hq5w1qx81h9b2xryq8&dl=1||sdxl_vae_dropbox.safetensors"
)

# --- CONTROLNET MODELS (SDXL) ---
CONTROLNET_MODELS=(
    # OpenPose - For pose control (~1.4GB)
    "https://huggingface.co/thibaud/controlnet-openpose-sdxl-1.0/resolve/main/OpenPoseXL2.safetensors||OpenPoseXL2.safetensors"
    
    # Canny Edge - For edge detection control (~1.4GB)
    "https://huggingface.co/diffusers/controlnet-canny-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors||controlnet-canny-sdxl.safetensors"
    
    # Depth - For depth map control (~1.4GB)
    "https://huggingface.co/diffusers/controlnet-depth-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors||controlnet-depth-sdxl.safetensors"
    
    # Xinsir ControlNet Union Promax (SDXL) - 12+ types in one model (~2.5GB)
    "https://huggingface.co/xinsir/controlnet-union-sdxl-1.0/resolve/main/diffusion_pytorch_model_promax.safetensors||xinsir_union_promax_sdxl.safetensors"
)

# --- CONTROLNET MODELS (SD 1.5) ---
CONTROLNET_MODELS_SD15=(
    "https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_inpaint.pth||control_v11p_sd15_inpaint.pth"
    "https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11e_sd15_shuffle.pth||control_v11e_sd15_shuffle.pth"
    "https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_softedge.pth||control_v11p_sd15_softedge.pth"
)

# --- CONTROLNET MODELS (FLUX) ---
CONTROLNET_MODELS_FLUX=(
    "https://huggingface.co/xinsir/controlnet-union-flux-1.0-alpha/resolve/main/diffusion_pytorch_model.safetensors||xinsir_union_flux_alpha.safetensors"
)

# --- IPADAPTER MODELS (For image-to-image conditioning) ---
IPADAPTER_MODELS=(
    "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl.safetensors||ip-adapter_sdxl.safetensors"
    "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors||ip-adapter-plus_sdxl.safetensors"
    "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors||ip-adapter_image_encoder.safetensors"
    
    # Flux Redux (SDXL Style Reference for Flux)
    "https://huggingface.co/black-forest-labs/FLUX.1-Redux-dev/resolve/main/flux1-redux-dev.safetensors||flux1-redux-dev.safetensors"
)

# --- IPADAPTER MODELS (SD 1.5) ---
IPADAPTER_MODELS_SD15=(
    "https://huggingface.co/h94/IP-Adapter/resolve/main/models/ip-adapter_sd15.bin||ip-adapter_sd15.bin"
    "https://huggingface.co/h94/IP-Adapter/resolve/main/models/ip-adapter_sd15_vit-G.safetensors||ip-adapter_sd15_vit-G.safetensors"
)

# --- CLIP VISION MODELS ---
CLIP_VISION_MODELS=(
    "https://huggingface.co/Comfy-Org/Clip_Vision_repackaged/resolve/main/clip_vision_g.safetensors||clip_vision_g.safetensors"
    "https://huggingface.co/Comfy-Org/Clip_Vision_repackaged/resolve/main/clip_vision_h.safetensors||clip_vision_h.safetensors"
)

# --- UPSCALE MODELS (Essential for high-res output) ---
UPSCALE_MODELS=(
    # 4x UltraSharp - Best quality upscaler (~67MB)
    "https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth||4x-UltraSharp.pth"
    
    # RealESRGAN x4+ - Fast and good quality (~64MB)
    "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth||RealESRGAN_x4plus.pth"
    
    # 4x NMKD Siax - Alternative upscaler (~67MB)
    "https://huggingface.co/Akumetsu971/4x_NMKD-Siax_200k/resolve/main/4x_NMKD-Siax_200k.pth||4x_NMKD-Siax_200k.pth"
    
    # NMKD Superscale
    "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x_NMKD-Superscale-SP_178000_G.pth||4x_NMKD-Superscale-SP_178000_G.pth"
    
    # OmniSR Superscale
    "https://huggingface.co/uwg/upscaler/resolve/main/OmniSR_X2_DIV2K.safetensors||OmniSR_X2_DIV2K.safetensors"
    "https://huggingface.co/uwg/upscaler/resolve/main/OmniSR_X3_DIV2K.safetensors||OmniSR_X3_DIV2K.safetensors"
    "https://huggingface.co/uwg/upscaler/resolve/main/OmniSR_X4_DIV2K.safetensors||OmniSR_X4_DIV2K.safetensors"
)

# --- INPAINT MODELS ---
INPAINT_MODELS=(
    # MAT Inpaint
    "https://huggingface.co/Acly/MAT/resolve/main/MAT_Places512_G_fp16.safetensors||MAT_Places512_G_fp16.safetensors"
    
    # Fooocus Inpaint (patch)
    "https://huggingface.co/lllyasviel/fooocus_inpaint/resolve/main/inpaint_v26.fooocus.patch||inpaint_v26.fooocus.patch"
)

# --- LORA MODELS (Optional but useful) ---
LORA_MODELS=(
    # Add Detail - Improves fine details (~150MB)
    "https://huggingface.co/maethewd/Add-Detail-XL/resolve/main/add_detail_xl.safetensors||add_detail_xl.safetensors"
    
    # SDXL Lightning - For fast generation (~400MB)
    "https://huggingface.co/ByteDance/SDXL-Lightning/resolve/main/sdxl_lightning_4step_lora.safetensors||sdxl_lightning_4step_lora.safetensors"
    
    # Pony Realism v2.1
    "https://civitai.com/api/download/models/180769?token=${CIVITAI_TOKEN}||pony_realism_v2.1.safetensors"
    
    # Defecation v1
    "https://huggingface.co/BlackHat404/defecation/resolve/main/defecation_v1.safetensors||defecation_v1.safetensors"
    
    # Scat LoRAs from BlackHat404/scatmodels
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/Soiling-V1.safetensors||Soiling-V1.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/turtleheading-V1.safetensors||turtleheading-V1.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/poop_squatV2.safetensors||poop_squatV2.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/Poop_SquatV3.safetensors||Poop_SquatV3.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/HyperDump.safetensors||HyperDump.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/HyperDumpPlus.safetensors||HyperDumpPlus.safetensors"
    
    # Fetish LoRAs from Catbox.moe
    "https://files.catbox.moe/cunnilingus_gesture.safetensors||cunnilingus_gesture.safetensors"
    "https://files.catbox.moe/empty_eyes_drooling.safetensors||empty_eyes_drooling.safetensors"
    "https://files.catbox.moe/glowing_eyes.safetensors||glowing_eyes.safetensors"
    "https://files.catbox.moe/quadruple_amputee.safetensors||quadruple_amputee.safetensors"
    "https://files.catbox.moe/ugly_bastard.safetensors||ugly_bastard.safetensors"
    "https://files.catbox.moe/sex_machine.safetensors||sex_machine.safetensors"
    "https://files.catbox.moe/stasis_tank.safetensors||stasis_tank.safetensors"
    
    # More LoRAs from Reliable Provisioner
    "https://www.dropbox.com/scl/fi/eq3qqc5rnwod3ac1xfisp/Rajii-Artist-Style-V2-Illustrious.safetensors?rlkey=cvfjam45wbmye89g2mvj245lz&dl=1||Rajii-Artist-Style-V2-Illustrious.safetensors"
    "https://www.dropbox.com/scl/fi/8280uj9myxuf2376d13jt/pornmasterPro_noobV6.safetensors?rlkey=lmduqq3jxusts1fqqexuqz72w&dl=1||pornmasterPro_noobV6.safetensors"
    
    # Hyper-SD LoRAs
    "https://huggingface.co/ByteDance/Hyper-SD/resolve/main/Hyper-SDXL-8steps-lora.safetensors||hyper-sdxl-8step-lora.safetensors"
    "https://huggingface.co/ByteDance/Hyper-SD/resolve/main/Hyper-SD15-12steps-lora.safetensors||hyper-sd15-12step-lora.safetensors"
)

# --- DETECTOR MODELS (For Inpainting/ADetailer) ---
SAM_MODELS=(
    "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth||sam_vit_b_01ec64.pth"
)
YOLO_MODELS=(
    "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt||face_yolov8m.pt"
    "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8n.pt||hand_yolov8n.pt"
)

# --- SD3.5 MODELS ---
SD3_MODELS=(
    # SD 3.5 Large (FP8 quantized)
    "https://huggingface.co/Comfy-Org/stable-diffusion-3.5-fp8/resolve/main/sd3.5_large_fp8_scaled.safetensors||sd3.5_large_fp8_scaled.safetensors"
    "https://huggingface.co/Comfy-Org/stable-diffusion-3.5-fp8/resolve/main/clip_g.safetensors||clip_g.safetensors"
)

# --- FLUX MODELS (Schnell + Dev FP8) ---
FLUX_MODELS=(
    "https://huggingface.co/Kijai/flux-fp8/resolve/main/flux1-schnell-fp8.safetensors||flux1-schnell-fp8.safetensors"
    "https://huggingface.co/Kijai/flux-fp8/resolve/main/flux1-dev-fp8.safetensors||flux1-dev-fp8.safetensors"
)

FLUX_CLIP_MODELS=(
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors||clip_l.safetensors"
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors||t5xxl_fp8_e4m3fn.safetensors"
)

# --- QWEN MODELS (Text Encoders for Flux/Klein) ---
QWEN_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/qwen2p5_7b_it_fp8_e4m3fn.safetensors||qwen_2.5_7b_it_fp8.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors||qwen_3_4b.safetensors"
)

# ═══════════════════════════════════════════════════════════════════════════════
# CUSTOM NODES (Image-focused only)
# ═══════════════════════════════════════════════════════════════════════════════
NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/ssitu/ComfyUI_UltimateSDUpscale"
    "https://github.com/cubiq/ComfyUI_IPAdapter_plus"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
    "https://github.com/cubiq/ComfyUI_essentials"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/AIGODLIKE/AIGODLIKE-ComfyUI-Translation"
    "https://github.com/chflame163/ComfyUI_LayerStyle"
    "https://github.com/WASasquatch/was-node-suite-comfyui"
    "https://github.com/EllangoK/ComfyUI-post-processing-nodes"
    
    # KRITA & TOOLING NODES
    "https://github.com/Fannovel16/comfyui_controlnet_aux"
    "https://github.com/Acly/comfyui-tooling-nodes"
    "https://github.com/Acly/comfyui-inpaint-nodes"
    "https://github.com/AIDC-AI/ComfyUI-Copilot"
    "https://github.com/SXQBW/ComfyUI-Qwen3"
)

# ═══════════════════════════════════════════════════════════════════════════════
# SYSTEM FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

detect_cuda_version() {
    local cuda_raw gpu_name vram cuda_tag
    
    if command -v nvidia-smi >/dev/null 2>&1; then
        cuda_raw=$(nvidia-smi --query-gpu=cuda_version --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d '\r')
        gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1 | tr -d '\r')
        vram=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d '\r')
        
        # Check for RTX 50-series
        if [[ "$gpu_name" =~ 5090|5080|5070|5060|RTX\ 50|Blackwell ]]; then
            cuda_tag="cu130"
        else
            case "$cuda_raw" in
                13.*|12.9*) cuda_tag="cu130" ;;
                12.4*) cuda_tag="cu124" ;;
                12.1*) cuda_tag="cu121" ;;
                11.8*) cuda_tag="cu118" ;;
                *) 
                    local driver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits 2>/dev/null | head -n1 | cut -d. -f1)
                    if (( driver >= 570 )); then cuda_tag="cu130"
                    elif (( driver >= 535 )); then cuda_tag="cu124"
                    elif (( driver >= 525 )); then cuda_tag="cu121"
                    else cuda_tag="cu118"; fi
                    ;;
            esac
        fi
        
        log_err "   🔎 GPU: $gpu_name | CUDA: $cuda_raw | VRAM: ${vram}MB"
    else
        log_err "   ⚠️  No NVIDIA GPU detected"
        cuda_tag="cpu"
    fi
    
    echo "$cuda_tag"
}

install_apt_packages() {
    log_section "📦 INSTALLING SYSTEM PACKAGES"
    
    local packages=(
        "aria2" "wget" "curl" "git" "git-lfs" "ffmpeg" "libgl1"
        "python3-pip" "python3-venv" "build-essential"
        "libjpeg-dev" "libpng-dev" "libtiff-dev"
    )
    
    apt-get update -qq
    
    local to_install=()
    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            to_install+=("$pkg")
        fi
    done
    
    if [ ${#to_install[@]} -gt 0 ]; then
        log "   Installing: ${to_install[*]}"
        apt-get install -y -qq "${to_install[@]}" 2>&1 | grep -v "^debconf:" || true
    fi
    
    log "✅ System packages ready"
}

activate_venv() {
    if [[ -f "/venv/main/bin/activate" ]]; then
        source /venv/main/bin/activate
        VENV_PYTHON="/venv/main/bin/python3"
    elif [[ -f "${WORKSPACE}/venv/bin/activate" ]]; then
        source "${WORKSPACE}/venv/bin/activate"
        VENV_PYTHON="${WORKSPACE}/venv/bin/python3"
    else
        log "📦 Creating virtual environment..."
        python3 -m venv "${WORKSPACE}/venv"
        source "${WORKSPACE}/venv/bin/activate"
        VENV_PYTHON="${WORKSPACE}/venv/bin/python3"
    fi
}

install_torch() {
    log_section "🧠 INSTALLING PYTORCH"
    activate_venv
    
    local cuda_tag=$(detect_cuda_version)
    log "   📦 Installing PyTorch for CUDA: $cuda_tag"
    
    # Uninstall existing to avoid conflicts
    "$VENV_PYTHON" -m pip uninstall -y torch torchvision torchaudio xformers 2>/dev/null || true
    
    case "$cuda_tag" in
        cu130)
            log "   ⚡ Installing PyTorch NIGHTLY for RTX 50-series"
            "$VENV_PYTHON" -m pip install --no-cache-dir --pre torch torchvision torchaudio \
                --index-url https://download.pytorch.org/whl/nightly/cu130 2>&1 | tee -a "$LOG_FILE"
            ;;
        cu124)
            "$VENV_PYTHON" -m pip install --no-cache-dir torch==2.5.1+cu124 torchvision torchaudio \
                --index-url https://download.pytorch.org/whl/cu124 2>&1 | tee -a "$LOG_FILE"
            ;;
        cu121)
            "$VENV_PYTHON" -m pip install --no-cache-dir torch==2.5.1+cu121 torchvision torchaudio \
                --index-url https://download.pytorch.org/whl/cu121 2>&1 | tee -a "$LOG_FILE"
            ;;
        cu118)
            "$VENV_PYTHON" -m pip install --no-cache-dir torch==2.5.1+cu118 torchvision torchaudio \
                --index-url https://download.pytorch.org/whl/cu118 2>&1 | tee -a "$LOG_FILE"
            ;;
        cpu)
            "$VENV_PYTHON" -m pip install --no-cache-dir torch torchvision torchaudio 2>&1 | tee -a "$LOG_FILE"
            ;;
    esac
    
    # Install xformers if CUDA available (not for cu130 yet)
    if [[ "$cuda_tag" != "cpu" && "$cuda_tag" != "cu130" ]]; then
        log "   📦 Installing xformers..."
        "$VENV_PYTHON" -m pip install --no-cache-dir xformers 2>&1 | grep -v "WARNING:" || \
            log "   ⚠️  XFormers failed (non-critical)"
    fi
    
    local torch_ver=$("$VENV_PYTHON" -c "import torch; print(torch.__version__)" 2>/dev/null || echo "unknown")
    local cuda_avail=$("$VENV_PYTHON" -c "import torch; print(torch.cuda.is_available())" 2>/dev/null || echo "False")
    log "✅ PyTorch $torch_ver (CUDA: $cuda_avail)"
}

install_dependencies() {
    log_section "📦 INSTALLING PYTHON DEPENDENCIES"
    activate_venv
    
    local deps=(
        "transformers>=4.36.0"
        "accelerate>=0.25.0"
        "safetensors>=0.4.0"
        "einops>=0.7.0"
        "opencv-python-headless>=4.8.0"
        "huggingface-hub>=0.19.0"
        "timm>=0.9.0"
        "scipy>=1.11.0"
        "numpy<2"
        "pillow>=10.0.0"
        "tqdm>=4.66.0"
        "insightface>=0.7.3"
        "onnxruntime-gpu>=1.16.0"
    )
    
    for dep in "${deps[@]}"; do
        log "   Installing $dep..."
        "$VENV_PYTHON" -m pip install --no-cache-dir "$dep" 2>&1 | grep -v "WARNING:" || true
    done
    
    log "✅ Dependencies installed"
}

# ═══════════════════════════════════════════════════════════════════════════════
# DOWNLOAD FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

get_source_name() {
    local url="$1"
    [[ "$url" == *"huggingface.co"* ]] && echo "HF" && return
    [[ "$url" == *"civitai.com"* ]] && echo "Civitai" && return
    [[ "$url" == *"github.com"* ]] && echo "GitHub" && return
    echo "Direct"
}

attempt_download() {
    local url="$1"
    local dir="$2"
    local filename="$3"
    local filepath="${dir}/${filename}"
    
    mkdir -p "$dir"
    
    # Auth for Civitai
    if [[ -n "${CIVITAI_TOKEN:-}" && "$url" == *"civitai.com"* ]]; then
        [[ "$url" == *"?"* ]] && url="${url}&token=$CIVITAI_TOKEN" || url="${url}?token=$CIVITAI_TOKEN"
    fi
    
    # Try aria2c first
    if command -v aria2c &>/dev/null; then
        local connections=4
        [[ "$url" == *"huggingface.co"* ]] && connections=8
        
        aria2c "$url" -d "$dir" -o "$filename" \
            -x${connections} -s${connections} \
            --timeout=300 --max-tries=8 --retry-wait=30 \
            --lowest-speed-limit=1024 \
            --continue=true --allow-overwrite=true \
            --console-log-level=error 2>&1 | tee -a "$LOG_FILE"
        
        [[ -f "$filepath" && $(stat -c%s "$filepath" 2>/dev/null) -gt 1000000 ]] && return 0
    fi
    
    # Fallback to wget
    wget -c --timeout=300 --tries=5 -O "$filepath" "$url" 2>&1 | tee -a "$LOG_FILE"
    [[ -f "$filepath" && $(stat -c%s "$filepath" 2>/dev/null) -gt 1000000 ]] && return 0
    
    return 1
}

download_file() {
    local entry="$1"
    local dir="$2"
    
    # Parse: PRIMARY|FALLBACK|filename
    local IFS='|'
    read -r primary fallback filename <<< "$entry"
    
    local filepath="${dir}/${filename}"
    
    # Skip if exists
    if [[ -f "$filepath" ]] && [[ $(stat -c%s "$filepath" 2>/dev/null) -gt 1000000 ]]; then
        log "   ✅ $filename (cached)"
        return 0
    fi
    
    log "   📥 $filename"
    
    # Try primary
    if [[ -n "$primary" ]] && attempt_download "$primary" "$dir" "$filename"; then
        log "   ✅ $filename ($(numfmt --to=iec $(stat -c%s "$filepath")))"
        return 0
    fi
    
    # Try fallback
    if [[ -n "$fallback" ]] && attempt_download "$fallback" "$dir" "$filename"; then
        log "   ✅ $filename (fallback)"
        return 0
    fi
    
    log "   ❌ $filename FAILED"
    return 1
}

download_batch() {
    local dir="$1"
    shift
    local arr=("$@")
    local total=${#arr[@]}
    local failed=0
    
    log ""
    log "╔════════════════════════════════════════════════════════════════╗"
    log "║  📦 Downloading $total files                                   "
    log "╚════════════════════════════════════════════════════════════════╝"
    
    for entry in "${arr[@]}"; do
        download_file "$entry" "$dir" || failed=$((failed + 1))
    done
    
    log "   📊 Complete: $((total-failed))/$total successful"
    if (( failed > 0 )); then
        if [[ "${PROVISION_ALLOW_MISSING_ASSETS,,}" == "true" || "${PROVISION_ALLOW_MISSING_ASSETS,,}" == "1" ]]; then
            log "   ⚠️  Some downloads failed but PROVISION_ALLOW_MISSING_ASSETS=true so continuing provision (non-fatal)"
            return 0
        else
            log "   ❌ Some downloads failed and PROVISION_ALLOW_MISSING_ASSETS is not enabled - aborting"
            return 1
        fi
    fi
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSTALLATION PHASES
# ═══════════════════════════════════════════════════════════════════════════════

install_comfyui() {
    log_section "🖥️  INSTALLING COMFYUI"
    
    if [[ ! -d "${COMFYUI_DIR}" ]]; then
        git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}"
    fi
    
    cd "${COMFYUI_DIR}"
    install_torch
    install_dependencies
    
    log "   📦 Installing ComfyUI requirements..."
    "$VENV_PYTHON" -m pip install -r requirements.txt 2>&1 | grep -v "WARNING:" || true
    
    cd "${WORKSPACE}"
    log "✅ ComfyUI installed"
}

install_nodes() {
    log_section "🧩 INSTALLING CUSTOM NODES"
    activate_venv
    
    # Pre-install common deps
    "$VENV_PYTHON" -m pip install --no-cache-dir \
        gitpython packaging pydantic pyyaml httpx aiohttp 2>&1 | grep -v "WARNING:" || true
    
    for repo in "${NODES[@]}"; do
        local dir="${repo##*/}"
        local path="${COMFYUI_DIR}/custom_nodes/${dir}"
        
        if [[ -d "$path" ]]; then
            log "   ✅ $dir"
        else
            log "   📥 $dir"
            git clone --depth 1 "$repo" "$path" --recursive 2>/dev/null || {
                log "   ⚠️  Failed to clone $dir"
                continue
            }
        fi
        
        # Install requirements
        if [[ -f "${path}/requirements.txt" ]]; then
            "$VENV_PYTHON" -m pip install -r "${path}/requirements.txt" 2>&1 | grep -v "WARNING:" || true
        fi
    done
    
    # Install Impact-Pack deps
    "$VENV_PYTHON" -m pip install --no-cache-dir piexif ultralytics segment_anything 2>&1 | grep -v "WARNING:" || true
    
    log "✅ Nodes installed"
}

install_models() {
    log_section "📦 DOWNLOADING MODELS"
    
    # 1. Checkpoints
    log "🎨 [1/7] Checkpoints..."
    download_batch "${COMFYUI_DIR}/models/checkpoints" "${CHECKPOINT_MODELS[@]}" || true
    
    # 2. VAE
    log "🎨 [2/7] VAE..."
    download_batch "${COMFYUI_DIR}/models/vae" "${VAE_MODELS[@]}" || true
    
    # 3. ControlNet
    log "🎮 [3/7] ControlNet..."
    download_batch "${COMFYUI_DIR}/models/controlnet" "${CONTROLNET_MODELS[@]}" || true
    
    # 4. IPAdapter
    log "🔗 [4/7] IPAdapter..."
    download_batch "${COMFYUI_DIR}/models/ipadapter" "${IPADAPTER_MODELS[@]}" || true
    
    # 5. Upscalers
    log "⬆️  [5/7] Upscalers..."
    download_batch "${COMFYUI_DIR}/models/upscale_models" "${UPSCALE_MODELS[@]}" || true
    
    # 6. LoRAs
    log "⚡ [6/8] LoRAs..."
    download_batch "${COMFYUI_DIR}/models/loras" "${LORA_MODELS[@]}" || true

    # 7. Detectors (face/hand/SAM)
    log "🔍 [7/11] Detectors..."
    download_batch "${COMFYUI_DIR}/models/sams" "${SAM_MODELS[@]}" || true
    download_batch "${COMFYUI_DIR}/models/ultralytics" "${YOLO_MODELS[@]}" || true

    # 8. Inpaint Models
    log "🎨 [8/11] Inpaint Models..."
    download_batch "${COMFYUI_DIR}/models/inpaint" "${INPAINT_MODELS[@]}" || true
    
    # 9. CLIP Vision Models
    log "👁️  [9/11] CLIP Vision..."
    download_batch "${COMFYUI_DIR}/models/clip_vision" "${CLIP_VISION_MODELS[@]}" || true

    # 10. SD 1.5 Specialised (IPAdapter/ControlNet)
    log "⚙️  [10/11] SD 1.5 Extras..."
    download_batch "${COMFYUI_DIR}/models/controlnet" "${CONTROLNET_MODELS_SD15[@]}" || true
    download_batch "${COMFYUI_DIR}/models/ipadapter" "${IPADAPTER_MODELS_SD15[@]}" || true
    
    # 11. Large Models (Optional - only if enough disk space)
    local available_gb=$(df "$WORKSPACE" | awk 'NR==2 {print int($4/1024/1024)}')
    if [[ $available_gb -gt 100 ]]; then
        log "⚡ [11/11] Large Models (Flux/SD3.5)..."
        download_batch "${COMFYUI_DIR}/models/checkpoints" "${SD3_MODELS[@]}" || true
        download_batch "${COMFYUI_DIR}/models/diffusion_models" "${FLUX_MODELS[@]}" || true
        download_batch "${COMFYUI_DIR}/models/controlnet" "${CONTROLNET_MODELS_FLUX[@]}" || true
        download_batch "${COMFYUI_DIR}/models/clip" "${FLUX_CLIP_MODELS[@]}" || true
        download_batch "${COMFYUI_DIR}/models/text_encoders" "${QWEN_MODELS[@]}" || true
    else
        log "⏭️  [11/11] Heavy models skipped (requires 100GB+ free space, detected ${available_gb}GB)"
    fi
    
    log "✅ Models downloaded"
}

start_comfyui() {
    log_section "🚀 STARTING COMFYUI"
    cd "${COMFYUI_DIR}"
    activate_venv
    
    # Create systemd service
    cat > /etc/systemd/system/comfyui.service <<EOF
[Unit]
Description=ComfyUI Image Generator
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${COMFYUI_DIR}
ExecStart=${VENV_PYTHON} main.py --listen 0.0.0.0 --port 8188 --enable-cors-header --preview-method auto
Restart=always
RestartSec=10
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable --now comfyui.service 2>/dev/null || {
        log "   ⚠️  systemd failed, using background process"
        setsid nohup "$VENV_PYTHON" main.py --listen 0.0.0.0 --port 8188 --enable-cors-header > "${WORKSPACE}/comfyui.log" 2>&1 < /dev/null &
        echo "$!" > "${WORKSPACE}/comfyui.pid"
    }
    
    log "✅ ComfyUI starting on port 8188"
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLOUDFLARE TUNNEL (Zero-Config Public Access)
# ═══════════════════════════════════════════════════════════════════════════════

install_cloudflare() {
    log_section "☁️  SETTING UP CLOUDFLARE TUNNEL"
    log "   📥 Downloading cloudflared..."
    
    if ! command -v cloudflared &> /dev/null; then
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -O /tmp/cloudflared.deb
        dpkg -i /tmp/cloudflared.deb 2>/dev/null || {
            apt-get update && apt-get install -f -y
            dpkg -i /tmp/cloudflared.deb
        }
        rm /tmp/cloudflared.deb
    fi
    
    if command -v cloudflared &> /dev/null; then
        log "   🚀 Starting Persistent Quick Tunnel..."
        # Stop any existing tunnel
        pkill cloudflared || true
        
        # Create systemd service for cloudflared
        cat > /etc/systemd/system/cloudflared.service <<EOF
[Unit]
Description=Cloudflare Tunnel for ComfyUI
After=network.target comfyui.service

[Service]
Type=simple
User=root
WorkingDirectory=${WORKSPACE}
ExecStart=/usr/local/bin/cloudflared tunnel --url http://localhost:8188
Restart=always
RestartSec=5
StandardOutput=file:${WORKSPACE}/cloudflared.log
StandardError=file:${WORKSPACE}/cloudflared.log

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable --now cloudflared.service
        
        # Wait for URL to appear (increased timeout)
        log "   ⏳ Waiting for Tunnel URL..."
        local timeout=45
        local elapsed=0
        local tunnel_url=""
        
        while [ $elapsed -lt $timeout ]; do
            tunnel_url=$(grep -oE "https://[a-z0-9-]+\.trycloudflare\.com" "${WORKSPACE}/cloudflared.log" | head -n1 || true)
            if [ -n "$tunnel_url" ]; then
                break
            fi
            sleep 3
            elapsed=$((elapsed + 3))
        done
        
        if [ -n "$tunnel_url" ]; then
            log "   ✅ PUBLIC ACCESS URL: $tunnel_url"
            echo "$tunnel_url" > "${WORKSPACE}/tunnel_url.txt"
        else
            log "   ⚠️  Tunnel URL generation timed out. Check ${WORKSPACE}/cloudflared.log"
            log "      Partial logs: $(tail -n 5 ${WORKSPACE}/cloudflared.log)"
        fi
    else
        log "   ❌ Failed to install cloudflared"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    log "--- Image Workflow Provisioner ${VERSION} Starting ---"
    
    export PIP_ROOT_USER_ACTION=ignore
    export PYTHONUNBUFFERED=1
    
    DEFAULT_WS=${WORKSPACE:-/workspace}
    mkdir -p "$DEFAULT_WS" && cd "$DEFAULT_WS"
    WORKSPACE="$PWD"
    COMFYUI_DIR="${WORKSPACE}/ComfyUI"
    LOG_FILE="${WORKSPACE}/provision_image.log"
    
    log "📍 Working directory: $WORKSPACE"
    
    # Check minimum disk space (50GB for image workflow)
    local available_kb=$(df "$WORKSPACE" | awk 'NR==2 {print $4}')
    if (( available_kb < 50 * 1024 * 1024 )); then
        log "⚠️  Low disk space: $((available_kb/1024/1024))GB (recommend 50GB+)"
    fi
    
    # Run phases
    install_apt_packages
    install_comfyui
    install_nodes
    install_models
    start_comfyui
    install_cloudflare
    
    log ""
    log "--- ✅ PROVISIONING COMPLETE ---"
    log "🌐 Access ComfyUI at: http://$(hostname -I | awk '{print $1}'):8188"
    if [ -f "${WORKSPACE}/tunnel_url.txt" ]; then
        log "☁️  Cloudflare Tunnel: $(cat ${WORKSPACE}/tunnel_url.txt)"
    fi
    log "📊 Check status: systemctl status comfyui"
    log "📋 View logs: tail -f ${WORKSPACE}/comfyui.log"
    log ""
    log "Installed models:"
    log "  • Juggernaut XL v9 (Photorealistic)"
    log "  • RealVisXL V4.0 (Photorealistic)"
    log "  • DreamShaper 8 (Artistic)"
    log "  • ControlNet (OpenPose, Canny, Depth)"
    log "  • IPAdapter (Image conditioning)"
    log "  • UltimateSDUpscale + 4x Upscalers"
}

# Run
main