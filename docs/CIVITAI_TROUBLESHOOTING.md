# Civitai Model Download Troubleshooting Guide

## Problem: Civitai Models Not Downloading During Provisioning

If Civitai models (Pony Diffusion V6 XL, Pornmaster v1.5) aren't downloading during instance provisioning, here are the likely causes and fixes:

---

## Issue #1: Civitai API Format (MOST LIKELY)

### Problem
The provision script uses `Authorization: Bearer` header, but **Civitai API uses query parameters**:
```bash
# ❌ WRONG (current script)
wget --header="Authorization: Bearer $CIVITAI_TOKEN" "https://civitai.com/api/download/models/290640"

# ✅ CORRECT (should be)
wget "https://civitai.com/api/download/models/290640?token=$CIVITAI_TOKEN"
```

### How to Verify
SSH to a running instance and test manually:
```bash
# Check if token is available
echo $CIVITAI_TOKEN

# Test with Bearer header (will likely fail)
wget --header="Authorization: Bearer $CIVITAI_TOKEN" \
  "https://civitai.com/api/download/models/290640?type=Model&format=SafeTensor" \
  -O /tmp/test_model.safetensors

# Test with query parameter (should work)
wget "https://civitai.com/api/download/models/290640?type=Model&format=SafeTensor&token=$CIVITAI_TOKEN" \
  -O /tmp/test_model_query.safetensors
```

### Fix
Update the provision script's `provisioning_download()` function:

**Current (broken):**
```bash
if [[ -n "$CIVITAI_TOKEN" && "$url" =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com ]]; then
    auth_token="$CIVITAI_TOKEN"
fi

if [[ -n "$auth_token" ]]; then
    wget --header="Authorization: Bearer $auth_token" \
        -qnc --content-disposition --show-progress \
        -e dotbytes=4M --timeout=60 --tries=3 \
        -P "$dir" "$url"
```

**Fixed:**
```bash
if [[ -n "$CIVITAI_TOKEN" && "$url" =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com ]]; then
    # Civitai uses query parameter, not Bearer header
    if [[ "$url" == *"?"* ]]; then
        url="${url}&token=${CIVITAI_TOKEN}"
    else
        url="${url}?token=${CIVITAI_TOKEN}"
    fi
fi

# Download (no auth header needed for Civitai anymore)
wget -qnc --content-disposition --show-progress \
    -e dotbytes=4M --timeout=60 --tries=3 \
    -P "$dir" "$url"
```

---

## Issue #2: Token Not Exported in Remote Shell

### Problem
Environment variables passed via Vast.ai's `env` parameter may not be exported to subshells created by the `onstart` bash script.

### How to Verify
Check provisioning logs on the instance:
```bash
# SSH to instance
ssh root@<instance_ip> -p <ssh_port> -i ~/.ssh/vastai_key

# Check if token was set
grep -i "CIVITAI_TOKEN" /workspace/*.log

# Check environment at runtime
env | grep CIVITAI
```

