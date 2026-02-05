# Which Is More Complete? + Action Plan to Fill Dropbox in One Provision

## Which is more complete?

| | **Provision script** | **Dropbox** |
|---|----------------------|-------------|
| **Role** | Catalogue of what we *want* (77+ models, one-shot install) | Backup of what we *have* (previous instance snapshot) |
| **Completeness** | **More complete as a target** – single source of truth for every model and where to get it (HF, Civitai, Dropbox, Catbox) | **Strong but not full** – has 58+ manifest items and 7,374 files (ComfyUI + workflows + duplicates), but missing several items the provision would download |
| **Verdict** | **Provision = more complete** for “what a full instance should have.” Dropbox is a backup that is missing some provision-only and Catbox-sourced files. |

So: **the provision script is the more complete catalogue.** Dropbox should be made to match it (and then exceed it as the canonical backup after every successful provision).

---

## Gaps: what provision has that Dropbox doesn’t (or might not)

1. **Definitely missing in Dropbox (provision would download these)**  
   - `ponyRealism_v21MainVAE.safetensors` (VAE, Civitai)  
   - `rife426.zip` / RIFE 4.26 (provision uses HF zip; Dropbox had `rife426.pth` in manifest)  
   - `mm_sdxl_v10_beta.ckpt` (AnimateDiff SDXL)  
   - `wan2.2_remix_fp8.safetensors` (Civitai)  
   - `umt5_xxl_fp8_e4m3fn.safetensors` (Wan text encoder; Dropbox has *scaled* version only)

2. **Naming / format differences (Dropbox has equivalent)**  
   - `wan2.1_vae.safetensors` vs Dropbox `wan_2.1_vae.safetensors`  
   - RIFE: provision uses `.zip` from HF; manifest listed `.pth`

3. **Catbox LoRAs (7 files)**  
   - Provision downloads from Catbox: cunnilingus_gesture, archive_lora.rar, empty_eyes_drooling, glowing_eyes, quadruple_amputee, ugly_bastard, sex_machine.  
   - When Catbox returns 503/errors, we have no backup unless these are already in Dropbox. If they’re not in `/workspace/pornmaster100`, **Dropbox is incomplete** for these.

4. **In Dropbox but not in provision (already documented)**  
   - Extras like ae.safetensors, gemma duplicates, sd_xl_base_1.0.1, wan_2.1_vae, resizers, etc. – good to keep; add to manifest so “complete catalogue” = provision list + these known extras.

---

## Goal

- **One provision** that gets the full catalogue with no (or minimal) issues.  
- **Then** make Dropbox the full backup: everything that was installed on the instance is also in Dropbox, so future provisions can use “Dropbox fallback” for any source that fails.

---

## Action plan: full catalogue in one provision + complete Dropbox

### Phase 1 – Maximize one-shot provision success

1. **Use all tokens on the instance**  
   - Ensure provision script receives and uses: `HUGGINGFACE_HUB_TOKEN`, `CIVITAI_TOKEN`, `DROPBOX_TOKEN` (for any Dropbox fallback URLs).  
   - So: 12 Dropbox links work, 1 gated HF (e.g. LTX-2 LoRA) works, Civitai works.

2. **Fix known broken/unreliable links (optional but recommended)**  
   - HF 404s (e.g. dreamshaper primary, umt5/wan2.1 paths): fix or add working fallbacks (Civitai/Dropbox) in the script.  
   - Ensure RIFE entry matches what we use (e.g. `rife426.zip` from HF); document expected filename in manifest (e.g. `rife426.zip` or extracted `.pth`).

3. **Catbox**  
   - No token we have fixes Catbox. Options:  
     - **A)** Run provision when Catbox is up; if it succeeds, upload those 7 files to Dropbox in Phase 2 and add Dropbox fallbacks for them in the script.  
     - **B)** Find alternate URLs (e.g. Civitai/HF) for the same LoRAs and add them as primary or fallback so provision doesn’t depend on Catbox.

