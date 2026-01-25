param(
  [string]$LogDir = "$PSScriptRoot\..\logs",
  [int]$KeepDays = 14
)
if (-not (Test-Path $LogDir)) { Write-Host "Log dir not found: $LogDir"; exit 0 }
$cutoff = (Get-Date).AddDays(-$KeepDays)
Get-ChildItem -Path $LogDir -Filter '*.log' | Where-Object { $_.LastWriteTime -lt $cutoff } | ForEach-Object { Remove-Item $_.FullName -Force }
# Rotate current app.log if present
$cur = Join-Path $LogDir 'app.log'
if (Test-Path $cur) {
  $dt = (Get-Date).ToString('yyyy-MM-dd')
  $dest = Join-Path $LogDir "app-$dt.log"
  Move-Item $cur $dest -Force
}
Write-Host 'Rotation complete'