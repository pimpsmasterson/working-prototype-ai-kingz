---
description: How to use the installed Wan 2.1 and LTX-Video models in ComfyUI
---

# 🎬 Video Kingz - LTX Professional Guide (v2.0)

This guide covers the high-end LTX-2 workflow currently configured in your updated provisioning script.

## 1. Professional Model Breakdown
The new script places models exactly where specialized graphs expect them:

| Model Type | Selection Path | Purpose |
| :--- | :--- | :--- |
| **Foundation** | `checkpoints / ltx-2-19b-dev-fp8` | The highest quality cinematic base. |
| **Fast Preview** | `checkpoints / ltx-2-19b-distilled` | 4-8 step generation for testing. |
| **The Brain** | `text_encoders / gemma_3_12B_it_fp4_mixed` | Gemma 3's advanced prompt comprehension. |
| **The Eyes** | `vae / ltx-2_vae` | Dedicated LTX video decompression. |

## 2. Advanced Control (LoRAs)
You have specialized camera control LoRAs in your `/loras` folder:
- **`ltx-2-19b-lora-camera-control-dolly-left`**: Use this for cinematic tracking shots.
- **`ltx-2-19b-ic-lora-depth-control`**: Use for high-precision motion depth.

## 3. The "Crispy" Finish (Upscaling)
- **Node**: `LatentUpscaleModelLoader`
- **Model**: `ltx-2-spatial-upscaler-x2-1.0`
- **Effect**: This is a dedicated spatial upscaler that doubles your resolution without losing LTX texture.

## 4. Troubleshooting Folder Issues
- **If models are missing**: Your graph might be hard-coded to a specific path.
- **Fix**: Use the **"Refresh"** button in ComfyUI Manager. If they still don't show, manually swap the loader node for a standard `CheckpointLoaderSimple` and point it to the `/checkpoints` folder.

## 5. Optimal Resolution
- **Standard**: 768x512 or 832x480.
- **With Upscaler**: 1280x720 or 1536x864.
