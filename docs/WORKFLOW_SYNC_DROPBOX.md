# Workflow Sync from Dropbox - Quick Setup Guide

**Status:** ✅ IMPLEMENTED - Ready to use immediately!

This guide shows you the **easiest way** to keep your ComfyUI workflows updated on Vast.ai instances using Dropbox.

---

## 🚀 Quick Start (5 Minutes)

### Method 1: Sync Entire Workflows Folder (Recommended)

**Step 1:** Share your workflows folder on Dropbox

1. Open Dropbox
2. Right-click on `scripts/workflows` folder (or wherever your workflows are)
3. Click "Share" → "Create link"
4. **Copy the link** (it will look like: `https://www.dropbox.com/sh/abc123xyz/AABBCCDDee?dl=0`)

**Step 2:** Add the link to your `.env` file

Edit `C:\Users\samsc\OneDrive\Desktop\working protoype\.env` and add:

```bash
# Dropbox Workflows Sync (Optional)
DROPBOX_WORKFLOWS_URL=https://www.dropbox.com/sh/YOUR_FOLDER_ID_HERE/AABBCCDDee?dl=0
```

**Step 3:** Done! Next provision will auto-sync

When you run `one-click-start-fixed.ps1`, the provision script will:
1. Download your entire workflows folder from Dropbox
2. Extract all JSON files
3. Place them in `/workspace/ComfyUI/user/default/workflows/`

**That's it!** Update workflows in Dropbox anytime, next provision gets latest versions.

---

### Method 2: Sync Individual Workflow Files

If you prefer to sync specific workflows only:

**Step 1:** Get direct download links for each workflow

For each workflow JSON in Dropbox:
1. Right-click file → "Share" → "Create link"
2. Copy the link (example: `https://www.dropbox.com/scl/fi/abc123/workflow.json?rlkey=xyz&dl=0`)
3. **Change `dl=0` to `dl=1`** at the end
   - Before: `?dl=0`
   - After: `?dl=1`

**Step 2:** Edit `scripts/provision-reliable.sh`

Find the `sync_workflows_from_links()` function (around line 1520) and add your links:

```bash
local workflow_links=(
    # Your actual Dropbox links (change dl=0 to dl=1):
    "https://www.dropbox.com/scl/fi/abc123/nsfw_pony.json?rlkey=xyz&dl=1|nsfw_pony_multiple_fetish_stacked_master_workflow.json"
    "https://www.dropbox.com/scl/fi/def456/nsfw_ltx.json?rlkey=uvw&dl=1|nsfw_ltx_camera_control_hyperdump_scat_video_workflow.json"
    # Add more here...
)
```

**Step 3:** Enable it in the provision script

Find line ~3286 where workflows are installed and change:

```bash
# Before:
sync_workflows_from_dropbox || true

# After:
sync_workflows_from_links || true
```

---

## 📋 How It Works

### Workflow Sync Process

```
Provision Script Starts
    ↓
Check for DROPBOX_WORKFLOWS_URL in .env
    ↓
If set → Download workflows folder from Dropbox
    ↓
Extract all JSON files to /workspace/ComfyUI/user/default/workflows/
    ↓
If not set → Use built-in workflow templates
    ↓
Continue with rest of provisioning
```

### Update Process

**To update workflows on running instances:**

1. Edit workflows locally in `scripts/workflows/`
2. Upload updated files to Dropbox (they sync automatically)
3. On next instance provision, latest versions are downloaded

**OR for immediate update (without reprovisioning):**

SSH into running instance and run:
```bash
cd /workspace/ComfyUI/user/default/workflows
wget -O workflow.json "https://www.dropbox.com/scl/fi/abc123/workflow.json?dl=1"
```

---

## 🔧 Configuration Options

### Environment Variable (Method 1)

Add to `.env` file:

```bash
# Enable Dropbox workflow sync
DROPBOX_WORKFLOWS_URL=https://www.dropbox.com/sh/YOUR_FOLDER_ID/AABBCCDDee?dl=0
```

**Notes:**
- If not set, provision script skips Dropbox sync
- Falls back to built-in workflow templates (heredocs)
- Can be changed anytime by editing `.env`

### Direct Links Array (Method 2)

Edit `provision-reliable.sh` line ~1520:

```bash
local workflow_links=(
    "DROPBOX_DIRECT_LINK_1|filename1.json"
    "DROPBOX_DIRECT_LINK_2|filename2.json"
)
```

**Format:** `"URL|FILENAME"`
- URL must have `dl=1` (not `dl=0`)
- FILENAME is what it saves as in ComfyUI

---

## 🎯 Advantages of This Approach

✅ **Dead Simple:** Just share Dropbox folder, add link to .env
✅ **No Git Setup:** No repos, no SSH keys, no git commands
✅ **Instant Updates:** Change workflows in Dropbox, next provision gets them
✅ **Version Control:** Dropbox keeps file history (restore previous versions)
✅ **No Code Changes:** Works without modifying provision script
✅ **Fallback Safe:** If Dropbox fails, built-in workflows still work
✅ **Bandwidth Efficient:** Only downloads on provision (not constantly syncing)

---

## 🔍 Troubleshooting

