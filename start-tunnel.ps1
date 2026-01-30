# Wrapper to centralized scripts/powershell/start-tunnel.ps1
$target = Join-Path $PSScriptRoot 'scripts\powershell\start-tunnel.ps1'
if (-Not (Test-Path $target)) { Write-Error "Target script not found: $target"; exit 1 }
& $target @Args
