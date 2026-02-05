# Dropbox Download Error Fix

## Issue
Curl error 22 when downloading from Dropbox - this means HTTP error (400, 404, 403, etc.)

## What Was Fixed
1. **Enhanced error logging** - Script now captures and displays actual Dropbox API error responses
2. **Better validation** - Checks token and path before attempting download
3. **Detailed error messages** - Shows HTTP status codes and error bodies

## Common Causes & Solutions

### 1. Path Doesn't Exist
**Error:** `path/not_found`  
**Fix:** Verify the path in Dropbox:
- Check your Dropbox account
- Ensure `/workspace/pornmaster100` exists exactly as written
- Paths are case-sensitive

### 2. Invalid/Expired Token
**Error:** `invalid_access_token` or `expired_access_token`  
**Fix:** Generate a new token:
1. Go to https://www.dropbox.com/developers/apps
2. Select your app
3. Generate new access token
4. Update `.env` with new `DROPBOX_TOKEN`

### 3. Token Permissions
**Error:** `insufficient_scope`  
**Fix:** Ensure token has:
- `files.content.read` (minimum)
- `files.metadata.read`
- Token must be for the correct Dropbox account

### 4. Folder Too Large
**Error:** Download starts but times out  
**Fix:** 
- Increase `--max-time` in script (currently 600 seconds)
- Consider splitting workspace into smaller folders
- Use `SKIP_TORCH=1` if PyTorch is already in workspace

## Testing Locally

Test your token and path:
```powershell
$token = "your_token_here"
$path = "/workspace/pornmaster100"
$body = @{path=$path} | ConvertTo-Json
Invoke-RestMethod -Uri "https://api.dropboxapi.com/2/files/list_folder" `
    -Method POST `
    -Headers @{"Authorization"="Bearer $token"; "Content-Type"="application/json"} `
    -Body $body
```

If this works, the path exists and token is valid.

## Next Steps
1. Check instance logs: `/tmp/provision-dropbox-only.log` on the instance
2. Look for the new error messages showing actual Dropbox API responses
3. Fix the root cause based on the error message
4. Retry provisioning
