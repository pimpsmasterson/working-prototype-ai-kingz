# Link Verification: Which Failures Would Work With Our API Tokens?

Based on the agent’s verification (no tokens), here’s which **failed/error** links would likely **succeed** if the downloader had our **API keys/tokens**, and which would not.

---

## Would download with our tokens

### DROPBOX_TOKEN (12 links)

Dropbox shared links often return **400** when hit with a plain HEAD/GET (no cookie, wrong UA, or link format).  
**With our DROPBOX_TOKEN**, the provision script or a helper can use the Dropbox API (e.g. `/files/download` or shared-link metadata) to get a valid download URL or stream. So these would be expected to work in real provisioning:

| # | Status | File / purpose |
|---|--------|-----------------|
| 1  | 400 | pmXL_v1.safetensors (checkpoint) |
| 7  | 400 | pony_realism_v2.2.safetensors |
| 9  | 400 | wai_illustrious_sdxl.safetensors |
| 10 | 400 | Rajii-Artist-Style-V2-Illustrious.safetensors |
| 11 | 400 | DR34MJOB_I2V_14b_LowNoise.safetensors |
| 12 | 400 | pornmasterPro_noobV6.safetensors |
| 13 | 400 | expressiveh_hentai.safetensors |
| 14 | 400 | fondled.safetensors |
| 15 | 400 | wan_dr34ml4y_all_in_one.safetensors |
| 16 | 400 | wan_dr34mjob.safetensors |
| 17 | 400 | twerk.safetensors |
| 19 | 400 | sdxl_vae.safetensors (fallback) |

**Conclusion:** All 12 Dropbox 400s would be expected to download when using **DROPBOX_TOKEN** (e.g. via Dropbox API or token-authenticated shared links).

---

### HUGGINGFACE_HUB_TOKEN (1 definite + 3 possible)

| # | Status | File / purpose | With HF token? |
|---|--------|-----------------|----------------|
| 25 | Requires sign-in | LTX-2-19b-LoRA-Camera-Control-Dolly-Left | **Yes** – gated repo; token fixes it. |
| 2  | 404 | dreamshaper_8.safetensors (stablediffusionapi) | Unlikely – 404 usually means repo/path gone or wrong; token doesn’t fix that. |
| 47 | 404 | umt5_xxl_fp8_e4m3fn.safetensors (Wan_2.1 text encoder) | **Maybe** – if 404 is due to gated or wrong path/casing (e.g. Comfy-Org vs Wan_2.1), token + correct path could work. |
| 48 | 404 | umt5_xxl_fp8_e4m3fn_scaled.safetensors (LTX-2) | **Maybe** – same as 47. |
| 54 | 404 | wan2.1_vae.safetensors | **Maybe** – same idea (path/repo structure or gated). |

**Conclusion:** **#25** would download with **HUGGINGFACE_HUB_TOKEN**. **#47, 48, 54** might work with HF token + correct repo/path; worth verifying paths (e.g. Comfy-Org vs ltx-2, and exact file paths).

---

### CIVITAI_TOKEN (2 possible)

| # | Status | File / purpose | With Civitai token? |
|---|--------|-----------------|----------------------|
| 3  | 404 | civitai.com/api/download/models/128641 (dreamshaper fallback) | **Maybe** – 404 can be wrong version ID or deprecated; **CIVITAI_TOKEN** in header is required for API downloads; with correct model/version ID it could work. |
| 2  | 404 | HuggingFace dreamshaper (primary) | Not Civitai; HF 404. |

**Conclusion:** **#3** might download with **CIVITAI_TOKEN** if the model/version is still available under a valid ID. Our script already uses Civitai token for other Civitai URLs.

---

## Would not be fixed by our tokens

### Catbox.moe (7 links) – no token we have

| # | Status | File |
|---|--------|------|
| 27 | 503 | cunnilingus_gesture.safetensors |
| 28 | 503 | archive_lora.rar |
| 29 | Error | empty_eyes_drooling.safetensors |
| 30 | 503 | glowing_eyes.safetensors |
| 31 | 503 | quadruple_amputee.safetensors |
| 32 | Error | ugly_bastard.safetensors |
| 33 | 503 | sex_machine.safetensors |

We do **not** have a Catbox API key or token. **503** = server overload/maintenance; **Error** = timeouts or connection issues. So **none of these would be “fixed” by our tokens** – they depend on Catbox being up and reachable (retries later may work).

---

### Meta CDN (1 link)

| # | Status | File |
|---|--------|------|
| 65 | Error | sam_vit_b_01ec64.pth (dl.fbaipublicfiles.com) |

Public CDN; we have no Meta token. Error is likely network/timeout. **No token** would help; **retry** or different network might.

---

## Summary table (with our APIs/tokens)

| Token / source | Would download with our token? | Count (definite) | Count (maybe) |
|----------------|--------------------------------|------------------|----------------|
| **DROPBOX_TOKEN** | Yes (use API or authenticated link) | 12 | 0 |
| **HUGGINGFACE_HUB_TOKEN** | Yes for gated; maybe for 404 if path wrong | 1 (#25) | 3 (#47, 48, 54) |
| **CIVITAI_TOKEN** | Maybe (wrong/deprecated model ID can still 404) | 0 | 1 (#3) |
| **Catbox** | No token | 0 | 0 |
| **Meta CDN** | No token | 0 | 0 |

---

## Bottom line

- **With our APIs and tokens** (Dropbox, HuggingFace, Civitai) used correctly on the provisioning instance:
  - **12 links** (all Dropbox 400s) would be expected to download.
  - **1 link** (#25, LTX-2 LoRA) would be expected to download with HF token.
  - **Up to 4 more** (#3 Civitai, #47/#48/#54 HuggingFace) might work with correct IDs/paths and the same tokens.
- **7 Catbox + 1 Meta** links would not be fixed by our tokens; they depend on Catbox availability and network to Meta’s CDN (retries can help).

So in practice, **with our tokens**, almost all “not downloadable” results that are due to **auth or Dropbox link handling** would be expected to download; only Catbox and the Meta SAM CDN are outside our token scope.
