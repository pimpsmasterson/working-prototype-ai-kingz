
# Connect to ComfyUI via SSH Tunnel (Robust)
# Used by open-comfy-vastai.ps1

Param(
    [string]$RemoteHost,
    [int]$SshPort,
    [string]$User = "root",
    [string]$Key,
    [int]$LocalPort = 8188,
    [int]$RemotePort = 8188,
    [switch]$NoOpen
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Key)) {
    Write-Host "SSH Key not found: $Key" -ForegroundColor Red
    exit 1
}

Write-Host "Establishing SSH Tunnel..." -ForegroundColor Cyan
Write-Host "Target: $User@$RemoteHost`:$SshPort" -ForegroundColor DarkGray
Write-Host "Tunnel: localhost:$LocalPort -> remote:$RemotePort" -ForegroundColor DarkGray
Write-Host "Key:    $Key" -ForegroundColor DarkGray

# Open browser first if requested (give tunnel a moment to establish)
if (-not $NoOpen) {
    Start-Job -ScriptBlock {
        Start-Sleep -Seconds 3
        Start-Process "http://localhost:$using:LocalPort"
    } | Out-Null
}

# Run SSH command with strict host checking disabled to avoid prompts
# -N: Do not execute a remote command (just forward ports)
# -o StrictHostKeyChecking=no: Don't ask to verify host key
# -o UserKnownHostsFile=nul: Don't save host key (prevents conflicts)
$sshCmd = "ssh -i `"$Key`" -p $SshPort -o StrictHostKeyChecking=no -o UserKnownHostsFile=nul -N -L ${LocalPort}:localhost:${RemotePort} ${User}@${RemoteHost}"

Write-Host "Running: $sshCmd" -ForegroundColor DarkGray
cmd /c $sshCmd
