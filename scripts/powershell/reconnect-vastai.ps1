# Reconnect to Vast.ai Instance and Show Status
# Quick script to reconnect to lost Vast.ai SSH connection

param(
    [Parameter(Mandatory=$false)]
    [string]$InstanceIP = "76.66.207.49",  # Default to current instance

    [Parameter(Mandatory=$false)]
    [switch]$ShowLogs,

    [Parameter(Mandatory=$false)]
    [switch]$ShowStatus,

    [Parameter(Mandatory=$false)]
    [switch]$Interactive
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   🔌 Vast.ai Instance Reconnect Tool                          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "Instance IP: " -NoNewline -ForegroundColor Gray
Write-Host "$InstanceIP" -ForegroundColor Green
Write-Host ""

# Build SSH command with keepalive options
$sshOptions = "-i $env:USERPROFILE\.ssh\id_rsa_vast -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o TCPKeepAlive=yes -o ConnectTimeout=30"
$sshCommand = "ssh $sshOptions -p 16018 root@ssh1.vast.ai"

if ($ShowLogs) {
    Write-Host "📋 Fetching provision logs..." -ForegroundColor Cyan
    Write-Host ""

    $remoteCommand = "tail -100 /workspace/provision_v3.log 2>/dev/null || echo 'Log file not found'"
    & $sshCommand $remoteCommand

    Write-Host ""
    Write-Host "✅ Logs retrieved" -ForegroundColor Green
    exit 0
}

if ($ShowStatus) {
    Write-Host "📊 Checking instance status..." -ForegroundColor Cyan
    Write-Host ""

    $statusCommand = @'
echo "=== Disk Usage ==="
df -h /workspace | grep -v Filesystem
echo ""
echo "=== Downloaded Models ==="
find /workspace/ComfyUI/models -type f \( -name '*.safetensors' -o -name '*.ckpt' -o -name '*.pt' \) 2>/dev/null | wc -l | awk '{print $1 " model files"}'
du -sh /workspace/ComfyUI/models 2>/dev/null | awk '{print $1 " total size"}'
echo ""
echo "=== Provision Status ==="
if ps aux | grep -q '[p]rovision'; then
    echo "✅ Provision script is running"
else
    echo "⚠️  Provision script not running"
fi
echo ""
echo "=== ComfyUI Status ==="
if ps aux | grep -q '[c]omfyui'; then
    echo "✅ ComfyUI is running"
    if [ -f /workspace/comfyui.pid ]; then
        echo "   PID: $(cat /workspace/comfyui.pid)"
    fi
else
    echo "⏳ ComfyUI not started yet"
fi
echo ""
echo "=== Last Provision Log Lines ==="
tail -10 /workspace/provision_v3.log 2>/dev/null || echo "No provision log yet"
'@

    & $sshCommand $statusCommand

    Write-Host ""
    Write-Host "✅ Status retrieved" -ForegroundColor Green
    exit 0
}

if ($Interactive) {
    Write-Host "🔗 Opening interactive SSH session..." -ForegroundColor Cyan
    Write-Host "   (Type 'exit' to disconnect)" -ForegroundColor Gray
    Write-Host ""

    & $sshCommand

    Write-Host ""
    Write-Host "🔌 Disconnected" -ForegroundColor Yellow
    exit 0
}

# Default: Show menu
Write-Host "Select an action:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. Open interactive SSH session" -ForegroundColor Cyan
Write-Host "  2. Show provision logs (last 100 lines)" -ForegroundColor Cyan
Write-Host "  3. Show instance status" -ForegroundColor Cyan
Write-Host "  4. Follow provision logs (real-time)" -ForegroundColor Cyan
Write-Host "  5. Restart provision script (skip Civitai validation)" -ForegroundColor Cyan
Write-Host "  6. Open ComfyUI web interface" -ForegroundColor Cyan
Write-Host "  7. Exit" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "Enter choice (1-7)"

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Host "🔗 Opening SSH session..." -ForegroundColor Cyan
        Write-Host ""
        & $sshCommand
    }

    "2" {
        Write-Host ""
        Write-Host "📋 Provision logs:" -ForegroundColor Cyan
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
        & $sshCommand "tail -100 /workspace/provision_v3.log 2>/dev/null || echo 'Log not found'"
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    }

    "3" {
        Write-Host ""
        & $sshCommand @'
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║   📊 Instance Status                                           ║"
╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "💾 Disk Usage:"
df -h /workspace | tail -1 | awk '{print "   Used: " $3 " / " $2 " (" $5 ")"}'
echo ""
echo "📦 Downloaded Models:"
find /workspace/ComfyUI/models -type f \( -name '*.safetensors' -o -name '*.ckpt' \) 2>/dev/null | wc -l | awk '{print "   Files: " $1}'
du -sh /workspace/ComfyUI/models 2>/dev/null | awk '{print "   Size: " $1}'
echo ""
echo "🔧 Running Processes:"
ps aux | grep -E '[p]rovision|[c]omfyui' | awk '{print "   " $11 " (PID " $2 ")"}'
'@
    }

    "4" {
        Write-Host ""
        Write-Host "📡 Following provision logs (Ctrl+C to stop)..." -ForegroundColor Cyan
        Write-Host ""
        & $sshCommand "tail -f /workspace/provision_v3.log"
    }

    "5" {
        Write-Host ""
        Write-Host "🔄 Restarting provision script (skipping Civitai validation)..." -ForegroundColor Yellow
        Write-Host ""
        & $sshCommand "cd /workspace && sed -i 's/if ! validate_civitai_token; then/if false; then # validate_civitai_token; then/' /tmp/provision.sh && bash /tmp/provision.sh &"
        Write-Host "✅ Provision script restarted in background (Civitai validation disabled)" -ForegroundColor Green
        Write-Host "   Use option 4 to follow logs" -ForegroundColor Gray
    }

    "6" {
        Write-Host ""
        Write-Host "🌐 Opening ComfyUI..." -ForegroundColor Cyan
        $comfyUrl = "http://${InstanceIP}:8188"
        Write-Host "   URL: $comfyUrl" -ForegroundColor Green
        Start-Process $comfyUrl
    }

    "7" {
        Write-Host ""
        Write-Host "👋 Goodbye!" -ForegroundColor Gray
        exit 0
    }

    default {
        Write-Host ""
        Write-Host "❌ Invalid choice" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "✅ Done!" -ForegroundColor Green
Write-Host ""
