# One-Click Start: Reliable PM2 start and Warm-Pool Prewarm

This document describes the improved `one-click-start.ps1` behavior and how it ensures the server starts under PM2 and triggers a warm-pool prewarm that rents an instance.

What the script now does:
- Loads environment variables from `.env` into the PowerShell session.
- Clears warm-pool DB volatile state.
- Starts or restarts the PM2 process using `npx pm2 startOrRestart config/ecosystem.config.js --update-env` so PM2 picks up the current environment variables and updated code.
- Waits for the HTTP health endpoint `/api/proxy/health` to return 200 (up to 5 minutes).
- Calls the admin prewarm endpoint `/api/proxy/admin/warm-pool/prewarm` with the `x-admin-key` header derived from `ADMIN_API_KEY` in `.env`.
- If the admin call is rejected (HTTP 403), the script restarts the PM2 process with `--update-env` and retries prewarm up to 3 times.
- After initiating prewarm, the script prints useful follow-up commands to check warm-pool status and tail PM2 logs.

Notes and troubleshooting:
- If PM2 reports an in-memory version mismatch, run `pm2 update`.
- If prewarm fails to rent an instance, collect the PM2 logs (`pm2 logs vastai-proxy --lines 200`) and the warm-pool status (`GET /api/proxy/admin/warm-pool/status`) and share them for analysis.
- Rotate any sensitive tokens found in `.env` if they were exposed.

Usage:
```powershell
.\one-click-start.ps1
```

If you want me to also add an automated step to SSH into the rented instance and grab provisioning logs, say so and I will implement it.
