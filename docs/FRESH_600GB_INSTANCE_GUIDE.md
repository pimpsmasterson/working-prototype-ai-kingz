# Fresh 600GB Instance Setup Guide

**Date:** 2026-02-04
**Objective:** Provision fresh Vast.ai instance with 600GB disk, verify SSH access, and validate against Dropbox manifest

## Overview

This guide walks through setting up a fresh instance from scratch with:
- ✅ 600GB minimum disk space
- ✅ SSH access configured and tested
- ✅ Dropbox API validation
- ✅ Manifest verification (Dropbox vs. local instance)
- ✅ Complete workspace backup with workflows

## Dropbox Structure

Your Dropbox has two critical folders:

### 1. `/pornmaster100` (Legacy Models - 14 files)
```
dreamshaper_8.safetensors (2.0GB)
[Rajii] Artist Style V2 Illustrious.safetensors (55MB)
DR34MJOB_I2V_14b_LowNoise.safetensors (293MB)
pony_realism_v2.2.safetensors (6.6GB)
pmXL_v1.safetensors (6.6GB)
wai_illustrious_sdxl.safetensors (6.5GB)
fondled.safetensors (343MB)
wan_dr34ml4y_all_in_one.safetensors (293MB)
wan_dr34mjob.safetensors (171MB)
twerk.safetensors (49MB)
pornmasterPro_noobV6.safetensors (6.6GB)
expressiveh_hentai.safetensors (686MB)
sdxl_vae.safetensors (319MB)
ponyDiffusionV6XL.safetensors (6.5GB)
```

### 2. `/workspace/pornmaster100` (PRODUCTION - Full Workspace)
```
Total: 321 folders, 1,680 files
- Complete ComfyUI installation
- All custom nodes installed
- User settings and workflows
- Provision logs and download history
```

## Prerequisites

### 1. Environment Variables Updated

Your `.env` file has been updated with:
```bash
# Fresh Dropbox token (generated 2026-02-04)
DROPBOX_TOKEN=sl.u.AGRm4deQ9ozVbXwLZxABO3AgpDAVaaQdGp9WSyEjgEgejmCCh23mQhszl1eGa2leg8V4xxqReT1dRxOk-TEf5xQgZlaa8ZCkH6pooW43hghA8_god-rBBHjnW1wAyesYo76WtgrSUx0ESpaM7rY3RrAk4K57VXtY1sr2nEj0RtNWQPgGyhOe4y0zS_VADbgL0zg9nQ0ucnIx4dVjFjM8osRRmzgq5m5qx6ykXwAKQJqUTtpeVIw8_ZzCmIESDzJixbnW1mQ1yhxPn37NGeJncy2RLDKSneI0p1hlcGwUdV2WRN0my9rYfz3d7vh2SQHreIAIXAH0VB92Svz6-SZc307egOC_yGOXOXzXhlJ_if2X0dA6fT34IfeAh8uXmhxENnt-0Zg8VrmDdm3zrLDyjOSB1jNXQSRTro-Z2vfAUDXlJxUi3HGKBQCtbdY5K_Pb3N572AxaJ6RDdik-sb6UM5UeY8zg5JpnR9O-e5a90MDqhEgWWlwC_-tHq0Xv2PWKj-gP90hEBPbTRYmqF7mimZ_ndR987mB-eVaQEhkTjIDmp5C6u7vowgTjdhFp4KK0S5qv5vToGAuIniCp6sACnFZizzdJTVseM-T2Dw3NAvnk4at002smJr9sYHReMINcNSMIBNPGOnR_7f38xgH92Bu0zKjs8Pr3r56Iu5Bl6kmbsoF2nUtiNvoRsVbEmOPP7QocxkWl2ZN7zV4Qb5_-kJlGkqlw7qZFb-w8esKsJg1lA6LNHKD3H5goChY32ll0luRxDfpi128-sNObjIQkF3zDA6_1l9KOxZIM5zAAVA_8hglVuwjOcsNsG9ZW1zr3zEasTc3YNUfSNCH8s5etymCj1KSSe4UoKhnvhZ-DwF0Bt_WxB2pddJdfXJcvFqtyLLUApjLofIHjZKL7bewXUzhqJ7qpEcLQZsVqbm4MPh3NpiddCIrog8xRX0Aevk45HDdrEPgKNnWccjwQwd1Md8VSPwALZQvoYACfnpkxZ7I9iYTgZP6eovI5l7Rg3s3rT0TdBEl3Bw5NEKpzorbCcECdOt7L1uI9oGhDCxKWJA21JSiAhsm92A7CeJl15Fq9EELgf0sSWtOIHU4SM8Mw1LR_-5w5VHbfIw-rijU4luWcNRsXDaCKoO1Lhogu4eCbEoN4gW_ucedHz7kWTObvpVK2AFVv1iTmqXs15mBaU4ANzY7f4ycM-DRYK9SPZjLOq-yE0cmRpnJuFvJ9nFm8idsmRO9-gevrLP9THu8bYSex_x35coXnzTa9VHoMUlpl5PHIznurojT1idxUShjf18IETNWDH2_W6P8_0l6rnPObLvsl_TB_VmbzGE1ChdtaVh_9xxsVTM1sZXNC_BvOTsJOxE9BHfU43iDtTzNFs3YZC4KaPS_Z2YeSM_JSsNpWfhM12_17eNmYb7IO6y1qIOvU

# Full workspace backup folder (use this for complete restoration)
DROPBOX_FOLDER=/workspace/pornmaster100

# Legacy models folder (older, 14 files only)
DROPBOX_MODELS_FOLDER=/pornmaster100

# Updated to 600GB minimum
WARM_POOL_DISK_GB=600
```

