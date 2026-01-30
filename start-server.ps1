# Wrapper to centralized scripts/powershell/start-server.ps1
$target = Join-Path $PSScriptRoot 'scripts\powershell\start-server.ps1'
if (-Not (Test-Path $target)) { Write-Error "Target script not found: $target"; exit 1 }
& $target @Args
