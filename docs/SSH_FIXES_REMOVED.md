# SSH Fixes Removed - Provisioning Restored

## Problem
The provision-reliable.sh script had accumulated multiple SSH-related "enhancements" that were actually breaking the provisioning process:

1. **Screen session wrapper** - Auto-wrapped provisioning in screen to "survive SSH disconnects"
2. **SSH permission fixes** - Called repeatedly during provisioning (fix_ssh_permissions)
3. **Reverse SSH tunnels** - Complex tunnel setup code (start_reverse_tunnel)
4. **SSH disconnect detection** - Cleanup handler tried to preserve state on disconnect
5. **Emergency recovery** - Called fix_ssh_permissions before git operations

## What Was Removed

### 1. Screen Session Auto-Wrapper (Lines 121-159)
**REMOVED**: The entire block that automatically wrapped provisioning in screen
- This was preventing logs from being visible during execution
- Caused the "SSH CONNECTION CAN NOW BE SAFELY CLOSED" message you saw
- Made debugging impossible since logs were hidden in screen session

### 2. SSH Permission Fixes
**REMOVED**: All calls to `fix_ssh_permissions()` function
- Removed from emergency_recovery()
- Removed from git clone retry loops in install_nodes()
- Function still exists but does nothing (safety stub)

### 3. Reverse SSH Tunnel (Lines 3231-3335)
**DISABLED**: Entire start_reverse_tunnel() function replaced with stub
- Complex tunnel negotiation code that could hang
- Not needed for basic Vast.ai provisioning
- All calls to this function removed from start_comfyui()

### 4. SSH Disconnect Detection
**SIMPLIFIED**: Cleanup handler no longer tries to detect SSH disconnects
- Removed exit code 129 (SIGHUP) handling
- Removed screen/tmux session preservation logic
- Now just cleans up on errors, exits cleanly on success

## What Now Works

✅ **Provisioning runs directly** - No screen wrapper hiding output
✅ **Logs visible in real-time** - Stdout/stderr appear immediately  
✅ **Git operations work** - No SSH permission "fixes" breaking git
✅ **Rate limiting handled** - Improved retry logic with backoff
✅ **Clean execution** - Script runs start to finish without SSH complications

## Rate Limiting Fixes (server/warm-pool.js)

Also improved rate limit handling in the Node.js server:

1. **checkInstance()** - Gracefully handles 429 responses, doesn't kill instance
2. **searchBundles()** - Backs off and retries on rate limits
3. **Rent attempts** - Adds 500ms delay between attempts to prevent rapid-fire requests

## SSH Functionality Restored (lib/vastai-ssh.js)

Fixed critical bug where vastai-ssh.js was a duplicate of warm-pool.js (1792 lines!). 
Restored proper SSH utility module with:
- `getKey()` - Get/create SSH keys
- `registerKey()` - Register with Vast.ai API
- `getConnectionString()` - Build SSH connection params
- `sshExec()` - Execute commands via SSH
- `testConnection()` - Test SSH connectivity

## scripts/collect_provision_logs.js

Restored proper log collection script (was also duplicated). Now properly:
- Connects via SSH to instance
- Tails multiple log file locations
- Streams output to local log file
- Handles graceful shutdown
- Integrated with process watchdog for auto-restart

## Usage

The provision script now runs exactly as Vast.ai intended:

```bash
curl -fsSL "https://your-script-url.sh" -o /tmp/provision.sh
chmod +x /tmp/provision.sh  
bash -x /tmp/provision.sh  # Logs visible in real-time
```

No screen wrapper, no SSH fixes, no tunnels - just clean, fast provisioning.