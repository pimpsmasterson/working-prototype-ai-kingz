# 👑 AI KINGS - COMPLETE SOFTWARE & ASSET MANIFEST
**Version:** 3.0  
**Last Updated:** 2026-02-04  
**Purpose:** Definitive inventory of ALL software, models, dependencies, and links used in our ComfyUI instances

---

## 📋 TABLE OF CONTENTS

1. [System Requirements](#system-requirements)
2. [Operating System Packages](#operating-system-packages)
3. [Python Environment](#python-environment)
4. [Core Software](#core-software)
5. [ComfyUI Extensions](#comfyui-extensions)
6. [AI Models - Checkpoints](#ai-models---checkpoints)
7. [AI Models - LoRAs](#ai-models---loras)
8. [AI Models - Video (Wan)](#ai-models---video-wan)
9. [AI Models - Video (LTX-2)](#ai-models---video-ltx-2)
10. [AI Models - FLUX](#ai-models---flux)
11. [AI Models - VAEs](#ai-models---vaes)
12. [AI Models - Text Encoders](#ai-models---text-encoders)
13. [AI Models - AnimateDiff](#ai-models---animatediff)
14. [AI Models - Upscalers](#ai-models---upscalers)
15. [AI Models - ControlNet](#ai-models---controlnet)
16. [AI Models - Detection Models](#ai-models---detection-models)
17. [AI Models - Frame Interpolation](#ai-models---frame-interpolation)
18. [Download Sources](#download-sources)
19. [Environment Variables](#environment-variables)
20. [Installation Size Summary](#installation-size-summary)

---

## 🖥️ SYSTEM REQUIREMENTS

### Minimum Requirements
- **Disk Space:** 200GB minimum (400GB recommended)
- **RAM:** 16GB minimum (32GB+ recommended)
- **GPU:** NVIDIA GPU with 8GB+ VRAM
- **CUDA:** 11.8 or higher (12.4 recommended)
- **Network:** 100 Mbps+ (for model downloads)

### Supported Operating Systems
- **Primary:** Ubuntu 22.04 LTS
- **Supported:** Ubuntu 24.04 LTS
- **Compatibility:** Debian-based Linux distributions

---

## 📦 OPERATING SYSTEM PACKAGES

### APT Packages (Installed via apt-get)

| Package | Purpose | Category |
|---------|---------|----------|
| `unrar` | Archive extraction | Utilities |
| `p7zip-full` | 7z archive support | Utilities |
| `unzip` | ZIP archive extraction | Utilities |
| `ffmpeg` | Video/audio processing | Media |
| `libgl1` | OpenGL library | Graphics |
| `git-lfs` | Git Large File Storage | Version Control |
| `file` | File type detection | Utilities |
| `aria2` | Multi-connection downloader | Network |
| `curl` | HTTP client | Network |
| `python3-pip` | Python package manager | Python |
| `python3-dev` | Python development headers | Python |
| `python3-venv` | Python virtual environments | Python |
| `build-essential` | C/C++ compilation tools | Development |
| `libssl-dev` | SSL development libraries | Security |
| `libffi-dev` | Foreign Function Interface | Development |
| `libglib2.0-0` | GLib library | System |
| `libfreetype-dev` | FreeType font engine | Graphics |
| `libjpeg-dev` | JPEG image library | Graphics |
| `libpng-dev` | PNG image library | Graphics |
| `libtiff-dev` | TIFF image library | Graphics |

---

## 🐍 PYTHON ENVIRONMENT

### Python Version
- **Version:** Python 3.11 or 3.12
- **Virtual Environment:** `/venv/main` or `${WORKSPACE}/venv`

### Core Python Packages

| Package | Version | Purpose |
|---------|---------|---------|
| `torch` | 2.5.1+cu124 | PyTorch deep learning framework |
| `torchvision` | 0.20.1+cu124 | Computer vision for PyTorch |
| `torchaudio` | 2.5.1+cu124 | Audio processing for PyTorch |
| `transformers` | 4.36.0 | Hugging Face transformers |
| `accelerate` | Latest | Training acceleration |
| `safetensors` | Latest | Safe tensor serialization |
| `einops` | Latest | Tensor operations |
| `opencv-python-headless` | Latest | Computer vision (no GUI) |
| `insightface` | Latest | Face analysis |
| `onnxruntime-gpu` | Latest | ONNX runtime with GPU |
| `sentencepiece` | Latest | Text tokenization |
| `gitpython` | Latest | Git integration |
| `packaging` | Latest | Package version handling |
| `pydantic` | Latest | Data validation |
| `pyyaml` | Latest | YAML parsing |
| `httpx` | Latest | HTTP client |
| `aiohttp` | Latest | Async HTTP client |
| `websockets` | Latest | WebSocket support |
| `typing-extensions` | Latest | Type hints |

### PyTorch CUDA Variants
- **CUDA 12.4:** `torch==2.5.1+cu124` (Primary)
- **CUDA 12.1:** `torch==2.5.1+cu121` (Fallback)
- **CUDA 11.8:** `torch==2.5.1+cu118` (Legacy)

**Note:** xformers is intentionally NOT installed to avoid version conflicts

---

## 🎨 CORE SOFTWARE

### ComfyUI
- **Repository:** https://github.com/comfyanonymous/ComfyUI
- **Installation:** Git clone (depth 1)
- **Location:** `${WORKSPACE}/ComfyUI`
- **Port:** 8188
- **Access:** `http://IP:8188`

### Hugging Face Tools
- **git-lfs:** Large file support for Git
- **Hugging Face CLI:** Command-line interface for HF Hub
- **Installation:** Via official install scripts

### NVIDIA Tools
- **nvidia-smi:** GPU monitoring
- **nvidia-container-toolkit:** Docker GPU support
- **CUDA Toolkit:** Included with drivers

---

## 🧩 COMFYUI EXTENSIONS

All extensions installed in `${COMFYUI_DIR}/custom_nodes/`

### 1. ComfyUI-Manager
- **Repository:** https://github.com/ltdrdata/ComfyUI-Manager
- **Purpose:** Extension and model management
- **Features:** Web UI for installing nodes, dependency management

### 2. ComfyUI-AnimateDiff-Evolved
- **Repository:** https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved
- **Purpose:** Advanced animation from static images
- **Features:** Motion modules, animation techniques

### 3. ComfyUI-VideoHelperSuite
- **Repository:** https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite
- **Purpose:** Comprehensive video processing
- **Features:** Load/save videos, frame extraction, format conversion

### 4. ComfyUI-Frame-Interpolation
- **Repository:** https://github.com/Fannovel16/ComfyUI-Frame-Interpolation
- **Purpose:** AI-powered frame interpolation
- **Features:** RIFE model support, smooth motion generation

### 5. ComfyUI-Impact-Pack
- **Repository:** https://github.com/ltdrdata/ComfyUI-Impact-Pack
- **Purpose:** Utility and detection tools
- **Features:** Face detection, masking, inpainting, workflow optimization

### 6. ComfyUI_UltimateSDUpscale
- **Repository:** https://github.com/ssitu/ComfyUI_UltimateSDUpscale
- **Purpose:** Advanced SD-based upscaling
- **Features:** High-quality image enlargement with detail preservation

### 7. ComfyUI-DepthAnythingV2
- **Repository:** https://github.com/kijai/ComfyUI-DepthAnythingV2
- **Purpose:** Depth estimation from images
- **Features:** 3D effects, depth-based control

### 8. ComfyUI-Custom-Scripts
- **Repository:** https://github.com/pythongosssss/ComfyUI-Custom-Scripts
- **Purpose:** Workflow automation and UI enhancements
- **Features:** Batch processing, image manipulation

### 9. ComfyUI-WanVideoWrapper
- **Repository:** https://github.com/kijai/ComfyUI-WanVideoWrapper
- **Purpose:** Wan video model integration
- **Features:** Text-to-video, image-to-video workflows

### 10. efficiency-nodes-comfyui
- **Repository:** https://github.com/jags111/efficiency-nodes-comfyui
- **Purpose:** Performance optimization
- **Features:** Model caching, memory management

### 11. ComfyUI_IPAdapter_plus
- **Repository:** https://github.com/cubiq/ComfyUI_IPAdapter_plus
- **Purpose:** Advanced image conditioning
- **Features:** Reference image-based generation control

### 12. ComfyUI_Comfyroll_CustomNodes
- **Repository:** https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes
- **Purpose:** Large collection of utility nodes
- **Features:** Text processing, image effects, data processing

### 13. rgthree-comfy
- **Repository:** https://github.com/rgthree/rgthree-comfy
- **Purpose:** Workflow enhancement
- **Features:** Context management, rerouting, execution control

### 14. ComfyUI-GGUF
- **Repository:** https://github.com/city96/ComfyUI-GGUF
- **Purpose:** Quantized model support
- **Features:** GGUF model loading, reduced memory usage

### 15. ComfyUI-TripoSR
- **Repository:** https://github.com/VykosX/ComfyUI-TripoSR
- **Purpose:** 2D to 3D conversion
- **Features:** Single-image 3D reconstruction, GLB/GLTF export

### 16. ComfyUI-LTXVideo
- **Repository:** https://github.com/Lightricks/ComfyUI-LTXVideo
- **Purpose:** LTX-2 video generation
- **Features:** Official LTX-2 integration, advanced text-to-video

---

## 🎭 AI MODELS - CHECKPOINTS

All checkpoints installed in `${COMFYUI_DIR}/models/checkpoints/`

### Image Generation Models

| Model | Size | Type | Source | Purpose |
|-------|------|------|--------|---------|
| `pmXL_v1.safetensors` | 6.5GB | SDXL | Dropbox | Pony/anime style |
| `dreamshaper_8.safetensors` | 2GB | SD 1.5 | HuggingFace/Dropbox | Realistic/artistic |
| `revAnimated_v122.safetensors` | 2GB | SD 1.5 | HuggingFace/Civitai | Animation/cartoon |
| `pony_realism_v2.2.safetensors` | 6.5GB | SDXL | HuggingFace/Dropbox | Semi-realistic pony |
| `wai_illustrious_sdxl.safetensors` | ~6GB | SDXL | Dropbox | Illustrative style |
| `Rajii-Artist-Style-V2-Illustrious.safetensors` | ~6GB | SDXL | Dropbox | Artistic style |
| `pornmasterPro_noobV6.safetensors` | ~6GB | SDXL | Dropbox | Adult content |
| `expressiveh_hentai.safetensors` | ~2GB | SD 1.5 | Dropbox | Hentai/anime |
| `fondled.safetensors` | ~2GB | SD 1.5 | Dropbox | Artistic |
| `twerk.safetensors` | ~2GB | SD 1.5 | Dropbox | Dance/movement |
| `sd_xl_base_1.0.safetensors` | 6.9GB | SDXL | HuggingFace | Official SDXL base |
| `sd_xl_refiner_1.0.safetensors` | 6.1GB | SDXL | HuggingFace | SDXL refiner |

### Video Generation Models

| Model | Size | Type | Source | Purpose |
|-------|------|------|--------|---------|
| `DR34MJOB_I2V_14b_LowNoise.safetensors` | ~14GB | I2V | Dropbox | Image-to-video |
| `wan_dr34ml4y_all_in_one.safetensors` | ~10GB | Video | Dropbox | Versatile video gen |
| `wan_dr34mjob.safetensors` | ~10GB | Video | Dropbox | Specialized video |
| `ltx-2-19b-distilled.safetensors` | ~19GB | Video | HuggingFace | LTX-2 video gen |

---

## 🎨 AI MODELS - LORAS

All LoRAs installed in `${COMFYUI_DIR}/models/loras/`

### General LoRAs

| Model | Size | Source | Purpose |
|-------|------|--------|---------|
| `pony_realism_v2.1.safetensors` | ~150MB | HuggingFace/Civitai | Pony realism enhancement |
| `ltx-2-19b-lora-camera-control-dolly-left.safetensors` | ~100MB | HuggingFace | LTX-2 camera control |
| `expressiveh_hentai.safetensors` | ~100MB | Dropbox | Hentai style |
| `fondled.safetensors` | ~100MB | Dropbox | Artistic style |
| `wan_dr34ml4y_all_in_one.safetensors` | ~500MB | Dropbox | Video enhancement |
| `wan_dr34mjob.safetensors` | ~500MB | Dropbox | Video enhancement |
| `twerk.safetensors` | ~100MB | Dropbox | Dance/movement |
| `defecation_v1.safetensors` | ~100MB | HuggingFace | Fetish content |

### Fetish LoRAs (Catbox.moe)

| Model | Size | Source | Purpose |
|-------|------|--------|---------|
| `cunnilingus_gesture.safetensors` | ~100MB | Catbox | Gesture elements |
| `archive_lora.rar` | Variable | Catbox | LoRA archive |
| `empty_eyes_drooling.safetensors` | ~100MB | Catbox | Facial expressions |
| `glowing_eyes.safetensors` | ~100MB | Catbox | Eye effects |
| `quadruple_amputee.safetensors` | ~100MB | Catbox | Body modifications |
| `ugly_bastard.safetensors` | ~100MB | Catbox | Character traits |
| `sex_machine.safetensors` | ~100MB | Catbox | Fetish themes |
| `stasis_tank.safetensors` | ~100MB | Catbox | Sci-fi fetish |

### Scat LoRAs (BlackHat404/scatmodels)

| Model | Size | Source | Purpose |
|-------|------|--------|---------|
| `Soiling-V1.safetensors` | ~100MB | HuggingFace | Soiling elements |
| `turtleheading-V1.safetensors` | ~100MB | HuggingFace | Scat elements |
| `poop_squatV2.safetensors` | ~100MB | HuggingFace | Squat pose |
| `Poop_SquatV3.safetensors` | ~100MB | HuggingFace | Enhanced squat |
| `HyperDump.safetensors` | ~100MB | HuggingFace | Extreme scat |
| `HyperDumpPlus.safetensors` | ~100MB | HuggingFace | Enhanced extreme |

---

## 🎬 AI MODELS - VIDEO (WAN)

### Wan Diffusion Models
Location: `${COMFYUI_DIR}/models/diffusion_models/`

| Model | Size | Precision | Source | Purpose |
|-------|------|-----------|--------|---------|
| `wan2.1_t2v_1.3B_fp16.safetensors` | ~2.6GB | FP16 | HuggingFace | Wan 2.1 text-to-video |
| `wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors` | ~14GB | FP8 | HuggingFace | High-noise video gen |
| `wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors` | ~14GB | FP8 | HuggingFace | Low-noise video gen |
| `wan2.2_ti2v_5B_fp16.safetensors` | ~10GB | FP16 | HuggingFace | Text+Image-to-Video |
| `wan2.2_remix_fp8.safetensors` | ~14GB | FP8 | Civitai | Enhanced NSFW video |

### Wan LoRAs (Lightning Fast Generation)
Location: `${COMFYUI_DIR}/models/loras/`

| Model | Size | Source | Purpose |
|-------|------|--------|---------|
| `wan2.2_t2v_lightx2v_4steps_lora_v1.1_high_noise.safetensors` | ~500MB | HuggingFace | 4-step T2V (high noise) |
| `wan2.2_t2v_lightx2v_4steps_lora_v1.1_low_noise.safetensors` | ~500MB | HuggingFace | 4-step T2V (low noise) |
| `wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors` | ~500MB | HuggingFace | 4-step I2V (high noise) |
| `wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors` | ~500MB | HuggingFace | 4-step I2V (low noise) |

### Wan Text Encoders
Location: `${COMFYUI_DIR}/models/clip/`

| Model | Size | Source | Purpose |
|-------|------|--------|---------|
| `umt5_xxl_fp8_e4m3fn.safetensors` | ~3GB | HuggingFace | Wan text encoding |

### Wan VAEs
Location: `${COMFYUI_DIR}/models/vae/`

| Model | Size | Source | Purpose |
|-------|------|--------|---------|
| `wan2.1_vae.safetensors` | ~320MB | HuggingFace | Wan 2.1 VAE |
| `wan2.2_vae.safetensors` | ~320MB | HuggingFace | Wan 2.2 VAE |

---

## 🎥 AI MODELS - VIDEO (LTX-2)

### LTX Diffusion Models
Location: `${COMFYUI_DIR}/models/diffusion_models/`

| Model | Size | Precision | Source | Purpose |
|-------|------|-----------|--------|---------|
| `ltx-2-19b-dev-fp8.safetensors` | ~19GB | FP8 | HuggingFace | LTX-2 development model |

### LTX LoRAs
Location: `${COMFYUI_DIR}/models/loras/`

| Model | Size | Source | Purpose |
|-------|------|--------|---------|
| `ltx-2-19b-lora-camera-control-dolly-left.safetensors` | ~100MB | HuggingFace | Camera dolly-left control |
| `ltx-2-19b-distilled-lora-384.safetensors` | ~100MB | HuggingFace | 384 resolution (2-3x faster) |

---

## ⚡ AI MODELS - FLUX

### FLUX Diffusion Models
Location: `${COMFYUI_DIR}/models/diffusion_models/`

| Model | Size | Precision | Source | Purpose |
|-------|------|-----------|--------|---------|
| `flux1-krea-dev_fp8_scaled.safetensors` | ~12GB | FP8 | HuggingFace | Refinement & inpainting |

### FLUX Text Encoders
Location: `${COMFYUI_DIR}/models/clip/`

| Model | Size | Source | Purpose |
|-------|------|--------|---------|
| `clip_l.safetensors` | ~250MB | HuggingFace | CLIP-L encoder |
| `t5xxl_fp16.safetensors` | ~9GB | HuggingFace | T5-XXL encoder |

---

## 🎨 AI MODELS - VAES

Location: `${COMFYUI_DIR}/models/vae/`

| Model | Size | Source | Purpose |
|-------|------|--------|---------|
| `sdxl_vae.safetensors` | 319MB | HuggingFace/Dropbox | Standard SDXL VAE |
| `ponyRealism_v21MainVAE.safetensors` | 320MB | Civitai | Pony realism VAE |
| `wan2.1_vae.safetensors` | 242MB | HuggingFace | Wan 2.1 VAE (standard) |
| `wan_2.1_vae.safetensors` | 242MB | Dropbox | Wan 2.1 VAE (alt naming) |
| `wan2.2_vae.safetensors` | 1.3GB | HuggingFace | Wan 2.2 VAE |
| `ae.safetensors` | 320MB | HuggingFace | Lumina Image 2.0 VAE |
| `lumina_ae.safetensors` | 320MB | HuggingFace | Lumina Image 2.0 (alt name) |

---

## 📝 AI MODELS - TEXT ENCODERS

Location: `${COMFYUI_DIR}/models/clip/` or `${COMFYUI_DIR}/models/text_encoders/`

| Model | Size | Source | Purpose |
|-------|------|--------|---------|
| `umt5_xxl_fp8_e4m3fn.safetensors` | 3GB | HuggingFace | Wan text encoding (standard) |
| `umt5_xxl_fp8_e4m3fn_scaled.safetensors` | 6.4GB | HuggingFace | Wan/LTX text encoding (scaled) |
| `gemma_3_12B_it_fp4_mixed.safetensors` | 9GB | HuggingFace | LTX-2/Gemma text encoding |
| `clip_l.safetensors` | 235MB | HuggingFace | FLUX CLIP-L encoder |
| `t5xxl_fp16.safetensors` | 9.3GB | HuggingFace | FLUX T5-XXL encoder |

---

## 🎬 AI MODELS - ANIMATEDIFF

Location: `${COMFYUI_DIR}/models/animatediff_models/`

| Model | Size | Source | Purpose |
|-------|------|--------|---------|
| `mm_sdxl_v10_beta.ckpt` | ~1.8GB | HuggingFace | SDXL motion module |
| `mm_sd_v15_v2.ckpt` | ~1.6GB | HuggingFace | SD 1.5 motion module |

---

## 🔍 AI MODELS - UPSCALERS

Location: `${COMFYUI_DIR}/models/upscale_models/`

| Model | Size | Source | Purpose |
|-------|------|--------|---------|
| `4x-UltraSharp.pth` | ~67MB | HuggingFace | 4x upscaling with sharpening |
| `RealESRGAN_x4plus.pth` | ~64MB | GitHub | Real-ESRGAN 4x upscaling |
| `ltx-2-spatial-upscaler-x2-1.0.safetensors` | ~500MB | HuggingFace | LTX-2 spatial upscaler |

---

## 🎮 AI MODELS - CONTROLNET

Location: `${COMFYUI_DIR}/models/controlnet/`

| Model | Size | Source | Purpose |
|-------|------|--------|---------|
| `OpenPoseXL2.safetensors` | ~2.5GB | HuggingFace | SDXL pose control |

---

## 🔎 AI MODELS - DETECTION MODELS

Location: `${COMFYUI_DIR}/models/` (various subdirectories)

| Model | Size | Source | Purpose |
|-------|------|--------|---------|
| `face_yolov8m.pt` | ~52MB | HuggingFace | Face detection (ADetailer) |
| `hand_yolov8n.pt` | ~6MB | HuggingFace | Hand detection (ADetailer) |
| `sam_vit_b_01ec64.pth` | ~375MB | Facebook AI | Segment Anything Model |

---

## 🎞️ AI MODELS - FRAME INTERPOLATION

Location: `${COMFYUI_DIR}/models/` (RIFE subdirectory)

| Model | Size | Source | Purpose | Status |
|-------|------|--------|---------|--------|
| `rife426.pth` | ~200MB | HuggingFace (zip) | RIFE v4.26 interpolation | Extracted from RIFEv4.26_0921.zip |

---

## 🔗 DOWNLOAD SOURCES

### Primary Sources

#### HuggingFace Repositories
- **Official Repos:** Stability AI, Comfy-Org, Lightricks
- **Community Repos:** LyliaEngine, John6666, BlackHat404
- **Authentication:** `HUGGINGFACE_HUB_TOKEN` (optional for public models)
- **Reliability:** ⭐⭐⭐⭐⭐ (Primary source)

#### Dropbox Links
- **Purpose:** Fallback mirrors for HuggingFace models
- **Reliability:** ⭐⭐⭐⭐ (Reliable fallback)
- **Rate Limits:** ~1TB/day per account
- **Download Rules:** Single connection only, 3-min timeout

#### Civitai API
- **Authentication:** `CIVITAI_TOKEN` (required)
- **Rate Limits:** Sequential downloads only (avoid 429 errors)
- **Reliability:** ⭐⭐⭐ (Requires valid token)
- **Token URL:** https://civitai.com/user/account

#### Catbox.moe
- **Purpose:** Fetish LoRA hosting
- **Reliability:** ⭐⭐ (Some dead links)
- **Rate Limits:** Moderate

#### GitHub Releases
- **Purpose:** Upscalers, RIFE models
- **Reliability:** ⭐⭐⭐⭐ (Stable)

### Dropbox Links (Current)

```
https://www.dropbox.com/scl/fi/v52p66ci8u7n8r5cqc1pi/dreamshaper_8.safetensors?rlkey=4f0133r062xr8nafpsxp2h9gq&dl=1
https://www.dropbox.com/scl/fi/eq3qqc5rnwod3ac1xfisp/Rajii-Artist-Style-V2-Illustrious.safetensors?rlkey=cvfjam45wbmye89g2mvj245lz&dl=1
https://www.dropbox.com/scl/fi/6af8pzucgqyr0dy78eh6q/DR34MJOB_I2V_14b_LowNoise.safetensors?rlkey=pgnys4h98h343ibaro0fgwhqv&dl=1
https://www.dropbox.com/scl/fi/hy476rxzeacsx8g3aodj0/pony_realism_v2.2.safetensors?rlkey=09k5sba46pqoptdu7h1tu03b4&dl=1
https://www.dropbox.com/scl/fi/dd7aiju5petevb6nalinr/pmXL_v1.safetensors?rlkey=p4ukouvdd2o912ilcfbi6cqk3&dl=1
https://www.dropbox.com/scl/fi/okhdb2r3i43l7f8hv07li/wai_illustrious_sdxl.safetensors?rlkey=t7r11yjr61ecdm0vrsgrkztc8&dl=1
https://www.dropbox.com/scl/fi/9drclw495plki15ynlmst/fondled.safetensors?rlkey=vh5efbuy0er4338xrkivilpnb&dl=1
https://www.dropbox.com/scl/fi/hp8t53h5ylrhkphnq4cyu/wan_dr34ml4y_all_in_one.safetensors?rlkey=9bq4clb4gmiz4rp6i8g69fl9u&dl=1
https://www.dropbox.com/scl/fi/ym112crqb6d7sdkqz5s9j/wan_dr34mjob.safetensors?rlkey=eqzd371f86g6tsof0fcecfn8n&dl=1
https://www.dropbox.com/scl/fi/0g4btjch885ij3kiauffm/twerk.safetensors?rlkey=8yqxhqpvs1osat76ynxadwkh8&dl=1
https://www.dropbox.com/scl/fi/8280uj9myxuf2376d13jt/pornmasterPro_noobV6.safetensors?rlkey=lmduqq3jxusts1fqqexuqz72w&dl=1
https://www.dropbox.com/scl/fi/5whxkdo39m4w2oimcffx2/expressiveh_hentai.safetensors?rlkey=5ejkyjvethd1r7fn121x7cvs1&dl=1
https://www.dropbox.com/scl/fi/3qygk64xe2ui2ey74neto/sdxl_vae.safetensors?rlkey=xzsllv3hq5w1qx81h9b2xryq8&dl=1
https://www.dropbox.com/scl/fi/p0uxwux03oq90l8fxmrqx/ponyDiffusionV6XL.safetensors?rlkey=nxd5ll1idx0uk6jvsqn7l4hmo&dl=1
```

**Note:** These links are from an older file. Cross-verify with Dropbox account for current links.

---

## 🔐 ENVIRONMENT VARIABLES

### Required Tokens

| Variable | Purpose | Required | How to Obtain |
|----------|---------|----------|---------------|
| `CIVITAI_TOKEN` | Civitai API downloads | Yes | https://civitai.com/user/account |
| `HUGGINGFACE_HUB_TOKEN` | HuggingFace downloads | Optional | https://huggingface.co/settings/tokens |
| `VASTAI_API_KEY` | Vast.ai automation | Yes (for automation) | https://cloud.vast.ai/account/ |
| `ADMIN_API_KEY` | Local server admin | Yes (for warm-pool) | Set in `.env` file |

### Optional Configuration

| Variable | Default | Purpose |
|----------|---------|---------|
| `WORKSPACE` | `/workspace` | Installation directory |
| `MIN_DISK_GB` | `200` | Minimum disk space check |
| `MAX_PAR_HF` | `4` | HuggingFace parallel downloads |
| `MAX_PAR_CIVITAI` | `1` | Civitai parallel downloads (sequential) |
| `PIP_ROOT_USER_ACTION` | `ignore` | Suppress pip root warnings |

---

## 💾 INSTALLATION SIZE SUMMARY

### By Category

| Category | Count | Estimated Size |
|----------|-------|----------------|
| **Checkpoints** | 16 | 60-70GB |
| **LoRAs** | 25+ | 6-10GB |
| **Video Models (Wan)** | 5 | 50-60GB |
| **Video Models (LTX)** | 1 | 19GB |
| **FLUX Models** | 1 | 12GB |
| **VAEs** | 5 | 1.5-2GB |
| **Text Encoders** | 4 | 18-20GB |
| **AnimateDiff** | 2 | 3-4GB |
| **Upscalers** | 3 | 600MB |
| **ControlNet** | 1 | 2.5GB |
| **Detection Models** | 3 | 450MB |
| **RIFE** | 1 | 200MB |
| **System Packages** | 20+ | 2-3GB |
| **Python Packages** | 20+ | 5-8GB |
| **ComfyUI + Extensions** | 16 | 2-3GB |
| **TOTAL** | **100+** | **180-220GB** |

### Provisioning Time
- **Fast Connection (1 Gbps):** 15-25 minutes
- **Medium Connection (100 Mbps):** 30-60 minutes
- **Slow Connection (10 Mbps):** 2-4 hours

### Disk Space Recommendations
- **Minimum:** 200GB (tight, may fail)
- **Recommended:** 400GB (comfortable)
- **Optimal:** 500GB+ (future-proof)

---

## 📚 REFERENCE DOCUMENTATION

### Provisioning Scripts
- **Main Script:** `scripts/provision-reliable.sh` (v3.0)
- **Core Script:** `scripts/provision-core.sh` (backup)
- **Workflows:** `scripts/provision-workflows.sh` (separate)
- **Fast Restore:** `scripts/fast_restore.sh` (batch downloader)

### Documentation Files
- **Provision Guide:** `docs/PROVISION_CLEAN.md`
- **Provision README:** `scripts/PROVISION_README.md`
- **Installed Assets:** `docs/installed_assets.md`
- **Workflow Guide:** `docs/WORKFLOW_GUIDE.md`

### Verification Locations
- **Download Logs:** `/workspace/download-logs/`
- **Model Logs:** `/workspace/download_models.log`
- **Provision Log:** `/workspace/provision_v3.log`
- **ComfyUI Log:** `/workspace/comfyui.log`
- **Model Folders:** `/workspace/ComfyUI/models/`

---

## 🔧 TROUBLESHOOTING

### Common Issues

#### Disk Space
```bash
# Check available space
df -h /workspace

# Clean up partial downloads
rm -rf /workspace/ComfyUI/models/*.aria2
rm -rf /workspace/ComfyUI/models/*.tmp
```

#### Token Validation
```bash
# Test Civitai token
curl -I "https://civitai.com/api/download/models/152309?token=$CIVITAI_TOKEN"

# Test HuggingFace token
curl -H "Authorization: Bearer $HUGGINGFACE_HUB_TOKEN" \
  https://huggingface.co/api/whoami
```

#### Model Verification
```bash
# List all downloaded models
find /workspace/ComfyUI/models -name "*.safetensors" -o -name "*.ckpt" -o -name "*.pth"

# Check model sizes
du -sh /workspace/ComfyUI/models/*
```

#### ComfyUI Health Check
```bash
# Check if running
ps aux | grep main.py

# Test API
curl http://localhost:8188/system_stats

# View logs
tail -f /workspace/comfyui.log
```

---

## 📝 NOTES

### Important Reminders
1. **Dropbox Links:** Current links in `data/dropbox_links.txt` are from an old file. Cross-verify with Dropbox account before using.
2. **Civitai Token:** Must be valid and not expired. Test before provisioning.
3. **SSH Fixes:** All SSH configuration fixes have been removed from provision scripts (they cause issues).
4. **xformers:** Intentionally NOT installed to avoid PyTorch version conflicts.
5. **Optional Assets:** `rife426.pth` and `example_pose.png` may fail (404 errors) - provisioning continues.

### Version History
- **v3.0 (2026-02-01):** Modular design, FLUX/LTX-2 support, Wan 2.2 Lightning LoRAs
- **v2.2:** Previous version with embedded workflows
- **v2.0:** Initial reliable provisioner

---

## 🎯 NEXT STEPS

### To Use This Manifest
1. ✅ Cross-verify Dropbox links with your Dropbox account
2. ✅ Ensure `CIVITAI_TOKEN` is valid and set
3. ✅ Review model list and remove unwanted models to save space
4. ✅ Run `scripts/provision-reliable.sh` on Vast.ai instance
5. ✅ Monitor logs at `/workspace/provision_v3.log`
6. ✅ Verify ComfyUI at `http://YOUR_IP:8188`

### To Update This Manifest
1. Edit this file: `docs/COMPLETE_SOFTWARE_MANIFEST.md`
2. Update version number and date at top
3. Add new models/software to appropriate sections
4. Update size estimates in summary table
5. Commit changes to version control

---

**Generated:** 2026-02-04  
**Provision Script Version:** v3.0  
**Total Assets:** 100+ items across 180-220GB  
**Maintained By:** AI Kings Team
