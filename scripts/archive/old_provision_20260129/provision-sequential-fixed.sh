#!/bin/bash
# AI Kings NSFW ComfyUI Provisioning - SEQUENTIAL (RELIABLE)
# Fixed version: Downloads one-by-one to prevent failures and timeouts

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI

# System packages
APT_PACKAGES=(
    "unrar"
)

# Python packages (none needed - covered by node requirements)
PIP_PACKAGES=()

# Custom nodes
NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
    "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation"
)

# Pony Diffusion V6 XL + Pornmaster v1.5 for NSFW content
CHECKPOINT_MODELS=(
    "https://civitai.com/api/download/models/290640?type=Model&format=SafeTensor&size=full&fp=fp16"
    "https://civitai.com/api/download/models/139562?type=Model&format=SafeTensor"
)

UNET_MODELS=()

# NSFW/Fetish LoRAs
LORA_MODELS=(
    "https://files.catbox.moe/f6r1nl.safetensors"
    "https://files.catbox.moe/pk6hl3.safetensors"
    "https://files.catbox.moe/wmshk3.safetensors"
    "https://files.catbox.moe/9qixqa.safetensors"
    "https://files.catbox.moe/yz5c9g.safetensors"
    "https://files.catbox.moe/tlt57h.safetensors"
    "https://files.catbox.moe/odmswn.safetensors"
    "https://files.catbox.moe/z71ic0.safetensors"
    "https://files.catbox.moe/mxbbg2.safetensors"
)

VAE_MODELS=()
ESRGAN_MODELS=()
CONTROLNET_MODELS=()

# AnimateDiff motion model for video generation
ANIMATEDIFF_MODELS=(
    "https://huggingface.co/guoyww/animatediff/resolve/main/mm_sd_v15_v2.ckpt"
)

# RIFE frame interpolation model
RIFE_MODELS=(
    "https://github.com/hzwer/Practical-RIFE/releases/download/v4.7/rife47.pth"
)

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages
    
    # Sequential downloads - one at a time for reliability
    provisioning_get_files_sequential \
        "${COMFYUI_DIR}/models/checkpoints" \
        "${CHECKPOINT_MODELS[@]}"
    
    provisioning_get_files_sequential \
        "${COMFYUI_DIR}/models/unet" \
        "${UNET_MODELS[@]}"
    
    provisioning_get_files_sequential \
        "${COMFYUI_DIR}/models/lora" \
        "${LORA_MODELS[@]}"
    
    provisioning_get_files_sequential \
        "${COMFYUI_DIR}/models/controlnet" \
        "${CONTROLNET_MODELS[@]}"
    
    provisioning_get_files_sequential \
        "${COMFYUI_DIR}/models/vae" \
        "${VAE_MODELS[@]}"
    
    provisioning_get_files_sequential \
        "${COMFYUI_DIR}/models/esrgan" \
        "${ESRGAN_MODELS[@]}"
    
    provisioning_get_files_sequential \
        "${COMFYUI_DIR}/models/animatediff_models" \
        "${ANIMATEDIFF_MODELS[@]}"
    
    provisioning_get_files_sequential \
        "${COMFYUI_DIR}/models/rife" \
        "${RIFE_MODELS[@]}"
    
    provisioning_extract_archives "${COMFYUI_DIR}/models/lora"
    provisioning_install_workflows
    provisioning_print_end
}

function provisioning_get_apt_packages() {
    if [[ -n "${APT_PACKAGES[*]}" ]]; then
        sudo apt-get update
        sudo apt-get install -y "${APT_PACKAGES[@]}"
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n "${PIP_PACKAGES[*]}" ]]; then
        pip install --no-cache-dir "${PIP_PACKAGES[@]}"
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="${COMFYUI_DIR}/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        
        if [[ -d "$path" ]]; then
            if [[ "${AUTO_UPDATE,,}" != "false" ]]; then
                printf "Updating node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
                if [[ -e "$requirements" ]]; then
                    pip install --no-cache-dir -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e "$requirements" ]]; then
                pip install --no-cache-dir -r "$requirements"
            fi
        fi
    done
}

