# 🚀 Quick Start: Full Automation Setup

## What This Does
**Fully automated** GPU rental → ComfyUI boot → NSFW models downloaded → Ready for generation

No SSH. No manual uploads. **Zero intervention after setup.**

---

## One-Time Setup (5 Minutes)

### Step 1: Upload Provisioning Script to GitHub Gist

1. Go to: https://gist.github.com
2. Create a new **public** gist
3. Name it: `comfyui-nsfw-provision.sh`
4. Copy the contents from: `scripts/comfyui-nsfw-provision.sh`
5. Click "Create public gist"
6. Click the "Raw" button and copy the URL (looks like: `https://gist.githubusercontent.com/youruser/abc123/raw/...`)

### Step 2: Set Environment Variables

Edit `start-proxy.ps1` and uncomment these lines:

```powershell
$env:HUGGINGFACE_HUB_TOKEN = "hf_YOUR_TOKEN_HERE"  # Get from: https://huggingface.co/settings/tokens
$env:CIVITAI_TOKEN = "YOUR_CIVITAI_TOKEN"          # Get from: https://civitai.com/user/account
$env:COMFYUI_PROVISION_SCRIPT = "https://gist.githubusercontent.com/youruser/abc123/raw/comfyui-nsfw-provision.sh"
```

### Step 3: Start the Proxy

```powershell
.\start-proxy.ps1
```

---

## That's It! 

Everything else is **automatic**:

1. User clicks "Generate" in UI
2. System finds cheapest GPU (under $0.80/hr)
3. GPU boots with ComfyUI
4. Your provisioning script runs automatically
5. NSFW models download from Hugging Face/Civitai
6. ComfyUI starts with all models loaded
7. Generation happens
8. GPU auto-shuts down after 15 min idle (saves money)

---

## Testing

```powershell
# Check proxy is running
Invoke-RestMethod http://localhost:3000/api/proxy/health

# Manually trigger GPU rental (for testing)
$headers = @{ "x-admin-api-key" = "secure_admin_key_2026" }
Invoke-RestMethod http://localhost:3000/api/proxy/warm-pool/prewarm -Method POST -Headers $headers

# Monitor status (wait for "ready")
Invoke-RestMethod http://localhost:3000/api/proxy/warm-pool -Method GET -Headers $headers
```

---

## Troubleshooting

**"No offers found"**
- Increase price cap in `server/warm-pool.js` (currently $0.80/hr)
- Try again in a few minutes (availability changes)

**Models not downloading**
- Verify `HUGGINGFACE_HUB_TOKEN` and `CIVITAI_TOKEN` are set
- Some models require authentication

**Full documentation:** See `docs/FULL_AUTOMATION_GUIDE.md`
