# AI Kings - Quick Start Guide

## Complete Setup Guide

This guide provides step-by-step instructions to properly set up and run the AI Kings ComfyUI automation system.

### Prerequisites

1. **Windows 10/11** with PowerShell 5.1+ (check with `$PSVersionTable.PSVersion`)
2. **Node.js 18+** installed (download from https://nodejs.org/)
3. **Git** installed (download from https://git-scm.com/)
4. **Valid Vast.ai API Key** (get from https://console.vast.ai/account/)
5. **Hugging Face Token** (get from https://huggingface.co/settings/tokens)
6. **Civitai Token** (get from https://civitai.com/user/account)
7. **SSH Key** configured for Vast.ai (see SSH Setup below)

### SSH Key Setup

1. Generate SSH key if you don't have one:
   ```powershell
   ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
   ```

2. Register the key with Vast.ai:
   - Go to https://console.vast.ai/account/
   - Upload your public key (`~/.ssh/id_rsa.pub`)
   - Rename the key to `id_rsa_vast` for the scripts to find it

### Environment Setup

1. **Clone or navigate to the project:**
   ```powershell
   cd 'c:\Users\samsc\OneDrive\Desktop\working protoype'
   ```

2. **Create/update .env file** with your tokens:
   ```
   VASTAI_API_KEY=your_vastai_key_here
   ADMIN_API_KEY=secure_admin_key_change_me
   HUGGINGFACE_HUB_TOKEN=your_hf_token_here
   CIVITAI_TOKEN=your_civitai_token_here
   AUDIT_SALT=ai_kings_audit_salt_2026_random_entropy_7x9k2p4q
   COMFYUI_PROVISION_SCRIPT=https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw
   SCRIPTS_BASE_URL=https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw
   WARM_POOL_SAFE_MODE=0
   WARM_POOL_IDLE_MINUTES=15
   WARM_POOL_DISK_GB=600
   PORT=3000
   COMFYUI_TUNNEL_URL=http://localhost:8188
   ```

### Server Startup

**IMPORTANT:** Always start the server with ALL environment variables set in the same PowerShell session.

```powershell
# Kill any existing processes
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force

# Start server with ALL variables (copy-paste this entire block)
$env:VASTAI_API_KEY='your_vastai_key_here'
$env:ADMIN_API_KEY='secure_admin_key_change_me'
$env:HUGGINGFACE_HUB_TOKEN='your_hf_token_here'
$env:CIVITAI_TOKEN='your_civitai_token_here'
$env:AUDIT_SALT='ai_kings_audit_salt_2026_random_entropy_7x9k2p4q'
$env:COMFYUI_PROVISION_SCRIPT='https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw'
$env:SCRIPTS_BASE_URL='https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw'
$env:WARM_POOL_SAFE_MODE='0'
$env:WARM_POOL_IDLE_MINUTES='15'
$env:WARM_POOL_DISK_GB='600'
$env:PORT='3000'
$env:COMFYUI_TUNNEL_URL='http://localhost:8188'
node server/vastai-proxy.js
```

**Verification:**
```powershell
# Check if server is running
netstat -ano | findstr ":3000" | findstr "LISTENING"

# Test health endpoint
curl http://localhost:3000/api/proxy/health
```

### GPU Instance Setup

1. **Trigger prewarm** (rents and provisions a GPU instance):
   ```powershell
   Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool/prewarm" -Headers @{ 'x-admin-key'='secure_admin_key_change_me' } -Method POST | ConvertTo-Json -Depth 6
   ```

2. **Monitor status:**
   ```powershell
   Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool/status" -Headers @{ 'x-admin-key'='secure_admin_key_change_me' } | ConvertTo-Json -Depth 5
   ```

3. **Wait for completion** (10-15 minutes). Look for `status: "ready"` and `connectionUrl`.

### Accessing ComfyUI

1. **Get instance details:**
   ```powershell
   $headers = @{ 'Authorization' = "Bearer $env:VASTAI_API_KEY" }
   $inst = (Invoke-RestMethod -Uri 'https://console.vast.ai/api/v0/instances/?owner=me' -Headers $headers).instances | Where-Object { $_.status -eq 'running' } | Select-Object -First 1
   ```

2. **Create SSH tunnel:**
   ```powershell
   ssh -i "$env:USERPROFILE\.ssh\id_rsa_vast" -p $inst.ssh_port -N -L 8188:localhost:8188 root@$inst.ssh_host
   ```

3. **Open ComfyUI:**
   - Browser: http://localhost:8188
   - Keep the tunnel window open

### Troubleshooting

**Server won't start:**
- Check all environment variables are set
- Verify tokens are valid
- Check port 3000 is not in use

**Prewarm fails:**
- Clear DB: `node -e "const db=require('./server/db'); const s=db.getState(); s.instance=null; s.useDefaultScript=false; s.provisionAttempt=0; db.saveState(s);"`
- Restart server with correct env vars
- Check Vast.ai account has credits

**Can't access ComfyUI:**
- Verify SSH tunnel is running
- Check instance status shows `ready`
- Try direct URL if available

**Provisioning errors:**
- Check provisioning logs on instance: `tail -100 /workspace/provision_v3.log`
- Verify COMFYUI_PROVISION_SCRIPT is set correctly
- Ensure gist content is up to date

---

## ⚠️ CRITICAL: Environment Variables
- Node.js installed
- Valid Vast.ai API key
- SSH key configured at `~/.ssh/id_rsa_vast` (for Vast.ai access)

## ⚠️ CRITICAL: Environment Variables

**MUST SET `COMFYUI_PROVISION_SCRIPT` OR WRONG SCRIPT WILL BE USED!**
> Tip: Set `PROVISION_ALLOWED_SCRIPTS` to the exact raw gist URL and `PROVISION_STRICT=true` to enforce that only the allowed gist is used; provisioning will abort instead of falling back to the default script if validation fails.

The server requires `COMFYUI_PROVISION_SCRIPT` environment variable to use the custom provisioning script with all 7 custom nodes, correct LoRA paths, and proper model downloads. Without this, Vast.ai's default script will be used, causing:
- Wrong models downloaded (798204 instead of 290640/139562)
- ComfyUI not installed at all
- Missing all custom nodes (FaceDetailer, UltimateSDUpscale, DepthAnythingV2, etc.)

**Note:** The provisioning script uses PyTorch 2.2.0+cu118 for compatibility with available wheels. If provisioning fails with PyTorch errors, ensure the script is updated to use compatible versions.

## Starting the Server (ONE COMMAND - COPY & PASTE)

### Kill any existing node processes first
```powershell
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force
```

### Start server with ALL required environment variables
**This MUST be run in a single PowerShell session. Environment variables don't persist across windows!**

```powershell
cd 'c:\Users\samsc\OneDrive\Desktop\working protoype'; $env:VASTAI_API_KEY='YOUR_VASTAI_API_KEY'; $env:ADMIN_API_KEY='YOUR_ADMIN_KEY'; $env:HUGGINGFACE_HUB_TOKEN='YOUR_HF_TOKEN'; $env:CIVITAI_TOKEN='YOUR_CIVITAI_TOKEN'; $env:AUDIT_SALT='YOUR_AUDIT_SALT'; $env:COMFYUI_PROVISION_SCRIPT='https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw'; $env:SCRIPTS_BASE_URL='https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw'; $env:PROVISION_ALLOWED_SCRIPTS='https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw'; $env:PROVISION_STRICT='true'; $env:WARM_POOL_SAFE_MODE='0'; $env:WARM_POOL_IDLE_MINUTES='15'; $env:PORT='3000'; $env:COMFYUI_TUNNEL_URL='http://localhost:8188'; node server/vastai-proxy.js
```

**Alternative: Start in separate window (recommended)**
```powershell
Start-Process powershell -ArgumentList '-NoExit', '-Command', "cd 'c:\Users\samsc\OneDrive\Desktop\working protoype'; `$env:VASTAI_API_KEY='YOUR_VASTAI_API_KEY'; `$env:ADMIN_API_KEY='YOUR_ADMIN_KEY'; `$env:HUGGINGFACE_HUB_TOKEN='YOUR_HF_TOKEN'; `$env:CIVITAI_TOKEN='YOUR_CIVITAI_TOKEN'; `$env:AUDIT_SALT='YOUR_AUDIT_SALT'; `$env:COMFYUI_PROVISION_SCRIPT='https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw'; `$env:SCRIPTS_BASE_URL='https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw'; `$env:WARM_POOL_SAFE_MODE='0'; `$env:WARM_POOL_IDLE_MINUTES='15'; `$env:PORT='3000'; `$env:COMFYUI_TUNNEL_URL='http://localhost:8188'; node server/vastai-proxy.js"
```

### Verify server is listening (wait 5-8 seconds)
```powershell
netstat -ano | findstr ":3000" | findstr "LISTENING"
```
Expected output: `TCP    0.0.0.0:3000           0.0.0.0:0              LISTENING       <PID>`

**OR use health endpoint:**
```powershell
curl http://localhost:3000/api/proxy/health
```
Expected: `{"status":"running","ok":true,"now":"..."}`

## Starting the Server with PM2 (Recommended for Production)

For reliable, background operation, use PM2 with the ecosystem configuration. This automatically loads environment variables from `.env` and manages the process.

### Prerequisites
- PM2 installed: `npm install -g pm2`
- `.env` file with all required variables (see Environment Setup above, plus any additional like `DROPBOX_TOKEN`, `COMFYUI_PROVISION_SCRIPT`, etc.)

### Start Server
```powershell
cd 'c:\Users\samsc\OneDrive\Desktop\working protoype'
pm2 delete vastai-proxy 2>$null
pm2 start config/ecosystem.config.js --update-env
pm2 save
```

### Update PM2 if needed
```powershell
pm2 update
```

### Verify
```powershell
pm2 list
curl http://localhost:3000/api/proxy/health
```

## Automated Startup Script

For convenience, use the provided `one-click-rent.ps1` script, which handles killing processes, cleaning DB, starting PM2, and triggering prewarm.

```powershell
.\one-click-rent.ps1
```

## Triggering Prewarm (Rents a GPU Instance)

**⚠️ WARNING: This will rent a Vast.ai instance and incur billing charges (~$0.30-0.50/hour)**

```powershell
Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool/prewarm" -Headers @{ 'x-admin-key'='secure_admin_key_change_me' } -Method POST | ConvertTo-Json -Depth 6
```

**Expected response:** Instance details with `contractId`, `status: "running"`, and `connectionUrl`

**Note:** Initial provisioning takes 10-15 minutes to download models and install custom nodes.

## Check Warm-Pool Status

```powershell
Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool/status" -Headers @{ 'x-admin-key'='secure_admin_key_change_me' } | ConvertTo-Json -Depth 5
```

### Status Indicators
- `isPrewarming: true` - Searching for available GPU or provisioning in progress
- `instances: []` with `isPrewarming: true` - Still searching for GPU (normal, can take 1-5 minutes)
- `instances: [...]` with `contractId` - Instance rented, provisioning models (10-15 minutes)
- `status: "ready"` - Instance fully provisioned and ready to use
- `connectionUrl` - ComfyUI endpoint (e.g., `http://91.150.160.38:8188`)

## Verify Provisioning Success

**Critical: Check that the CORRECT provisioning script was used!**

SSH into the instance and verify:
```bash
# Check custom nodes are installed (should show 7 directories)
ls -la /workspace/ComfyUI/custom_nodes/

# Expected output:
# ComfyUI-Manager
# ComfyUI-AnimateDiff-Evolved
# ComfyUI-VideoHelperSuite
# ComfyUI-Frame-Interpolation
# ComfyUI-Impact-Pack
# ComfyUI_UltimateSDUpscale
# ComfyUI-DepthAnythingV2

# Check LoRAs are in correct folder (should show 10 files)
ls -la /workspace/ComfyUI/models/loras/

# Check symlink exists for backwards compatibility
ls -la /workspace/ComfyUI/models/lora

# View provisioning log to verify correct script header
tail -100 /workspace/comfyui.log | grep -A 5 "AI Kings"
```

**Look for:** `AI Kings NSFW ComfyUI Provisioning - Complete with All Custom Nodes`

**If you see Vast.ai default messages or wrong models:** Server was started without `COMFYUI_PROVISION_SCRIPT` environment variable. Terminate instance and restart server with correct env vars.

## Accessing ComfyUI

### Option 1: Direct Access (if instance has port mapping)
Once status shows `ready`, open the `connectionUrl` in your browser:
```
http://<IP>:8188
```

### Option 2: SSH Tunnel (if direct ports unavailable)
Some Vast.ai hosts don't support direct port mapping. Use SSH tunnel:

**⚠️ IMPORTANT:** Run these commands in your **LOCAL PowerShell** terminal, NOT inside an SSH session!

```powershell
# Get SSH details from Vast.ai API
$headers = @{ 'Authorization' = "Bearer $env:VASTAI_API_KEY" }
$inst = (Invoke-RestMethod -Uri 'https://console.vast.ai/api/v0/instances/?owner=me' -Headers $headers).instances | Where-Object { $_.status -eq 'running' } | Select-Object -First 1

# Create tunnel (keeps terminal open)
ssh -i "$env:USERPROFILE\.ssh\id_rsa_vast" -p $inst.ssh_port -N -L 8188:localhost:8188 root@$inst.ssh_host
```

**Notes:**
- When first connecting, you'll see: "Are you sure you want to continue connecting (yes/no/[fingerprint])?" - Type **yes** and press Enter
- The terminal will appear to hang with no output - **this is normal** for an SSH tunnel
- Keep the terminal window open while using ComfyUI
- If you accidentally close it, just run the command again

Then open: **http://localhost:8188** in your browser.

### Automatic Tunnel (Recommended)

For convenience, use the provided scripts:

**Option 1: Double-click**
```
start-tunnel.bat
```

**Option 2: PowerShell**
```powershell
.\start-tunnel.ps1
```

Both will automatically find your running instance and create the tunnel. Keep the window open while working.

## Saving Workflows from ComfyUI

To export your current workflow from ComfyUI to `config/workflows/`:

### Method 1: Manual Export (Easiest)
1. In ComfyUI web interface, click the **gear icon** (⚙️) or **menu button**
2. Select **"Save (API Format)"** or **"Export"**
3. Save the JSON file to: `config/workflows/your_workflow.json`

### Method 2: Using Export Script
```powershell
.\export-workflows.ps1
```
Follow the prompts to paste your workflow JSON.

### Method 3: Save via ComfyUI API
With tunnel running:
```powershell
# Get current workflow (if loaded in ComfyUI)
$workflow = Invoke-RestMethod -Uri "http://localhost:8188/prompt" -Method GET
$workflow | ConvertTo-Json -Depth 20 | Out-File "config/workflows/my_workflow.json"
```

## Installing Missing Custom Nodes

If a workflow requires custom nodes you haven't installed (e.g., FaceDetailer, UltimateSDUpscale, DepthAnythingV2):

```powershell
# Get instance SSH connection details
$headers = @{ 'Authorization' = "Bearer $env:VASTAI_API_KEY" }
$inst = (Invoke-RestMethod -Uri 'https://console.vast.ai/api/v0/instances/?owner=me' -Headers $headers).instances | Where-Object { $_.status -eq 'running' } | Select-Object -First 1

# SSH into the instance
ssh -i "$env:USERPROFILE\.ssh\id_rsa_vast" -p $inst.ssh_port root@$inst.ssh_host
```

Once connected, install nodes:
```bash
cd /workspace/ComfyUI/custom_nodes

# FaceDetailer (includes Impact Pack)
git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack
cd ComfyUI-Impact-Pack && source /venv/main/bin/activate && pip install -r requirements.txt --no-cache-dir && cd ..

# UltimateSDUpscale
git clone https://github.com/ssitu/ComfyUI_UltimateSDUpscale

# DepthAnythingV2
git clone https://github.com/kijai/ComfyUI-DepthAnythingV2
cd ComfyUI-DepthAnythingV2 && source /venv/main/bin/activate && pip install -r requirements.txt --no-cache-dir && cd ..

# Restart ComfyUI to load new nodes
pkill -f "main.py --listen"
cd /workspace/ComfyUI && source /venv/main/bin/activate && nohup python main.py --listen 0.0.0.0 --disable-auto-launch --port 8188 --enable-cors-header > /workspace/comfyui_restart.log 2>&1 &

# Verify restart (wait 10 seconds)
sleep 10 && tail -n 20 /workspace/comfyui_restart.log
```

### Preventing Missing Nodes in Future

**Update the provisioning script** ([gist-provision-patched.sh](gist-provision-patched.sh)) to include these nodes during initial setup:

```bash
# Add to the "Downloading node" section (around line 50):
echo "Downloading node: https://github.com/ltdrdata/ComfyUI-Impact-Pack..."
git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack "${COMFYUI_DIR}/custom_nodes/ComfyUI-Impact-Pack"
cd "${COMFYUI_DIR}/custom_nodes/ComfyUI-Impact-Pack" && pip install -r requirements.txt --no-cache-dir

echo "Downloading node: https://github.com/ssitu/ComfyUI_UltimateSDUpscale..."
git clone https://github.com/ssitu/ComfyUI_UltimateSDUpscale "${COMFYUI_DIR}/custom_nodes/ComfyUI_UltimateSDUpscale"

echo "Downloading node: https://github.com/kijai/ComfyUI-DepthAnythingV2..."
git clone https://github.com/kijai/ComfyUI-DepthAnythingV2 "${COMFYUI_DIR}/custom_nodes/ComfyUI-DepthAnythingV2"
cd "${COMFYUI_DIR}/custom_nodes/ComfyUI-DepthAnythingV2" && pip install -r requirements.txt --no-cache-dir
```

Then update your gist URL or use the local file by changing `COMFYUI_PROVISION_SCRIPT` env var.

## Troubleshooting

### ❌ "Connection refused" error
- **Cause:** Server not running or crashed
- **Fix:** Restart server with correct environment variables (see "Starting the Server" section)
- **Verify:** `netstat -ano | findstr ":3000" | findstr "LISTENING"`

### ❌ "Forbidden - invalid admin key" error
- **Cause:** Server started without `ADMIN_API_KEY` environment variable
- **Fix:**
  1. Kill server: `Get-Process node | Stop-Process -Force`
  2. Restart with ALL environment variables (especially `ADMIN_API_KEY`)

### ❌ Wrong provisioning script used (wrong models, no ComfyUI, missing nodes)
- **Cause:** Server started without `COMFYUI_PROVISION_SCRIPT` environment variable
- **Symptoms:**
  - Models like 798204 download instead of 290640/139562
  - `/workspace/ComfyUI` directory doesn't exist
  - Only 4 custom nodes instead of 7
- **Fix:**
  1. Kill server: `Get-Process node | Stop-Process -Force`
  2. Clear database: `node -e "const db=require('./server/db'); const s=db.getState(); s.instance=null; s.useDefaultScript=false; db.saveState(s);"`
  3. Terminate bad instance via Vast.ai console or API
  4. Restart server with **ALL environment variables** including `COMFYUI_PROVISION_SCRIPT`
  5. Trigger fresh prewarm
  6. SSH to verify: `tail -100 /workspace/comfyui.log | grep "AI Kings"`

### ⚠️ "Instance already present" but no actual instance
- **Cause:** Database has stale data from previous session
- **Fix:**
  ```powershell
  node -e "const db=require('./server/db'); const s=db.getState(); s.instance=null; s.useDefaultScript=false; s.provisionAttempt=0; db.saveState(s); console.log('✓ Database cleared');"
  ```
- **Then:** Trigger prewarm again

### ⏱️ Prewarm takes >5 minutes with no instance
- **Normal behavior:** GPU availability varies, can take 1-5 minutes to find suitable instance
- **Check status:** `Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool/status" -Headers @{ 'x-admin-key'='secure_admin_key_change_me' }`
- **If `isPrewarming: true` and `instances: []`:** Still searching for GPU, wait
- **If `isPrewarming: false` and `instances: []`:** Prewarm stopped, trigger again

### 🔌 Can't access ComfyUI at connectionUrl
- **Cause:** Some Vast.ai hosts don't support direct port mapping
- **Symptom:** `direct_port_end: -1` in instance details, or connection refused
- **Fix:** Use SSH tunnel (see "Accessing ComfyUI" → "Option 2" section)
- **Important:** Run tunnel commands in **LOCAL PowerShell**, not inside SSH session
- **Quick:** Run `.\start-tunnel.bat` then open http://localhost:8188
- **Common mistake:** If you see `-bash: command not found` errors, you're running PowerShell commands inside SSH - exit SSH first!

### 📦 LoRAs not appearing in ComfyUI dropdown
- **Cause:** Old provisioning script downloaded to `models/lora` (singular) but ComfyUI reads `models/loras` (plural)
- **Fix:** SSH to instance and create symlink:
  ```bash
  cd /workspace/ComfyUI/models
  ln -s loras lora
  ```
- **Permanent fix:** Gist already updated with correct path and symlink

### 🧩 Custom nodes missing (FaceDetailer, UltimateSDUpscale, DepthAnythingV2)
- **Cause:** Old provisioning script didn't include these nodes
- **Temporary fix:** SSH and manually install (see "Installing Missing Custom Nodes")
- **Permanent fix:** Server must use updated gist with `COMFYUI_PROVISION_SCRIPT` env var
This is normal. Check status with the status command above. Provisioning continues in background.

## One-Line Quick Start (Copy-Paste)

```powershell
# Kill existing, start server, wait, check status
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force; $env:VASTAI_API_KEY='YOUR_VASTAI_API_KEY'; $env:ADMIN_API_KEY='YOUR_ADMIN_KEY'; $env:HUGGINGFACE_HUB_TOKEN='YOUR_HF_TOKEN'; $env:CIVITAI_TOKEN='YOUR_CIVITAI_TOKEN'; $env:AUDIT_SALT='YOUR_AUDIT_SALT'; $env:COMFYUI_PROVISION_SCRIPT='https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw'; $env:SCRIPTS_BASE_URL='https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw'; $env:WARM_POOL_SAFE_MODE='0'; $env:WARM_POOL_IDLE_MINUTES='15'; $env:PORT='3000'; $env:COMFYUI_TUNNEL_URL='http://localhost:8188'; Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD'; npm start" -WindowStyle Normal; Start-Sleep -Seconds 8; netstat -ano | findstr ":3000" | findstr "LISTENING"
```

## Environment Variables Reference

| Variable | Purpose | Required |
|----------|---------|----------|
| `VASTAI_API_KEY` | Vast.ai authentication | ✅ Yes |
| `ADMIN_API_KEY` | Admin endpoint protection | ✅ Yes |
| `HUGGINGFACE_HUB_TOKEN` | Download gated models | Optional |
| `CIVITAI_TOKEN` | Download Civitai models | Optional |
| `COMFYUI_PROVISION_SCRIPT` | Custom provisioning script URL | Optional |
| `WARM_POOL_SAFE_MODE` | Auto-terminate instances (1=yes) | Optional |
| `WARM_POOL_IDLE_MINUTES` | Minutes before idle shutdown | Optional |
| `PORT` | Server port | Optional (default: 3000) |

## Key Lessons (Why It Failed Before)

1. **Environment variables must be set in the SAME shell that runs npm start**
   - Setting them, then running in a separate process = they don't transfer
   - Solution: Set vars, then immediately run `npm start` in that shell

2. **Server must stay running**
   - Background processes (`-isBackground:true`) were exiting silently
   - Solution: Use `Start-Process` with `-NoExit` and visible window

3. **Admin key header format**
   - Use `'x-admin-key'` (with quotes) in PowerShell headers
   - Query param alternative: `?adminKey=<key>` in URL

4. **Stale database state**
   - DB persists instance info even if Vast.ai instance is gone
   - Clear stale entries before prewarming if you see "already_present" errors
