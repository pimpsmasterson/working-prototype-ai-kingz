#!/bin/bash
# 🚜 AI KINGS - MASTER HARVESTER 2026 v2.0
# Purpose: Clean install harvest of ALL models/nodes to Dropbox.
# No ComfyUI install needed, just download and sync.
#
# Usage:
#   export DROPBOX_TOKEN="your_token_here"
#   export CIVITAI_TOKEN="your_civitai_token"  # Optional but recommended
#   ./master_harvest.sh

# Don't exit on individual errors - we want to continue harvesting
set -uo pipefail

# --- AUTO-SHUTDOWN AFTER 2 HOURS ---
MAX_RUNTIME_SECONDS=7200  # 2 hours
SCRIPT_START_TIME=$(date +%s)

# Background watchdog that kills script after 2 hours
(
    sleep $MAX_RUNTIME_SECONDS
    echo ""
    echo "⏰ AUTO-SHUTDOWN: 2 hour limit reached. Terminating harvest..."
    echo "📊 Check /workspace/master_harvest.log for progress"
    # Kill the main script process group
    kill -TERM -$$ 2>/dev/null || kill -TERM $$ 2>/dev/null
    sleep 5
    # If still running, force kill
    kill -9 -$$ 2>/dev/null || kill -9 $$ 2>/dev/null
) &
WATCHDOG_PID=$!

# Cleanup watchdog on normal exit
trap "kill $WATCHDOG_PID 2>/dev/null; exit" EXIT

# --- CONFIGURATION ---
VAST_WORKSPACE="/workspace"
HARVEST_ROOT="${VAST_WORKSPACE}/harvest_v2_2026"
LOG_FILE="${VAST_WORKSPACE}/master_harvest.log"
FAILED_LOG="${VAST_WORKSPACE}/failed_harvests.log"
REMOTE_NAME="dropbox_remote"
DROPBOX_DEST="/AI_KINGS_HUB_2026"

# Counters for summary
TOTAL_COUNT=0
SUCCESS_COUNT=0
FAILED_COUNT=0

log() { echo "$(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE"; }

# --- 1. SYSTEM INITIALIZATION ---
log "🚀 Starting Master Harvest v2.0..."
log "📁 Target: ${REMOTE_NAME}:${DROPBOX_DEST}"

apt-get update && apt-get install -y aria2 curl git rclone python3-pip || {
    log "⚠️ Some packages failed to install, continuing..."
}

mkdir -p "$HARVEST_ROOT"/{checkpoints/nsfw,checkpoints/standard,checkpoints/video}
mkdir -p "$HARVEST_ROOT"/{loras/nsfw,loras/utility,loras/catbox,loras/ltx}
mkdir -p "$HARVEST_ROOT"/{vae,text_encoders,controlnet,upscale_models}
mkdir -p "$HARVEST_ROOT"/{diffusion_models/wan,diffusion_models/ltx,diffusion_models/flux}
mkdir -p "$HARVEST_ROOT"/{animatediff_models,detection/yolo,detection/sam,rife}
: > "$FAILED_LOG"  # Clear/create failed log

# --- 2. RCLONE CONFIG ---
if [ -z "${DROPBOX_TOKEN:-}" ]; then
    log "❌ ERROR: DROPBOX_TOKEN not set."
    log "   Run: export DROPBOX_TOKEN='your_token_here'"
    exit 1
fi

log "🔧 Configuring rclone for Dropbox..."
mkdir -p ~/.config/rclone
cat > ~/.config/rclone/rclone.conf << EOF
[${REMOTE_NAME}]
type = dropbox
token = {"access_token":"${DROPBOX_TOKEN}","token_type":"bearer","expiry":"2027-01-01T00:00:00.000000000Z"}
EOF

# Verify rclone config works
if ! rclone lsd "${REMOTE_NAME}:/" >/dev/null 2>&1; then
    log "❌ ERROR: rclone cannot connect to Dropbox. Check your token."
    exit 1
fi
log "✅ Dropbox connection verified"

