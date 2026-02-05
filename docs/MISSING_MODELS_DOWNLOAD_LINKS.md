# Missing Models - Download Links Verification

## Summary
After auditing Dropbox `/workspace/pornmaster100` against manifest, here are the ACTUALLY missing models (ignoring false positives like markdown headers):

## ✅ FALSE ALARM - Already in Dropbox
These were flagged as "missing from loras" but are actually in checkpoints:
- express iveh_hentai.safetensors (685MB) - IN DROPBOX
- fondled.safetensors (342MB) - IN DROPBOX
- wan_dr34ml4y_all_in_one.safetensors (292MB) - IN DROPBOX
- wan_dr34mjob.safetensors (171MB) - IN DROPBOX
- twerk.safetensors (49MB) - IN DROPBOX

## ❌ ACTUALLY MISSING - Need Links

### 1. ponyRealism_v21MainVAE.safetensors (~320MB)
**Source:** Civitai
**Download Link:** https://civitai.com/api/download/models/105924
**Notes:** PonyRealism v2.1 VAE

### 2. rife426.pth (~200MB)
**Source:** GitHub (RIFE frame interpolation)
**Download Link:** https://github.com/hzwer/Practical-RIFE/releases/download/4.26/flownet-v4.26.pkl
**Notes:** RIFE 4.26 model for frame interpolation

### 3. mm_sdxl_v10_beta.ckpt (~1.8GB)
**Source:** HuggingFace
**Download Link:** https://huggingface.co/guoyww/animatediff/resolve/main/mm_sdxl_v10_beta.ckpt
**Notes:** AnimateDiff SDXL motion module

### 4. wan2.2_remix_fp8.safetensors (~14GB)
**Source:** HuggingFace
**Download Link:** https://huggingface.co/Kijai/WanWan-Diffusion/resolve/main/wan2.2_remix_fp8.safetensors
**Notes:** Wan 2.2 Remix FP8 video model

### 5. umt5_xxl_fp8_e4m3fn.safetensors (~3GB)
**Source:** HuggingFace
**Download Link:** https://huggingface.co/SG161222/LTX-2/resolve/main/text_encoder_2/umt5_xxl_fp8_e4m3fn.safetensors
**Notes:** UMT5 text encoder for LTX-2
**Alternative:** umt5_xxl_fp8_e4m3fn_scaled.safetensors (6.4GB) ALREADY IN DROPBOX

### 6. wan2.1_vae.safetensors (~320MB)
**Source:** HuggingFace
**Download Link:** https://huggingface.co/Kijai/WanWan-Diffusion/resolve/main/wan2.1_vae.safetensors
**Notes:** Wan 2.1 VAE
**Alternative:** wan_2.1_vae.safetensors (242MB) ALREADY IN DROPBOX (different naming)

### 7. wan2.2_vae.safetensors (~320MB)
**Source:** Already in Dropbox!
**Path:** /workspace/pornmaster100/ComfyUI/models/vae/wan2.2_vae.safetensors (1.3GB)
**Status:** ✅ FOUND

## 🎯 PRIORITY ACTION ITEMS

### HIGH PRIORITY (Required for full functionality):
1. mm_sdxl_v10_beta.ckpt - AnimateDiff SDXL
2. rife426.pth - Frame interpolation

### MEDIUM PRIORITY (Nice to have):
3. ponyRealism_v21MainVAE.safetensors - Better quality for Pony models
4. wan2.2_remix_fp8.safetensors - Latest Wan video model

### LOW PRIORITY (Alternatives exist):
5. umt5_xxl_fp8_e4m3fn.safetensors - Have scaled version
6. wan2.1_vae.safetensors - Have wan_2.1_vae.safetensors

## Download Commands (for manual verification):

```bash
# 1. PonyRealism VAE
wget -O ponyRealism_v21MainVAE.safetensors \
  "https://civitai.com/api/download/models/105924"

# 2. RIFE 4.26
wget -O rife426.pth \
  "https://github.com/hzwer/Practical-RIFE/releases/download/4.26/flownet-v4.26.pkl"

# 3. AnimateDiff SDXL
wget -O mm_sdxl_v10_beta.ckpt \
  "https://huggingface.co/guoyww/animatediff/resolve/main/mm_sdxl_v10_beta.ckpt"

# 4. Wan 2.2 Remix
wget -O wan2.2_remix_fp8.safetensors \
  "https://huggingface.co/Kijai/WanWan-Diffusion/resolve/main/wan2.2_remix_fp8.safetensors"
```

## ✅ MODELS IN DROPBOX BUT NOT IN MANIFEST (Need to ADD to manifest):

These are in Dropbox but missing from COMPLETE_SOFTWARE_MANIFEST.md:

1. **ae.safetensors** (319.8MB) - LTX VAE
2. **gemma_3_12B_it_fp4_mixed.safetensors** (9GB x2) - Text encoder
3. **umt5_xxl_fp8_e4m3fn_scaled.safetensors** (6.4GB) - Scaled text encoder
4. **flux1-krea-dev_fp8_scaled.safetensors** (11.3GB x2) - FLUX Krea variant
5. **sd_xl_base_1.0.1.safetensors** (6.6GB) - SDXL base v1.0.1
6. **sd_xl_refiner_1.0.1.safetensors** (5.8GB) - SDXL refiner v1.0.1
7. **wan2.2_ti2v_5B_fp16.safetensors** (9.5GB x2) - Wan text-to-image-to-video
8. **wan_2.1_vae.safetensors** (242MB) - Wan 2.1 VAE (different from wan2.1_vae)
9. **sd15_resizer.pt** / **sdxl_resizer.pt** (12MB each) - Efficiency nodes resizers
10. **encoded_silence.safetensors** (1.6MB) - WanVideoWrapper silence encoding

## CONCLUSION

**Real Missing Count:** 4-6 critical models
**False Positives:** 40+ (mostly manifest markdown/duplicates)
**Need to Add to Manifest:** 10+ models currently in Dropbox

**Next Steps:**
1. Add download links for 4-6 missing models to provision script
2. Update COMPLETE_SOFTWARE_MANIFEST.md with 10+ models in Dropbox
3. Fix manifest parser to exclude markdown table headers
