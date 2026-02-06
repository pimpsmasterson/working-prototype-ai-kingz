# Krita AI Diffusion + AI Kings ComfyUI Setup

This guide covers using Krita (with the AI Diffusion plugin) with ComfyUI running on rented Vast.ai instances.

## Architecture

- **Krita** runs on your local Windows PC
- **ComfyUI** runs on a rented Vast.ai GPU instance
- **Cloudflare tunnel** (or SSH tunnel) exposes ComfyUI so Krita can connect

Krita sends prompts and images to the remote ComfyUI; the GPU does the AI work and returns results.

## Prerequisites

1. Warm pool running (or manual Vast.ai instance with provisioning complete)
2. Provision script includes Krita nodes: `comfyui_controlnet_aux`, `comfyui-inpaint-nodes`, `comfyui-tooling-nodes`

## Step 1: Install Krita Locally

### Option A: Portable (Project Folder)

1. Create `tools/krita/` if it doesn't exist
2. Download Krita portable from [krita.org/en/download](https://krita.org/en/download)
3. Extract the ZIP into `tools/krita/`
4. Run `tools/krita/krita.exe`

### Option B: Standard Installer

1. Download Krita installer from [krita.org](https://krita.org/en/download)
2. Install like any Windows app

## Step 2: Install Krita AI Diffusion Plugin

1. Download the latest plugin ZIP from [GitHub releases](https://github.com/Acly/krita-ai-diffusion/releases/latest)
2. In Krita: **Tools** → **Scripts** → **Import Python Plugin from File...**
3. Select the downloaded ZIP
4. Restart Krita
5. Enable docker: **Settings** → **Dockers** → **AI Image Generation** (check the box)

## Step 3: Start Your Stack and Get ComfyUI URL

### Start the warm pool

```powershell
.\one-click-start.ps1
```

Wait for provisioning to complete (typically 10–20 minutes).

### Get the ComfyUI URL

**Method 1: Cloudflare tunnel (recommended)**

The provision script starts a Cloudflare Quick Tunnel. The URL is written to the provision log.

- SSH into the instance, then:
  ```bash
  grep trycloudflare /workspace/provision_v3.log
  # or
  cat /workspace/.comfyui_tunnel_url
  ```
- Copy the full URL (e.g. `https://abc123-xyz.trycloudflare.com`)

**Method 2: SSH tunnel**

If Cloudflare fails or you prefer a tunnel:

```powershell
.\scripts\open-comfy-vastai.ps1 -InstanceId <YOUR_INSTANCE_ID>
```

Use `http://localhost:8080` (or the port from `-LocalPort`) in Krita.

**Method 3: Direct IP**

From the admin dashboard (warm pool status), copy the instance `connectionUrl` (e.g. `http://PUBLIC_IP:8188`).

## Step 4: Connect Krita to ComfyUI

1. Open Krita
2. Open the **AI Image Generation** docker (if not visible: Settings → Dockers → AI Image Generation)
3. Click **Configure**
4. Select **Custom Server**
5. Paste the ComfyUI URL (no trailing slash, no spaces)
6. Click **Connect**

The plugin will check for required nodes and models. If something is missing, see the plugin log ("View Log files" in settings).

## Troubleshooting

### Connection fails

- Confirm the instance is running and provisioning completed
- Verify the URL is correct (HTTPS for Cloudflare, HTTP for direct/tunnel)
- Check firewall/network; Cloudflare URLs work from most networks

### "Missing nodes" or "Missing models"

- Ensure `provision-reliable.sh` includes the 3 Krita nodes (see [KRITA_PROVISIONING_PLAN.md](KRITA_PROVISIONING_PLAN.md))
- Push the updated script to the Gist and prewarm a new instance

### Cloudflare URL changes

- Quick Tunnel URLs are ephemeral; they change when the tunnel or instance restarts
- Get the new URL from the provision log or `.comfyui_tunnel_url` after restart

### Plugin log

- In Krita: AI Image Generation docker → Configure → "View Log files"
- Use this to diagnose connection and model issues

## References

- [Krita AI Handbook](https://docs.interstice.cloud)
- [KRITA_PROVISIONING_PLAN.md](KRITA_PROVISIONING_PLAN.md) – Provision script changes
- [tools/krita/README.md](../tools/krita/README.md) – Portable install in project
