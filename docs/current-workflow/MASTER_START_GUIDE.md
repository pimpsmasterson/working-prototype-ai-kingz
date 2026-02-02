## MASTER START GUIDE

This guide collects the exact commands and verification steps to get the `vastai-proxy` server running, ensure PM2 loads environment variables, test Vast.ai connectivity, prewarm an instance, and connect via SSH.

**See also:** `VITAL_RULES.md` for concise operational and security rules.

Prerequisites
- Node.js and npm installed
- PM2 installed (`npm i -g pm2`)
- A valid Vast.ai API key (from https://console.vast.ai/ → Account → API Keys)
- Your SSH private key available at `%USERPROFILE%\.ssh\id_rsa_vast`

1) Place environment variables

Edit `.env` with the correct values (example):

```
# at repository root
VASTAI_API_KEY=YOUR_VASTAI_API_KEY_HERE
ADMIN_API_KEY=secure_admin_key_change_me
HUGGINGFACE_HUB_TOKEN=your_hf_token_here
CIVITAI_TOKEN=your_civitai_token_here
AUDIT_SALT=your_audit_salt
COMFYUI_PROVISION_SCRIPT=https://gist.githubusercontent.com/pimpsmasterson/5a3dc3d4b9151081f3dab111d741a1e7/raw
SCRIPTS_BASE_URL=https://gist.githubusercontent.com/pimpsmasterson/5a3dc3d4b9151081f3dab111d741a1e7/raw
WARM_POOL_SAFE_MODE=0
WARM_POOL_IDLE_MINUTES=15
PORT=3000
COMFYUI_TUNNEL_URL=http://localhost:8188
DROPBOX_TOKEN=your_dropbox_token
```

2) Ensure PM2 ecosystem loads `.env`

We updated `config/ecosystem.config.js` to call `dotenv` and forward `process.env` values to PM2. If you changed `.env`, restart the PM2 app with updated env:

```powershell
# From repo root (PowerShell)
pm2 update  # Update PM2 if needed
pm2 delete vastai-proxy || true
pm2 start config/ecosystem.config.js --update-env
pm2 save
```

**Alternative: Use the automated script** `start-ai-kings.ps1` for full setup and prewarm.

3) Start or restart server (plain node for debugging)

```powershell
# For foreground debugging (no pm2)
# Open a shell in repo root
node server/vastai-proxy.js
```

4) Verify server is listening

```powershell
curl http://localhost:3000/api/proxy/health
# Expected: JSON with status and warmPool info
```

5) Test Vast.ai API connectivity (bundles search)

```powershell
curl -X POST http://localhost:3000/api/proxy/bundles \
  -H "x-api-key: secure_admin_key_change_me" \
  -H "Content-Type: application/json" \
  -d '{"q": {}, "type": "ask", "order": ["dph_total","asc"]}'
```

If this returns `{"success":false,"error":"auth_error","msg":"Invalid user key"}`, your server is NOT using a valid `VASTAI_API_KEY` (check `.env` and PM2 env with `pm2 show vastai-proxy`).

6) Prewarm (rent) a warm-pool instance

```powershell
curl -X POST http://localhost:3000/api/proxy/admin/warm-pool/prewarm \
  -H "x-admin-api-key: secure_admin_key_change_me"
```

Check status:

```powershell
curl http://localhost:3000/api/proxy/admin/warm-pool/status -H "x-admin-api-key: secure_admin_key_change_me"
```

Look for `instances` and `ssh_host`/`ssh_port` in the response.

7) Connect via SSH

### Automated (Recommended)
    
    Run the helper script to auto-detect and connect:
    ```powershell
    .\scripts\tools\connect.ps1
    ```
    
    ### Manual
    ```powershell
    ssh -i $env:USERPROFILE\.ssh\id_rsa_vast root@INSTANCE_SSH_HOST -p INSTANCE_SSH_PORT
    ```

8) Troubleshooting notes
- If PM2 still shows demo key in logs (`demo_vasta...`), PM2 process was started with an env that didn't source `.env` — use `pm2 delete vastai-proxy` then `pm2 start config/ecosystem.config.js --update-env`.
- Check PM2 env:

```powershell
pm2 show vastai-proxy
```

