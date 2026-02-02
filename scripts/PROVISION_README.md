# 🚀 AI Kings ComfyUI Provisioning Scripts v3.0

## Two-Script System (FAST & MODULAR)

### ✅ `provision-core.sh` - Essential Setup (Run This First!)
Gets ComfyUI up and running FAST - **NO workflows**

**What it does:**
- ✅ System packages & dependencies
- ✅ PyTorch 2.5.1+cu124 (Python 3.12 compatible)
- ✅ ComfyUI + 14 custom nodes
- ✅ All essential models (checkpoints, LoRAs, Wan, Flux)
- ✅ Starts ComfyUI on port 8188
- ✅ **FAST**: 10-20 min vs 30+ min with workflows

**Usage:**
```bash
# SSH into your Vast.ai instance
ssh root@YOUR_IP -p 22

# Run core provisioning
cd /workspace
bash scripts/provision-core.sh

# When done, access ComfyUI at:
# http://YOUR_IP:8188
```

**What you get:**
- 🎨 ComfyUI running and ready to use
- 📦 All models downloaded (checkpoints, LoRAs, Wan, Flux)
- 🧩 All custom nodes installed
- 🚀 Can start using ComfyUI immediately!

---

### 📝 `provision-workflows.sh` - Workflows Only (Optional)
Installs pre-built workflows - **run after core completes**

**Status:** Currently a placeholder (workflows coming soon)

**Usage:**
```bash
# Run AFTER provision-core.sh completes
bash scripts/provision-workflows.sh
```

---

## Quick Start Guide

### 1️⃣ **Upload Scripts to Vast.ai**

Option A - Git (if using repo):
```bash
cd /workspace
git clone YOUR_REPO_URL
cd YOUR_REPO
```

Option B - Direct upload:
```bash
# From your local machine
scp scripts/provision-core.sh root@YOUR_IP:/workspace/scripts/
```

Option C - Manual paste:
```bash
# SSH in and create the file
nano /workspace/scripts/provision-core.sh
# Paste content, save (Ctrl+X, Y, Enter)
```

### 2️⃣ **Set Environment Tokens**

```bash
# On Vast.ai instance
export CIVITAI_TOKEN="your_civitai_token_here"
export HUGGINGFACE_HUB_TOKEN="your_hf_token_here"
```

### 3️⃣ **Run Core Provisioning**

```bash
cd /workspace
bash scripts/provision-core.sh
```

**Watch for:**
- CPU usage should spike to 50-95%
- Models downloading (watch the log)
- "ComfyUI started on port 8188" message

### 4️⃣ **Access ComfyUI**

```bash
# Get your instance IP from Vast.ai dashboard
# Open in browser:
http://YOUR_VAST_IP:8188
```

---

## Monitoring Progress

### Watch the log in real-time:
```bash
tail -f /workspace/provision_core.log
```

### Check if ComfyUI is running:
```bash
ps aux | grep main.py
curl http://localhost:8188
```

### Check resource usage:
```bash
top
nvidia-smi  # GPU usage
```

---

## Troubleshooting

### ❌ Script exits immediately
```bash
# Check for errors
tail -50 /workspace/provision_core.log | grep -i error
```

### ❌ PyTorch installation fails
```bash
# Check Python version
python3 --version  # Should be 3.11 or 3.12

# Check CUDA
nvidia-smi  # Should show CUDA 12.x
```

### ❌ Models fail to download
```bash
# Check tokens are set
echo $CIVITAI_TOKEN
echo $HUGGINGFACE_HUB_TOKEN

# Some download failures are OK (script continues)
```

### ❌ ComfyUI won't start
```bash
# Check the log
tail -100 /workspace/comfyui.log

# Try starting manually
cd /workspace/ComfyUI
source /venv/main/bin/activate
python main.py --listen 0.0.0.0 --port 8188
```

---

## Key Improvements in v3.0

| Feature | Old (v2.2) | New (v3.0 Core) |
|---------|------------|-----------------|
| **Speed** | 30-45 min | 10-20 min |
| **Script Size** | 2000+ lines | ~500 lines |
| **Workflows** | Embedded | Separate script |
| **Debugging** | Hard | Easy |
| **xformers** | Conflicts | Removed |
| **Errors** | Fatal | Continues |

---

## Files Created

After running `provision-core.sh`:

```
/workspace/
├── ComfyUI/              # ComfyUI installation
│   ├── models/           # All downloaded models
│   ├── custom_nodes/     # 14 custom nodes
│   └── main.py           # ComfyUI entry point
├── venv/                 # Python virtual environment
├── provision_core.log    # Provisioning log
├── comfyui.log          # ComfyUI runtime log
├── comfyui.pid          # ComfyUI process ID
└── scripts/
    ├── provision-core.sh      # This script
    └── provision-workflows.sh # Workflows (optional)
```

---

## Next Steps

1. ✅ Run `provision-core.sh` to get ComfyUI running
2. ✅ Access ComfyUI at `http://YOUR_IP:8188`
3. 📝 Create your own workflows in the UI, or
4. 📝 Wait for `provision-workflows.sh` to be populated with templates

---

## Support

- **GitHub Issues**: Report bugs in the repo
- **Logs**: Always include `/workspace/provision_core.log` when reporting issues
- **Vast.ai**: Check instance has enough disk space (400GB recommended)

---

**🎉 Enjoy your fast, lean ComfyUI setup!**
