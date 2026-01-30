# Wrapper to centralized scripts/powershell/test-extended-video.ps1
$target = Join-Path $PSScriptRoot 'scripts\powershell\test-extended-video.ps1'
if (-Not (Test-Path $target)) { Write-Error "Target script not found: $target"; exit 1 }
& $target @Args
