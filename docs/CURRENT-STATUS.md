# Current Status

**Last updated:** 2026-02-07

## Provisioner v3.1.8 — Status Summary

| Item | Status |
|------|--------|
| **Provision script** | v3.1.8 — Canonical gist **002d4121626567402b4c59febbc1297d** (file: `gistfile1.txt`) |
| **Gist** | ✅ Single canonical: `https://gist.github.com/pimpsmasterson/002d4121626567402b4c59febbc1297d` → raw `.../raw/gistfile1.txt` |
| **One-click rent** | ✅ `one-click-rent.ps1` — restart server, reset state, prewarm; single entry point |
| **Whitelist** | Only gist 002d41... allowed; old gists (9fb9d7c60, c3f61f20) removed |
| **China/Ukraine GPUs** | ✅ Excluded in warm-pool filter |
| **Cloudflare tunnel** | ✅ Post-connect verification, restart-cloudflare-tunnel.sh helper |
| **Current issue** | Ready for new rental; server uses .env → canonical gist |
| **Network requirement** | 2000 Mbps (2 Gbps) minimum |
| **Disk requirement** | 200 GB minimum |

---

## What's Working

- **One-click start** (`one-click-start.ps1`) runs end-to-end: prerequisites, env load, port cleanup, PM2 start, health check, prewarm.
- **One-click rent** (`one-click-rent.ps1`): restart server, reset state, prewarm — single entry point for new rental.
- **Server** starts via PM2 (`vastai-proxy`); health at `http://localhost:3000/api/proxy/health`.
- **Warm pool** reports instance when already present or starts prewarm; uses canonical gist 002d41.../gistfile1.txt only.
- **Studio UI:** `http://localhost:3000/pages/studio.html`
- **Admin dashboard:** `http://localhost:3000/admin/warm-pool`

### Failure history (provision fixes)

| # | Failure | Fix (v) |
|---|---------|---------|
| 1 | retry_failed_downloads log spam | Only log lines with `FAILED:` (3.1) |
| 2 | mm_sdxl_v10_beta.ckpt 404 | guoyww/animatediff source (3.1) |
| 3 | ComfyUI-Copilot not installed | AIDC-AI/ComfyUI-Copilot in NODES (3.1) |
| 4 | 502 / Cloudflare URL dies | Post-connect check + restart helper (3.1) |
| 5 | Civitai token HTTP 307 | curl `-L` follow redirects (3.1.1) |
| 6 | detect_cuda_version pollutes cuda_tag | Log to stderr; skip invalid nvidia-smi (3.1.1) |
| 7 | ComfyUI readiness timeout (connection refused) | Use `/` not `/system_stats`; 10 min wait; start tunnel anyway (3.1.2) |
| 8 | Pinned Gist URL 404 | Unpinned `.../raw/provision-reliable.sh` |
| 9 | Gist API 401 | Git push from gist clone |
| 10 | git clone hangs (rgthree-comfy) | timeout 180s on all git clones; fix exit code check (3.1.3) |
| 11 | Civitai token validation 200000 | curl \|\| echo 000 concatenated; separate capture (3.1.3) |
| 12 | ComfyUI startup timeout (no diagnostics) | Process monitoring, port checks, comprehensive error detection (3.1.4) |
| 13 | Port 8188 conflicts (Address already in use) | free_port_8188() detects/kills processes before start (3.1.5) |
| 14 | ComfyUI fails silently (no root cause) | diagnose_comfyui_failure() hunts for errors (3.1.5) |
| 15 | SQLAlchemy ImportError (mapped_column) | Added sqlalchemy>=2.0.0 to dependencies + pre-start upgrade check (3.1.7) |
| 16 | Security warning (malicious script execution) | URL whitelist validation, security audit logging (3.1.7) |
| 17 | Dropbox gist URL 404 (pinned commit) | Switched to reliable gist; then canonical gist 002d41... (3.1.8) |
| 18 | Wrong script used (Dropbox vs reliable) | .env and whitelist fixed to reliable; then single canonical gist everywhere (3.1.8) |
| 19 | gistfile1.txt rejected globally | Whitelist now allows 002d41.../gistfile1.txt; blanket gistfile1 rejection removed (3.1.8) |

### v3.1.8 / 2026-02-07 — Canonical Gist & One-Click Rent

- **Single canonical gist**: All provisioning uses **only** gist `002d4121626567402b4c59febbc1297d` (file `gistfile1.txt`). Old gists removed from whitelist.
- **server/warm-pool.js**: Whitelist allows only that gist with `gistfile1.txt`; no HEAD check for whitelisted URL (gist redirects can cause false fallback).
- **one-click-rent.ps1**: New script — restart server, reset-state, prewarm (600s timeout). Single entry point for rental.
- **AI failures addressed**: 404 from pinned Dropbox gist; wrong script (Dropbox vs reliable); gistfile1.txt blanket rejection — all fixed by single canonical gist and whitelist.

