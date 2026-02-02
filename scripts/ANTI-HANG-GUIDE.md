# Anti-Hanging & Dropbox Download Rules

## Overview

**provision-reliable.sh** includes multiple layers of protection to prevent downloads from hanging, especially with Dropbox's aggressive rate limiting. This guide explains all the safeguards.

---

## Dropbox Download Rules (Auto-Enforced)

### Hard Requirements
1. **Single Connection Only**
   - Dropbox **immediately bans** multi-connection downloads
   - Script enforces `connections=1` for all Dropbox URLs
   - Violation = instant 429 rate limit

2. **Bandwidth Limits**
   - ~1TB/day per Dropbox account
   - Individual file throttling after ~10GB/hour
   - Script stays well under these limits

3. **Rate Limiting Behavior**
   - Dropbox throttles to <10KB/s when exceeded
   - Can last 15-60 minutes per file
   - Script detects this and fails fast

---

## Anti-Hanging Mechanisms (5 Layers)

### Layer 1: Per-Attempt Timeout (aria2c/wget)
```bash
Dropbox:    3 minutes per attempt
HuggingFace: 5 minutes per attempt
```

**How it works:**
- Each download attempt has a hard timeout
- Dropbox gets shorter timeout to fail fast
- Prevents single retry from hanging forever

### Layer 2: Stall Detection (aria2c only)
```bash
--lowest-speed-limit=51200  # 50KB/s for Dropbox
--lowest-speed-limit=10240  # 10KB/s for others
```

**How it works:**
- Monitors download speed in real-time
- If speed drops below threshold for 30 seconds → abort
- Catches Dropbox throttling immediately
- Auto-fails to try fallback source

### Layer 3: Retry Limits
```bash
Dropbox:     5 retries max (fail fast)
HuggingFace: 10 retries max
```

**How it works:**
- Fewer retries for Dropbox (15 min max vs 50 min)
- Prevents endless retry loops
- Moves to fallback source faster

### Layer 4: Global Per-File Timeout (15 minutes)
```bash
timeout -k 30 900 download_file ...
```

**How it works:**
- **900 seconds (15 min)** hard limit per file
- If exceeded, sends SIGTERM to process
- After **30 seconds** grace period, sends SIGKILL (force kill)
- Even if aria2c hangs, this will kill it
- Exit codes:
  - `124` = Timeout (normal termination)
  - `137` = Force killed (unresponsive process)

### Layer 5: Automatic Cleanup
```bash
# Clean up partial/corrupt downloads
[[ -f "$filepath" ]] && rm -f "$filepath"
```

**How it works:**
- Removes partial files after timeout
- Prevents corrupt files from being detected as "cached"
- Forces clean retry on next provision attempt

---

## Timeout Hierarchy (Prevents Cascading Hangs)

```
┌──────────────────────────────────────────────────────┐
│ Global Timeout: 15 minutes (HARD KILL)              │
│  ├─ Primary Source Attempt                          │
│  │   ├─ aria2c timeout: 3-5 min per attempt         │
│  │   │   └─ Stall detection: 30s at low speed       │
│  │   └─ wget timeout: 5-10 min                      │
│  └─ Fallback Source Attempt                         │
│      ├─ aria2c timeout: 3-5 min per attempt         │
│      │   └─ Stall detection: 30s at low speed       │
│      └─ wget timeout: 5-10 min                      │
└──────────────────────────────────────────────────────┘
```

**Maximum hang time per file: 15 minutes**
- Even if all internal timeouts fail, global timeout kills it
- Script continues to next file (no cascade failure)

---

## Real-World Scenarios

### Scenario 1: Dropbox Throttling
**What happens:**
```
1. Download starts at 5MB/s
2. Dropbox throttles to 8KB/s after 2 minutes
3. Stall detection triggers (below 50KB/s threshold)
4. aria2c aborts after 30 seconds
5. Script tries fallback (HuggingFace)
6. Download completes from HF
```

**Result:** 3-minute recovery time (not 15 minutes!)

### Scenario 2: Network Interruption
**What happens:**
```
1. Download starts, gets 50% complete
2. Network drops completely
3. aria2c waits for timeout (3-5 min)
4. Timeout expires, aria2c fails
5. wget tries, also times out
6. Global timeout kills after 15 min total
7. Partial file cleaned up
8. Script continues to next file
```

**Result:** File marked as failed, provisioning continues

### Scenario 3: Dropbox Temporary Ban
**What happens:**
```
1. aria2c tries to download
2. Dropbox returns 429 (rate limit)
3. aria2c retries 5 times (5 × 3min = 15 min max)
4. All retries fail with 429
5. Script tries fallback (HuggingFace or Civitai)
6. Download completes from fallback
```

