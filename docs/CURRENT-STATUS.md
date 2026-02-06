# Current Status Report - 2026-02-06

## Provisioner v3.1 — Full Update

### Status Summary

| Item | Status |
|------|--------|
| **Provision script** | v3.1 — Cloudflare verification, ComfyUI-Copilot, mm_sdxl fix |
| **Gist URL** | ✅ Use unpinned `.../raw/provision-reliable.sh` |
| **gistfile1.txt** | ❌ 404 – gist uses `provision-reliable.sh` |
| **China/Ukraine GPUs** | ✅ Excluded in warm-pool filter |
| **PORTAL_CONFIG** | ✅ Simplified (ComfyUI + Instance Portal only) |
| **Cloudflare tunnel** | ✅ Post-connect verification, restart helper, COMFYUI_URL.txt |

---

## v3.1 Changelog (Full Enumeration)

### provision-reliable.sh
1. **Version bump** v3.0 → v3.1
2. **retry_failed_downloads** — Only log lines matching `FAILED:`; skip aria2 diagnostic output (fixes `❌ unknown` spam)
3. **failed_count** — Use `grep -c 'FAILED:'` instead of `wc -l` for accurate count
4. **mm_sdxl_v10_beta.ckpt** — Switch from camenduru (404) to guoyww/animatediff
5. **ComfyUI-Copilot** — Add AIDC-AI/ComfyUI-Copilot to NODES list
6. **Cloudflare post-connect verification** — Curl `${TUNNEL_URL}/system_stats` to verify reachability
7. **restart-cloudflare-tunnel.sh** — Write helper script at `/workspace/restart-cloudflare-tunnel.sh` for 502/recovery
8. **Log message** — Add "If URL stops working (502/restart): bash /workspace/restart-cloudflare-tunnel.sh"

### push-provision-to-gist.js
- Gist description: `AI Kings ComfyUI reliable provisioner v3.1 — Cloudflare tunnel + ComfyUI-Copilot + mm_sdxl fix`

### docs/CURRENT-STATUS.md
- 502/Cloudflare reconnection documentation
- ComfyUI-Copilot section
- v3.1 changelog

---

## Changes Made (Prior Sessions)

### 1. warm-pool.js
- **Geolocation filter**: Exclude China (`china`, `cn`) and Ukraine (`ukraine`, `ua`)
- **PORTAL_CONFIG**: Reduced from 6 entries to 2 (ComfyUI + Instance Portal). Removed duplicates and extras that could trigger "remote port forwarding failed"
- **rentBody**: Added `ssh_direct: true`, reduced `direct_port_count` 100 → 20

### 2. provision-reliable.sh
- **Cloudflare URL**: Write to both `.comfyui_tunnel_url` and `COMFYUI_URL.txt`
- **Messaging**: Note that "remote port forwarding failed" is Vast.ai SSH noise – ignore it, use Cloudflare URL
- **End message**: Clarify that provisioning completed even if SSH errors appear

### 3. .env
- **COMFYUI_PROVISION_SCRIPT**: Switched from pinned commit URL (404) to unpinned `.../raw/provision-reliable.sh`

### 4. docs/PROVISION_CHECKLIST.md
- Document working unpinned URL; warn that pinned commit URLs can 404

---

## Failures and Known Issues

### 1. retry_failed_downloads log spam (FIXED v3.1)
- **Cause**: provision_errors.log contained aria2 diagnostic output (from `tail -n 80`); script logged `❌ unknown` for every line.
- **Fix**: Only log lines matching `FAILED: <filename>`; skip non-matching lines. Use `grep -c 'FAILED:'` for count.

### 2. mm_sdxl_v10_beta.ckpt 404 (FIXED v3.1)
- **Cause**: `huggingface.co/camenduru/AnimateDiff-sdxl-beta` returns 404.
- **Fix**: Use `huggingface.co/guoyww/animatediff/resolve/main/mm_sdxl_v10_beta.ckpt`.

### 3. ComfyUI-Copilot not installed (FIXED v3.1)
- **Cause**: ComfyUI-Copilot was never in NODES list; provision-reliable-fixed.sh referenced Starttoaster (404).
- **Fix**: Add AIDC-AI/ComfyUI-Copilot to NODES.

### 4. 502 Bad Gateway / Cloudflare URL stops working (MITIGATED v3.1)
- **Cause**: cloudflared forwards to localhost:8188; if ComfyUI down or instance restarted, 502 or URL dies.
- **Mitigation**: Post-connect verification; restart-cloudflare-tunnel.sh helper; documentation.