4. **Single run**  
   - Start one 600GB instance, run provision with all env/tokens set.  
   - Log which files failed (if any). Resolve failures in script (or add Dropbox fallback after Phase 2).

---

### Phase 2 – Make Dropbox fully complete (instance → Dropbox)

5. **Sync instance models to Dropbox after successful provision**  
   - From the provisioned instance, upload to Dropbox everything under the model dirs that we care about, e.g.:  
     - `ComfyUI/models/checkpoints`  
     - `ComfyUI/models/loras`  
     - `ComfyUI/models/vae`  
     - `ComfyUI/models/diffusion_models`  
     - `ComfyUI/models/clip` (text encoders)  
     - `ComfyUI/models/animatediff_models`  
     - `ComfyUI/models/upscale_models`  
     - `ComfyUI/models/controlnet`  
     - `ComfyUI/models/ultralytics`, `sams`, etc.  
     - RIFE: wherever the script puts it (e.g. custom_nodes/ComfyUI-Frame-Interpolation or similar).  
   - Options:  
     - **A)** Dropbox API: script (local or on instance) that lists instance paths, lists Dropbox `DROPBOX_FOLDER` (e.g. `/workspace/pornmaster100`), and uploads any file that’s missing or newer.  
     - **B)** rclone with Dropbox remote: one-way sync instance → Dropbox.  
     - **C)** Manual: download from instance (e.g. scp/rsync to local) then upload to Dropbox (folder or shared structure).  
   - Keep the same folder structure under Dropbox as in the manifest (e.g. `.../ComfyUI/models/loras/...`) so future audits and fallback URLs match.

6. **Add Dropbox fallbacks for newly backed-up files**  
   - For every model that (i) provision downloads from HF/Civitai/Catbox and (ii) is now in Dropbox, create shared links and add them to the provision script as fallback (e.g. `PRIMARY|DROPBOX_FALLBACK|filename`).  
   - Prioritize: Catbox LoRAs, then any other link that has historically failed (404/503).

7. **Update manifest from Dropbox**  
   - Run your Dropbox manifest audit again after sync.  
   - Add any “extra” files that are now in Dropbox to `COMPLETE_SOFTWARE_MANIFEST.md` so the “full catalogue” = provision list + known Dropbox-only extras.  
   - Optionally: add a short “Dropbox-only” section for files we don’t download in provision but keep in backup (e.g. older SDXL 1.0.1, duplicate VAEs).

---

### Phase 3 – Keep Dropbox complete going forward

8. **Repeat sync after every successful provision**  
   - Same process as Phase 2: instance model dirs → Dropbox.  
   - Either: same script/commands, or a small “post-provision sync” step (e.g. run a script on the instance that uploads to Dropbox via API, or run rclone from a machine that can see both instance and Dropbox).

9. **Treat Dropbox as canonical backup**  
   - Once all provision targets are in Dropbox and fallbacks are in the script, “full catalogue” = what’s in the provision script, and “full backup” = what’s in Dropbox.  
   - Any new model added to provision should be uploaded to Dropbox after the first successful install, and a Dropbox fallback URL added to the script.

---

## Summary checklist

- [ ] **Phase 1:** Provision script uses HF + Civitai + Dropbox tokens on instance; fix known 404/403 links or add fallbacks.  
- [ ] **Phase 1:** Run one full 600GB provision; note any failures (especially Catbox).  
- [ ] **Phase 2:** Sync provisioned instance model dirs → Dropbox (API, rclone, or manual).  
- [ ] **Phase 2:** Create Dropbox shared links for newly backed-up files; add fallback URLs to provision script (Catbox LoRAs first).  
- [ ] **Phase 2:** Re-run manifest audit; update `COMPLETE_SOFTWARE_MANIFEST.md` with any new/extra files.  
- [ ] **Phase 3:** After every future successful provision, run the same instance → Dropbox sync so the catalogue stays fully backed up.

Result: **one provision** gets the full catalogue (or as full as external links allow), and **Dropbox becomes the full backup** so we can always restore or use it as fallback and avoid single-source failures.
