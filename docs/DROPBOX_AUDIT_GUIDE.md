# Dropbox Asset Audit Guide

## Overview

The Dropbox Asset Audit Script compares your `COMPLETE_SOFTWARE_MANIFEST.md` against files stored in your Dropbox folder (`/pornmaster100`) to verify:

- ✅ **Presence** - Which manifest files exist in Dropbox
- ✅ **Size** - Whether file sizes match expected values (±5% tolerance)
- ✅ **Checksums** - SHA-256 hashes for files ≤5GB
- ✅ **Extra Files** - Untracked files in Dropbox not listed in manifest

## Prerequisites

### 1. Python Environment
```bash
# Ensure Python 3.8+ is installed
python --version

# Install dependencies
pip install -r requirements.txt
```

### 2. Environment Variables

Your `.env` file must contain:
```bash
DROPBOX_TOKEN=sl.xxxxx...  # Your Dropbox access token
DROPBOX_FOLDER=/pornmaster100  # Path to Dropbox folder
```

**Security Note:** The script NEVER logs the token value - only confirms it's present.

### 3. Manifest File

Ensure `docs/COMPLETE_SOFTWARE_MANIFEST.md` exists and is up-to-date.

## Usage

### Basic Execution

```bash
# From project root
python scripts/audit_dropbox_assets.py
```

### Output Format

The script produces **two outputs**:

1. **JSON Report** (stdout, first line):
   ```json
   {"summary": {...}, "missing": [...], "extra": [...], "mapping": {...}}
   ```

2. **Human Summary** (stderr, subsequent lines):
   ```
   === AUDIT SUMMARY ===
   Missing: 5
   Extras: 12
   Size mismatches: 2
   Checksum mismatches: 0
   ```

3. **Report File**: `audit_report.json` (saved to current directory)

### Redirect Output

```bash
# Save JSON to file, see summary in terminal
python scripts/audit_dropbox_assets.py > report.json

# Save both JSON and summary
python scripts/audit_dropbox_assets.py > report.json 2> summary.txt
```

## Report Structure

### JSON Format

```json
{
  "summary": {
    "total_manifested": 100,
    "total_found": 95,
    "missing_count": 5,
    "extra_count": 12,
    "size_mismatch_count": 2,
    "checksum_mismatch_count": 0
  },
  "missing": [
    {
      "category": "checkpoints",
      "name": "missing_model.safetensors"
    }
  ],
  "extra": [
    {
      "path": "/pornmaster100/extra_file.bin",
      "size": 1234567890,
      "modified": "2026-01-15T10:30:00Z"
    }
  ],
  "size_mismatches": [
    {
      "name": "pony_realism_v2.2.safetensors",
      "expected_size": 6979321856,
      "found_size": 6500000000,
      "paths": ["/pornmaster100/pony_realism_v2.2.safetensors"]
    }
  ],
  "checksum_mismatches": [],
  "mapping": {
    "pmXL_v1.safetensors": [
      {
        "path": "/pornmaster100/checkpoints/pmXL_v1.safetensors",
        "size": 6979321856,
        "modified": "2025-12-01T08:15:00Z",
        "sha256_or_null": "abc123def456..."
      }
    ]
  },
  "notes": [
    "Skipped checksum (>5GB): wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors",
    "FLAGGED for review: suspicious_file.bin - Matched illegal content pattern"
  ]
}
```

## Behavior & Features

### Checksum Computation

- **Files ≤5GB**: Downloads and computes SHA-256
- **Files >5GB**: Skips checksum (logs in `notes`)
- **Concurrent Downloads**: Max 4 simultaneous (controlled by semaphore)

### Content Safety

The script flags files matching suspicious patterns:
- `child`, `minor`, `kid`, `teen`, `young`, `underage`
- `csam`, `cp`
- `non-consent`, `rape`, `assault`

**Flagged files are NOT downloaded** and appear in `notes` for manual review.

### Rate Limiting

- **Automatic Retry**: Exponential backoff on 429 errors
- **Retry-After**: Respects Dropbox's rate limit headers
- **Max Retries**: 3 attempts before failure

### Size Matching

- **Tolerance**: ±5% of expected size
- **Example**: A 6.5GB file can be 6.18GB-6.83GB
- **Parsing**: Handles "6.5GB", "320MB", "1.8GB" formats

## Troubleshooting

### Error: DROPBOX_TOKEN not set

**Solution:** Ensure `.env` file exists with valid token:
```bash
# Check .env file
cat .env | grep DROPBOX_TOKEN

# If missing, add it:
echo "DROPBOX_TOKEN=sl.your_token_here" >> .env
```

### Error: Manifest not found

**Solution:** Verify manifest path:
```bash
ls -la docs/COMPLETE_SOFTWARE_MANIFEST.md
```

### Rate Limit Exceeded

**Symptoms:** `Rate limit exceeded after 3 retries`

**Solutions:**
- Wait 60 minutes and retry
- Reduce concurrent downloads (edit `MAX_CONCURRENT_DOWNLOADS` in script)
- Run audit in batches (manually comment out categories)

### Checksum Failures

