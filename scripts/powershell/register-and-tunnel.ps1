<#
PowerShell helper: register-and-tunnel.ps1
- Generates an ed25519 key (unless VASTAI_SSH_KEY_TYPE env var overrides)
- Registers the public key with Vast.ai using existing script
- Prints and optionally runs an SSH tunnel command to forward local port 8080 to remote localhost:8080
Usage:
  - Set environment variable VASTAI_API_KEY (or export in current session)
  - Run: .\scripts\powershell\register-and-tunnel.ps1
  - Optional args: -Host ssh2.vast.ai -Port 20070 -RemotePort 8080 -AutoOpen
#>
param(
  [string]$Host,
  [int]$Port,
  [int]$RemotePort = 8080,
  [switch]$AutoOpen
)

Set-StrictMode -Version Latest

function Ensure-SshKey {
    $home = $env:USERPROFILE
    $sshDir = Join-Path $home ".ssh"
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    }

    $keyType = $env:VASTAI_SSH_KEY_TYPE -or 'ed25519'
    $keyPath = $env:VASTAI_SSH_KEY_PATH -or (Join-Path $sshDir 'id_vast')
    $pubPath = "$keyPath.pub"

    if (-not (Test-Path $keyPath -PathType Leaf) -or -not (Test-Path $pubPath -PathType Leaf)) {
        Write-Host "🔄 Generating new SSH key ($keyType) at $keyPath" -ForegroundColor Yellow
        if ($keyType -ieq 'ed25519') {
            & ssh-keygen -t ed25519 -f "$keyPath" -N "" -C "ai-kings-vastai" | Out-Null
        } elseif ($keyType -ieq 'rsa') {
            $bits = $env:VASTAI_SSH_KEY_BITS -or 4096
            & ssh-keygen -t rsa -b $bits -f "$keyPath" -N "" -C "ai-kings-vastai" | Out-Null
        } else {
            throw "Unsupported key type: $keyType"
        }

        # Restrict key file permissions on Windows
        try {
            $user = if ($env:USERDOMAIN) { "$($env:USERDOMAIN)\$($env:USERNAME)" } else { $env:USERNAME }
            & icacls "$keyPath" /inheritance:r /grant:r "$user:R" | Out-Null
            Write-Host "✅ Set ACLs on $keyPath" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to set ACLs on $keyPath: $_"
        }
    } else {
        Write-Host "Using existing SSH key at $keyPath" -ForegroundColor Green
    }

    return @{ keyPath = $keyPath; pubPath = $pubPath }
}

# Main
if (-not $env:VASTAI_API_KEY) {
    Write-Warning "Environment variable VASTAI_API_KEY not set. Set it before running this script."
    exit 2
}

$kp = Ensure-SshKey
$pub = Get-Content $kp.pubPath -Raw
$env:PUBLIC_KEY = $pub

# Register using node script
Write-Host "Registering public key with Vast.ai..." -ForegroundColor Yellow
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    Write-Error "Node.js not found in PATH. Please install Node.js to use the registration script."; exit 3
}

$scriptPath = Join-Path $PSScriptRoot "..\register_vastai_ssh_key.js"
$scriptPath = (Resolve-Path $scriptPath).Path
$exitCode = & node $scriptPath
if ($LASTEXITCODE -ne 0) {
    Write-Error "Registration script exited with code $LASTEXITCODE"; exit $LASTEXITCODE
}

Write-Host "✅ Public key registered (or already present)" -ForegroundColor Green

if (-not $Host -or -not $Port) {
    Write-Host "\nNext step: get SSH host & port from your Vast.ai instance's SSH panel (e.g., ssh2.vast.ai and 20070)."
} else {
    $tunnelCmd = "ssh -i \"$($kp.keyPath)\" -p $Port -L 8080:localhost:$RemotePort root@$Host -N -o StrictHostKeyChecking=no"

    Write-Host "\nRun this command to open an SSH tunnel (forwards your local 8080 to remote localhost:$RemotePort):" -ForegroundColor Cyan
    Write-Host "  $tunnelCmd" -ForegroundColor White

    if ($AutoOpen) {
        Write-Host "Opening SSH tunnel (press Ctrl+C to close)" -ForegroundColor Yellow
        & ssh -i $kp.keyPath -p $Port -L 8080:localhost:$RemotePort root@$Host -N -o StrictHostKeyChecking=no
    }
}

Write-Host "\nDone. If you need, provide the instance host and port to open a tunnel automatically: -Host <host> -Port <port> -AutoOpen" -ForegroundColor Green
