#!/bin/bash
# AI Kings NSFW ComfyUI Provisioning - SEQUENTIAL (RELIABLE)
# Patched version for Gist: appends CIVITAI token as query parameter

# Ensure we are in a working directory
WORKSPACE=${WORKSPACE:-/workspace}
cd "$WORKSPACE"

# Activate venv if it exists
if [ -f "/venv/main/bin/activate" ]; then
    source /venv/main/bin/activate
elif [ -f "/usr/bin/python3" ]; then
    # Fallback to system python if no venv
    alias python='/usr/bin/python3'
fi

COMFYUI_DIR=${WORKSPACE}/ComfyUI

# System packages
APT_PACKAGES=(
    "unrar"
    "p7zip-full"
)

# Python packages (none needed - covered by node requirements)
PIP_PACKAGES=()

# Custom nodes (including nodes needed for advanced workflows)
NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
    "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
    "https://github.com/ssitu/ComfyUI_UltimateSDUpscale"
    "https://github.com/kijai/ComfyUI-DepthAnythingV2"
)

# Pony Diffusion V6 XL + Pornmaster v1.5 for NSFW content
CHECKPOINT_MODELS=(
    "https://civitai.com/api/download/models/290640|ponyDiffusionV6XL_v6StartWithThisOne.safetensors"
    "https://civitai.com/api/download/models/206536|pornmaster_xl.safetensors"
)

UNET_MODELS=()

# DepthAnything V2 Models
DEPTHANYTHING_MODELS=(
    "https://huggingface.co/Kijai/depth-anything-2-safetensors/resolve/main/depth_anything_v2_vitl.safetensors|depth_anything_v2_vitl.safetensors"
)

# NSFW/Fetish LoRAs
LORA_MODELS=(
    "https://civitai.com/api/download/models/152309|pony_realism_v2.1.safetensors"
    # Shared clothes
    "https://files.catbox.moe/f6r1nl.safetensors"
    # X-ray glasses
    "https://files.catbox.moe/pk6hl3.safetensors"
    # Cunnilingus gesture
    "https://files.catbox.moe/wmshk3.safetensors"
    # Penis hug
    "https://files.catbox.moe/88e51n.rar"  # This is a RAR, might need handling
    # Empty eyes drooling
    "https://files.catbox.moe/9qixqa.safetensors"
    # Glowing eyes
    "https://files.catbox.moe/yz5c9g.safetensors"
    # Quadruple amputee
    "https://files.catbox.moe/tlt57h.safetensors"
    # Ugly bastard
    "https://files.catbox.moe/odmswn.safetensors"
    # Sex machine
    "https://files.catbox.moe/z71ic0.safetensors"
    # Stasis tank
    "https://files.catbox.moe/mxbbg2.safetensors"
    # Additional scat LoRAs from Hugging Face
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/Soiling-V1.safetensors|Soiling-V1.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/turtleheading-V1.safetensors|turtleheading-V1.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/poop_squatV2.safetensors|poop_squatV2.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/Poop_SquatV3.safetensors|Poop_SquatV3.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/HyperDump.safetensors|HyperDump.safetensors"
    "https://huggingface.co/BlackHat404/scatmodels/resolve/main/HyperDumpPlus.safetensors|HyperDumpPlus.safetensors"
    "https://huggingface.co/JollyIm/Defecation/resolve/main/defecation_v1.safetensors|defecation_v1.safetensors"
)

VAE_MODELS=()
ESRGAN_MODELS=(
    "https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth|4x-UltraSharp.pth"
)
CONTROLNET_MODELS=(
    "https://huggingface.co/thibaud/controlnet-openpose-sdxl-1.0/resolve/main/OpenPoseXL2.safetensors|OpenPoseXL2.safetensors"
    "https://huggingface.co/diffusers/controlnet-depth-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors|diffusion_pytorch_model.safetensors"
)

# AnimateDiff motion model for video generation
ANIMATEDIFF_MODELS=(
    "https://huggingface.co/guoyww/animatediff/resolve/main/mm_sd_v15_v2.ckpt"
)