---

## Why One-Click Start Was Broken (Failure Analysis)

One-click start had been broken since integration/recent changes due to **PowerShell parsing and variable issues**, not server or API logic.

### 1. Script never ran – parse error at line 311

- **Symptom:** `The string is missing the terminator: ".` at line 311 (`Write-Host "…" -ForegroundColor Magenta`).
- **Cause:** File contained **Unicode** (emojis like 🎉, ✅, ❌, box-drawing ╔═║╚, 🌐📊💡). When PowerShell runs the script with default/system encoding (e.g. Windows-1252 or no BOM), it can misread UTF-8 multi-byte sequences. One of those sequences was interpreted in a way that broke the closing quote of a string, so the parser thought the string never ended.
- **Fix:** Replaced all Unicode in the script with **ASCII** (`[OK]`, `[X]`, `[!]`, `===`, plain text). Script now parses correctly regardless of console encoding.

### 2. Parse error at line 117 (after first fix)

- **Symptom:** `Variable reference is not valid. ':' was not followed by a valid variable name character` at `$port:`.
- **Cause:** In PowerShell, `$port:` is parsed as a **drive/scope** (e.g. like `C:`). The parser treats the colon as part of the variable reference, so it expects a valid variable name after `:`.
- **Fix:** Used string concatenation for the warning message instead of interpolating `$port:` in a double-quoted string, e.g. `"… port " + $port + ": " + …`. Alternatively `${port}:` would work.

### 3. Port cleanup fallback failed – "Cannot overwrite variable PID"

- **Symptom:** When something was listening on a port, port cleanup hit: `Cannot overwrite variable PID because it is read-only or constant` (and netstat fallback failed the same way).
- **Cause:** **`$pid` is a read-only automatic variable** in PowerShell (current process ID). The script used `$pid` as a loop variable and for process IDs when killing processes, which overwrote the automatic variable.
- **Fix:** Renamed all such uses to **`$procId`** in both the `Get-NetTCPConnection` path and the netstat fallback.

### 4. Noisy warnings when ports were already free

- **Symptom:** Long WARNING every run: "Port cleanup failed for port 3000 using Get-NetTCPConnection: No matching MSFT_NetTCPConnection objects found… Attempting netstat fallback."
- **Cause:** On this system, `Get-NetTCPConnection -LocalPort $port -State Listen` **throws** when no connection exists (instead of returning empty). The script treated that as "failure" and ran the fallback.
- **Fix:** In the catch block, if the message matches "No matching.*MSFT_NetTCPConnection", treat as "port is free" and `continue` without warning or fallback.

---

## Summary Table

| Issue | Cause | Fix |
|-------|--------|-----|
| Script won’t run; string terminator at 311 | Unicode in script + encoding | All output/decoration to ASCII |
| Invalid variable `$port:` at 117 | Parser sees drive/scope | Concatenation or `${port}` |
| Cannot overwrite variable PID | `$pid` is read-only | Use `$procId` everywhere |
| Spam when ports free | Get-NetTCPConnection throws when empty | Treat "No matching…" as success, skip warning |

---

## Recommended Next Steps

1. **New rental**: Run `.\one-click-rent.ps1` — restarts server, reset-state, prewarm (single entry point).
2. **Restore `.env.example`** if it was deleted accidentally (template only, no secrets).
3. Keep **one-click-start.ps1** as the single canonical launcher; align **one-click-start-fixed.ps1** / **start-ai-kings*.ps1** or retire them to avoid drift.
4. For **provisioning/warm pool**: see `docs/ONE-CLICK-START-AUDIT.md` and server logs (`pm2 logs vastai-proxy`) if instance rent or ComfyUI readiness is still failing.

---

### provision-reliable.sh (changelog detail)
- **Port 8188 conflict resolution**: `free_port_8188()` function detects processes using port 8188 (via ss/netstat/lsof), kills them, verifies port is free before starting ComfyUI
- **Comprehensive diagnostics**: `diagnose_comfyui_failure()` function checks: process status, port listening, log analysis (50 lines), error pattern matching (ModuleNotFoundError, CUDA errors, port conflicts, permissions, disk full, syntax errors), Python/CUDA availability, disk space, ComfyUI file existence
- **Process monitoring**: Verify ComfyUI PID is alive during wait; detect immediate crashes
- **Port checks**: Use ss/netstat to check if port 8188 is listening (faster than HTTP)
- **Better error messages**: Distinguish 502 (ComfyUI not ready) vs connection failed vs rate limit
- **Actionable fixes**: Each error type includes suggested fix

