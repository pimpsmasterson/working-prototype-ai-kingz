# 🏗️ AI KINGS: Technical Engineering & Infrastructure Report
**Date:** February 8, 2026
**Subject:** Backend Stability & Provisioning Architecture (v6.1+)

## 1. Environment Stability (The SQLAlchemy "Shield")
The primary technical blocker was a dependency conflict where custom nodes would downgrade `SQLAlchemy`, breaking ComfyUI's internal database manager. 

**Engineering Fix:** Implemented a **Triple-Layer Defensive Strategy**:
*   **Layer 1 (Bootstrap):** Forces `SQLAlchemy>=2.0.0` during initial `pip install`.
*   **Layer 2 (Post-Install Quarantine):** Re-runs the upgrade command *after* all custom nodes have finished installing their own requirements. This overwrites any "sneaky" downgrades.
*   **Layer 3 (Pre-Flight Execution):** Every time the `start_comfyui` function is called, it performs a real-time Python check (`import sqlalchemy`). If it detects version < 2.0, it self-repairs the environment before launching the process.

---

## 2. Model Integrity & "Anti-Stub" Logic
We discovered that high-latency connections were causing "Silent Failures" where model files (Checkpoints) were created as empty 1KB stubs or corrupted 700KB fragments. ComfyUI would then hang indefinitely trying to load them.

**Engineering Fix:** **Size-Based Verification Protocol**:
*   **Thresholds:** Each model category now has a mandated `min_size` in the provisioning script (Checkpoints: 500MB, VAE: 50MB, Nodes: 1MB).
*   **Auto-Purge:** If a file exists but is below the threshold, the script executes `rm -f` and re-triggers the download batch.
*   **Mirror Logic:** Switched to a **Primary | Fallback** array. If HuggingFace (Primary) fails/throttles, the script immediately switches to Dropbox/Civitai mirrors.

---

## 3. High-Reliability Process Management
Instances on Vast.ai often lack a full `systemd` init system, causing background processes to die when the SSH session ends.

**Engineering Fix:**
*   **Conditional Init:** The script detects if `systemctl` is available. If not, it falls back to a custom `monitor_processes` loop that runs as a nohup background process.
*   **Startup Verification Loop:** Instead of just firing the "start" command, the script now uses a `curl --retry` loop against `localhost:8188`. It will not signal "Success" until the ComfyUI API responds with a 200 OK.
*   **PID Shielding:** Added centralized PID management in `/workspace/*.pid` to prevent "Ghost Processes" from double-binding ports 8188 and 8080.

---

## 4. Disk Space Intelligence (The 100GB Guard)
Running out of disk space during provisioning often leads to corrupted databases and half-written models.

**Engineering Fix:**
*   **Dynamic Provisioning:** The script now calculates `available_gb` before downloading "Heavy" assets (Flux/SD3.5).
*   **The 100GB Rule:** If the instance disk is smaller than 100GB, the script automatically skips multi-gigabyte models to preserve the integrity of the primary SDXL/Pony stack.

---

## 5. Network & Tunnel Architecture
*   **Cloudflare Persistence:** Switched to a session-bound tunnel that auto-restarts if it detects a `connection reset`.
*   **Vast.ai Proxy Optimization:** Configured `.env` with `DISABLE_CLOUDFLARED=1` capability to allow seamless failover to Vast's built-in TCP proxies if Cloudflare is blocked in specific regions.

---

## Summary of Updated Source-of-Truth
The repository `scripts/provision-image-only.sh` (v6.1) is now the definitive engineering template. It is fully decoupled from local files and pulls its logic directly from the GitHub Master branch to ensure every new GPU instance is identical and "Bulletproof."