**Symptoms:** `Checksum failed for <file>: <error>`

**Common Causes:**
- Network timeout (file too large)
- Corrupted download
- Dropbox API quota exceeded

**Solution:** Re-run the script (checksums are computed independently)

### Import Error: aiohttp

**Solution:** Install dependencies:
```bash
pip install aiohttp python-dotenv
```

## Performance Expectations

### Small Folder (<50 files, <50GB)
- **Listing:** ~5-10 seconds
- **Matching:** ~1 second
- **Checksums:** ~5-10 minutes (depending on file sizes)

### Medium Folder (50-200 files, 50-200GB)
- **Listing:** ~10-30 seconds
- **Matching:** ~2-5 seconds
- **Checksums:** ~20-60 minutes

### Large Folder (>200 files, >200GB)
- **Listing:** ~30-120 seconds (pagination)
- **Matching:** ~5-10 seconds
- **Checksums:** ~1-3 hours (most files >5GB will be skipped)

## Advanced Usage

### Dry Run (No Checksums)

Edit script and set:
```python
MAX_FILE_SIZE_FOR_CHECKSUM = 0  # Skip all checksums
```

### Custom Concurrent Downloads

Edit script:
```python
MAX_CONCURRENT_DOWNLOADS = 2  # Reduce for slower connections
```

### Parse Only (No Dropbox API)

Comment out the audit execution:
```python
# async with DropboxClient(token) as client:
#     engine = AuditEngine(client, entries)
#     await engine.run_audit(folder)

# Print parsed entries instead
for entry in entries:
    print(f"{entry.category}: {entry.name}")
```

## Interpreting Results

### Missing Files

**Action:** Download from sources listed in manifest:
- HuggingFace: `huggingface.co/<model_path>`
- Civitai: Use `CIVITAI_TOKEN` with API
- Dropbox: Check alternate links

### Extra Files

**Action:** Review and either:
- Add to manifest if needed
- Delete if obsolete
- Keep as backup (no action required)

### Size Mismatches

**Causes:**
- Wrong model version
- Incomplete download
- Compressed vs. uncompressed file

**Action:** Re-download or update manifest with correct size

### Checksum Mismatches

**Causes:**
- File corruption
- Model was updated
- Different quantization/precision

**Action:** Verify file integrity and re-download if needed

## Security Notes

1. **Token Never Logged**: Script confirms token exists but never prints value
2. **Content Safety**: Suspicious filenames are flagged, not downloaded
3. **Read-Only**: Script only reads from Dropbox, never modifies or deletes
4. **Local Storage**: Report saved to `audit_report.json` (review before sharing)

## Integration

### In CI/CD Pipeline

```bash
# Run audit and check for missing files
python scripts/audit_dropbox_assets.py 2>&1 | tee audit.log
if grep -q '"missing_count": 0' audit.log; then
  echo "✓ All manifest files present"
else
  echo "✗ Missing files detected"
  exit 1
fi
```

### In Cron Job

```bash
# Daily audit at 2 AM
0 2 * * * cd /path/to/project && python scripts/audit_dropbox_assets.py > /var/log/dropbox-audit.json 2>&1
```

## Maintenance

### Update Manifest

After adding/removing models:
1. Edit `docs/COMPLETE_SOFTWARE_MANIFEST.md`
2. Update version number and date
3. Re-run audit: `python scripts/audit_dropbox_assets.py`

### Verify Checksums

For critical files, manually verify SHA-256:
```bash
# From audit_report.json
sha256sum path/to/file.safetensors
```

Compare with `sha256_or_null` value in report.

## Support & Debugging

### Enable Verbose Logging

All progress messages go to stderr. Redirect to see:
```bash
python scripts/audit_dropbox_assets.py 2>&1 | tee -a audit_debug.log
```

### Test Dropbox Connection

```bash
# Quick test
python -c "
import os
from dotenv import load_dotenv
load_dotenv()
token = os.getenv('DROPBOX_TOKEN')
print(f'Token present: {bool(token)}')
print(f'Token length: {len(token) if token else 0}')
"
```

### Parse Manifest Only

```bash
# Test manifest parsing
python -c "
import sys
sys.path.append('scripts')
from audit_dropbox_assets import ManifestParser
parser = ManifestParser('docs/COMPLETE_SOFTWARE_MANIFEST.md')
entries = parser.parse()
print(f'Found {len(entries)} entries')
for e in entries[:5]:
    print(f'  {e.category}: {e.name}')
"
```

## FAQ

**Q: Does this script modify my Dropbox files?**
A: No, it's completely read-only.

**Q: How long does the audit take?**
A: Depends on folder size. Expect 30-120 minutes for typical setups.

**Q: Can I run this on multiple folders?**
A: Yes, change `DROPBOX_FOLDER` in `.env` and re-run.

**Q: What if a file has no checksum in the report?**
A: Either >5GB (skipped) or flagged for safety (see `notes`).

**Q: Can I use this with Google Drive or OneDrive?**
A: No, currently Dropbox-specific. Adapting to other providers would require API client changes.

---

**Last Updated:** 2026-02-04
**Script Version:** 1.0
**Author:** AI Kings Team