# --- 3. CIVITAI SETUP ---
CIVITAI_HEADER=""
if [ -n "${CIVITAI_TOKEN:-}" ]; then
    CIVITAI_HEADER="--header=Authorization: Bearer ${CIVITAI_TOKEN}"
    log "✅ Civitai token configured"
else
    log "⚠️ No CIVITAI_TOKEN set - some downloads may fail"
fi

# --- 4. HARVEST QUEUE ---
# Format: "URL|FILENAME|TARGET_SUBDIR"
HARVEST_QUEUE=(
    # ═══════════════════════════════════════════════════════════════════
    # 🔞 PRIMARY NSFW ENGINES (HuggingFace - Reliable)
    # ═══════════════════════════════════════════════════════════════════
    "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors|Wan2.2_Remix_NSFW_i2v_14b_high_fp8.safetensors|checkpoints/nsfw"
    "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors|Wan2.2_Remix_NSFW_i2v_14b_low_fp8.safetensors|checkpoints/nsfw"
    "https://huggingface.co/Phr00t/WAN2.2-14B-Rapid-AllInOne/resolve/main/WAN2.2-14B-Rapid-AllInOne.safetensors|WAN2.2-14B-Rapid-AllInOne.safetensors|checkpoints/nsfw"

    # ═══════════════════════════════════════════════════════════════════
    # 🎭 STANDARD CHECKPOINTS (HuggingFace - Reliable)
    # ═══════════════════════════════════════════════════════════════════
    "https://huggingface.co/SG161222/RealVisXL_V4.0/resolve/main/RealVisXL_V4.0.safetensors|RealVisXL_V4.0.safetensors|checkpoints/standard"
    "https://huggingface.co/Comfy-Org/stable-diffusion-3.5-fp8/resolve/main/sd3.5_large_fp8_scaled.safetensors|sd3.5_large_fp8_scaled.safetensors|checkpoints/standard"
    "https://huggingface.co/stablediffusionapi/dreamshaper-8/resolve/main/dreamshaper_8.safetensors|dreamshaper_8.safetensors|checkpoints/standard"

    # ═══════════════════════════════════════════════════════════════════
    # 🎥 VIDEO MODELS (HuggingFace)
    # ═══════════════════════════════════════════════════════════════════
    "https://huggingface.co/Lightricks/LTX-Video/resolve/main/ltx-video-2b-v0.9.8.safetensors|ltx-video-2b-v0.9.8.safetensors|checkpoints/video"

    # ═══════════════════════════════════════════════════════════════════
    # 🎨 LoRAs - NSFW (Civitai - Requires Token)
    # ═══════════════════════════════════════════════════════════════════
    "https://civitai.com/api/download/models/1811313|wan-dr34ml4y-nsfw.safetensors|loras/nsfw"
    "https://civitai.com/api/download/models/1307155|wan-general-nsfw.safetensors|loras/nsfw"
    "https://civitai.com/api/download/models/8877|squatting-cowgirl.safetensors|loras/nsfw"

    # ═══════════════════════════════════════════════════════════════════
    # 🎨 LoRAs - UTILITY (HuggingFace)
    # ═══════════════════════════════════════════════════════════════════
    "https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-T2V-A14B-4steps-lora-rank64-V1.safetensors|wan2.2-lightning-4step.safetensors|loras/utility"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_high_noise.safetensors|wan2.2_t2v_lightx2v_4steps_lora_v1.1_high_noise.safetensors|loras/utility"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_low_noise.safetensors|wan2.2_t2v_lightx2v_4steps_lora_v1.1_low_noise.safetensors|loras/utility"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors|wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors|loras/utility"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors|wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors|loras/utility"
    "https://huggingface.co/JollyIm/Defecation/resolve/main/defecation_v1.safetensors|defecation_v1.safetensors|loras/nsfw"

    # ═══════════════════════════════════════════════════════════════════
    # 🎨 LoRAs - CATBOX.MOE BACKUP (May have dead links)
    # ═══════════════════════════════════════════════════════════════════
    "https://files.catbox.moe/wmshk3.safetensors|cunnilingus_gesture.safetensors|loras/catbox"
    "https://files.catbox.moe/9qixqa.safetensors|empty_eyes_drooling.safetensors|loras/catbox"
    "https://files.catbox.moe/yz5c9g.safetensors|glowing_eyes.safetensors|loras/catbox"
    "https://files.catbox.moe/tlt57h.safetensors|quadruple_amputee.safetensors|loras/catbox"
    "https://files.catbox.moe/odmswn.safetensors|ugly_bastard.safetensors|loras/catbox"
    "https://files.catbox.moe/z71ic0.safetensors|sex_machine.safetensors|loras/catbox"
    "https://files.catbox.moe/mxbbg2.safetensors|stasis_tank.safetensors|loras/catbox"

    # ═══════════════════════════════════════════════════════════════════
    # 📝 TEXT ENCODERS (HuggingFace)
    # ═══════════════════════════════════════════════════════════════════
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn.safetensors|umt5_xxl_fp8_e4m3fn.safetensors|text_encoders"
    "https://huggingface.co/Comfy-Org/LTX-2/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors|umt5_xxl_fp8_e4m3fn_scaled.safetensors|text_encoders"
    "https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors|gemma_3_12B_it_fp4_mixed.safetensors|text_encoders"
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors|clip_l.safetensors|text_encoders"
    "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors|t5xxl_fp16.safetensors|text_encoders"

    # ═══════════════════════════════════════════════════════════════════
    # 🎬 VAE MODELS (HuggingFace)
    # ═══════════════════════════════════════════════════════════════════
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan2.1_vae.safetensors|wan2.1_vae.safetensors|vae"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors|wan2.2_vae.safetensors|vae"
    "https://huggingface.co/Comfy-Org/Lumina_Image_2.0_Repackaged/resolve/main/split_files/vae/ae.safetensors|ae.safetensors|vae"
    "https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors|sdxl_vae.safetensors|vae"

    # ═══════════════════════════════════════════════════════════════════
    # ⬆️ UPSCALE MODELS (HuggingFace/GitHub)
    # ═══════════════════════════════════════════════════════════════════
    "https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth|4x-UltraSharp.pth|upscale_models"
    "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth|RealESRGAN_x4plus.pth|upscale_models"
    "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-spatial-upscaler-x2-1.0.safetensors|ltx-2-spatial-upscaler-x2-1.0.safetensors|upscale_models"

    # ═══════════════════════════════════════════════════════════════════
    # 🎮 CONTROLNET (HuggingFace)
    # ═══════════════════════════════════════════════════════════════════
    "https://huggingface.co/thibaud/controlnet-openpose-sdxl-1.0/resolve/main/OpenPoseXL2.safetensors|OpenPoseXL2.safetensors|controlnet"

    # ═══════════════════════════════════════════════════════════════════
    # 🎥 WAN DIFFUSION MODELS - FULL LIBRARY (HuggingFace)
    # ═══════════════════════════════════════════════════════════════════
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_t2v_1.3B_fp16.safetensors|wan2.1_t2v_1.3B_fp16.safetensors|diffusion_models/wan"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors|wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors|diffusion_models/wan"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors|wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors|diffusion_models/wan"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors|wan2.2_ti2v_5B_fp16.safetensors|diffusion_models/wan"

    # ═══════════════════════════════════════════════════════════════════
    # 🎬 LTX-2 DIFFUSION MODEL (HuggingFace) - 19GB
    # ═══════════════════════════════════════════════════════════════════
    "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-dev-fp8.safetensors|ltx-2-19b-dev-fp8.safetensors|diffusion_models/ltx"

    # ═══════════════════════════════════════════════════════════════════
    # 🎞️ ANIMATEDIFF MOTION MODULES (HuggingFace)
    # ═══════════════════════════════════════════════════════════════════
    "https://huggingface.co/guoyww/animatediff/resolve/main/mm_sdxl_v10_beta.ckpt|mm_sdxl_v10_beta.ckpt|animatediff_models"
    "https://huggingface.co/guoyww/animatediff/resolve/main/mm_sd_v15_v2.ckpt|mm_sd_v15_v2.ckpt|animatediff_models"

    # ═══════════════════════════════════════════════════════════════════
    # 🔍 DETECTION MODELS - YOLO & SAM (HuggingFace)
    # ═══════════════════════════════════════════════════════════════════
    "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt|face_yolov8m.pt|detection/yolo"
    "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8n.pt|hand_yolov8n.pt|detection/yolo"
    "https://huggingface.co/spaces/abhishek/StableSAM/resolve/main/sam_vit_b_01ec64.pth|sam_vit_b_01ec64.pth|detection/sam"

    # ═══════════════════════════════════════════════════════════════════
    # 🎞️ RIFE FRAME INTERPOLATION (HuggingFace)
    # ═══════════════════════════════════════════════════════════════════
    "https://huggingface.co/AlexWortworworwortwort/RIFE/resolve/main/rife49.pth|rife49.pth|rife"

    # ═══════════════════════════════════════════════════════════════════
    # ⚡ FLUX MODELS (HuggingFace)
    # ═══════════════════════════════════════════════════════════════════
    "https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/flux1-dev-fp8.safetensors|flux1-dev-fp8.safetensors|diffusion_models/flux"

    # ═══════════════════════════════════════════════════════════════════
    # 🎨 LTX LORAS (Camera Control)
    # ═══════════════════════════════════════════════════════════════════
    "https://huggingface.co/Lightricks/LTX-2-19b-LoRA-Camera-Control-Dolly-Left/resolve/main/ltx-2-19b-lora-camera-control-dolly-left.safetensors|ltx-2-19b-lora-camera-control-dolly-left.safetensors|loras/ltx"
    "https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-distilled-lora-384.safetensors|ltx-2-19b-distilled-lora-384.safetensors|loras/ltx"
)

