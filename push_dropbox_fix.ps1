# Push scripts/provision-dropbox-only.sh to the Gist
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$provisionPath = Join-Path $projectRoot "scripts\provision-dropbox-only.sh"
$gistClone = Join-Path $env:TEMP "gist-c3f61f20067d498b6699d1bdbddea395"
$gistId = "c3f61f20067d498b6699d1bdbddea395"

if (-not (Test-Path $gistClone)) {
    Write-Host "ERROR: Gist clone not found at $gistClone" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $provisionPath)) {
    Write-Host "ERROR: Provision script not found: $provisionPath" -ForegroundColor Red
    exit 1
}

Copy-Item $provisionPath -Destination (Join-Path $gistClone "provision-dropbox-only.sh") -Force
Push-Location $gistClone
try {
    git config --local http.proxy ""
    git config --local https.proxy ""
    git add provision-dropbox-only.sh
    git commit -m "Update provision-dropbox-only.sh with rclone fallback"
    git push origin main
    $commitHash = (git log -1 --format="%H").Trim()
    Write-Host ""
    Write-Host "Pushed. Updated Gist URL:" -ForegroundColor Green
    Write-Host "https://gist.githubusercontent.com/pimpsmasterson/$gistId/raw/$commitHash/provision-dropbox-only.sh" -ForegroundColor White
}
finally {
    Pop-Location
}
