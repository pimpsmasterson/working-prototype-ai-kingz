# ⏱️ Timeout Fix - Prewarm & Provisioning

## 🚨 Problem

The prewarm request was timing out after 60 seconds with this error:

```
⚠️  Prewarm attempt #1 failed: The request was canceled due to the configured HttpClient.Timeout of 60 seconds elapsing.
```

**Root Cause:**
- **Client-side**: PowerShell `Invoke-RestMethod` had `-TimeoutSec 60` (60 seconds)
- **Server-side**: Node.js HTTP server default timeout is 120 seconds (2 minutes)
- **Actual time needed**: Provisioning takes **5-15 minutes** depending on instance speed

The instance **WAS actually provisioning successfully**, but the HTTP request timed out before getting the response.

## ✅ Fix Applied

### 1. Client-Side Timeout (PowerShell)

**File**: [one-click-rent.ps1](../one-click-rent.ps1)

**Before:**
```powershell
-TimeoutSec 60 `  # ❌ Only 60 seconds!
```

**After:**
```powershell
-TimeoutSec 1800 `  # ✅ 30 minutes (1800 seconds)
```

**Location**: Line 429

### 2. Server-Side Timeout (Node.js)

**File**: [server/vastai-proxy.js](../server/vastai-proxy.js)

**Added:**
```javascript
// Set server timeout to 30 minutes (1800000ms) to allow for long-running operations
// like prewarm (which can take 5-15 minutes for provisioning)
server.timeout = 1800000; // 30 minutes
server.keepAliveTimeout = 65000; // Slightly higher than default nginx timeout
server.headersTimeout = 66000; // Should be higher than keepAliveTimeout
```

**Location**: Lines 1568-1572 (in `startProxy` function)

## 📊 Timeout Comparison

| Component | Before | After | Reason |
|-----------|--------|-------|--------|
| PowerShell client | 60s | 1800s (30min) | Match server timeout |
| Node.js server | 120s (default) | 1800s (30min) | Allow full provisioning |
| Provisioning time | 5-15 minutes | N/A | Actual time needed |

## 🎯 What Happens Now

### Before Fix
```
[Client] Send prewarm request
  ↓
[Client] Wait 60 seconds...
  ↓
[Client] ❌ TIMEOUT! Cancel request
  ↓
[Server] Still provisioning in background ✅
  ↓
[User] "Error! But instance is actually provisioning..."
```

### After Fix
```
[Client] Send prewarm request
  ↓
[Client] Wait up to 30 minutes...
  ↓
[Server] Provision completes (5-15 min)
  ↓
[Server] Send success response ✅
  ↓
[Client] ✅ Receive confirmation
  ↓
[User] "Success! Instance is ready!"
```

## 🔧 Technical Details

### Why 30 Minutes?

**Provisioning Breakdown:**
```
1. Vast.ai instance creation:     30-60 seconds
2. Docker container startup:      20-30 seconds
3. System package installation:   1-2 minutes
4. Python dependencies:            2-3 minutes
5. Model downloads:                5-10 minutes
                                   ─────────────
Total:                             ~8-15 minutes
```

**Safety margin**: 30 minutes allows for:
- Slow instances
- Network congestion
- Large model downloads
- Unexpected delays

### HTTP Keep-Alive Settings

```javascript
server.timeout = 1800000;         // 30 min - overall request timeout
server.keepAliveTimeout = 65000;  // 65 sec - TCP connection reuse
server.headersTimeout = 66000;    // 66 sec - must be > keepAlive
```

**Why these values?**
- `keepAliveTimeout`: Default nginx timeout is 60s, we use 65s to be slightly higher
- `headersTimeout`: Must be higher than keepAliveTimeout to avoid race conditions
- `timeout`: Overall request timeout for long-running operations

## ✅ Success Indicators

You'll know the fix works when:

1. **No more timeout errors** during prewarm
2. **Prewarm completes successfully** with instance details
3. **Status shows**:
   ```
   ✅ Prewarm initiated successfully!

   Instance Details:
   - Contract ID: 30844803
   - Machine ID: 25557
   - GPU: RTX 4060 Ti
   - Status: loading
   ```

## 🐛 Troubleshooting

### Still Getting Timeouts?

**Check 1: Is provisioning slow?**
```powershell
# Monitor provision progress
.\scripts\powershell\reconnect-vastai.ps1 -ShowLogs
```

**Check 2: Are models downloading?**
```powershell
# Check disk usage growth
.\scripts\powershell\reconnect-vastai.ps1 -ShowStatus
```

**Check 3: Network issues?**
- Slow downloads can extend provisioning time
- Consider instances with faster network (3000+ Mbps)

### If Provisioning Takes > 30 Minutes

**Very rare**, but if it happens:

1. **Increase timeout** further in both files:
   - `one-click-rent.ps1`: Line 429 → `-TimeoutSec 3600` (1 hour)
   - `server/vastai-proxy.js`: Line 1568 → `server.timeout = 3600000;` (1 hour)

2. **Check instance health**:
   ```powershell
   .\scripts\powershell\reconnect-vastai.ps1 -Interactive
   ```

3. **Destroy and retry** - Instance might be stuck:
   ```powershell
   # In Vast.ai console, destroy instance
   # Then re-run one-click-start
   .\one-click-rent.ps1
   ```

## 📝 Related Files

- [one-click-rent.ps1](../one-click-rent.ps1) - Client timeout fix
- [server/vastai-proxy.js](../server/vastai-proxy.js) - Server timeout fix
- [scripts/provision-reliable.sh](../scripts/provision-reliable.sh) - Provision script

## 💡 Best Practices

1. **Don't reduce timeouts** below 15 minutes for prewarm
2. **Monitor provision logs** while waiting
3. **Use resilient script** for automatic reconnection:
   ```powershell
   .\one-click-start-resilient.ps1
   ```
4. **Check instance specs** - Faster GPUs provision faster

## 🎓 Understanding the Error

The original error message:
```
The request was canceled due to the configured HttpClient.Timeout of 60 seconds elapsing.
```

**This means:**
- ✅ Request was sent successfully
- ✅ Server received it and started provisioning
- ❌ Client gave up waiting after 60 seconds
- ✅ Server kept provisioning in background

**The fix ensures:**
- ✅ Client waits long enough
- ✅ Server doesn't timeout either
- ✅ Both sides complete the full operation
- ✅ User gets proper success confirmation

---

## 🚀 Quick Test

To verify the fix works:

```powershell
# Run the one-click start
.\one-click-rent.ps1

# You should see (no timeout errors!):
✅ Prewarm initiated successfully!

Instance Details:
- Contract ID: 12345678
- Machine ID: 67890
- GPU: RTX 4090
- Status: loading

[8/8] Waiting for instance to be fully ready...
   Attempt 1/60: Status = provisioning
   ...
   ✅ Instance is ready!
```

**Success!** No more 60-second timeouts. 🎉
