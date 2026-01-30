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
)

# ═══════════════════════════════════════════════════════════════════════════════
# PYTHON PACKAGES (Critical for Impact Pack, VHS, and core functions)
# ═══════════════════════════════════════════════════════════════════════════════
PIP_PACKAGES=(
    "sqlalchemy"
    "alembic"
    "opencv-python-headless"
    "insightface"
    "lpips"
    "GitPython"
    "matplotlib"
    "screeninfo"
    "scipy"
    "onnxruntime-gpu"
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
)

# ═══════════════════════════════════════════════════════════════════════════════
# CHECKPOINTS (Pony XL + Pornmaster XL)
# Format: "url|filename.safetensors"
# ═══════════════════════════════════════════════════════════════════════════════
CHECKPOINT_MODELS=(
    "https://civitai.com/api/download/models/290640|ponyDiffusionV6XL.safetensors"
    "https://civitai.com/api/download/models/175234|pornmaster_v1.5.safetensors"
    "https://civitai.com/api/download/models/128713|dreamshaper_8.safetensors"
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
    "https://huggingface.co/guoyww/animatediff/resolve/main/mm_sdxl_v1_beta.ckpt|mm_sdxl_v1_beta.ckpt"
    "https://huggingface.co/guoyww/animatediff/resolve/main/mm_sd_v15_v2.ckpt|mm_sd_v15_v2.ckpt"
)

# ═══════════════════════════════════════════════════════════════════════════════
# RIFE FRAME INTERPOLATION MODELS
# ═══════════════════════════════════════════════════════════════════════════════
RIFE_MODELS=(
    "https://github.com/hzwer/Practical-RIFE/releases/download/v4.7/rife47.pth|rife47.pth"
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
    "https://huggingface.co/Kijai/depth-anything-2-safetensors/resolve/main/depth_anything_v2_vitl.safetensors|depth_anything_v2_vitl.safetensors"
)

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

