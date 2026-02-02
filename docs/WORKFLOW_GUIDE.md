# ComfyUI Workflow Guide - AI Kings NSFW Production System

**Version:** 2.0
**Last Updated:** 2026-02-01
**Total Workflows:** 23 specialized NSFW workflows

---

## Table of Contents

1. [Overview](#overview)
2. [Workflow Categories](#workflow-categories)
3. [Advanced LoRA Stacking Techniques](#advanced-lora-stacking-techniques)
4. [Quality Enhancement Chains](#quality-enhancement-chains)
5. [Prompting Strategies](#prompting-strategies)
6. [Model Selection Guide](#model-selection-guide)
7. [Troubleshooting](#troubleshooting)
8. [Performance Optimization](#performance-optimization)
9. [Workflow Reference](#workflow-reference)

---

## Overview

This production system includes 23 highly-optimized NSFW workflows designed for maximum quality output across different content types, themes, and technical requirements. All workflows are located in `scripts/workflows/` and are automatically installed during provisioning.

### System Specifications
- **Total Models:** 100GB+ (checkpoints, LoRAs, VAEs, text encoders)
- **Recommended VRAM:** 24GB (RTX 4090, RTX 3090)
- **Minimum VRAM:** 16GB with system RAM offloading
- **Target Platform:** Vast.ai GPU instances with high-speed storage

### Key Features
- Multi-tier LoRA stacking (Anatomy → Fetish → Style)
- Advanced camera control (LTX-2 dolly/pan/zoom)
- Lightning-fast generation (4-step LoRAs for Wan 2.2)
- Quality enhancement chains (FaceDetailer → Upscaler)
- Comprehensive fetish theme support

---

## Workflow Categories

### 1. **Image Generation** (7 workflows)
High-quality still image generation with various models and themes.

**Workflows:**
- `nsfw_ultimate_image_workflow.json` - Universal SDXL image generator
- `nsfw_sdxl_image_workflow.json` - Standard SDXL workflow
- `nsfw_sdxl_realism_hyperdump_cunnilingus_master_workflow.json` - Realism + fetish stacking
- `nsfw_lora_image_workflow.json` - LoRA-focused image generation
- `nsfw_pornmaster_workflow.json` - PornMaster Pro checkpoint
- `nsfw_controlnet_pose_workflow.json` - Pose-controlled generation
- `nsfw_3d_generation_workflow.json` - 3D model generation

**Best For:** High-resolution stills, character design, scene composition

---

### 2. **Video Generation** (10 workflows)
Text-to-video and image-to-video with motion control.

**Workflows:**
- `nsfw_wan22_master_video_workflow.json` - **⭐ PRIMARY** - Wan 2.2 T2V master
- `nsfw_wan21_video_workflow.json` - Wan 2.1 T2V (lighter, faster)
- `nsfw_wan25_preview_video_workflow.json` - Quick preview generation
- `nsfw_video_workflow.json` - General video generation
- `nsfw_ultimate_video_workflow.json` - Universal video generator
- `nsfw_cinema_production_workflow.json` - Cinematic quality video
- `nsfw_ltx_video_workflow.json` - LTX-2 standard video
- `nsfw_ltx_camera_control_hyperdump_scat_video_workflow.json` - **⭐ ENHANCED** - LTX camera control
- `nsfw_realistic_furry_video_workflow.json` - Furry/anthro video (EXCLUDED per user request)
- `nsfw_wan22_dr34ml4y_dr34mjob_fetish_video_master_workflow.json` - Wan + custom LoRAs

**Best For:** Animated sequences, camera movement, dynamic content

---

### 3. **Fetish-Themed** (8 workflows)
Specialized workflows for specific fetish content with advanced LoRA stacking.

**Workflows:**
- `nsfw_pony_hyperdump_soiling_turtleheading_scat_master_workflow.json` - **⭐ SCAT MASTER** - Multi-LoRA scat
- `nsfw_sdxl_soiling_turtleheading_poopsquat_scat_master_workflow.json` - SDXL scat variation
- `nsfw_pony_hyperdump_cunnilingus_sexmachine_dreamlay_dreamjob_fetish_master_workflow.json` - **⭐ ULTIMATE STACK** - 6+ LoRAs
- `nsfw_pony_multiple_fetish_stacked_master_workflow.json` - Multi-fetish combination
- `nsfw_sdxl_fetish_workflow.json` - SDXL fetish base
- `nsfw_ltx_camera_control_hyperdump_scat_video_workflow.json` - Video scat with camera control
- `nsfw_wan22_dr34ml4y_dr34mjob_fetish_video_master_workflow.json` - Wan video fetish

**Best For:** Explicit themed content, multi-LoRA combinations, extreme customization

---

### 4. **Advanced/Experimental** (3 workflows)
Cutting-edge techniques and experimental features.

**Workflows:**
- `nsfw_sdxl_triposr_3d_generation_workflow.json` - 3D mesh from 2D image (TripoSR)
- `nsfw_3d_generation_workflow.json` - 3D asset generation
- `nsfw_cinema_production_workflow.json` - Film-grade output

**Best For:** Experimental features, unique outputs, technical exploration

---

## Advanced LoRA Stacking Techniques

### The 3-Tier Stack System

Research shows optimal LoRA stacking follows this hierarchy:

```
Tier 1: ANATOMY (0.6-0.8) → Foundation
   ↓
Tier 2: FETISH/THEME (0.8-1.2) → Primary content
   ↓
Tier 3: STYLE (0.5-0.7) → Artistic polish
```

#### **Tier 1: Anatomy LoRAs** (0.6-0.8 weight)
**Purpose:** Establish correct body structure, proportions, poses

**Examples:**
- General anatomy LoRAs (when available)
- Pose-specific LoRAs
- Body type LoRAs (curvy, athletic, etc.)

**Weight Guide:**
- 0.6 = Subtle anatomical guidance
- 0.7 = **Recommended** for most cases
- 0.8 = Strong anatomical enforcement

**Tips:**
- Always apply first in stack
- Use lower weights (0.6) if checkpoint already has good anatomy
- Increase to 0.8 if getting distorted limbs/hands

#### **Tier 2: Fetish/Theme LoRAs** (0.8-1.2 weight)
**Purpose:** Apply specific content themes, actions, or fetish elements

**Examples from Inventory:**
- **Scat Theme:** HyperDump (1.0-1.2), Soiling-V1 (0.9-1.1), Turtleheading-V1 (0.8-1.0), Poop_SquatV3 (0.9-1.1)
- **Action:** Cunnilingus_gesture (0.8-1.0), Sex_machine (0.8-1.1)
- **Specialized:** Fondled (0.8-1.0), dr34ml4y/dr34mjob (0.8-1.0)

**Weight Guide:**
- 0.8 = Subtle theme application
- 1.0 = **Recommended** for balanced fetish emphasis
- 1.2 = Strong/extreme fetish focus
- 1.5+ = Maximum intensity (use cautiously, may cause artifacts)

**Tips:**
- Stack multiple fetish LoRAs (e.g., HyperDump + Soiling for layered effect)
- Use 1.0-1.2 for primary fetish, 0.8-0.9 for secondary
- If stacking 3+ fetish LoRAs, reduce each by 0.1-0.2

#### **Tier 3: Style LoRAs** (0.5-0.7 weight)
**Purpose:** Artistic enhancement, rendering style, aesthetic polish

**Examples:**
- Rajii-Artist-Style-V2 (0.6 for illustrated look)
- Lighting/atmosphere LoRAs
- Art style LoRAs (anime, realistic, etc.)

**Weight Guide:**
- 0.5 = Gentle stylistic hint
- 0.6 = **Recommended** for noticeable style
- 0.7 = Strong style application

**Tips:**
- Apply last in stack to avoid interfering with content
- Use lower weights (0.5-0.6) if checkpoint has strong inherent style
- Can skip if happy with base checkpoint aesthetic

### Example Stacking Configurations

#### **Configuration 1: Pony Scat Master (6-LoRA Stack)**
```
Checkpoint: pony_realism_v2.2.safetensors
VAE: ponyRealism_v21MainVAE.safetensors

Stack:
1. [Anatomy Tier] - (If available) General anatomy LoRA @ 0.7
2. [Fetish Tier 1] HyperDump.safetensors @ 1.2 (primary scat)
3. [Fetish Tier 2] Soiling-V1.safetensors @ 1.0 (layered effect)
4. [Fetish Tier 3] Turtleheading-V1.safetensors @ 0.9 (additional detail)
5. [Action] Poop_SquatV3.safetensors @ 0.9 (pose/action)
6. [Style Tier] Rajii-Artist-Style-V2.safetensors @ 0.6 (artistic polish)
```

**Total LoRA Influence:** 5.7 combined weight
**Expected Output:** Extreme scat-themed content with realistic anatomy, layered fetish details, and illustrated style
**VRAM:** ~18-20GB

#### **Configuration 2: SDXL Realism Fetish (3-LoRA Stack)**
```
Checkpoint: pornmasterPro_noobV6.safetensors or pony_realism_v2.2.safetensors
VAE: sdxl_vae.safetensors

Stack:
1. [Fetish Tier 1] HyperDump.safetensors @ 1.0 (primary theme)
2. [Action] Cunnilingus_gesture.safetensors @ 0.8 (action)
3. [Style Tier] (Optional) Style LoRA @ 0.5

```

**Total LoRA Influence:** 2.3 combined weight
**Expected Output:** Balanced fetish content with realistic rendering
**VRAM:** ~14-16GB

#### **Configuration 3: Wan 2.2 Lightning Video (2-LoRA Stack)**
```
Checkpoint: wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors
Text Encoder: umt5_xxl_fp8_e4m3fn.safetensors

Stack:
1. [Speed Tier] wan2.2_t2v_lightx2v_4steps_lora_v1.1_high_noise.safetensors @ 0.9 (4-step generation)
2. [Fetish Tier] Fondled.safetensors @ 0.8 (theme)
```

**Total LoRA Influence:** 1.7 combined weight
**Expected Output:** Fast video generation (4 steps instead of 25) with fetish theme
**VRAM:** ~22GB
**Speed:** 2-3 minutes for 24 frames (vs. 8-10 minutes without Lightning LoRA)

### Common Stacking Mistakes

❌ **WRONG: Style-First Stacking**
```
1. Style LoRA @ 0.7
2. Fetish LoRA @ 1.0
3. Anatomy LoRA @ 0.6
```
**Problem:** Style interferes with content generation, anatomy corrections fail

✅ **CORRECT: Anatomy → Fetish → Style**
```
1. Anatomy LoRA @ 0.7
2. Fetish LoRA @ 1.0
3. Style LoRA @ 0.6
```

❌ **WRONG: Over-Weighting Multiple LoRAs**
```
1. HyperDump @ 1.5
2. Soiling-V1 @ 1.4
3. Turtleheading-V1 @ 1.3
```
**Total:** 4.2 weight → Causes artifacts, collapsed features, nonsensical output

✅ **CORRECT: Balanced Multi-LoRA**
```
1. HyperDump @ 1.1 (primary)
2. Soiling-V1 @ 0.9 (secondary)
3. Turtleheading-V1 @ 0.8 (accent)
```
**Total:** 2.8 weight → Layered effect without distortion

---

## Quality Enhancement Chains

### Post-Processing Pipeline

For maximum quality, apply these nodes AFTER initial generation:

```
Base Generation
    ↓
FaceDetailer (denoise 0.35-0.45)
    ↓
ADetailer - Hands (denoise 0.30-0.40)
    ↓
ADetailer - Body (denoise 0.25-0.35)
    ↓
UltimateSDUpscale (2x or 4x)
    ↓
Frame Interpolation (video only, RIFE 2x)
    ↓
Final Output
```

#### **1. FaceDetailer (Impact-Pack)**
**Purpose:** Fix facial anatomy, expressions, eyes

**Settings:**
- Denoise: 0.35-0.45 (higher = more changes)
- Dilation: 10-20 pixels (expand mask slightly)
- Model: face_yolov8m.pt

**When to Use:** Always use for portraits, close-ups

#### **2. ADetailer - Hands**
**Purpose:** Fix common hand artifacts (extra fingers, fused digits)

**Settings:**
- Denoise: 0.30-0.40
- Prompt: "(perfect hands:1.4), (five fingers:1.3)"
- Model: hand_yolov8n.pt

**When to Use:** If hands visible in generation

#### **3. UltimateSDUpscale**
**Purpose:** Increase resolution while maintaining detail

**Models:**
- 4x-UltraSharp.pth (sharp, detailed) - **Recommended**
- RealESRGAN_x4plus.pth (smooth, realistic)
- ltx-2-spatial-upscaler-x2-1.0.safetensors (LTX video only)

**Settings:**
- Upscale Factor: 2x (1024→2048) or 4x (1024→4096)
- Tile Size: 512 (VRAM-friendly)
- Denoise: 0.2-0.3 (add detail without changing content)

**When to Use:** For print-quality outputs, high-res displays

#### **4. RIFE Frame Interpolation (Video Only)**
**Purpose:** Double frame rate for ultra-smooth motion

**Models:**
- rife426.pth (latest, best quality)

**Settings:**
- Multiplier: 2x (24 FPS → 48 FPS)
- Ensemble: True (slower but smoother)

**When to Use:** For cinematic video, slow-motion effects

---

## Prompting Strategies

### Prompt Structure Template

```
[Quality Tags] + [Subject] + [Action/Pose] + [Environment] + [Lighting] + [Style] + [Technical Modifiers]
```

#### **Quality Tags** (Always First)
```
score_9, score_8_up, rating_explicit, masterpiece, best quality, high resolution
```

**Why:** Triggers quality filters in SDXL/Pony models
**When to Adjust:** Use `score_7` instead of `score_9` for more experimental/creative outputs

#### **Subject Description**
```
1girl, full body, voluptuous curves, detailed anatomy, sweat-glistened skin
```

**Advanced Techniques:**
- Use weights: `(voluptuous curves:1.3)` for emphasis
- Stack details: `detailed face, detailed hands, detailed body`
- Specify count: `1girl` (not "a girl") for Pony/SDXL

#### **Action/Pose**
```
defecation, squatting pose, intense expression, explicit act
```

**Fetish-Specific Examples:**
- Scat: `hyper dump, defecation, soiling, visible mess, turtleheading`
- Action: `cunnilingus gesture, sex machine, fondled`
- Video: `smooth motion, fluid movement, natural jiggle`

#### **Environment**
```
bathroom interior, tiled floor, soft lighting, intimate setting
```

**Tips:**
- Keep simple for fetish focus
- Add `cinematic` for video workflows
- Use `studio lighting` for controlled look

#### **Lighting**
```
soft lighting, rim light, subsurface scattering
```

**Advanced:**
- `(subsurface scattering:1.5)` for realistic skin
- `(golden hour lighting:1.3)` for warm tones
- `(dramatic shadows:1.2)` for contrast

#### **Style Modifiers**
```
realistic texture, 8K, highly detailed, photorealistic
```

**Model-Specific:**
- **Pony:** Add `pony diffusion style` or `anime realistic`
- **SDXL:** Add `digital painting` or `photographic`
- **Wan:** Add `mo-e motion, natural movement`

#### **Technical Modifiers** (Advanced)
```
perfect anatomy, five fingers, detailed genitals, skin pores, fabric texture
```

### Negative Prompting

#### **Universal Negatives** (Every Workflow)
```
score_6, score_5, score_4, low quality, worst quality, lowres, blurry, watermark, text, logo, bad anatomy, deformed, extra limbs, fused fingers, poorly drawn
```

#### **Fetish-Specific Negatives**
```
clean, sanitary, censored, mosaic, clothed (if nude desired)
```

#### **Video Negatives**
```
static, frozen, still image, no motion, jerky movement
```

#### **Advanced Negatives**
Use strong weights for critical issues:
```
(deformed anatomy:1.5), (extra fingers:1.6), (bad hands:1.5), (distorted genitals:1.5)
```

### Example Prompts

#### **SDXL Scat Image (Pony Realism)**
```
POSITIVE:
score_9, score_8_up, rating_explicit, masterpiece, best quality, high resolution, 1girl, full body, voluptuous curves, (detailed anatomy:1.4), (sweat-glistened skin:1.3), (subsurface scattering:1.5), defecation, hyper dump, squatting pose, (intense expression:1.3), (visible mess:1.4), bathroom interior, soft lighting, realistic texture, 8K, photorealistic, perfect anatomy

NEGATIVE:
score_6, score_5, low quality, worst quality, blurry, watermark, bad anatomy, (deformed:1.5), (extra limbs:1.5), (fused fingers:1.6), clean, sanitary, censored, clothed
```

#### **Wan 2.2 Fetish Video**
```
POSITIVE:
score_9, score_8_up, rating_explicit, masterpiece, best quality, cinematic, 1girl, full body, realistic texture, nsfw, defecation, smooth motion, (natural movement:1.3), (mo-e motion:1.4), detailed anatomy, fondled, intimate scene

NEGATIVE:
score_6, score_5, low quality, worst quality, watermark, static, frozen, still image, jerky movement, clean
```

#### **LTX-2 Camera Control**
```
POSITIVE:
score_9, score_8_up, rating_explicit, masterpiece, best quality, cinematic, 1girl, full body, realistic texture, nsfw, scat, hyper dump, (camera dolly left:1.3), (smooth camera movement:1.4), explicit sex, detailed anatomy, (mo-e motion:1.3)

NEGATIVE:
score_6, score_5, low quality, worst quality, watermark, (static camera:1.5), frozen, clean, sanitary
```

---

## Model Selection Guide

### Checkpoints

| Model | Best For | Style | VRAM | Speed |
|-------|----------|-------|------|-------|
| **pony_realism_v2.2** | Fetish stacking, LoRA compatibility | Semi-realistic pony | 18GB | Medium |
| **pornmasterPro_noobV6** | NSFW realism, explicit content | Photorealistic | 20GB | Medium |
| **dreamshaper_8** | General NSFW, artistic | Artistic realistic | 14GB | Fast |
| **wai_illustrious_sdxl** | Illustrated style, anime-adjacent | Illustrative | 16GB | Medium |
| **expressiveh_hentai** | Hentai style, exaggerated features | Anime/hentai | 12GB | Fast |
| **wan2.2_t2v_high_noise_14B** | High-quality video, detailed motion | Video realistic | 22GB | Slow |
| **wan2.2_t2v_low_noise_14B** | Smooth video, clean output | Video smooth | 22GB | Slow |
| **wan2.1_t2v_1.3B** | Fast video preview, testing | Video light | 16GB | Fast |
| **ltx-2-19b-dev-fp8** | Camera control video, cinematic | Video cinematic | 24GB | Medium |

### LoRA Selection Matrix

#### **Fetish Theme LoRAs**
| LoRA | Theme | Weight | Stack Priority |
|------|-------|--------|----------------|
| **HyperDump** | Extreme scat, hyper defecation | 1.0-1.2 | Primary |
| **Soiling-V1** | Soiling, mess, accidents | 0.9-1.1 | Secondary |
| **Turtleheading-V1** | Turtleheading, partial exposure | 0.8-1.0 | Accent |
| **Poop_SquatV3** | Squatting pose, defecation pose | 0.9-1.1 | Action |
| **Cunnilingus_gesture** | Oral sex gesture | 0.8-1.0 | Action |
| **Sex_machine** | Sex machine, mechanical | 0.8-1.1 | Theme |
| **Fondled** | Touching, fondling actions | 0.8-1.0 | Action |

#### **Video Enhancement LoRAs**
| LoRA | Purpose | Weight | Compatible With |
|------|---------|--------|-----------------|
| **wan2.2_t2v_lightx2v_4steps_high_noise** | 4-step T2V (high noise) | 0.9 | Wan 2.2 high_noise |
| **wan2.2_t2v_lightx2v_4steps_low_noise** | 4-step T2V (low noise) | 0.9 | Wan 2.2 low_noise |
| **wan2.2_i2v_lightx2v_4steps_high_noise** | 4-step I2V (high noise) | 0.9 | Wan 2.2 high_noise |
| **wan2.2_i2v_lightx2v_4steps_low_noise** | 4-step I2V (low noise) | 0.9 | Wan 2.2 low_noise |
| **ltx-2-19b-lora-camera-control-dolly-left** | Dolly-left camera movement | 0.8 | LTX-2 |

#### **Style LoRAs**
| LoRA | Style | Weight | Best With |
|------|-------|--------|-----------|
| **Rajii-Artist-Style-V2** | Illustrated, artistic | 0.6 | Pony, SDXL |

### VAE Selection

| VAE | Purpose | Compatible With | Quality Impact |
|-----|---------|-----------------|----------------|
| **sdxl_vae** | Standard SDXL | SDXL checkpoints | High (color accuracy) |
| **ponyRealism_v21MainVAE** | Pony-specific | Pony checkpoints | Critical (use with Pony) |
| **wan2.1_vae** | Wan 2.1 video | Wan 2.1 models | Required |
| **wan2.2_vae** | Wan 2.2 video | Wan 2.2 models | Required |
| **lumina_ae** | Advanced encoding | Experimental | Experimental |

---

## Troubleshooting

### Common Issues & Solutions

#### **Issue: Blurry/Low-Quality Output**
**Symptoms:** Output lacks detail, appears soft or blurry

**Solutions:**
1. Increase sampling steps (25 → 30-40)
2. Raise CFG scale (+1-2 points)
3. Use correct VAE for checkpoint
4. Add `(highly detailed:1.3), (sharp focus:1.2)` to positive prompt
5. Apply UltimateSDUpscale post-processing

#### **Issue: Anatomy Distortions (Extra Limbs, Fused Parts)**
**Symptoms:** Extra fingers, fused hands, distorted faces

**Solutions:**
1. Lower ALL LoRA weights by 0.1-0.2
2. Add `(perfect anatomy:1.4), (five fingers:1.3)` to positive
3. Add `(bad anatomy:1.5), (extra limbs:1.5)` to negative
4. Use FaceDetailer and ADetailer post-processing
5. Reduce number of stacked LoRAs (max 4-5 for stability)

#### **Issue: Weak Fetish Theme**
**Symptoms:** Content doesn't match fetish LoRA theme

**Solutions:**
1. Increase fetish LoRA weight (→ 1.0-1.2)
2. Add explicit theme keywords to prompt with weights: `(hyper dump:1.4)`
3. Ensure LoRA is in Tier 2 position (after anatomy, before style)
4. Check LoRA filename matches installed file
5. Stack multiple related LoRAs (e.g., HyperDump + Soiling)

#### **Issue: Video Stuttering/Jerky Motion**
**Symptoms:** Video has choppy motion, frame skips

**Solutions:**
1. Increase frame count (49 → 81 or 97)
2. Lower CFG scale (→ 5-6 for Wan)
3. Use Lightning LoRAs for smoother 4-step generation
4. Apply RIFE frame interpolation post-processing (2x FPS)
5. Check `(smooth motion:1.3), (fluid movement:1.2)` in prompt

#### **Issue: Out of Memory (OOM)**
**Symptoms:** Generation fails with CUDA OOM error

**Solutions:**
1. Reduce resolution (1024x1024 → 832x832)
2. Enable tiled VAE (if available)
3. Reduce batch size to 1
4. Use FP8 quantized models (already enabled for Wan/LTX)
5. Offload models to CPU when not in use
6. Close other applications
7. Reduce frame count (video) (81 → 49 or 33)

#### **Issue: Camera Not Moving (LTX-2)**
**Symptoms:** Static camera despite camera control LoRA

**Solutions:**
1. Increase camera LoRA weight (0.8 → 0.9-1.0)
2. Add camera keywords to prompt: `(camera dolly left:1.3), (smooth camera movement:1.4)`
3. Verify camera LoRA loaded before other LoRAs
4. Check using correct camera LoRA filename
5. Ensure sufficient frame count (min 49 frames for visible movement)

---

## Performance Optimization

### Speed Optimizations

#### **For Fastest Generation:**
1. Use Lightning LoRAs (Wan 2.2 4-step)
   - Reduce steps from 25 → 4-6
   - 3-4x speed boost
   - Minor quality loss (<10%)

2. Lower resolution
   - 1024x1024 → 640x832 (2x faster)
   - Upscale later if needed

3. Use FP8 models
   - Already enabled for Wan 2.2, LTX-2
   - ~30% speed boost vs FP16

4. Reduce frame count (video)
   - 81 frames → 49 frames (40% faster)
   - Use RIFE interpolation to restore smoothness

#### **For Best Quality:**
1. Increase sampling steps (25 → 35-45)
2. Use higher resolution (1024 → 1536 or 2048)
3. Apply full enhancement chain (FaceDetailer → Upscaler)
4. Use non-quantized models (FP16 instead of FP8)
5. Higher CFG (7 → 8-9)

#### **Balanced Settings (Recommended):**
- Steps: 25-30
- Resolution: 1024x1024
- CFG: 7.0
- FP8 models
- 49-81 frames (video)
- Selective post-processing (FaceDetailer only)

### VRAM Management

| Configuration | VRAM Usage | Recommendation |
|---------------|------------|----------------|
| SDXL image, no LoRAs | ~10-12GB | Use on 16GB+ cards |
| SDXL + 3 LoRAs + Upscaler | ~16-18GB | Use on 24GB cards |
| Wan 2.2 video (49 frames) | ~20-22GB | Requires 24GB+ |
| LTX-2 video (49 frames) | ~22-24GB | Requires 24GB+ |
| Full enhancement chain | +4-6GB | Plan accordingly |

**Tips:**
- Monitor VRAM with `nvidia-smi`
- Enable CPU offloading in ComfyUI settings
- Reduce batch size if hitting limits
- Use tiled processing for upscaling

---

## Workflow Reference

### Quick Selection Guide

**I want to generate...**

| Desired Output | Recommended Workflow | Time Est. |
|----------------|----------------------|-----------|
| **High-quality NSFW still image** | `nsfw_ultimate_image_workflow.json` | 2-3 min |
| **Scat-themed image with multiple LoRAs** | `nsfw_pony_hyperdump_soiling_turtleheading_scat_master_workflow.json` | 3-4 min |
| **Realistic NSFW portrait** | `nsfw_pornmaster_workflow.json` | 2-3 min |
| **Pose-controlled NSFW** | `nsfw_controlnet_pose_workflow.json` | 3-5 min |
| **Fast video preview** | `nsfw_wan25_preview_video_workflow.json` | 3-5 min |
| **High-quality T2V** | `nsfw_wan22_master_video_workflow.json` | 8-12 min |
| **Video with camera movement** | `nsfw_ltx_camera_control_hyperdump_scat_video_workflow.json` | 5-8 min |
| **Scat video with custom LoRAs** | `nsfw_wan22_dr34ml4y_dr34mjob_fetish_video_master_workflow.json` | 8-12 min |
| **Extreme multi-fetish content** | `nsfw_pony_hyperdump_cunnilingus_sexmachine_dreamlay_dreamjob_fetish_master_workflow.json` | 4-6 min |
| **Cinematic quality video** | `nsfw_cinema_production_workflow.json` | 12-20 min |
| **3D model from 2D** | `nsfw_sdxl_triposr_3d_generation_workflow.json` | 5-10 min |

### Workflow Naming Convention

All workflows follow this pattern:
```
nsfw_[model-type]_[features]_[theme]_workflow.json
```

Examples:
- `nsfw` = NSFW content flag
- `sdxl` / `pony` / `wan22` / `ltx` = Model type
- `hyperdump` / `soiling` / `cunnilingus` = Theme/LoRA
- `master` = Advanced multi-LoRA stack
- `workflow.json` = ComfyUI workflow file

---

## Appendix: Enhanced Workflow Template

When adding metadata to workflows, use this template:

```json
{
  "metadata": {
    "title": "Workflow Name",
    "description": "What this workflow does, when to use it, and expected outcomes",
    "model_requirements": {
      "checkpoint": "model_name.safetensors (description)",
      "text_encoder": "encoder_name.safetensors (optional)",
      "loras": [
        "lora1.safetensors (weight X.X) - Purpose",
        "lora2.safetensors (weight X.X) - Purpose"
      ],
      "vae": "vae_name.safetensors"
    },
    "quality_settings": {
      "resolution": "WxH, details",
      "steps": "X-Y (guidance)",
      "cfg": "X.X (guidance)",
      "sampler": "sampler_name (why)",
      "estimated_time": "X-Y minutes on GPU type"
    },
    "lora_stack_guide": {
      "lora_name": {
        "purpose": "What it does",
        "weight_recommended": 0.0,
        "weight_range": "min-max",
        "tips": "Usage tips"
      }
    },
    "prompting_tips": {
      "positive_structure": "Template",
      "positive_boosters": ["boost1", "boost2"],
      "negative_essentials": ["neg1", "neg2"]
    },
    "workflow_flow": {
      "step_1": "Description",
      "step_2": "Description"
    },
    "expected_output": {
      "format": "Format details",
      "quality": "Quality description"
    },
    "vram_requirements": {
      "minimum": "XGB",
      "recommended": "XGB"
    },
    "troubleshooting": {
      "issue_name": "Solution"
    }
  }
}
```

---

## Support & Further Resources

**Model Documentation:** See `docs/installed_assets.md` for complete model inventory

**Provisioning:** See `PROVISION_README.md` for setup/installation

**System Status:** See `docs/CURRENT_STATUS_2026-01-26.md` for latest updates

**Issues:** Report problems via GitHub issues or contact administrator

---

**End of Workflow Guide v2.0**
