# Provision Script Checklist — Zero-Failure Target

**Purpose:** Prevent GPU cost waste. Every failed provision = money lost.

---

## 1. COMFYUI_PROVISION_SCRIPT URL (CRITICAL)

**Canonical gist (only this one is used):** https://gist.github.com/pimpsmasterson/002d4121626567402b4c59febbc1297d

| ✅ CORRECT |
|------------|
| `.../002d4121626567402b4c59febbc1297d/raw/gistfile1.txt` (v3.1.8 reliable provisioner) |

**Working URL (unpinned):**
```
https://gist.githubusercontent.com/pimpsmasterson/002d4121626567402b4c59febbc1297d/raw/gistfile1.txt
```

**Check:** `.env` must use the above URL. **warm-pool.js** whitelist allows only this gist.

---

## 2. Critical URLs (Must Work)

| Asset | Primary URL | Fallback | If Both Fail |
|-------|-------------|----------|--------------|
| **RIFE** | `huggingface.co/hzwer/RIFE/.../RIFEv4.26_0921.zip` | `huggingface.co/r3gm/RIFE/.../RIFEv4.26_0921.zip` | Log, continue (optional) |
| **example_pose.png** | `huggingface.co/thibaud/controlnet-openpose-sdxl-1.0/.../out_ballerina.png` | none | Log, continue (optional) |

**Never use:** `github.com/.../rife426.pth` (404), `huggingface.co/spaces/hysts/ControlNet/.../pose.png` (404)

---

## 3. Script Crash Points (Must Not Reference Unbound Vars)

| Location | Variable | Fix |
|----------|----------|-----|
| `download_file` failure block | `file_log` (undefined there) | Use `err_log` and `errfile` |
| `attempt_download` | `file_log` | Local to that function only |

**Rule:** In failure block, define `err_log` and `errfile`; never reference `file_log`.

---

## 4. Optional Downloads (Never Abort)

- **example_pose.png:** Wrapped in subshell `( download_file ... ) || log "..."` so failure cannot crash script.
- **RIFE:** In `smart_download_parallel` which returns 0 always; failures are logged only.

---

## 5. Before Pushing to Gist

1. Run `scripts/push-provision-to-gist.ps1`
2. Update `.env` with new raw URL (or pinned commit URL)
3. Run `pm2 restart vastai-proxy --update-env`
4. Terminate any running instance before testing (old script cached)

---

## 6. Pre-Launch Verification

```powershell
# Verify provision URL returns 200
Invoke-WebRequest -Uri $env:COMFYUI_PROVISION_SCRIPT -Method Head

# Verify .env uses provision-reliable.sh
Select-String -Path .env -Pattern "provision-reliable|gistfile1"
```

---

## 7. When Provisioning Fails

1. Check `provision_v3.log` on instance (via SSH or Vast.ai console)
2. Check `provision_errors.log` for failed downloads
3. Verify COMFYUI_PROVISION_SCRIPT in .env is correct
4. Restart PM2: `pm2 restart vastai-proxy --update-env`
5. Terminate instance and start fresh (old script may be cached)

---

---

## 8. Cloudflare Quick Tunnel (Optional)

At the end of provisioning, cloudflared is installed and started to create a **trycloudflare.com** URL. No config needed.

- **Output:** URL printed in a box, e.g. `https://xyz.trycloudflare.com`
- **Disable:** Set `DISABLE_CLOUDFLARED=1` in env
- **If it fails:** Use SSH tunnel or direct IP:8188 (Vast.ai port mapping)

---

**Last Updated:** 2026-02-05