# SEQUENTIAL download function - downloads one file at a time
function provisioning_get_files_sequential() {
    if [[ -z "$2" ]]; then return 0; fi
    
    local dir="$1"
    mkdir -p "$dir"
    shift
    local arr=("$@")
    
    if [[ ${#arr[@]} -eq 0 ]]; then
        return 0
    fi
    
    printf "\n=== Downloading %s model(s) to %s (SEQUENTIAL) ===\n" "${#arr[@]}" "$dir"
    
    local count=0
    for url in "${arr[@]}"; do
        count=$((count + 1))
        printf "\n[%d/%d] Downloading: %s\n" "$count" "${#arr[@]}" "${url}"
        
        # Retry logic: try up to 3 times per file
        local retry=0
        local max_retries=3
        while [[ $retry -lt $max_retries ]]; do
            if provisioning_download "${url}" "${dir}"; then
                printf "✓ Download complete\n"
                break
            else
                retry=$((retry + 1))
                if [[ $retry -lt $max_retries ]]; then
                    printf "⚠ Download failed, retrying (%d/%d)...\n" "$retry" "$max_retries"
                    sleep 5
                else
                    printf "✗ Download failed after %d attempts\n" "$max_retries"
                fi
            fi
        done
    done
    printf "\n"
}

function provisioning_download() {
    local url="$1"
    local dir="$2"
    local auth_token=""
    
    # Detect auth token based on URL
    if [[ -n "$HUGGINGFACE_HUB_TOKEN" && "$url" =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co ]]; then
        auth_token="$HUGGINGFACE_HUB_TOKEN"
    elif [[ -n "$CIVITAI_TOKEN" && "$url" =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi
  # Civitai requires token as a query parameter; append it and avoid bearer header
  local download_url="$url"
  if [[ -n "$CIVITAI_TOKEN" && "$url" =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com ]]; then
    if [[ "$url" == *"?"* ]]; then
      download_url="${url}&token=${CIVITAI_TOKEN}"
    else
      download_url="${url}?token=${CIVITAI_TOKEN}"
    fi
    # Clear auth_token so we don't send a bearer header for civitai
    auth_token=""
  fi

  # Download with or without auth header (Hugging Face uses Bearer header)
  if [[ -n "$auth_token" ]]; then
    wget --header="Authorization: Bearer $auth_token" \
      -qnc --content-disposition --show-progress \
      -e dotbytes=4M --timeout=60 --tries=3 \
      -P "$dir" "$download_url"
  else
    wget -qnc --content-disposition --show-progress \
      -e dotbytes=4M --timeout=60 --tries=3 \
      -P "$dir" "$download_url"
  fi
    
    return $?
}

function provisioning_extract_archives() {
    local dir="$1"
    printf "Extracting archives in %s...\n" "$dir"
    
    for file in "$dir"/*.rar; do
        if [[ -f "$file" ]]; then
            printf "Extracting RAR: %s\n" "$file"
            unrar x -o- "$file" "$dir/" && rm "$file"
        fi
    done
}

function provisioning_install_workflows() {
    local workflows_dir="${COMFYUI_DIR}/user/default/workflows"
    mkdir -p "$workflows_dir"
    
    # NSFW Image Workflow (Pony V6 XL)
    cat > "${workflows_dir}/nsfw_image_workflow.json" << 'EOF'
{
  "last_node_id": 7,
  "last_link_id": 7,
  "nodes": [
    {
      "id": 1,
      "type": "CheckpointLoaderSimple",
      "pos": [50, 50],
      "size": [315, 98],
      "flags": {},
      "order": 0,
      "mode": 0,
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1]},
        {"name": "CLIP", "type": "CLIP", "links": [2, 3]},
        {"name": "VAE", "type": "VAE", "links": [6]}
      ],
      "properties": {},
      "widgets_values": ["ponyDiffusionV6XL_v6StartWithThisOne.safetensors"]
    },
    {
      "id": 2,
      "type": "CLIPTextEncode",
      "pos": [400, 50],
      "size": [400, 200],
      "flags": {},
      "order": 1,
      "mode": 0,
      "inputs": [
        {"name": "clip", "type": "CLIP", "link": 2}
      ],
      "outputs": [
        {"name": "CONDITIONING", "type": "CONDITIONING", "links": [4]}
      ],
      "properties": {},
      "widgets_values": ["score_9, score_8_up, score_7_up, 1girl, detailed face, high quality, nsfw, fetish content, beautiful lighting"]
    },
    {
      "id": 3,
      "type": "CLIPTextEncode",
      "pos": [400, 300],
      "size": [400, 200],
      "flags": {},
      "order": 2,
      "mode": 0,
      "inputs": [
        {"name": "clip", "type": "CLIP", "link": 3}
      ],
      "outputs": [
        {"name": "CONDITIONING", "type": "CONDITIONING", "links": [5]}
      ],
      "properties": {},
      "widgets_values": ["score_4, score_5, score_6, low quality, blurry, censored, watermark"]
    },
    {
      "id": 7,
      "type": "EmptyLatentImage",
      "pos": [50, 200],
      "size": [315, 106],
      "flags": {},
      "order": 3,
      "mode": 0,
      "outputs": [
        {"name": "LATENT", "type": "LATENT", "links": [7]}
      ],
      "properties": {},
      "widgets_values": [1024, 1024, 1]
    },
    {
      "id": 4,
      "type": "KSampler",
      "pos": [850, 50],
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
        {"name": "LATENT", "type": "LATENT", "links": [8]}
      ],
      "properties": {},
      "widgets_values": [123456, "randomize", 20, 7, "euler", "normal", 1]
    },
    {
      "id": 5,
      "type": "VAEDecode",
      "pos": [1200, 50],
      "size": [210, 46],
      "flags": {},
      "order": 5,
      "mode": 0,
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 8},
        {"name": "vae", "type": "VAE", "link": 6}
      ],
      "outputs": [
        {"name": "IMAGE", "type": "IMAGE", "links": [9]}
      ],
      "properties": {}
    },
    {
      "id": 6,
      "type": "SaveImage",
      "pos": [1450, 50],
      "size": [315, 270],
      "flags": {},
      "order": 6,
      "mode": 0,
      "inputs": [
        {"name": "images", "type": "IMAGE", "link": 9}
      ],
      "properties": {},
      "widgets_values": ["nsfw_image"]
    }
  ],
  "links": [
    [1, 1, 0, 4, 0, "MODEL"],
    [2, 1, 1, 2, 0, "CLIP"],
    [3, 1, 1, 3, 0, "CLIP"],
    [4, 2, 0, 4, 1, "CONDITIONING"],
    [5, 3, 0, 4, 2, "CONDITIONING"],
    [6, 1, 2, 5, 1, "VAE"],
    [7, 7, 0, 4, 3, "LATENT"],
    [8, 4, 0, 5, 0, "LATENT"],
    [9, 5, 0, 6, 0, "IMAGE"]
  ],
  "groups": [],
  "config": {},
  "extra": {},
  "version": 0.4
}
EOF

    # NSFW Video Workflow (AnimateDiff)
    cat > "${workflows_dir}/nsfw_video_workflow.json" << 'EOF'
{
  "last_node_id": 9,
  "last_link_id": 12,
  "nodes": [
    {
      "id": 1,
      "type": "CheckpointLoaderSimple",
      "pos": [50, 50],
      "size": [315, 98],
      "flags": {},
      "order": 0,
      "mode": 0,
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [1]},
        {"name": "CLIP", "type": "CLIP", "links": [2, 3]},
        {"name": "VAE", "type": "VAE", "links": [10]}
      ],
      "properties": {},
      "widgets_values": ["ponyDiffusionV6XL_v6StartWithThisOne.safetensors"]
    },
    {
      "id": 2,
      "type": "CLIPTextEncode",
      "pos": [400, 50],
      "size": [400, 200],
      "flags": {},
      "order": 1,
      "mode": 0,
      "inputs": [
        {"name": "clip", "type": "CLIP", "link": 2}
      ],
      "outputs": [
        {"name": "CONDITIONING", "type": "CONDITIONING", "links": [6]}
      ],
      "properties": {},
      "widgets_values": ["score_9, score_8_up, 1girl, detailed face, dynamic pose, nsfw, fetish content, smooth animation"]
    },
    {
      "id": 3,
      "type": "CLIPTextEncode",
      "pos": [400, 300],
      "size": [400, 200],
      "flags": {},
      "order": 2,
      "mode": 0,
      "inputs": [
        {"name": "clip", "type": "CLIP", "link": 3}
      ],
      "outputs": [
        {"name": "CONDITIONING", "type": "CONDITIONING", "links": [7]}
      ],
      "properties": {},
      "widgets_values": ["score_4, score_5, low quality, blurry, censored, static, frozen"]
    },
    {
      "id": 4,
      "type": "ADE_AnimateDiffLoaderGen1",
      "pos": [50, 400],
      "size": [315, 78],
      "flags": {},
      "order": 3,
      "mode": 0,
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1}
      ],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [4]}
      ],
      "properties": {},
      "widgets_values": ["mm_sd_v15_v2.ckpt", "sqrt_linear (AnimateDiff)"]
    },
    {
      "id": 8,
      "type": "EmptyLatentImage",
      "pos": [50, 550],
      "size": [315, 106],
      "flags": {},
      "order": 4,
      "mode": 0,
      "outputs": [
        {"name": "LATENT", "type": "LATENT", "links": [11]}
      ],
      "properties": {},
      "widgets_values": [512, 512, 16]
    },
    {
      "id": 5,
      "type": "KSampler",
      "pos": [850, 50],
      "size": [315, 262],
      "flags": {},
      "order": 5,
      "mode": 0,
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 4},
        {"name": "positive", "type": "CONDITIONING", "link": 6},
        {"name": "negative", "type": "CONDITIONING", "link": 7},
        {"name": "latent_image", "type": "LATENT", "link": 11}
      ],
      "outputs": [
        {"name": "LATENT", "type": "LATENT", "links": [8]}
      ],
      "properties": {},
      "widgets_values": [123456, "randomize", 20, 7, "euler", "normal", 1]
    },
    {
      "id": 6,
      "type": "VAEDecode",
      "pos": [1200, 50],
      "size": [210, 46],
      "flags": {},
      "order": 6,
      "mode": 0,
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 8},
        {"name": "vae", "type": "VAE", "link": 10}
      ],
      "outputs": [
        {"name": "IMAGE", "type": "IMAGE", "links": [9]}
      ],
      "properties": {}
    },
    {
      "id": 7,
      "type": "VHS_VideoCombine",
      "pos": [1450, 50],
      "size": [315, 290],
      "flags": {},
      "order": 7,
      "mode": 0,
      "inputs": [
        {"name": "images", "type": "IMAGE", "link": 9}
      ],
      "properties": {},
      "widgets_values": {
        "frame_rate": 8,
        "loop_count": 0,
        "filename_prefix": "nsfw_video",
        "format": "video/h264-mp4",
        "pix_fmt": "yuv420p",
        "crf": 20,
        "save_metadata": true
      }
    }
  ],
  "links": [
    [1, 1, 0, 4, 0, "MODEL"],
    [2, 1, 1, 2, 0, "CLIP"],
    [3, 1, 1, 3, 0, "CLIP"],
    [4, 4, 0, 5, 0, "MODEL"],
    [6, 2, 0, 5, 1, "CONDITIONING"],
    [7, 3, 0, 5, 2, "CONDITIONING"],
    [8, 5, 0, 6, 0, "LATENT"],
    [9, 6, 0, 7, 0, "IMAGE"],
    [10, 1, 2, 6, 1, "VAE"],
    [11, 8, 0, 5, 3, "LATENT"]
  ],
  "groups": [],
  "config": {},
  "extra": {},
  "version": 0.4
}
EOF
    
    printf "Workflows installed:\n"
    printf "  - nsfw_image_workflow.json\n"
    printf "  - nsfw_video_workflow.json\n"
}

function provisioning_print_header() {
    printf "\n##############################################\n"
    printf "#                                            #\n"
    printf "#   AI Kings NSFW ComfyUI Provisioning      #\n"
    printf "#         (SEQUENTIAL DOWNLOADS)             #\n"
    printf "#                                            #\n"
    printf "#    Reliable one-by-one downloading        #\n"
    printf "#    Estimated time: 20-30 minutes          #\n"
    printf "#                                            #\n"
    printf "##############################################\n\n"
}

function provisioning_print_end() {
    printf "\n##############################################\n"
    printf "#                                            #\n"
    printf "#   Provisioning Complete!                   #\n"
    printf "#   AI Kings NSFW ComfyUI Ready              #\n"
    printf "#                                            #\n"
    printf "##############################################\n\n"
}

# Start provisioning if not disabled
if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi
