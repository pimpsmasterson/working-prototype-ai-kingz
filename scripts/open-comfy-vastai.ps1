<#
.SYNOPSIS
    Open ComfyUI on a Vast.ai instance via SSH tunnel (when Cloudflare tunnel failed).
.DESCRIPTION
    Gets SSH connection details for the instance and starts a tunnel so you can
    open http://localhost:8080 in your browser. Uses id_rsa_vast by default.
.EXAMPLE
    .\open-comfy-vastai.ps1 -InstanceId 30957355
.EXAMPLE
    .\open-comfy-vastai.ps1 -InstanceId 30957355 -LocalPort 9090
#>
Param(
    [Parameter(Mandatory = $true)]
    [string]$InstanceId,

    [int]$LocalPort = 8080,
    [string]$KeyPath = "$env:USERPROFILE\.ssh\id_rsa_vast",
    [switch]$NoOpen
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

# 1) Pre-checks so we fail fast with clear errors
if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: ssh not in PATH. Install OpenSSH Client (Windows Settings -> Apps -> Optional features -> OpenSSH Client)." -ForegroundColor Red
    exit 2
}
$keyFile = [System.IO.Path]::GetFullPath([Environment]::ExpandVariables($KeyPath))
if (-not (Test-Path -LiteralPath $keyFile)) {
    Write-Host "ERROR: SSH key not found: $keyFile" -ForegroundColor Red
    Write-Host "Create one or point -KeyPath to your Vast.ai key." -ForegroundColor Yellow
    exit 3
}

# 2) Load VASTAI_API_KEY from .env so vastai CLI works
$envPath = Join-Path $projectRoot ".env"
if (Test-Path $envPath) {
    Get-Content $envPath | ForEach-Object {
        if ($_ -match '^\s*VASTAI_API_KEY=(.+)$') { $env:VASTAI_API_KEY = $matches[1].Trim() }
    }
}
if (-not $env:VASTAI_API_KEY) {
    Write-Host "WARN: VASTAI_API_KEY not set. vastai ssh-url may fail. Set it in .env or environment." -ForegroundColor Yellow
}

# 3) Get SSH URL from vastai CLI (e.g. ssh://root@ssh2.vast.ai:19860)
$sshUrl = $null
try {
    $sshUrl = & vastai ssh-url $InstanceId 2>&1 | Out-String
    $sshUrl = $sshUrl.Trim()
    if ($LASTEXITCODE -ne 0) { $sshUrl = $null }
} catch {
    $sshUrl = $null
}

if (-not $sshUrl -or $sshUrl -notmatch "ssh://") {
    Write-Host "Could not get SSH URL for instance $InstanceId." -ForegroundColor Yellow
    Write-Host "  - Install vastai: pip install vastai" -ForegroundColor Gray
    Write-Host "  - Set API key: vastai set api-key YOUR_KEY (or in .env as VASTAI_API_KEY)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Manual method (always works):" -ForegroundColor Cyan
    Write-Host "  1. Open https://cloud.vast.ai/instances/ and click your instance."
    Write-Host "  2. Note 'SSH Addr' and 'SSH Port' (e.g. ssh2.vast.ai and 19860)."
    Write-Host "  3. Run:"
    Write-Host "     .\scripts\connect-comfy.ps1 -RemoteHost ssh2.vast.ai -SshPort 19860 -Key `"`$env:USERPROFILE\.ssh\id_rsa_vast`" -LocalPort $LocalPort" -ForegroundColor White
    Write-Host ""
    exit 1
}

try {
    $uri = [System.Uri]$sshUrl
    $remoteHost = $uri.Host
    $sshPort = $uri.Port
} catch {
    Write-Host "ERROR: Could not parse SSH URL: $sshUrl" -ForegroundColor Red
    exit 4
}
if (-not $sshPort -or $sshPort -le 0) { $sshPort = 22 }

Write-Host "Instance $InstanceId -> $remoteHost`:$sshPort" -ForegroundColor Green
Write-Host "Tunnel: http://localhost:$LocalPort -> remote ComfyUI:8188" -ForegroundColor Green
Write-Host "Press Ctrl+C to close the tunnel." -ForegroundColor Gray
Write-Host ""

& "$scriptDir\connect-comfy.ps1" -RemoteHost $remoteHost -SshPort $sshPort -User "root" -Key $keyFile -LocalPort $LocalPort -RemotePort 8188 -NoOpen:$NoOpen
