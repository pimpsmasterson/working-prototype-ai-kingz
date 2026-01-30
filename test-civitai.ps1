# Wrapper to centralized scripts/powershell/test-civitai.ps1
$target = Join-Path $PSScriptRoot 'scripts\powershell\test-civitai.ps1'
if (-Not (Test-Path $target)) { Write-Error "Target script not found: $target"; exit 1 }
& $target @Args
