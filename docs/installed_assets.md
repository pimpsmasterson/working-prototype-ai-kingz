# Installed / Requested Downloads — Audit

This document collects all external downloads, mirrors, and hosting links referenced by the provisioning and fast-restore scripts in this workspace. It's an inventory for auditing what the provisioner attempts to fetch and what we treat as optional.

Files / scripts scanned
- `scripts/provision-reliable.sh` (primary provisioning script)
- `scripts/provision-core.sh` (backup)
- `scripts/fast_restore.sh` (fast restore / batch downloader)
- `scripts/provision-workflows.sh`

GitHub repositories (extensions / node packs)
- https://github.com/ltdrdata/ComfyUI-Manager
- https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved
- https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite
- https://github.com/Fannovel16/ComfyUI-Frame-Interpolation
- https://github.com/ltdrdata/ComfyUI-Impact-Pack
- https://github.com/ssitu/ComfyUI_UltimateSDUpscale
- https://github.com/kijai/ComfyUI-DepthAnythingV2
- https://github.com/pythongosssss/ComfyUI-Custom-Scripts
- https://github.com/kijai/ComfyUI-WanVideoWrapper
- https://github.com/jags111/efficiency-nodes-comfyui
- https://github.com/cubiq/ComfyUI_IPAdapter_plus
- https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes
- https://github.com/rgthree/rgthree-comfy
- https://github.com/city96/ComfyUI-GGUF

Hugging Face and model files (direct `huggingface.co` links)
- https://huggingface.co/LyliaEngine/Pony_Diffusion_V6_XL/resolve/main/pmXL_v1.safetensors (commented/mirror provided)
- https://huggingface.co/Lykon/dreamshaper-8/resolve/main/dreamshaper_8.safetensors
- https://huggingface.co/danbrown/RevAnimated-v1-2-2/resolve/main/revAnimated_v122.safetensors
- https://huggingface.co/John6666/pony-realism-v22main-sdxl/resolve/main/pony_realism_v2.2.safetensors
- https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors
- https://huggingface.co/LyliaEngine/ponyRealism_v21MainVAE/resolve/main/ponyRealism_v21MainVAE.safetensors
- https://huggingface.co/JollyIm/Defecation/resolve/main/defecation_v1.safetensors
- https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_t2v_1.3B_fp16.safetensors
- https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors
- https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors
- https://huggingface.co/FX-FeiHou/wan2.2-Remix (git clone repository)
- https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors
- https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors
- https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors
- https://huggingface.co/camenduru/AnimateDiff-sdxl-beta/resolve/main/mm_sdxl_v10_beta.ckpt
- https://huggingface.co/guoyww/animatediff/resolve/main/mm_sd_v15_v2.ckpt
- https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth
- https://huggingface.co/thibaud/controlnet-openpose-sdxl-1.0/resolve/main/OpenPoseXL2.safetensors
- https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt
- https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8n.pt
- https://huggingface.co/stabilityai/stable-diffusion-xl-refiner-1.0/resolve/main/sd_xl_refiner_1.0.safetensors?download=true
- https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors?download=true

# --- Civitai.com Models (with API token authentication) ---
- https://civitai.com/api/download/models/2567309?type=Model&format=SafeTensor&size=pruned&fp=fp8 (wan2.2-Remix FP8)
- https://civitai.com/api/download/models/915814?type=Model&format=SafeTensor&size=pruned&fp=fp16 (wan2.2-Remix FP16)

# --- Catbox.moe Fetish LoRAs (dead links removed) ---
- https://files.catbox.moe/wmshk3.safetensors
- https://files.catbox.moe/88e51n.rar
- https://files.catbox.moe/9qixqa.safetensors
- https://files.catbox.moe/yz5c9g.safetensors
- https://files.catbox.moe/tlt57h.safetensors
- https://files.catbox.moe/odmswn.safetensors
- https://files.catbox.moe/z71ic0.safetensors
- https://files.catbox.moe/mxbbg2.safetensors