- Check logs:

```powershell
pm2 logs vastai-proxy --lines 200
```

- If `WarmPool: Error response: {"success":false,"error":"auth_error","msg":"Invalid user key"}` appears, confirm the `VASTAI_API_KEY` value in `.env` matches EXACTLY the key from Vast.ai dashboard.

9) Quick recovery steps (if things got broken during testing)

```powershell
# 1) Stop any running app
pm2 delete vastai-proxy
# 2) Ensure .env is correct
# 3) Start with pm2 and force it to read env
pm2 start config/ecosystem.config.js --update-env
# 4) Verify
curl http://localhost:3000/api/proxy/health
```

---

## Common AI Failures and Fixes

### 1. Server Won't Start or Exits Immediately
- **Symptoms**: `node server/vastai-proxy.js` prints startup messages but exits with code 1.
- **Causes**: Missing environment variables, port already in use, or code errors.
- **Fixes**:
  - Ensure `.env` file exists and has `VASTAI_API_KEY` and `ADMIN_API_KEY`.
  - Kill existing Node processes: `Get-Process node | Stop-Process -Force`
  - Check for port conflicts: `netstat -ano | findstr :3000`
  - Use the one-click script: `.\one-click-start.ps1`

### 2. PM2 Hangs or Fails to Start
- **Symptoms**: `pm2 start config/ecosystem.config.js` hangs indefinitely.
- **Causes**: PM2 issues, environment not loaded properly.
- **Fixes**:
  - Use direct node start instead: `$env:VASTAI_API_KEY='key'; $env:ADMIN_API_KEY='key'; node server/vastai-proxy.js`
  - Or use the one-click script which starts in background.

### 3. Prewarm Fails with "Invalid user key"
- **Symptoms**: Prewarm returns `{"success":false,"error":"auth_error","msg":"Invalid user key"}`
- **Causes**: VASTAI_API_KEY is invalid, expired, or not set correctly.
- **Fixes**:
  - Regenerate API key in Vast.ai dashboard.
  - Test key directly: `curl -H "Authorization: Bearer YOUR_KEY" https://console.vast.ai/api/v0/instances/`
  - Ensure key in `.env` matches exactly.

### 4. Provisioning Fails with SSH Authentication
- **Symptoms**: Logs show "All configured authentication methods failed"
- **Causes**: SSH key not registered with Vast.ai, or key file missing.
- **Fixes**:
  - Ensure SSH key exists at `%USERPROFILE%\.ssh\id_rsa_vast`
  - Register key in Vast.ai account under Account > SSH Keys.
  - Check provision logs in `logs/` for details.

### 5. No GPU Offers Available
- **Symptoms**: Prewarm searches but finds no instances.
- **Causes**: High demand, insufficient credits, or restrictive filters.
- **Fixes**:
  - Check Vast.ai dashboard for available credits.
  - Adjust filters in code (e.g., increase CUDA min, disk space).
  - Try different times when demand is lower.

### 6. ComfyUI Fails to Start on Instance
- **Symptoms**: Instance rented but ComfyUI not accessible.
- **Causes**: Provision script errors, model download failures.
- **Fixes**:
  - Check provision logs for script errors.
  - Ensure `COMFYUI_PROVISION_SCRIPT` URL is valid.
  - Verify Hugging Face and Civitai tokens if downloading models.

### 7. Database Corruption
- **Symptoms**: Server starts but warm-pool state is wrong.
- **Causes**: Interrupted writes, disk issues.
- **Fixes**:
  - Clean DB: `node -e "const db=require('./server/db'); const s=db.getState(); s.instance=null; s.isPrewarming=false; db.saveState(s);"`
  - Delete `data/warm_pool.db` and restart.

### 8. Port Already in Use
- **Symptoms**: `listen EADDRINUSE`
- **Causes**: Another process using port 3000.
- **Fixes**:
  - Kill processes: `Get-Process | Where-Object { $_.Id -in (Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue).OwningProcess } | Stop-Process`
  - Change port in `.env`: `PORT=3001`

---

If you want, I can now:
- verify PM2 env values (`pm2 show vastai-proxy`) and paste output here
- run the bundles test and prewarm again and paste logs

Pick one and I'll run it next.
