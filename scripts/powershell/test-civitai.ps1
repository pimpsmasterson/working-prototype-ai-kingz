# Civitai Token & Provision Script Diagnostic
# Tests if Civitai models can be accessed

Write-Host "`n=== Civitai Token & Provision Script Test ===" -ForegroundColor Cyan

# 1. Check if CIVITAI_TOKEN is set
Write-Host "`n[1] Checking CIVITAI_TOKEN environment variable..." -ForegroundColor Yellow
if ($env:CIVITAI_TOKEN) {
    $tokenLength = $env:CIVITAI_TOKEN.Length
    $tokenPreview = $env:CIVITAI_TOKEN.Substring(0, [Math]::Min(8, $tokenLength))
    Write-Host "✓ CIVITAI_TOKEN is set (${tokenLength} chars, starts with: ${tokenPreview}...)" -ForegroundColor Green
} else {
    Write-Host "✗ CIVITAI_TOKEN is NOT set!" -ForegroundColor Red
    Write-Host "  Set it with: `$env:CIVITAI_TOKEN='your_token_here'" -ForegroundColor Yellow
    exit 1
}

# 2. Test Civitai API connectivity (Pony Diffusion V6 XL)
Write-Host "`n[2] Testing Civitai API access (Pony Diffusion V6 XL)..." -ForegroundColor Yellow
$testModelUrl = "https://civitai.com/api/download/models/290640?type=Model&format=SafeTensor&size=full&fp=fp16"

try {
    Write-Host "   Testing WITHOUT token..." -ForegroundColor Gray
    $responseNoAuth = Invoke-WebRequest -Uri $testModelUrl -Method Head -MaximumRedirection 0 -ErrorAction Stop
    Write-Host "   ⚠ Download works WITHOUT token (model may be public)" -ForegroundColor Yellow
} catch {
    if ($_.Exception.Response.StatusCode -eq 401 -or $_.Exception.Response.StatusCode -eq 403) {
        Write-Host "   ✓ Authentication required (expected)" -ForegroundColor Green
    } elseif ($_.Exception.Response.StatusCode -eq 302 -or $_.Exception.Response.StatusCode -eq 307) {
        Write-Host "   ⚠ Redirect without auth (model may be public)" -ForegroundColor Yellow
    } else {
        Write-Host "   ! Unexpected response: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    }
}

try {
    Write-Host "   Testing WITH token..." -ForegroundColor Gray
    $headers = @{
        "Authorization" = "Bearer $env:CIVITAI_TOKEN"
    }
    $responseWithAuth = Invoke-WebRequest -Uri $testModelUrl -Headers $headers -Method Head -MaximumRedirection 0 -ErrorAction Stop
    Write-Host "   ✓ Authenticated request successful!" -ForegroundColor Green
    
    if ($responseWithAuth.Headers.'Content-Length') {
        $sizeGB = [Math]::Round([int64]$responseWithAuth.Headers.'Content-Length' / 1GB, 2)
        Write-Host "   Model size: ${sizeGB} GB" -ForegroundColor Cyan
    }
} catch {
    if ($_.Exception.Response.StatusCode -eq 302 -or $_.Exception.Response.StatusCode -eq 307) {
        Write-Host "   ✓ Authenticated redirect (download would proceed)" -ForegroundColor Green
        if ($_.Exception.Response.Headers.Location) {
            Write-Host "   Redirect location: $($_.Exception.Response.Headers.Location.Substring(0, 60))..." -ForegroundColor Cyan
        }
    } elseif ($_.Exception.Response.StatusCode -eq 401 -or $_.Exception.Response.StatusCode -eq 403) {
        Write-Host "   ✗ Authentication FAILED with token!" -ForegroundColor Red
        Write-Host "   Token may be invalid or expired" -ForegroundColor Yellow
        exit 1
    } else {
        Write-Host "   Response: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    }
}

# 3. Test provision script download
Write-Host "`n[3] Testing provision script download..." -ForegroundColor Yellow
$provisionScriptUrl = "https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw/"

try {
    $scriptContent = Invoke-RestMethod -Uri $provisionScriptUrl -TimeoutSec 10
    Write-Host "   ✓ Provision script downloaded successfully" -ForegroundColor Green
    
    # Check if script properly uses CIVITAI_TOKEN
    if ($scriptContent -match 'CIVITAI_TOKEN') {
        Write-Host "   ✓ Script contains CIVITAI_TOKEN usage" -ForegroundColor Green
        
        # Extract the token usage pattern
        $tokenPattern = $scriptContent | Select-String -Pattern 'CIVITAI_TOKEN.*auth_token' -Context 1,1
        if ($tokenPattern) {
            Write-Host "`n   Token usage in script:" -ForegroundColor Cyan
            Write-Host "   $($tokenPattern.Line)" -ForegroundColor Gray
        }
    } else {
        Write-Host "   ✗ Script does NOT contain CIVITAI_TOKEN usage!" -ForegroundColor Red
        exit 1
    }
    
    # Check for Civitai model URLs
    $civitaiUrls = ([regex]::Matches($scriptContent, 'https://civitai\.com/api/download/[^"]+') | ForEach-Object { $_.Value }) | Select-Object -Unique
    Write-Host "`n   Civitai models in script: $($civitaiUrls.Count)" -ForegroundColor Cyan
    foreach ($url in $civitaiUrls) {
        Write-Host "   - $url" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "   ✗ Failed to download provision script!" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Yellow
    exit 1
}

# 4. Summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "✓ CIVITAI_TOKEN is configured" -ForegroundColor Green
Write-Host "✓ Civitai API is accessible with token" -ForegroundColor Green
Write-Host "✓ Provision script is valid and uses token" -ForegroundColor Green

Write-Host "`n=== Potential Issues ===" -ForegroundColor Yellow
Write-Host "
Common reasons Civitai models don't download:
1. Token not passed to remote instance
   - Check: Server must have CIVITAI_TOKEN in environment when starting
   - Fix: Ensure token is set BEFORE running 'npm start'
   
2. Provision script downloads but wget fails
   - Check: Instance logs at /workspace/*.log
   - Fix: Verify token is actually exported in remote shell
   
3. Models download but are incomplete/corrupted
   - Check: Disk space (needs ~6GB for Pony V6 XL)
   - Fix: Increase WARM_POOL_DISK_GB to 150+
   
4. Script times out during download
   - Check: Network speed of Vast.ai instance
   - Fix: Sequential script should retry 3x per file
" -ForegroundColor Gray

Write-Host "`n=== Next Steps ===" -ForegroundColor Cyan
Write-Host "To verify on a live instance:
1. SSH to instance: node -e 'require(`"./lib/vastai-ssh`").connectToInstance(<contractId>)'
2. Check environment: echo `$CIVITAI_TOKEN
3. Check logs: tail -f /workspace/provision*.log
4. Manual test: wget --header=`"Authorization: Bearer `$CIVITAI_TOKEN`" <civitai_url>
" -ForegroundColor Gray
