# Extended Video Testing Script
# Run this script to test the new 8-12 second video generation capability

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Extended NSFW Video Generation - Test Suite" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$SERVER_URL = "http://localhost:3000"
$ADMIN_KEY = $env:ADMIN_API_KEY

if (-not $ADMIN_KEY) {
    # Try to load from .env file
    if (Test-Path ".env") {
        Write-Host "🔄 Loading environment variables from .env file..." -ForegroundColor Gray
        Get-Content ".env" | ForEach-Object {
            if ($_ -match '^([^=]+)=(.*)$') {
                [Environment]::SetEnvironmentVariable($matches[1], $matches[2])
            }
        }
        $ADMIN_KEY = $env:ADMIN_API_KEY
    }
    
    if (-not $ADMIN_KEY) {
        Write-Host "❌ ERROR: ADMIN_API_KEY environment variable not set" -ForegroundColor Red
        Write-Host "Set it with: `$env:ADMIN_API_KEY='your_key'" -ForegroundColor Yellow
        Write-Host "Or ensure .env file exists with the variables" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "✅ Admin API key found" -ForegroundColor Green
Write-Host ""

# Test 1: Server Health
Write-Host "Test 1: Checking server health..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$SERVER_URL/api/proxy/health"
    Write-Host "✅ Server is healthy" -ForegroundColor Green
    Write-Host "   Status: $($health.status)" -ForegroundColor Gray
} catch {
    Write-Host "❌ Server not responding. Start with: node server/vastai-proxy.js" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test 2: Warm Pool Status
Write-Host "Test 2: Checking warm pool status..." -ForegroundColor Yellow
try {
    $poolStatus = Invoke-RestMethod -Uri "$SERVER_URL/api/proxy/admin/warm-pool/status" `
        -Headers @{"x-admin-api-key" = $ADMIN_KEY}
    
    $readyCount = ($poolStatus.instances | Where-Object { $_.status -eq 'ready' }).Count
    Write-Host "✅ Warm pool status retrieved" -ForegroundColor Green
    Write-Host "   Ready instances: $readyCount" -ForegroundColor Gray
    Write-Host "   Total instances: $($poolStatus.instances.Count)" -ForegroundColor Gray
    
    if ($readyCount -eq 0) {
        Write-Host "⚠️  No ready instances. Provisioning one now..." -ForegroundColor Yellow
        
        $prewarm = Invoke-RestMethod -Uri "$SERVER_URL/api/proxy/admin/warm-pool/prewarm" `
            -Method POST `
            -Headers @{"x-admin-api-key" = $ADMIN_KEY}
        
        Write-Host "   Provisioning started. Instance ID: $($prewarm.instanceId)" -ForegroundColor Gray
        Write-Host "   This will take 15-25 minutes. Check status periodically." -ForegroundColor Gray
        Write-Host ""
        Write-Host "Run this script again in 20 minutes to continue testing." -ForegroundColor Cyan
        exit 0
    }
} catch {
    Write-Host "❌ Failed to check warm pool status" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test 3: Workflow Validation
Write-Host "Test 3: Validating new workflows..." -ForegroundColor Yellow

$workflows = @(
    "nsfw_video_extended_hybrid",
    "nsfw_image_pornmaster"
)

foreach ($workflow in $workflows) {
    try {
        $validation = Invoke-RestMethod -Uri "$SERVER_URL/api/proxy/admin/workflows/validate/$workflow" `
            -Headers @{"x-admin-api-key" = $ADMIN_KEY}
        
        if ($validation.valid) {
            Write-Host "✅ $workflow is valid" -ForegroundColor Green
        } else {
            Write-Host "❌ $workflow validation failed" -ForegroundColor Red
            Write-Host "   Missing: $($validation.missingModels -join ', ')" -ForegroundColor Red
        }
    } catch {
        Write-Host "⚠️  $workflow validation endpoint not available (may need server restart)" -ForegroundColor Yellow
    }
}
Write-Host ""

# Test 4: Generate Pornmaster Image
Write-Host "Test 4: Generating Pornmaster test image..." -ForegroundColor Yellow
$imageBody = @{
    prompt = "beautiful woman, photorealistic, natural lighting, professional photography, detailed skin texture"
    negativePrompt = "cartoon, anime, illustration, blurry, fake, 3d render"
    workflowType = "image"
    workflowTemplate = "nsfw_image_pornmaster"
    nsfw = $true
    settings = @{
        width = 512
        height = 768
        steps = 30
        cfgScale = 7
        sampler = "dpm_2_ancestral"
        seed = 123456
    }
} | ConvertTo-Json -Depth 5

try {
    $imageJob = Invoke-RestMethod -Uri "$SERVER_URL/api/proxy/generate" `
        -Method POST `
        -Body $imageBody `
        -ContentType "application/json"
    
    Write-Host "✅ Image generation job submitted" -ForegroundColor Green
    Write-Host "   Job ID: $($imageJob.jobId)" -ForegroundColor Gray
    Write-Host "   Check status: $SERVER_URL/api/proxy/status/$($imageJob.jobId)" -ForegroundColor Gray
    
    # Poll for completion
    Write-Host "   Waiting for completion..." -ForegroundColor Gray
    $maxAttempts = 30
    $attempt = 0
    
    while ($attempt -lt $maxAttempts) {
        Start-Sleep -Seconds 5
        $attempt++
        
        try {
            $status = Invoke-RestMethod -Uri "$SERVER_URL/api/proxy/status/$($imageJob.jobId)"
            
            if ($status.status -eq "completed") {
                Write-Host "✅ Image generated successfully!" -ForegroundColor Green
                Write-Host "   Output: $($status.output)" -ForegroundColor Gray
                break
            } elseif ($status.status -eq "failed") {
                Write-Host "❌ Image generation failed" -ForegroundColor Red
                Write-Host "   Error: $($status.error)" -ForegroundColor Red
                break
            } else {
                Write-Host "   Status: $($status.status) (attempt $attempt/$maxAttempts)" -ForegroundColor Gray
            }
        } catch {
            Write-Host "   Polling error (attempt $attempt)" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "❌ Failed to submit image generation job" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Red
}
Write-Host ""

# Test 5: Generate Extended Video (8 seconds)
Write-Host "Test 5: Generating extended 8-second video..." -ForegroundColor Yellow
$videoBody = @{
    prompt = "beautiful woman dancing elegantly, smooth graceful movements, cinematic lighting, high quality, flowing dress"
    negativePrompt = "static, frozen, choppy motion, blurry, censored, low quality, watermark"
    workflowType = "video"
    workflowTemplate = "nsfw_video_extended_hybrid"
    nsfw = $true
    settings = @{
        checkpoint = "dreamshaper_8.safetensors"
        width = 512
        height = 512
        steps = 30
        cfgScale = 7
        sampler = "euler"
        frames = 32  # Will be interpolated to 64
        fps = 8
        seed = 789012
    }
} | ConvertTo-Json -Depth 5

try {
    $videoJob = Invoke-RestMethod -Uri "$SERVER_URL/api/proxy/generate" `
        -Method POST `
        -Body $videoBody `
        -ContentType "application/json"
    
    Write-Host "✅ Video generation job submitted" -ForegroundColor Green
    Write-Host "   Job ID: $($videoJob.jobId)" -ForegroundColor Gray
    Write-Host "   Check status: $SERVER_URL/api/proxy/status/$($videoJob.jobId)" -ForegroundColor Gray
    Write-Host "   Expected time: ~8-12 minutes" -ForegroundColor Gray
    
    # Poll for completion (longer timeout for video)
    Write-Host "   Waiting for completion (this may take a few minutes)..." -ForegroundColor Gray
    $maxAttempts = 180  # 15 minutes
    $attempt = 0
    
    while ($attempt -lt $maxAttempts) {
        Start-Sleep -Seconds 5
        $attempt++
        
        try {
            $status = Invoke-RestMethod -Uri "$SERVER_URL/api/proxy/status/$($videoJob.jobId)"
            
            if ($status.status -eq "completed") {
                Write-Host "✅ Video generated successfully!" -ForegroundColor Green
                Write-Host "   Output: $($status.output)" -ForegroundColor Gray
                Write-Host "   Duration: ~8 seconds (64 interpolated frames @ 8fps)" -ForegroundColor Gray
                break
            } elseif ($status.status -eq "failed") {
                Write-Host "❌ Video generation failed" -ForegroundColor Red
                Write-Host "   Error: $($status.error)" -ForegroundColor Red
                break
            } else {
                $elapsed = $attempt * 5
                Write-Host "   Status: $($status.status) - ${elapsed}s elapsed" -ForegroundColor Gray
            }
        } catch {
            Write-Host "   Polling error (attempt $attempt)" -ForegroundColor Gray
        }
    }
    
    if ($attempt -ge $maxAttempts) {
        Write-Host "⚠️  Video generation timeout (5 minutes). Job may still be processing." -ForegroundColor Yellow
        Write-Host "   Check manually: $SERVER_URL/api/proxy/status/$($videoJob.jobId)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Failed to submit video generation job" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Red
}
Write-Host ""

# Summary
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Test Suite Complete" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Check generated files in: data/generated/" -ForegroundColor Gray
Write-Host "2. Review video quality and duration" -ForegroundColor Gray
Write-Host "3. Test with different prompts and settings" -ForegroundColor Gray
Write-Host "4. Monitor VRAM usage via admin dashboard" -ForegroundColor Gray
Write-Host ""
Write-Host "For 12-second videos, use frames=48 in settings" -ForegroundColor Yellow
Write-Host "For Pony SDXL videos, wait for CogVideoX implementation" -ForegroundColor Yellow
Write-Host ""
