# VastAI Disconnection Elimination Guide

**Complete reference for the 7-layer defense system that ensures VastAI instances never disconnect.**

---

## Table of Contents

1. [Overview & Architecture](#overview--architecture)
2. [Layer 1: SSH Connection Resilience](#layer-1-ssh-connection-resilience)
3. [Layer 2: Token Management](#layer-2-token-management)
4. [Layer 3: Port Validation](#layer-3-port-validation)
5. [Layer 4: Connection Monitoring](#layer-4-connection-monitoring)
6. [Layer 5: Adaptive Polling](#layer-5-adaptive-polling)
7. [Layer 6: Process Supervision](#layer-6-process-supervision)
8. [Configuration Reference](#configuration-reference)
9. [Troubleshooting](#troubleshooting)
10. [Monitoring & Health Checks](#monitoring--health-checks)

---

## Overview & Architecture

### Design Philosophy

The system is built on **defense-in-depth** principles: multiple independent layers of protection that work together to prevent disconnections from any cause.

### 7-Layer Defense System

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 7: Process Watchdog - Auto-restart failed daemons    │
├─────────────────────────────────────────────────────────────┤
│ Layer 6: Adaptive Polling - Close detection gaps           │
├─────────────────────────────────────────────────────────────┤
│ Layer 5: Proactive Keepalive - Continuous monitoring       │
├─────────────────────────────────────────────────────────────┤
│ Layer 4: Port Validation - Verify accessibility            │
├─────────────────────────────────────────────────────────────┤
│ Layer 3: Token Validation - Prevent auth failures          │
├─────────────────────────────────────────────────────────────┤
│ Layer 2: SSH Health Monitoring - Detect dead connections   │
├─────────────────────────────────────────────────────────────┤
│ Layer 1: Unlimited SSH Retry - Never give up               │
└─────────────────────────────────────────────────────────────┘
```

### Key Improvements

| Issue | Before | After |
|-------|--------|-------|
| SSH failures | Gave up after 5 attempts | Unlimited retry with backoff |
| Token validation | Never checked | Validated before operations |
| Port accessibility | Assumed working | Tested before use |
| Connection monitoring | Reactive only | Proactive keepalive |
| Polling gaps | 120s always | 30s active, 180s idle |
| Process crashes | Manual restart | Auto-restart with watchdog |

---

## Layer 1: SSH Connection Resilience

### Problem Solved

Log collector terminated after 5 consecutive SSH failures, losing visibility during network hiccups.

### Solution

**File**: [scripts/collect_provision_logs.js](../scripts/collect_provision_logs.js)

#### Unlimited Retry with Exponential Backoff

```javascript
// Line 259: No longer gives up after 5 failures
const maxFailures = parseInt(process.env.SSH_MAX_CONSECUTIVE_FAILURES || '999999', 10);
if (consecutiveFailures >= maxFailures) {
  const backoffMs = Math.min(Math.pow(2, Math.min(consecutiveFailures - maxFailures, 10)) * 1000, 300000);
  await new Promise(r => setTimeout(r, backoffMs)); // Wait and retry
}
```

**Backoff Schedule**: 1s → 2s → 4s → 8s → 16s → 32s → 64s → 128s → 256s → 300s (max)

#### Proactive SSH Health Monitoring

```javascript
// Line 185: Health check every 30 seconds
setInterval(async () => {
  if (!sshClient || sshClient._sock?.destroyed) {
    sshClient = null; // Force reconnect
    return;
  }
  await execSSHCommand('echo "keepalive"', 5000);
}, 30000);
```

### Configuration

```bash
SSH_MAX_CONSECUTIVE_FAILURES=999999      # Effectively unlimited (default)
SSH_READY_TIMEOUT_MS=30000               # 30s connection timeout
SSH_KEEPALIVE_INTERVAL_MS=10000          # 10s keepalive ping
SSH_KEEPALIVE_MAX_MISS=3                 # Disconnect after 3 missed pings
```

### Testing

```powershell
# Kill SSH connection during provisioning
taskkill /F /PID <log-collector-pid>

# Verify: Log shows "backing off" messages with increasing delays
# Verify: Provisioning completes successfully after reconnection
```

---

## Layer 2: Token Management

### Problem Solved

Tokens loaded once at startup but never re-validated, causing silent failures during long operations.

### Solution

**File**: [lib/token-manager.js](../lib/token-manager.js)

#### Centralized Token Validation

```javascript
// Validates all tokens with actual API calls
const results = await tokenManager.validateAll(useCache);

// Results:
{
  vastai: { valid: true, testedAt: '2026-02-02T...' },
  huggingface: { valid: true, user: 'username' },
  civitai: { valid: false, error: 'Token authentication failed (401)' }
}
```

#### Pre-Flight Validation

```javascript
// Line 676 in server/warm-pool.js
// Validates tokens BEFORE renting expensive instances
const tokenValidation = await tokenManager.validateAll(true);
if (tokenValidation.vastai?.valid === false) {
  throw new Error(`VastAI API token invalid`);
}
```

#### Periodic Background Validation

```javascript
// Line 35 in server/vastai-proxy.js
// Validates every 10 minutes
tokenManager.startPeriodicValidation(600000);

tokenManager.on('token-invalid', ({ service, error }) => {
  console.error(`❌ ${service} token validation FAILED: ${error}`);
});
```

### API Endpoints

#### Validate Tokens

```bash
curl -X POST http://localhost:3000/api/proxy/admin/validate-tokens \
  -H "X-Admin-Key: YOUR_ADMIN_KEY"
```

**Response**:
```json
{
  "success": true,
  "validation": {
    "vastai": { "valid": true, "testedAt": "2026-02-02T..." },
    "huggingface": { "valid": true, "user": "username" },
    "civitai": { "valid": true }
  }
}
```

#### Update Token at Runtime

```bash
curl -X POST http://localhost:3000/api/proxy/admin/update-token \
  -H "X-Admin-Key: YOUR_ADMIN_KEY" \
  -H "Content-Type: application/json" \
  -d '{"service": "civitai", "token": "NEW_TOKEN_HERE"}'
```

### Configuration

```bash
TOKEN_VALIDATION_CACHE_MS=300000         # 5min cache (default)
TOKEN_PERIODIC_CHECK_MS=600000           # 10min periodic validation
```

### Testing

```powershell
# Test with invalid token
$env:CIVITAI_TOKEN = "invalid_token"
npm run start

# Verify: Logs show "token validation FAILED"
# Verify: Can update token via API without restart
```

---

## Layer 3: Port Validation

### Problem Solved

Ports detected from VastAI API but never tested for actual accessibility, causing failures on firewalled instances.

### Solution

**File**: [lib/port-validator.js](../lib/port-validator.js)

#### Multi-Layer Port Testing

1. **TCP Socket Test** (5s timeout)
   ```javascript
   const socket = net.Socket();
   socket.connect(port, host);
   // Verifies port is open and accepting connections
   ```

2. **HTTP Endpoint Test** (10s timeout)
   ```javascript
   const response = await fetch(`${url}/system_stats`);
   // Verifies ComfyUI API is responding
   ```

3. **Multi-Candidate Testing**
   - Priority 1: Direct port 8188
   - Priority 2: Mapped port from `8188/tcp`
   - Priority 3: Fallback port from `18188/tcp`

#### Firewall Detection

```javascript
const allPortsBlocked = results.every(r => r.tcpResult && !r.tcpResult.success);
if (allPortsBlocked && results.length >= 2) {
  return { error: 'All ports blocked - firewall detected' };
}
```

### Integration

**File**: [server/warm-pool.js](../server/warm-pool.js) (Line 1326)

```javascript
const validation = await portValidator.validateInstancePorts(inst);

if (validation.success) {
  state.instance.connectionUrl = validation.connectionUrl;
  console.log(`✅ Port ${validation.port} validated and accessible`);
} else {
  console.warn(`⚠️  Port validation failed: ${validation.error}`);
  // Wait for next poll cycle to retry
}
```

### Testing

```bash
# Rent instance with firewall blocking ports
# Verify: Instance stays in "loading" state
# Verify: Logs show "Port validation failed"
# When ports open: Instance automatically transitions to "ready"
```

---

## Layer 4: Connection Monitoring

### Problem Solved

Only reactive health checks when polled. No proactive monitoring for ComfyUI crashes.

### Solution

**File**: [lib/comfyui-keepalive.js](../lib/comfyui-keepalive.js)

#### Proactive ComfyUI Keepalive

```javascript
// Pings /system_stats every 30 seconds
setInterval(async () => {
  const response = await fetch(`${connectionUrl}/system_stats`);

  if (!response.ok) {
    consecutiveFailures++;
    if (consecutiveFailures >= maxConsecutiveFailures) {
      emit('connection-lost'); // Trigger recovery
    }
  }
}, 30000);
```

#### Event-Based Monitoring

```javascript
comfyKeepalive.on('connection-lost', ({ failures, lastError }) => {
  console.error(`❌ ComfyUI connection LOST after ${failures} failures`);
  // Trigger immediate health check
  checkInstance();
});

comfyKeepalive.on('ping-failure', ({ failures, error }) => {
  console.warn(`⚠️  ComfyUI ping failed (${failures} consecutive)`);
});
```

### Configuration

```bash
COMFYUI_KEEPALIVE_INTERVAL_MS=30000      # 30s ping interval (default)
COMFYUI_KEEPALIVE_TIMEOUT_MS=5000        # 5s ping timeout
COMFYUI_KEEPALIVE_MAX_FAILURES=5         # Alert threshold
```

### Monitoring

```javascript
// Get current keepalive status
const status = comfyKeepalive.getStatus();
// Returns: { isRunning, consecutiveFailures, successRate, ... }
```

---

## Layer 5: Adaptive Polling

### Problem Solved

Fixed 120-second polling created long gaps for detecting failures during critical phases.

### Solution

**File**: [server/warm-pool.js](../server/warm-pool.js) (Line 1573)

#### Dynamic Interval Calculation

```javascript
function getPollingInterval() {
  if (!state.instance) return 120000; // 2min when no instance

  const status = state.instance.status;
  const isLeased = state.instance.leasedUntil && Date.now() < new Date(state.instance.leasedUntil).getTime();

  if (status === 'starting' || status === 'loading' || isLeased) {
    return 30000;  // 30s when active
  } else if (status === 'ready') {
    return 180000; // 3min when idle
  } else {
    return 120000; // 2min default
  }
}
```

#### Polling States

| State | Interval | Reason |
|-------|----------|--------|
| No instance | 120s | Low priority |
| Starting | 30s | Critical phase |
| Loading | 30s | Waiting for ComfyUI |
| Ready (leased) | 30s | Active use |
| Ready (idle) | 180s | Save resources |
| Other | 120s | Default |

### Configuration

```bash
WARM_POOL_POLL_ACTIVE_INTERVAL_MS=30000  # 30s when active/leased (default)
WARM_POOL_POLL_IDLE_INTERVAL_MS=180000   # 3min when idle (default)
WARM_POOL_POLL_INTERVAL_MS=120000        # 2min default (default)
```

### Benefits

- **Faster Detection**: Critical phases checked every 30s instead of 120s
- **Resource Efficient**: Idle instances polled every 3 minutes
- **Reduced Gaps**: Maximum detection delay reduced from 120s to 30s during active use

---

## Layer 6: Process Supervision

### Problem Solved

Log collector crashes not auto-recovered, losing provisioning visibility.

### Solution

**File**: [lib/process-watchdog.js](../lib/process-watchdog.js)

#### Automatic Restart

```javascript
// Register process with watchdog
processWatchdog.register('log-collector-123', {
  name: 'LogCollector-123',
  command: 'node',
  args: ['scripts/collect_provision_logs.js', ...],
  maxRestarts: -1,        // Unlimited
  restartDelay: 10000     // 10s base delay
});

// Watchdog monitors PID health every 30s
// Auto-restarts on crash with exponential backoff
```

#### Exponential Backoff

**Backoff Schedule** (for rapid crashes):
- 1st crash: 10s delay
- 2nd crash: 20s delay
- 3rd crash: 40s delay
- 4th+ crash: 60s delay (max)

Stable runs (>60s runtime) reset the backoff counter.

#### Event Monitoring

```javascript
processWatchdog.on('process-restarted', ({ id, restartCount, consecutiveCrashes }) => {
  console.log(`Restarted ${id} (attempt ${restartCount}, ${consecutiveCrashes} crashes)`);
});

processWatchdog.on('process-failed', ({ id, restartCount }) => {
  console.error(`Process ${id} FAILED after ${restartCount} restarts`);
});
```

### Health Monitoring

```javascript
// Health check every 30 seconds
setInterval(() => {
  for (const [id, entry] of processes.entries()) {
    try {
      process.kill(pid, 0); // Check if alive (signal 0 doesn't kill)
    } catch {
      // Process is dead - restart it
      startProcess(id);
    }
  }
}, 30000);
```

### Testing

```powershell
# Kill log collector process
taskkill /F /PID <pid>

# Verify: Watchdog restarts process within 10 seconds
# Verify: Logs show "Restarted log-collector"
# Kill again: Verify exponential backoff (10s, 20s, 40s)
```

---

## Configuration Reference

### Complete Environment Variables

```bash
# ═══════════════════════════════════════════════════════════════
# SSH CONNECTION RESILIENCE
# ═══════════════════════════════════════════════════════════════
SSH_MAX_CONSECUTIVE_FAILURES=999999      # SSH retry limit (effectively unlimited)
SSH_READY_TIMEOUT_MS=30000               # 30s connection timeout
SSH_KEEPALIVE_INTERVAL_MS=10000          # 10s keepalive ping
SSH_KEEPALIVE_MAX_MISS=3                 # Disconnect after 3 missed pings

# ═══════════════════════════════════════════════════════════════
# TOKEN MANAGEMENT
# ═══════════════════════════════════════════════════════════════
TOKEN_VALIDATION_CACHE_MS=300000         # 5min cache duration
TOKEN_PERIODIC_CHECK_MS=600000           # 10min periodic validation interval

# ═══════════════════════════════════════════════════════════════
# CONNECTION MONITORING
# ═══════════════════════════════════════════════════════════════
COMFYUI_KEEPALIVE_INTERVAL_MS=30000      # 30s ping interval
COMFYUI_KEEPALIVE_TIMEOUT_MS=5000        # 5s ping timeout
COMFYUI_KEEPALIVE_MAX_FAILURES=5         # Alert after 5 consecutive failures

# ═══════════════════════════════════════════════════════════════
# ADAPTIVE POLLING
# ═══════════════════════════════════════════════════════════════
WARM_POOL_POLL_ACTIVE_INTERVAL_MS=30000  # 30s when starting/loading/leased
WARM_POOL_POLL_IDLE_INTERVAL_MS=180000   # 3min when ready but idle
WARM_POOL_POLL_INTERVAL_MS=120000        # 2min default fallback
```

### Recommended Production Values

```bash
# High-reliability configuration (recommended)
SSH_MAX_CONSECUTIVE_FAILURES=999999
SSH_KEEPALIVE_INTERVAL_MS=10000
COMFYUI_KEEPALIVE_INTERVAL_MS=30000
WARM_POOL_POLL_ACTIVE_INTERVAL_MS=30000
WARM_POOL_POLL_IDLE_INTERVAL_MS=180000
```

### Conservative Configuration

```bash
# Reduce network traffic and API calls
SSH_KEEPALIVE_INTERVAL_MS=30000          # Less frequent SSH keepalive
COMFYUI_KEEPALIVE_INTERVAL_MS=60000      # Ping every 60s
WARM_POOL_POLL_ACTIVE_INTERVAL_MS=60000  # Poll every 60s when active
WARM_POOL_POLL_IDLE_INTERVAL_MS=300000   # Poll every 5min when idle
```

---

## Troubleshooting

### SSH Connection Issues

**Symptom**: Log collector shows "backing off" messages

**Diagnosis**:
```bash
# Check SSH connectivity
ssh -p <PORT> -i ~/.ssh/id_rsa_vast root@<SSH_HOST> echo "test"

# Verify SSH key
cat ~/.ssh/id_rsa_vast.pub
```

**Solutions**:
- Verify SSH key is registered with VastAI
- Check firewall rules allow SSH port
- Increase `SSH_READY_TIMEOUT_MS` if connection is slow
- Check logs for specific SSH errors

### Token Validation Failures

**Symptom**: Logs show "token validation FAILED"

**Diagnosis**:
```bash
# Test VastAI token
curl -H "Authorization: Bearer $VASTAI_API_KEY" \
  https://console.vast.ai/api/v0/instances/

# Test HuggingFace token
curl -H "Authorization: Bearer $HUGGINGFACE_HUB_TOKEN" \
  https://huggingface.co/api/whoami-v2

# Test Civitai token
curl "https://civitai.com/api/v1/models?token=$CIVITAI_TOKEN&limit=1"
```

**Solutions**:
- Regenerate tokens from service websites
- Update tokens via API: `POST /api/proxy/admin/update-token`
- Check tokens in `.env` file are not truncated or wrapped

### Port Validation Failures

**Symptom**: "Port validation failed" in logs, instance stuck in "loading"

**Diagnosis**:
```powershell
# Test TCP connectivity
Test-NetConnection -ComputerName <IP> -Port 8188

# Test HTTP endpoint
curl http://<IP>:8188/system_stats
```

**Solutions**:
- Wait 2-3 minutes for ComfyUI to fully start
- Check VastAI instance firewall rules
- Verify port mappings in VastAI console
- Try alternative ports (18188)

### Keepalive Connection Loss

**Symptom**: "ComfyUI connection LOST" alerts

**Diagnosis**:
```bash
# Check ComfyUI is running
curl http://<IP>:8188/system_stats

# Check ComfyUI logs
ssh ... "tail -100 /workspace/comfyui.log"
```

**Solutions**:
- ComfyUI may have crashed - check remote logs
- Network instability - verify connection to IP
- Increase `COMFYUI_KEEPALIVE_MAX_FAILURES` threshold
- Check GPU memory - ComfyUI OOM can cause crashes

---

## Monitoring & Health Checks

### System Health Dashboard

```javascript
// Get warm pool status
GET /api/proxy/admin/warm-pool/status

// Returns:
{
  "desiredSize": 1,
  "instance": {
    "contractId": "12345",
    "status": "ready",
    "connectionUrl": "http://1.2.3.4:8188",
    "lastHeartbeat": "2026-02-02T...",
    "leasedUntil": null
  },
  "isPrewarming": false,
  "safeMode": false
}
```

### Token Validation Status

```bash
# Validate all tokens
POST /api/proxy/admin/validate-tokens

# Returns:
{
  "success": true,
  "validation": {
    "vastai": { "valid": true, "testedAt": "..." },
    "huggingface": { "valid": true, "user": "username" },
    "civitai": { "valid": true }
  }
}
```

### ComfyUI Keepalive Status

```javascript
// Get keepalive status
const status = comfyKeepalive.getStatus();

// Returns:
{
  "isRunning": true,
  "consecutiveFailures": 0,
  "lastSuccessTime": "2026-02-02T...",
  "totalPings": 1234,
  "totalSuccesses": 1230,
  "totalFailures": 4,
  "successRate": "99.68%"
}
```

### Process Watchdog Status

```javascript
// Get all supervised processes
const status = processWatchdog.getStatus();

// Returns:
{
  "log-collector-12345": {
    "name": "LogCollector-12345",
    "pid": 67890,
    "status": "running",
    "restartCount": 3,
    "consecutiveCrashes": 0,
    "lastStartTime": "2026-02-02T...",
    "lastCrashTime": null,
    "lastError": null
  }
}
```

### Log Monitoring

**Key Log Messages**:

```
✅ Port 8188 (direct) validated and accessible
✅ vastai token validated successfully
✅ civitai token validated successfully
[Keepalive] Starting ComfyUI connection monitoring
[Watchdog] Registered process: LogCollector-12345
[Polling] Starting adaptive polling loop
```

**Warning Messages**:

```
⚠️  Port validation failed: TCP connection timeout
⚠️  Civitai token invalid: Token authentication failed (401)
⚠️  ComfyUI ping failed (3 consecutive): HTTP 503
[LogCollector] 10 consecutive failures, backing off 32s before retry
```

**Error Messages**:

```
❌ vastai token validation FAILED: Token authentication failed (401)
❌ ComfyUI connection LOST after 5 failures: Connection timeout
[Watchdog] Process LogCollector-12345 FAILED after 100 restarts
```

---

## Success Metrics

After implementing all 7 layers, you should see:

✅ **Zero unexpected disconnections** - No SSH/connection failures that don't auto-recover
✅ **100% token validation** - All operations use validated tokens
✅ **100% port validation** - All "ready" instances have accessible ports
✅ **<150s failure detection** - Connection loss detected within 2.5 minutes
✅ **>99.9% daemon uptime** - Log collectors restart successfully on crash
✅ **30s active polling** - Responsive during critical phases
✅ **180s idle polling** - Resource-efficient when idle

---

## Summary

The 7-layer defense system provides comprehensive protection against all known disconnection vectors:

1. **SSH**: Never gives up (unlimited retry with backoff)
2. **Tokens**: Validated before use, monitored continuously
3. **Ports**: Tested for actual accessibility before marking ready
4. **Keepalive**: Proactive monitoring detects failures early
5. **Polling**: Adaptive intervals close detection gaps
6. **Watchdog**: Auto-restarts critical processes on crash
7. **Monitoring**: Event-based alerting for all failure modes

Every component is independently testable, configurable, and can be disabled without breaking existing functionality. The result is a system that **never gives up** on maintaining connectivity to VastAI instances.