### 2. Dropbox API Verification

Test your token (already validated successfully):
```powershell
node -e "const token=process.env.DROPBOX_TOKEN || require('dotenv').config() && process.env.DROPBOX_TOKEN; console.log('Token valid:', !!token, 'Length:', token?.length)"
```

Expected output: `Token valid: true Length: 2048`

## Step 1: Clean State

Before starting, ensure no old instance data:

```powershell
# Navigate to project
cd "c:\Users\samsc\OneDrive\Desktop\working protoype"

# Clear old database
node -e "const db=require('./server/db'); const s=db.getState(); s.instance=null; s.isPrewarming=false; s.provisionAttempt=0; db.saveState(s); console.log('✓ Database cleared');"

# Kill any old processes
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force
```

## Step 2: Start Server with All Environment Variables

```powershell
# Start server (all env vars loaded from .env)
pm2 delete vastai-proxy 2>$null
pm2 start config/ecosystem.config.js --update-env
pm2 save

# Verify server is running
Start-Sleep -Seconds 5
curl http://localhost:3000/api/proxy/health
```

Expected output:
```json
{
  "status": "running",
  "ok": true,
  "warmPool": {
    "enabled": true,
    "diskRequirement": "600GB"
  }
}
```

## Step 3: Trigger Prewarm (Rent 600GB Instance)

```powershell
$headers = @{ 'x-admin-api-key' = '64d94046-d1b0-447d-9b2d-55b2d5bf0744' }
$response = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool/prewarm" -Headers $headers -Method POST
$response | ConvertTo-Json -Depth 6
```

**Monitor provisioning** (run every 30 seconds):
```powershell
$status = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool/status" -Headers @{ 'x-admin-api-key' = '64d94046-d1b0-447d-9b2d-55b2d5bf0744' }
$status | ConvertTo-Json -Depth 5
```

Look for:
- `status: "provisioning"` → Models downloading (10-15 minutes)
- `status: "ready"` → Instance ready for SSH

## Step 4: SSH Access Verification

### Option A: Automatic Connection Script

```powershell
.\scripts\connect-comfy.ps1
```

