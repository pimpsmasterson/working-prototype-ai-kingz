#!/bin/bash

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI

# Custom provisioning for Fetish King NSFW ComfyUI setup

# Packages
APT_PACKAGES=(
    #"package-1"
)

PIP_PACKAGES=(
    #"package-1"
)

NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
    "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation"
)

WORKFLOWS=(
    # Will be added via custom script
)

# Pony Diffusion V6 XL for NSFW/fetish content
# Pornmaster v1.5 for photorealistic NSFW
CHECKPOINT_MODELS=(
    "https://civitai.com/api/download/models/290640?type=Model&format=SafeTensor&size=full&fp=fp16"
    "https://civitai.com/api/download/models/139562?type=Model&format=SafeTensor"
)

UNET_MODELS=(
)

# NSFW/Fetish LoRAs
LORA_MODELS=(
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
)

VAE_MODELS=(
)

ESRGAN_MODELS=(
)

CONTROLNET_MODELS=(
)

# AnimateDiff motion models for video generation
ANIMATEDIFF_MODELS=(
    "https://huggingface.co/guoyww/animatediff/resolve/main/mm_sd_v15_v2.ckpt"
)

# RIFE frame interpolation models
RIFE_MODELS=(
    "https://github.com/hzwer/Practical-RIFE/releases/download/v4.7/rife47.pth"
)

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages
    provisioning_get_files \
        "${COMFYUI_DIR}/models/checkpoints" \
        "${CHECKPOINT_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/unet" \
        "${UNET_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/lora" \
        "${LORA_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/controlnet" \
        "${CONTROLNET_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/vae" \
        "${VAE_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/esrgan" \
        "${ESRGAN_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/animatediff_models" \
        "${ANIMATEDIFF_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/rife" \
        "${RIFE_MODELS[@]}"
    provisioning_install_workflows
    provisioning_print_end
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
        sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
        pip install --no-cache-dir ${PIP_PACKAGES[@]}
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="${COMFYUI_DIR}/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Updating node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
                if [[ -e $requirements ]]; then
                    pip install --no-cache-dir -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip install --no-cache-dir -r "$requirements"
            fi
        fi
    done
}

function provisioning_get_files() {
    if [[ -z $2 ]]; then return 1; fi
    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"
        printf "\n"
    done
}

