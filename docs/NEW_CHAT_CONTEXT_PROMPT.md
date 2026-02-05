# Prompt for New Chat – Current Status (copy below)

Use this in a new chat to bring the AI up to speed.

---

**Project: AI Kings – ComfyUI on Vast.ai**

This is a Node.js + PowerShell project that runs a local proxy server (`vastai-proxy`), manages a Vast.ai warm pool (GPU instances), and provisions remote instances with ComfyUI and 77+ AI models via a bash script. We use Dropbox for backup/verification and a public Gist for the provision script.

**Current status (as of 2026-02-04):**

- **Goal:** Provision a **fresh 600GB** Vast.ai instance, run the provision script from the Gist, ensure SSH access, and have all models available (aligned with Dropbox manifest).
- **Done:**  
  - `.env` has all tokens (VASTAI_API_KEY, ADMIN_API_KEY, HUGGINGFACE_HUB_TOKEN, CIVITAI_TOKEN, DROPBOX_TOKEN, NEED_KEY).  
  - `WARM_POOL_DISK_GB=600`, `DROPBOX_FOLDER=/workspace/pornmaster100`.  
  - Provision script `scripts/provision-reliable.sh` (v3.0) has 77+ model URLs (HuggingFace primary, Dropbox/Civitai fallback). RIFE and AnimateDiff links were fixed; ponyRealism VAE and UMT5 scaled added.  
  - Manifest `docs/COMPLETE_SOFTWARE_MANIFEST.md` updated.  
  - Dropbox folder `/workspace/pornmaster100` verified (7,374 files).  
  - All 73 provision script download URLs were verified by an external agent; failures (400 Dropbox, 404 HF, 503 Catbox, etc.) are documented in `docs/LINK_VERIFICATION_WITH_TOKENS.md` – with our tokens, 12 Dropbox + 1 HF gated would work; Catbox/Meta have no token.
- **Provision script is served from a Gist;** `COMFYUI_PROVISION_SCRIPT` and `PROVISION_ALLOWED_SCRIPTS` in `.env` point to that Gist. Pushing changes to the script means updating the Gist and optionally the hash in the URL.
- **Key paths:**  
  - Server: `server/vastai-proxy.js`, warm pool: `server/warm-pool.js`.  
  - Provision script: `scripts/provision-reliable.sh`.  
  - Config: `.env`, `config/ecosystem.config.js` (PM2).  
  - Docs: `docs/PROVISION_READY_VERIFICATION.md`, `docs/FRESH_600GB_INSTANCE_GUIDE.md`, `docs/LINK_VERIFICATION_WITH_TOKENS.md`, `docs/AGENT_PROMPT_VERIFY_ALL_LINKS.md`.

**What I might ask next:** Start/prewarm a 600GB instance, push provision script to Gist, debug provisioning or SSH, update manifest or links, or change env/config. Use the repo structure and docs above; do not assume tokens are missing unless I say so.

---

End of context prompt.
