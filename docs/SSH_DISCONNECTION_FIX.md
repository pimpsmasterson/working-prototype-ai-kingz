# 🔌 SSH Disconnection Fix Guide

## 🚨 Problem: Instance Keeps Disconnecting

Your Vast.ai instance disconnects because:

1. **SSH Keepalive Timeout** - SSH drops idle connections after ~60 seconds
2. **Long Provisioning** - The provision script runs for 5-15 minutes without output
3. **Network Instability** - Vast.ai hosts can have intermittent network issues
4. **No Auto-Reconnect** - Old script didn't retry on connection loss

## ✅ Solution: Use the Resilient One-Click Start

### Quick Start

```powershell
# Run the new resilient script
.\one-click-start-resilient.ps1
```

### What It Does

The new script **NEVER GIVES UP**:

✅ **Infinite Retries** - Will keep trying forever until provision completes
✅ **Exponential Backoff** - Smart retry delays (5s → 10s → 20s → 40s → 60s max)
✅ **Connection Monitoring** - Detects disconnections instantly
✅ **Auto-Reconnect** - Reconnects automatically without user intervention
✅ **Progress Tracking** - Shows real-time provision progress
✅ **Error Recovery** - Handles all SSH errors gracefully

### Features

#### 1. SSH Keepalive Options

Every SSH connection uses:
```
-o ServerAliveInterval=30    # Send keepalive every 30 seconds
-o ServerAliveCountMax=3     # Retry 3 times before giving up
-o TCPKeepAlive=yes         # Enable TCP keepalive
-o ConnectTimeout=30        # 30 second connection timeout
-o ConnectionAttempts=3     # Try 3 times to connect
```

#### 2. Infinite Retry Loop

```powershell
# NEVER STOPS - Keeps retrying until success
while ($true) {
    try {
        # Execute SSH command with retries
        $result = Invoke-SSHCommand -MaxRetries 5

        if (-not $result.Success) {
            # Auto-reconnect with exponential backoff
            $backoff = [Math]::Min(60, $delay * 2^$retries)
            Start-Sleep -Seconds $backoff
            continue  # Keep trying!
        }

        # Success - continue monitoring
    }
    catch {
        # Handle error and retry
        Start-Sleep -Seconds 5
        continue
    }
}
```

#### 3. Disconnection Counter

The script tracks how many times it reconnects:
```
⚠️  Connection lost (attempt 1) - Auto-reconnecting in 5s...
⚠️  Connection lost (attempt 2) - Auto-reconnecting in 10s...
⚠️  Connection lost (attempt 3) - Auto-reconnecting in 20s...
✅ Reconnected! (was disconnected 3 times)
```

## 📋 Usage Examples

### Basic Usage

```powershell
# Monitor existing instance
.\one-click-start-resilient.ps1

# Specify instance IP
.\one-click-start-resilient.ps1 -InstanceIP "76.66.207.49"

# Skip provision, just monitor
.\one-click-start-resilient.ps1 -SkipProvision

# Monitor only (don't start provision)
.\one-click-start-resilient.ps1 -MonitorOnly
```

### Advanced: Reconnect Tool

```powershell
# Quick reconnect with SSH keepalive
.\scripts\powershell\reconnect-vastai.ps1 -Interactive

# Show provision logs
.\scripts\powershell\reconnect-vastai.ps1 -ShowLogs

# Check instance status
.\scripts\powershell\reconnect-vastai.ps1 -ShowStatus
```

## 🔧 Technical Details

### SSH Config File (Optional)

Created at `~/.ssh/config_vastai`:

```ssh-config
Host *.vast.ai ssh*.vast.ai 76.66.207.*
    ServerAliveInterval 30
    ServerAliveCountMax 3
    TCPKeepAlive yes
    ConnectionAttempts 3
    ConnectTimeout 30
    Compression yes
    IdentityFile ~/.ssh/id_rsa_vast
    User root
```

To use this config:
```powershell
ssh -F ~/.ssh/config_vastai root@76.66.207.49
```

### Invoke-SSHCommand Function

Smart SSH wrapper with:
- **MaxRetries**: Configurable retry attempts (default: 3)
- **RetryDelay**: Delay between retries (default: 5s)
- **Error Handling**: Captures all errors and retries
- **Output Capture**: Returns both success status and output

```powershell
$result = Invoke-SSHCommand `
    -IP "76.66.207.49" `
    -Command "ls /workspace" `
    -MaxRetries 5 `
    -RetryDelay 10

if ($result.Success) {
    Write-Host $result.Output
} else {
    # Will retry 5 times automatically
}
```

## 🎯 What to Expect

### Normal Operation

```
╔══════════════════════════════════════════════════════════════════╗
║  AI KINGS - Resilient One-Click Start                            ║
╚══════════════════════════════════════════════════════════════════╝

➤ Loading environment variables...
✅ Environment variables loaded

➤ Using instance IP: 76.66.207.49

➤ Testing SSH connection...
✅ SSH connection established

➤ Checking provision status...
✅ Provision is already running

╔══════════════════════════════════════════════════════════════════╗
║  Monitoring Provision Progress                                   ║
╚══════════════════════════════════════════════════════════════════╝

🔄 Auto-reconnect enabled - will NEVER give up!
   (Script will keep retrying forever until provision completes)

[01:05:33] 📦 INSTALLING CUSTOM NODES
[01:05:35] 📥 Cloning ComfyUI-Manager...
[01:05:36] ✅ ComfyUI-Manager cloned
[01:05:37] 📥 Cloning ComfyUI-AnimateDiff-Evolved...
```