---

## v3.1.4 Changelog (2026-02-06)

### provision-reliable.sh
- **Process monitoring**: Verify ComfyUI PID is alive during wait; detect immediate crashes
- **Port checks**: Use ss/netstat to check if port 8188 is listening (faster than HTTP)
- **Error detection**: Detect ModuleNotFoundError, CUDA errors, port conflicts
- **Cloudflare tunnel diagnostics**: Verify tunnel process is alive; better error messages
- **Better diagnostics output**: Process status, port status, HTTP response codes with meaning

---

## v3.1.3 Changelog (2026-02-06)

### provision-reliable.sh
- **git clone timeout**: Add `timeout 180` to all git clone commands (ComfyUI base + custom nodes) — prevents indefinite hangs on slow submodules (e.g. rgthree-comfy)
- **Exit code fix**: Use `PIPESTATUS[0]` to check actual git clone exit code, not grep's exit code from pipeline
- **Timeout logging**: Log "Clone timed out (180s)" when timeout occurs before retry
- **Civitai token validation**: Fix `200000` bug — removed `|| echo 000` from inside `$()`; capture curl output separately, only set `000` if response is empty

---

## v3.1.2 Changelog (2026-02-06)

### provision-reliable.sh
- **ComfyUI readiness**: Use `http://localhost:8188/` (root) instead of `/system_stats` — universal in ComfyUI
- **Wait**: 5 min → 10 min (120 × 5s)
- **Tunnel on timeout**: If ComfyUI not ready after 10 min, start tunnel anyway; tail comfyui.log; log restart helper message
- **restart-cloudflare-tunnel.sh**: Same `/`-based check
- **Tunnel verification**: Use `/` instead of `/system_stats`

---

## v3.1 / v3.1.1 Changelog

### provision-reliable.sh
1. **Version bump** v3.0 → v3.1
2. **retry_failed_downloads** — Only log lines matching `FAILED:`; skip aria2 diagnostic output (fixes `❌ unknown` spam)
3. **failed_count** — Use `grep -c 'FAILED:'` instead of `wc -l` for accurate count
4. **mm_sdxl_v10_beta.ckpt** — Switch from camenduru (404) to guoyww/animatediff
5. **ComfyUI-Copilot** — Add AIDC-AI/ComfyUI-Copilot to NODES list
6. **Cloudflare post-connect verification** — Curl `${TUNNEL_URL}/system_stats` to verify reachability
7. **restart-cloudflare-tunnel.sh** — Write helper script at `/workspace/restart-cloudflare-tunnel.sh` for 502/recovery
8. **Log message** — Add "If URL stops working (502/restart): bash /workspace/restart-cloudflare-tunnel.sh"

### Instance 30995556 findings (v3.1.1 fixes)
9. **Civitai token HTTP 307**: Civitai redirects download URLs; curl without `-L` returns 307. Added `-L` to follow redirects.
10. **detect_cuda_version bug**: (a) Some nvidia-smi lack `--query-gpu=cuda_version` and return "Field ... is not a valid field"; skip to driver inference. (b) `log` output was captured by `$(detect_cuda_version)` — `cuda_tag` contained log text + cu124. Redirect log to stderr in detect_cuda_version.
11. **CUDA 12.6/12.8**: Map to cu124 (PyTorch cu124 works with 12.4+).

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

### 9. Civitai token HTTP 307 (FIXED v3.1.1)
- **Cause**: Civitai redirects download URLs with HTTP 307; curl without `-L` returns 307 and fails.
- **Fix**: Added `-L` to curl in `validate_civitai_token` and Civitai downloads.

### 10. detect_cuda_version pollutes cuda_tag (FIXED v3.1.1)
- **Cause**: (a) Some nvidia-smi lack `--query-gpu=cuda_version` and return "Field ... is not a valid field". (b) `log` output was captured by `$(detect_cuda_version)` — `cuda_tag` ended up with log text + cu124.
- **Fix**: Redirect log to stderr; skip invalid nvidia-smi output; infer CUDA from driver; map 12.6/12.8 → cu124.

### 11. ComfyUI readiness timeout (FIXED v3.1.2)
- **Cause**: Script polled `http://localhost:8188/system_stats` — ComfyUI may not expose this in some setups; or ComfyUI crashed during node load. Connection refused for 5+ min.
- **Fix**: Use `http://localhost:8188/` (root, universal); extend wait to 10 min; start tunnel anyway on timeout; tail comfyui.log for diagnostics.

