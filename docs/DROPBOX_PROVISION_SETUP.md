# Dropbox Provision Script Setup & Troubleshooting

## What Was Fixed

### ✅ 1. Uploaded Dropbox Script to Gist
- **File:** `scripts/provision-dropbox-only.sh`
- **Gist commit:** `a5691b79ab62a1d5606b1b0f08eea92d15481102`
- **Gist URL:** `https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw/a5691b79ab62a1d5606b1b0f08eea92d15481102/provision-dropbox-only.sh`
- **Status:** Committed locally, needs git push (see below)

### ✅ 2. Updated warm-pool.js to Pass Dropbox Credentials
- Added `DROPBOX_TOKEN` to `envVars` if present in `.env`
- Added `DROPBOX_FOLDER` to `envVars` (also sets `DROPBOX_PATH` for compatibility)
- **File:** `server/warm-pool.js` lines ~1172-1180

### ✅ 3. Updated .env Configuration
- Changed `COMFYUI_PROVISION_SCRIPT` to point to Dropbox script
- **Current value:** `https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw/a5691b79ab62a1d5606b1b0f08eea92d15481102/provision-dropbox-only.sh`

## How It Works

1. **Instance Creation:** When `prewarm()` is called, it creates a Vast.ai instance
2. **Environment Variables:** The instance receives:
   - `DROPBOX_TOKEN` (from `.env`)
   - `DROPBOX_FOLDER` (from `.env`, e.g., `/workspace/pornmaster100`)
   - `DROPBOX_PATH` (same as `DROPBOX_FOLDER` for compatibility)
3. **Provisioning:** Vast.ai downloads the script from the Gist URL and runs it
4. **Script Execution:** The script:
   - Downloads the entire workspace ZIP from Dropbox
   - Extracts it to `/workspace`
   - Finds ComfyUI directory
   - Sets up virtualenv if needed
   - Installs PyTorch if missing (unless `SKIP_TORCH=1`)
   - Starts ComfyUI on port 8188

## Troubleshooting

### Issue: Script Fails with "DROPBOX_TOKEN is not set"
**Cause:** Environment variables not being passed to instance
**Fix:** 
- Verify `.env` has `DROPBOX_TOKEN` set
- Verify `.env` has `DROPBOX_FOLDER` set (e.g., `/workspace/pornmaster100`)
- Restart proxy: `pm2 restart vastai-proxy --update-env`
- Check `pm2 logs vastai-proxy` for "WarmPool: 📦" messages showing env vars

### Issue: Script Fails with "DROPBOX_PATH is not set"
**Cause:** `DROPBOX_FOLDER` not set in `.env` or not passed to instance
**Fix:** 
- Set `DROPBOX_FOLDER=/workspace/pornmaster100` in `.env`
- Restart proxy to reload env vars

### Issue: Download Fails (429, timeout, or empty ZIP)
**Possible Causes:**
1. **Dropbox token expired or invalid**
   - Check token in Dropbox App Console: https://www.dropbox.com/developers/apps
   - Generate new token if needed
   - Update `.env` with new token

2. **Dropbox path doesn't exist**
   - Verify path in Dropbox: `DROPBOX_FOLDER=/workspace/pornmaster100`
   - Path must start with `/` and match exact folder name in Dropbox

3. **Network/timeout issues**
   - Script retries 3 times with 5-second delays
   - Check `/tmp/provision-dropbox-only.log` on instance for details
   - Increase `RETRIES` env var if needed

4. **ZIP too small (< 500KB)**
   - Check if Dropbox folder is empty or very small
   - Verify workspace was uploaded correctly to Dropbox
   - Check `MIN_ZIP_BYTES` env var (default 500000)

### Issue: ComfyUI Not Found After Extraction
**Cause:** ZIP structure doesn't match expected layout
**Fix:**
- Verify Dropbox folder structure: `/workspace/pornmaster100/ComfyUI/` should exist
- Or set `COMFYUI_DIR` env var to correct path
- Script auto-detects by finding `main.py` in extracted files

### Issue: Script Not Downloaded from Gist
**Cause:** Gist URL returns 404 or unreachable
**Fix:**
1. **Push Gist commit** (if not pushed yet):
   ```powershell
   cd $env:TEMP\gist-c3f61f20067d498b6699d1bdbddea395
   git push origin main
   ```
2. **Verify URL is accessible:**
   ```powershell
   curl -I "https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw/a5691b79ab62a1d5606b1b0f08eea92d15481102/provision-dropbox-only.sh"
   ```
3. **Update `.env` with correct commit hash** if you pushed a new commit

## Testing

### Dry Run (Local)
```bash
DRY_RUN=1 DROPBOX_TOKEN="sl.xxx" DROPBOX_FOLDER="/workspace/pornmaster100" bash scripts/provision-dropbox-only.sh
```

### Check Logs on Instance
```bash
# SSH into instance
ssh root@<instance-ip> -p <port>

# View provision log
tail -f /tmp/provision-dropbox-only.log

# Check ComfyUI log
tail -f /workspace/ComfyUI/comfyui.log
```

## Switching Back to Model Download Script

If you want to use the model-download script instead:

1. Update `.env`:
   ```env
   COMFYUI_PROVISION_SCRIPT=https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw/<commit-hash>/provision-reliable.sh
   ```

2. Restart proxy:
   ```powershell
   pm2 restart vastai-proxy --update-env
   ```

## Next Steps

1. **Push Gist commit** (if git push works):
   ```powershell
   cd $env:TEMP\gist-c3f61f20067d498b6699d1bdbddea395
   git push origin main
   ```

2. **Test provisioning:**
   - Restart proxy: `pm2 restart vastai-proxy --update-env`
   - Trigger prewarm: `POST /api/proxy/admin/warm-pool/prewarm` with admin key
   - Monitor logs: `pm2 logs vastai-proxy`

3. **Verify Dropbox workspace:**
   - Ensure `/workspace/pornmaster100` exists in Dropbox
   - Contains `ComfyUI/` directory with `main.py`
   - Contains `venv/` if you want to skip PyTorch install (`SKIP_TORCH=1`)
