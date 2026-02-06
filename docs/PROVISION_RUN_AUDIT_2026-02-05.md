# Provision Run Audit — 2026-02-05

## Executive Summary

This document compares provision runs, documents failures, and explains why time and money were wasted. It is based on logs in `logs/`, `server_start.log`, `server_restart.log`, `proxy.log`, `pm2_watchdog.log`, and user-reported Vast.ai Instance Portal output.

---

## Run Comparison

### Earlier Runs (Logs Show Failure or Empty)

| Contract ID | Remote (SSH) | Outcome | Root Cause |
|-------------|--------------|---------|------------|
| 30845235 | ssh8.vast.ai:15234 | **FAILED** | ECONNREFUSED 52.90.27.194:15234 — 5 consecutive errors, log collection aborted |
| 30845510 | ssh2.vast.ai:15510 | **EMPTY** | Remote log empty — collector looked for `/workspace/provision_core.log` but script writes `/workspace/provision_v3.log` |
| 30846018 | ssh1.vast.ai:16018 | **TIMEOUT** | 3600s timeout, remote log empty — same path mismatch |
| 30848816 | ssh5.vast.ai:18816 | **TIMEOUT** | 3600s timeout, remote log empty — same path mismatch |

**Critical bug:** `scripts/collect_provision_logs.js` uses `remoteLogPath: '/workspace/provision_core.log'` while `scripts/provision-reliable.sh` writes to `${WORKSPACE}/provision_v3.log` (typically `/workspace/provision_v3.log`). The log collector has **never** successfully fetched provision output — all local provision logs are empty.

### This Run (Instance 30994895)

| Property | Value |
|----------|-------|
| Instance ID | 30994895 |
| Host ID | 79466 |
| GPU | 2x RTX 2060S, 16GB VRAM |
| IP | 142.170.89.112 |
| Cost | $0.176/hr |
| Network | 3013.8 Mbps down, 1474.3 Mbps up |
| Status | Provisioning ran (user viewed in Vast.ai Instance Portal) |

**Source of logs:** User saw output in **Vast.ai Instance Portal** (web UI), not from our proxy's log collector. Vast streams onstart stdout to the browser. Our `collect_provision_logs.js` was never fixed to use `provision_v3.log`.

**This run (30994895) vs earlier runs:**
- No "remote port forwarding failed" spam in user's paste (simplified PORTAL_CONFIG may have helped)
- PyTorch 2.5.1+cu124, insightface, nodes installed
- Some node requirements failed (ComfyUI-Manager, VideoHelperSuite, DepthAnythingV2, WanVideoWrapper) — non-fatal, script continues
- Provisioning appeared to proceed; outcome unknown without final log

---

## What Went Wrong and Why Time/Money Were Wasted

### 1. Pinned Gist URL 404

- **What:** `.env` used `.../raw/7aad3f7/provision-reliable.sh`. That commit returned 404.
- **Impact:** Warm-pool HEAD request failed → fell back to Vast.ai default script → minimal provisioning, single Civitai model, no full ComfyUI setup. Instance billed while running wrong script.
- **Why missed:** Assumed pinned URLs are stable. Gist commit hashes can become invalid after force-push or history rewrite.
- **Cost:** Each failed/incorrect provision = ~$0.15–0.20/hr × runtime (often 30–60+ min) = wasted spend.

### 2. gistfile1.txt vs provision-reliable.sh

- **What:** Warm-pool or docs referenced `gistfile1.txt`, but the gist file is named `provision-reliable.sh`.
- **Impact:** 404 → fallback to Vast default script, same as above.
- **Why missed:** Gist filenames depend on upload method; default is `gistfile1.txt`. No validation that configured URL matched actual gist contents.

### 3. Log Collector Path Mismatch

- **What:** `collect_provision_logs.js` reads `/workspace/provision_core.log`. Provision script writes `/workspace/provision_v3.log`.
- **Impact:** All provision log collections return empty. No local visibility into provision output. Debugging relied on Vast.ai UI or manual SSH.
- **Why missed:** Log path was not audited when switching from `provision_core.sh` to `provision-reliable.sh` (which uses `provision_v3.log`).

