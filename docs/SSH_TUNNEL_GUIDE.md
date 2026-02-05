# SSH Tunnel Guide for Remote AI Agents (Vast.ai ComfyUI)

## Quick Reference

**Connect to ComfyUI:**
```powershell
.\scripts\connect-comfy.ps1 -RemoteHost ssh1.vast.ai -SshPort 13586
```

**Access ComfyUI:** http://localhost:8080

**Close Tunnel:** Press `Ctrl+C` in the PowerShell window

---

## What is SSH Tunneling?

SSH tunneling creates a secure connection between your local machine and a remote server, forwarding network traffic through an encrypted channel. For AI work, this lets you:

- Access remote GPU servers from your local browser
- Keep connections secure and encrypted
- Bypass firewall restrictions
- Use services as if they were running locally

## Architecture

```
Your Browser (localhost:8080)
    ↓
SSH Tunnel (encrypted)
    ↓
Vast.ai Server (ssh1.vast.ai:13586)
    ↓
ComfyUI Server (localhost:8188 on remote)
```

## Prerequisites

1. **SSH Client** (built into Windows 10+)
2. **SSH Key** at `~/.ssh/id_ed25519` (or specify custom path)
3. **Remote Server** running ComfyUI on port 8188
4. **SSH Access** to the remote server

## The connect-comfy.ps1 Script

### Basic Usage

```powershell
# Minimal - opens browser automatically
.\scripts\connect-comfy.ps1 -RemoteHost ssh1.vast.ai -SshPort 13586

# With custom SSH key
.\scripts\connect-comfy.ps1 -RemoteHost ssh1.vast.ai -SshPort 13586 -Key 'C:\Users\you\.ssh\custom_key'

# Don't open browser
.\scripts\connect-comfy.ps1 -RemoteHost ssh1.vast.ai -SshPort 13586 -NoOpen

# Custom local port
.\scripts\connect-comfy.ps1 -RemoteHost ssh1.vast.ai -SshPort 13586 -LocalPort 9000
```

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-RemoteHost` | *required* | SSH host (e.g., ssh1.vast.ai) |
| `-SshPort` | 22 | SSH port number |
| `-User` | root | SSH username |
| `-Key` | `~/.ssh/id_ed25519` | Path to SSH private key |
| `-LocalPort` | 8080 | Local port to access ComfyUI |
| `-RemotePort` | 8188 | Remote port where ComfyUI runs |
| `-NoOpen` | false | Skip auto-opening browser |

## Manual SSH Tunnel Command

If you need to run SSH tunneling manually without the script:

```bash
ssh -p 13586 \
    -i ~/.ssh/id_ed25519 \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    -L 8080:localhost:8188 \
    root@ssh1.vast.ai \
    -N
```

**SSH Options Explained:**
- `-p 13586` - SSH port
- `-i ~/.ssh/id_ed25519` - SSH private key
- `-o StrictHostKeyChecking=no` - Don't ask about host key
- `-o UserKnownHostsFile=/dev/null` - Don't save host key
- `-o ServerAliveInterval=30` - Send keepalive every 30s
- `-o ServerAliveCountMax=3` - Disconnect after 3 failed keepalives
- `-L 8080:localhost:8188` - Forward local 8080 to remote 8188
- `-N` - Don't execute remote commands (tunnel only)

## Troubleshooting

### SSH Connection Fails

**Check SSH key permissions:**
```powershell
# Windows - ensure only you can read the key
icacls C:\Users\you\.ssh\id_ed25519 /inheritance:r /grant:r "%USERNAME%:R"
```

**Test SSH connection:**
```bash
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "echo 'Connection successful'"
```

### Port Already in Use

**Find and kill process using port 8080:**
```powershell
# Find process
netstat -ano | findstr :8080