# --- 5. DOWNLOAD FUNCTION ---
download_file() {
    local URL="$1"
    local FILENAME="$2"
    local SUBDIR="$3"
    local DEST_PATH="${HARVEST_ROOT}/${SUBDIR}/${FILENAME}"

    mkdir -p "$(dirname "$DEST_PATH")"

    log "📥 [$((TOTAL_COUNT+1))] Downloading: $FILENAME"
    log "   📁 Target: $SUBDIR"

    # Build aria2c command with optional Civitai header
    local ARIA_ARGS="-x16 -s16 -k1M --continue=true --max-tries=5 --retry-wait=10 --timeout=300 --connect-timeout=30 --lowest-speed-limit=50K --allow-overwrite=true"

    # Add Civitai header if it's a Civitai URL and token is set
    if [[ "$URL" == *"civitai.com"* ]] && [ -n "${CIVITAI_TOKEN:-}" ]; then
        ARIA_ARGS="$ARIA_ARGS --header='Authorization: Bearer ${CIVITAI_TOKEN}'"
    fi

    # Execute download with timeout wrapper (30 min max per file)
    if timeout 1800 aria2c $ARIA_ARGS -o "$FILENAME" -d "$(dirname "$DEST_PATH")" "$URL" 2>&1 | tee -a "$LOG_FILE"; then
        if [ -f "$DEST_PATH" ]; then
            local SIZE=$(du -h "$DEST_PATH" | cut -f1)
            log "   ✅ Downloaded: $FILENAME ($SIZE)"
            return 0
        fi
    fi

    log "   ❌ FAILED: $FILENAME"
    return 1
}