### Issue: "Failed to download from Dropbox"

**Check:**
1. Is the Dropbox link correct and public?
2. Did you change `dl=0` to `dl=1` for direct download?
3. Is the link still valid? (Dropbox links can expire)
4. Test the link in browser first - does it download the file?

**Fix:**
```bash
# Test link manually:
wget "https://www.dropbox.com/scl/fi/abc123/test.json?dl=1"

# Check if file downloaded:
ls -lh test.json
```

### Issue: "unzip command not found"

**Fix:** Provision script auto-installs unzip if needed. If it fails:

```bash
ssh into instance
sudo apt-get update && sudo apt-get install -y unzip
```

### Issue: Workflows not appearing in ComfyUI

**Check:**
1. SSH into instance: `ssh root@INSTANCE_IP`
2. Check workflows directory:
   ```bash
   ls -lh /workspace/ComfyUI/user/default/workflows/
   ```
3. Verify JSON files are valid:
   ```bash
   python3 -m json.tool workflow.json
   ```

**Fix:** If files are corrupted, re-download:
```bash
cd /workspace/ComfyUI/user/default/workflows
rm *.json
# Then reprovision or manually wget from Dropbox
```

### Issue: Old workflows not being replaced

**Reason:** Provision script doesn't delete existing workflows, only adds new ones

**Fix:** Clear workflows directory before syncing:
```bash
# Add to provision-reliable.sh before sync:
rm -f "${workflows_dir}"/*.json
```

---

## 🚦 Testing Your Setup

### Test 1: Verify Dropbox Link

```bash
# Test download (run on your Windows machine):
curl -L "https://www.dropbox.com/sh/YOUR_FOLDER_ID?dl=1" -o test.zip
```

**Expected:** Downloads a ZIP file with your workflows

### Test 2: Test on Vast.ai Instance

1. Launch test instance
2. Run provision with your DROPBOX_WORKFLOWS_URL set
3. Check logs:
   ```bash
   grep "SYNCING WORKFLOWS" /workspace/provision_v3.log
   ```
4. Verify files:
   ```bash
   ls /workspace/ComfyUI/user/default/workflows/
   ```

### Test 3: Load in ComfyUI

1. Open ComfyUI web interface
2. Click "Load" button
3. Your workflows should appear in the list
4. Load one and verify all nodes connect correctly

---

## 📊 Comparison: Workflow Sync Methods

| Method | Ease | Speed | Version Control | Auto-Update |
|--------|------|-------|-----------------|-------------|
| **Dropbox Folder Sync** | ⭐⭐⭐⭐⭐ | Fast | ✅ (History) | On provision |
| **Dropbox Direct Links** | ⭐⭐⭐⭐ | Fast | ✅ (History) | On provision |
| Git Repository | ⭐⭐⭐ | Medium | ✅✅ (Full) | On provision + cron |
| Manual SCP | ⭐⭐ | Fast | ❌ | Manual only |
| Built-in Heredocs | ⭐⭐⭐⭐⭐ | Instant | ❌ | Requires script edit |

**Recommendation:** Use Dropbox Folder Sync (Method 1) for best balance of ease and functionality.

---

## 🔐 Security Notes

- **Dropbox links are public** if someone has the URL. Use private/unlisted links.
- **Don't commit Dropbox URLs to public repos** with sensitive workflows.
- **Consider using Dropbox App Tokens** for more secure access (requires rclone setup).
- **Rotate links periodically** if sharing with multiple people.

---

## 📝 Example: Full Setup

Here's a complete example:

**1. Your local setup:**
```
C:\Users\samsc\OneDrive\Desktop\working protoype\
├── scripts/
│   └── workflows/
│       ├── nsfw_pony_multiple_fetish_stacked_master_workflow.json
│       ├── nsfw_ltx_camera_control_hyperdump_scat_video_workflow.json
│       └── ... (21 more workflows)
└── .env
```

**2. Share workflows folder on Dropbox:**
- Shared link: `https://www.dropbox.com/sh/xyz789/AABBCCDD?dl=0`

**3. Add to `.env`:**
```bash
DROPBOX_WORKFLOWS_URL=https://www.dropbox.com/sh/xyz789/AABBCCDD?dl=0
```

**4. Run one-click-start:**
```powershell
.\one-click-start-fixed.ps1
```

**5. Provision script automatically:**
- Downloads workflows from Dropbox
- Extracts to `/workspace/ComfyUI/user/default/workflows/`
- All 23 workflows ready to use!

**6. To update a workflow:**
- Edit locally in `scripts/workflows/`
- Dropbox syncs automatically
- Next instance gets updated version

---

## 🎉 You're Done!

Your workflows will now auto-sync from Dropbox on every provision. Update them anytime by editing files in Dropbox!

**Next Steps:**
- Test with a small Vast.ai instance
- Verify workflows load in ComfyUI
- Generate a test image/video
- Update a workflow in Dropbox and reprovision to test sync

Need help? Check the troubleshooting section above or review provision logs at `/workspace/provision_v3.log`.

---

**Last Updated:** 2026-02-01
**Script Version:** provision-reliable.sh v3.1 (with Dropbox sync)
