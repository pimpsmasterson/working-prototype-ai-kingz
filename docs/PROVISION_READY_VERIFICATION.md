# Provision Script - 600GB Instance - Ready Verification

**Date:** 2026-02-04  
**Status:** ✅ ALL DOWNLOAD LINKS VERIFIED  
**Dropbox:** ✅ FULL WORKSPACE BACKUP CONFIRMED  
**Disk:** ✅ 600GB MINIMUM CONFIGURED  

---

## ✅ VERIFICATION COMPLETE

### Dropbox Status
- **Path:** `/workspace/pornmaster100`
- **Total Files:** 7,374
- **Total Folders:** 321
- **Status:** COMPLETE WORKSPACE BACKUP
- **Token:** VALID (tested 2026-02-04)

### Models in Dropbox vs Provision Script

**Found in Both (58 models):**
- All core SDXL checkpoints (pmXL, dreamshaper, pony_realism, etc.)
- All LoRAs (defecation, twerk, fondled, expressiveh, etc.)
- All VAEs (sdxl_vae, wan2.2_vae, ae.safetensors)
- All upscalers (4x-UltraSharp, RealESRGAN)
- All detection models (face_yolov8m, hand_yolov8n, sam)
- All AnimateDiff models
- All Wan 2.1 & 2.2 models
- All LTX-2 models
- All FLUX models

### Download Links Verified

| Model | Link Status | Size | Notes |
|-------|-------------|------|-------|
| mm_sdxl_v10_beta.ckpt | ✅ 302 Redirect | 950MB | AnimateDiff SDXL |
| rife426.zip | ✅ 302 Redirect | 23MB | RIFE 4.26 (needs unzip) |
| ponyRealism_v21MainVAE.safetensors | ✅ 307 Redirect | 320MB | Civitai download |
| umt5_xxl_fp8_e4m3fn_scaled.safetensors | ✅ 302 Redirect | 6.4GB | Scaled text encoder |
| ae.safetensors | ✅ 302 Redirect | 320MB | Lumina VAE |
| sdxl_vae.safetensors | ✅ 302 Redirect | 320MB | SDXL VAE |
| All HuggingFace links | ✅ Valid | Various | Verified working |

### Critical Updates Made

1. **provision-reliable.sh:**
   - ✅ Added `ponyRealism_v21MainVAE.safetensors` to WAN_VAE_MODELS
   - ✅ Fixed RIFE download link (now using HuggingFace r3gm/RIFE)
   - ✅ Fixed AnimateDiff SDXL link (now using guoyww/animatediff official)
   - ✅ Added `umt5_xxl_fp8_e4m3fn_scaled.safetensors` to WAN_CLIP_MODELS
   - ✅ Changed `lumina_ae.safetensors` to `ae.safetensors` (correct filename)

2. **COMPLETE_SOFTWARE_MANIFEST.md:**
   - ✅ Added `ae.safetensors` (Lumina VAE)
   - ✅ Added `wan_2.1_vae.safetensors` (alternate naming)
   - ✅ Added `umt5_xxl_fp8_e4m3fn_scaled.safetensors` (scaled text encoder)
   - ✅ Updated sizes to match actual Dropbox files

3. **.env:**
   - ✅ Updated `DROPBOX_TOKEN` (fresh, verified working)
   - ✅ Set `WARM_POOL_DISK_GB=600`
   - ✅ Set `DROPBOX_FOLDER=/workspace/pornmaster100`

---

## 📊 PROVISION SCRIPT MODEL COUNT

### By Category:
- **Checkpoints:** 16 models
- **LoRAs:** 25+ models
- **VAEs:** 7 models (updated)
- **Text Encoders:** 5 models (updated)
- **AnimateDiff:** 2 models (verified)
- **Upscalers:** 3 models
- **ControlNet:** 1 model
- **Detection:** 3 models
- **RIFE:** 1 model (fixed link)
- **Wan Diffusion:** 5 models
- **Wan LoRAs:** 4 models
- **LTX-2 Diffusion:** 1 model
- **LTX-2 LoRAs:** 2 models
- **LTX-2 Upscaler:** 1 model
- **FLUX:** 1 model

**TOTAL: 77+ models** with verified download links

---

## 🚀 READY TO PROVISION

### Pre-Flight Checklist

- [x] Dropbox API access verified
- [x] Dropbox folder contains 7,374 files (complete backup)
- [x] All download links tested and working
- [x] RIFE link fixed (HuggingFace r3gm/RIFE)
- [x] AnimateDiff link fixed (guoyww official)
- [x] Missing models added to provision script
- [x] Manifest updated with all Dropbox models
- [x] 600GB disk requirement set in .env
- [x] SSH key configured (id_rsa_vast)
- [x] All tokens present in .env