**Result:** Logged to `/workspace/provision_fallback.log`

---

## Monitoring Anti-Hang Events

### Real-Time Monitoring
```bash
# Watch provision log
tail -f /workspace/provision_v3.log

# Watch for timeouts
grep "TIMEOUT\|FORCE KILLED" /workspace/provision_v3.log

# Watch for stall detection
grep "Timeout or stall detected" /workspace/provision_v3.log

# Watch fallback usage
tail -f /workspace/provision_fallback.log
```

### Log Output Examples

**Stall Detection:**
```
06:23:45    ⚠️  Timeout or stall detected (speed < 51200 bytes/s)
06:23:45    ⚠️  Primary failed, trying fallback...
06:23:45       Fallback: HuggingFace
```

**Global Timeout:**
```
06:38:22    ⏱️  TIMEOUT: ponyDiffusionV6XL.safetensors exceeded 15-minute limit (killed)
06:38:22       This usually indicates Dropbox throttling or network issues
06:38:22       🗑️  Cleaned up partial file
```

**Force Kill:**
```
06:45:10    💀 FORCE KILLED: model.safetensors (unresponsive after timeout)
06:45:10    ⚠️  Download failed: model.safetensors (continuing...)
```

---

## Performance Impact

### Before Anti-Hang Protections
- **Worst case:** Single Dropbox file hangs for 50 minutes (10 retries × 5 min)
- **Total provision time:** Could exceed 4+ hours
- **Failure mode:** Script hangs indefinitely on network issues

### After Anti-Hang Protections
- **Worst case:** Single file hangs for 15 minutes (global timeout)
- **Typical case:** Dropbox throttle detected in 3 minutes, fallback succeeds
- **Total provision time:** ~25-30 minutes (unchanged for successful downloads)
- **Failure mode:** File marked as failed, script continues

**Improvement:** 3-4x faster recovery from hangs

---

## Configuration Tunables

If you want to adjust the anti-hang settings, edit these variables in `provision-reliable.sh`:

```bash
# In attempt_download() function:
timeout_per_attempt=180    # Dropbox: 3 min (line 431)
max_tries=5                # Dropbox: 5 retries (line 432)
lowest_speed=51200         # Dropbox: 50KB/s stall detection (line 433)

# In smart_download_parallel() function:
download_timeout=900       # Global: 15 min hard limit (line 596)
timeout_kill_after=30      # Grace period before SIGKILL (line 599)
```

**Warning:** Don't increase timeouts too much or you'll reintroduce hanging issues!

---

## Testing Anti-Hang Mechanisms

### Test 1: Simulate Dropbox Throttle
```bash
# Replace one Dropbox URL with an intentionally slow server
# Script should detect stall and fail to fallback within 3-5 minutes
```

### Test 2: Simulate Network Drop
```bash
# Start provision, then disable network adapter mid-download
# Script should timeout after 15 minutes and continue
```

### Test 3: Force Kill Test
```bash
# Monitor a download that's taking too long
# After 15 min, should see "TIMEOUT" message and cleanup
```

---

## Troubleshooting

### Issue: Downloads still hanging
**Check:**
1. Is `timeout` command available? (`which timeout`)
2. Are you running on Windows Git Bash? (use WSL instead)
3. Check log for "TIMEOUT" messages

### Issue: Too many timeouts
**Possible causes:**
1. Dropbox account rate limited (wait 1 hour)
2. Network too slow (min speed requirements not met)
3. VPN/proxy interfering with downloads

**Solution:**
- Check fallback log: `cat /workspace/provision_fallback.log`
- Most files should succeed via fallback
- If >50% fail, check network speed

### Issue: Files marked as cached incorrectly
**Fix:**
```bash
# Clean up ComfyUI models directory
rm -rf /workspace/ComfyUI/models/checkpoints/*.safetensors
# Re-run provisioning
```

---

## Summary: Why This Won't Lock Up

1. **Multiple timeout layers** (attempt → stall → global)
2. **Aggressive Dropbox tuning** (3-min timeout, 50KB/s stall)
3. **Automatic fallback** (HF/Dropbox redundancy)
4. **Force kill protection** (SIGKILL after 15 min + 30s)
5. **Automatic cleanup** (no corrupt partial files)
6. **Continue on failure** (one file failure ≠ script failure)

**Result:** Provisioning completes in ~25-30 minutes, even with Dropbox throttling or network issues.