function provisioning_get_pip_packages() {
    if [[ ${#PIP_PACKAGES[@]} -gt 0 ]]; then
        printf "🐍 Installing Python packages...\n"
        pip install --no-cache-dir "${PIP_PACKAGES[@]}" --quiet
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
    cat > "${workflows_dir}/nsfw_image_workflow.json" << 'IMGWORKFLOW'
{
  "last_node_id": 7,
  "last_link_id": 7,
  "nodes": [
    {
      "id": 1,
      "type": "CheckpointLoaderSimple",
      "pos": [50, 100],
      "size": [315, 98],
      "flags": {},
      "order": 0,
      "mode": 0,
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [2, 3], "slot_index": 1},
        {"name": "VAE", "type": "VAE", "links": [6], "slot_index": 2}
      ],
      "properties": {"Node name for S&R": "CheckpointLoaderSimple"},
      "widgets_values": ["ponyDiffusionV6XL.safetensors"]
    },
    {
      "id": 2,
      "type": "CLIPTextEncode",
      "pos": [450, 50],
      "size": [400, 100],
      "flags": {},
      "order": 1,
      "mode": 0,
      "inputs": [
        {"name": "clip", "type": "CLIP", "link": 2}
      ],
      "outputs": [
        {"name": "CONDITIONING", "type": "CONDITIONING", "links": [4], "slot_index": 0}
      ],
      "properties": {"Node name for S&R": "CLIPTextEncode"},
      "widgets_values": ["score_9, score_8_up, score_7_up, 1girl, beautiful face, detailed eyes, high quality, nsfw, masterpiece"]
    },
    {
      "id": 3,
      "type": "CLIPTextEncode",
      "pos": [450, 200],
      "size": [400, 100],
      "flags": {},
      "order": 2,
      "mode": 0,
      "inputs": [
        {"name": "clip", "type": "CLIP", "link": 3}
      ],
      "outputs": [
        {"name": "CONDITIONING", "type": "CONDITIONING", "links": [5], "slot_index": 0}
      ],
      "properties": {"Node name for S&R": "CLIPTextEncode"},
      "widgets_values": ["score_6, score_5, score_4, low quality, blurry, censored, watermark, ugly"]
    },
    {
      "id": 4,
      "type": "EmptyLatentImage",
      "pos": [450, 350],
      "size": [315, 106],
      "flags": {},
      "order": 3,
      "mode": 0,
      "outputs": [
        {"name": "LATENT", "type": "LATENT", "links": [7], "slot_index": 0}
      ],
      "properties": {"Node name for S&R": "EmptyLatentImage"},
      "widgets_values": [1024, 1024, 1]
    },
    {
      "id": 5,
      "type": "KSampler",
      "pos": [900, 100],
      "size": [315, 262],
      "flags": {},
      "order": 4,
      "mode": 0,
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1},
        {"name": "positive", "type": "CONDITIONING", "link": 4},
        {"name": "negative", "type": "CONDITIONING", "link": 5},
        {"name": "latent_image", "type": "LATENT", "link": 7}
      ],
      "outputs": [
        {"name": "LATENT", "type": "LATENT", "links": [8], "slot_index": 0}
      ],
      "properties": {"Node name for S&R": "KSampler"},
      "widgets_values": [123456789, "randomize", 25, 7, "dpmpp_2m", "karras", 1]
    },
    {
      "id": 6,
      "type": "VAEDecode",
      "pos": [1250, 100],
      "size": [210, 46],
      "flags": {},
      "order": 5,
      "mode": 0,
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 8},
        {"name": "vae", "type": "VAE", "link": 6}
      ],
      "outputs": [
        {"name": "IMAGE", "type": "IMAGE", "links": [9], "slot_index": 0}
      ],
      "properties": {"Node name for S&R": "VAEDecode"}
    },
    {
      "id": 7,
      "type": "SaveImage",
      "pos": [1500, 100],
      "size": [315, 270],
      "flags": {},
      "order": 6,
      "mode": 0,
      "inputs": [
        {"name": "images", "type": "IMAGE", "link": 9}
      ],
      "properties": {"Node name for S&R": "SaveImage"},
      "widgets_values": ["aikings_nsfw"]
    }
  ],
  "links": [
    [1, 1, 0, 5, 0, "MODEL"],
    [2, 1, 1, 2, 0, "CLIP"],
    [3, 1, 1, 3, 0, "CLIP"],
    [4, 2, 0, 5, 1, "CONDITIONING"],
    [5, 3, 0, 5, 2, "CONDITIONING"],
    [6, 1, 2, 6, 1, "VAE"],
    [7, 4, 0, 5, 3, "LATENT"],
    [8, 5, 0, 6, 0, "LATENT"],
    [9, 6, 0, 7, 0, "IMAGE"]
  ],
  "groups": [],
  "config": {},
  "extra": {},
  "version": 0.4
}
IMGWORKFLOW

    # ═══════════════════════════════════════════════════════════════════════
    # NSFW VIDEO WORKFLOW (AnimateDiff SDXL - Fully Connected)
    # Uses: ADE_AnimateDiffLoaderGen1 + VHS_VideoCombine
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_video_workflow.json" << 'VIDWORKFLOW'
{
  "last_node_id": 9,
  "last_link_id": 11,
  "nodes": [
    {
      "id": 1,
      "type": "CheckpointLoaderSimple",
      "pos": [50, 100],
      "size": [315, 98],
      "flags": {},
      "order": 0,
      "mode": 0,
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [2, 3], "slot_index": 1},
        {"name": "VAE", "type": "VAE", "links": [9], "slot_index": 2}
      ],
      "properties": {"Node name for S&R": "CheckpointLoaderSimple"},
      "widgets_values": ["ponyDiffusionV6XL.safetensors"]
    },
    {
      "id": 2,
      "type": "ADE_AnimateDiffLoaderGen1",
      "pos": [50, 300],
      "size": [315, 98],
      "flags": {},
      "order": 1,
      "mode": 0,
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1}
      ],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [4], "slot_index": 0}
      ],
      "properties": {"Node name for S&R": "ADE_AnimateDiffLoaderGen1"},
      "widgets_values": ["mm_sdxl_v1_beta.ckpt", "sqrt_linear (AnimateDiff)"]
    },
    {
      "id": 3,
      "type": "CLIPTextEncode",
      "pos": [450, 50],
      "size": [400, 100],
      "flags": {},
      "order": 2,
      "mode": 0,
      "inputs": [
        {"name": "clip", "type": "CLIP", "link": 2}
      ],
      "outputs": [
        {"name": "CONDITIONING", "type": "CONDITIONING", "links": [5], "slot_index": 0}
      ],
      "properties": {"Node name for S&R": "CLIPTextEncode"},
      "widgets_values": ["score_9, score_8_up, score_7_up, 1girl, dancing, dynamic motion, beautiful face, high quality, nsfw, masterpiece"]
    },
    {
      "id": 4,
      "type": "CLIPTextEncode",
      "pos": [450, 200],
      "size": [400, 100],
      "flags": {},
      "order": 3,
      "mode": 0,
      "inputs": [
        {"name": "clip", "type": "CLIP", "link": 3}
      ],
      "outputs": [
        {"name": "CONDITIONING", "type": "CONDITIONING", "links": [6], "slot_index": 0}
      ],
      "properties": {"Node name for S&R": "CLIPTextEncode"},
      "widgets_values": ["score_6, score_5, score_4, static, frozen, low quality, blurry, censored, watermark"]
    },
    {
      "id": 5,
      "type": "EmptyLatentImage",
      "pos": [450, 350],
      "size": [315, 106],
      "flags": {},
      "order": 4,
      "mode": 0,
      "outputs": [
        {"name": "LATENT", "type": "LATENT", "links": [7], "slot_index": 0}
      ],
      "properties": {"Node name for S&R": "EmptyLatentImage"},
      "widgets_values": [512, 512, 16]
    },
    {
      "id": 6,
      "type": "KSampler",
      "pos": [900, 100],
      "size": [315, 262],
      "flags": {},
      "order": 5,
      "mode": 0,
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 4},
        {"name": "positive", "type": "CONDITIONING", "link": 5},
        {"name": "negative", "type": "CONDITIONING", "link": 6},
        {"name": "latent_image", "type": "LATENT", "link": 7}
      ],
      "outputs": [
        {"name": "LATENT", "type": "LATENT", "links": [8], "slot_index": 0}
      ],
      "properties": {"Node name for S&R": "KSampler"},
      "widgets_values": [987654321, "randomize", 20, 7, "euler", "normal", 1]
    },
    {
      "id": 7,
      "type": "VAEDecode",
      "pos": [1250, 100],
      "size": [210, 46],
      "flags": {},
      "order": 6,
      "mode": 0,
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 8},
        {"name": "vae", "type": "VAE", "link": 9}
      ],
      "outputs": [
        {"name": "IMAGE", "type": "IMAGE", "links": [10], "slot_index": 0}
      ],
      "properties": {"Node name for S&R": "VAEDecode"}
    },
    {
      "id": 8,
      "type": "VHS_VideoCombine",
      "pos": [1500, 100],
      "size": [315, 290],
      "flags": {},
      "order": 7,
      "mode": 0,
      "inputs": [
        {"name": "images", "type": "IMAGE", "link": 10}
      ],
      "properties": {"Node name for S&R": "VHS_VideoCombine"},
      "widgets_values": ["aikings_video", 8, 0, "image/webp", false, true, ""]
    }
  ],
  "links": [
    [1, 1, 0, 2, 0, "MODEL"],
    [2, 1, 1, 3, 0, "CLIP"],
    [3, 1, 1, 4, 0, "CLIP"],
    [4, 2, 0, 6, 0, "MODEL"],
    [5, 3, 0, 6, 1, "CONDITIONING"],
    [6, 4, 0, 6, 2, "CONDITIONING"],
    [7, 5, 0, 6, 3, "LATENT"],
    [8, 6, 0, 7, 0, "LATENT"],
    [9, 1, 2, 7, 1, "VAE"],
    [10, 7, 0, 8, 0, "IMAGE"]
  ],
  "groups": [],
  "config": {},
  "extra": {},
  "version": 0.4
}
VIDWORKFLOW

    # ═══════════════════════════════════════════════════════════════════════
    # EXTENDED VIDEO WORKFLOW (With RIFE Interpolation - 8-12 Seconds)
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_video_extended_workflow.json" << 'EXTVIDWORKFLOW'
{
  "last_node_id": 10,
  "last_link_id": 13,
  "nodes": [
    {
      "id": 1,
      "type": "CheckpointLoaderSimple",
      "pos": [50, 100],
      "size": [315, 98],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [2, 3], "slot_index": 1},
        {"name": "VAE", "type": "VAE", "links": [9], "slot_index": 2}
      ],
      "widgets_values": ["dreamshaper_8.safetensors"]
    },
    {
      "id": 2,
      "type": "ADE_AnimateDiffLoaderGen1",
      "pos": [50, 300],
      "size": [315, 98],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1}
      ],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [4], "slot_index": 0}
      ],
      "widgets_values": ["mm_sd_v15_v2.ckpt", "sqrt_linear (AnimateDiff)"]
    },
    {
      "id": 3,
      "type": "CLIPTextEncode",
      "pos": [450, 50],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 2}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [5], "slot_index": 0}],
      "widgets_values": ["beautiful woman dancing, smooth motion, cinematic lighting, high quality, masterpiece"]
    },
    {
      "id": 4,
      "type": "CLIPTextEncode",
      "pos": [450, 200],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 3}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [6], "slot_index": 0}],
      "widgets_values": ["static, frozen, choppy, low quality, blurry, watermark"]
    },
    {
      "id": 5,
      "type": "EmptyLatentImage",
      "pos": [450, 350],
      "size": [315, 106],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [7], "slot_index": 0}],
      "widgets_values": [512, 512, 32]
    },
    {
      "id": 6,
      "type": "KSampler",
      "pos": [900, 100],
      "size": [315, 262],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 4},
        {"name": "positive", "type": "CONDITIONING", "link": 5},
        {"name": "negative", "type": "CONDITIONING", "link": 6},
        {"name": "latent_image", "type": "LATENT", "link": 7}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [8], "slot_index": 0}],
      "widgets_values": [555555, "randomize", 25, 7, "euler", "normal", 1]
    },
    {
      "id": 7,
      "type": "VAEDecode",
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
      "type": "RIFE VFI",
      "pos": [1500, 100],
      "size": [315, 150],
      "inputs": [{"name": "frames", "type": "IMAGE", "link": 10}],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "links": [12], "slot_index": 0}],
      "widgets_values": ["rife47.pth", 10, 2, true, false, 1.0]
    },
    {
      "id": 10,
      "type": "VHS_VideoCombine",
      "pos": [1850, 100],
      "size": [315, 290],
      "inputs": [{"name": "images", "type": "IMAGE", "link": 12}],
      "widgets_values": ["aikings_extended_video", 16, 0, "video/h264-mp4", false, true, ""]
    }
  ],
  "links": [
    [1, 1, 0, 2, 0, "MODEL"],
    [2, 1, 1, 3, 0, "CLIP"],
    [3, 1, 1, 4, 0, "CLIP"],
    [4, 2, 0, 6, 0, "MODEL"],
    [5, 3, 0, 6, 1, "CONDITIONING"],
    [6, 4, 0, 6, 2, "CONDITIONING"],
    [7, 5, 0, 6, 3, "LATENT"],
    [8, 6, 0, 7, 0, "LATENT"],
    [9, 1, 2, 7, 1, "VAE"],
    [10, 7, 0, 9, 0, "IMAGE"],
    [12, 9, 0, 10, 0, "IMAGE"]
  ],
  "version": 0.4
}
EXTVIDWORKFLOW

    # ═══════════════════════════════════════════════════════════════════════
    # LORA-FOCUSED IMAGE WORKFLOW (With LoRA Loader - Fully Connected)
    # For using the specialized fetish LoRAs
    # ═══════════════════════════════════════════════════════════════════════
    cat > "${workflows_dir}/nsfw_lora_image_workflow.json" << 'LORAWORKFLOW'
{
  "last_node_id": 9,
  "last_link_id": 12,
  "nodes": [
    {
      "id": 1,
      "type": "CheckpointLoaderSimple",
      "pos": [50, 100],
      "size": [315, 98],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [2], "slot_index": 1},
        {"name": "VAE", "type": "VAE", "links": [10], "slot_index": 2}
      ],
      "widgets_values": ["ponyDiffusionV6XL.safetensors"]
    },
    {
      "id": 2,
      "type": "LoraLoader",
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
      "type": "CLIPTextEncode",
      "pos": [750, 50],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 4}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [6], "slot_index": 0}],
      "widgets_values": ["score_9, score_8_up, score_7_up, 1girl, detailed face, beautiful eyes, high quality, nsfw, masterpiece, photorealistic"]
    },
    {
      "id": 4,
      "type": "CLIPTextEncode",
      "pos": [750, 200],
      "size": [400, 100],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 5}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [7], "slot_index": 0}],
      "widgets_values": ["score_6, score_5, score_4, low quality, blurry, censored, watermark, ugly, cartoon, anime"]
    },
    {
      "id": 5,
      "type": "EmptyLatentImage",
      "pos": [750, 350],
      "size": [315, 106],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [8], "slot_index": 0}],
      "widgets_values": [1024, 1024, 1]
    },
    {
      "id": 6,
      "type": "KSampler",
      "pos": [1200, 100],
      "size": [315, 262],
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 3},
        {"name": "positive", "type": "CONDITIONING", "link": 6},
        {"name": "negative", "type": "CONDITIONING", "link": 7},
        {"name": "latent_image", "type": "LATENT", "link": 8}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [9], "slot_index": 0}],
      "widgets_values": [111222333, "randomize", 28, 7.5, "dpmpp_2m", "karras", 1]
    },
    {
      "id": 7,
      "type": "VAEDecode",
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
      "type": "SaveImage",
      "pos": [1800, 100],
      "size": [315, 270],
      "inputs": [{"name": "images", "type": "IMAGE", "link": 11}],
      "widgets_values": ["aikings_lora_nsfw"]
    }
  ],
  "links": [
    [1, 1, 0, 2, 0, "MODEL"],
    [2, 1, 1, 2, 1, "CLIP"],
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
  "last_node_id": 7,
  "last_link_id": 9,
  "nodes": [
    {
      "id": 1,
      "type": "CheckpointLoaderSimple",
      "pos": [50, 100],
      "size": [315, 98],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0},
        {"name": "CLIP", "type": "CLIP", "links": [2, 3], "slot_index": 1},
        {"name": "VAE", "type": "VAE", "links": [6], "slot_index": 2}
      ],
      "widgets_values": ["pornmaster_v1.5.safetensors"]
    },
    {
      "id": 2,
      "type": "CLIPTextEncode",
      "pos": [450, 50],
      "size": [450, 120],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 2}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [4], "slot_index": 0}],
      "widgets_values": ["photorealistic, professional photography, beautiful woman, detailed skin texture, natural lighting, high resolution, sharp focus, 8k uhd, dslr quality, nsfw"]
    },
    {
      "id": 3,
      "type": "CLIPTextEncode",
      "pos": [450, 220],
      "size": [450, 120],
      "inputs": [{"name": "clip", "type": "CLIP", "link": 3}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "links": [5], "slot_index": 0}],
      "widgets_values": ["cartoon, anime, illustration, 3d render, fake, plastic, low quality, blurry, censored, watermark, text, ugly, deformed"]
    },
    {
      "id": 4,
      "type": "EmptyLatentImage",
      "pos": [450, 400],
      "size": [315, 106],
      "outputs": [{"name": "LATENT", "type": "LATENT", "links": [7], "slot_index": 0}],
      "widgets_values": [832, 1216, 1]
    },
    {
      "id": 5,
      "type": "KSampler",
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
      "type": "VAEDecode",
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
      "type": "SaveImage",
      "pos": [1550, 100],
      "size": [315, 270],
      "inputs": [{"name": "images", "type": "IMAGE", "link": 9}],
      "widgets_values": ["aikings_pornmaster"]
    }
  ],
  "links": [
    [1, 1, 0, 5, 0, "MODEL"],
    [2, 1, 1, 2, 0, "CLIP"],
    [3, 1, 1, 3, 0, "CLIP"],
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

    printf "   ✅ nsfw_image_workflow.json\n"
    printf "   ✅ nsfw_video_workflow.json\n"
    printf "   ✅ nsfw_video_extended_workflow.json\n"
    printf "   ✅ nsfw_lora_image_workflow.json\n"
    printf "   ✅ nsfw_pornmaster_workflow.json\n"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN PROVISIONING START
# ═══════════════════════════════════════════════════════════════════════════════
function provisioning_start() {
    # Cleanup any existing processes
    printf "🧹 Searching for existing ComfyUI processes...\n"
    ps aux | grep -E 'python|main.py' | grep -v grep | awk '{print $2}' | xargs -r kill -9

    # Warnings for missing tokens
    [[ -z "$CIVITAI_TOKEN" ]] && printf "⚠️  WARNING: CIVITAI_TOKEN not set – Some models may fail to download\n"
    [[ -z "$HUGGINGFACE_HUB_TOKEN" ]] && printf "⚠️  WARNING: HUGGINGFACE_HUB_TOKEN not set\n"

    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_pip_packages
    provisioning_install_comfyui
    provisioning_get_nodes

    # Download all model types
    provisioning_get_files_sequential "${COMFYUI_DIR}/models/checkpoints" "${CHECKPOINT_MODELS[@]}"
    provisioning_get_files_sequential "${COMFYUI_DIR}/models/loras" "${LORA_MODELS[@]}"
    provisioning_get_files_sequential "${COMFYUI_DIR}/models/animatediff_models" "${ANIMATEDIFF_MODELS[@]}"
    provisioning_get_files_sequential "${COMFYUI_DIR}/models/vfi" "${RIFE_MODELS[@]}"
    provisioning_get_files_sequential "${COMFYUI_DIR}/models/upscale_models" "${ESRGAN_MODELS[@]}"
    provisioning_get_files_sequential "${COMFYUI_DIR}/models/controlnet" "${CONTROLNET_MODELS[@]}"
    provisioning_get_files_sequential "${COMFYUI_DIR}/models/depthanything" "${DEPTHANYTHING_MODELS[@]}"

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