This script will:
1. Query Vast.ai API for running instances
2. Extract SSH host/port
3. Create SSH tunnel: `localhost:8080` → `remote:8188`
4. Open browser to `http://localhost:8080`

### Option B: Manual SSH Connection

```powershell
# Get instance SSH details
$headers = @{ 'Authorization' = "Bearer $env:VASTAI_API_KEY" }
$instances = (Invoke-RestMethod -Uri 'https://console.vast.ai/api/v0/instances/?owner=me' -Headers $headers).instances
$inst = $instances | Where-Object { $_.status -eq 'running' } | Select-Object -First 1

# Display SSH info
Write-Host "SSH Host: $($inst.ssh_host)"
Write-Host "SSH Port: $($inst.ssh_port)"

# Connect via SSH
ssh -i "$env:USERPROFILE\.ssh\id_rsa_vast" -p $inst.ssh_port root@$inst.ssh_host
```

### Verify SSH Works

Once connected, run:
```bash
# Check disk space (should show ~600GB)
df -h

# Check GPU
nvidia-smi

# Check ComfyUI is running
curl http://localhost:8188 | head -20

# Check provision logs
tail -100 /workspace/provision_v3.log
```

## Step 5: Dropbox Manifest Verification

### 5A: Generate Manifest from Dropbox

```powershell
# List all model files in Dropbox workspace
node scripts/dropbox_create_links.js --find /workspace/pornmaster100 > data/dropbox_manifest.txt
```

### 5B: Audit Against Instance

Run the Python audit script to compare Dropbox vs. instance:

```powershell
# Ensure Python dependencies installed
pip install -r requirements.txt

# Run audit (outputs JSON report)
python scripts/audit_dropbox_assets.py > audit_report.json 2>&1

# View summary
cat audit_report.json | jq '.summary'
```

Expected output:
```json
{
  "total_manifested": 45,
  "total_found": 1680,
  "missing_count": 0,
  "extra_count": 1635,
  "size_mismatch_count": 0
}
```

**Notes:**
- `missing_count: 0` = All required models present
- `extra_count` = Dropbox has full workspace (custom nodes, configs, etc.)

### 5C: Download Missing Files (if any)

If audit shows missing files, SSH to instance and download:

```bash
# SSH to instance first
ssh -i ~/.ssh/id_rsa_vast -p <PORT> root@<HOST>

# Download missing model (example)
cd /workspace/ComfyUI/models/checkpoints
wget https://huggingface.co/path/to/model.safetensors
```

## Step 6: Verify ComfyUI Functionality

### 6A: Check Web Interface

Open browser: `http://localhost:8080` (via SSH tunnel)

### 6B: Verify Custom Nodes

In ComfyUI interface, check that these nodes are available:
- FaceDetailer (Impact Pack)
- UltimateSDUpscale
- DepthAnythingV2
- VideoHelperSuite
- AnimateDiff-Evolved
- Frame-Interpolation
- ComfyUI-Manager

### 6C: Load Test Workflow

From local `scripts/workflows/` folder, drag-and-drop a workflow JSON into ComfyUI.

If workflow loads without errors → SUCCESS!

## Step 7: Backup Instance Configuration

Once instance is fully working, create a backup:

```bash
# SSH to instance
cd /workspace
tar -czf comfyui_backup_$(date +%Y%m%d).tar.gz ComfyUI/

# Upload to Dropbox (optional)
# Use Dropbox API or web interface
```

## Troubleshooting

### ❌ Prewarm Fails: "No instances found"

**Cause:** High demand or restrictive filters

**Solution:**
```powershell
# Check Vast.ai availability manually
curl -H "Authorization: Bearer $env:VASTAI_API_KEY" `
  "https://console.vast.ai/api/v0/bundles/?q={%22verified%22:{%22eq%22:true},%22external%22:{%22eq%22:false},%22rentable%22:{%22eq%22:true},%22disk_space%22:{%22gte%22:600}}" | jq '.offers | length'
