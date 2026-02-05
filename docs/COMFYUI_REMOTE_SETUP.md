# ComfyUI Remote Setup Summary

## Current Status ✅

### SSH Tunnel
- **Status:** Active
- **Connection:** `localhost:8080` → `ssh1.vast.ai:13586` → `remote:8188`
- **Access URL:** http://localhost:8080
- **Control:** Press Ctrl+C to close tunnel

### ComfyUI Server
- **Status:** Running
- **Python:** 3.12.12 (conda-forge)
- **PyTorch:** 2.5.1+cu124
- **Attention:** PyTorch (xFormers not needed)
- **GPU:** NVIDIA RTX 4060 Ti (16GB VRAM)
- **VRAM Mode:** NORMAL_VRAM
- **Log:** `/workspace/ComfyUI/user/comfyui.log` (remote)

## Installed Custom Nodes ✅

### Video Generation
- ✅ **ComfyUI-LTXVideo** - LTXVideo model support
  - LTXVideoModelLoader
  - LTXVideoTextEncoderLoader
  - LTXVideoLatentGenerator
  - LTXVideoSampler
  - LTXVideoDecoder

- ✅ **ComfyUI-WanVideoWrapper** - WAN Video 2.2 support
  - Dependencies installed
  - VAE model downloading: `wan_2.1_vae.safetensors`

- ✅ **ComfyUI-AnimateDiff-Evolved** - Advanced animation
- ✅ **ComfyUI-VideoHelperSuite** - Video utilities
- ✅ **ComfyUI-Frame-Interpolation** - Frame interpolation

### Utility Nodes
- ✅ **efficiency-nodes-comfyui**
  - MultiplePathsInput ✅
  - INTConstant ✅
  - easy cleanGpuUsed ✅
  - easy showAnything ✅

- ✅ **rgthree-comfy** (48 nodes loaded)
  - SetNode ✅
  - GetNode ✅

- ✅ **ComfyUI-Custom-Scripts**
  - ImageLoader ✅

### Image Processing
- ✅ **ComfyUI_IPAdapter_plus** - IP-Adapter
- ✅ **ComfyUI_UltimateSDUpscale** - Upscaling
- ✅ **ComfyUI-DepthAnythingV2** - Depth estimation
- ✅ **ComfyUI_Comfyroll_CustomNodes** (175 nodes)

### Segmentation
- ✅ **ComfyUI-Impact-Pack** (dependencies fixed)
  - piexif installed ✅
  - scikit-image installed ✅

### Other
- ✅ **ComfyUI-Manager** - Package management
- ✅ **ComfyUI-GGUF** - GGUF model support

## Missing Nodes (To Install via ComfyUI Manager)

Use the ComfyUI Manager in the web interface to install these:

### Image Processing
- ❌ **ComfyUI-Image-Resize** (ImageResize+)
  - Install via: Manager → Install Custom Nodes → Search "Image Resize"

### 3D Generation
- ❌ **ComfyUI-TripoSR** (TripoSR nodes)
  - TripoSRModelLoader
  - TripoSRSampler
  - TripoSRMeshToGLTF
  - SaveGLTF
  - Install via: Manager → Install Custom Nodes → Search "TripoSR"

### Vision/VQA
- ❌ **ComfyUI-Qwen_VQA** (Qwen3_VQA)
  - Install via: Manager → Install Custom Nodes → Search "Qwen"

## How to Install Missing Nodes

### Method 1: ComfyUI Manager (Recommended)

1. Open ComfyUI: http://localhost:8080
2. Click **Manager** button (wrench icon)
3. Click **Install Custom Nodes**
4. Search for the node name (e.g., "TripoSR")
5. Click **Install**
6. Restart ComfyUI when prompted

### Method 2: SSH Command

```bash
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "cd /workspace/ComfyUI/custom_nodes && git clone <REPO_URL>"
```

