# Warm-pool & ComfyUI Deployment Audit — 2026-01-26

## Executive summary ✅
- We successfully validated warm-pool concurrency protection and moved from test/mocked flows to real-world rentals on Vast.ai.
- Two provisioning problems were encountered during real prewarm runs: (1) image extraction failed due to insufficient disk on the host ("no space left on device") and (2) intermittent network/port availability causing frontend ETIMEDOUT when proxying to ComfyUI.
- Immediate mitigation: increased requested ephemeral storage to **250GB** and added direct port filter checks. Removed the stuck instance(s).

---

## Current state (observed) 🛰️
- Proxy: `server/vastai-proxy.js` running locally at `http://localhost:3000/`.
- Warm-pool: `server/warm-pool.js` active; polling enabled in non-test environments.
- Instances observed:
  - Instance `30518793` — previously running; experienced ETIMEDOUT when proxy attempted to reach `http://1.208.108.242:8188` (frontend polling failures). Resolved by terminating when unreachable.
  - Instance `30519173` — encountered container extraction failure with status message:
    "failed to extract layer ... no space left on device" (Vast.ai host overlayfs error). Terminated to stop costs.

---

## Timeline & actions taken (annotated) 🧭
1. Verified warm-pool concurrency tests passing locally (unit tests). ✅
2. Fixed environment key handling (`.env` load) to use real `VASTAI_API_KEY` and `ADMIN_API_KEY`. ✅
3. Provisioning failed due to overlayfs / disk full on the remote host -> increased requested disk from 120GB → 150GB → 250GB in `server/warm-pool.js`. ✅
   - File changes: `disk_space` filter and `disk` rent field updated.
4. Observed ETIMEDOUT when proxy forwarded ComfyUI calls. Added readiness probe `waitForComfyReady()` and increased logging in `server/vastai-proxy.js` to capture headers and auth issues. ✅
5. Terminated failing instances via Vast.ai API when a failure was detected to avoid ongoing charges. ✅

---

## Repro steps & diagnostics performed 🔬
- Used the Vast.ai API to inspect instance details: `curl -H "Authorization: Bearer $VASTAI_API_KEY" https://console.vast.ai/api/v0/instances/<id>/`.
- Verified `status_msg` field showing extraction failure and `public_ipaddr` for connectivity tests.
- From local network: `Test-NetConnection -ComputerName 1.208.108.242 -Port 8188` (TCP connect failed with `False`).
- Observed proxy logs showing `comfy proxy error: connect ETIMEDOUT` and `Prewarm endpoint hit` with header debug logs indicating missing or incorrect admin header in some requests.

---

## Problems & root cause analysis (RCA) 🔎
1. "No space left on device" during container extraction
   - Root cause: Instance host overlayfs ran out of disk while extracting large ComfyUI/provisioning images.
   - Proof: instance `status_msg` containing the overlayfs error pointing to `/var/lib/containerd/.../caddy: no space left on device`.
   - Mitigation: increase requested image disk to **250GB** and require `direct_port_count` in search filters.
   - Recommendation: add an automatic early-detection rule to terminate instances whose `status_msg` includes "no space left" to avoid unpaid stuck instances.

2. ETIMEDOUT connecting to ComfyUI on rented instance
   - Root cause candidates:
     - ComfyUI not yet fully initialized (model downloads, container start) when proxy attempts connection.
     - Direct port mapping may not be assigned immediately (Vast.ai `direct_port_start` sometimes `-1`).
     - Network path (geolocation latency/firewall) or ComfyUI binding mismatches (internal port 18188 vs external 8188 mapping) causing connection failure.
   - Proof: `waitForComfyReady()` sometimes times out; `Test-NetConnection` to host:8188 fails.
   - Mitigation: rely on `waitForComfyReady()` (already implemented), increase timeout and backoff in readiness probe, log `lastStatusMessage` and `direct_port_start/end` in warm-pool `getStatus()`.

3. Admin prewarm call sometimes reports "Key received: NO" (Auth failed)
   - Root cause: client requests did not send the expected header (`x-admin-key` or `x-admin-api-key`) or proxy test used different header capitalization/parameter.
   - Proof: `server/vastai-proxy.js` debug logs showed headers and key presence checks. Logging was added to make this deterministic.
   - Mitigation: make prewarm endpoint accept both `x-admin-key` and `x-admin-api-key` (already present) and surface clear error messages when missing.

---