# --- BlackHat404/scatmodels (HuggingFace) ---
- https://huggingface.co/BlackHat404/scatmodels/resolve/main/Soiling-V1.safetensors
- https://huggingface.co/BlackHat404/scatmodels/resolve/main/turtleheading-V1.safetensors
- https://huggingface.co/BlackHat404/scatmodels/resolve/main/poop_squatV2.safetensors
- https://huggingface.co/BlackHat404/scatmodels/resolve/main/Poop_SquatV3.safetensors
- https://huggingface.co/BlackHat404/scatmodels/resolve/main/HyperDump.safetensors
- https://huggingface.co/BlackHat404/scatmodels/resolve/main/HyperDumpPlus.safetensors
- https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-distilled.safetensors | ltx-2-19b-distilled.safetensors
- https://huggingface.co/Lightricks/LTX-2-19b-LoRA-Camera-Control-Dolly-Left/resolve/main/ltx-2-19b-lora-camera-control-dolly-left.safetensors | ltx-2-19b-lora-camera-control-dolly-left.safetensors
- https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors | gemma_3_12B_it_fp4_mixed.safetensors
- https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-spatial-upscaler-x2-1.0.safetensors | ltx-2-spatial-upscaler-x2-1.0.safetensors

Dropbox-hosted files (direct dropbox links / mirrors)
- https://www.dropbox.com/scl/fi/dd7aiju5petevb6nalinr/pmXL_v1.safetensors?rlkey=p4ukouvdd2o912ilcfbi6cqk3&dl=1
- https://www.dropbox.com/scl/fi/p0uxwux03oq90l8fxmrqx/pmXL_v1.safetensors?rlkey=nxd5ll1idx0uk6jvsqn7l4hmo&dl=1
- https://www.dropbox.com/scl/fi/v52p66ci8u7n8r5cqc1pi/dreamshaper_8.safetensors?rlkey=4f0133r062xr8nafpsxp2h9gq&dl=1
- https://www.dropbox.com/scl/fi/hy476rxzeacsx8g3aodj0/pony_realism_v2.2.safetensors?rlkey=09k5sba46pqoptdu7h1tu03b4&dl=1
- https://www.dropbox.com/scl/fi/okhdb2r3i43l7f8hv07li/wai_illustrious_sdxl.safetensors?rlkey=t7r11yjr61ecdm0vrsgrkztc8&dl=1
- https://www.dropbox.com/scl/fi/eq3qqc5rnwod3ac1xfisp/Rajii-Artist-Style-V2-Illustrious.safetensors?rlkey=cvfjam45wbmye89g2mvj245lz&dl=1
- https://www.dropbox.com/scl/fi/6af8pzucgqyr0dy78eh6q/DR34MJOB_I2V_14b_LowNoise.safetensors?rlkey=pgnys4h98h343ibaro0fgwhqv&dl=1
- https://www.dropbox.com/scl/fi/8280uj9myxuf2376d13jt/pornmasterPro_noobV6.safetensors?rlkey=lmduqq3jxusts1fqqexuqz72w&dl=1
- https://www.dropbox.com/scl/fi/5whxkdo39m4w2oimcffx2/expressiveh_hentai.safetensors?rlkey=5ejkyjvethd1r7fn121x7cvs1&dl=1
- https://www.dropbox.com/scl/fi/9drclw495plki15ynlmst/fondled.safetensors?rlkey=vh5efbuy0er4338xrkivilpnb&dl=1
- https://www.dropbox.com/scl/fi/hp8t53h5ylrhkphnq4cyu/wan_dr34ml4y_all_in_one.safetensors?rlkey=9bq4clb4gmiz4rp6i8g69fl9u&dl=1
- https://www.dropbox.com/scl/fi/ym112crqb6d7sdkqz5s9j/wan_dr34mjob.safetensors?rlkey=eqzd371f86g6tsof0fcecfn8n&dl=1
- https://www.dropbox.com/scl/fi/0g4btjch885ij3kiauffm/twerk.safetensors?rlkey=8yqxhqpvs1osat76ynxadwkh8&dl=1
- https://www.dropbox.com/scl/fi/3qygk64xe2ui2ey74neto/sdxl_vae.safetensors?rlkey=xzsllv3hq5w1qx81h9b2xryq8&dl=1

Civitai / API download endpoints
- https://civitai.com/api/download/models/152309?token=$CIVITAI_TOKEN
- https://civitai.com/api/download/models/122606

Other direct-hosted artifacts
- https://github.com/hzwer/Practical-RIFE/releases/download/v4.26/rife426.pth  (RIFE frame interpolation — reported 404 in instance logs)
- https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth
- https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth
- https://nvidia.github.io/nvidia-docker/gpgkey
- https://download.pytorch.org/whl/cu124  (and cu121 / cu118 indexes used for pip)

