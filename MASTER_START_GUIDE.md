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
PORT=3000
COMFYUI_TUNNEL_URL=http://localhost:8188
WARM_POOL_SAFE_MODE=0
WARM_POOL_IDLE_MINUTES=15
```

2) Ensure PM2 ecosystem loads `.env`

We updated `config/ecosystem.config.js` to call `dotenv` and forward `process.env` values to PM2. If you changed `.env`, restart the PM2 app with updated env:

```powershell
# From repo root (PowerShell)
pm2 delete vastai-proxy || true
pm2 start config/ecosystem.config.js --update-env
pm2 save
```

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

If you want, I can now:
- verify PM2 env values (`pm2 show vastai-proxy`) and paste output here
- run the bundles test and prewarm again and paste logs

Pick one and I'll run it next.
