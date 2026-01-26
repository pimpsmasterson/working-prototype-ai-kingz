# ComfyUI NSFW Model Auto-Provisioning Setup

## Overview
This setup enables **fully automated** GPU instance creation with NSFW models pre-loaded.

## How It Works

### Architecture Flow:
```
1. User clicks "Generate" button
2. Backend checks if GPU is ready
3. If not ready → Rents cheapest GPU from Vast.ai
4. GPU boots → Runs provisioning script automatically
5. Script downloads NSFW models from Hugging Face/Civitai
6. ComfyUI starts with all models loaded
7. Backend polls until ComfyUI responds (ready state)
8. Generation request is forwarded to GPU
9. Result returned to user
10. GPU idles → Auto-terminates after 15 min to save money
```

## Setup Instructions

### Option 1: Use Hosted Provisioning Script (Easiest)

1. **Upload the script to GitHub Gist or your own server:**
   ```bash
   # The script is at: scripts/comfyui-nsfw-provision.sh
   # Upload it to: https://gist.github.com (as a public gist)
   ```

2. **Get the raw URL** (example):
   ```
   https://gist.githubusercontent.com/youruser/abc123/raw/comfyui-nsfw-provision.sh
   ```

3. **Update environment variable:**
   ```powershell
   $env:COMFYUI_PROVISION_SCRIPT = "https://your-gist-url/comfyui-nsfw-provision.sh"
   ```

4. **Restart the proxy:**
   ```powershell
   .\start-proxy.ps1
   ```

### Option 2: Custom Docker Image (Best for Production)

1. **Create a Dockerfile:**
   ```dockerfile
   FROM vastai/comfy:v0.10.0-cuda-12.9-py312
   
   # Copy models into the image
   COPY models/checkpoints/*.safetensors /workspace/ComfyUI/models/checkpoints/
   COPY models/loras/*.safetensors /workspace/ComfyUI/models/loras/
   COPY models/vae/*.safetensors /workspace/ComfyUI/models/vae/
   ```

2. **Build and push:**
   ```bash
   docker build -t yourdockerhub/comfyui-nsfw:latest .
   docker push yourdockerhub/comfyui-nsfw:latest
   ```

3. **Update environment:**
   ```powershell
   $env:VASTAI_COMFY_IMAGE = "yourdockerhub/comfyui-nsfw:latest"
   ```

## Environment Variables Reference

| Variable | Purpose | Example |
|----------|---------|---------|
| `VASTAI_API_KEY` | Your Vast.ai API key | `4986d1c01dc...` |
| `ADMIN_API_KEY` | Admin panel password | `secure_admin_key_2026` |
| `HUGGINGFACE_HUB_TOKEN` | Download gated models | `hf_abc123...` |
| `CIVITAI_TOKEN` | Download from Civitai | `abc123...` |
| `COMFYUI_PROVISION_SCRIPT` | Custom provisioning script URL | `https://...` |
| `VASTAI_COMFY_IMAGE` | Custom Docker image | `user/comfyui-nsfw` |
| `WARM_POOL_IDLE_MINUTES` | Auto-shutdown after idle | `15` (default) |

## What Happens Automatically

✅ **GPU Rental:** When you click "Generate", system finds cheapest GPU under $0.80/hr
✅ **SSH Key:** Automatically registered (no password prompts)
✅ **ComfyUI Boot:** Instance starts with ComfyUI pre-installed
✅ **Model Download:** Provisioning script downloads NSFW models automatically
✅ **Health Check:** Backend polls until ComfyUI responds (marks as "ready")
✅ **Generation:** Your request is automatically forwarded
✅ **Auto-Shutdown:** GPU terminates after 15 min idle to save money

## What You Need to Do (One-Time Setup)

1. **Host the provisioning script** (upload `scripts/comfyui-nsfw-provision.sh` to GitHub Gist)
2. **Set environment variables** (see table above)
3. **Restart the proxy** (`.\start-proxy.ps1`)

That's it! Everything else is automatic.

## Testing the Full Flow

```powershell
# 1. Check proxy health
Invoke-RestMethod http://localhost:3000/api/proxy/health

# 2. Manually trigger GPU rental (for testing)
$headers = @{ "x-admin-api-key" = "secure_admin_key_2026" }
Invoke-RestMethod -Uri http://localhost:3000/api/proxy/warm-pool/prewarm -Method POST -Headers $headers

# 3. Monitor status
Invoke-RestMethod -Uri http://localhost:3000/api/proxy/warm-pool -Method GET -Headers $headers

# 4. Wait for status: "ready" (usually 3-5 minutes)
# Then test generation from the UI
```

## Troubleshooting

**GPU won't boot:**
- Check `VASTAI_API_KEY` is set correctly
- Verify price cap allows offers: Current max is $0.80/hr

**Models not downloading:**
- Check `HUGGINGFACE_HUB_TOKEN` and `CIVITAI_TOKEN` are set
- Some models require authentication

**ComfyUI not responding:**
- SSH into instance: `ssh -i ~/.ssh/id_rsa_vast -p PORT root@ssh8.vast.ai`
- Check logs: `cat /tmp/comfyui.log`
- Verify provisioning script ran: `ls /workspace/ComfyUI/models/checkpoints/`

**Proxy crashes:**
- Check error logs in terminal
- Common issue: No GPU offers available (increase price cap or wait)