**Repository URLs:**
- TripoSR: `https://github.com/VAST-AI-Research/TripoSR-ComfyUI.git`
- Image Resize: `https://github.com/EllangoK/ComfyUI-Image-Resize.git`
- Qwen VQA: `https://github.com/Dobidop/ComfyUI-Qwen-VL-2.git`

### Method 3: ComfyUI Manager Install-Missing

1. Load a workflow with missing nodes
2. Click **Manager** → **Install Missing Custom Nodes**
3. ComfyUI will automatically install all missing nodes
4. Restart when prompted

## Available Models

### Checkpoints
Located at `/workspace/ComfyUI/models/checkpoints/`
- Run `ssh ... "ls -lh /workspace/ComfyUI/models/checkpoints/"` to see available models

### VAE
- ✅ `wan_2.1_vae.safetensors` (downloading)

### To Download More Models

```bash
# Via SSH
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "cd /workspace/ComfyUI/models/<type> && wget <URL>"

# Example: Download a checkpoint
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "cd /workspace/ComfyUI/models/checkpoints && wget https://huggingface.co/.../model.safetensors"
```

## Quick Commands

### Connect to ComfyUI
```powershell
.\scripts\connect-comfy.ps1 -RemoteHost ssh1.vast.ai -SshPort 13586
```

### Check ComfyUI Status
```bash
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "curl -s http://localhost:8188 | head -5"
```

### View Logs
```bash
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "tail -50 /workspace/ComfyUI/user/comfyui.log"
```

### Restart ComfyUI
```bash
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "killall -9 python3; cd /workspace/ComfyUI && /venv/main/bin/python3 main.py --listen 0.0.0.0 --port 8188 > /tmp/comfyui.log 2>&1 &"
```

### Clear Stuck Queue
```bash
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "rm -f /workspace/ComfyUI/user/queue.db*"
```

### Check GPU
```bash
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "nvidia-smi"
```

### Install Python Package
```bash
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "/venv/main/bin/pip install <package>"
```

## Known Issues & Solutions

### Issue: xFormers Not Available
**Status:** Not a problem
**Explanation:** PyTorch attention works fine, xFormers is optional
**Action:** None needed

### Issue: Stuck Checkpoint/Queue
**Cause:** Corrupted queue database
**Solution:**
```bash
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "rm -f /workspace/ComfyUI/user/queue.db*"
```
Then restart ComfyUI

### Issue: Custom Node Import Fails
**Cause:** Missing dependencies
**Solution:**
```bash
# Find requirements.txt in the node folder
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "cd /workspace/ComfyUI/custom_nodes/<NODE_NAME> && /venv/main/bin/pip install -r requirements.txt"
```

### Issue: Port Already in Use
**Solution:**
```bash
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "lsof -ti:8188 | xargs kill -9"
```

## Performance Settings

### Current Configuration
- **VRAM:** NORMAL_VRAM (16GB available)
- **Weight Offloading:** Async with 2 streams
- **Pinned Memory:** 489GB enabled
- **Attention:** PyTorch (not xFormers)

### To Change VRAM Mode
Add flags to ComfyUI startup:
```bash
# Low VRAM mode
python main.py --lowvram

# Normal VRAM mode (current)
python main.py # no flag needed

# High VRAM mode
python main.py --highvram
```

## Next Steps

1. **Install remaining nodes** via ComfyUI Manager web interface
2. **Download models** you need for your workflows
3. **Test workflows** - start with simple ones first
4. **Save workflows** to git for backup

## Documentation References

- [SSH Tunnel Guide](./SSH_TUNNEL_GUIDE.md) - Complete tunneling documentation
- [Claude Learning Log](./CLAUDE.md) - What was learned this session
- [Master Start Guide](./current-workflow/MASTER_START_GUIDE.md) - Project overview

---

**Last Updated:** 2026-02-03
**Remote IP:** ssh1.vast.ai:13586
**Local Access:** http://localhost:8080
**Status:** ✅ Operational