### 5. "remote port forwarding failed for listen port 34656"
- **Cause**: Vast.ai Instance Portal sets up SSH port forwards when you view logs. One of those forwards (34656) fails repeatedly on some instances.
- **Impact**: Log spam. Provisioning still completes – this is from Vast.ai’s SSH client, not our script.
- **Mitigation**: Simplified PORTAL_CONFIG, added Cloudflare tunnel as primary access, clarified messaging. If Vast rejects `ssh_direct`, revert it.

### 6. Pinned Gist URL 404
- **Cause**: `.env` used `.../raw/7aad3f7/provision-reliable.sh`. That commit became invalid or inaccessible.
- **Impact**: Warm-pool HEAD request returns 404 → falls back to Vast default script → minimal provisioning, wrong models.
- **Fix**: Use unpinned URL `.../raw/provision-reliable.sh`.

### 7. Gist API 401 (Bad credentials)
- **Cause**: GITHUB_TOKEN / GH_TOKEN / NEED_KEY in .env invalid or expired.
- **Impact**: `push-provision-to-gist.js` fails; git fallback works if gist is cloned.
- **Workaround**: Use git push from gist clone (`scripts/push-provision-to-gist.ps1`).

### 8. ssh_direct Parameter
- **Uncertainty**: `ssh_direct: true` may not be supported by Vast.ai rent API; docs mention templates.
- **If rent fails**: Remove `ssh_direct` from rentBody.

---

## Why These Issues Were Missed

1. **retry_failed_downloads spam**: provision_errors.log appended aria2 output; script didn't filter for `FAILED:` lines.
2. **mm_sdxl camenduru 404**: Didn't verify HuggingFace URLs; camenduru repo moved/removed.
3. **ComfyUI-Copilot**: Was in provision-reliable-fixed.sh but never in main provision-reliable.sh.
4. **Pinned URL 404**: Assumed pinned commit URLs were stable. Gist commit hashes can become invalid after force-push or history rewrite. Should have validated URL with HEAD before relying on it.
5. **gistfile1.txt vs provision-reliable.sh**: Gist filenames depend on upload method. Default `gistfile1.txt` 404s when the gist uses `provision-reliable.sh`. Didn’t check gist contents vs configured filename.
6. **"remote port forwarding failed"**: Treated as provisioning failure. It’s Vast.ai’s Instance Portal SSH, not our script. Provisioning completes; logs are just noisy. Should have traced the error source earlier.
7. **China GPUs**: Geolocation filter only excluded Ukraine; China wasn’t in the original exclusion list. Added after explicit request.
8. **PORTAL_CONFIG complexity**: 6+ portal entries increase SSH port forwards. More forwards increase chances of failure on some hosts. Didn’t initially consider simplifying.

---

## Server Status

- **Proxy**: Running via PM2
- **Port**: 3000
- **Prewarm**: Uses corrected gist URL and filters

---

---

## 502 Bad Gateway / Cloudflare Tunnel Reconnection

### Why 502 Bad Gateway?

Cloudflare Quick Tunnel forwards traffic to `localhost:8188` (ComfyUI). A **502** means cloudflared cannot reach ComfyUI. Common causes:

| Cause | Fix |
|-------|-----|
| ComfyUI still starting | Wait 1–2 min; ComfyUI loads models on boot |
| ComfyUI crashed or restarted | Wait for ComfyUI to come back, then retry |
| Instance restarted | cloudflared died — run restart helper (below) |

### Why does the Cloudflare URL stop working after restart?

Cloudflare Quick Tunnel URLs are **ephemeral** and tied to the cloudflared process:

| Scenario | What happens | Fix |
|----------|--------------|-----|
| **ComfyUI process restart only** | cloudflared keeps running; URL still works once ComfyUI is back on 8188 | Wait 1–2 min |
| **Instance restart** (or cloudflared killed) | cloudflared exits → URL dies | Run `bash /workspace/restart-cloudflare-tunnel.sh` |

### How to get a new URL

On the Vast.ai instance (SSH in):

```bash
bash /workspace/restart-cloudflare-tunnel.sh
```

This script waits for ComfyUI on 8188, restarts cloudflared, and prints the new URL (also saved to `/workspace/COMFYUI_URL.txt`).

---

### 5. ComfyUI-Copilot
- **Added**: ComfyUI-Copilot (AIDC-AI) is now in the NODES list — AI assistant for workflow generation, debugging, rewriting.
- **Fallback**: If git clone fails (rate limit, network), use ComfyUI Manager → Custom Nodes → search "ComfyUI-Copilot" → Install.
- **Why**: Needed to build/fix workflows inside ComfyUI (one-click debug, workflow rewrite, node/model recommendations).

---

## Next Steps

1. Run one-click start and confirm provisioning completes
2. If rent fails with `ssh_direct`, remove it from warm-pool.js
3. Fix GITHUB_TOKEN for gist API push if desired
4. Verify Cloudflare URL is visible and usable when "remote port forwarding failed" appears
