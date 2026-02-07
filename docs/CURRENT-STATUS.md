# Current Status

**Last updated:** 2026-02-07

---

## What's Working

- **One-click start** (`one-click-start.ps1`) runs end-to-end: prerequisites, env load, port cleanup, PM2 start, health check, prewarm.
- **Server** starts via PM2 (`vastai-proxy`); health at `http://localhost:3000/api/proxy/health`.
- **Warm pool** reports instance (e.g. contract 31012271) when already present or starts prewarm.
- **Studio UI:** `http://localhost:3000/pages/studio.html`
- **Admin dashboard:** `http://localhost:3000/admin/warm-pool`

---

## Why One-Click Start Was Broken (Failure Analysis)

One-click start had been broken since integration/recent changes due to **PowerShell parsing and variable issues**, not server or API logic.

### 1. Script never ran – parse error at line 311

- **Symptom:** `The string is missing the terminator: ".` at line 311 (`Write-Host "…" -ForegroundColor Magenta`).
- **Cause:** File contained **Unicode** (emojis like 🎉, ✅, ❌, box-drawing ╔═║╚, 🌐📊💡). When PowerShell runs the script with default/system encoding (e.g. Windows-1252 or no BOM), it can misread UTF-8 multi-byte sequences. One of those sequences was interpreted in a way that broke the closing quote of a string, so the parser thought the string never ended.
- **Fix:** Replaced all Unicode in the script with **ASCII** (`[OK]`, `[X]`, `[!]`, `===`, plain text). Script now parses correctly regardless of console encoding.

### 2. Parse error at line 117 (after first fix)

- **Symptom:** `Variable reference is not valid. ':' was not followed by a valid variable name character` at `$port:`.
- **Cause:** In PowerShell, `$port:` is parsed as a **drive/scope** (e.g. like `C:`). The parser treats the colon as part of the variable reference, so it expects a valid variable name after `:`.
- **Fix:** Used string concatenation for the warning message instead of interpolating `$port:` in a double-quoted string, e.g. `"… port " + $port + ": " + …`. Alternatively `${port}:` would work.

### 3. Port cleanup fallback failed – "Cannot overwrite variable PID"

- **Symptom:** When something was listening on a port, port cleanup hit: `Cannot overwrite variable PID because it is read-only or constant` (and netstat fallback failed the same way).
- **Cause:** **`$pid` is a read-only automatic variable** in PowerShell (current process ID). The script used `$pid` as a loop variable and for process IDs when killing processes, which overwrote the automatic variable.
- **Fix:** Renamed all such uses to **`$procId`** in both the `Get-NetTCPConnection` path and the netstat fallback.

### 4. Noisy warnings when ports were already free

- **Symptom:** Long WARNING every run: "Port cleanup failed for port 3000 using Get-NetTCPConnection: No matching MSFT_NetTCPConnection objects found… Attempting netstat fallback."
- **Cause:** On this system, `Get-NetTCPConnection -LocalPort $port -State Listen` **throws** when no connection exists (instead of returning empty). The script treated that as "failure" and ran the fallback.
- **Fix:** In the catch block, if the message matches "No matching.*MSFT_NetTCPConnection", treat as "port is free" and `continue` without warning or fallback.

---

## Summary Table

| Issue | Cause | Fix |
|-------|--------|-----|
| Script won’t run; string terminator at 311 | Unicode in script + encoding | All output/decoration to ASCII |
| Invalid variable `$port:` at 117 | Parser sees drive/scope | Concatenation or `${port}` |
| Cannot overwrite variable PID | `$pid` is read-only | Use `$procId` everywhere |
| Spam when ports free | Get-NetTCPConnection throws when empty | Treat "No matching…" as success, skip warning |

---

## Recommended Next Steps

1. **Restore `.env.example`** if it was deleted accidentally (template only, no secrets).
2. Keep **one-click-start.ps1** as the single canonical launcher; align **one-click-start-fixed.ps1** / **start-ai-kings*.ps1** or retire them to avoid drift.
3. For **provisioning/warm pool**: see `docs/ONE-CLICK-START-AUDIT.md` and server logs (`pm2 logs vastai-proxy`) if instance rent or ComfyUI readiness is still failing.
