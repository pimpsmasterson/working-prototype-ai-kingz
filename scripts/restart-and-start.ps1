# Restart-and-start: Kill relevant processes and launch start-ai-kings.ps1 in a new window
# Usage: powershell -ExecutionPolicy Bypass -File scripts/restart-and-start.ps1

param(
    [switch]$NoNewWindow
)

Write-Host "Restart-and-start: stopping common processes and launching start-ai-kings.ps1..."

# Resolve repo root (script sits in scripts/)
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$repoRoot = Resolve-Path "$scriptRoot\.."
Set-Location $repoRoot

# Stop pm2-managed app if pm2 is available
if (Get-Command pm2 -ErrorAction SilentlyContinue) {
    Write-Host "Stopping pm2 app 'vastai-proxy' (if present)..."
    pm2 delete vastai-proxy 2>$null | Out-Null
    pm2 stop vastai-proxy 2>$null | Out-Null
    Start-Sleep -Seconds 1
}

# Kill common processes (node, python, aria2c)
$toKill = @('node','node.exe','python','python.exe','aria2c','aria2c.exe')
foreach ($name in $toKill) {
    try {
        Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "Stopping process: $($_.ProcessName) (PID: $($_.Id))"
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    } catch {
        # ignore
    }
}

Start-Sleep -Milliseconds 500

# Launch start-ai-kings.ps1
$startScript = Join-Path $repoRoot 'start-ai-kings.ps1'
if (-not (Test-Path $startScript)) {
    Write-Host "Error: start-ai-kings.ps1 not found at $startScript" -ForegroundColor Red
    exit 1
}

if ($NoNewWindow) {
    Write-Host "Launching start-ai-kings.ps1 in current window..."
    & powershell -ExecutionPolicy Bypass -File $startScript
} else {
    Write-Host "Launching start-ai-kings.ps1 in a new PowerShell window..."
    Start-Process powershell -ArgumentList '-NoExit','-ExecutionPolicy','Bypass','-File',"$startScript" -WorkingDirectory $repoRoot
}

Write-Host "Done. If you opened a new window, use that to monitor startup."