## Risks & Costs ⚠️
- Failed or stuck instances continue to be billed. A stuck image extraction can accrue storage/hour charges.
- Using 250GB disk increases instance hourly cost (storage cost ~ $0.033/hr for 120GB in prior instances — check Vast.ai pricing per disk size for precise estimate).
- Network instability or long provisioning times cause higher latency for users and may degrade UX in the studio frontend.

---

## Recommended next actions (prioritized) ✅
1. Short-term (0–2 days)
   - Ensure all failing instances are terminated and validate `https://console.vast.ai/api/v0/instances/` shows no stuck instances. (You already issued deletes; verify via API/dash).
   - Restart `server/vastai-proxy.js`, trigger `POST /api/proxy/warm-pool/prewarm` and monitor `proxy.log` and `proxy_err.log` for the first 10 minutes.
   - Increase `waitForComfyReady()` timeout to 5 minutes and add exponential backoff to the readiness poll.
   - Add automatic termination rule: terminate if `status_msg` contains "no space left" or `actual_status` is `load_failed` for > 120 seconds.

2. Medium-term (1–2 weeks)
   - Implement a more robust port-readiness policy: query instance `direct_port_start`, attempt to map to the public ports returned by Vast.ai, and only mark `connectionUrl` when mapped and tested.
   - Add more telemetry to `warmPool.getStatus()` (expose `lastStatusMessage`, `direct_port_start`, `direct_port_end`, `public_ipaddr`) and surface via admin endpoint.
   - Add unit/integration tests that simulate the overlayfs failure response from the Vast.ai API to assert termination behavior.

3. Long-term (ongoing)
   - Introduce metrics & alerting (Prometheus or similar): prewarm success rate, average time to ready, failed extraction count.
   - Add retry strategies and graceful fallbacks: attempt a second image (fallback image) or smaller image with fewer initial model downloads.
   - Consider caching commonly-used images across hosts (if Vast.ai supports persistent templates) or hosting a smaller base image to reduce extraction pressure.

---

## Changes committed in this session (file references) ✍️
- `server/warm-pool.js`:
  - Increased `disk_space` search filter to `gte: 250`.
  - Increased `disk` rent parameter to `250`.
  - Added/updated `direct_port_count` filter logic.
  - Observability: ensured `lastStatusMessage` is recorded from Vast.ai responses.

- `server/vastai-proxy.js`:
  - Added debug header logging to `/api/proxy/warm-pool/prewarm` for auth troubleshooting.
  - Improved proxy error logging for ComfyUI forwarding and port/timeouts.

- New file: `docs/WARM_POOL_AUDIT_2026-01-26.md` — this document (current file) added to `docs/`.

---

## Commands & checks to run now (copy-paste) 🧾
- Verify no stuck instances in Vast.ai:
```powershell
$env:VASTAI_API_KEY = (Get-Content .env | Select-String 'VASTAI_API_KEY=').ToString().Split('=')[1].Trim("'\" ")
curl -H "Authorization: Bearer $env:VASTAI_API_KEY" https://console.vast.ai/api/v0/instances/
```

- Restart proxy and prewarm (PowerShell):
```powershell
taskkill /IM node.exe /F; Start-Process -FilePath node -ArgumentList 'server/vastai-proxy.js' -NoNewWindow -PassThru
Start-Sleep -Seconds 2
Invoke-RestMethod -Method POST -Uri 'http://localhost:3000/api/proxy/warm-pool/prewarm' -Headers @{ 'x-admin-key' = 'secure_admin_key_change_me' }
Invoke-RestMethod -Method GET -Uri 'http://localhost:3000/api/proxy/warm-pool' -Headers @{ 'x-admin-key' = 'secure_admin_key_change_me' }
Get-Content proxy.log -Tail 50
Get-Content proxy_err.log -Tail 50
```

---

## Appendix: Relevant logs / excerpts 📎
- Example failed status message (Vast.ai instance):
> failed to extract layer (application/vnd.oci.image.layer.v1.tar+gzip sha256:...) to overlayfs ...: write /var/lib/containerd/.../caddy: no space left on device

- Proxy ETIMEDOUT observation:
> comfy proxy error: connect ETIMEDOUT 1.208.108.242:8188

---

If you want, I can also:
- push a small PR that auto-terminates failed instances with explanatory audit log, and
- add an admin endpoint to retry prewarm with alternative smaller images when the first attempt fails.

Tell me which of the recommended next actions you want me to implement first and I'll open PRs and tests for them. 

---

Generated by: GitHub Copilot using Raptor mini (Preview)

