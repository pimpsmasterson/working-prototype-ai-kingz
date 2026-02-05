# Provision: Dropbox-only workspace transfer (minimal)

This document explains how to use `scripts/provision-dropbox-only.sh` to provision a GPU instance by transferring a complete workspace from Dropbox (no model downloads).

## Prerequisites
- A Dropbox token (with at least `files.content.read`) available as `DROPBOX_TOKEN`.
- The Dropbox folder path to the pre-built workspace (e.g. `/workspace/pornmaster100`) set as `DROPBOX_PATH`.
- Sufficient disk on the instance (recommend 600GB+ for large workspaces).

## Usage

From the instance (or as part of Vast.ai onstart):

```bash
DROPBOX_TOKEN="sl.xxx" DROPBOX_PATH="/workspace/pornmaster100" bash scripts/provision-dropbox-only.sh
```

Optional environment variables:
- `WORKSPACE` (default `/workspace`)
- `COMFYUI_DIR` (default `$WORKSPACE/ComfyUI`)
- `PORT` (default `8188`)
- `SKIP_TORCH=1` to skip installing PyTorch if it's already included in the workspace
- `RETRIES` (default `3`) - number of download retry attempts
- `MIN_ZIP_BYTES` (default `500000`) - minimum expected ZIP size in bytes

## Vast.ai Integration

To use this script with Vast.ai instances, set it as the provisioning script in your template:

1. In Vast.ai console, create or edit a template
2. Add environment variables:
   - `DROPBOX_TOKEN`: Your Dropbox access token
   - `DROPBOX_PATH`: Path to your workspace folder
3. Set the onstart command to run the script:
   ```
   bash -c 'curl -fsSL https://raw.githubusercontent.com/your-repo/scripts/provision-dropbox-only.sh -o /tmp/provision.sh && chmod +x /tmp/provision.sh && /tmp/provision.sh'
   ```

## Dropbox API Usage

The script uses Dropbox API v2 endpoints correctly:
- `POST https://content.dropboxapi.com/2/files/download_zip` for downloading folders as ZIP
- `POST https://api.dropboxapi.com/2/files/list_folder` for token validation
- Proper headers: `Authorization: Bearer <token>` and `Dropbox-API-Arg: {"path": "/folder"}`

## Best Practices
- Token should have `files.content.read` scope minimum
- Use long-lived tokens for production (not short-lived)
- Test with small folders first
- Monitor `/tmp/provision-dropbox-only.log` for debugging
- The script includes retries and proper error handling per Dropbox API guidelines

## Notes
- Script uses Dropbox `download_zip` for a single-archive transfer; this is faster and more reliable than many individual downloads.
- Log file: `/tmp/provision-dropbox-only.log` and ComfyUI logs at `$COMFYUI_DIR/comfyui.log`.
- The script is intentionally minimal and idempotent; you can re-run it safely.
