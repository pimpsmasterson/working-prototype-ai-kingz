# ComfyUI Post-Setup (Manual steps & 20GB essentials)

This document describes the recommended manual steps once a minimal ComfyUI instance is running (via `quick-comfyui-setup.ps1` or similar). The goal is to keep the initial footprint <= 20GB while allowing you to install nodes and models via the ComfyUI Manager UI.

---

## 1. Access ComfyUI
- If the instance exposes `comfy_url`, open that (e.g., `http://<ip>:8188` or the tunnel URL shown).
- If you only have SSH, set up an SSH tunnel:
  - ssh -i ~/.ssh/id_rsa_vast -L 8188:localhost:8188 -p <port> root@<host>
  - Open http://localhost:8188 in your browser

## 2. Use ComfyUI Manager UI to install nodes (recommended order)
1. Open the Manager from the top-right of ComfyUI UI (Manager button).
2. Install *only what you need* initially. Recommended start list:
   - ComfyUI Manager (core plugin if not present)
   - ControlNet (if you plan to use images with structure)
   - Upscale node (x4-UltraSharp)
   - AnimateDiff (only if you need video/animation features)
3. Install one node at a time and click "Restart ComfyUI" when prompted.

Tip: Avoid installing large node bundles (video/wan) until you need them.

## 3. Download essential models (stay within ~20GB)
Suggested minimal model set (approx sizes):
- SDXL Base checkpoint (approx 6.0 GB)
- SDXL VAE (approx 0.3 GB)
- 2-4 small LoRAs (combined 2-3 GB)
- One upscaler model (0.2-1.0 GB)

Estimated total:
- ComfyUI + Python env: ~5 GB
- Models and LoRAs: ~11 GB
- System overhead / buffer: ~3 GB
- Total: ~19 GB (safe under 20 GB)

How to download via UI:
- Manager -> Models -> Add from HuggingFace/Civitai (enter repo-model or direct file URL)
- Alternatively, use wget/curl on the instance and place files under `ComfyUI/models/checkpoints` or `ComfyUI/models/vae` etc.

Example commands (SSH into instance):
```bash
# SDXL base (change URL to official file)
wget -O /root/ComfyUI/models/checkpoints/sdxl-base.ckpt "https://huggingface.co/...."
# VAE
wget -O /root/ComfyUI/models/vae/sdxl-vae.ckpt "https://huggingface.co/...."
```

## 4. Verify and test
- Restart ComfyUI after installing models/nodes.
- Test a simple generation using a small image size and one-step pipeline to validate GPU and model.

## 5. Disk & Cost Control
- Keep `WARM_POOL_IDLE_MINUTES` low (5-15 min) while iterating.
- Remove unused models or move them to cloud storage (Dropbox / S3) when not needed.
- Snapshot the instance if you have a good working image to avoid re-provisioning from scratch.

## 6. If you need more models or nodes later
- Expand slowly; install 1-2 nodes then test.
- Prefer manual downloads via the Manager UI to avoid large upfront downloads during provisioning.

---

If you'd like, I can: (A) create a short checklist you can follow in the UI, (B) add explicit download links for recommended SDXL / VAE files, or (C) add small helper scripts to download specified models to the instance. Which would you prefer next?