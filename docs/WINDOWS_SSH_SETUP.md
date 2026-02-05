# Windows SSH setup for Vast.ai (quick start) ✅

This repository includes a PowerShell helper to generate a key, register it with Vast.ai, and give you the SSH tunnel command to forward a remote port to your local machine.

## Prereqs
- Windows 10+ with OpenSSH client installed (ssh, ssh-keygen)
- Node.js available in PATH
- Export your Vast.ai API key as `VASTAI_API_KEY` in your environment

## One-line usage
Open PowerShell and run:

```
# Registers key (generates id_vast and id_vast.pub in %USERPROFILE%\.ssh) and prints a tunnel command
powershell -ExecutionPolicy Bypass -File scripts/powershell/register-and-tunnel.ps1
```

To automatically open the tunnel provide host and port and `-AutoOpen`:

```
.\scripts\powershell\register-and-tunnel.ps1 -Host ssh2.vast.ai -Port 20070 -RemotePort 8080 -AutoOpen
```

## Environment variables
- `VASTAI_API_KEY` — required to register the public key with your Vast.ai account
- `VASTAI_SSH_KEY_TYPE` — optional: `ed25519` (default) or `rsa`
- `VASTAI_SSH_KEY_BITS` — optional (when using `rsa`) to set bitlength (default 4096)
- `VASTAI_SSH_KEY_PATH` — optional: override key filename (defaults to `%USERPROFILE%\.ssh\id_vast`)

## Workflow
1. Run the PowerShell helper to generate the key and register it with Vast.ai.
2. Get your instance SSH host/port from the Vast.ai instance SSH panel.
3. Run the printed SSH tunnel command locally (or use `-Host`/`-Port`/`-AutoOpen` to open it automatically).

## Troubleshooting
- If `ssh`/`ssh-keygen` are not found, install Windows OpenSSH client via Optional Features or use WSL.
- If registration fails with HTTP errors, verify `VASTAI_API_KEY` is correct and network connectivity is available.
- If you can’t SSH into an already-running instance after registering, add your public key manually to the instance’s `~/.ssh/authorized_keys` using the web instance console.

---
If you want, I can also add a single PowerShell wrapper to open the tunnel in a new background window or create a Windows shortcut for quick access. Let me know which you'd prefer.