```

If 0 offers, lower disk requirement temporarily or wait for availability.

### ❌ SSH Connection Refused

**Symptoms:**
```
ssh: connect to host ssh1.vast.ai port 12345: Connection refused
```

**Solutions:**
1. Verify instance is running: Check Vast.ai dashboard
2. Wait 2-3 minutes after provision completes
3. Check SSH key is registered: Vast.ai → Account → SSH Keys

### ❌ Dropbox Token Expired

**Symptoms:**
```
Error: Dropbox API error: expired_access_token
```

**Solution:**
1. Generate new token: https://www.dropbox.com/developers/apps
2. Update `.env` file with new `DROPBOX_TOKEN`
3. Restart server: `pm2 restart vastai-proxy`

### ❌ Manifest Shows Missing Files

**Check:**
1. Does `/pornmaster100` have the files? (14 models)
2. Does `/workspace/pornmaster100` have the files? (full workspace)
3. Did provision script run successfully? Check `/workspace/provision_v3.log`

**Fix:**
- Re-run provisioning with correct `DROPBOX_FOLDER` in `.env`
- Manually download missing files via wget/curl

### ❌ ComfyUI Not Responding on :8188

**Check:**
```bash
# SSH to instance
ps aux | grep python | grep ComfyUI
curl http://localhost:8188
tail -50 /workspace/comfyui.log
```

**Restart:**
```bash
pkill -f "python.*main.py"
cd /workspace/ComfyUI
nohup python main.py --listen 0.0.0.0 --port 8188 > /workspace/comfyui.log 2>&1 &
```

## Quick Command Reference

### Health Check
```powershell
curl http://localhost:3000/api/proxy/health
```

### Status Check
```powershell
$h=@{'x-admin-api-key'='64d94046-d1b0-447d-9b2d-55b2d5bf0744'}; (Invoke-RestMethod -Uri http://localhost:3000/api/proxy/admin/warm-pool/status -Headers $h).instances
```

### SSH Tunnel
```powershell
$h=@{'Authorization'="Bearer $env:VASTAI_API_KEY"}; $i=(Invoke-RestMethod -Uri https://console.vast.ai/api/v0/instances/?owner=me -Headers $h).instances[0]; ssh -i ~/.ssh/id_rsa_vast -p $i.ssh_port -L 8080:localhost:8188 root@$i.ssh_host
```

### Terminate Instance
```powershell
$h=@{'x-admin-api-key'='64d94046-d1b0-447d-9b2d-55b2d5bf0744'}; Invoke-RestMethod -Uri http://localhost:3000/api/proxy/admin/warm-pool/terminate -Headers $h -Method POST
```

## Success Criteria

✅ **Instance Running:** Vast.ai shows status "running"  
✅ **SSH Access:** Can connect via ssh without errors  
✅ **Disk Space:** `df -h` shows ≥600GB available  
✅ **GPU Available:** `nvidia-smi` shows GPU details  
✅ **ComfyUI Responsive:** `curl http://localhost:8188` returns HTML  
✅ **Manifest Verified:** `audit_report.json` shows `missing_count: 0`  
✅ **Custom Nodes Loaded:** ComfyUI interface shows all expected nodes  
✅ **Workflow Loads:** Test workflow JSON loads without errors  

## Next Steps

1. **Test Generation:** Queue a simple workflow (SD1.5 txt2img)
2. **Save Configuration:** Backup working instance to Dropbox
3. **Document Changes:** Update manifest if new models added
4. **Monitor Costs:** Set up auto-terminate on idle

## Support

- **Provision script logs:** `/workspace/provision_v3.log`
- **ComfyUI logs:** `/workspace/comfyui.log`
- **Download logs:** `/workspace/download-logs/*.log`
- **Server logs:** `pm2 logs vastai-proxy`

---

**Last Updated:** 2026-02-04
**Status:** Ready for fresh instance provisioning
