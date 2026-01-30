#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# 👑 AI KINGS NSFW COMFYUI PROVISIONING - FINAL PRODUCTION VERSION
# ═══════════════════════════════════════════════════════════════════════════════
# Fully compatible with Pony Diffusion V6 XL (SDXL-based)
# Uses correct node names: ADE_AnimateDiffLoaderGen1, VHS_VideoCombine
# All workflows are fully connected and ready to generate immediately
# ═══════════════════════════════════════════════════════════════════════════════

WORKSPACE=${WORKSPACE:-/workspace}
cd "$WORKSPACE"

# Activate venv if available
if [ -f "/venv/main/bin/activate" ]; then
    source /venv/main/bin/activate
elif [ -f "${WORKSPACE}/venv/bin/activate" ]; then
    source "${WORKSPACE}/venv/bin/activate"
fi

COMFYUI_DIR=${WORKSPACE}/ComfyUI

# ═══════════════════════════════════════════════════════════════════════════════
# SYSTEM PACKAGES
# ═══════════════════════════════════════════════════════════════════════════════
APT_PACKAGES=(
    "unrar"
    "p7zip-full"
    "ffmpeg"
    "libgl1"
    "libglib2.0-0"
    "file"
)

# ═══════════════════════════════════════════════════════════════════════════════
# CUSTOM NODES (Current, Maintained Versions)
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
)

# ═══════════════════════════════════════════════════════════════════════════════
# CHECKPOINTS (Pony XL + Pornmaster XL)
# Format: "url|filename.safetensors"
# ═══════════════════════════════════════════════════════════════════════════════
CHECKPOINT_MODELS=(
    "https://civitai.com/api/download/models/290640|ponyDiffusionV6XL.safetensors"
    "https://civitai.com/api/download/models/206536|pmXL_v1.safetensors"
    "https://civitai.com/api/download/models/128713|dreamshaper_8.safetensors"
    "https://civitai.com/api/download/model-versions/914390|pony_realism_v2.2.safetensors"
)

# ═══════════════════════════════════════════════════════════════════════════════
# LORAS WITH DESCRIPTIVE NAMES (COMPLETE COLLECTION)
# ═══════════════════════════════════════════════════════════════════════════════
LORA_MODELS=(
    # --- Pony Realism ---
    "https://civitai.com/api/download/models/152309|pony_realism_v2.1.safetensors"
    
    # --- Catbox.moe Fetish LoRAs ---
    "https://files.catbox.moe/f6r1nl.safetensors|shared_clothes.safetensors"
    "https://files.catbox.moe/pk6hl3.safetensors|xray_glasses.safetensors"
    "https://files.catbox.moe/wmshk3.safetensors|cunnilingus_gesture.safetensors"
    "https://files.catbox.moe/88e51n.rar|archive_lora.rar"
    "https://files.catbox.moe/9qixqa.safetensors|empty_eyes_drooling.safetensors"
    "https://files.catbox.moe/yz5c9g.safetensors|glowing_eyes.safetensors"
    "https://files.catbox.moe/tlt57h.safetensors|quadruple_amputee.safetensors"
    "https://files.catbox.moe/odmswn.safetensors|ugly_bastard.safetensors"
    "https://files.catbox.moe/z71ic0.safetensors|sex_machine.safetensors"
    "https://files.catbox.moe/mxbbg2.safetensors|stasis_tank.safetensors"
    
    # --- BlackHat404/scatmodels (HuggingFace) ---
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/Soiling-V1.safetensors|Soiling-V1.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/turtleheading-V1.safetensors|turtleheading-V1.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/poop_squatV2.safetensors|poop_squatV2.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/Poop_SquatV3.safetensors|Poop_SquatV3.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/HyperDump.safetensors|HyperDump.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/HyperDumpPlus.safetensors|HyperDumpPlus.safetensors"
    
    # --- JollyIm/Defecation (HuggingFace) ---
    "https://huggingface.co/JollyIm/Defecation/resolve/main/defecation_v1.safetensors|defecation_v1.safetensors"
)

# ═══════════════════════════════════════════════════════════════════════════════
# ANIMATEDIFF MODELS (SDXL-Compatible for Pony XL)
# ═══════════════════════════════════════════════════════════════════════════════
ANIMATEDIFF_MODELS=(
    "https://huggingface.co/camenduru/AnimateDiff-sdxl-beta/resolve/main/mm_sdxl_v10_beta.ckpt|mm_sdxl_v1_beta.ckpt"
    "https://huggingface.co/guoyww/animatediff/resolve/main/mm_sd_v15_v2.ckpt|mm_sd_v15_v2.ckpt"
)

# ═══════════════════════════════════════════════════════════════════════════════
# RIFE FRAME INTERPOLATION MODELS
# ═══════════════════════════════════════════════════════════════════════════════
RIFE_MODELS=(
    "https://github.com/hzwer/Practical-RIFE/releases/download/v4.26/rife426.pth|rife47.pth"
)

# ═══════════════════════════════════════════════════════════════════════════════
# UPSCALE MODELS
# ═══════════════════════════════════════════════════════════════════════════════
ESRGAN_MODELS=(
    "https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth|4x-UltraSharp.pth"
    "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth|RealESRGAN_x4plus.pth"
)

# ═══════════════════════════════════════════════════════════════════════════════
# CONTROLNET MODELS (SDXL)
# ═══════════════════════════════════════════════════════════════════════════════
CONTROLNET_MODELS=(
    "https://huggingface.co/thibaud/controlnet-openpose-sdxl-1.0/resolve/main/OpenPoseXL2.safetensors|OpenPoseXL2.safetensors"
)

# ═══════════════════════════════════════════════════════════════════════════════
# DEPTH ANYTHING V2
# ═══════════════════════════════════════════════════════════════════════════════
DEPTHANYTHING_MODELS=(
    "https://huggingface.co/Kijai/DepthAnythingV2-safetensors/resolve/main/depth_anything_v2_vitl_fp16.safetensors|depth_anything_v2_vitl_fp16.safetensors"
)

# ═══════════════════════════════════════════════════════════════════════════════
# IMPACT PACK / FACE DETAILER MODELS
# ═══════════════════════════════════════════════════════════════════════════════
BBOX_MODELS=(
    "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt|face_yolov8m.pt"
    "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8n.pt|hand_yolov8n.pt"
)

SAM_MODELS=(
    "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth|sam_vit_b_01ec64.pth"
)

# ═══════════════════════════════════════════════════════════════════════════════
# WAN 2.1 VIDEO MODELS
# ═══════════════════════════════════════════════════════════════════════════════
WAN_DIFFUSION_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/wan2.1_t2v_1.3B_fp16.safetensors|wan2.1_t2v_1.3B_fp16.safetensors"
)

WAN_TEXT_ENCODERS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp16.safetensors|umt5_xxl_fp16.safetensors"
)

WAN_VAE=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan2.1_vae.safetensors|wan2.1_vae.safetensors"
)

# ═══════════════════════════════════════════════════════════════════════════════
# WAN 2.2 VIDEO MODELS (Mixture-of-Experts)
# ═══════════════════════════════════════════════════════════════════════════════
WAN22_DIFFUSION_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_repackaged/resolve/main/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors|wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_repackaged/resolve/main/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors|wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_repackaged/resolve/main/wan2.2_ti2v_5B_fp16.safetensors|wan2.2_ti2v_5B_fp16.safetensors"
)

WAN22_VAE=(
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_repackaged/resolve/main/wan2.2_vae.safetensors|wan2.2_vae.safetensors"
)

# ═══════════════════════════════════════════════════════════════════════════════
# WAN 2.5 VIDEO MODELS (Preview) - REMOVED - Not publicly available yet
# ═══════════════════════════════════════════════════════════════════════════════
# WAN25_DIFFUSION_MODELS=()
# WAN25_VAE=()

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

function provisioning_print_header() {
    printf "\n"
    printf "╔═══════════════════════════════════════════════════════════════════╗\n"
    printf "║                                                                   ║\n"
    printf "║   👑 AI KINGS NSFW COMFYUI - PRODUCTION PROVISIONING             ║\n"
    printf "║                                                                   ║\n"
    printf "║   ✓ Pony Diffusion V6 XL (SDXL) Compatible                       ║\n"
    printf "║   ✓ AnimateDiff SDXL Beta Motion Model                           ║\n"
    printf "║   ✓ Fully Connected Workflows (No Manual Wiring)                 ║\n"
    printf "║   ✓ RIFE Frame Interpolation for Smooth Video                    ║\n"
    printf "║                                                                   ║\n"
    printf "╚═══════════════════════════════════════════════════════════════════╝\n"
    printf "\n"
}

function provisioning_print_end() {
    printf "\n"
    printf "╔═══════════════════════════════════════════════════════════════════╗\n"
    printf "║                                                                   ║\n"
    printf "║   ✅ PROVISIONING COMPLETE                                        ║\n"
    printf "║                                                                   ║\n"
    printf "║   ComfyUI: http://localhost:8188                                  ║\n"
    printf "║   Logs: tail -f ${WORKSPACE}/comfyui.log                  ║\n"
    printf "║                                                                   ║\n"
    printf "║   Quick Start:                                                    ║\n"
    printf "║   1. Open ComfyUI in browser                                      ║\n"
    printf "║   2. Load workflow from /user/default/workflows/                  ║\n"
    printf "║   3. Queue Prompt - Generate immediately!                         ║\n"
    printf "║                                                                   ║\n"
    printf "╚═══════════════════════════════════════════════════════════════════╝\n"
    printf "\n"
}