# RIFE frame interpolation model (Hugging Face mirror for stability)
RIFE_MODELS=(
    "https://huggingface.co/wavespeed/misc/resolve/main/rife/rife47.pth"
)

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    # Check for tokens
    if [[ -z "$CIVITAI_TOKEN" ]]; then
        printf "⚠ WARNING: CIVITAI_TOKEN is not set. Restricted models (Pony V6 XL) will fail to download!\n"
    fi
    if [[ -z "$HUGGINGFACE_HUB_TOKEN" ]]; then
        printf "⚠ WARNING: HUGGINGFACE_HUB_TOKEN is not set.\n"
    fi

    provisioning_print_header
    provisioning_install_comfyui
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
        "${COMFYUI_DIR}/models/depthanything" \
        "${DEPTHANYTHING_MODELS[@]}"
    
    provisioning_get_files_sequential \
        "${COMFYUI_DIR}/models/loras" \
        "${LORA_MODELS[@]}"
    
    provisioning_get_files_sequential \
        "${COMFYUI_DIR}/models/controlnet" \
        "${CONTROLNET_MODELS[@]}"
    
    provisioning_get_files_sequential \
        "${COMFYUI_DIR}/models/vae" \
        "${VAE_MODELS[@]}"
    
    provisioning_get_files_sequential \
        "${COMFYUI_DIR}/models/upscale_models" \
        "${ESRGAN_MODELS[@]}"
    
    provisioning_get_files_sequential \
        "${COMFYUI_DIR}/models/animatediff_models" \
        "${ANIMATEDIFF_MODELS[@]}"
    
    provisioning_get_files_sequential \
        "${COMFYUI_DIR}/models/rife" \
        "${RIFE_MODELS[@]}"
    
    # Extract any RAR/ZIP archives in loras folder
    provisioning_extract_archives "${COMFYUI_DIR}/models/loras"
    
    # Create symlink for backwards compatibility (lora vs loras)
    if [ ! -L "${COMFYUI_DIR}/models/lora" ]; then
        ln -s "${COMFYUI_DIR}/models/loras" "${COMFYUI_DIR}/models/lora"
    fi
    provisioning_install_workflows
    
    # Launch ComfyUI automatically
    printf "\nLaunching ComfyUI...\n"
    cd "${COMFYUI_DIR}"
    nohup python main.py --listen 0.0.0.0 --port 8188 --enable-cors-header > "${WORKSPACE}/comfyui.log" 2>&1 &
    
    printf "✓ ComfyUI launched in background. Check logs with: tail -f /workspace/comfyui.log\n"
    provisioning_print_end
}

function provisioning_print_header() {
    printf "\n"
    printf "========================================\n"
    printf " AI Kings NSFW ComfyUI Provisioning\n"
    printf " Complete with All Custom Nodes\n"
    printf "========================================\n"
    printf "\n"
}

function provisioning_print_end() {
    printf "\n"
    printf "========================================\n"
    printf " ✓ Provisioning Complete\n"
    printf "========================================\n"
    printf "\n"
}

function provisioning_get_apt_packages() {
    if [[ -n "${APT_PACKAGES[*]}" ]]; then
        sudo apt-get update
        sudo apt-get install -y "${APT_PACKAGES[@]}"
    fi
}

function provisioning_install_comfyui() {
    if [[ ! -d "${COMFYUI_DIR}" ]]; then
        printf "Installing ComfyUI...\n"
        git clone https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}"
        if [[ -e "${COMFYUI_DIR}/requirements.txt" ]]; then
            pip install --no-cache-dir -r "${COMFYUI_DIR}/requirements.txt"
        fi
        printf "✓ ComfyUI installed\n"
    else
        printf "ComfyUI already exists, skipping installation\n"
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
    for item in "${arr[@]}"; do
        count=$((count + 1))
        
        # Split URL and Filename if separated by |
        local url="${item%|*}"
        local filename="${item#*|}"
        if [[ "$url" == "$filename" ]]; then
            filename=""
        fi

        printf "\n[%d/%d] Downloading: %s\n" "$count" "${#arr[@]}" "${url}"
        if [[ -n "$filename" ]]; then
            printf "Target filename: %s\n" "$filename"
        fi
        
        # Retry logic: try up to 5 times per file
        local retry=0
        local max_retries=5
        while [[ $retry -lt $max_retries ]]; do
            if provisioning_download "${url}" "${dir}" "${filename}"; then
                # Verification: check if file exists
                printf "✓ Download complete\n"
                break
            else
                retry=$((retry + 1))
                if [[ $retry -lt $max_retries ]]; then
                    printf "⚠ Download failed, retrying (%s/%s)...\n" "$retry" "$max_retries"
                    sleep 5
                else
                    printf "✗ Download failed after %s attempts: %s\n" "$max_retries" "${url}"
                fi
            fi
        done
    done
    printf "\n"
}

