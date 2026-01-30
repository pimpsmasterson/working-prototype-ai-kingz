# VITAL RULES — How to Use and Maintain the Vast.ai Proxy & Warm-Pool

A short, authoritative set of rules for safe, predictable operation of this project. Follow these rules to avoid outages, security leaks, and wasted spend. Keep this file copy-controlled and reference it in `MASTER_START_GUIDE.md`.

---

## 1) Authentication & Secrets 🔐
- **Never** commit API keys or tokens to git (use `.env` and add `.env` to `.gitignore`).
- Store keys in `.env` in repo root with these exact names: `VASTAI_API_KEY`, `ADMIN_API_KEY`, `HUGGINGFACE_HUB_TOKEN`, `CIVITAI_TOKEN`, `AUDIT_SALT`.
- Use the runtime admin endpoint to set tokens for a running process (localhost-only):

  ```bash
  curl -X POST http://localhost:3000/api/proxy/admin/set-tokens \
    -H "Content-Type: application/json" \
    -d '{"vastai":"<key>","huggingface":"<token>"}'
  ```

- Rotate keys immediately if leaked; update `.env` and restart PM2 with `--update-env`.

---

## 2) PM2 & Environment Consistency ⚙️
- Always use `config/ecosystem.config.js` to start/manage the app under PM2.
- After editing `.env`, run:

  ```powershell
  pm2 delete vastai-proxy || true
  pm2 start config/ecosystem.config.js --update-env
  pm2 save
  ```

- Verify environment loaded:

  ```powershell
  pm2 show vastai-proxy
  pm2 env 0
  ```

---

## 3) Renting, Prewarming & Cost Control 💳
- Use the prewarm endpoint to rent an instance for the warm pool (admin key required):

  ```bash
  curl -X POST http://localhost:3000/api/proxy/admin/warm-pool/prewarm -H "x-admin-api-key: <admin>"
  ```

- The system will try offers and fallback; monitor logs for `WarmPool` messages to confirm success.
- Be mindful of hourly costs; terminate idle instances via admin endpoint if not in use.

---

## 4) SSH & Instance Access 🛠️
- Use the provided ssh key (e.g., `%USERPROFILE%/.ssh/id_rsa_vast`) to connect when `ssh_host` and `ssh_port` show in status.
- Inspect logs and processes on the instance if ComfyUI doesn't start:

  ```bash
  ssh -i ~/.ssh/id_rsa_vast -p <port> root@<ssh_host>
  tail -F /workspace/comfyui.log
  ps aux | egrep 'comfy|main.py|python'
  curl -s http://localhost:8188/system_stats
  ```

---

## 5) Health Checks & Timeouts ⏱️
- The warm-pool health checks poll the instance's ComfyUI endpoint and will show `network timeout` if the service doesn't respond.
- Allow 5–15 minutes for provisioning; if health check repeatedly times out, inspect instance logs and pip installs (common cause).

---

## 6) Logs & Troubleshooting 🔎
- Primary logs: `pm2 logs vastai-proxy --lines 200` (server) and `/workspace/comfyui.log` (instance).
- Common failure patterns:
  - **Invalid user key** → Vast.ai API returns auth error. Verify `VASTAI_API_KEY` in PM2 env and `.env`.
  - **Provisioning stuck** → pip installs still running; check remote pip logs and available disk/RAM.
  - **Comfy UI not responding** → service not started or crashed; check `/workspace/comfyui.log` and restart `nohup python main.py ...` if necessary.

---

## 7) Security & Safety Rules ⚠️
- Admin endpoints are protected by `ADMIN_API_KEY` — keep this secret and change it from the default `secure_admin_key_change_me` immediately in production.
- Only call `/api/proxy/admin/set-tokens` from localhost (the server enforces this).
- Audit logs are HMAC-signed with `AUDIT_SALT` — do not change `AUDIT_SALT` arbitrarily (breaks audit continuity).

---

## 8) Escalation & Communication 📣
- If an instance provisioning fails and you're unsure why:
  1. Check `pm2 logs` and instance `/workspace/comfyui.log`.
  2. If pip installs fail or disk is low, solve on the instance or reprovision.
  3. If Vast.ai reports `Invalid user key`, verify account & API key in the Vast.ai dashboard.
  4. Open an issue in this repo with logs and timeline.

---

## 9) Where to add/inspect rules (repo files) 📂
- Quick start: `MASTER_START_GUIDE.md`
- Runtime/server: `server/vastai-proxy.js` and `server/warm-pool.js`
- PM2 config: `config/ecosystem.config.js`
- Add new rules or modify this file and raise PR for review.

---

If you want, I can now:
- commit a small README update linking to `VITAL_RULES.md`, and
- open a PR draft (local commit) for your review.

Pick one or both and I'll proceed.