# Kill process (replace PID with actual number)
taskkill /PID <PID> /F
```

**Or use a different local port:**
```powershell
.\scripts\connect-comfy.ps1 -RemoteHost ssh1.vast.ai -SshPort 13586 -LocalPort 9000
```

### Tunnel Connects but Browser Shows Error

**Check if ComfyUI is running on remote:**
```bash
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "curl -s http://localhost:8188 | head -5"
```

**Check ComfyUI logs:**
```bash
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "tail -50 /workspace/ComfyUI/user/comfyui.log"
```

**Restart ComfyUI:**
```bash
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "cd /workspace/ComfyUI && /venv/main/bin/python3 main.py --listen 0.0.0.0 --port 8188"
```

### Password Prompts in Terminal

When typing passwords in terminals, **characters don't appear** - this is normal security behavior. Just type the password and press Enter.

### Connection Drops

The tunnel includes keepalive settings, but if it still drops:

1. **Check network stability**
2. **Reduce keepalive interval:**
   ```bash
   ssh ... -o ServerAliveInterval=15 ...
   ```
3. **Use tmux/screen on remote** to keep ComfyUI running if SSH disconnects

## Remote Server Management via SSH

### Install Missing ComfyUI Custom Nodes

```bash
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "cd /workspace/ComfyUI/custom_nodes && git clone <node-repo-url>"
```

### Check GPU Status

```bash
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "nvidia-smi"
```

### Monitor ComfyUI in Real-Time

```bash
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "tail -f /workspace/ComfyUI/user/comfyui.log"
```

### Clear Stuck Queue

```bash
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "rm -f /workspace/ComfyUI/user/queue.db*"
```

## Advanced: Multiple Tunnels

You can run multiple tunnels to different services:

```powershell
# Terminal 1 - ComfyUI
.\scripts\connect-comfy.ps1 -RemoteHost ssh1.vast.ai -SshPort 13586 -LocalPort 8080

# Terminal 2 - Jupyter (if running on remote)
ssh -p 13586 -i ~/.ssh/id_ed25519 -L 8888:localhost:8888 root@ssh1.vast.ai -N

# Terminal 3 - SSH terminal session
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai
```

## Security Best Practices

1. **Use SSH keys** instead of passwords
2. **Keep private keys secure** - never share them
3. **Use strong passphrases** for SSH keys (optional but recommended)
4. **Don't commit keys** to git repositories
5. **Rotate keys periodically**

## Performance Tips

1. **Use local browser** - accessing through the tunnel is faster than remote desktop
2. **Close unused tunnels** to free up connections
3. **Monitor bandwidth** - large model downloads will be slower through tunnel
4. **Use compression** for slow connections:
   ```bash
   ssh ... -C ... (add -C flag for compression)
   ```

## Common Vast.ai Commands

### Get Instance SSH Details
```bash
vastai show instances
```

### Stop Instance
```bash
vastai stop instance <instance_id>
```

### Start Instance
```bash
vastai start instance <instance_id>
```

## Integration with Automation

The SSH tunnel can be integrated into automated workflows:

```powershell
# Start tunnel in background
Start-Process powershell -ArgumentList "-File", "scripts\connect-comfy.ps1", "-RemoteHost", "ssh1.vast.ai", "-SshPort", "13586", "-NoOpen" -WindowStyle Hidden

# Your automation script here
# ...

# Close tunnel when done
Get-Process | Where-Object {$_.CommandLine -like "*connect-comfy*"} | Stop-Process
```

## Lessons Learned

### xFormers is NOT Required
- ComfyUI works perfectly with PyTorch attention
- xFormers can cause version conflicts
- "xFormers not available" is just a warning, not an error

### Stuck Checkpoints
- Usually caused by stuck queue database, not xFormers
- Solution: Clear queue with `rm -f /workspace/ComfyUI/user/queue.db*`

### Virtual Environment Issues
- Always install packages in the correct venv: `/venv/main/bin/pip install <package>`
- Global pip installs won't work for ComfyUI

### Port Conflicts
- Always check if ports are in use before starting services
- Use `lsof -ti:<port> | xargs kill -9` to free ports

## Resources

- [ComfyUI Documentation](https://github.com/comfyanonymous/ComfyUI)
- [Vast.ai Documentation](https://vast.ai/docs/)
- [SSH Tunneling Guide](https://www.ssh.com/academy/ssh/tunneling)
- [PowerShell SSH Client](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_overview)

---

**Last Updated:** 2026-02-03
**Author:** AI Assistant
**Version:** 1.0