Notes, verification and pointers
- The full raw URL lists are embedded in `scripts/provision-reliable.sh`, `scripts/provision-core.sh.backup`, and `scripts/fast_restore.sh`. See them directly for the canonical, machine-parsable lists:
  - [scripts/provision-reliable.sh](scripts/provision-reliable.sh)
  - [scripts/provision-core.sh.backup](scripts/provision-core.sh.backup)
  - [scripts/fast_restore.sh](scripts/fast_restore.sh)

- To verify what actually finished downloading on an instance, inspect `/workspace/download-logs/`, `/workspace/download_models.log`, and the ComfyUI model folders under `/workspace/ComfyUI/`.

# Detailed Asset Information

This section provides detailed information on each asset, categorized by type. It includes what each asset is (checkpoint, LoRA, extension, etc.), what it does, and how to use it in ComfyUI workflows.

## ComfyUI Extensions / Node Packs

These are GitHub repositories that add custom nodes and functionality to ComfyUI. They extend the base capabilities for specific tasks like animation, video processing, upscaling, etc.

- **ComfyUI-Manager** (https://github.com/ltdrdata/ComfyUI-Manager):  
  **Type:** Extension Manager  
  **What it does:** Provides a web interface to install, update, and manage ComfyUI custom nodes and models. Includes dependency management and workflow templates.  
  **How to use:** Access via the "Manager" button in ComfyUI web interface. Use it to browse and install additional extensions without manual cloning.

- **ComfyUI-AnimateDiff-Evolved** (https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved):  
  **Type:** Animation Extension  
  **What it does:** Advanced implementation of AnimateDiff for creating smooth animations from static images using motion modules. Supports various animation techniques and model merging.  
  **How to use:** Load AnimateDiff models (mm_*.ckpt) and use AnimateDiff nodes to apply motion to image sequences. Requires compatible base models.

- **ComfyUI-VideoHelperSuite** (https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite):  
  **Type:** Video Processing Extension  
  **What it does:** Comprehensive video processing toolkit with nodes for loading, processing, and saving videos. Includes frame extraction, interpolation, and format conversion.  
  **How to use:** Use "Load Video" nodes to import videos, process frames with other nodes, then "Save Video" to export. Supports various video formats and codecs.

- **ComfyUI-Frame-Interpolation** (https://github.com/Fannovel16/ComfyUI-Frame-Interpolation):  
  **Type:** Frame Interpolation Extension  
  **What it does:** Uses AI models (like RIFE) to generate intermediate frames between existing frames, creating smoother motion in videos.  
  **How to use:** Load a video or image sequence, apply interpolation nodes with RIFE models, and save the enhanced video. Requires rife*.pth models.

- **ComfyUI-Impact-Pack** (https://github.com/ltdrdata/ComfyUI-Impact-Pack):  
  **Type:** Utility and Detection Extension  
  **What it does:** Collection of utility nodes including face detection, masking, inpainting, and workflow optimization tools.  
  **How to use:** Use detection nodes (face, hand, etc.) for masking, combine with inpainting for targeted edits. Includes workflow management features.

- **ComfyUI_UltimateSDUpscale** (https://github.com/ssitu/ComfyUI_UltimateSDUpscale):  
  **Type:** Upscaling Extension  
  **What it does:** Advanced upscaling using Stable Diffusion models for high-quality image enlargement with detail preservation.  
  **How to use:** Connect to image inputs, select upscale models, and adjust parameters for resolution increase. Works with various SD models.

- **ComfyUI-DepthAnythingV2** (https://github.com/kijai/ComfyUI-DepthAnythingV2):  
  **Type:** Depth Estimation Extension  
  **What it does:** Uses DepthAnything models to estimate depth from images, useful for 3D effects and depth-based control.  
  **How to use:** Load images, apply depth estimation nodes, use output for depth-guided generation or effects.

- **ComfyUI-Custom-Scripts** (https://github.com/pythongosssss/ComfyUI-Custom-Scripts):  
  **Type:** Utility Scripts Extension  
  **What it does:** Collection of custom script nodes for workflow automation, image processing, and UI enhancements.  
  **How to use:** Access various script nodes for tasks like batch processing, image manipulation, and workflow control.

- **ComfyUI-WanVideoWrapper** (https://github.com/kijai/ComfyUI-WanVideoWrapper):  
  **Type:** Video Generation Extension  
  **What it does:** Wrapper for Wan video generation models, enabling text-to-video and image-to-video workflows.  
  **How to use:** Load Wan models, input prompts or images, generate videos using specialized nodes for video diffusion.

- **efficiency-nodes-comfyui** (https://github.com/jags111/efficiency-nodes-comfyui):  
  **Type:** Optimization Extension  
  **What it does:** Performance optimization nodes including model caching, memory management, and workflow efficiency improvements.  
  **How to use:** Use caching nodes to store intermediate results, apply memory optimization for larger workflows.

- **ComfyUI_IPAdapter_plus** (https://github.com/cubiq/ComfyUI_IPAdapter_plus):  
  **Type:** Image Conditioning Extension  
  **What it does:** Advanced IP-Adapter implementation for conditioning generation on reference images with various adapter types.  
  **How to use:** Load IP-Adapter models, connect reference images, use conditioning nodes to guide generation based on image content.

- **ComfyUI_Comfyroll_CustomNodes** (https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes):  
  **Type:** Custom Nodes Collection  
  **What it does:** Large collection of custom nodes for various tasks including text processing, image manipulation, and workflow utilities.  
  **How to use:** Browse the categorized nodes for specific functions like text manipulation, image effects, and data processing.

- **rgthree-comfy** (https://github.com/rgthree/rgthree-comfy):  
  **Type:** Workflow Enhancement Extension  
  **What it does:** Advanced workflow nodes including context management, rerouting, and execution control features.  
  **How to use:** Use context nodes for variable management, reroute nodes for cleaner workflows, and control nodes for execution flow.

- **ComfyUI-GGUF** (https://github.com/city96/ComfyUI-GGUF):  
  **Type:** Quantization Extension  
  **What it does:** Support for GGUF quantized models, enabling efficient inference with reduced memory usage.  
  **How to use:** Load GGUF models using specialized loader nodes, use in place of standard model loaders for memory-constrained setups.

- **ComfyUI-TripoSR** (https://github.com/VykosX/ComfyUI-TripoSR):  
  **Type:** 3D Generation Extension  
  **What it does:** TripoSR implementation for converting 2D images to 3D models using single-image reconstruction.  
  **How to use:** Input images, use TripoSR nodes to generate 3D meshes, export as GLB/GLTF files for 3D applications.

- **ComfyUI-LTXVideo** (https://github.com/Lightricks/ComfyUI-LTXVideo):  
  **Type:** Video Generation Extension  
  **What it does:** Official ComfyUI extension for LTX-2 video generation models with advanced text-to-video capabilities.  
  **How to use:** Load LTX models, input prompts, generate high-quality videos using specialized diffusion nodes.

## Checkpoints

These are base Stable Diffusion models (.safetensors) that serve as the foundation for image generation.

- **pmXL_v1.safetensors** (Pony Diffusion V6 XL):  
  **Type:** Checkpoint  
  **What it does:** High-quality pony/anime style model trained on pony-related content.  
  **How to use:** Load as base model in SDXL workflows for anime-style generation.

- **dreamshaper_8.safetensors**:  
  **Type:** Checkpoint  
  **What it does:** Realistic/artistic model good for detailed, high-quality images across various styles.  
  **How to use:** Use in standard SD 1.5 workflows for versatile image generation.

- **revAnimated_v122.safetensors**:  
  **Type:** Checkpoint  
  **What it does:** Specialized for animation and cartoon styles with good consistency.  
  **How to use:** Load in SD 1.5 workflows for animated/cartoon content creation.

- **pony_realism_v2.2.safetensors**:  
  **Type:** Checkpoint  
  **What it does:** Pony model with realistic elements, blending anime and realistic styles.  
  **How to use:** Use in SDXL workflows for semi-realistic pony/anime generation.

- **defecation_v1.safetensors**:  
  **Type:** Checkpoint  
  **What it does:** Artistic model with unique style characteristics.  
  **How to use:** Load in SD 1.5 workflows for distinctive artistic outputs.

- **wan2.1_t2v_1.3B_fp16.safetensors**:  
  **Type:** Checkpoint (Video)  
  **What it does:** Wan 2.1 text-to-video model for generating videos from text prompts.  
  **How to use:** Use with WanVideoWrapper extension for text-to-video generation.

- **wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors**:  
  **Type:** Checkpoint (Video)  
  **What it does:** Wan 2.2 high-noise video model for detailed video generation.  
  **How to use:** Load in video workflows for high-quality text-to-video with noise-based enhancement.

- **wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors**:  
  **Type:** Checkpoint (Video)  
  **What it does:** Wan 2.2 low-noise video model for smoother video generation.  
  **How to use:** Use for cleaner, less noisy video outputs in text-to-video workflows.

- **wan2.2_remix_fp8.safetensors**:  
  **Type:** Checkpoint (Video)  
  **What it does:** Wan 2.2 Remix model by FX-FeiHou - enhanced version with improved video quality and NSFW capabilities.  
  **How to use:** Load in video workflows for high-quality NSFW video generation. Supports both high and low noise variants. Requires git-xet for cloning and HF CLI for downloading.

- **sd_xl_refiner_1.0.safetensors**:  
  **Type:** Checkpoint (Refiner)  
  **What it does:** SDXL refiner model for enhancing details in generated images.  
  **How to use:** Apply after base SDXL generation for improved quality and details.

- **sd_xl_base_1.0.safetensors**:  
  **Type:** Checkpoint (Base)  
  **What it does:** Standard SDXL base model for high-resolution image generation.  
  **How to use:** Load as primary model in SDXL workflows for general image generation.

- **wai_illustrious_sdxl.safetensors**:  
  **Type:** Checkpoint  
  **What it does:** Illustrative style model for artistic, illustrative content.  
  **How to use:** Use in SDXL workflows for illustration-style generation.

- **Rajii-Artist-Style-V2-Illustrious.safetensors**:  
  **Type:** Checkpoint  
  **What it does:** Artistic style model inspired by specific artistic techniques.  
  **How to use:** Load for distinctive artistic/illustrative outputs.

- **DR34MJOB_I2V_14b_LowNoise.safetensors**:  
  **Type:** Checkpoint (Video)  
  **What it does:** Image-to-video model with low noise characteristics.  
  **How to use:** Use for converting images to videos with smooth transitions.

- **pornmasterPro_noobV6.safetensors**:  
  **Type:** Checkpoint  
  **What it does:** Specialized model for adult content generation.  
  **How to use:** Load in appropriate workflows for NSFW content creation.

- **expressiveh_hentai.safetensors**:  
  **Type:** Checkpoint  
  **What it does:** Hentai/anime style model with expressive characteristics.  
  **How to use:** Use for hentai-style generation in SD 1.5 workflows.

- **fondled.safetensors**:  
  **Type:** Checkpoint  
  **What it does:** Artistic model with specific stylistic traits.  
  **How to use:** Load for unique artistic outputs.

- **wan_dr34ml4y_all_in_one.safetensors**:  
  **Type:** Checkpoint (Video)  
  **What it does:** Combined Wan video model for versatile video generation.  
  **How to use:** Use in video workflows for comprehensive text/image-to-video tasks.

- **wan_dr34mjob.safetensors**:  
  **Type:** Checkpoint (Video)  
  **What it does:** Specialized Wan video model for specific generation tasks.  
  **How to use:** Load in Wan video workflows for targeted video creation.

- **twerk.safetensors**:  
  **Type:** Checkpoint  
  **What it does:** Specialized model for dance/movement related content.  
  **How to use:** Use in animation workflows for dance-style generation.

- **ltx-2-19b-distilled.safetensors**:  
  **Type:** Checkpoint (LTX Video)  
  **What it does:** LTX-2 distilled model for high-quality video generation.  
  **How to use:** Load in LTX workflows for advanced video synthesis.

## LoRAs (Low-Rank Adaptations)

These are small adapter models that modify the behavior of base checkpoints for specific styles or subjects.

- **ltx-2-19b-lora-camera-control-dolly-left.safetensors**:  
  **Type:** LoRA  
  **What it does:** Adds camera dolly-left movement control to LTX-2 models.  
  **How to use:** Apply via LoRA loader nodes in LTX video workflows to control camera movement.

- **cunnilingus_gesture.safetensors**:  
  **Type:** LoRA  
  **What it does:** Adds cunnilingus gesture elements to generated images.  
  **How to use:** Apply via LoRA loader nodes for fetish-themed content.

- **archive_lora.rar**:  
  **Type:** LoRA Archive  
  **What it does:** Archive containing multiple LoRA models.  
  **How to use:** Extract and use individual LoRA files as needed.

- **empty_eyes_drooling.safetensors**:  
  **Type:** LoRA  
  **What it does:** Adds empty eyes and drooling expression effects.  
  **How to use:** Apply via LoRA loader nodes for specific facial expressions.

- **glowing_eyes.safetensors**:  
  **Type:** LoRA  
  **What it does:** Adds glowing eyes effect to characters.  
  **How to use:** Apply via LoRA loader nodes for supernatural or enhanced eye effects.

- **quadruple_amputee.safetensors**:  
  **Type:** LoRA  
  **What it does:** Adds quadruple amputee body modifications.  
  **How to use:** Apply via LoRA loader nodes for fetish-themed content.

- **ugly_bastard.safetensors**:  
  **Type:** LoRA  
  **What it does:** Adds ugly bastard character traits.  
  **How to use:** Apply via LoRA loader nodes for specific character styling.

- **sex_machine.safetensors**:  
  **Type:** LoRA  
  **What it does:** Adds sex machine elements and themes.  
  **How to use:** Apply via LoRA loader nodes for fetish-themed content.

- **stasis_tank.safetensors**:  
  **Type:** LoRA  
  **What it does:** Adds stasis tank environment and elements.  
  **How to use:** Apply via LoRA loader nodes for sci-fi fetish content.

- **Soiling-V1.safetensors**:  
  **Type:** LoRA  
  **What it does:** Adds soiling/scat elements to images.  
  **How to use:** Apply via LoRA loader nodes for scat-themed content.

- **turtleheading-V1.safetensors**:  
  **Type:** LoRA  
  **What it does:** Adds turtleheading scat elements.  
  **How to use:** Apply via LoRA loader nodes for specific scat themes.

- **poop_squatV2.safetensors**:  
  **Type:** LoRA  
  **What it does:** Adds poop squat pose and elements.  
  **How to use:** Apply via LoRA loader nodes for scat-themed content.

- **Poop_SquatV3.safetensors**:  
  **Type:** LoRA  
  **What it does:** Enhanced version of poop squat LoRA.  
  **How to use:** Apply via LoRA loader nodes for scat-themed content.

- **HyperDump.safetensors**:  
  **Type:** LoRA  
  **What it does:** Adds hyper dump scat elements.  
  **How to use:** Apply via LoRA loader nodes for extreme scat themes.

- **HyperDumpPlus.safetensors**:  
  **Type:** LoRA  
  **What it does:** Enhanced hyper dump LoRA with additional effects.  
  **How to use:** Apply via LoRA loader nodes for extreme scat themes.

## VAEs (Variational Autoencoders)

VAEs encode/decode images for better quality and compression in diffusion models.

- **sdxl_vae.safetensors**:  
  **Type:** VAE  
  **What it does:** Standard SDXL VAE for improved image quality and color accuracy.  
  **How to use:** Load alongside SDXL models to enhance generation quality.

- **ponyRealism_v21MainVAE.safetensors**:  
  **Type:** VAE  
  **What it does:** Specialized VAE for pony realism models.  
  **How to use:** Use with pony realism checkpoints for optimal quality.

- **wan_2.1_vae.safetensors**:  
  **Type:** VAE (Video)  
  **What it does:** VAE for Wan 2.1 video models.  
  **How to use:** Load in Wan video workflows for video compression/quality.

- **wan2.2_vae.safetensors**:  
  **Type:** VAE (Video)  
  **What it does:** VAE for Wan 2.2 video models.  
  **How to use:** Use with Wan 2.2 checkpoints for video processing.

## Text Encoders

Models for processing text prompts into embeddings.

- **umt5_xxl_fp8_e4m3fn_scaled.safetensors**:  
  **Type:** Text Encoder  
  **What it does:** Large text encoder for Wan models, processes complex prompts.  
  **How to use:** Load in Wan workflows for text-to-video generation.

- **gemma_3_12B_it_fp4_mixed.safetensors**:  
  **Type:** Text Encoder  
  **What it does:** Gemma-based text encoder for LTX-2 models.  
  **How to use:** Use in LTX workflows for advanced text understanding.

## Motion Modules / AnimateDiff Models

Used for adding motion to static images in animation workflows.

- **mm_sdxl_v10_beta.ckpt**:  
  **Type:** Motion Module  
  **What it does:** AnimateDiff motion module for SDXL models.  
  **How to use:** Load in AnimateDiff workflows to animate SDXL generations.

- **mm_sd_v15_v2.ckpt**:  
  **Type:** Motion Module  
  **What it does:** AnimateDiff motion module for SD 1.5 models.  
  **How to use:** Use with SD 1.5 checkpoints in animation pipelines.

## Upscalers

Models for increasing image resolution while maintaining quality.

- **4x-UltraSharp.pth**:  
  **Type:** Upscaler  
  **What it does:** 4x upscaling model with sharpening for crisp results.  
  **How to use:** Apply to low-resolution images for high-quality enlargement.

- **RealESRGAN_x4plus.pth**:  
  **Type:** Upscaler  
  **What it does:** Real-ESRGAN model for 4x realistic upscaling.  
  **How to use:** Use in upscaling nodes for general image enhancement.

- **ltx-2-spatial-upscaler-x2-1.0.safetensors**:  
  **Type:** Upscaler (Spatial)  
  **What it does:** Spatial upscaler for LTX-2 video models.  
  **How to use:** Apply in LTX workflows for video resolution enhancement.

## ControlNets

Models for controlling generation with additional inputs like poses or depth.

- **OpenPoseXL2.safetensors**:  
  **Type:** ControlNet  
  **What it does:** Pose detection and control for SDXL models.  
  **How to use:** Input pose images to control figure poses in generation.

## Detection Models

Used for object detection in images.

- **face_yolov8m.pt**:  
  **Type:** Detection Model  
  **What it does:** Face detection model for ADetailer.  
  **How to use:** Use with ADetailer extension for automatic face enhancement.

- **hand_yolov8n.pt**:  
  **Type:** Detection Model  
  **What it does:** Hand detection model for ADetailer.  
  **How to use:** Apply for hand-focused inpainting and enhancement.

## Frame Interpolation Models

Used for creating smooth motion between frames.

- **rife426.pth**:  
  **Type:** Frame Interpolation Model  
  **What it does:** RIFE v4.26 model for frame interpolation.  
  **How to use:** Load in frame interpolation nodes to add intermediate frames to videos.

## Segmentation Models

For image segmentation and masking.

- **sam_vit_b_01ec64.pth**:  
  **Type:** Segmentation Model  
  **What it does:** Segment Anything Model for advanced image segmentation.  
  **How to use:** Use for creating precise masks and selections in images.

## Civitai Downloads

These are model files downloaded via Civitai API. Specific details depend on the model IDs, but generally include specialized checkpoints or LoRAs.

- **Model 152309**: Check Civitai for specific details (likely a specialized checkpoint).  
- **Model 122606**: Check Civitai for specific details (likely a specialized checkpoint).

## Optional Assets

These may not always download successfully but provide additional functionality when available.

- **rife426.pth**: See above under Frame Interpolation Models.  
- **example_pose.png**: Sample pose image for testing ControlNet pose models.
- The full raw URL lists are embedded in `scripts/provision-reliable.sh`, `scripts/provision-core.sh.backup`, and `scripts/fast_restore.sh`. See them directly for the canonical, machine-parsable lists:
  - [scripts/provision-reliable.sh](scripts/provision-reliable.sh)
  - [scripts/provision-core.sh.backup](scripts/provision-core.sh.backup)
  - [scripts/fast_restore.sh](scripts/fast_restore.sh)

- To verify what actually finished downloading on an instance, inspect `/workspace/download-logs/`, `/workspace/download_models.log`, and the ComfyUI model folders under `/workspace/ComfyUI/`.

- If you want a CSV or a machine-friendly manifest of exact URL -> filename lines, I can parse the scripts and generate `installed_manifest.csv` next.

Generated: `docs/installed_assets.md`


---

## New Models Added (2026-02-01)

This section documents models added during the latest provision script update.

### Wan 2.2 Lightning LoRAs (4-Step Generation)

These LoRAs enable ultra-fast video generation with minimal quality loss.

- **wan2.2_t2v_lightx2v_4steps_lora_v1.1_high_noise.safetensors**:
  **Type:** LoRA (Video)
  **What it does:** Enables 4-step text-to-video generation with high noise variant. Reduces generation time by 75% (25 steps → 4 steps).
  **How to use:** Load with Wan 2.2 high_noise model, set steps to 4-6, weight 0.9. Best for quick previews or when speed matters more than maximum quality.

- **wan2.2_t2v_lightx2v_4steps_lora_v1.1_low_noise.safetensors**:
  **Type:** LoRA (Video)
  **What it does:** Enables 4-step text-to-video generation with low noise variant for smoother output.
  **How to use:** Load with Wan 2.2 low_noise model, set steps to 4-6, weight 0.9. Produces cleaner, less grainy videos than high_noise variant.

- **wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors**:
  **Type:** LoRA (Image-to-Video)
  **What it does:** 4-step image-to-video with high noise, converts static images to animated videos rapidly.

- **wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors**:
  **Type:** LoRA (Image-to-Video)
  **What it does:** 4-step image-to-video with low noise for smoother animated conversions.

### Wan 2.2 TI2V (Text+Image-to-Video)

- **wan2.2_ti2v_5B_fp16.safetensors**:
  **Type:** Checkpoint (Video)
  **What it does:** Text+Image-to-Video model combining both text prompts and reference images for video generation. 5B parameters, FP16 precision.

### FLUX Models (Refinement & Inpainting)

- **flux1-krea-dev_fp8_scaled.safetensors**:
  **Type:** Checkpoint (Diffusion)
  **What it does:** FLUX Krea development model, FP8 quantized for efficient refinement and inpainting. Excellent for fixing anatomy issues without full regeneration.

- **clip_l.safetensors** + **t5xxl_fp16.safetensors**:
  **Type:** Text Encoders (FLUX)
  **What they do:** Dual text encoder system for FLUX models. CLIP-L + T5-XXL provide comprehensive prompt understanding.

### LTX-2 Models (Camera Control & Advanced Video)

- **ltx-2-19b-dev-fp8.safetensors**:
  **Type:** Checkpoint (Video)
  **What it does:** LTX-2 19B development model, FP8 quantized for high-quality video generation with camera control support.

- **ltx-2-19b-distilled-lora-384.safetensors**:
  **Type:** LoRA (Video)
  **What it does:** Distilled LoRA for 384 resolution, enables faster generation at lower resolutions. 2-3x faster than full resolution.

### VAE Models

- **lumina_ae.safetensors**:
  **Type:** VAE
  **What it does:** Lumina Image 2.0 autoencoder for advanced image/video encoding. Experimental alternative to standard VAEs.

### Text Encoders

- **gemma_3_12B_it_fp4_mixed.safetensors**:
  **Type:** Text Encoder
  **What it does:** Gemma 3 12B text encoder with instruction tuning, FP4 mixed precision. Required for LTX-2 workflows.

### Fixed/Updated Model URLs

- **umt5_xxl_fp8_e4m3fn.safetensors** (FIXED from umt5_xxl_fp8_e4m3fn_scaled.safetensors)
- **wan2.1_vae.safetensors** (FIXED from wan_2.1_vae.safetensors)

---

## Installation Size Estimate (Updated)

| Category | Count | Est. Size |
|----------|-------|-----------|
| Checkpoints | 12 | 45-50GB |
| LoRAs | 18+ | 5-8GB |
| VAEs | 5 | 1-2GB |
| Text Encoders | 4 | 3-5GB |
| AnimateDiff | 2 | 2-3GB |
| Upscalers | 3 | 500MB |
| ControlNet | 1 | 1-2GB |
| Detectors | 3 | 500MB |
| RIFE | 1 | 200MB |
| **TOTAL** | **47+** | **100GB+** |

**Provisioning Time:** 15-30 minutes on high-speed connection

---

## Workflow Enhancement Status

### Enhanced with Full Metadata
- ✅ **nsfw_ltx_camera_control_hyperdump_scat_video_workflow.json** - Complete metadata, optimized weights, documentation

### Pending Enhancement
- ⏳ 22 additional workflows - Can be enhanced using metadata template from WORKFLOW_GUIDE.md

---

**Last Updated:** 2026-02-01
**Provision Script Version:** v3.0
**Total Assets:** 100GB+ across 47+ models