function provisioning_install_workflows() {
    workflows_dir="${COMFYUI_DIR}/user/default/workflows"
    mkdir -p "$workflows_dir"
    
    # Download or create workflows here
    cat > "${workflows_dir}/nsfw_image_workflow.json" << 'EOF'
{
  "workflow": {
    "nodes": [
      {
        "id": 1,
        "type": "CheckpointLoaderSimple",
        "inputs": {
          "ckpt_name": "ponyDiffusionV6XL_v6StartWithThisOne.safetensors"
        },
        "outputs": [
          {"name": "MODEL"},
          {"name": "CLIP"},
          {"name": "VAE"}
        ]
      },
      {
        "id": 2,
        "type": "CLIPTextEncode",
        "inputs": {
          "text": "1girl, detailed face, high quality, nsfw, fetish content",
          "clip": ["CLIP", 0]
        },
        "outputs": [{"name": "CONDITIONING"}]
      },
      {
        "id": 3,
        "type": "CLIPTextEncode",
        "inputs": {
          "text": "low quality, blurry, censored",
          "clip": ["CLIP", 0]
        },
        "outputs": [{"name": "CONDITIONING"}]
      },
      {
        "id": 4,
        "type": "KSampler",
        "inputs": {
          "model": ["MODEL", 0],
          "positive": ["CONDITIONING", 0],
          "negative": ["CONDITIONING", 1],
          "latent_image": ["EmptyLatentImage", 0],
          "seed": 12345,
          "steps": 20,
          "cfg": 7.0,
          "sampler_name": "euler",
          "scheduler": "normal",
          "denoise": 1.0
        },
        "outputs": [{"name": "LATENT"}]
      },
      {
        "id": 5,
        "type": "VAEDecode",
        "inputs": {
          "samples": ["LATENT", 0],
          "vae": ["VAE", 0]
        },
        "outputs": [{"name": "IMAGE"}]
      },
      {
        "id": 6,
        "type": "SaveImage",
        "inputs": {
          "images": ["IMAGE", 0],
          "filename_prefix": "nsfw_image"
        }
      },
      {
        "id": 7,
        "type": "EmptyLatentImage",
        "inputs": {
          "width": 1024,
          "height": 1024,
          "batch_size": 1
        },
        "outputs": [{"name": "LATENT"}]
      }
    ],
    "links": [
      [1, 0, 4, 0],
      [1, 1, 2, 1],
      [1, 1, 3, 1],
      [1, 2, 5, 1],
      [2, 0, 4, 1],
      [3, 0, 4, 2],
      [4, 0, 5, 0],
      [5, 0, 6, 0],
      [7, 0, 4, 3]
    ]
  }
}
EOF

    cat > "${workflows_dir}/nsfw_video_workflow.json" << 'EOF'
{
  "workflow": {
    "nodes": [
      {
        "id": 1,
        "type": "CheckpointLoaderSimple",
        "inputs": {
          "ckpt_name": "ponyDiffusionV6XL_v6StartWithThisOne.safetensors"
        },
        "outputs": [
          {"name": "MODEL"},
          {"name": "CLIP"},
          {"name": "VAE"}
        ]
      },
      {
        "id": 2,
        "type": "CLIPTextEncode",
        "inputs": {
          "text": "1girl, detailed face, high quality, nsfw, fetish content, dynamic pose",
          "clip": ["CLIP", 0]
        },
        "outputs": [{"name": "CONDITIONING"}]
      },
      {
        "id": 3,
        "type": "CLIPTextEncode",
        "inputs": {
          "text": "low quality, blurry, censored, static",
          "clip": ["CLIP", 0]
        },
        "outputs": [{"name": "CONDITIONING"}]
      },
      {
        "id": 4,
        "type": "AnimateDiffLoader",
        "inputs": {
          "model_name": "mm_sd_v15_v2.ckpt",
          "beta_schedule": "sqrt_linear (AnimateDiff)"
        },
        "outputs": [{"name": "MODEL"}]
      },
      {
        "id": 5,
        "type": "KSampler",
        "inputs": {
          "model": ["MODEL", 0],
          "positive": ["CONDITIONING", 0],
          "negative": ["CONDITIONING", 1],
          "latent_image": ["EmptyLatentImage", 0],
          "seed": 12345,
          "steps": 20,
          "cfg": 7.0,
          "sampler_name": "euler",
          "scheduler": "normal",
          "denoise": 1.0
        },
        "outputs": [{"name": "LATENT"}]
      },
      {
        "id": 6,
        "type": "VAEDecode",
        "inputs": {
          "samples": ["LATENT", 0],
          "vae": ["VAE", 0]
        },
        "outputs": [{"name": "IMAGE"}]
      },
      {
        "id": 7,
        "type": "SaveAnimatedWEBP",
        "inputs": {
          "images": ["IMAGE", 0],
          "filename_prefix": "nsfw_video",
          "fps": 8,
          "lossless": false,
          "quality": 80,
          "method": "default"
        }
      },
      {
        "id": 8,
        "type": "EmptyLatentImage",
        "inputs": {
          "width": 512,
          "height": 512,
          "batch_size": 16
        },
        "outputs": [{"name": "LATENT"}]
      }
    ],
    "links": [
      [1, 0, 4, 0],
      [1, 1, 2, 1],
      [1, 1, 3, 1],
      [1, 2, 6, 1],
      [2, 0, 5, 1],
      [3, 0, 5, 2],
      [4, 0, 5, 0],
      [5, 0, 6, 0],
      [6, 0, 7, 0],
      [8, 0, 5, 3]
    ]
  }
}
EOF
}

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          Fetish King NSFW Provisioning      #\n#                                            #\n#         This will take some time            #\n#                                            #\n# Your container will be ready on completion  #\n#                                            #\n##############################################\n\n"
}

function provisioning_print_end() {
    printf "\nProvisioning complete: Fetish King NSFW ComfyUI ready\n\n"
}

function provisioning_has_valid_hf_token() {
    [[ -n "$HF_TOKEN" ]] || return 1
    url="https://huggingface.co/api/whoami-v2"
    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $HF_TOKEN" \
        -H "Content-Type: application/json")
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

function provisioning_has_valid_civitai_token() {
    [[ -n "$CIVITAI_TOKEN" ]] || return 1
    url="https://civitai.com/api/v1/models?hidden=1&limit=1"
    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $CIVITAI_TOKEN" \
        -H "Content-Type: application/json")
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

# Download from $1 URL to $2 file path
function provisioning_download() {
  # Determine download URL and auth behavior
  download_url="$1"
  if [[ -n $HF_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
    auth_token="$HF_TOKEN"
  elif [[ -n $CIVITAI_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
    # Append token as query parameter for Civitai
    if [[ "$1" == *"?"* ]]; then
      download_url="${1}&token=${CIVITAI_TOKEN}"
    else
      download_url="${1}?token=${CIVITAI_TOKEN}"
    fi
    auth_token=""
  fi

  if [[ -n $auth_token ]];then
    wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$download_url"
  else
    wget -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$download_url"
  fi
}

# Allow user to disable provisioning if they started with a script they didn't want
if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi