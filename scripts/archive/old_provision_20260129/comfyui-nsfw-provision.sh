#!/bin/bash
# ComfyUI NSFW Model Provisioning Script
# This runs automatically when a Vast.ai instance boots
# It downloads popular NSFW models and checkpoints for ComfyUI

set -e  # Exit on error

echo "🚀 Starting ComfyUI NSFW model provisioning..."

# Retry configuration
PROVISION_RETRY_COUNT=${PROVISION_RETRY_COUNT:-5}
PROVISION_RETRY_DELAY=${PROVISION_RETRY_DELAY:-5}

# Optional manifest URL (JSON mapping filename -> sha256) to verify downloads
MODEL_MANIFEST_URL=${MODEL_MANIFEST_URL:-}

# Prefer curl when available for better retry/resume support
USE_CURL=0
if command -v curl >/dev/null 2>&1; then
    USE_CURL=1
fi

# Base directories
COMFY_DIR="/workspace/ComfyUI"
MODELS_DIR="$COMFY_DIR/models"
CHECKPOINTS_DIR="$MODELS_DIR/checkpoints"
LORAS_DIR="$MODELS_DIR/loras"
VAE_DIR="$MODELS_DIR/vae"

# Create directories if they don't exist
mkdir -p "$CHECKPOINTS_DIR" "$LORAS_DIR" "$VAE_DIR"

# Hugging Face token (set via environment variable HUGGINGFACE_HUB_TOKEN)
HF_TOKEN="${HUGGINGFACE_HUB_TOKEN:-}"
CIVITAI_TOKEN="${CIVITAI_TOKEN:-}"

# Function to download from Hugging Face
download_hf() {
    local repo="$1"
    local file="$2"
    local output="$3"

    if [ -f "$output" ]; then
        echo "✓ Already exists: $(basename $output)"
        return 0
    fi

    local url="https://huggingface.co/$repo/resolve/main/$file"
    echo "⬇️  Downloading: $file from $repo -> $(basename $output)"

    for attempt in $(seq 1 $PROVISION_RETRY_COUNT); do
        echo "  Attempt $attempt/$PROVISION_RETRY_COUNT"
        if [ "$USE_CURL" -eq 1 ]; then
            if [ -n "$HF_TOKEN" ]; then
                curl -fSL --retry $PROVISION_RETRY_COUNT --retry-delay $PROVISION_RETRY_DELAY --continue-at - -H "Authorization: Bearer $HF_TOKEN" -o "$output" "$url" && rc=0 || rc=$?
            else
                curl -fSL --retry $PROVISION_RETRY_COUNT --retry-delay $PROVISION_RETRY_DELAY --continue-at - -o "$output" "$url" && rc=0 || rc=$?
            fi
        else
            if [ -n "$HF_TOKEN" ]; then
                wget -c --tries=$PROVISION_RETRY_COUNT --header="Authorization: Bearer $HF_TOKEN" "$url" -O "$output" && rc=0 || rc=$?
            else
                wget -c --tries=$PROVISION_RETRY_COUNT "$url" -O "$output" && rc=0 || rc=$?
            fi
        fi

        if [ $rc -eq 0 ]; then
            echo "✓ Downloaded: $(basename $output)"
            # Verify checksum if available
            if verify_checksum "$url" "$output"; then
                return 0
            else
                echo "⚠️ Checksum failed for $(basename $output), removing and retrying"
                rm -f "$output"
            fi
        else
            echo "⚠️ Download attempt $attempt failed (rc=$rc)"
        fi

        sleep $PROVISION_RETRY_DELAY
    done

    echo "❌ Failed to download $file after $PROVISION_RETRY_COUNT attempts"
    return 2
}

# Function to download from Civitai
download_civitai() {
    local model_id="$1"
    local output="$2"

    if [ -f "$output" ]; then
        echo "✓ Already exists: $(basename $output)"
        return 0
    fi

    # Attempt to resolve direct download URL via Civitai API (may require token)
    local apiUrl="https://civitai.com/api/v1/models/$model_id"
    local headers=()
    if [ -n "$CIVITAI_TOKEN" ]; then
        headers=( -H "Authorization: Bearer $CIVITAI_TOKEN" )
    fi

    echo "⬇️  Downloading from Civitai: Model $model_id -> $(basename $output)"

    # Try to get download URL
    local downloadUrl
    if command -v curl >/dev/null 2>&1; then
        downloadUrl=$(curl -s ${headers[*]} "$apiUrl" | awk -v RS="," -v ORS="," '1' | sed 's/,/\n/g' | grep -o '"downloadUrl":"[^"]\+' | sed 's/"downloadUrl":"//' | head -n 1 || true)
    else
        downloadUrl=$(wget -q -O - ${headers[*]} "$apiUrl" 2>/dev/null | awk -v RS="," -v ORS="," '1' | sed 's/,/\n/g' | grep -o '"downloadUrl":"[^"]\+' | sed 's/"downloadUrl":"//' | head -n 1 || true)
    fi

    # Fallback to API download endpoint if direct URL not found
    if [ -z "$downloadUrl" ]; then
        if [ -n "$CIVITAI_TOKEN" ]; then
            downloadUrl="https://civitai.com/api/download/models/$model_id?token=$CIVITAI_TOKEN"
        else
            downloadUrl="https://civitai.com/api/download/models/$model_id"
        fi
    fi

    for attempt in $(seq 1 $PROVISION_RETRY_COUNT); do
        echo "  Attempt $attempt/$PROVISION_RETRY_COUNT"
        if [ "$USE_CURL" -eq 1 ]; then
            curl -fSL --retry $PROVISION_RETRY_COUNT --retry-delay $PROVISION_RETRY_DELAY --continue-at - -o "$output" "$downloadUrl" && rc=0 || rc=$?
        else
            wget -c --tries=$PROVISION_RETRY_COUNT "$downloadUrl" -O "$output" && rc=0 || rc=$?
        fi

        if [ $rc -eq 0 ]; then
            echo "✓ Downloaded: $(basename $output)"
            if verify_checksum "$downloadUrl" "$output"; then
                return 0
            else
                echo "⚠️ Checksum failed for $(basename $output), removing and retrying"
                rm -f "$output"
            fi
        else
            echo "⚠️ Download attempt $attempt failed (rc=$rc)"
        fi

        sleep $PROVISION_RETRY_DELAY
    done

    echo "❌ Failed to download model $model_id after $PROVISION_RETRY_COUNT attempts"
    return 2
}

# Verify checksum helper: tries manifest, .sha256 sidecar, or <url>.sha256
verify_checksum() {
    local url="$1"
    local output="$2"

    local filename
    filename=$(basename "$output")

    # 1) If MODEL_MANIFEST_URL provided, attempt to fetch JSON and match
    if [ -n "$MODEL_MANIFEST_URL" ]; then
        echo "🔎 Checking manifest for $filename"
        if command -v curl >/dev/null 2>&1; then
            manifest=$(curl -s -f "$MODEL_MANIFEST_URL" || true)
        else
            manifest=$(wget -q -O - "$MODEL_MANIFEST_URL" || true)
        fi
        if [ -n "$manifest" ]; then
            sha=$(echo "$manifest" | python -c "import sys, json; d=json.load(sys.stdin); print(d.get('$filename',''))" 2>/dev/null || true)
            if [ -n "$sha" ]; then
                echo "$sha  $output" > "$output.sha256.tmp"
                if sha256sum -c "$output.sha256.tmp" >/dev/null 2>&1; then
                    rm -f "$output.sha256.tmp"
                    echo "✓ Checksum verified via manifest"
                    return 0
                else
                    rm -f "$output.sha256.tmp"
                    echo "⚠️ Manifest checksum mismatch"
                    return 1
                fi
            fi
        fi
    fi

    # 2) If a local sidecar exists (output.sha256), use it
    if [ -f "$output.sha256" ]; then
        if sha256sum -c "$output.sha256" >/dev/null 2>&1; then
            echo "✓ Checksum verified via local sidecar"
            return 0
        else
            echo "⚠️ Local sidecar checksum mismatch"
            return 1
        fi
    fi

    # 3) Try fetching <url>.sha256
    local shaurl="$url.sha256"
    local tmpsha="$output.sha256.download"
    if [ "$USE_CURL" -eq 1 ]; then
        curl -fsS --retry 2 -o "$tmpsha" "$shaurl" || true
    else
        wget -q -O "$tmpsha" "$shaurl" || true
    fi
    if [ -s "$tmpsha" ]; then
        # Ensure file contains just the checksum or in common formats
        # Normalize to 'checksum  filename' format
        awk '{print $1"  '$output'"}' "$tmpsha" > "$output.sha256.tmp" || true
        if sha256sum -c "$output.sha256.tmp" >/dev/null 2>&1; then
            rm -f "$output.sha256.tmp" "$tmpsha"
            echo "✓ Checksum verified via remote .sha256"
            return 0
        else
            rm -f "$output.sha256.tmp" "$tmpsha"
            echo "⚠️ Remote .sha256 checksum mismatch"
            return 1
        fi
    fi

    # 4) No checksum available - treat as success but warn
    echo "⚠️ No checksum available for $filename; skipping verification"
    return 0
}

# ====== DOWNLOAD POPULAR NSFW CHECKPOINTS ======

echo "📦 Downloading NSFW Checkpoints..."

# Pony Diffusion V6 XL (Best for fetish/NSFW content - highly detailed and stylized)
download_civitai "290640" "$CHECKPOINTS_DIR/ponyDiffusionV6XL_v6StartWithThisOne.safetensors"

# Realistic Vision V6.0 (Popular NSFW photorealistic model)
download_civitai "245598" "$CHECKPOINTS_DIR/realisticVisionV60_v60B1.safetensors"

# Dreamshaper 8 (Versatile NSFW/SFW model)
download_hf "Lykon/DreamShaper" "DreamShaper_8_pruned.safetensors" \
    "$CHECKPOINTS_DIR/dreamshaper_8.safetensors"

# Deliberate V3 (High-quality NSFW model)
download_hf "XpucT/Deliberate" "Deliberate_v3.safetensors" \
    "$CHECKPOINTS_DIR/deliberate_v3.safetensors"

# ====== DOWNLOAD NSFW LORAS ======

echo "📦 Downloading NSFW LoRAs..."

# Detail Tweaker (Enhances details)
download_civitai "135867" "$LORAS_DIR/add_detail.safetensors"

# Better Hands (Fixes hand generation issues)
download_civitai "85746" "$LORAS_DIR/better_hands.safetensors"

# ====== DOWNLOAD VAE ======

echo "📦 Downloading VAE..."

# VAE for better color/detail
download_hf "stabilityai/sd-vae-ft-mse-original" "vae-ft-mse-840000-ema-pruned.safetensors" \
    "$VAE_DIR/vae-ft-mse-840000-ema-pruned.safetensors"

# ====== DOWNLOAD ANIMATEDIFF MOTION MODELS ======

echo "📦 Downloading AnimateDiff motion models for video generation..."

ANIMATEDIFF_DIR="$MODELS_DIR/animatediff_models"
mkdir -p "$ANIMATEDIFF_DIR"

# AnimateDiff v2 motion module (most compatible with SD 1.5 models)
download_hf "guoyww/animatediff" "mm_sd_v15_v2.ckpt" \
    "$ANIMATEDIFF_DIR/mm_sd_v15_v2.ckpt"

# ====== VERIFY COMFYUI IS RUNNING ======

echo "🔍 Checking if ComfyUI is running..."

# Wait for ComfyUI to start (up to 2 minutes)
for i in {1..24}; do
    if curl -s http://localhost:8188/system_stats > /dev/null 2>&1; then
        echo "✅ ComfyUI is running and responsive!"
        break
    fi
    echo "⏳ Waiting for ComfyUI to start... ($i/24)"
    sleep 5
done

echo "✅ NSFW model provisioning complete!"
echo "📊 Summary:"
echo "   Checkpoints: $(ls -1 $CHECKPOINTS_DIR/*.safetensors 2>/dev/null | wc -l)"
echo "   LoRAs: $(ls -1 $LORAS_DIR/*.safetensors 2>/dev/null | wc -l)"
echo "   VAEs: $(ls -1 $VAE_DIR/*.safetensors 2>/dev/null | wc -l)"
echo "   AnimateDiff: $(ls -1 $ANIMATEDIFF_DIR/*.ckpt 2>/dev/null | wc -l)"