sync_to_dropbox() {
    local FILENAME="$1"
    local SUBDIR="$2"
    local DEST_PATH="${HARVEST_ROOT}/${SUBDIR}/${FILENAME}"

    if [ -f "$DEST_PATH" ]; then
        log "   📤 Syncing to Dropbox: ${DROPBOX_DEST}/${SUBDIR}/"
        if rclone copy "$DEST_PATH" "${REMOTE_NAME}:${DROPBOX_DEST}/${SUBDIR}" --progress 2>&1 | tee -a "$LOG_FILE"; then
            log "   ✅ Synced: $FILENAME"
            # Clean up local file to save disk space
            rm -f "$DEST_PATH"
            return 0
        else
            log "   ⚠️ Sync failed, keeping local copy"
            return 1
        fi
    fi
    return 1
}

# --- 6. EXECUTION LOOP ---
log ""
log "╔════════════════════════════════════════════════════════════════╗"
log "║  🚜 STARTING HARVEST - ${#HARVEST_QUEUE[@]} files queued              "
log "╚════════════════════════════════════════════════════════════════╝"
log ""

for entry in "${HARVEST_QUEUE[@]}"; do
    IFS="|" read -r URL FILENAME SUBDIR <<< "$entry"
    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    # Download
    if download_file "$URL" "$FILENAME" "$SUBDIR"; then
        # Sync to Dropbox
        if sync_to_dropbox "$FILENAME" "$SUBDIR"; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            FAILED_COUNT=$((FAILED_COUNT + 1))
            echo "${URL}|${FILENAME}|${SUBDIR}|SYNC_FAILED" >> "$FAILED_LOG"
        fi
    else
        FAILED_COUNT=$((FAILED_COUNT + 1))
        echo "${URL}|${FILENAME}|${SUBDIR}|DOWNLOAD_FAILED" >> "$FAILED_LOG"
    fi

    log "   📊 Progress: $SUCCESS_COUNT/$TOTAL_COUNT succeeded, $FAILED_COUNT failed"
    log ""
