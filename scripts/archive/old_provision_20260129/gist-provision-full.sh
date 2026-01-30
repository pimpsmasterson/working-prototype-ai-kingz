#!/bin/bash

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI

# Custom provisioning for Fetish King NSFW ComfyUI setup (full model set)

# Packages
APT_PACKAGES=(
    "unrar"
)

PIP_PACKAGES=(
)

NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
    "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation"
)

WORKFLOWS=(
)

# Pony Diffusion V6 XL for NSFW/fetish content
# Pornmaster v1.5 for photorealistic NSFW
CHECKPOINT_MODELS=(
    "https://civitai.com/api/download/models/290640?type=Model&format=SafeTensor&size=full&fp=fp16"
    "https://civitai.com/api/download/models/139562?type=Model&format=SafeTensor"
    # add additional checkpoint URLs here as needed
)

UNET_MODELS=(
)

# NSFW/Fetish LoRAs
LORA_MODELS=(
    "https://files.catbox.moe/f6r1nl.safetensors"
    "https://files.catbox.moe/pk6hl3.safetensors"
    "https://files.catbox.moe/wmshk3.safetensors"
    "https://files.catbox.moe/88e51n.rar"
    "https://files.catbox.moe/9qixqa.safetensors"
    "https://files.catbox.moe/yz5c9g.safetensors"
    "https://files.catbox.moe/tlt57h.safetensors"
    "https://files.catbox.moe/odmswn.safetensors"
    "https://files.catbox.moe/z71ic0.safetensors"
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
    if [[ -n ${APT_PACKAGES[@]} ]]; then
        sudo apt-get update
        sudo apt-get install -y "${APT_PACKAGES[@]}"
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n ${PIP_PACKAGES[@]} ]]; then
        pip install --no-cache-dir "${PIP_PACKAGES[@]}"
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

# Patched provisioning_download: appends civitai token as query param and uses Bearer for HF only
function provisioning_download() {
    local url="$1"
    local dir="$2"
    local auth_token=""
    local download_url="$url"

    if [[ -n "$HUGGINGFACE_HUB_TOKEN" && "$url" =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co ]]; then
        auth_token="$HUGGINGFACE_HUB_TOKEN"
    fi

    if [[ -n "$CIVITAI_TOKEN" && "$url" =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com ]]; then
        if [[ "$url" == *"?"* ]]; then
            download_url="${url}&token=${CIVITAI_TOKEN}"
        else
            download_url="${url}?token=${CIVITAI_TOKEN}"
        fi
    fi

    if [[ -n "$auth_token" ]]; then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes=4M --timeout=60 --tries=3 -P "$dir" "$download_url"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes=4M --timeout=60 --tries=3 -P "$dir" "$download_url"
    fi

    return $?
}

function provisioning_install_workflows() {
    workflows_dir="${COMFYUI_DIR}/user/default/workflows"
    mkdir -p "$workflows_dir"
    # Minimal workflow files created here; customize as needed
    cat > "${workflows_dir}/nsfw_image_workflow.json" << 'EOF'
{
  "workflow": {"nodes": []}
}
EOF
}

function provisioning_print_header() {
    cat <<'HDR'
##############################################
#                                            #
#   AI Kings NSFW ComfyUI Provisioning      #
#         (FULL MODEL SET)                   #
#                                            #
##############################################
HDR
}

function provisioning_print_end() {
    echo "Provisioning complete"
}

# Start provisioning unless explicitly disabled
if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi
