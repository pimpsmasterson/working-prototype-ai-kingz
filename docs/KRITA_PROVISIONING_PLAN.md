# Krita + Rented Instance: Provisioning and Script Impact Report (Full Plan)

> Consolidated plan with all details from our discussion. Reference: `.cursor/plans/krita_provisioning_impact_report_6ed4fb39.plan.md`

---

## Executive Summary

Your project uses a **warm pool** that provisions Vast.ai instances with ComfyUI, exposes them via public IP or Cloudflare tunnel, and routes Studio UI requests through the proxy (`/api/proxy/comfy`). Krita works in **hybrid mode**: Krita runs **locally on your PC** and connects **directly** to the ComfyUI instance (via URL), **not** through your proxy. Provisioning is largely compatible but requires **3 additional custom nodes** and clear documentation.

---

## 1. Where Everything Runs

| Component | Location | Purpose |
|-----------|----------|---------|
| **Krita** | Your Windows PC (in `tools/krita/`) | Painting UI, creative work |
| **Krita AI Diffusion plugin** | Inside Krita on your PC | Sends prompts/images to ComfyUI, receives results |
| **ComfyUI** | Rented Vast.ai instance | Runs AI models on GPU |
| **Cloudflare tunnel** | Started on instance during provisioning | Exposes ComfyUI at `https://xxx.trycloudflare.com` |

**Krita is always installed locally. Never on the rented instance.**

---

## 2. Provision Script Details

### 2.1 Main Script

- **File:** `scripts/provision-reliable.sh`
- **Served from:** GitHub Gist
- **Gist ID:** `9fb9d7c60d3822c2ffd3ad4b000cc864`
- **Canonical URLs:**
  - Base: `https://gist.githubusercontent.com/pimpsmasterson/9fb9d7c60d3822c2ffd3ad4b000cc864/raw`
  - Script: `https://gist.githubusercontent.com/pimpsmasterson/9fb9d7c60d3822c2ffd3ad4b000cc864/raw/provision-reliable.sh`

### 2.2 How Provisioning Runs

1. Warm pool rents a Vast.ai instance
2. `onstart` downloads script from `COMFYUI_PROVISION_SCRIPT` (from `.env`)
3. Runs: `bash -x /tmp/provision.sh`
4. ComfyUI starts on `0.0.0.0:8188`
5. Cloudflare Quick Tunnel starts; URL appears in provision log (`provision_v3.log`)

### 2.3 Gist Verification (Always Check Before Run)

Ensure `.env` has:

```
COMFYUI_PROVISION_SCRIPT=https://gist.githubusercontent.com/pimpsmasterson/9fb9d7c60d3822c2ffd3ad4b000cc864/raw/provision-reliable.sh
SCRIPTS_BASE_URL=https://gist.githubusercontent.com/pimpsmasterson/9fb9d7c60d3822c2ffd3ad4b000cc864/raw
```

**Critical:** Use `.../raw/provision-reliable.sh`, never `gistfile1.txt` — warm pool rejects it.

Verify with:
```powershell
grep -E "COMFYUI_PROVISION_SCRIPT|SCRIPTS_BASE_URL" .env
```

### 2.4 Push Workflow

After editing `provision-reliable.sh`, push to Gist:
```powershell
.\scripts\push-provision-to-gist.ps1
```
Requires `GITHUB_TOKEN` (or `GH_TOKEN`) in `.env` with Gists scope.

---

## 3. What to Add to Provision Script

### 3.1 Three Krita-Required Nodes

Add to `scripts/provision-reliable.sh` in the `NODES` array (after line ~297):

```bash
# Krita AI Diffusion plugin required nodes
"https://github.com/Fannovel16/comfyui_controlnet_aux"
"https://github.com/Acly/comfyui-inpaint-nodes"
"https://github.com/Acly/comfyui-tooling-nodes"
```

### 3.2 Already Present

- IP-Adapter (`ComfyUI_IPAdapter_plus`) — no change
- GGUF (`ComfyUI-GGUF`) — no change
- Checkpoints, LoRAs, etc. — sufficient for Krita

---

## 4. Krita Installation (Project Subfolder)

### 4.1 Location and Type

- **Folder:** `tools/krita/` (inside project)
- **Type:** Portable (extract ZIP, no system install)

### 4.2 Steps

1. Create `tools/krita/` folder
2. Download Krita portable ZIP from [krita.org/en/download](https://krita.org/en/download)
3. Extract contents into `tools/krita/`
4. Run `tools/krita/krita.exe` to launch
5. Install AI Diffusion plugin:
   - Tools → Scripts → Import Python Plugin from File
   - Select plugin ZIP from [GitHub releases](https://github.com/Acly/krita-ai-diffusion/releases/latest)
6. Enable docker: Settings → Dockers → AI Image Generation (check the box)

### 4.3 Connecting Krita to ComfyUI

In Krita's AI Image Generation docker:
- Click **Configure**
- Select **Custom Server**
- Enter the ComfyUI URL (see Section 5)
- Click **Connect**

---

## 5. Getting the ComfyUI URL for Krita

### Option A: Cloudflare (Recommended)

1. After provisioning completes, get URL from provision log:
   ```bash
   grep trycloudflare /workspace/provision_v3.log
   # or
   tail -100 /workspace/provision_v3.log
   ```
2. Or SSH and run: `cat /workspace/.comfyui_tunnel_url`
3. Paste full URL (e.g. `https://abc123-xyz.trycloudflare.com`) into Krita — no spaces

### Option B: SSH Tunnel

1. Run: `.\scripts\open-comfy-vastai.ps1 -InstanceId <YOUR_INSTANCE_ID>`
2. In Krita, use: `http://localhost:8080` (or `-LocalPort` value)

### Option C: Direct IP

From admin/warm-pool status, use `connectionUrl` (e.g. `http://PUBLIC_IP:8188`)

---

## 6. Vast.ai Permanent Template

| Option | What it is | Use case |
|--------|------------|----------|
| **Rent template** | Saved rent configuration | Same setup every time; no manual re-entry |
| **Custom image** | Snapshot of provisioned instance | Skips provisioning; much faster startup |

- **Rent template:** Rent once, save config in Vast.ai "Save as template"
- **Custom image:** Provision instance, snapshot it, use that image for future rents

---

## 7. Implementation Checklist

| # | Action | File / Step | Notes |
|---|--------|-------------|-------|
| 1 | Edit | `scripts/provision-reliable.sh` | Add 3 Krita nodes to NODES array (after ~line 297) |
| 2 | Run | `scripts/push-provision-to-gist.ps1` | Push to Gist (requires GITHUB_TOKEN in .env) |
| 3 | Verify | `.env` | `grep -E "COMFYUI_PROVISION_SCRIPT|SCRIPTS_BASE_URL" .env` |
| 4 | Create | `tools/krita/` | Folder for Krita portable |
| 5 | Download | krita.org | Krita portable ZIP, extract to `tools/krita/` |
| 6 | Create | `tools/krita/README.md` | Setup + connection instructions |
| 7 | Create | `docs/KRITA_SETUP.md` | Full Krita + Cloudflare setup guide |
| 8 | Update | `scripts/PROVISION_README.md` | Add Krita compatibility section |

---

## 8. End-to-End Flow (After Setup)

1. Run `one-click-start.ps1` — starts proxy + prewarms instance
2. Wait for provisioning (~10–20 min); Cloudflare tunnel URL appears in log
3. Get URL from log (or SSH) — see Section 5
4. Launch Krita from `tools/krita/krita.exe`
5. Configure AI Image Generation → Custom Server → paste URL → Connect
6. Generate images; Krita sends work to remote ComfyUI

---

## 9. Summary

| Component | Impact | Action |
|-----------|--------|--------|
| provision-reliable.sh | Add 3 nodes | Add comfyui_controlnet_aux, comfyui-inpaint-nodes, comfyui-tooling-nodes |
| Warm pool | None | No changes |
| Proxy | None | Krita bypasses proxy |
| open-comfy-vastai.ps1 | Use as-is | Document for SSH tunnel fallback |
| Documentation | New + update | Add KRITA_SETUP.md, tools/krita/README.md, update PROVISION_README |
