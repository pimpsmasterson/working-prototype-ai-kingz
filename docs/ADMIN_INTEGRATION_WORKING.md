# ✅ Admin Integration - WORKING SOLUTION

## Quick Start

### 1. Start the Server
Open PowerShell in the project directory and run:
```powershell
npm start
```

The server will load environment variables from `.env` automatically and start on `http://localhost:3000`.

You should see:
```
Loaded persistent tokens from C:\Users\samsc\.proxy-tokens.json
Database initialized: ...\data\warm_pool.db
DB schema ready
[DEBUG] Starting server... require.main === module is true
[DEBUG] PORT: 3000
[DEBUG] startProxy() called, server object: true
Vast.ai proxy running on http://localhost:3000/ (ready)
[DEBUG] Server is now listening
```

**Leave this terminal window open** - the server needs to stay running.

### 2. Test the Server
Open a **NEW** PowerShell window and run:
```powershell
.\test-proxy.ps1
```

This will test:
- ✅ Health endpoint
- ✅ Prewarm with admin key
- ✅ Warm-pool status

## Admin UI Access

1. Open browser to: `http://localhost:3000/admin/warm-pool`
2. Enter admin key: `secure_admin_key_change_me` (from `.env` file)
3. Click **Refresh** to load current status
4. Click **Prewarm** to start a GPU instance

## Admin API Endpoints

All admin endpoints require the header: `x-admin-key: secure_admin_key_change_me`

### Prewarm (Start GPU)
```powershell
Invoke-RestMethod -Method POST `
  -Uri "http://localhost:3000/api/proxy/warm-pool/prewarm" `
  -Headers @{ "x-admin-key" = "secure_admin_key_change_me" }
```

### Check Status
```powershell
Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/warm-pool"
```

### Terminate Instance
```powershell
Invoke-RestMethod -Method POST `
  -Uri "http://localhost:3000/api/proxy/warm-pool/terminate" `
  -Headers @{ "x-admin-key" = "secure_admin_key_change_me" } `
  -Body (@{instanceId="CONTRACT_ID"} | ConvertTo-Json) `
  -ContentType "application/json"
```

### View Audit Logs
```powershell
Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/logs?limit=50" `
  -Headers @{ "x-admin-key" = "secure_admin_key_change_me" }
```

## Environment Variables (`.env`)

The server loads these from your `.env` file:
- `ADMIN_API_KEY=secure_admin_key_change_me` ← Use this as the admin key
- `VASTAI_API_KEY` ← Your Vast.ai API key  
- `HUGGINGFACE_HUB_TOKEN` ← For model downloads
- `CIVITAI_TOKEN` ← For Civitai model downloads
- `COMFYUI_PROVISION_SCRIPT` ← Provisioning script URL

## Troubleshooting

### Server won't start
- Check if port 3000 is already in use: `netstat -ano | findstr :3000`
- Kill existing node processes: `Get-Process -Name node | Stop-Process -Force`

### Connection refused
- Make sure the server terminal is still running (didn't exit)
- Check that you're using `http://localhost:3000` (not `127.0.0.1` if there are network restrictions)
- Try from the same machine/terminal where the server is running

### Admin key rejected
- Verify the admin key in `.env` matches what you're sending
- Check the server logs for `[DEBUG] Key received:` to see what the server got
- Default key from `.env`: `secure_admin_key_change_me`

## Next Steps

Once prewarm succeeds (takes 2-5 minutes):
1. Open Studio UI: `http://localhost:3000/studio.html`
2. GPU will be ready for image/video generation
3. Monitor status at: `http://localhost:3000/admin/warm-pool`

---

**Status**: ✅ All admin endpoints integrated and tested  
**Last Updated**: January 26, 2026
