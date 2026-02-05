# Current Status Report - 2026-02-05

## Post-Mortem: Provision Failures and Fixes

### Status Summary

| Item | Status |
|------|--------|
| **Gist URL** | ✅ Use unpinned `.../raw/provision-reliable.sh` (NOT pinned commit – 404s) |
| **gistfile1.txt** | ❌ 404 – gist has `provision-reliable.sh`, NOT gistfile1.txt |
| **China/Ukraine GPUs** | ✅ Excluded in warm-pool filter |
| **PORTAL_CONFIG** | ✅ Simplified (ComfyUI + Instance Portal only) to reduce "remote port forwarding failed" |
| **ssh_direct** | ⚠️ Added – may not be supported by Vast rent API |
| **direct_port_count** | Reduced 100 → 20 |
| **Cloudflare tunnel** | ✅ Prominent URL, COMFYUI_URL.txt, note about SSH noise |

---

## Changes Made (This Session)

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

### 1. "remote port forwarding failed for listen port 34656"
- **Cause**: Vast.ai Instance Portal sets up SSH port forwards when you view logs. One of those forwards (34656) fails repeatedly on some instances.
- **Impact**: Log spam. Provisioning still completes – this is from Vast.ai’s SSH client, not our script.
- **Mitigation**: Simplified PORTAL_CONFIG, added Cloudflare tunnel as primary access, clarified messaging. If Vast rejects `ssh_direct`, revert it.

### 2. Pinned Gist URL 404
- **Cause**: `.env` used `.../raw/7aad3f7/provision-reliable.sh`. That commit became invalid or inaccessible.
- **Impact**: Warm-pool HEAD request returns 404 → falls back to Vast default script → minimal provisioning, wrong models.
- **Fix**: Use unpinned URL `.../raw/provision-reliable.sh`.

### 3. Gist API 401 (Bad credentials)
- **Cause**: GITHUB_TOKEN / GH_TOKEN / NEED_KEY in .env invalid or expired.
- **Impact**: `push-provision-to-gist.js` fails; git fallback works if gist is cloned.
- **Workaround**: Use git push from gist clone (`scripts/push-provision-to-gist.ps1`).

### 4. ssh_direct Parameter
- **Uncertainty**: `ssh_direct: true` may not be supported by Vast.ai rent API; docs mention templates.
- **If rent fails**: Remove `ssh_direct` from rentBody.

---

## Why These Issues Were Missed

1. **Pinned URL 404**: Assumed pinned commit URLs were stable. Gist commit hashes can become invalid after force-push or history rewrite. Should have validated URL with HEAD before relying on it.
2. **gistfile1.txt vs provision-reliable.sh**: Gist filenames depend on upload method. Default `gistfile1.txt` 404s when the gist uses `provision-reliable.sh`. Didn’t check gist contents vs configured filename.
3. **"remote port forwarding failed"**: Treated as provisioning failure. It’s Vast.ai’s Instance Portal SSH, not our script. Provisioning completes; logs are just noisy. Should have traced the error source earlier.
4. **China GPUs**: Geolocation filter only excluded Ukraine; China wasn’t in the original exclusion list. Added after explicit request.
5. **PORTAL_CONFIG complexity**: 6+ portal entries increase SSH port forwards. More forwards increase chances of failure on some hosts. Didn’t initially consider simplifying.

---

## Server Status

- **Proxy**: Running via PM2
- **Port**: 3000
- **Prewarm**: Uses corrected gist URL and filters

---

## Next Steps

1. Run one-click start and confirm provisioning completes
2. If rent fails with `ssh_direct`, remove it from warm-pool.js
3. Fix GITHUB_TOKEN for gist API push if desired
4. Verify Cloudflare URL is visible and usable when "remote port forwarding failed" appears