### When Disconnection Happens

```
[01:08:22] Downloading models...
⚠️  Connection lost (attempt 1) - Auto-reconnecting in 5s...
   💡 Don't worry! Script will keep trying forever.
⚠️  Connection lost (attempt 2) - Auto-reconnecting in 10s...
✅ Reconnected! (was disconnected 2 times)
[01:08:45] ✅ Models downloaded
```

### When Provision Completes

```
[01:15:33] ✅ All provisioning complete

✅ 🎉 Provision completed successfully!
✅ Total disconnections handled: 5

╔══════════════════════════════════════════════════════════════════╗
║  Final Status                                                    ║
╚══════════════════════════════════════════════════════════════════╝

Disk Usage:
  Used: 45G/600G (8%)

Downloaded Models:
  Count: 127
  Size: 42G

ComfyUI Status:
  ✅ Running

✅ Instance is ready!

Next steps:
  • Connect: ssh root@76.66.207.49
  • Monitor: .\scripts\powershell\reconnect-vastai.ps1 -ShowLogs
  • ComfyUI: http://76.66.207.49:8188
```

## 🐛 Troubleshooting

### Script Won't Connect at All

**Problem**: Cannot establish initial SSH connection

**Solutions**:
1. Check instance is running in Vast.ai console
2. Verify IP address: `76.66.207.49`
3. Test manual SSH: `ssh -v root@76.66.207.49`
4. Check SSH key is registered:
   ```powershell
   node scripts/register_vastai_ssh_key.js
   ```

### Constant Reconnections

**Problem**: Script reconnects every 30-60 seconds

**Cause**: Instance network is unstable or being throttled

**Solutions**:
1. **Destroy and recreate** - Instance host may be flaky
2. **Choose better host** - Filter by reliability score
3. **Check bandwidth** - High network usage can cause throttling

### Provision Stops But Script Keeps Monitoring

**Problem**: Provision failed but script doesn't exit

**Solution**: Press Ctrl+C to stop, then check logs:
```powershell
.\scripts\powershell\reconnect-vastai.ps1 -ShowLogs
```

Look for error messages in the last 100 lines.

## 📊 Comparison: Old vs New

| Feature | Old Script | New Resilient Script |
|---------|-----------|---------------------|
| Auto-reconnect | ❌ No | ✅ Yes (infinite) |
| Keepalive | ❌ No | ✅ Yes (30s) |
| Retry logic | ❌ None | ✅ Exponential backoff |
| Error handling | ❌ Crashes | ✅ Graceful recovery |
| Progress tracking | ❌ None | ✅ Real-time logs |
| Disconnection count | ❌ N/A | ✅ Tracked |
| Manual intervention | ✅ Required | ❌ Not needed |

## 🎓 Best Practices

1. **Always use resilient script** for long-running operations
2. **Monitor in background** - Let it run in a separate terminal
3. **Check logs periodically** using reconnect tool
4. **Don't interrupt** - Let auto-reconnect handle issues
5. **Verify completion** - Wait for success message

## 🔗 Related Files

- [one-click-start-resilient.ps1](../one-click-start-resilient.ps1) - Main resilient script
- [reconnect-vastai.ps1](../scripts/powershell/reconnect-vastai.ps1) - Quick reconnect tool
- [~/.ssh/config_vastai](~/.ssh/config_vastai) - SSH configuration
- [vastai-ssh.js](../lib/vastai-ssh.js) - SSH key management

## 💡 Tips

### Keep Terminal Open

The script runs in your terminal. If you close it, monitoring stops (but provision continues on the instance).

To run in background:
```powershell
# Start in new window that stays open
Start-Process powershell -ArgumentList "-NoExit", "-File", ".\one-click-start-resilient.ps1"
```

### Watch Multiple Instances

Open multiple terminals to monitor multiple instances:
```powershell
# Terminal 1
.\one-click-start-resilient.ps1 -InstanceIP "76.66.207.49"

# Terminal 2
.\one-click-start-resilient.ps1 -InstanceIP "192.168.1.100"
```

### Check Provision Status Anytime

```powershell
# Quick status check (doesn't monitor continuously)
.\scripts\powershell\reconnect-vastai.ps1 -ShowStatus
```

## ✅ Success Indicators

You'll know it's working when:

1. ✅ "Auto-reconnect enabled" appears
2. ✅ Log lines appear with timestamps
3. ✅ Reconnection messages show when network hiccups occur
4. ✅ "Reconnected!" appears after brief disconnections
5. ✅ Final success message with disconnection count

## 🚀 Quick Start Commands

```powershell
# RECOMMENDED: Use resilient script
.\one-click-start-resilient.ps1

# Alternative: Reconnect to running instance
.\scripts\powershell\reconnect-vastai.ps1 -Interactive

# Check what's happening
.\scripts\powershell\reconnect-vastai.ps1 -ShowLogs
```

---

**Remember**: The resilient script **NEVER GIVES UP**. It will keep retrying until the provision completes successfully. You can walk away and it will handle all disconnections automatically! 🎉
