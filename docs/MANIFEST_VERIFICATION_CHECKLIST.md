# 📋 MANIFEST VERIFICATION CHECKLIST

**Date:** 2026-02-04  
**Purpose:** Checklist to verify and update the Complete Software Manifest

---

## ✅ COMPLETED

1. ✅ **Created Complete Software Manifest**
   - Location: `docs/COMPLETE_SOFTWARE_MANIFEST.md`
   - Includes: All software, models, dependencies, links
   - Sources: `installed_assets.md`, `provision-reliable.sh`, provision docs

2. ✅ **Documented All Components**
   - System packages (APT)
   - Python packages
   - ComfyUI extensions (16 total)
   - AI models (100+ items)
   - Download sources
   - Environment variables

---

## 🔄 PENDING VERIFICATION

### 1. Dropbox Links Cross-Verification

**Status:** ⚠️ Links in `data/dropbox_links.txt` are from an old file (per user request)

**Action Required:**
1. Access your Dropbox account
2. Verify all model files are still present
3. Regenerate direct download links if needed
4. Update `data/dropbox_links.txt` with current links

**Current Links to Verify:**
```
dreamshaper_8.safetensors
Rajii-Artist-Style-V2-Illustrious.safetensors
DR34MJOB_I2V_14b_LowNoise.safetensors
pony_realism_v2.2.safetensors
pmXL_v1.safetensors
wai_illustrious_sdxl.safetensors
fondled.safetensors
wan_dr34ml4y_all_in_one.safetensors
wan_dr34mjob.safetensors
twerk.safetensors
pornmasterPro_noobV6.safetensors
expressiveh_hentai.safetensors
sdxl_vae.safetensors
ponyDiffusionV6XL.safetensors
```

**How to Regenerate Links:**

Option A - Using the Script:
```bash
# Set your Dropbox token
export DROPBOX_TOKEN="sl.your_token_here"

# List folders to find correct path
node scripts/dropbox_create_links.js --list /

# Generate links for your models folder
node scripts/dropbox_create_links.js /YourModelsFolder

# Output will be in data/dropbox_links.txt
```

Option B - Manual (Dropbox Web UI):
1. Go to https://www.dropbox.com
2. Navigate to each model file
3. Click "Share" → "Create link"
4. Copy link and change `?dl=0` to `?dl=1`
5. Update `data/dropbox_links.txt`

### 2. Civitai Token Validation

**Action Required:**
1. Verify your Civitai token is still valid
2. Test token with a download
3. Update `.env` if token expired

**Test Command:**
```bash
curl -I "https://civitai.com/api/download/models/152309?token=$CIVITAI_TOKEN"
# Should return HTTP 200 or start download
```

**Get New Token:** https://civitai.com/user/account

### 3. HuggingFace Token (Optional)

**Action Required:**
1. Check if you need private model access
2. Generate token if needed: https://huggingface.co/settings/tokens
3. Add to `.env` as `HUGGINGFACE_HUB_TOKEN`

### 4. Model Availability Check

**Action Required:**
Verify these models are still accessible:

**HuggingFace Models:**
- [ ] `Lykon/dreamshaper-8`
- [ ] `stabilityai/sdxl-vae`
- [ ] `Comfy-Org/Wan_2.1_ComfyUI_repackaged`
- [ ] `Comfy-Org/Wan_2.2_ComfyUI_Repackaged`
- [ ] `Lightricks/LTX-2`
- [ ] `BlackHat404/scatmodels`
- [ ] `JollyIm/Defecation`

**Catbox.moe Links:**
- [ ] Test each link in `LORA_MODELS` section
- [ ] Remove dead links
- [ ] Find alternative sources if needed

**GitHub Releases:**
- [ ] `rife426.pth` (currently 404 - marked optional)
- [ ] `RealESRGAN_x4plus.pth`
- [ ] `4x-UltraSharp.pth`

---

## 🔧 RECOMMENDED UPDATES