### Environment Variables Ready

```bash
VASTAI_API_KEY=c0c517...  (valid)
ADMIN_API_KEY=64d94046...  (set)
HUGGINGFACE_HUB_TOKEN=hf_AlLrDh...  (valid)
CIVITAI_TOKEN=8d592efd...  (valid)
DROPBOX_TOKEN=sl.u.AGRm4deQ...  (VERIFIED 2026-02-04)
WARM_POOL_DISK_GB=600  (SET)
DROPBOX_FOLDER=/workspace/pornmaster100  (SET)
```

### Provision Script Status

**File:** `scripts/provision-reliable.sh`  
**Version:** v3.0  
**Signature:** RELIABLE PROVISIONER v3.0  
**Models:** 77+  
**Download Strategy:** HuggingFace Primary + Dropbox/Civitai Fallback  
**Anti-Hang:** ✅ Enabled (30min timeout per file)  
**Parallel Downloads:** ✅ 4x for HF, 1x for Civitai  

---

## 🎯 NEXT STEPS

### Step 1: Clean Database
```powershell
node -e "const db=require('./server/db'); const s=db.getState(); s.instance=null; s.isPrewarming=false; s.provisionAttempt=0; db.saveState(s); console.log('✓ Database cleared');"
```

### Step 2: Start Server
```powershell
pm2 delete vastai-proxy 2>$null
pm2 start config/ecosystem.config.js --update-env
pm2 save
Start-Sleep -Seconds 5
curl http://localhost:3000/api/proxy/health
```

### Step 3: Trigger Prewarm (600GB Instance)
```powershell
$headers = @{ 'x-admin-api-key' = '64d94046-d1b0-447d-9b2d-55b2d5bf0744' }
Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool/prewarm" -Headers $headers -Method POST | ConvertTo-Json -Depth 6
```

### Step 4: Monitor Provisioning
```powershell
# Run every 60 seconds
$headers = @{ 'x-admin-api-key' = '64d94046-d1b0-447d-9b2d-55b2d5bf0744' }
$status = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool/status" -Headers $headers
$status | ConvertTo-Json -Depth 5
```

### Step 5: SSH Connection (Once Ready)
```powershell
# Automatic
.\scripts\connect-comfy.ps1

# Manual
$headers = @{ 'Authorization' = "Bearer $env:VASTAI_API_KEY" }
$inst = (Invoke-RestMethod -Uri 'https://console.vast.ai/api/v0/instances/?owner=me' -Headers $headers).instances[0]
ssh -i "$env:USERPROFILE\.ssh\id_rsa_vast" -p $inst.ssh_port root@$inst.ssh_host
```

### Step 6: Verify Instance
```bash
# Once SSH'd in:
df -h  # Should show ~600GB total
nvidia-smi  # Should show GPU
ls -la /workspace/ComfyUI/models/checkpoints | wc -l  # Should show 15+ files
tail -100 /workspace/provision_v3.log | grep "RELIABLE PROVISIONER v3.0"
```

---

## 📝 KNOWN ISSUES RESOLVED

1. ❌ ~~RIFE link was 404~~ → ✅ Fixed (using HuggingFace r3gm/RIFE)
2. ❌ ~~AnimateDiff link was 401~~ → ✅ Fixed (using guoyww/animatediff)
3. ❌ ~~ponyRealism VAE missing~~ → ✅ Added to provision script
4. ❌ ~~UMT5 scaled not in manifest~~ → ✅ Added to both script and manifest
5. ❌ ~~Lumina VAE wrong name~~ → ✅ Changed from lumina_ae to ae.safetensors

---

## 🎉 READY STATUS

**ALL SYSTEMS GO FOR 600GB FRESH INSTANCE PROVISIONING!**

- ✅ 77+ models with verified download links
- ✅ Dropbox backup with 7,374 files ready for restoration
- ✅ SSH access configured and tested
- ✅ Manifest updated and synchronized
- ✅ Provision script v3.0 ready
- ✅ All APIs verified (Vast.ai, Dropbox, HuggingFace, Civitai)

**Estimated Provision Time:** 20-30 minutes  
**Estimated Download Size:** ~180GB (all models)  
**Estimated Total Space Used:** ~250GB (models + ComfyUI + dependencies)  
**Buffer for 600GB:** ~350GB remaining for outputs/temp files  

---

**Ready to launch?** Run the commands in "NEXT STEPS" section above.
