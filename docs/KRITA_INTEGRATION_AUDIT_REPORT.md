# 🕵️ Krita AI Diffusion + ComfyUI Integration Audit Report
**Date:** February 8, 2026
**Version:** 1.0 (Final Diagnostic)

## 1. Executive Summary
After a deep-tissue diagnostic of the Vast.ai environment and Krita workflows, we identified a "Triple Failure" chain that was preventing image generation. We have implemented a "Gold Standard" fix that secures the Python environment, the Real-time Node communication, and the Model integrity.

---

## 2. Key Findings & Root Causes

### **A. The SQLAlchemy Crash (Fixed)**
*   **Symptom:** ComfyUI failing to start; `ImportError: cannot import name 'mapped_column'`.
*   **Cause:** Base Vast.ai images use SQLAlchemy 1.x. Latest ComfyUI requires 2.0. Custom nodes were also "downgrading" the version back to 1.x during installation.
*   **Fix:** Implemented **Triple-Layer Protection** in `provision-image-only.sh`. It forces 2.0 at (1) install, (2) after nodes are added, and (3) right before execution.

### **B. The "16-Channel" Architecture Mismatch (Fixed)**
*   **Symptom:** `expected input[1, 16, 64, 32] to have 4 channels, but got 16`.
*   **Cause:** Mixing FLUX (16 channels) and SDXL (4 channels). The Krita plugin was often defaulting to Flux while the server was running SDXL, or the workflow was missing an explicit VAE lock.
*   **Fix:** Created "Locked" Gold Standard workflows (`krita_gold_standard_sdxl.json` and `krita_gold_standard_flux.json`) that force the correct VAE and latent space.

### **C. The "Unfunctional" Krita Nodes (Fixed)**
*   **Symptom:** Krita showing "Server Unfunctional" or failing to sync canvas.
*   **Cause:** The workflows were using standard `LoadImage` nodes or generic `KritaInput` IDs.
*   **Discovery:** The production server registers nodes with a specific prefix: **`ETN_KritaCanvas`** and **`ETN_KritaOutput`**.
*   **Fix:** Updated all Krita workflows to use the verified `ETN_` class IDs found in the server's registry.

### **D. The Model Corruption Ghost (Critical)**
*   **Symptom:** Infinite "VAE Decode" time or sudden process crashes.
*   **Discovery:** On the live instance, `Juggernaut-XL-v9.safetensors` was only **710 KB** (a stub) instead of **6.6 GB**.
*   **Reason:** Provisioning script was not verifying the integrity/size of downloads after they finished.

---

## 3. The "Bulletproof" Solution (v6.1+)

We have updated the **Master Provisioning Script** to prevent these issues from ever returning:

1.  **Model Integrity Checks:** Added logic to check if a model is < 1MB and re-download it.
2.  **Krita Node Injection:** Automates the presence of `comfyui-tooling-nodes`.
3.  **Gold Standard Auto-Load:** The script now automatically injects the verified JSON workflows into the `/workspace/ComfyUI/workflows` folder.
4.  **VAE Name Sync:** Standardized on `sdxl_vae_fp16.safetensors` to match the most reliable high-speed download mirrors.

---

## 4. How to Ensure a "Clean" Instance Every Time

1.  **Use v6.1+:** Always ensure `.env` points to the latest `provision-image-only.sh` on the GitHub `main` branch.
2.  **Krita Setup:** 
    *   Connect to the URL.
    *   Go to the **Graph** tab in Krita.
    *   Load **`krita_gold_standard_sdxl.json`**.
    *   Ensure the Krita Sidebar "Architecture" matches the workflow (SDXL for SDXL, Flux for Flux).

---

## 5. Next Steps for Automation
*   [x] Push v6.1 with Model Size Verification.
*   [x] Push Verified ETN_ Workflows to Repo.
*   [ ] (Optional) Add a "Self-Heal" button to the Admin UI to trigger v6.1 repatching on an existing instance.
