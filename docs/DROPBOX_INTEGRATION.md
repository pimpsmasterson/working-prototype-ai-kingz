# Dropbox Integration (Automatic links for provisioning)

This document describes how to automate creation of direct-download Dropbox links and pass them to instance provisioning.

Quick steps

1. Add your Dropbox token to your `.env` (do NOT commit `.env`):

   DROPBOX_TOKEN=sl.your_token_here
   DROPBOX_FOLDER=/MyModels

2. Inspect and generate links using the helper script:

   - List immediate children of a path (help find the exact folder path):
     ```bash
     DROPBOX_TOKEN=sl.TOKEN node scripts/dropbox_create_links.js --list /
     ```

   - Find model-like files recursively (useful for nested folders):
     ```bash
     DROPBOX_TOKEN=sl.TOKEN node scripts/dropbox_create_links.js --find /MySharedFolder
     ```

   - Create direct-download links for immediate files in a folder:
     ```bash
     DROPBOX_TOKEN=sl.TOKEN node scripts/dropbox_create_links.js /MySharedFolder
     # or using npm helper
     npm run create-dropbox-links -- /MySharedFolder
     ```

   The script writes `data/dropbox_links.txt` with lines in the format expected by the provisioner:

   https://www.dropbox.com/s/abcd1234/filename.safetensors?dl=1|filename.safetensors

3. Prewarm an instance (the file will be read automatically if present):

   - If `data/dropbox_links.txt` exists it will be packaged into the instance env as `PROVISION_DROPBOX_LINKS_B64` and decoded by the provision script.

Troubleshooting & token scopes

- If the script fails with `missing_scope` or prints "Dropbox token missing required scope", the token needs the following scopes:
  - `files.metadata.read`
  - `files.content.read`
  - `sharing.write`

- If you see `No files found in /YourPath`:
  - Run `--list /YourPath` to verify the exact folder path (Dropbox paths are case-sensitive and often start with `/`).
  - Use `--find` to locate model files if they're nested deeper.

- If your folder path is not under your account or you don't see expected files, check the Dropbox Web UI for the correct path or ensure you're using the account that owns the files.

Implementation notes

- The server will attempt to auto-generate `data/dropbox_links.txt` when `DROPBOX_TOKEN` is present and links file is missing. The default `DROPBOX_FOLDER` is `/` unless overridden in `.env`.
- Prefer to run the script locally once to confirm output and correct folder selection; `data/dropbox_links.txt` is ignored by git and safe to keep locally for repeatable provisioning.

Next steps you can ask for

- I can add an admin endpoint to trigger generation on demand (protected by `ADMIN_API_KEY`).
- I can add an interactive `--choose` mode that lists top-level folders and prompts you to pick one when running the script from a TTY.

Security

- DO NOT commit `.env` with secrets to version control.
- Use short-lived tokens where possible and rotate regularly.

---

## Embedded links & status (2026-01-31) ✅

- Status: The Dropbox links for the known model files were embedded directly into the provisioning scripts on **2026-01-31** to make provisioning deterministic and reduce provisioning failures caused by missing per-file links.

- Files added to `CHECKPOINT_MODELS` (in `scripts/provision-core.sh` and `scripts/provision.sh`):
  - `dreamshaper_8.safetensors`
  - `Rajii-Artist-Style-V2-Illustrious.safetensors`
  - `DR34MJOB_I2V_14b_LowNoise.safetensors`
  - `pony_realism_v2.2.safetensors`
  - `pmXL_v1.safetensors`
  - `wai_illustrious_sdxl.safetensors`
  - `ponyDiffusionV6XL.safetensors`
  - `pornmasterPro_noobV6.safetensors`
  - `expressiveh_hentai.safetensors`
  - `fondled.safetensors`
  - `wan_dr34ml4y_all_in_one.safetensors`
  - `wan_dr34mjob.safetensors`
  - `twerk.safetensors`
  - `sdxl_vae.safetensors` (also added to VAEs)

- Local file: `data/dropbox_links.txt` was generated and contains the corresponding direct-download URLs (ignored by git).

- Notes:
  - The provisioner still supports runtime overrides via `PROVISION_DROPBOX_LINKS_B64` or `PROVISION_DROPBOX_LINKS` if you need to change links without editing the scripts.
  - Recommendation: If you frequently change models, use the generator script + `data/dropbox_links.txt` and consider adding an admin endpoint to regenerate links on demand.