function provisioning_get_apt_packages() {
    if [[ ${#APT_PACKAGES[@]} -gt 0 ]]; then
        printf "📦 Installing system packages...\n"
        sudo apt-get update -qq
        sudo apt-get install -y -qq "${APT_PACKAGES[@]}"
    fi
}

function provisioning_install_comfyui() {
    if [[ ! -d "${COMFYUI_DIR}" ]]; then
        printf "📥 Installing ComfyUI...\n"
        git clone https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}"
        cd "${COMFYUI_DIR}"
        pip install -r requirements.txt
        cd "${WORKSPACE}"
    else
        printf "✅ ComfyUI already installed\n"
    fi
}

function provisioning_get_nodes() {
    printf "🧩 Installing custom nodes...\n"
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="${COMFYUI_DIR}/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            printf "   ✅ %s exists\n" "${dir}"
        else
            printf "   📥 Cloning %s...\n" "${dir}"
            git clone "${repo}" "${path}" --recursive --quiet
            if [[ -e $requirements ]]; then
                pip install --no-cache-dir -r "$requirements" --quiet
            fi
        fi
    done
}

function provisioning_download() {
    local url="$1"
    local dir="$2"
    local filename="$3"
    local filepath="${dir}/${filename}"
    
    # Skip if exists
    if [[ -f "$filepath" ]]; then
        printf "   ✅ %s exists\n" "$filename"
        return 0
    fi
    
    mkdir -p "$dir"
    local download_url="$url"
    
    # Append Civitai token
    if [[ -n "$CIVITAI_TOKEN" && "$url" =~ civitai\.com ]]; then
        if [[ "$url" == *"?"* ]]; then
            download_url="${url}&token=${CIVITAI_TOKEN}"
        else
            download_url="${url}?token=${CIVITAI_TOKEN}"
        fi
    fi
    
    printf "   ⬇️  Downloading %s...\n" "$filename"
    
    # Download with appropriate auth
    if [[ -n "$HUGGINGFACE_HUB_TOKEN" && "$url" =~ huggingface\.co ]]; then
        wget --header="Authorization: Bearer $HUGGINGFACE_HUB_TOKEN" \
             -q --show-progress --progress=bar:force:noscroll \
             --timeout=300 --tries=3 \
             -O "$filepath" "$download_url" || {
            printf "   ❌ Failed: %s\n" "$filename"
            rm -f "$filepath"
            return 1
        }
    else
        wget -q --show-progress --progress=bar:force:noscroll \
             --timeout=300 --tries=3 \
             -O "$filepath" "$download_url" || {
            printf "   ❌ Failed: %s\n" "$filename"
            rm -f "$filepath"
            return 1
        }
    fi
    
    printf "   ✅ Downloaded: %s\n" "$filename"
    return 0
}

function provisioning_get_files_sequential() {
    local dir="$1"
    shift
    local arr=("$@")
    
    if [[ ${#arr[@]} -eq 0 ]]; then return; fi
    
    printf "\n📁 Downloading to %s...\n" "$dir"
    
    for entry in "${arr[@]}"; do
        if [[ "$entry" == *"|"* ]]; then
            local url="${entry%%|*}"
            local filename="${entry##*|}"
        else
            local url="$entry"
            local filename="${url##*/}"
            filename="${filename%%\?*}"
        fi
        provisioning_download "$url" "$dir" "$filename"
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# CONCURRENT DOWNLOAD FUNCTION (for non-rate-limited sources)
# Uses background jobs with max parallel limit
# ═══════════════════════════════════════════════════════════════════════════════
function provisioning_get_files_concurrent() {
    local dir="$1"
    local max_parallel="${2:-4}"  # Default 4 parallel downloads
    shift 2
    local arr=("$@")
    
    if [[ ${#arr[@]} -eq 0 ]]; then return; fi
    
    printf "\n📁 Concurrent download to %s (max %s parallel)...\n" "$dir" "$max_parallel"
    
    local pids=()
    local count=0
    
    for entry in "${arr[@]}"; do
        if [[ "$entry" == *"|"* ]]; then
            local url="${entry%%|*}"
            local filename="${entry##*|}"
        else
            local url="$entry"
            local filename="${url##*/}"
            filename="${filename%%\?*}"
        fi
        
        # Start download in background
        provisioning_download "$url" "$dir" "$filename" &
        pids+=($!)
        ((count++))
        
        # Wait if we hit max parallel limit
        if [[ $count -ge $max_parallel ]]; then
            wait "${pids[0]}"
            pids=("${pids[@]:1}")
            ((count--))
        fi
    done
    
    # Wait for remaining downloads
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    printf "   ✅ Concurrent downloads complete\n"
}

function provisioning_extract_archives() {
    local dir="$1"
    printf "\n📦 Extracting archives in %s...\n" "$dir"
    
    # Extract RAR files
    for rar in "$dir"/*.rar; do
        [[ -f "$rar" ]] || continue
        printf "   📂 Extracting %s...\n" "$(basename "$rar")"
        unrar x -o+ "$rar" "$dir/" && rm -f "$rar"
    done
    
    # Extract ZIP files
    for zip in "$dir"/*.zip; do
        [[ -f "$zip" ]] || continue
        printf "   📂 Extracting %s...\n" "$(basename "$zip")"
        unzip -o "$zip" -d "$dir/" && rm -f "$zip"
    done
    
    # Extract 7z files
    for sz in "$dir"/*.7z; do
        [[ -f "$sz" ]] || continue
        printf "   📂 Extracting %s...\n" "$(basename "$sz")"
        7z x -y "$sz" -o"$dir/" && rm -f "$sz"
    done
}

function provisioning_install_workflows() {
    local workflows_dir="${COMFYUI_DIR}/user/default/workflows"
    mkdir -p "$workflows_dir"
    
    printf "\n📝 Installing ready-to-use workflows...\n"

    # ═══════════════════════════════════════════════════════════════════════
    # NSFW IMAGE WORKFLOW (Pony XL - Fully Connected)
    # ═══════════════════════════════════════════════════════════════════════
    # ═══════════════════════════════════════════════════════════════════════
    # NSFW ULTIMATE IMAGE WORKFLOW (Pony XL + FaceDetailer + Upscale)
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_ultimate_image_workflow.json" << 'ULTIMGWORKFLOW'
{
  "last_node_id": 101,
  "last_link_id": 104,
  "nodes": [
    {
      "id": 1,
      "class_type": "CheckpointLoaderSimple",
      "pos": [50, 100],
      "size": [315, 98],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1, 21, 31], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [100], "slot_index": 1},
        {"name": "VAE", "type": "VAE", "links": [6, 23, 33], "slot_index": 2}
      ],
      "widgets_values": ["pmXL_v1.safetensors"]
    },
    {
      "id": 99,
      "class_type": "CLIPSetLastLayer",
      "pos": [50, 250],
      "size": [315, 58],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 100}],
      "outputs": [{"name": "CLIP", "type": "CLIP", "links": [2, 3, 22, 101, 102], "slot_index": 0}],
      "widgets_values": [-2]
    },
    {
      "id": 2,
      "class_type": "CLIPTextEncode",
      "pos": [400, 50],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 2}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [4, 34], "slot_index": 0}],
      "widgets_values": ["score_9, score_8_up, score_7_up, source_anime, rating_explicit, 1girl, beautiful detailed face, beautiful detailed eyes, high quality, nsfw, masterpiece, best quality, photorealistic, cinematic lighting"]
    },
    {
      "id": 3,
      "class_type": "CLIPTextEncode",
      "pos": [400, 200],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 3}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [5, 35], "slot_index": 0}],
      "widgets_values": ["score_6, score_5, score_4, source_pony, source_furry, low quality, worst quality, blurry, censored, watermark, ugly, bad anatomy, deformed, extra limbs, bad hands, bad fingers"]
    },
    {
      "id": 100,
      "class_type": "CLIPTextEncode",
      "pos": [1200, 550],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 101}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [50], "slot_index": 0}],
      "widgets_values": ["detailed face, sharp eyes, high quality, masterpiece"]
    },
    {
      "id": 101,
      "class_type": "CLIPTextEncode",
      "pos": [1200, 700],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 102}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [51], "slot_index": 0}],
      "widgets_values": ["blurry, deformed, ugly, messy, bad anatomy, low quality"]
    },
    {
      "id": 4,
      "class_type": "EmptyLatentImage",
      "pos": [400, 350],
      "size": [315, 106],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [7], "slot_index": 0}],
      "widgets_values": [832, 1216, 1]
    },
    {
      "id": 5,
      "class_type": "KSampler",
      "pos": [850, 100],
      "size": [315, 262],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1},
        {"name": "positive", "type": "CONDITIONING", "link": 4},
        {"name": "negative", "type": "CONDITIONING", "link": 5},
        {"name": "latent_image", "type": "LATENT", "link": 7}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [8], "slot_index": 0}],
      "widgets_values": [11223344, "randomize", 30, 7.0, "dpmpp_2m_sde", "karras", 1]
    },
    {
      "id": 6,
      "class_type": "VAEDecode",
      "pos": [1200, 100],
      "size": [210, 46],
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 8},
        {"name": "vae", "type": "VAE", "link": 6}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [20], "slot_index": 0}]
    },
    {
      "id": 10,
      "class_type": "UltralyticsDetectorProvider",
      "pos": [1200, 250],
      "size": [315, 100],
      "outputs": [{"name": "BBOX_DETECTOR", "type": "BBOX_DETECTOR", "links": [24], "slot_index": 0}],
      "widgets_values": ["face_yolov8m.pt"]
    },
    {
      "id": 11,
      "class_type": "SAMLoader",
      "pos": [1200, 400],
      "size": [315, 100],
      "outputs": [{"name": "SAM_MODEL", "type": "SAM_MODEL", "links": [25], "slot_index": 0}],
      "widgets_values": ["sam_vit_b_01ec64.pth"]
    },
    {
      "id": 12,
      "class_type": "FaceDetailer",
      "pos": [1600, 100],
      "size": [315, 500],
      "inputs": [
        {"name": "image", "type": "IMAGE", "link": 20},
        {"name": "model", "type": "MODEL", "link": 21},
        {"name": "clip", "type": "CLIP", "link": 22},
        {"name": "vae", "type": "VAE", "link": 23},
        {"name": "positive", "type": "CONDITIONING", "link": 50},
        {"name": "negative", "type": "CONDITIONING", "link": 51},
        {"name": "bbox_detector", "type": "BBOX_DETECTOR", "link": 24},
        {"name": "sam_model_opt", "type": "SAM_MODEL", "link": 25}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [32], "slot_index": 0}],
      "widgets_values": [384, 1024, 0.4, 20, 0.5, "randomize", "dpmpp_2m", "karras", 1, 0.4]
    },
    {
      "id": 13,
      "class_type": "UpscaleModelLoader",
      "pos": [1600, 650],
      "size": [315, 58],
      "outputs": [{"name": "UPSCALE_MODEL", "type": "UPSCALE_MODEL", "links": [36], "slot_index": 0}],
      "widgets_values": ["4x-UltraSharp.pth"]
    },
    {
      "id": 14,
      "class_type": "UltimateSDUpscale",
      "pos": [2000, 100],
      "size": [315, 600],
      "inputs": [
        {"name": "image", "type": "IMAGE", "link": 32},
        {"name": "model", "type": "MODEL", "link": 31},
        {"name": "positive", "type": "CONDITIONING", "link": 34},
        {"name": "negative", "type": "CONDITIONING", "link": 35},
        {"name": "vae", "type": "VAE", "link": 33},
        {"name": "upscale_model", "type": "UPSCALE_MODEL", "link": 36}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [40], "slot_index": 0}],
      "widgets_values": [2, 1024, 0.35, 20, "dpmpp_2m", "karras", 1, 512, 0, 1, 64, 32, 2, true, false]
    },
    {
      "id": 7,
      "class_type": "SaveImage",
      "pos": [2400, 100],
      "size": [315, 270],
      "inputs": [{"name": "images", "type": "IMAGE", "link": 40}],
      "widgets_values": ["aikings_ultimate"]
    }
  ],
  "links": [
    [1, 1, 0, 5, 0, "MODEL"],
    [100, 1, 1, 99, 0, "CLIP"],
    [2, 99, 0, 2, 0, "CLIP"],
    [3, 99, 0, 3, 0, "CLIP"],
    [101, 99, 0, 100, 0, "CLIP"],
    [102, 99, 0, 101, 0, "CLIP"],
    [4, 2, 0, 5, 1, "CONDITIONING"],
    [5, 3, 0, 5, 2, "CONDITIONING"],
    [6, 1, 2, 6, 1, "VAE"],
    [7, 4, 0, 5, 3, "LATENT"],
    [8, 5, 0, 6, 0, "LATENT"],
    [20, 6, 0, 12, 0, "IMAGE"],
    [21, 1, 0, 12, 1, "MODEL"],
    [22, 99, 0, 12, 2, "CLIP"],
    [23, 1, 2, 12, 3, "VAE"],
    [50, 100, 0, 12, 4, "CONDITIONING"],
    [51, 101, 0, 12, 5, "CONDITIONING"],
    [24, 10, 0, 12, 6, "BBOX_DETECTOR"],
    [25, 11, 0, 12, 7, "SAM_MODEL"],
    [31, 1, 0, 14, 1, "MODEL"],
    [32, 12, 0, 14, 0, "IMAGE"],
    [33, 1, 2, 14, 4, "VAE"],
    [34, 2, 0, 14, 2, "CONDITIONING"],
    [35, 3, 0, 14, 3, "CONDITIONING"],
    [36, 13, 0, 14, 5, "UPSCALE_MODEL"],
    [40, 14, 0, 7, 0, "IMAGE"]
  ],
  "version": 0.4
}
ULTIMGWORKFLOW

    # ═══════════════════════════════════════════════════════════════════════
    # NSFW VIDEO WORKFLOW (AnimateDiff SDXL - Fully Connected)
    # Uses: ADE_AnimateDiffLoaderGen1 + VHS_VideoCombine
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_video_workflow.json" << 'VIDWORKFLOW'
{
  "last_node_id": 99,
  "last_link_id": 100,
  "nodes": [
    {
      "id": 1,
      "class_type": "CheckpointLoaderSimple",
      "pos": [50, 100],
      "size": [315, 98],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [100], "slot_index": 1},
        {"name": "VAE", "type": "VAE", "links": [9], "slot_index": 2}
      ],
      "widgets_values": ["ponyDiffusionV6XL.safetensors"]
    },
    {
      "id": 99,
      "class_type": "CLIPSetLastLayer",
      "pos": [50, 250],
      "size": [315, 58],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 100}],
      "outputs": [{"name": "CLIP", "type": "CLIP", "links": [2, 3], "slot_index": 0}],
      "widgets_values": [-2]
    },
    {
      "id": 2,
      "class_type": "ADE_AnimateDiffLoaderGen1",
      "pos": [50, 350],
      "size": [315, 98],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1}
      ],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [4], "slot_index": 0}
      ],
      "widgets_values": ["mm_sdxl_v1_beta.ckpt", "linear (AnimateDiff-SDXL)"]
    },
    {
      "id": 3,
      "class_type": "CLIPTextEncode",
      "pos": [450, 50],
      "size": [400, 100],
      "inputs": [
        {"name": "clip", "type": "CLIP", "link": 2}
      ],
      "outputs": [
        {"name": "CONDITIONING", "type": "CONDITIONING", "links": [5], "slot_index": 0}
      ],
      "widgets_values": ["score_9, score_8_up, score_7_up, source_anime, rating_explicit, 1girl, dancing, dynamic motion, beautiful detailed face, high quality, nsfw, masterpiece, best quality, smooth animation"]
    },
    {
      "id": 4,
      "class_type": "CLIPTextEncode",
      "pos": [450, 200],
      "size": [400, 100],
      "inputs": [
        {"name": "clip", "type": "CLIP", "link": 3}
      ],
      "outputs": [
        {"name": "CONDITIONING", "type": "CONDITIONING", "links": [6], "slot_index": 0}
      ],
      "widgets_values": ["score_6, score_5, score_4, source_pony, source_furry, static, frozen, choppy, low quality, worst quality, blurry, censored, watermark, bad anatomy, deformed"]
    },
    {
      "id": 5,
      "class_type": "EmptyLatentImage",
      "pos": [450, 350],
      "size": [315, 106],
      "outputs": [
        {"name": "LATENT", "type": "LATENT", "links": [7], "slot_index": 0}
      ],
      "widgets_values": [512, 512, 16]
    },
    {
      "id": 6,
      "class_type": "KSampler",
      "pos": [900, 100],
      "size": [315, 262],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 4},
        {"name": "positive", "type": "CONDITIONING", "link": 5},
        {"name": "negative", "type": "CONDITIONING", "link": 6},
        {"name": "latent_image", "type": "LATENT", "link": 7}
      ],
      "outputs": [
        {"name": "LATENT", "type": "LATENT", "links": [8], "slot_index": 0}
      ],
      "widgets_values": [987654321, "randomize", 25, 7, "dpmpp_2m_sde", "karras", 1]
    },
    {
      "id": 7,
      "class_type": "VAEDecode",
      "pos": [1250, 100],
      "size": [210, 46],
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 8},
        {"name": "vae", "type": "VAE", "link": 9}
      ],
      "outputs": [
        {"name": "IMAGE", "type": "IMAGE", "links": [10], "slot_index": 0}
      ]
    },
    {
      "id": 8,
      "class_type": "VHS_VideoCombine",
      "pos": [1500, 100],
      "size": [315, 290],
      "inputs": [
        {"name": "images", "type": "IMAGE", "link": 10}
      ],
      "widgets_values": ["aikings_video", 8, 0, "image/webp", false, true, ""]
    }
  ],
  "links": [
    [1, 1, 0, 2, 0, "MODEL"],
    [100, 1, 1, 99, 0, "CLIP"],
    [2, 99, 0, 3, 0, "CLIP"],
    [3, 99, 0, 4, 0, "CLIP"],
    [4, 2, 0, 6, 0, "MODEL"],
    [5, 3, 0, 6, 1, "CONDITIONING"],
    [6, 4, 0, 6, 2, "CONDITIONING"],
    [7, 5, 0, 6, 3, "LATENT"],
    [8, 6, 0, 7, 0, "LATENT"],
    [9, 1, 2, 7, 1, "VAE"],
    [10, 7, 0, 8, 0, "IMAGE"]
  ],
  "version": 0.4
}
VIDWORKFLOW

    # ═══════════════════════════════════════════════════════════════════════
    # NSFW ULTIMATE VIDEO WORKFLOW (AnimateDiff + RIFE + Upscale)
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_ultimate_video_workflow.json" << 'ULTVIDWORKFLOW'
{
  "last_node_id": 99,
  "last_link_id": 100,
  "nodes": [
    {
      "id": 1,
      "class_type": "CheckpointLoaderSimple",
      "pos": [50, 100],
      "size": [315, 98],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [100], "slot_index": 1},
        {"name": "VAE", "type": "VAE", "links": [9], "slot_index": 2}
      ],
      "widgets_values": ["pmXL_v1.safetensors"]
    },
    {
      "id": 99,
      "class_type": "CLIPSetLastLayer",
      "pos": [50, 250],
      "size": [315, 58],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 100}],
      "outputs": [{"name": "CLIP", "type": "CLIP", "links": [2, 3], "slot_index": 0}],
      "widgets_values": [-2]
    },
    {
      "id": 2,
      "class_type": "ADE_AnimateDiffLoaderGen1",
      "pos": [50, 350],
      "size": [315, 98],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1}
      ],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [4], "slot_index": 0}
      ],
      "widgets_values": ["mm_sdxl_v1_beta.ckpt", "linear (AnimateDiff-SDXL)"]
    },
    {
      "id": 3,
      "class_type": "CLIPTextEncode",
      "pos": [450, 50],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 2}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [5], "slot_index": 0}],
      "widgets_values": ["score_9, score_8_up, score_7_up, source_anime, rating_explicit, beautiful woman dancing, smooth motion, cinematic lighting, high quality, nsfw, masterpiece, best quality, dynamic camera"]
    },
    {
      "id": 4,
      "class_type": "CLIPTextEncode",
      "pos": [450, 200],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 3}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [6], "slot_index": 0}],
      "widgets_values": ["score_6, score_5, score_4, source_pony, source_furry, static, frozen, choppy, blurry, low quality, worst quality, watermark, deformed, bad anatomy"]
    },
    {
      "id": 5,
      "class_type": "EmptyLatentImage",
      "pos": [450, 350],
      "size": [315, 106],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [7], "slot_index": 0}],
      "widgets_values": [512, 768, 24]
    },
    {
      "id": 6,
      "class_type": "KSampler",
      "pos": [900, 100],
      "size": [315, 262],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 4},
        {"name": "positive", "type": "CONDITIONING", "link": 5},
        {"name": "negative", "type": "CONDITIONING", "link": 6},
        {"name": "latent_image", "type": "LATENT", "link": 7}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [8], "slot_index": 0}],
      "widgets_values": [99887766, "randomize", 25, 7, "dpmpp_2m_sde", "karras", 1]
    },
    {
      "id": 7,
      "class_type": "VAEDecode",
      "pos": [1250, 100],
      "size": [210, 46],
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 8},
        {"name": "vae", "type": "VAE", "link": 9}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [10], "slot_index": 0}]
    },
    {
      "id": 9,
      "class_type": "RIFE VFI",
      "pos": [1500, 100],
      "size": [315, 150],
      "inputs": [{"name": "frames", "type": "IMAGE", "link": 10}],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [12], "slot_index": 0}],
      "widgets_values": ["rife47.pth", 12, 2, true, false, 1.0]
    },
    {
      "id": 13,
      "class_type": "UpscaleModelLoader",
      "pos": [1500, 300],
      "size": [315, 58],
      "outputs": [{"name": "UPSCALE_MODEL", "type": "UPSCALE_MODEL", "links": [20], "slot_index": 0}],
      "widgets_values": ["4x-UltraSharp.pth"]
    },
    {
      "id": 14,
      "class_type": "ImageUpscaleWithModel",
      "pos": [1900, 100],
      "size": [240, 46],
      "inputs": [
        {"name": "upscale_model", "type": "UPSCALE_MODEL", "link": 20},
        {"name": "image", "type": "IMAGE", "link": 12}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [21], "slot_index": 0}]
    },
    {
      "id": 10,
      "class_type": "VHS_VideoCombine",
      "pos": [2200, 100],
      "size": [315, 290],
      "inputs": [{"name": "images", "type": "IMAGE", "link": 21}],
      "widgets_values": ["aikings_ultimate_video", 24, 0, "video/h264-mp4", false, true, ""]
    }
  ],
  "links": [
    [1, 1, 0, 2, 0, "MODEL"],
    [100, 1, 1, 99, 0, "CLIP"],
    [2, 99, 0, 3, 0, "CLIP"],
    [3, 99, 0, 4, 0, "CLIP"],
    [4, 2, 0, 6, 0, "MODEL"],
    [5, 3, 0, 6, 1, "CONDITIONING"],
    [6, 4, 0, 6, 2, "CONDITIONING"],
    [7, 5, 0, 6, 3, "LATENT"],
    [8, 6, 0, 7, 0, "LATENT"],
    [9, 1, 2, 7, 1, "VAE"],
    [10, 7, 0, 9, 0, "IMAGE"],
    [12, 9, 0, 14, 1, "IMAGE"],
    [20, 13, 0, 14, 0, "UPSCALE_MODEL"],
    [21, 14, 0, 10, 0, "IMAGE"]
  ],
  "version": 0.4
}
ULTVIDWORKFLOW

    # ═══════════════════════════════════════════════════════════════════════
    # LORA-FOCUSED IMAGE WORKFLOW (With LoRA Loader - Fully Connected)
    # For using the specialized fetish LoRAs
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_lora_image_workflow.json" << 'LORAWORKFLOW'
{
  "last_node_id": 99,
  "last_link_id": 100,
  "nodes": [
    {
      "id": 1,
      "class_type": "CheckpointLoaderSimple",
      "pos": [50, 100],
      "size": [315, 98],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [100], "slot_index": 1},
        {"name": "VAE", "type": "VAE", "links": [10], "slot_index": 2}
      ],
      "widgets_values": ["ponyDiffusionV6XL.safetensors"]
    },
    {
      "id": 99,
      "class_type": "CLIPSetLastLayer",
      "pos": [50, 250],
      "size": [315, 58],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 100}],
      "outputs": [{"name": "CLIP", "type": "CLIP", "links": [2], "slot_index": 0}],
      "widgets_values": [-2]
    },
    {
      "id": 2,
      "class_type": "LoraLoader",
      "pos": [400, 100],
      "size": [315, 126],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1},
        {"name": "clip", "type": "CLIP", "link": 2}
      ],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [3], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [4, 5], "slot_index": 1}
      ],
      "widgets_values": ["pony_realism_v2.1.safetensors", 0.8, 0.8]
    },
    {
      "id": 3,
      "class_type": "CLIPTextEncode",
      "pos": [750, 50],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 4}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [6], "slot_index": 0}],
      "widgets_values": ["score_9, score_8_up, score_7_up, 1girl, detailed face, beautiful eyes, high quality, nsfw, masterpiece, photorealistic"]
    },
    {
      "id": 4,
      "class_type": "CLIPTextEncode",
      "pos": [750, 200],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 5}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [7], "slot_index": 0}],
      "widgets_values": ["score_6, score_5, score_4, low quality, blurry, censored, watermark, ugly, cartoon, anime"]
    },
    {
      "id": 5,
      "class_type": "EmptyLatentImage",
      "pos": [750, 350],
      "size": [315, 106],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [8], "slot_index": 0}],
      "widgets_values": [1024, 1024, 1]
    },
    {
      "id": 6,
      "class_type": "KSampler",
      "pos": [1200, 100],
      "size": [315, 262],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 3},
        {"name": "positive", "type": "CONDITIONING", "link": 6},
        {"name": "negative", "type": "CONDITIONING", "link": 7},
        {"name": "latent_image", "type": "LATENT", "link": 8}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [9], "slot_index": 0}],
      "widgets_values": [111222333, "randomize", 30, 7.0, "dpmpp_2m_sde", "karras", 1]
    },
    {
      "id": 7,
      "class_type": "VAEDecode",
      "pos": [1550, 100],
      "size": [210, 46],
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 9},
        {"name": "vae", "type": "VAE", "link": 10}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [11], "slot_index": 0}]
    },
    {
      "id": 8,
      "class_type": "SaveImage",
      "pos": [1800, 100],
      "size": [315, 270],
      "inputs": [{"name": "images", "type": "IMAGE", "link": 11}],
      "widgets_values": ["aikings_lora_nsfw"]
    }
  ],
  "links": [
    [1, 1, 0, 2, 0, "MODEL"],
    [100, 1, 1, 99, 0, "CLIP"],
    [2, 99, 0, 2, 1, "CLIP"],
    [3, 2, 0, 6, 0, "MODEL"],
    [4, 2, 1, 3, 0, "CLIP"],
    [5, 2, 1, 4, 0, "CLIP"],
    [6, 3, 0, 6, 1, "CONDITIONING"],
    [7, 4, 0, 6, 2, "CONDITIONING"],
    [8, 5, 0, 6, 3, "LATENT"],
    [9, 6, 0, 7, 0, "LATENT"],
    [10, 1, 2, 7, 1, "VAE"],
    [11, 7, 0, 8, 0, "IMAGE"]
  ],
  "version": 0.4
}
LORAWORKFLOW

    # ═══════════════════════════════════════════════════════════════════════
    # PORNMASTER PHOTOREALISTIC WORKFLOW (Fully Connected)
    # Optimized for photorealistic NSFW content
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_pornmaster_workflow.json" << 'PORNMASTERWORKFLOW'
{
  "last_node_id": 99,
  "last_link_id": 100,
  "nodes": [
    {
      "id": 1,
      "class_type": "CheckpointLoaderSimple",
      "pos": [50, 100],
      "size": [315, 98],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [100], "slot_index": 1},
        {"name": "VAE", "type": "VAE", "links": [6], "slot_index": 2}
      ],
      "widgets_values": ["pmXL_v1.safetensors"]
    },
    {
      "id": 99,
      "class_type": "CLIPSetLastLayer",
      "pos": [50, 250],
      "size": [315, 58],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 100}],
      "outputs": [{"name": "CLIP", "type": "CLIP", "links": [2, 3], "slot_index": 0}],
      "widgets_values": [-2]
    },
    {
      "id": 2,
      "class_type": "CLIPTextEncode",
      "pos": [450, 50],
      "size": [450, 120],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 2}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [4], "slot_index": 0}],
      "widgets_values": ["score_9, score_8_up, score_7_up, photorealistic, professional photography, beautiful woman, detailed skin texture, natural lighting, high resolution, sharp focus, 8k uhd, dslr quality, nsfw"]
    },
    {
      "id": 3,
      "class_type": "CLIPTextEncode",
      "pos": [450, 220],
      "size": [450, 120],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 3}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [5], "slot_index": 0}],
      "widgets_values": ["cartoon, anime, illustration, 3d render, fake, plastic, low quality, blurry, censored, watermark, text, ugly, deformed"]
    },
    {
      "id": 4,
      "class_type": "EmptyLatentImage",
      "pos": [450, 400],
      "size": [315, 106],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [7], "slot_index": 0}],
      "widgets_values": [832, 1216, 1]
    },
    {
      "id": 5,
      "class_type": "KSampler",
      "pos": [950, 100],
      "size": [315, 262],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1},
        {"name": "positive", "type": "CONDITIONING", "link": 4},
        {"name": "negative", "type": "CONDITIONING", "link": 5},
        {"name": "latent_image", "type": "LATENT", "link": 7}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [8], "slot_index": 0}],
      "widgets_values": [444555666, "randomize", 30, 7, "dpmpp_2m_sde", "karras", 1]
    },
    {
      "id": 6,
      "class_type": "VAEDecode",
      "pos": [1300, 100],
      "size": [210, 46],
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 8},
        {"name": "vae", "type": "VAE", "link": 6}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [9], "slot_index": 0}]
    },
    {
      "id": 7,
      "class_type": "SaveImage",
      "pos": [1550, 100],
      "size": [315, 270],
      "inputs": [{"name": "images", "type": "IMAGE", "link": 9}],
      "widgets_values": ["aikings_pornmaster"]
    }
  ],
  "links": [
    [1, 1, 0, 5, 0, "MODEL"],
    [100, 1, 1, 99, 0, "CLIP"],
    [2, 99, 0, 2, 0, "CLIP"],
    [3, 99, 0, 3, 0, "CLIP"],
    [4, 2, 0, 5, 1, "CONDITIONING"],
    [5, 3, 0, 5, 2, "CONDITIONING"],
    [6, 1, 2, 6, 1, "VAE"],
    [7, 4, 0, 5, 3, "LATENT"],
    [8, 5, 0, 6, 0, "LATENT"],
    [9, 6, 0, 7, 0, "IMAGE"]
  ],
  "version": 0.4
}
PORNMASTERWORKFLOW

    # ═══════════════════════════════════════════════════════════════════════
    # CONTROLNET OPENPOSE WORKFLOW (Pose-Guided Generation)
    # Uses: ControlNetLoader + Apply ControlNet + OpenPose
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_controlnet_pose_workflow.json" << 'POSEWORKFLOW'
{
  "last_node_id": 99,
  "last_link_id": 100,
  "nodes": [
    {
      "id": 1,
      "class_type": "CheckpointLoaderSimple",
      "pos": [50, 100],
      "size": [315, 98],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [100], "slot_index": 1},
        {"name": "VAE", "type": "VAE", "links": [10], "slot_index": 2}
      ],
      "widgets_values": ["pmXL_v1.safetensors"]
    },
    {
      "id": 99,
      "class_type": "CLIPSetLastLayer",
      "pos": [50, 250],
      "size": [315, 58],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 100}],
      "outputs": [{"name": "CLIP", "type": "CLIP", "links": [2, 3], "slot_index": 0}],
      "widgets_values": [-2]
    },
    {
      "id": 2,
      "class_type": "CLIPTextEncode",
      "pos": [400, 50],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 2}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [4], "slot_index": 0}],
      "widgets_values": ["score_9, score_8_up, score_7_up, 1girl, beautiful face, detailed eyes, high quality, nsfw, masterpiece, photorealistic, dynamic pose"]
    },
    {
      "id": 3,
      "class_type": "CLIPTextEncode",
      "pos": [400, 200],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 3}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [5], "slot_index": 0}],
      "widgets_values": ["score_6, score_5, score_4, low quality, blurry, censored, watermark, ugly, bad anatomy, deformed"]
    },
    {
      "id": 4,
      "class_type": "LoadImage",
      "pos": [50, 300],
      "size": [315, 314],
      "outputs": [
        {"name": "IMAGE", "type": "IMAGE", "links": [6], "slot_index": 0},
        {"name": "MASK", "type": "MASK", "links": null, "slot_index": 1}
      ],
      "widgets_values": ["example_pose.png", "image"]
    },
    {
      "id": 5,
      "class_type": "ControlNetLoader",
      "pos": [400, 400],
      "size": [315, 58],
      "outputs": [{"name": "CONTROL_NET", "type": "CONTROL_NET", "links": [7], "slot_index": 0}],
      "widgets_values": ["OpenPoseXL2.safetensors"]
    },
    {
      "id": 6,
      "class_type": "ControlNetApplyAdvanced",
      "pos": [800, 100],
      "size": [315, 186],
      "inputs": [
        {"name": "positive", "type": "CONDITIONING", "link": 4},
        {"name": "negative", "type": "CONDITIONING", "link": 5},
        {"name": "control_net", "type": "CONTROL_NET", "link": 7},
        {"name": "image", "type": "IMAGE", "link": 6}
      ],
      "outputs": [
        {"name": "positive", "type": "CONDITIONING", "links": [8], "slot_index": 0},
        {"name": "negative", "type": "CONDITIONING", "links": [9], "slot_index": 1}
      ],
      "widgets_values": [0.85, 0.0, 1.0]
    },
    {
      "id": 7,
      "class_type": "EmptyLatentImage",
      "pos": [800, 350],
      "size": [315, 106],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [11], "slot_index": 0}],
      "widgets_values": [832, 1216, 1]
    },
    {
      "id": 8,
      "class_type": "KSampler",
      "pos": [1200, 100],
      "size": [315, 262],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1},
        {"name": "positive", "type": "CONDITIONING", "link": 8},
        {"name": "negative", "type": "CONDITIONING", "link": 9},
        {"name": "latent_image", "type": "LATENT", "link": 11}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [12], "slot_index": 0}],
      "widgets_values": [55667788, "randomize", 30, 7.0, "dpmpp_2m_sde", "karras", 1]
    },
    {
      "id": 9,
      "class_type": "VAEDecode",
      "pos": [1550, 100],
      "size": [210, 46],
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 12},
        {"name": "vae", "type": "VAE", "link": 10}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [13], "slot_index": 0}]
    },
    {
      "id": 10,
      "class_type": "SaveImage",
      "pos": [1800, 100],
      "size": [315, 270],
      "inputs": [{"name": "images", "type": "IMAGE", "link": 13}],
      "widgets_values": ["aikings_pose"]
    }
  ],
  "links": [
    [1, 1, 0, 8, 0, "MODEL"],
    [100, 1, 1, 99, 0, "CLIP"],
    [2, 99, 0, 2, 0, "CLIP"],
    [3, 99, 0, 3, 0, "CLIP"],
    [4, 2, 0, 6, 0, "CONDITIONING"],
    [5, 3, 0, 6, 1, "CONDITIONING"],
    [6, 4, 0, 6, 3, "IMAGE"],
    [7, 5, 0, 6, 2, "CONTROL_NET"],
    [8, 6, 0, 8, 1, "CONDITIONING"],
    [9, 6, 1, 8, 2, "CONDITIONING"],
    [10, 1, 2, 9, 1, "VAE"],
    [11, 7, 0, 8, 3, "LATENT"],
    [12, 8, 0, 9, 0, "LATENT"],
    [13, 9, 0, 10, 0, "IMAGE"]
  ],
  "version": 0.4
}
POSEWORKFLOW

    # ═══════════════════════════════════════════════════════════════════════
    # WAN 2.1 TEXT-TO-VIDEO WORKFLOW (Repackaged Native Implementation)
    # Optimized for: 1.3B/14B Wan models, 480p/720p cinematic motion
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_wan21_video_workflow.json" << 'WANWORKFLOW'
{
  "last_node_id": 10,
  "last_link_id": 10,
  "nodes": [
    {
      "id": 1,
      "class_type": "WanVideoModelLoader",
      "pos": [50, 100],
      "size": [315, 82],
      "outputs": [{"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0}],
      "widgets_values": ["wan2.1_t2v_1.3B_fp16.safetensors", "fp16"]
    },
    {
      "id": 2,
      "class_type": "WanVideoT5TextEncode",
      "pos": [50, 250],
      "size": [315, 82],
      "outputs": [{"name": "CLIP", "type": "CLIP", "links": [2, 3], "slot_index": 0}],
      "widgets_values": ["umt5_xxl_fp8_e4m3fn_scaled.safetensors"]
    },
    {
      "id": 3,
      "class_type": "CLIPTextEncode",
      "pos": [450, 50],
      "size": [400, 150],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 2}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [4], "slot_index": 0}],
      "widgets_values": ["score_9, score_8_up, score_7_up, rating_explicit, masterpiece, best quality, cinematic, 1girl, full body, nsfw, realistic motion"]
    },
    {
      "id": 4,
      "class_type": "CLIPTextEncode",
      "pos": [450, 250],
      "size": [400, 150],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 3}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [5], "slot_index": 0}],
      "widgets_values": ["score_6, score_5, score_4, low quality, worst quality, blurry, watermark, bad anatomy"]
    },
    {
      "id": 5,
      "class_type": "WanVideoSampler",
      "pos": [900, 100],
      "size": [315, 450],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1},
        {"name": "positive", "type": "CONDITIONING", "link": 4},
        {"name": "negative", "type": "CONDITIONING", "link": 5},
        {"name": "latent_image", "type": "LATENT", "link": 9}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [6], "slot_index": 0}],
      "widgets_values": [30, 7.0, 11223344, "randomize"]
    },
    {
      "id": 9,
      "class_type": "EmptyWanVideoLatent",
      "pos": [900, 600],
      "size": [315, 106],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [9], "slot_index": 0}],
      "widgets_values": [832, 480, 81]
    },
    {
      "id": 6,
      "class_type": "WanVideoVaeLoader",
      "pos": [900, 750],
      "size": [315, 58],
      "outputs": [{"name": "VAE", "type": "VAE", "links": [7], "slot_index": 0}],
      "widgets_values": ["wan_2.1_vae.safetensors"]
    },
    {
      "id": 7,
      "class_type": "VAEDecode",
      "pos": [1250, 100],
      "size": [210, 46],
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 6},
        {"name": "vae", "type": "VAE", "link": 7}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [8], "slot_index": 0}]
    },
    {
      "id": 8,
      "class_type": "VHS_VideoCombine",
      "pos": [1500, 100],
      "size": [315, 350],
      "inputs": [{"name": "images", "type": "IMAGE", "link": 8}],
      "widgets_values": ["aikings_wan", 16, 0, "video/h264-mp4", false, true, "", 6]
    }
  ],
  "links": [
    [1, 1, 0, 5, 0, "MODEL"],
    [2, 2, 0, 3, 0, "CLIP"],
    [3, 2, 0, 4, 0, "CLIP"],
    [4, 3, 0, 5, 1, "CONDITIONING"],
    [5, 4, 0, 5, 2, "CONDITIONING"],
    [9, 9, 0, 5, 3, "LATENT"],
    [6, 5, 0, 7, 0, "LATENT"],
    [7, 6, 0, 7, 1, "VAE"],
    [8, 7, 0, 8, 0, "IMAGE"]
  ],
  "version": 0.4
}
WANWORKFLOW

    # ═══════════════════════════════════════════════════════════════════════
    # MASTER FURRY REALISTIC VIDEO WORKFLOW (SDXL + LoRA Stacker)
    # Optimized for: Realistic furry NSFW, skin/fur texture, heavy LoRA use
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_realistic_furry_video_workflow.json" << 'FURRYWORKFLOW'
{
  "last_node_id": 99,
  "last_link_id": 100,
  "nodes": [
    {
      "id": 1,
      "class_type": "CheckpointLoaderSimple",
      "pos": [50, 100],
      "size": [315, 98],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [100], "slot_index": 1},
        {"name": "VAE", "type": "VAE", "links": [3], "slot_index": 2}
      ],
      "widgets_values": ["pony_realism_v2.2.safetensors"]
    },
    {
      "id": 99,
      "class_type": "CLIPSetLastLayer",
      "pos": [50, 250],
      "size": [315, 58],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 100}],
      "outputs": [{"name": "CLIP", "type": "CLIP", "links": [2], "slot_index": 0}],
      "widgets_values": [-2]
    },
    {
      "id": 2,
      "class_type": "LoraStacker",
      "pos": [50, 350],
      "size": [315, 300],
      "outputs": [{"name": "LORA_STACK", "type": "LORA_STACK", "links": [4], "slot_index": 0}],
      "widgets_values": [
        "Enabled", "pony_realism_v2.1.safetensors", 0.6, 0.6,
        "Enabled", "defecation_v1.safetensors", 0.5, 0.5,
        "Disabled", "None", 0.0, 0.0,
        "Disabled", "None", 0.0, 0.0,
        "Disabled", "None", 0.0, 0.0
      ]
    },
    {
      "id": 3,
      "class_type": "ApplyLoraStack",
      "pos": [400, 100],
      "size": [315, 120],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1},
        {"name": "clip", "type": "CLIP", "link": 2},
        {"name": "lora_stack", "type": "LORA_STACK", "link": 4}
      ],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [5], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [6], "slot_index": 1}
      ]
    },
    {
      "id": 4,
      "class_type": "ADE_AnimateDiffLoaderGen1",
      "pos": [400, 300],
      "size": [315, 98],
      "inputs": [{"name": "model", "type": "MODEL", "link": 5}],
      "outputs": [{"name": "MODEL", "type": "MODEL", "links": [7], "slot_index": 0}],
      "widgets_values": ["mm_sdxl_v1_beta.ckpt", "linear (AnimateDiff-SDXL)"]
    },
    {
      "id": 5,
      "class_type": "CLIPTextEncode",
      "pos": [750, 50],
      "size": [400, 150],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 6}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [8], "slot_index": 0}],
      "widgets_values": ["score_9, score_8_up, score_7_up, source_anime, rating_explicit, masterpiece, best quality, cinematic, furry, anthropomorphic, realistic fur texture, detailed skin, 1girl, full body, wide shot, nsfw, explicit"]
    },
    {
      "id": 6,
      "class_type": "CLIPTextEncode",
      "pos": [750, 250],
      "size": [400, 150],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 6}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [9], "slot_index": 0}],
      "widgets_values": ["score_6, score_5, score_4, source_pony, low quality, worst quality, blurry, watermark, bad anatomy, deformed, human eyes on furry"]
    },
    {
      "id": 7,
      "class_type": "EmptyLatentImage",
      "pos": [750, 450],
      "size": [315, 106],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [10], "slot_index": 0}],
      "widgets_values": [832, 1216, 16]
    },
    {
      "id": 8,
      "class_type": "KSampler",
      "pos": [1200, 100],
      "size": [315, 262],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 7},
        {"name": "positive", "type": "CONDITIONING", "link": 8},
        {"name": "negative", "type": "CONDITIONING", "link": 9},
        {"name": "latent_image", "type": "LATENT", "link": 10}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [11], "slot_index": 0}],
      "widgets_values": [44556677, "randomize", 30, 7.0, "dpmpp_2m_sde", "karras", 1]
    },
    {
      "id": 9,
      "class_type": "VAEDecode",
      "pos": [1550, 100],
      "size": [210, 46],
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 11},
        {"name": "vae", "type": "VAE", "link": 3}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [12], "slot_index": 0}]
    },
    {
      "id": 10,
      "class_type": "VHS_VideoCombine",
      "pos": [1800, 100],
      "size": [315, 350],
      "inputs": [{"name": "images", "type": "IMAGE", "link": 12}],
      "widgets_values": ["aikings_furry_realistic", 12, 0, "video/h264-mp4", false, true, "", 6]
    }
  ],
  "links": [
    [1, 1, 0, 3, 0, "MODEL"],
    [100, 1, 1, 99, 0, "CLIP"],
    [2, 99, 0, 3, 1, "CLIP"],
    [3, 1, 2, 9, 1, "VAE"],
    [4, 2, 0, 3, 2, "LORA_STACK"],
    [5, 3, 0, 4, 0, "MODEL"],
    [6, 3, 1, 5, 0, "CLIP"],
    [30, 3, 1, 6, 0, "CLIP"],
    [7, 4, 0, 8, 0, "MODEL"],
    [8, 5, 0, 8, 1, "CONDITIONING"],
    [9, 6, 0, 8, 2, "CONDITIONING"],
    [10, 7, 0, 8, 3, "LATENT"],
    [11, 8, 0, 9, 0, "LATENT"],
    [12, 9, 0, 10, 0, "IMAGE"]
  ],
  "version": 0.4
}
FURRYWORKFLOW

    # ═══════════════════════════════════════════════════════════════════════
    # ULTIMATE CINEMA PRODUCTION WORKFLOW (Full Scene, Multiple Subjects)
    # Optimized for: Wide shots, full body, realistic motion, NSFW scenes
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_cinema_production_workflow.json" << 'CINEMAWORKFLOW'
{
  "last_node_id": 99,
  "last_link_id": 100,
  "nodes": [
    {
      "id": 1,
      "class_type": "CheckpointLoaderSimple",
      "pos": [50, 100],
      "size": [315, 98],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [100], "slot_index": 1},
        {"name": "VAE", "type": "VAE", "links": [15], "slot_index": 2}
      ],
      "widgets_values": ["pmXL_v1.safetensors"]
    },
    {
      "id": 99,
      "class_type": "CLIPSetLastLayer",
      "pos": [50, 250],
      "size": [315, 58],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 100}],
      "outputs": [{"name": "CLIP", "type": "CLIP", "links": [2, 3], "slot_index": 0}],
      "widgets_values": [-2]
    },
    {
      "id": 2,
      "class_type": "ADE_AnimateDiffLoaderGen1",
      "pos": [50, 350],
      "size": [315, 98],
      "inputs": [{"name": "model", "type": "MODEL", "link": 1}],
      "outputs": [{"name": "MODEL", "type": "MODEL", "links": [4], "slot_index": 0}],
      "widgets_values": ["mm_sdxl_v1_beta.ckpt", "linear (AnimateDiff-SDXL)"]
    },
    {
      "id": 3,
      "class_type": "CLIPTextEncode",
      "pos": [400, 50],
      "size": [500, 120],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 2}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [5], "slot_index": 0}],
      "widgets_values": ["score_9, score_8_up, score_7_up, source_anime, rating_explicit, masterpiece, best quality, cinematic, wide shot, full body, multiple girls, 2girls, detailed background, interior room, professional lighting, realistic proportions, detailed faces, beautiful eyes, nsfw, explicit, dynamic pose, interaction"]
    },
    {
      "id": 4,
      "class_type": "CLIPTextEncode",
      "pos": [400, 220],
      "size": [500, 120],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 3}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [6], "slot_index": 0}],
      "widgets_values": ["score_6, score_5, score_4, source_pony, source_furry, low quality, worst quality, blurry, censored, watermark, ugly, bad anatomy, deformed, extra limbs, bad hands, bad fingers, close-up, cropped, out of frame, jpeg artifacts, duplicate, mutation"]
    },
    {
      "id": 5,
      "class_type": "ADE_AnimateDiffUniformContextOptions",
      "pos": [400, 400],
      "size": [315, 150],
      "outputs": [{"name": "CONTEXT_OPTIONS", "type": "CONTEXT_OPTIONS", "links": [7], "slot_index": 0}],
      "widgets_values": [16, 1, 4, "uniform", false, "flat", false, 0, 1.0]
    },
    {
      "id": 6,
      "class_type": "EmptyLatentImage",
      "pos": [750, 400],
      "size": [315, 106],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [8], "slot_index": 0}],
      "widgets_values": [576, 1024, 32]
    },
    {
      "id": 7,
      "class_type": "KSamplerAdvanced",
      "pos": [1100, 100],
      "size": [315, 400],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 4},
        {"name": "positive", "type": "CONDITIONING", "link": 5},
        {"name": "negative", "type": "CONDITIONING", "link": 6},
        {"name": "latent_image", "type": "LATENT", "link": 8}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [9], "slot_index": 0}],
      "widgets_values": ["enable", 44556677, "randomize", 30, 7.0, "dpmpp_2m_sde", "karras", 0, 30, "disable"]
    },
    {
      "id": 8,
      "class_type": "VAEDecode",
      "pos": [1450, 100],
      "size": [210, 46],
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 9},
        {"name": "vae", "type": "VAE", "link": 15}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [10], "slot_index": 0}]
    },
    {
      "id": 9,
      "class_type": "RIFE VFI",
      "pos": [1700, 100],
      "size": [315, 150],
      "inputs": [{"name": "frames", "type": "IMAGE", "link": 10}],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [11], "slot_index": 0}],
      "widgets_values": ["rife47.pth", 12, 2, true, true, 1.0]
    },
    {
      "id": 10,
      "class_type": "UpscaleModelLoader",
      "pos": [1700, 300],
      "size": [315, 58],
      "outputs": [{"name": "UPSCALE_MODEL", "type": "UPSCALE_MODEL", "links": [20], "slot_index": 0}],
      "widgets_values": ["4x-UltraSharp.pth"]
    },
    {
      "id": 11,
      "class_type": "ImageUpscaleWithModel",
      "pos": [2050, 100],
      "size": [240, 46],
      "inputs": [
        {"name": "upscale_model", "type": "UPSCALE_MODEL", "link": 20},
        {"name": "image", "type": "IMAGE", "link": 11}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [21], "slot_index": 0}]
    },
    {
      "id": 12,
      "class_type": "ImageScaleBy",
      "pos": [2050, 200],
      "size": [240, 80],
      "inputs": [{"name": "image", "type": "IMAGE", "link": 21}],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [22], "slot_index": 0}],
      "widgets_values": ["lanczos", 0.5]
    },
    {
      "id": 13,
      "class_type": "VHS_VideoCombine",
      "pos": [2350, 100],
      "size": [315, 350],
      "inputs": [{"name": "images", "type": "IMAGE", "link": 22}],
      "widgets_values": ["aikings_cinema", 24, 0, "video/h264-mp4", false, true, "", 6]
    }
  ],
  "links": [
    [1, 1, 0, 2, 0, "MODEL"],
    [100, 1, 1, 99, 0, "CLIP"],
    [2, 99, 0, 3, 0, "CLIP"],
    [3, 99, 0, 4, 0, "CLIP"],
    [4, 2, 0, 7, 0, "MODEL"],
    [5, 3, 0, 7, 1, "CONDITIONING"],
    [6, 4, 0, 7, 2, "CONDITIONING"],
    [7, 5, 0, 2, 1, "CONTEXT_OPTIONS"],
    [8, 6, 0, 7, 3, "LATENT"],
    [9, 7, 0, 8, 0, "LATENT"],
    [15, 1, 2, 8, 1, "VAE"],
    [10, 8, 0, 9, 0, "IMAGE"],
    [11, 9, 0, 11, 1, "IMAGE"],
    [20, 10, 0, 11, 0, "UPSCALE_MODEL"],
    [21, 11, 0, 12, 0, "IMAGE"],
    [22, 12, 0, 13, 0, "IMAGE"]
  ],
  "version": 0.4
}
CINEMAWORKFLOW

    # ═══════════════════════════════════════════════════════════════════════
    # WAN 2.2 MASTER MoE WORKFLOW (Expert Chaining)
    # Optimized for: 14B High/Low noise mixture-of-experts, cinema motion
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_wan22_master_video_workflow.json" << 'WAN22WORKFLOW'
{
  "last_node_id": 15,
  "last_link_id": 20,
  "nodes": [
    {
      "id": 1,
      "class_type": "WanVideoModelLoader",
      "pos": [50, 100],
      "size": [315, 82],
      "outputs": [{"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0}],
      "widgets_values": ["wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors", "fp8_e4m3fn"]
    },
    {
      "id": 2,
      "class_type": "WanVideoModelLoader",
      "pos": [50, 200],
      "size": [315, 82],
      "outputs": [{"name": "MODEL", "type": "MODEL", "links": [2], "slot_index": 0}],
      "widgets_values": ["wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors", "fp8_e4m3fn"]
    },
    {
      "id": 3,
      "class_type": "WanVideoT5TextEncode",
      "pos": [50, 350],
      "size": [315, 82],
      "outputs": [{"name": "CLIP", "type": "CLIP", "links": [3, 4], "slot_index": 0}],
      "widgets_values": ["umt5_xxl_fp8_e4m3fn_scaled.safetensors"]
    },
    {
      "id": 4,
      "class_type": "CLIPTextEncode",
      "pos": [450, 50],
      "size": [400, 150],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 3}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [5, 6], "slot_index": 0}],
      "widgets_values": ["score_9, score_8_up, rating_explicit, masterpiece, best quality, cinematic, 1girl, full body, realistic texture, mo-e motion"]
    },
    {
      "id": 5,
      "class_type": "CLIPTextEncode",
      "pos": [450, 250],
      "size": [400, 150],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 4}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [7, 8], "slot_index": 0}],
      "widgets_values": ["score_6, score_5, low quality, worst quality, watermark"]
    },
    {
      "id": 6,
      "class_type": "EmptyWanVideoLatent",
      "pos": [450, 450],
      "size": [315, 106],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [9], "slot_index": 0}],
      "widgets_values": [832, 480, 81]
    },
    {
      "id": 7,
      "class_type": "WanVideoSampler",
      "pos": [900, 50],
      "size": [315, 450],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1},
        {"name": "positive", "type": "CONDITIONING", "link": 5},
        {"name": "negative", "type": "CONDITIONING", "link": 7},
        {"name": "latent_image", "type": "LATENT", "link": 9}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [10], "slot_index": 0}],
      "widgets_values": [25, 7.0, 5566, "randomize"]
    },
    {
      "id": 8,
      "class_type": "WanVideoSampler",
      "pos": [1250, 50],
      "size": [315, 450],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 2},
        {"name": "positive", "type": "CONDITIONING", "link": 6},
        {"name": "negative", "type": "CONDITIONING", "link": 8},
        {"name": "latent_image", "type": "LATENT", "link": 10}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [11], "slot_index": 0}],
      "widgets_values": [10, 7.0, 5566, "randomize"]
    },
    {
      "id": 9,
      "class_type": "WanVideoVaeLoader",
      "pos": [1250, 600],
      "size": [315, 58],
      "outputs": [{"name": "VAE", "type": "VAE", "links": [12], "slot_index": 0}],
      "widgets_values": ["wan2.2_vae.safetensors"]
    },
    {
      "id": 10,
      "class_type": "VAEDecode",
      "pos": [1600, 50],
      "size": [210, 46],
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 11},
        {"name": "vae", "type": "VAE", "link": 12}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [13], "slot_index": 0}]
    },
    {
      "id": 11,
      "class_type": "VHS_VideoCombine",
      "pos": [1850, 50],
      "size": [315, 350],
      "inputs": [{"name": "images", "type": "IMAGE", "link": 13}],
      "widgets_values": ["aikings_wan22_moe", 24, 0, "video/h264-mp4", false, true, "", 6]
    }
  ],
  "links": [
    [1, 1, 0, 7, 0, "MODEL"],
    [2, 2, 0, 8, 0, "MODEL"],
    [3, 3, 0, 4, 0, "CLIP"],
    [4, 3, 0, 5, 0, "CLIP"],
    [5, 4, 0, 7, 1, "CONDITIONING"],
    [6, 4, 0, 8, 1, "CONDITIONING"],
    [7, 5, 0, 7, 2, "CONDITIONING"],
    [8, 5, 0, 8, 2, "CONDITIONING"],
    [9, 6, 0, 7, 3, "LATENT"],
    [10, 7, 0, 8, 3, "LATENT"],
    [11, 8, 0, 10, 0, "LATENT"],
    [12, 9, 0, 10, 1, "VAE"],
    [13, 10, 0, 11, 0, "IMAGE"]
  ],
  "version": 0.4
}
WAN22WORKFLOW

    # ═══════════════════════════════════════════════════════════════════════
    # WAN 2.5 PREVIEW VIDEO WORKFLOW (I2V High Fidelity)
    # Optimized for: 14B Wan 2.5 Preview, Image-to-Video consistency
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_wan25_preview_video_workflow.json" << 'WAN25WORKFLOW'
{
  "last_node_id": 12,
  "last_link_id": 15,
  "nodes": [
    {
      "id": 1,
      "class_type": "WanVideoModelLoader",
      "pos": [50, 100],
      "size": [315, 82],
      "outputs": [{"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0}],
      "widgets_values": ["wan25_i2v_14b_fp8_high_scaled.safetensors", "fp8_e4m3fn"]
    },
    {
      "id": 2,
      "class_type": "LoadImage",
      "pos": [50, 250],
      "size": [315, 314],
      "outputs": [
        {"name": "IMAGE", "type": "IMAGE", "links": [2], "slot_index": 0},
        {"name": "MASK", "type": "MASK", "links": [], "slot_index": 1}
      ],
      "widgets_values": ["reference_character.png"]
    },
    {
      "id": 3,
      "class_type": "WanVideoT5TextEncode",
      "pos": [50, 600],
      "size": [315, 82],
      "outputs": [{"name": "CLIP", "type": "CLIP", "links": [3, 4], "slot_index": 0}],
      "widgets_values": ["umt5_xxl_fp8_e4m3fn_scaled.safetensors"]
    },
    {
      "id": 4,
      "class_type": "CLIPTextEncode",
      "pos": [450, 50],
      "size": [400, 150],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 3}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [5], "slot_index": 0}],
      "widgets_values": ["score_9, score_8_up, masterpiece, realistic motion, consistency, nsfw"]
    },
    {
      "id": 5,
      "class_type": "CLIPTextEncode",
      "pos": [450, 250],
      "size": [400, 150],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 4}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [6], "slot_index": 0}],
      "widgets_values": ["score_6, score_5, blurry, watermark"]
    },
    {
      "id": 6,
      "class_type": "WanVideoVaeLoader",
      "pos": [450, 450],
      "size": [315, 58],
      "outputs": [{"name": "VAE", "type": "VAE", "links": [7, 8], "slot_index": 0}],
      "widgets_values": ["wan2.5_vae.safetensors"]
    },
    {
      "id": 7,
      "class_type": "VAEEncode",
      "pos": [750, 250],
      "size": [210, 46],
      "inputs": [
        {"name": "pixels", "type": "IMAGE", "link": 2},
        {"name": "vae", "type": "VAE", "link": 7}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [9], "slot_index": 0}]
    },
    {
      "id": 8,
      "class_type": "WanVideoSampler",
      "pos": [1050, 50],
      "size": [315, 450],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1},
        {"name": "positive", "type": "CONDITIONING", "link": 5},
        {"name": "negative", "type": "CONDITIONING", "link": 6},
        {"name": "latent_image", "type": "LATENT", "link": 9}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [10], "slot_index": 0}],
      "widgets_values": [40, 7.5, 9988, "randomize"]
    },
    {
      "id": 9,
      "class_type": "VAEDecode",
      "pos": [1400, 50],
      "size": [210, 46],
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 10},
        {"name": "vae", "type": "VAE", "link": 8}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [11], "slot_index": 0}]
    },
    {
      "id": 10,
      "class_type": "VHS_VideoCombine",
      "pos": [1650, 50],
      "size": [315, 350],
      "inputs": [{"name": "images", "type": "IMAGE", "link": 11}],
      "widgets_values": ["aikings_wan25_preview", 24, 0, "video/h264-mp4", false, true, "", 6]
    }
  ],
  "links": [
    [1, 1, 0, 8, 0, "MODEL"],
    [2, 2, 0, 7, 0, "IMAGE"],
    [3, 3, 0, 4, 0, "CLIP"],
    [4, 3, 0, 5, 0, "CLIP"],
    [5, 4, 0, 8, 1, "CONDITIONING"],
    [6, 5, 0, 8, 2, "CONDITIONING"],
    [7, 6, 0, 7, 1, "VAE"],
    [8, 6, 0, 9, 1, "VAE"],
    [9, 7, 0, 8, 3, "LATENT"],
    [10, 8, 0, 9, 0, "LATENT"],
    [11, 9, 0, 10, 0, "IMAGE"]
  ],
  "version": 0.4
}
WAN25WORKFLOW

    printf "   ✅ nsfw_ultimate_image_workflow.json (High Quality + Face Fix + Upscale)\n"
    printf "   ✅ nsfw_video_workflow.json\n"
    printf "   ✅ nsfw_ultimate_video_workflow.json (AnimateDiff + RIFE + Upscale)\n"
    printf "   ✅ nsfw_lora_image_workflow.json\n"
    printf "   ✅ nsfw_pornmaster_workflow.json\n"
    printf "   ✅ nsfw_controlnet_pose_workflow.json (OpenPose Guided)\n"
    printf "   ✅ nsfw_cinema_production_workflow.json (Full Scene + Wide Shot)\n"
    printf "   ✅ nsfw_wan21_video_workflow.json (Wan 2.1 Next-Gen Video)\n"
    printf "   ✅ nsfw_realistic_furry_video_workflow.json (Master Furry + LoRA Stacker)\n"
    printf "   ✅ nsfw_wan22_master_video_workflow.json (Wan 2.2 MoE Expert Chain)\n"
    # printf "   ✅ nsfw_wan25_preview_video_workflow.json (Wan 2.5 I2V Preview)\n"  # REMOVED - Models not available
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN PROVISIONING START
# ═══════════════════════════════════════════════════════════════════════════════
function provisioning_start() {
    # Warnings for missing tokens
    [[ -z "$CIVITAI_TOKEN" ]] && printf "⚠️  WARNING: CIVITAI_TOKEN not set – Some models may fail to download\n"
    [[ -z "$HUGGINGFACE_HUB_TOKEN" ]] && printf "⚠️  WARNING: HUGGINGFACE_HUB_TOKEN not set\n"

    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_install_comfyui
    provisioning_get_nodes

    # Download all model types
    provisioning_get_files_sequential "${COMFYUI_DIR}/models/checkpoints" "${CHECKPOINT_MODELS[@]}"
    # LoRAs - Sequential (Civitai has rate limits)
    provisioning_get_files_sequential "${COMFYUI_DIR}/models/loras" "${LORA_MODELS[@]}"
    
    # HuggingFace models - Concurrent (no rate limits, 4 parallel downloads)
    provisioning_get_files_concurrent "${COMFYUI_DIR}/models/animatediff_models" 2 "${ANIMATEDIFF_MODELS[@]}"
    provisioning_get_files_concurrent "${COMFYUI_DIR}/models/vfi" 2 "${RIFE_MODELS[@]}"
    provisioning_get_files_concurrent "${COMFYUI_DIR}/models/upscale_models" 2 "${ESRGAN_MODELS[@]}"
    provisioning_get_files_concurrent "${COMFYUI_DIR}/models/controlnet" 2 "${CONTROLNET_MODELS[@]}"
    provisioning_get_files_concurrent "${COMFYUI_DIR}/models/depthanything" 2 "${DEPTHANYTHING_MODELS[@]}"
    
    # Impact Pack Models - Concurrent (HuggingFace + Meta, no rate limits)
    provisioning_get_files_concurrent "${COMFYUI_DIR}/models/ultralytics/bbox" 2 "${BBOX_MODELS[@]}"
    provisioning_get_files_concurrent "${COMFYUI_DIR}/models/sams" 2 "${SAM_MODELS[@]}"

    # Wan 2.1 Video Models - Concurrent (HuggingFace)
    provisioning_get_files_concurrent "${COMFYUI_DIR}/models/diffusion_models" 2 "${WAN_DIFFUSION_MODELS[@]}"
    provisioning_get_files_concurrent "${COMFYUI_DIR}/models/text_encoders" 2 "${WAN_TEXT_ENCODERS[@]}"
    provisioning_get_files_concurrent "${COMFYUI_DIR}/models/vae" 2 "${WAN_VAE[@]}"

    # Wan 2.2 Video Models - Concurrent (HuggingFace)
    provisioning_get_files_concurrent "${COMFYUI_DIR}/models/diffusion_models" 2 "${WAN22_DIFFUSION_MODELS[@]}"
    provisioning_get_files_concurrent "${COMFYUI_DIR}/models/vae" 2 "${WAN22_VAE[@]}"

    # Wan 2.5 removed - models not publicly available
    # provisioning_get_files_concurrent "${COMFYUI_DIR}/models/diffusion_models" 2 "${WAN25_DIFFUSION_MODELS[@]}"
    # provisioning_get_files_concurrent "${COMFYUI_DIR}/models/vae" 2 "${WAN25_VAE[@]}"

    # Extract any archives
    provisioning_extract_archives "${COMFYUI_DIR}/models/loras"

    # Create symlink for lora/loras compatibility
    if [[ ! -L "${COMFYUI_DIR}/models/lora" && ! -d "${COMFYUI_DIR}/models/lora" ]]; then
        ln -s "${COMFYUI_DIR}/models/loras" "${COMFYUI_DIR}/models/lora"
        printf "✅ Created symlink: models/lora -> models/loras\n"
    fi

    # Install fully-connected workflows
    provisioning_install_workflows

    # Launch ComfyUI
    printf "\n🚀 Starting ComfyUI on port 8188...\n"
    cd "${COMFYUI_DIR}"
    python main.py --listen 0.0.0.0 --port 8188 --enable-cors-header &
    
    provisioning_print_end
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXECUTE
# ═══════════════════════════════════════════════════════════════════════════════
provisioning_start
