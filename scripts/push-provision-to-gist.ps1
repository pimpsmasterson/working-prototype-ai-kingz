# Push scripts/provision-reliable.sh to the Gist (doc: docs/GIST_PUSH_AND_FRESH_START.md)
# Option A: Use GitHub API (requires GITHUB_TOKEN or GH_TOKEN in .env). Option B: Use git from Gist clone.

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$provisionPath = Join-Path $projectRoot "scripts\provision-reliable.sh"
$gistClone = Join-Path $env:TEMP "gist-c3f61f20067d498b6699d1bdbddea395"
$gistId = "c3f61f20067d498b6699d1bdbddea395"

# Try API first (no proxy issues)
$envPath = Join-Path $projectRoot ".env"
if (Test-Path $envPath) {
    Get-Content $envPath | Where-Object { $_ -match '^[^#].*=' } | ForEach-Object {
        $p = $_ -split '=', 2
        Set-Item -Path "env:$($p[0].Trim())" -Value $p[1].Trim() -ErrorAction SilentlyContinue
    }
}
$token = $env:GITHUB_TOKEN ?? $env:GH_TOKEN ?? $env:NEED_KEY
if ($token -and (Test-Path $provisionPath)) {
    Write-Host "Pushing via GitHub API..." -ForegroundColor Cyan
    & node (Join-Path $projectRoot "scripts\push-provision-to-gist.js")
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Done. Update .env COMFYUI_PROVISION_SCRIPT with the Raw URL printed above, then: pm2 restart vastai-proxy --update-env" -ForegroundColor Green
        exit 0
    }
    Write-Host "API push failed, falling back to git push from Gist clone." -ForegroundColor Yellow
}

# Option B: Git push from Gist clone (doc flow)
if (-not (Test-Path $gistClone)) {
    Write-Host "ERROR: Gist clone not found at $gistClone" -ForegroundColor Red
    Write-Host "Clone it once: git clone https://gist.github.com/$gistId.git $gistClone" -ForegroundColor Yellow
    exit 1
}
if (-not (Test-Path $provisionPath)) {
    Write-Host "ERROR: Provision script not found: $provisionPath" -ForegroundColor Red
    exit 1
}

Copy-Item $provisionPath -Destination (Join-Path $gistClone "provision-reliable.sh") -Force
Push-Location $gistClone
try {
    # Avoid proxy redirecting to 127.0.0.1:9 (discard port)
    git config --local http.proxy ""
    git config --local https.proxy ""
    git config --local --unset url."https://github.com/.insteadOf" 2>$null
    git config --local --unset url."https://gist.github.com/.insteadOf" 2>$null
    git add provision-reliable.sh
    git commit -m "Sync provision-reliable.sh: latest updates from workspace"
    git push origin main
    $commitHash = (git log -1 --format="%H").Trim()
    Write-Host ""
    Write-Host "Pushed. Add to .env:" -ForegroundColor Green
    Write-Host "COMFYUI_PROVISION_SCRIPT=https://gist.githubusercontent.com/pimpsmasterson/$gistId/raw/$commitHash/provision-reliable.sh" -ForegroundColor White
    Write-Host "Then: pm2 restart vastai-proxy --update-env" -ForegroundColor Cyan
} finally {
    Pop-Location
}