function provisioning_download() {
    local url="$1"
    local dir="$2"
    local filename="$3"
    local auth_token=""

    # Check if target file already exists when filename is specified
    if [[ -n "$filename" && -f "${dir}/${filename}" ]]; then
        printf "File already exists, skipping: %s\n" "$filename"
        return 0
    fi
    
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

  # Download with or without auth header
  if [[ -n "$filename" ]]; then
    if [[ -n "$auth_token" ]]; then
        wget --header="Authorization: Bearer $auth_token" \
          -q --show-progress \
          -e dotbytes=4M --timeout=60 --tries=3 \
          -O "${dir}/${filename}" "$download_url"
    else
        wget -q --show-progress \
          -e dotbytes=4M --timeout=60 --tries=3 \
          -O "${dir}/${filename}" "$download_url"
    fi
  else
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
  fi
    
    return $?
}

function provisioning_extract_archives() {
    local dir="$1"
    printf "Extracting archives in %s...\n" "$dir"
    
    # Extract RAR files
    for file in "$dir"/*.rar; do
        if [[ -f "$file" ]]; then
            printf "Extracting RAR: %s\n" "$file"
            unrar x -o- "$file" "$dir/" && rm "$file"
        fi
    done
    
    # Extract ZIP files
    for file in "$dir"/*.zip; do
        if [[ -f "$file" ]]; then
            printf "Extracting ZIP: %s\n" "$file"
            unzip -o "$file" -d "$dir/" && rm "$file"
        fi
    done
    
    # Extract 7z files
    for file in "$dir"/*.7z; do
        if [[ -f "$file" ]]; then
            printf "Extracting 7Z: %s\n" "$file"
            7z x "$file" -o"$dir/" -y && rm "$file"
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
  "last_link_id": 9,
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
      "size": [422, 164],
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
      "widgets_values": ["1girl, detailed face, high quality, nsfw, fetish content"]
    },
    {
      "id": 3,
      "type": "CLIPTextEncode",
      "pos": [850, 50],
      "size": [425, 180],
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
      "widgets_values": ["low quality, blurry, censored"]
    },
    {
      "id": 4,
      "type": "KSampler",
      "pos": [1300, 50],
      "size": [315, 262],
      "flags": {},
      "order": 3,
      "mode": 0,
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1},
        {"name": "positive", "type": "CONDITIONING", "link": 4},
        {"name": "negative", "type": "CONDITIONING", "link": 5},
        {"name": "latent_image", "type": "LATENT", "link": 9}
      ],
      "outputs": [
        {"name": "LATENT", "type": "LATENT", "links": [6]}
      ],
      "properties": {},
      "widgets_values": [12345, 20, 7.0, "euler", "normal", 1.0]
    },
    {
      "id": 5,
      "type": "VAEDecode",
      "pos": [1650, 50],
      "size": [210, 46],
      "flags": {},
      "order": 4,
      "mode": 0,
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 6},
        {"name": "vae", "type": "VAE", "link": 7}
      ],
      "outputs": [
        {"name": "IMAGE", "type": "IMAGE", "links": [8]}
      ],
      "properties": {},
      "widgets_values": []
    },
    {
      "id": 6,
      "type": "SaveImage",
      "pos": [1900, 50],
      "size": [400, 450],
      "flags": {},
      "order": 5,
      "mode": 0,
      "inputs": [
        {"name": "images", "type": "IMAGE", "link": 8}
      ],
      "outputs": [],
      "properties": {},
      "widgets_values": ["nsfw_image"]
    },
    {
      "id": 7,
      "type": "EmptyLatentImage",
      "pos": [1300, 350],
      "size": [315, 106],
      "flags": {},
      "order": 6,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {"name": "LATENT", "type": "LATENT", "links": [9]}
      ],
      "properties": {},
      "widgets_values": [1024, 1024, 1]
    }
  ],
  "links": [
    [1, 0, 4, 0],
    [2, 1, 2, 0],
    [3, 1, 3, 0],
    [4, 0, 4, 1],
    [5, 0, 4, 2],
    [6, 0, 5, 0],
    [7, 2, 5, 1],
    [8, 0, 6, 0],
    [9, 0, 7, 0]
  ]
}
EOF

    cat > "${workflows_dir}/nsfw_video_workflow.json" << 'EOF'
{
  "last_node_id": 8,
  "last_link_id": 10,
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
        {"name": "VAE", "type": "VAE", "links": [9]}
      ],
      "properties": {},
      "widgets_values": ["ponyDiffusionV6XL_v6StartWithThisOne.safetensors"]
    },
    {
      "id": 2,
      "type": "CLIPTextEncode",
      "pos": [400, 50],
      "size": [422, 164],
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
      "widgets_values": ["1girl, detailed face, high quality, nsfw, fetish content, dynamic pose"]
    },
    {
      "id": 3,
      "type": "CLIPTextEncode",
      "pos": [850, 50],
      "size": [425, 180],
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
      "widgets_values": ["low quality, blurry, censored, static"]
    },
    {
      "id": 4,
      "type": "AnimateDiffLoader",
      "pos": [1300, 50],
      "size": [315, 122],
      "flags": {},
      "order": 3,
      "mode": 0,
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 1}
      ],
      "outputs": [
        {"name": "MODEL", "type": "MODEL", "links": [6]}
      ],
      "properties": {},
      "widgets_values": ["mm_sd_v15_v2.ckpt", "sqrt_linear (AnimateDiff)"]
    },
    {
      "id": 5,
      "type": "KSampler",
      "pos": [1650, 50],
      "size": [315, 262],
      "flags": {},
      "order": 4,
      "mode": 0,
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 6},
        {"name": "positive", "type": "CONDITIONING", "link": 4},
        {"name": "negative", "type": "CONDITIONING", "link": 5},
        {"name": "latent_image", "type": "LATENT", "link": 8}
      ],
      "outputs": [
        {"name": "LATENT", "type": "LATENT", "links": [7]}
      ],
      "properties": {},
      "widgets_values": [12345, 20, 7.0, "euler", "normal", 1.0]
    },
    {
      "id": 6,
      "type": "VAEDecode",
      "pos": [2000, 50],
      "size": [210, 46],
      "flags": {},
      "order": 5,
      "mode": 0,
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 7},
        {"name": "vae", "type": "VAE", "link": 9}
      ],
      "outputs": [
        {"name": "IMAGE", "type": "IMAGE", "links": [10]}
      ],
      "properties": {},
      "widgets_values": []
    },
    {
      "id": 7,
      "type": "SaveAnimatedWEBP",
      "pos": [2250, 50],
      "size": [400, 450],
      "flags": {},
      "order": 6,
      "mode": 0,
      "inputs": [
        {"name": "images", "type": "IMAGE", "link": 10}
      ],
      "outputs": [],
      "properties": {},
      "widgets_values": ["nsfw_video", 8, false, 80, "default"]
    },
    {
      "id": 8,
      "type": "EmptyLatentImage",
      "pos": [1650, 350],
      "size": [315, 106],
      "flags": {},
      "order": 7,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {"name": "LATENT", "type": "LATENT", "links": [8]}
      ],
      "properties": {},
      "widgets_values": [512, 512, 16]
    }
  ],
  "links": [
    [1, 0, 4, 0],
    [2, 1, 2, 0],
    [3, 1, 3, 0],
    [4, 0, 5, 1],
    [5, 0, 5, 2],
    [6, 0, 5, 0],
    [7, 0, 6, 0],
    [8, 0, 8, 0],
    [9, 2, 6, 1],
    [10, 0, 7, 0]
  ]
}
EOF
}

# Start provisioning
provisioning_start
