# One-Click Start Audit Report

**File:** `one-click-start.ps1`  
**Date:** 2026-02-06  
**Purpose:** Identify why one-click-start may be broken and document all issues.

---

## Summary of Issues Found

| # | Severity | Location | Issue | Impact |
|---|----------|----------|-------|--------|
| 1 | **High** | Step 2 (lines 47-54) | .env loader does not strip quotes from values | Values like `ADMIN_API_KEY="abc-123"` keep quotes → prewarm 403 |
| 2 | **Medium** | Step 4 (line 134) | `pm2 start` output suppressed; errors hidden | PM2 failures are silent; hard to debug |
| 3 | **Medium** | Non-PM2 fallback (line 157) | `Merge-HashTable` receives wrong input type | Start-Job path may fail with env var passing |
| 4 | **Low** | Step 3 (lines 92-103) | `Get-NetTCPConnection` can fail on some Windows configs | Port cleanup may silently fail |
| 5 | **Low** | Access points (line 245) | Admin URL `/pages/admin-warm-pool.html` works via static but canonical is `/admin/warm-pool` | Minor inconsistency |

---

## Issue 1: .env Loader Does Not Strip Quotes (HIGH)

**Where:** Lines 47-54

```powershell
Get-Content ".env" | Where-Object { $_ -match '^[^#].*=' } | ForEach-Object {
    $parts = $_ -split '=', 2
    if ($parts.Count -eq 2) {
        $key = $parts[0].Trim()
        $value = $parts[1].Trim()   # <-- NO quote stripping
        Set-Item -Path "env:$key" -Value $value
    }
}
```

**Problem:** If `.env` has quoted values (e.g. `ADMIN_API_KEY="64d94046-d1b0-447d-9b2d-55b2d5bf0744"`), the value is stored **with quotes**. When the prewarm request sends `'x-admin-key' = $env:ADMIN_API_KEY`, the header becomes `"64d94046-..."` (with quotes). The server compares against the raw `.env` value (without quotes) and authentication fails with 403.

**Current .env:** Your `ADMIN_API_KEY=64d94046-d1b0-447d-9b2d-55b2d5bf0744` has no quotes, so this may not affect you now—but if any value is ever quoted, it will break.

**Fix (from one-click-start-fixed.ps1):**
```powershell
if ($value.Length -ge 2 -and $value[0] -eq '"' -and $value[-1] -eq '"') { $value = $value.Substring(1, $value.Length - 2) }
if ($value.Length -ge 2 -and $value[0] -eq "'" -and $value[-1] -eq "'") { $value = $value.Substring(1, $value.Length - 2) }
```

---

## Issue 2: PM2 Output Suppressed (MEDIUM)

**Where:** Lines 127, 134-135

```powershell
& pm2 delete vastai-proxy 2>&1 | Out-Null
# ...
& pm2 start config/ecosystem.config.js --update-env 2>&1 | Out-Null
```

**Problem:** All PM2 output is discarded. If `pm2 start` fails (e.g. script path wrong, module not found), the user sees nothing. The script continues and Step 5 health check may fail 60 seconds later with a generic "Server failed to start" message.

**Fix:** At minimum, capture and check exit code; on failure, show PM2 output before exiting.

---

## Issue 3: Merge-HashTable / Start-Job Env Passing (MEDIUM)

**Where:** Lines 146-157 (non-PM2 path)

```powershell
$serverJob = Start-Job -ScriptBlock {
    param($workDir, $envVars)
    ...
} -ArgumentList (Get-Location).Path, (Get-ChildItem env: | ForEach-Object { @{$_.Name = $_.Value} } | Merge-HashTable)
```

**Problem:** `Get-ChildItem env: | ForEach-Object { @{$_.Name = $_.Value} }` produces many single-key hashtables. `Merge-HashTable` expects `[hashtable[]]` via pipeline. The pipeline sends one hashtable at a time; `Merge-HashTable` receives them correctly. However, passing a very large hashtable (hundreds of env vars) as an argument to Start-Job can hit serialization limits or cause slowness on some PowerShell versions.

**Note:** This path is only used when PM2 is not found. If PM2 is installed, this is not executed.

---

## Issue 4: Get-NetTCPConnection May Fail (LOW)

**Where:** Lines 92-103

**Problem:** `Get-NetTCPConnection -LocalPort $port -State Listen` can throw or return nothing in some Windows configurations (e.g. restricted execution policy, missing WinRM, firewall). The script wraps in `try { } catch { }` so it won't crash, but port cleanup may not run—leaving port 3000 in use. Then PM2 or the new server fails to bind.

**Symptom:** "Port 3000 already in use" or health check never succeeds.

---

## Issue 5: Admin URL Inconsistency (LOW)

**Where:** Line 245

```powershell
Write-Host "   Admin Dashboard:  http://localhost:3000/pages/admin-warm-pool.html"
```

**Reality:** The server exposes `/admin/warm-pool` as the canonical route. `express.static` also serves `/pages/admin-warm-pool.html`. Both work, but the script could use `/admin/warm-pool` for consistency.

---

## Additional Observations

### ecosystem.config.js cwd

The config uses `cwd: './'`. When `pm2 start config/ecosystem.config.js` runs, PM2's cwd is the shell's current directory. Because we now `Set-Location $scriptDir` at the start, this should be correct. If the script were run without changing directory, `cwd: './'` could point elsewhere.

### Required vs Recommended Env Vars

The script only checks `VASTAI_API_KEY` and `ADMIN_API_KEY`. The fixed script also requires `HUGGINGFACE_HUB_TOKEN` and `CIVITAI_TOKEN`. Provisioning will fail without those, but one-click-start will still report "Environment variables loaded."

### Order of Operations

1. Kill processes on 3000, 8080, 8188  
2. `pm2 delete vastai-proxy`  
3. `pm2 start`  
4. Wait 5 seconds  
5. Health check (up to 60 seconds)

If the server takes longer than 5 seconds to bind (e.g. DB init), the health check might hit before the server is ready. The 30 retries × 2 seconds give 60 seconds total, which is usually enough.

---

## Recommended Fixes (Priority Order)

1. **Add quote stripping** to the .env loader (Issue 1).
2. **Stop suppressing PM2 output** on failure; show stderr when `pm2 start` fails (Issue 2).
3. **Add HUGGINGFACE_HUB_TOKEN and CIVITAI_TOKEN** to required vars if you want provisioning to work reliably.
4. Optionally: **Use `/admin/warm-pool`** in the printed Admin Dashboard URL (Issue 5).

**Status:** ✅ Fixes applied in `one-click-start.ps1` on 2026-02-07: implemented .env quote stripping, surfaced PM2 errors (and fallback to direct start), added netstat fallback and warnings for port cleanup, and made Start-Job environment passing robust. Run `powershell .\one-click-start.ps1` with a quoted `ADMIN_API_KEY` to verify prewarm no longer returns 403.

---

## How to Reproduce / Verify

1. Add quotes to a value in `.env` (e.g. `ADMIN_API_KEY="64d94046-d1b0-447d-9b2d-55b2d5bf0744"`) → run one-click-start → prewarm should return 403.
2. Rename `config/ecosystem.config.js` temporarily → run script → PM2 will fail silently; health check will eventually fail.
3. Start another process on port 3000 before running → port cleanup may or may not free it depending on Issue 4.