### 12. git clone hangs indefinitely (FIXED v3.1.3)
- **Cause**: `git clone --recursive` on slow repos (e.g. rgthree-comfy with submodules) can hang forever; no timeout.
- **Impact**: Provision script freezes waiting for clone; instance costs money while stuck.
- **Fix**: Add `timeout 180` to all git clone commands; use `PIPESTATUS[0]` to check actual clone exit code (not grep's).

### 13. Civitai token validation returns 200000 (FIXED v3.1.3)
- **Cause**: `response=$(curl ... || echo "000")` — when curl returns 200 but exits 63 (max-filesize abort), both `200` and `000` are captured → `200000`.
- **Impact**: Token validation always fails even when token is valid.
- **Fix**: Capture curl output separately; only set `000` if response is empty (curl failed entirely).

---

## AI Pitfalls (Lessons from AI-Assisted Dev)

1. **Assumed endpoints exist** — Used `/system_stats` without verifying vanilla ComfyUI exposes it. Should have checked docs or used `/` first.
2. **No live verification** — Fixed issues without re-running on fresh instance. Each "fix" cost ~$0.24; should validate before declaring success.
3. **Overconfidence in fixes** — Said "sure" multiple times without fetching gist content or tailing provision logs to confirm.
4. **Pinned URLs assumed stable** — Gist commit hashes can 404 after force-push; unpinned URLs are safer.
5. **Stderr vs stdout in subshells** — `$(func)` captures stdout; diagnostic logs must go to stderr or they pollute variables.
6. **HTTP redirects** — Civitai 307; curl needs `-L` to follow. Didn't test token validation against live redirects.
7. **Container vs host assumptions** — systemd doesn't run in Vast.ai containers; script must fall back to setsid/nohup.
8. **Scope creep** — "remote port forwarding failed" is Vast.ai SSH, not our script; spent time chasing wrong target.

---

## Current Status & Known Issues

### Instance 31010493 (v3.1.6) — SQLAlchemy ImportError
- **Status**: Provision completed, all models downloaded, ComfyUI crashed on startup
- **Symptoms**: `ImportError: cannot import name 'mapped_column' from 'sqlalchemy.orm'`; 502 Bad Gateway from tunnel
- **Root cause**: SQLAlchemy 1.x installed (ComfyUI requires 2.0+)
- **Fix**: v3.1.7 adds `sqlalchemy>=2.0.0` to dependencies and pre-start upgrade check
- **Identification**: Error logs clearly showed ImportError; `diagnose_comfyui_failure()` detected missing module

### AI Failures (Lessons Learned)
1. **Assumed ComfyUI would start** — Didn't add process monitoring or diagnostics initially
2. **No port conflict handling** — Assumed port 8188 was always free
3. **Silent failures** — Waited 10 min without checking why ComfyUI wasn't responding
4. **Minimal error output** — Only showed last 10 lines of log, no pattern matching

---

## Next Steps if v3.1.7 Fails

1. **Check comfyui.log** — `tail -100 /workspace/comfyui.log` on instance. Look for: `ModuleNotFoundError`, `ImportError`, CUDA mismatch, OOM.
2. **ComfyUI crashed?** — If log shows traceback, fix dependency or skip problematic node. Consider reducing NODES list for initial boot.
3. **Still timing out?** — Increase wait to 15 min; or add port-check (`nc -z localhost 8188`) before HTTP check.
4. **Tunnel URL 502** — ComfyUI not up. Run `bash /workspace/restart-cloudflare-tunnel.sh` after ComfyUI is ready.
5. **Gist not updated?** — Verify: `curl -sI https://gist.githubusercontent.com/.../raw/provision-reliable.sh` returns 200. Re-run `scripts/push-provision-to-gist.ps1`.
6. **Rent fails** — If `ssh_direct` causes rent rejection, remove from warm-pool.js rentBody.
7. **Cost spiral** — Stop renting; fix locally; test with `bash -x provision-reliable.sh` in Docker before next rent.

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
9. **Civitai 307**: Didn't test Civitai token validation against live redirects; curl without `-L` fails on HTTP 307.
10. **detect_cuda_version**: Didn't test on hosts where nvidia-smi lacks cuda_version field; didn't isolate stderr from stdout in subshells.
11. **ComfyUI readiness**: Assumed /system_stats exists; vanilla ComfyUI uses /. Should have used / from the start; didn't plan for tunnel-on-timeout.

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

1. **New rental**: Run `.\one-click-rent.ps1` — restarts server, reset-state, prewarm (single entry point).
2. If rent fails with `ssh_direct`, remove it from warm-pool.js.
3. Fix GITHUB_TOKEN for gist API push if desired (push scripts still reference old gist IDs for updating those gists).
4. Verify Cloudflare URL is visible and usable when "remote port forwarding failed" appears.
5. To update **canonical** gist (002d41...): edit content on GitHub Gist UI or use a push script updated for that gist ID.