### Fix
Update [server/warm-pool.js](server/warm-pool.js#L720) to explicitly export tokens in the `onstart` command:

```javascript
onstart: `bash -c "export CIVITAI_TOKEN='${process.env.CIVITAI_TOKEN || ''}' HUGGINGFACE_HUB_TOKEN='${process.env.HUGGINGFACE_HUB_TOKEN || ''}' && curl -fsSL ${provisionScript} | bash && cd /workspace/ComfyUI && nohup python main.py --listen 0.0.0.0 --disable-auto-launch --port 8188 --enable-cors-header > /workspace/comfyui.log 2>&1 &"`,
```

---

## Issue #3: Civitai Infrastructure Problems

### Problem
Civitai's CDN/API can be unreliable and return 502/524 timeouts.

### How to Verify
Run the diagnostic:
```powershell
.\test-civitai.ps1
```

Look for:
- `502 Bad Gateway`
- `524 A timeout occurred`
- Connection timeouts

### Fix
The provision script already has retry logic (3 attempts per file). If Civitai is down:

**Option A: Wait and retry provisioning later**
```powershell
# Check Civitai status
curl -I https://civitai.com/api/download/models/290640

# Retry prewarm when Civitai is responsive
Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool/prewarm" `
  -Headers @{ 'x-admin-key'='secure_admin_key_change_me' } `
  -Method POST
```

**Option B: Use alternative model sources**
Update the checkpoint URLs in the provision script to use direct downloads or mirrors:
```bash
# Instead of Civitai
CHECKPOINT_MODELS=(
    "https://civitai.com/api/download/models/290640"  # May fail
)

# Use Hugging Face mirror (if available)
CHECKPOINT_MODELS=(
    "https://huggingface.co/username/pony-diffusion-v6-xl/resolve/main/model.safetensors"
)
```

---

## Issue #4: Insufficient Disk Space

### Problem
Pony Diffusion V6 XL is ~6.5GB. If the instance has low disk, downloads may fail.

### How to Verify
```bash
# Check disk on instance
df -h /workspace
```

### Fix
Ensure `WARM_POOL_DISK_GB` is sufficient:
```powershell
$env:WARM_POOL_DISK_GB='300'  # 300GB minimum for SDXL models
npm start
```

---

## Quick Diagnostic Checklist

Run these in order:

### 1. Test Token Locally
```powershell
.\test-civitai.ps1
```

### 2. Check Server Environment
```powershell
# Verify token is set before starting server
$env:CIVITAI_TOKEN
$env:HUGGINGFACE_HUB_TOKEN

# Check server sees the tokens
Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/health" | ConvertTo-Json
```

### 3. Verify Instance Status
```powershell
Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool" `
  -Headers @{ 'x-admin-key'='secure_admin_key_change_me' } | ConvertTo-Json -Depth 4
```

### 4. SSH to Instance (Advanced)
```powershell
# Get contract ID from status
$status = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool" `
  -Headers @{ 'x-admin-key'='secure_admin_key_change_me' }
$contractId = $status.instance.contractId

# SSH (requires lib/vastai-ssh.js)
node -e "require('./lib/vastai-ssh').connectToInstance($contractId)"
```

Once SSH'd:
```bash
# Check if token is set
echo $CIVITAI_TOKEN

# Check provision logs
tail -100 /var/log/cloud-init-output.log

# Test Civitai access manually
wget "https://civitai.com/api/download/models/290640?token=$CIVITAI_TOKEN" \
  -O /tmp/test.safetensors --progress=bar:force --timeout=60
```

---

## Recommended Fixes (Priority Order)

### 1. ✅ Fix Provision Script (Highest Priority)
Update the gist at `https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw/` to use query parameters instead of Bearer headers for Civitai.

### 2. ✅ Explicitly Export Tokens in onstart
Modify [server/warm-pool.js](server/warm-pool.js#L720) to export environment variables.

### 3. ✅ Add Fallback Model Sources
Include non-Civitai URLs as fallbacks in the provision script.

### 4. ✅ Enhance Retry Logic
Increase retry count and add exponential backoff for Civitai downloads.

---

## Testing the Fix

After applying fixes:

```powershell
# 1. Clear stale instance
node -e "const db=require('./server/db'); const s=db.getState(); s.instance=null; db.saveState(s); console.log('cleared');"

# 2. Start server with tokens
$env:CIVITAI_TOKEN='11a72963b7f26eae7794381206a763dc'
$env:HUGGINGFACE_HUB_TOKEN='hf_XXXXXXXXXXXXXXXXXXXXXXXX'
npm start

# 3. Trigger prewarm
Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool/prewarm" `
  -Headers @{ 'x-admin-key'='secure_admin_key_change_me' } `
  -Method POST `
  -Body '{}' `
  -ContentType 'application/json'

# 4. Monitor logs
# Watch the new PowerShell window running npm start for provisioning progress

# 5. After 15-20 minutes, check models
# SSH to instance and verify:
ls -lh /workspace/ComfyUI/models/checkpoints/
```

---

## Summary

**Root Cause:** Civitai API uses `?token=` query parameters, not `Authorization: Bearer` headers.

**Impact:** All Civitai models (Pony V6 XL, Pornmaster v1.5) fail to download during provisioning.

**Solution:** Update provision script's `provisioning_download()` function to append `&token=$CIVITAI_TOKEN` to Civitai URLs instead of using wget's `--header` flag.