done

# --- 7. COPY EXISTING PORNMASTER100 CONTENT ---
log ""
log "═══════════════════════════════════════════════════════════════"
log "📦 COPYING EXISTING /pornmaster100 TO NEW STRUCTURE..."
log "═══════════════════════════════════════════════════════════════"

# Check if pornmaster100 exists
if rclone lsd "${REMOTE_NAME}:/pornmaster100" >/dev/null 2>&1; then
    log "📋 Found /pornmaster100, copying to /AI_KINGS_HUB_2026/checkpoints/legacy/"
    mkdir -p "$HARVEST_ROOT/checkpoints/legacy"

    rclone copy "${REMOTE_NAME}:/pornmaster100" "${REMOTE_NAME}:${DROPBOX_DEST}/checkpoints/legacy" \
        --progress \
        --log-file="$LOG_FILE" \
        --log-level=INFO

    if [ $? -eq 0 ]; then
        log "✅ Legacy models copied successfully"
    else
        log "⚠️ Some legacy models may have failed to copy"
    fi
else
    log "ℹ️ /pornmaster100 not found, skipping legacy copy"
fi

# --- 8. FINAL SUMMARY ---
log ""
log "╔════════════════════════════════════════════════════════════════╗"
log "║  🏁 MASTER HARVEST COMPLETE                                    "
log "╠════════════════════════════════════════════════════════════════╣"
log "║  ✅ Succeeded: $SUCCESS_COUNT / $TOTAL_COUNT                           "
log "║  ❌ Failed: $FAILED_COUNT                                              "
log "║  📁 Location: ${REMOTE_NAME}:${DROPBOX_DEST}                   "
log "╚════════════════════════════════════════════════════════════════╝"

if [ $FAILED_COUNT -gt 0 ]; then
    log ""
    log "⚠️ FAILED DOWNLOADS:"
    cat "$FAILED_LOG" | while read line; do
        log "   - $line"
    done
    log ""
    log "💡 To retry failed downloads, check: $FAILED_LOG"
fi

log ""
log "📊 Dropbox structure:"
rclone tree "${REMOTE_NAME}:${DROPBOX_DEST}" --max-depth 2 2>&1 | tee -a "$LOG_FILE" || true

log ""
log "🎉 Harvest complete! Check your Dropbox at: ${DROPBOX_DEST}"
