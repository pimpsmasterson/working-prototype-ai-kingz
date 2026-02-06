# Krita Portable (AI Diffusion)

Krita runs **locally on your PC**. This folder holds the Krita portable installation for use with the AI Kings ComfyUI setup on rented Vast.ai instances.

## Installation

### 1. Download Krita Portable

1. Go to [krita.org/en/download](https://krita.org/en/download)
2. Download the **Windows (64-bit)** ZIP (portable)
3. Extract the ZIP contents into this folder (`tools/krita/`)
4. You should have `krita.exe` and other files in this directory

### 2. Install Krita AI Diffusion Plugin

1. Download the plugin from [GitHub releases](https://github.com/Acly/krita-ai-diffusion/releases/latest) (get the `.zip` file)
2. Launch Krita: run `krita.exe` in this folder
3. In Krita: **Tools** → **Scripts** → **Import Python Plugin from File...**
4. Select the plugin ZIP and confirm
5. Restart Krita
6. Enable the docker: **Settings** → **Dockers** → **AI Image Generation** (check the box)

### 3. Connect to ComfyUI (Remote Instance)

Your ComfyUI runs on a rented Vast.ai instance. Get the connection URL from one of:

**Option A – Cloudflare (recommended)**  
After provisioning, the Cloudflare tunnel URL appears in the provision log:
- SSH to instance and run: `grep trycloudflare /workspace/provision_v3.log`
- Or: `cat /workspace/.comfyui_tunnel_url`
- Copy the full URL (e.g. `https://abc123-xyz.trycloudflare.com`)

**Option B – SSH tunnel**  
Run from project root:
```powershell
.\scripts\open-comfy-vastai.ps1 -InstanceId <YOUR_INSTANCE_ID>
```
Then use `http://localhost:8080` in Krita.

**In Krita:**
1. Open the AI Image Generation docker
2. Click **Configure**
3. Select **Custom Server**
4. Paste the URL (no spaces)
5. Click **Connect**

## Quick Reference

| Item | Location |
|------|----------|
| Krita exe | `tools/krita/krita.exe` |
| Plugin docs | [docs.interstice.cloud](https://docs.interstice.cloud) |
| Full setup guide | [../docs/KRITA_SETUP.md](../docs/KRITA_SETUP.md) |