### 1. Update Provision Scripts

After verifying Dropbox links, update these files:
- `scripts/provision-reliable.sh` (lines 316-368 for checkpoints)
- `scripts/provision-reliable.sh` (lines 373-415 for LoRAs)

### 2. Update Manifest

After verification, update:
- `docs/COMPLETE_SOFTWARE_MANIFEST.md`
- Change "Cross-verify with Dropbox" note to "Verified on [DATE]"
- Update any changed links

### 3. Create Backup

**Action Required:**
```bash
# Backup current links
cp data/dropbox_links.txt data/dropbox_links.backup.txt

# After verification, commit new links
git add data/dropbox_links.txt
git commit -m "Update verified Dropbox links - 2026-02-04"
```

---

## 📊 VERIFICATION MATRIX

| Component | Status | Last Verified | Action |
|-----------|--------|---------------|--------|
| System Packages | ✅ Complete | 2026-02-04 | None |
| Python Packages | ✅ Complete | 2026-02-04 | None |
| ComfyUI Extensions | ✅ Complete | 2026-02-04 | None |
| HuggingFace Models | ⚠️ Needs Check | - | Test downloads |
| Dropbox Links | ❌ Old File | - | **REGENERATE** |
| Civitai Token | ⚠️ Unknown | - | **VALIDATE** |
| Catbox Links | ⚠️ Some Dead | - | Test & remove |
| GitHub Releases | ⚠️ Some 404 | - | Mark optional |

---

## 🎯 NEXT STEPS (Priority Order)

### HIGH PRIORITY
1. **Validate Civitai Token**
   - Required for provisioning
   - Blocks downloads if invalid
   - Quick to test

2. **Regenerate Dropbox Links**
   - Critical for model downloads
   - Old links may be expired
   - Use script or manual method

### MEDIUM PRIORITY
3. **Test HuggingFace Downloads**
   - Verify public models accessible
   - Check for moved/deleted repos
   - Update manifest if needed

4. **Update Provision Scripts**
   - Replace old Dropbox links
   - Remove dead Catbox links
   - Mark optional models

### LOW PRIORITY
5. **Test Catbox Links**
   - Many may be dead
   - Find alternatives if needed
   - Consider moving to Dropbox

6. **Document Changes**
   - Update manifest with verified links
   - Add verification date
   - Commit to version control

---

## 🔐 SECURITY REMINDERS

- ✅ Never commit `.env` with tokens
- ✅ Use short-lived tokens when possible
- ✅ Rotate Dropbox tokens regularly
- ✅ Keep Civitai token private
- ✅ Test tokens before provisioning

---

## 📝 NOTES

### Dropbox Link Format
```
https://www.dropbox.com/scl/fi/[FILE_ID]/[FILENAME]?rlkey=[KEY]&dl=1
```
- Must end with `&dl=1` for direct download
- `rlkey` is required for shared links
- Links can expire if sharing settings change

### Civitai API Format
```
https://civitai.com/api/download/models/[MODEL_ID]?token=$CIVITAI_TOKEN
```
- Token required for all downloads
- Rate limited (use sequential downloads)
- Some models require specific parameters

### HuggingFace Format
```
https://huggingface.co/[USER]/[REPO]/resolve/main/[FILE]
```
- Public models don't need token
- Private models need `HUGGINGFACE_HUB_TOKEN`
- Use `git-lfs` for large files

---

## ✅ COMPLETION CHECKLIST

When all verification is complete:

- [ ] All Dropbox links tested and working
- [ ] Civitai token validated
- [ ] HuggingFace models accessible
- [ ] Dead links removed or replaced
- [ ] Provision scripts updated
- [ ] Manifest updated with verification date
- [ ] Changes committed to git
- [ ] Test provision on fresh instance
- [ ] Update this checklist status

---

**Last Updated:** 2026-02-04  
**Next Review:** After Dropbox verification  
**Maintained By:** AI Kings Team