### 4. "remote port forwarding failed" Misdiagnosis

- **What:** Repeated "Error: remote port forwarding failed for listen port 34656" in logs.
- **Impact:** Treated as provisioning failure. Provisioning actually completed — the error is from Vast.ai's Instance Portal SSH, not our script.
- **Why missed:** Error origin was not traced. Assumed any error in the stream meant our script failed.
- **Cost:** Extra rent attempts and debugging time on instances that were likely fine.

### 5. China GPUs Not Excluded

- **What:** Geolocation filter only excluded Ukraine; China was included.
- **Impact:** Instances in China could have higher latency, firewall issues, or policy concerns for the user.
- **Why missed:** Exclusion list was not reviewed; China added only after explicit request.

### 6. PORTAL_CONFIG Too Complex

- **What:** 6+ portal entries (Instance Portal, ComfyUI x2, API Wrapper, Jupyter, Syncthing) → many SSH port forwards.
- **Impact:** More port forwards increase chance of "remote port forwarding failed" on some hosts.
- **Why missed:** Did not initially consider reducing portal entries to minimize SSH forward failures.

### 7. AbortController Bug (server_start.log)

- **What:** `fetch-with-retry: AbortController is not a constructor` — Vast.ai API checks fail.
- **Impact:** Instance validation and polling fail; stale instance state possible.
- **Why missed:** Node.js version or polyfill issue; AbortController usage may be incorrect for the runtime.

### 8. PM2 Watchdog JSON Parse Error

- **What:** `Failed to parse pm2 jlist JSON: ... duplicated keys 'USERNAME' and 'username'`.
- **Impact:** Watchdog resurrections may fail or behave unexpectedly.
- **Why missed:** PM2 dump format or parsing assumed unique keys; Windows/env can produce case-variant duplicates.

### 9. proxy.log: "node" Not Found

- **What:** `nohup: failed to run command 'node': No such file or directory`.
- **Impact:** Some startup path cannot find Node; likely a PATH or environment issue when running from a context without Node in PATH.

### 10. Provision Log Collection ECONNREFUSED

- **What:** Contract 30845235 — `connect ECONNREFUSED 52.90.27.194:15234`.
- **Impact:** SSH to instance failed; instance may have been down, firewalled, or port not yet ready.
- **Cost:** Instance billed; no logs collected.

---

## Summary of Waste

| Category | Cause | Consequence |
|----------|-------|-------------|
| Wrong script ran | Pinned gist 404, gistfile1.txt 404 | Minimal provisioning, wrong models, instance useless for full workflow |
| Billing on bad instances | Rent before validation, no early termination | Paid for instances that never became usable |
| Debugging blind | Log collector path mismatch | No local logs; relied on manual Vast.ai UI |
| Misdiagnosis | "remote port forwarding failed" treated as fatal | Assumed failure when provisioning may have completed |
| Repeated rents | Each fix attempted without full validation | Multiple $0.15–0.20/hr runs |

---

## Fixes Applied (This Session)

1. **Gist URL:** Switched to unpinned `.../raw/provision-reliable.sh`.
2. **Geolocation:** Excluded China and Ukraine.
3. **PORTAL_CONFIG:** Reduced to ComfyUI + Instance Portal.
4. **ssh_direct + direct_port_count:** Added `ssh_direct: true`, reduced `direct_port_count` 100 → 20.
5. **Cloudflare tunnel:** Prominent URL, COMFYUI_URL.txt, messaging that SSH errors are Vast.ai noise.

---

## Remaining Actions

1. **Fix log collector path:** Change `collect_provision_logs.js` `remoteLogPath` to `/workspace/provision_v3.log`.
2. **Fix AbortController:** Resolve `AbortController is not a constructor` in fetch-with-retry.
3. **Verify Node in PATH:** Ensure `nohup node` runs in an environment where `node` is on PATH.
4. **Validate provision completion:** Confirm instance 30994895 finished and ComfyUI is reachable via Cloudflare or direct port.
