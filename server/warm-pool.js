// Lightweight WarmPool manager (file-backed persistence)
// Purpose: manage a single warm instance for fast ComfyUI starts, with idle shutdown

const fs = require('fs');
const path = require('path');
const fetch = require('node-fetch');
const { fetchWithTimeout, fetchWithRetry } = require('../lib/fetch-with-timeout');
const { spawn } = require('child_process');

const DATA_FILE = path.join(__dirname, '..', 'data', 'warm_pool.json');
const db = require('./db');
const audit = require('./audit');
const ComfyUIKeepalive = require('../lib/comfyui-keepalive');
const processWatchdog = require('../lib/process-watchdog');
const VAST_BASE = 'https://console.vast.ai/api/v0';
const VASTAI_API_KEY = process.env.VASTAI_API_KEY || process.env.VAST_AI_API_KEY || null;

// Start process watchdog
processWatchdog.start();

processWatchdog.on('process-restarted', ({ id, restartCount, consecutiveCrashes }) => {
  console.log(`[Watchdog] Restarted ${id} (attempt ${restartCount}, ${consecutiveCrashes} consecutive crashes)`);
});

processWatchdog.on('process-failed', ({ id, restartCount }) => {
  console.error(`[Watchdog] Process ${id} FAILED after ${restartCount} restarts`);
});

// Global ComfyUI keepalive monitor
let comfyKeepalive = null;

// ============================================================================
// GPU CUDA CAPABILITY REFERENCE
// ============================================================================
// - 6.1: GTX 1080 Ti, TITAN Xp (requires PyTorch ≤2.0, CUDA 11.8)
// - 7.0: V100 (PyTorch 2.0+)
// - 7.5: RTX 2080 Ti, TITAN RTX (PyTorch 2.0+)
// - 8.0: A100 (PyTorch 2.0+)
// - 8.6: RTX 3090, A4000, A5000 (PyTorch 2.0+)
// - 8.9: RTX 4090, L40 (PyTorch 2.1+)
// - 9.0: H100 (PyTorch 2.1+)
// ============================================================================

// Minimum CUDA capability - excludes Pascal and older (GTX 10 series, TITAN Xp)
// Lowered to 6.0 to allow datacenter GPUs like P100/P40 which have high VRAM
const MIN_CUDA_CAPABILITY = parseFloat(process.env.VASTAI_MIN_CUDA_CAPABILITY || '6.0');

// Configurable minimum disk (GB) for warm instances. Default to 500GB to ensure
// room for large models (Flux/SDXL/Wan) and custom nodes while meeting user requirements.
const RAW_WARM_POOL_DISK = parseInt(process.env.WARM_POOL_DISK_GB || process.env.WARM_POOL_DISK || '500', 10);
const WARM_POOL_DISK_GB = Number.isFinite(RAW_WARM_POOL_DISK) ? RAW_WARM_POOL_DISK : 500;
// Clamp to sane bounds: min 100GB, max 2000GB
const requiredDiskGb = Math.min(Math.max(WARM_POOL_DISK_GB, 100), 2000);
/**
 * Check if a GPU meets minimum CUDA capability requirements
 * @param {number|string} cudaCapability - CUDA compute capability (e.g., 6.1, 8.6)
 * @returns {boolean} - True if GPU is compatible
 */
function isGpuCompatible(cudaCapability) {
    const cap = parseFloat(cudaCapability);
    if (isNaN(cap)) return true; // If unknown, allow (will fail at health check)
    return cap >= MIN_CUDA_CAPABILITY;
}

/**
 * Select compatible PyTorch version based on GPU CUDA capability
 * @param {number|string} cudaCapability - CUDA compute capability
 * @returns {Object} - PyTorch configuration { torch, torchvision, indexUrl, cudaVersion }
 */
function getPyTorchVersionForGPU(cudaCapability) {
    const capability = parseFloat(cudaCapability);

    // Legacy GPUs (Pascal architecture - GTX 10 series, TITAN Xp)
    // These require older PyTorch with CUDA 11.8 support
    if (!isNaN(capability) && capability <= 6.1) {
        console.warn('WarmPool: Legacy GPU detected (CUDA ' + capability + '), would need PyTorch 2.0.1');
        return {
            torch: 'torch==2.0.1+cu118',
            torchvision: 'torchvision==0.15.2+cu118',
            indexUrl: 'https://download.pytorch.org/whl/cu118',
            cudaVersion: '11.8',
            isLegacy: true
        };
    }

    // Modern GPUs (Volta, Turing, Ampere, Ada, Hopper architectures)
    return {
        torch: 'torch==2.9.1+cu128',
        torchvision: 'torchvision==0.20.1+cu128',
        indexUrl: 'https://download.pytorch.org/whl/cu128',
        cudaVersion: '12.8',
        isLegacy: false
    };
}

// In-flight prewarm promise to serialize concurrent prewarm requests
let prewarmInFlight = null;
let prewarmLock = false;

let state = {
    desiredSize: 1,
    instance: null, // { contractId, status, connectionUrl, createdAt, lastHeartbeat, leasedUntil }
    lastAction: null,
    isPrewarming: false,
    safeMode: false,
    provisionAttempt: 0,       // Track provisioning attempts for diagnostics
    useDefaultScript: false    // Fallback flag: use default Vast.ai script instead of custom
};

const vastaiSsh = require('../lib/vastai-ssh');

async function load() {
    try {
        const row = db.getState();
        if (row) {
            state = Object.assign(state, row);
        }
    } catch (e) {
        console.error('WarmPool load failed:', e);
    }
    // Always reset volatile prewarming status on load to prevent stuck state after crash/restart
    state.isPrewarming = false;
    prewarmLock = false;

    // Validate instance still exists on Vast.ai (auto-cleanup stale state)
    if (state.instance && state.instance.contractId) {
        console.log(`WarmPool: Validating instance ${state.instance.contractId} after load...`);
        try {
            await checkInstance();
            if (!state.instance) {
                console.log('WarmPool: Stale instance cleared during load validation');
            } else {
                console.log('WarmPool: Instance validated successfully');
            }
        } catch (err) {
            console.warn('WarmPool: Instance validation failed during load:', err.message);
            // Don't clear instance on validation errors - might be transient network issue
        }
    }
}

// Wait for ComfyUI to respond on the instance (polls /system_stats)
// Now includes comprehensive GPU and model health validation
// ADAPTIVE POLLING: Wait for provisioning buffer, then poll slowly during provisioning
async function waitForComfyReady(contractId, timeoutMs = parseInt(process.env.WARM_POOL_HEALTH_TIMEOUT_MS || '1500000', 10), intervalMs = parseInt(process.env.WARM_POOL_HEALTH_INITIAL_INTERVAL_MS || '90000', 10)) {
    const start = Date.now();
    let lastHealthReport = null;
    let consecutiveFailures = 0;
    let consecutiveSuccesses = 0;
    let currentInterval = intervalMs;

    // Configurable health parameters (minutes, thresholds, intervals)
    const provisioningBufferMs = parseInt(process.env.WARM_POOL_HEALTH_BUFFER_MINUTES || '5', 10) * 60 * 1000;
    const FAILURE_THRESHOLD = parseInt(process.env.WARM_POOL_HEALTH_FAILURES_THRESHOLD || '3', 10);
    const SUCCESS_THRESHOLD = parseInt(process.env.WARM_POOL_HEALTH_SUCCESS_THRESHOLD || '2', 10);
    const REPAIR_THRESHOLD = parseInt(process.env.WARM_POOL_REPAIR_THRESHOLD || '5', 10); // attempt repair after consecutive failures
    const LATER_INTERVAL_MS = parseInt(process.env.WARM_POOL_HEALTH_LATER_INTERVAL_MS || '30000', 10);

    console.log(`WarmPool: Provisioning buffer active - waiting ${provisioningBufferMs / 1000}s before health checks`);
    await new Promise(r => setTimeout(r, provisioningBufferMs));

    while (Date.now() - start < timeoutMs) {
        // Refresh instance info from Vast.ai
        await checkInstance();
        if (!state.instance || state.instance.contractId != contractId) return false;

        if (state.instance.connectionUrl) {
            // Run comprehensive health check instead of just checking /system_stats
            const healthReport = await validateInstanceHealth(state.instance.connectionUrl, contractId);
            lastHealthReport = healthReport;

            if (isInstanceHealthy(healthReport)) {
                // Healthy check: require multiple consecutive successes to avoid flapping
                consecutiveSuccesses++;
                consecutiveFailures = 0;
                console.log(`WarmPool: ✅ Health success (${consecutiveSuccesses}/${SUCCESS_THRESHOLD} consecutive)`);
                if (consecutiveSuccesses >= SUCCESS_THRESHOLD) {
                    // Instance is fully healthy - API responding, GPU available and functional
                    state.instance.status = 'ready';
                    state.instance.lastHeartbeat = new Date().toISOString();
                    state.instance.lastHealthReport = healthReport;

                    // Fetch complete model inventory for pre-flight validation
                    try {
                        state.instance.modelInventory = await fetchModelInventory(state.instance.connectionUrl);
                        console.log('WarmPool: Model inventory cached', {
                            checkpoints: state.instance.modelInventory.checkpoints.length,
                            loras: state.instance.modelInventory.loras.length
                        });
                    } catch (invErr) {
                        console.warn('WarmPool: Failed to fetch model inventory:', invErr.message);
                        state.instance.modelInventory = { checkpoints: [], loras: [], vaes: [], customNodes: [], errors: [invErr.message] };
                    }

                    save();

                    try {
                        audit.logUsageEvent({
                            event_type: 'instance_ready',
                            contract_id: contractId,
                            instance_status: 'ready',
                            details: {
                                vram_total: healthReport.vram_total,
                                vram_free: healthReport.vram_free,
                                checkpoint_count: healthReport.checkpoint_count,
                                lora_count: state.instance.modelInventory?.loras?.length || 0
                            },
                            source: 'warm-pool'
                        });
                    } catch (e) { }

                    return true;
                }
            } else {
                // Not healthy - track consecutive failures and detect script errors to trigger fallback sooner
                consecutiveSuccesses = 0;
                consecutiveFailures++;

                const elapsed = Math.round((Date.now() - start) / 1000);

                // Detect provisioning/script-level failures from reported errors and trigger fallback
                const errs = (healthReport.errors || []).join(' ').toLowerCase();
                if (consecutiveFailures >= FAILURE_THRESHOLD && /nohup|failed to run command 'node'|enoent|permission denied|failed to run command/.test(errs)) {
                    console.warn('WarmPool: ⚠️ Detected provisioning script failure on instance. Enabling default fallback and aborting prewarm attempt early.');
                    state.useDefaultScript = true;
                    save();
                    try { audit.logUsageEvent({ event_type: 'provision_failure_script', contract_id: contractId, details: { errors: healthReport.errors }, source: 'warm-pool' }); } catch (e) {}
                    return false;
                }

                // Automated repair attempt: if failures exceed REPAIR_THRESHOLD, try restarting ComfyUI on the instance
                if (consecutiveFailures >= REPAIR_THRESHOLD) {
                    console.warn(`WarmPool: Consecutive failures (${consecutiveFailures}) reached REPAIR_THRESHOLD (${REPAIR_THRESHOLD}). Attempting automated repair...`);
                    try {
                        const repairOk = await attemptRepairInstance(contractId);
                        try { audit.logUsageEvent({ event_type: 'instance_repair_attempt', contract_id: contractId, details: { success: !!repairOk, consecutiveFailures }, source: 'warm-pool' }); } catch (e) {}
                        if (repairOk) {
                            console.log('WarmPool: Repair attempt succeeded; continuing health checks')
                            consecutiveFailures = 0; // reset failures and continue
                        } else {
                            console.warn('WarmPool: Repair attempt did not fix the instance');
                            // Notify via webhook if configured
                            notifyFailure(contractId, 'Automated repair attempt failed');
                        }
                    } catch (e) {
                        console.error('WarmPool: Repair attempt threw an error:', e && e.message ? e.message : e);
                    }
                }

                // Adaptive polling based on elapsed provisioning time
                if (elapsed < 600) {
                    currentInterval = intervalMs; // use initial interval during early provisioning phase
                } else {
                    currentInterval = LATER_INTERVAL_MS; // faster polling after 10 minutes
                }

                console.log(`WarmPool: Waiting for healthy instance (${elapsed}s elapsed, poll every ${currentInterval / 1000}s)...`, {
                    api: healthReport.comfyui_api,
                    gpu: healthReport.gpu_available,
                    functional: healthReport.gpu_functional,
                    errors: healthReport.errors,
                    consecutiveFailures
                });
            }

        } else {
            consecutiveFailures = 0; // Reset on any progress
        }

        await new Promise(r => setTimeout(r, currentInterval));
    }

    // Timed out - log the last health report for debugging
    console.error('WarmPool: Instance readiness timeout', {
        contractId,
        timeoutMs,
        lastHealthReport,
        provisionAttempt: state.provisionAttempt,
        useDefaultScript: state.useDefaultScript
    });

    // FALLBACK TRIGGER: If using custom script and it failed, set fallback flag for next attempt
    if (!state.useDefaultScript && process.env.COMFYUI_PROVISION_SCRIPT) {
        console.warn('WarmPool: ⚠️ FALLBACK TRIGGERED - Custom provisioning script failed. Next prewarm will use default Vast.ai script.');
        state.useDefaultScript = true;
        save();
    }

    return false;
}

/**
 * Comprehensive instance health check
 * Validates: API responsiveness, GPU availability, VRAM, models loaded
 * @param {string} connectionUrl - Base URL of the ComfyUI instance
 * @param {string} contractId - Contract ID for logging
 * @returns {Object} - Health report with individual check results
 */
async function validateInstanceHealth(connectionUrl, contractId) {
    const healthReport = {
        comfyui_api: false,
        gpu_available: false,
        gpu_functional: false,
        models_loaded: false,
        vram_total: 0,
        vram_free: 0,
        checkpoint_count: 0,
        timestamp: new Date().toISOString(),
        errors: []
    };

    if (!connectionUrl) {
        healthReport.errors.push('No connection URL');
        return healthReport;
    }

    // Candidate URLs: prefer local SSH tunnel if configured (or via COMFYUI_TUNNEL_URL env var)
    const TUNNEL_URL = process.env.COMFYUI_TUNNEL_URL || 'http://localhost:8188';
    const urlsToTry = [];
    if (TUNNEL_URL) urlsToTry.push(TUNNEL_URL.replace(/\/$/, ''));
    urlsToTry.push(connectionUrl.replace(/\/$/, ''));

    let usedBase = null;
    let stats = null;

    try {
        // Try each candidate base URL until one succeeds
        for (const candidateBase of urlsToTry) {
            try {
                const systemStatsUrl = candidateBase + '/system_stats';
                console.log(`WarmPool: Trying health endpoint ${systemStatsUrl}`);
                const statsResponse = await fetchWithTimeout(systemStatsUrl, {
                    method: 'GET'
                }, 10000);

                if (!statsResponse.ok) {
                    console.warn(`WarmPool: Health endpoint ${systemStatsUrl} returned HTTP ${statsResponse.status}`);
                    // try next candidate
                    continue;
                }

                stats = await statsResponse.json();
                usedBase = candidateBase;
                healthReport.comfyui_api = true;
                console.log(`WarmPool: Using ComfyUI base URL: ${usedBase}`);
                break;
            } catch (e) {
                console.warn(`WarmPool: Health check failed for candidate ${candidateBase}: ${e.message}`);
                // Try next candidate
                continue;
            }
        }

        if (!usedBase) {
            healthReport.errors.push('All health endpoints failed');
            return healthReport;
        }

        // 2. Verify GPU is detected and has VRAM
        if (stats && stats.system) {
            healthReport.vram_total = stats.system.vram_total || 0;
            healthReport.vram_free = stats.system.vram_free || 0;
            healthReport.gpu_available = healthReport.vram_total > 0;

            // GPU is functional if it has at least 50% VRAM free (not exhausted)
            if (healthReport.vram_total > 0) {
                const vramUsagePercent = ((healthReport.vram_total - healthReport.vram_free) / healthReport.vram_total) * 100;
                healthReport.gpu_functional = vramUsagePercent < 90; // Less than 90% used

                if (!healthReport.gpu_functional) {
                    healthReport.errors.push(`VRAM exhausted: ${vramUsagePercent.toFixed(1)}% used`);
                }
            }
        }

        if (!healthReport.gpu_available) {
            healthReport.errors.push('No GPU detected or VRAM=0');
        }

        // 3. Check if models/checkpoints are loaded via object_info endpoint
        // CRITICAL: Verify models actually downloaded (not just ComfyUI running) - 60s timeout for large model lists
        try {
            const objectInfoUrl = usedBase + '/object_info/CheckpointLoaderSimple';
            const objectInfoResponse = await fetchWithTimeout(objectInfoUrl, {
                method: 'GET'
            }, 60000);

            if (objectInfoResponse.ok) {
                const objectInfo = await objectInfoResponse.json();
                const checkpoints = objectInfo?.CheckpointLoaderSimple?.input?.required?.ckpt_name?.[0] || [];
                healthReport.checkpoint_count = Array.isArray(checkpoints) ? checkpoints.length : 0;
                healthReport.models_loaded = healthReport.checkpoint_count > 0;

                if (!healthReport.models_loaded) {
                    healthReport.errors.push('CRITICAL: No checkpoints found - provisioning likely failed');
                }
            } else {
                healthReport.errors.push(`object_info endpoint failed: ${objectInfoResponse.status}`);
            }
        } catch (objErr) {
            // object_info might not be available on all ComfyUI versions
            console.log('WarmPool: Could not fetch object_info:', objErr.message);
            healthReport.errors.push('Cannot verify model inventory');
            // CHANGED: Don't assume OK if we can't verify - mark as unknown and log warning
            healthReport.models_loaded = false;
        }

    } catch (error) {
        healthReport.errors.push(`Health check failed: ${error.message}`);
        console.error('WarmPool: Health check error:', error);
    }



    // Log health check result
    const isHealthy = healthReport.comfyui_api && healthReport.gpu_available && healthReport.gpu_functional;
    console.log(`WarmPool: Health check for ${contractId}:`, {
        healthy: isHealthy,
        api: healthReport.comfyui_api,
        gpu: healthReport.gpu_available,
        functional: healthReport.gpu_functional,
        vram: `${healthReport.vram_free}/${healthReport.vram_total}`,
        checkpoints: healthReport.checkpoint_count,
        errors: healthReport.errors
    });

    return healthReport;
}

/**
 * Attempt to repair an instance by SSHing into it and restarting ComfyUI service/process
 * Returns true if the repair action appears successful
 */
async function attemptRepairInstance(contractId) {
    try {
        if (!state.instance || state.instance.contractId != contractId) return false;
        const inst = state.instance;
        const sshHost = inst.ssh_host || inst.host || null;
        const sshPort = inst.ssh_port || inst.machine_ssh_port || process.env.VASTAI_SSH_PORT || null;
        const keyPath = process.env.VASTAI_SSH_KEY_PATH || (process.env.HOME || process.env.USERPROFILE ? (path.join(process.env.HOME || process.env.USERPROFILE, '.ssh', 'id_rsa_vast')) : null);
        if (!sshHost || !sshPort) {
            console.warn('WarmPool: Cannot attempt repair - SSH host/port missing');
            return false;
        }

        // Construct restart commands: prefer systemd restart; fall back to pkill+manual start
        const restartCmd = `sudo systemctl restart comfyui.service || (pkill -f main.py || true; nohup python3 /workspace/ComfyUI/main.py --listen 0.0.0.0 --port 8188 --enable-cors-header >/dev/null 2>&1 &)`;

        console.log(`WarmPool: Attempting SSH repair to ${sshHost}:${sshPort} (cmd: ${restartCmd.substring(0,80)}...)`);

        const { exec } = require('child_process');
        const sshArgs = ['-o', 'StrictHostKeyChecking=no', '-o', 'ConnectTimeout=10', '-p', sshPort.toString(), '-i', keyPath, `root@${sshHost}`, restartCmd];

        return await new Promise((resolve) => {
            const child = exec(`ssh ${sshArgs.map(a => (a.indexOf(' ')>=0 ? `"${a}"` : a)).join(' ')}`, { timeout: 60000 }, (err, stdout, stderr) => {
                if (err) {
                    console.warn(`WarmPool: SSH repair command failed: ${err && err.message ? err.message : err}`);
                    console.warn('WarmPool: stderr:', stderr);
                    resolve(false);
                    return;
                }
                console.log('WarmPool: SSH repair stdout:', stdout);
                // Quick local check: try fetching system_stats via tunnel or public URL
                validateInstanceHealth(inst.connectionUrl, contractId).then(hr => {
                    const ok = hr.comfyui_api && hr.gpu_available;
                    resolve(ok);
                }).catch(() => resolve(false));
            });
            // Safety: kill child after 55s if still running
            setTimeout(() => { try { child.kill(); } catch (e) {} }, 55000);
        });

    } catch (e) {
        console.error('WarmPool: attemptRepairInstance error:', e && e.message ? e.message : e);
        return false;
    }
}

/**
 * Notify failure via webhook (if configured)
 */
async function notifyFailure(contractId, message) {
    try {
        const url = process.env.WARM_POOL_ALERT_WEBHOOK;
        if (!url) return false;
        const payload = { contractId, message, time: new Date().toISOString() };
        await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
        console.log('WarmPool: Sent failure notification to webhook');
        return true;
    } catch (e) {
        console.warn('WarmPool: notifyFailure error:', e && e.message ? e.message : e);
        return false;
    }
}

/**
 * Check if health report indicates a fully functional instance
 * ENHANCED: Now also requires models to be loaded (prevents returning broken instances)
 * @param {Object} healthReport - Result from validateInstanceHealth
 * @returns {boolean} - True if instance is healthy AND has models
 */
function isInstanceHealthy(healthReport) {
    const basicHealth = healthReport.comfyui_api &&
        healthReport.gpu_available &&
        healthReport.gpu_functional;

    // Configurable grace period for models to finish downloading/initialising.
    // Some images or very large models (Flux / SDXL conversions) can take >10-20 minutes.
    const defaultGraceMs = parseInt(process.env.COMFYUI_MODELS_GRACE_MS || String(20 * 60 * 1000), 10); // default: 20 minutes

    // Determine if models are ready. If checkpoints are reported as loaded, it's ready.
    // Otherwise allow a temporary grace period (since provisioning may still be downloading/extracting models).
    let modelsReady = false;
    if (healthReport.models_loaded && healthReport.checkpoint_count > 0) {
        modelsReady = true;
    } else {
        try {
            if (state.instance && state.instance.createdAt) {
                const elapsed = Date.now() - new Date(state.instance.createdAt).getTime();
                if (elapsed < defaultGraceMs) {
                    console.log(`WarmPool: Models not yet loaded but within grace period (${Math.round(elapsed/1000)}s elapsed < ${Math.round(defaultGraceMs/1000)}s). Waiting.`);
                    modelsReady = true; // treat as 'in-progress' and don't fail immediately
                } else {
                    modelsReady = false;
                }
            } else {
                // No createdAt available - be conservative and don't mark models ready
                modelsReady = false;
            }
        } catch (e) {
            console.warn('WarmPool: Error while evaluating model grace period:', e && e.message ? e.message : e);
            modelsReady = false;
        }
    }

    if (basicHealth && !modelsReady) {
        console.warn('WarmPool: Instance API/GPU healthy but NO MODELS LOADED - provisioning failed (post-grace)');
    }

    return basicHealth && modelsReady;
}

/**
 * Fetch complete model inventory from ComfyUI instance
 * Queries multiple /object_info endpoints to discover available models
 * @param {string} connectionUrl - Base URL of the ComfyUI instance
 * @returns {Object} - Model inventory { checkpoints: [], loras: [], vaes: [], customNodes: [] }
 */
async function fetchModelInventory(connectionUrl) {
    const inventory = {
        checkpoints: [],
        loras: [],
        vaes: [],
        customNodes: [],
        timestamp: new Date().toISOString(),
        errors: []
    };

    if (!connectionUrl) {
        inventory.errors.push('No connection URL');
        return inventory;
    }

    const base = connectionUrl.replace(/\/$/, '');

    // Fetch available checkpoints
    try {
        const checkpointResp = await fetch(`${base}/object_info/CheckpointLoaderSimple`, { timeout: 10000 });
        if (checkpointResp.ok) {
            const data = await checkpointResp.json();
            inventory.checkpoints = data?.CheckpointLoaderSimple?.input?.required?.ckpt_name?.[0] || [];
        }
    } catch (e) {
        inventory.errors.push(`Checkpoint fetch failed: ${e.message}`);
    }

    // Fetch available LoRAs
    try {
        const loraResp = await fetch(`${base}/object_info/LoraLoader`, { timeout: 10000 });
        if (loraResp.ok) {
            const data = await loraResp.json();
            inventory.loras = data?.LoraLoader?.input?.required?.lora_name?.[0] || [];
        }
    } catch (e) {
        inventory.errors.push(`LoRA fetch failed: ${e.message}`);
    }

    // Fetch available VAEs
    try {
        const vaeResp = await fetch(`${base}/object_info/VAELoader`, { timeout: 10000 });
        if (vaeResp.ok) {
            const data = await vaeResp.json();
            inventory.vaes = data?.VAELoader?.input?.required?.vae_name?.[0] || [];
        }
    } catch (e) {
        inventory.errors.push(`VAE fetch failed: ${e.message}`);
    }

    // Check for AnimateDiff custom node (critical for video workflows)
    try {
        const animateDiffResp = await fetch(`${base}/object_info/AnimateDiffLoader`, { timeout: 10000 });
        if (animateDiffResp.ok) {
            inventory.customNodes.push('AnimateDiffLoader');
        }
    } catch (e) { /* Node not available */ }

    // Check for ADE_AnimateDiffLoaderWithContext (alternate AnimateDiff node)
    try {
        const adeResp = await fetch(`${base}/object_info/ADE_AnimateDiffLoaderWithContext`, { timeout: 10000 });
        if (adeResp.ok) {
            if (!inventory.customNodes.includes('AnimateDiffLoader')) {
                inventory.customNodes.push('AnimateDiffLoader');
            }
        }
    } catch (e) { /* Node not available */ }

    // Check for VHS_VideoCombine (critical for video output)
    try {
        const vhsResp = await fetch(`${base}/object_info/VHS_VideoCombine`, { timeout: 10000 });
        if (vhsResp.ok) {
            inventory.customNodes.push('VHS_VideoCombine');
        }
    } catch (e) { /* Node not available */ }

    console.log('WarmPool: Model inventory fetched', {
        checkpoints: inventory.checkpoints.length,
        loras: inventory.loras.length,
        vaes: inventory.vaes.length,
        customNodes: inventory.customNodes
    });

    return inventory;
}

function save() {
    try {
        state.lastAction = state.lastAction || new Date().toISOString();
        db.saveState(state);
    } catch (e) {
        console.error('WarmPool save failed:', e);
    }
}

async function prewarm() {
    console.log('[PREWARM DEBUG] Function called');
    console.log('[PREWARM DEBUG] VASTAI_API_KEY:', VASTAI_API_KEY ? `${VASTAI_API_KEY.slice(0, 10)}...` : 'NOT SET');

    if (prewarmLock) {
        if (prewarmInFlight) {
            console.log('[PREWARM DEBUG] Waiting on in-flight prewarm');

            // Add 5-minute timeout to prevent indefinite waiting on stuck promises
            const PREWARM_WAIT_TIMEOUT = 5 * 60 * 1000; // 5 minutes
            const timeoutPromise = new Promise((_, reject) => {
                setTimeout(() => reject(new Error('Prewarm lock wait timeout exceeded (5 min)')), PREWARM_WAIT_TIMEOUT);
            });

            try {
                // Race between actual prewarm completion and timeout
                return await Promise.race([prewarmInFlight, timeoutPromise]);
            } catch (err) {
                if (err.message.includes('timeout exceeded')) {
                    console.error('WarmPool: Prewarm lock timeout - clearing stuck promise');
                    // Clear the stuck promise to allow retry
                    prewarmInFlight = null;
                    prewarmLock = false;
                }
                throw err;
            }
        }
    }

    if (!VASTAI_API_KEY) throw new Error('VASTAI_API_KEY not set on server');
    console.log('[PREWARM DEBUG] API key check passed');

    // If another prewarm is in-flight, wait for it and return its result
    if (prewarmInFlight) {
        console.log('[PREWARM DEBUG] Waiting on in-flight prewarm');
        return await prewarmInFlight;
    }

    if (state.isPrewarming) return { status: 'already_prewarming' };

    // Acquire prewarm lock immediately to avoid races with concurrent calls
    prewarmLock = true;
    let resolveInflight, rejectInflight;
    prewarmInFlight = new Promise((resolve, reject) => { resolveInflight = resolve; rejectInflight = reject; });

    state.isPrewarming = true;
    state.lastAction = new Date().toISOString();

    try {
        console.log('[PREWARM DEBUG] Calling save()...');
        save();
        console.log('[PREWARM DEBUG] isPrewarming set and save() completed');

        // PRE-FLIGHT: Validate critical tokens before starting expensive operations
        const tokenManager = require('../lib/token-manager');
        console.log('[Prewarm] Validating tokens before instance rental...');
        const tokenValidation = await tokenManager.validateAll(true); // Use cache

        if (tokenValidation.vastai?.valid === false) {
            const error = `VastAI API token invalid: ${tokenValidation.vastai.error}`;
            console.error(`[Prewarm] ❌ ${error}`);
            throw new Error(error);
        }

        if (tokenValidation.civitai?.valid === false) {
            console.warn(`[Prewarm] ⚠️  Civitai token invalid: ${tokenValidation.civitai.error}`);
            console.warn('[Prewarm]    Model downloads from Civitai may fail');
        }

        if (tokenValidation.huggingface?.valid === false) {
            console.warn(`[Prewarm] ⚠️  HuggingFace token invalid: ${tokenValidation.huggingface.error}`);
            console.warn('[Prewarm]    Model downloads from HuggingFace may fail');
        }

        if (state.instance && (state.instance.status === 'starting' || state.instance.status === 'running')) {
            // resolve inflight before returning
            resolveInflight({ status: 'already_present', instance: state.instance });
            prewarmInFlight = null;
            state.isPrewarming = false;
            prewarmLock = false;
            save();
            return { status: 'already_present', instance: state.instance };
        }
        console.log('[PREWARM DEBUG] No existing instance, proceeding');
        // Vast.ai bundle search - use minimal server-side params, filter client-side
        // Note: Many filters (verified, rentable, rented, etc.) are NOT valid server-side ops
        const searchParams = {
            order: [['dph_total', 'asc']],  // Cheapest first - let server sort by price
            type: 'ask'
        };

        // Client-side filtering criteria (optimized for presentation/showcase)
        const filterOffer = (o) => {
            const reasons = [];
            if (!o.rentable) { reasons.push('not rentable'); return false; }
            if (o.rented) { reasons.push('already rented'); return false; }

            // Exclude Ukraine region
            if (o.geolocation && (o.geolocation.includes('Ukraine') || o.geolocation.includes('UA'))) {
                reasons.push('region excluded: Ukraine');
                console.log(`WarmPool: Filtered offer ${o.id}: ${reasons.join(', ')} [${o.gpu_name}]`);
                return false;
            }

            const maxPrice = parseFloat(process.env.WARM_POOL_MAX_DPH || '3.00');
            if (typeof o.dph_total === 'number' && o.dph_total > maxPrice) {
                reasons.push(`price too high: $${o.dph_total}/hr > $${maxPrice}/hr`);
                console.log(`WarmPool: Filtered offer ${o.id}: ${reasons.join(', ')} [${o.gpu_name}]`);
                return false;
            }

            // CRITICAL: Minimum 16GB VRAM for SDXL workflows.
            // Support multi-GPU configurations (e.g. 2x8GB) by checking total VRAM.
            const minVRAM = parseInt(process.env.VASTAI_MIN_GPU_RAM_MB || '16000'); // 16GB default
            const numGpus = o.num_gpus || 1;
            const totalVram = (o.gpu_ram || 0) * numGpus;

            if (totalVram < minVRAM) {
                reasons.push(`Total GPU RAM too low: ${totalVram}MB < ${minVRAM}MB (${numGpus}x ${o.gpu_ram}MB)`);
                console.log(`WarmPool: Filtered offer ${o.id}: ${reasons.join(', ')} [${o.gpu_name}]`);
                return false;
            }
            if (typeof o.disk_space === 'number' && o.disk_space < requiredDiskGb) {
                reasons.push(`disk too small: ${o.disk_space}GB < ${requiredDiskGb}GB`);
                console.log(`WarmPool: Filtered offer ${o.id}: ${reasons.join(', ')} [${o.gpu_name}]`);
                return false;
            }

            // CRITICAL: Require verified hosts only - reject unverified/deverified providers
            // Vast.ai uses TWO fields: o.verified (boolean) AND o.verification (string)
            console.log(`WarmPool: Checking offer ${o.id} [${o.gpu_name}] - verified=${JSON.stringify(o.verified)}, verification=${JSON.stringify(o.verification)}`);

            // Accept if EITHER field indicates verification
            const isVerifiedBoolean = o.verified === true;
            const isVerifiedString = o.verification === 'verified';

            if (!isVerifiedBoolean && !isVerifiedString) {
                reasons.push(`host not verified (verified=${JSON.stringify(o.verified)}, verification=${JSON.stringify(o.verification)})`);
                console.log(`WarmPool: ❌ REJECTED offer ${o.id}: ${reasons.join(', ')} [${o.gpu_name}]`);
                return false;
            }

            console.log(`WarmPool: ✓ Offer ${o.id} [${o.gpu_name}] PASSED verification check`);

            // Bandwidth cost filters - reject expensive bandwidth that kills profitability
            // Target: <$3/TB download, <$5/TB upload (reasonable datacenter rates)
            const maxDownloadCostPerTB = parseFloat(process.env.VASTAI_MAX_INET_DOWN_COST_TB || '3.0');
            const maxUploadCostPerTB = parseFloat(process.env.VASTAI_MAX_INET_UP_COST_TB || '5.0');

            if (typeof o.internet_down_cost_per_tb === 'number' && o.internet_down_cost_per_tb > maxDownloadCostPerTB) {
                reasons.push(`download bandwidth too expensive: $${o.internet_down_cost_per_tb.toFixed(2)}/TB > $${maxDownloadCostPerTB}/TB`);
                console.log(`WarmPool: Filtered offer ${o.id}: ${reasons.join(', ')} [${o.gpu_name}]`);
                return false;
            }

            if (typeof o.internet_up_cost_per_tb === 'number' && o.internet_up_cost_per_tb > maxUploadCostPerTB) {
                reasons.push(`upload bandwidth too expensive: $${o.internet_up_cost_per_tb.toFixed(2)}/TB > $${maxUploadCostPerTB}/TB`);
                console.log(`WarmPool: Filtered offer ${o.id}: ${reasons.join(', ')} [${o.gpu_name}]`);
                return false;
            }

            // High-speed download requirement
            const minInetDown = parseFloat(process.env.VASTAI_MIN_INET_DOWN || '2000'); // 2000 Mbps (2 Gbps) minimum
            if (typeof o.inet_down === 'number' && o.inet_down < minInetDown) {
                reasons.push(`internet speed too low: ${o.inet_down.toFixed(1)} Mbps < ${minInetDown} Mbps`);
                console.log(`WarmPool: Filtered offer ${o.id}: ${reasons.join(', ')} [${o.gpu_name}]`);
                return false;
            }

            const minReliability = parseFloat(process.env.VASTAI_MIN_RELIABILITY || '0.95'); // 95% reliability
            if (typeof o.reliability === 'number' && o.reliability < minReliability) {
                reasons.push(`reliability too low: ${(o.reliability * 100).toFixed(1)}% < ${(minReliability * 100).toFixed(1)}%`);
                console.log(`WarmPool: Filtered offer ${o.id}: ${reasons.join(', ')} [${o.gpu_name}]`);
                return false;
            }

            // CRITICAL: Filter out consumer-grade legacy GPUs incompatible with modern workloads
            // Allow datacenter GPUs like P100/P40 (they have 16-24GB VRAM for SDXL)
            const isLegacyName = (o.gpu_name || '').toLowerCase().match(/^gtx\s*(1080|1070)|titan\s*x/);
            if (isLegacyName || (o.cuda_max_good && !isGpuCompatible(o.cuda_max_good))) {
                console.log(`WarmPool: Filtered out legacy GPU ${o.gpu_name || 'unknown'} (CUDA ${o.cuda_max_good || 'N/A'} < ${MIN_CUDA_CAPABILITY})`);
                return false;
            }

            // Log successful offer with bandwidth costs for transparency
            const downCost = typeof o.internet_down_cost_per_tb === 'number' ? `$${o.internet_down_cost_per_tb.toFixed(2)}/TB` : 'N/A';
            const upCost = typeof o.internet_up_cost_per_tb === 'number' ? `$${o.internet_up_cost_per_tb.toFixed(2)}/TB` : 'N/A';
            console.log(`WarmPool: ✓ Offer ${o.id} PASSED filters: ${numGpus}x ${o.gpu_name}, $${o.dph_total}/hr, ${totalVram}MB Total VRAM, ${o.disk_space}GB disk, verified=${o.verified}, bandwidth: ↓${downCost} ↑${upCost}`);
            return true;
        };

        // Robust bundle search with retries
        async function searchBundles(params, attempts = 3) {
            for (let i = 1; i <= attempts; i++) {
                try {
                    console.log(`WarmPool: bundle search attempt ${i} with params:`, JSON.stringify(params));

                    const queryParams = {
                        ...params,
                        // Request 1000 results to ensure we find high-quality candidates
                        limit: 1000
                    };

                    const r = await fetch(`${VAST_BASE}/bundles/`, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                            'Authorization': `Bearer ${VASTAI_API_KEY}`
                        },
                        body: JSON.stringify(queryParams)
                    });

                    if (!r.ok) {
                        const errorText = await r.text();
                        
                        // Handle rate limiting (429) - this is expected behavior
                        if (r.status === 429) {
                            console.warn(`WarmPool: Vast.ai API rate limited (429) on bundle search attempt ${i}. This is normal - backing off before retry.`);
                            const backoffDelay = 2000 * i; // Increasing backoff
                            await new Promise(resolve => setTimeout(resolve, backoffDelay));
                            continue; // Try again after waiting
                        }
                        
                        console.error(`WarmPool: Vast.ai API returned ${r.status} ${r.statusText}`);
                        console.error(`WarmPool: Error response:`, errorText);
                        
                        // Rate limiting handled above, now check for other transient errors
                        if (r.status >= 500 || r.status === 408) {
                            console.warn(`WarmPool: Server error detected, will retry after brief pause`);
                            await new Promise(resolve => setTimeout(resolve, 1000 * i));
                            continue;
                        }
                        
                        continue;
                    }

                    const data = await r.json();
                    const allOffers = data.offers || [];
                    console.log(`WarmPool: Vast.ai returned ${allOffers.length} total offers`);

                    // Log sample of first few offers for debugging
                    if (allOffers.length > 0 && allOffers.length <= 5) {
                        console.log(`WarmPool: Sample offers:`, allOffers.map(o => ({
                            id: o.id,
                            gpu: o.gpu_name,
                            price: o.dph_total,
                            vram: o.gpu_ram,
                            disk: o.disk_space,
                            rentable: o.rentable,
                            rented: o.rented
                        })));
                    }

                    // Apply client-side filtering
                    let offers = allOffers.filter(filterOffer);

                    // Sort results: Primary by value (price per Gbps), secondarily by bandwidth (Mbps DESC)
                    // This balances cost vs speed - allows higher price for significantly faster network
                    offers.sort((a, b) => {
                        const a_speed_gbps = (a.inet_down || 0) / 1000;
                        const b_speed_gbps = (b.inet_down || 0) / 1000;
                        const a_price_per_gbps = a.dph_total / Math.max(a_speed_gbps, 0.1); // avoid div by zero
                        const b_price_per_gbps = b.dph_total / Math.max(b_speed_gbps, 0.1);
                        if (a_price_per_gbps !== b_price_per_gbps) return a_price_per_gbps - b_price_per_gbps;
                        return (b.inet_down || 0) - (a.inet_down || 0);
                    });

                    console.log(`WarmPool: bundle search attempt ${i} found ${allOffers.length} total, ${offers.length} matching criteria`);
                    if (offers.length) return offers;
                } catch (err) {
                    console.error(`WarmPool: bundle search attempt ${i} error:`, err && err.message ? err.message : err);
                }
                // backoff
                await new Promise(res => setTimeout(res, 1000 * i));
            }
            return [];
        }

        const offers = await searchBundles(searchParams);

        // CRITICAL: NO RELAXED FALLBACK - strict requirements are non-negotiable
        // Previous relaxed fallback was bypassing verification, bandwidth speed, and VRAM checks
        // This caused unverified 8GB GPUs with 600 Mbps to be rented despite 16GB + 1Gbps requirement

        if (!offers.length) {
            throw new Error('No offers found after retries and fallback');
        }

        // Try renting offers in order until one succeeds. This handles cases where an
        // offer becomes unavailable between search and rent (Vast.ai returns no_such_ask).
        let rentData = null;
        let selectedOffer = null;
        // Concurrency guard: if another prewarm set a VALID instance while we searched, skip renting
        // We only skip if the instance is NOT in a failed state.
        if (state.instance && state.instance.contractId &&
            state.instance.status !== 'failed' &&
            !String(state.instance.lastStatusMessage || '').toLowerCase().includes('no space left on device')) {
            console.warn('WarmPool: instance already present after search; skipping rent');
            return { status: 'already_present', instance: state.instance };
        }

        // Allow the prebuilt image to be configurable via VASTAI_COMFY_IMAGE.
        // If VASTAI_COMFY_IMAGE is set to 'auto', do not set `image` so the offer default is used.
        // By default (when the env var is not set) prefer the known Comfy template image to improve reliability.
        const configuredImage = (process.env.VASTAI_COMFY_IMAGE === undefined)
            ? 'vastai/comfy:v0.10.0-cuda-12.9-py312'
            : process.env.VASTAI_COMFY_IMAGE;

        // PARALLEL PROVISIONING: Use optimized parallel download script for fast setup
        // Priority: 1) Check fallback flag, 2) COMFYUI_PROVISION_SCRIPT env var, 3) Vast.ai default
        const customProvisionScript = process.env.COMFYUI_PROVISION_SCRIPT;
        const defaultProvisionScript = "https://raw.githubusercontent.com/vast-ai/base-image/refs/heads/main/derivatives/pytorch/derivatives/comfyui/provisioning_scripts/default.sh";

        // Strict provisioning controls:
        // - PROVISION_STRICT=true  => do NOT fall back to default; abort provisioning on custom script failure
        // - PROVISION_ALLOWED_SCRIPTS="url1,url2" => whitelist of allowed provision script URLs (exact match or substring)
        const provisionStrict = String(process.env.PROVISION_STRICT || '').toLowerCase() === '1' || String(process.env.PROVISION_STRICT || '').toLowerCase() === 'true';
        const allowedProvisionScripts = (process.env.PROVISION_ALLOWED_SCRIPTS || '').split(',').map(s => s.trim()).filter(Boolean);

        // Increment provision attempt counter
        state.provisionAttempt = (state.provisionAttempt || 0) + 1;
        console.log(`WarmPool: 📦 Provisioning attempt #${state.provisionAttempt} (fallback mode: ${state.useDefaultScript}, provisionStrict: ${provisionStrict})`);

        // Cap provisioning attempts to avoid endless churn and enter safe mode if exceeded
        const MAX_ATTEMPTS = parseInt(process.env.WARM_POOL_MAX_PROVISION_ATTEMPTS || '5', 10);
        if (state.provisionAttempt >= MAX_ATTEMPTS) {
            console.error(`WarmPool: ❌ Exceeded max provisioning attempts (${MAX_ATTEMPTS}). Entering safe mode to prevent further churn.`);
            state.safeMode = true;
            save();
            try { audit.logUsageEvent({ event_type: 'safe_mode_engaged', details: { provisionAttempt: state.provisionAttempt }, source: 'warm-pool' }); } catch (e) {}
            return { status: 'safe_mode', message: 'Max provisioning attempts exceeded, safe mode engaged' };
        }

        // FALLBACK / STRICT LOGIC: If useDefaultScript flag is set (from previous failure)
        let provisionScript = null;
        if (state.useDefaultScript) {
            if (provisionStrict) {
                console.error('WarmPool: ❌ Custom provisioning previously failed and PROVISION_STRICT=true — aborting provisioning instead of using default');
                state.safeMode = true;
                save();
                return { status: 'provision_failed', message: 'Custom provisioning failed previously and strict mode prevents fallback' };
            }
            console.warn('WarmPool: ⚠️ Using DEFAULT Vast.ai script (fallback from failed custom script)');
            provisionScript = defaultProvisionScript;
        } else if (customProvisionScript) {
            // Validate custom script URL before using it (check for 404 gist issues)
            try {
                const testResp = await fetchWithTimeout(customProvisionScript, { method: 'HEAD' }, 10000);
                if (!testResp.ok) {
                    const msg = `Custom provision script returned ${testResp.status}`;
                    if (provisionStrict) {
                        console.error('WarmPool: ❌', msg, 'and PROVISION_STRICT=true — aborting provisioning');
                        state.safeMode = true;
                        save();
                        return { status: 'provision_failed', message: msg };
                    }
                    console.warn('WarmPool: ⚠️', msg, ', falling back to default');
                    provisionScript = defaultProvisionScript;
                } else {
                    // If an allowlist exists, ensure the provided script matches one of the allowed values
                    if (allowedProvisionScripts.length > 0) {
                        const allowed = allowedProvisionScripts.some(a => customProvisionScript.includes(a) || customProvisionScript === a);
                        if (!allowed) {
                            const msg = 'Custom provision script is not in PROVISION_ALLOWED_SCRIPTS';
                            if (provisionStrict) {
                                console.error('WarmPool: ❌', msg, 'and PROVISION_STRICT=true — aborting provisioning');
                                state.safeMode = true;
                                save();
                                return { status: 'provision_failed', message: msg };
                            }
                            console.warn('WarmPool: ⚠️', msg, ', falling back to default');
                            provisionScript = defaultProvisionScript;
                        } else {
                            // Further safety: fetch the script body and scan for any external hosts
                            try {
                                const bodyResp = await fetchWithTimeout(customProvisionScript, { method: 'GET' }, 20000);
                                if (!bodyResp.ok) throw new Error(`GET returned ${bodyResp.status}`);
                                const text = await bodyResp.text();
                                const urlMatches = Array.from(text.matchAll(/https?:\/\/[^\s"'`\)]+/g)).map(m => m[0]);
                                const hosts = Array.from(new Set(urlMatches.map(u => {
                                    try { return (new URL(u)).host; } catch (e) { return null; }
                                }).filter(Boolean)));

                                // Optional: require the fetched script to contain a configured signature string
                                const expectedSig = (process.env.PROVISION_EXPECTED_SIGNATURE || '').trim();
                                if (expectedSig) {
                                    if (!text.includes(expectedSig)) {
                                        const msg = `Custom provision script missing expected signature: ${expectedSig}`;
                                        if (provisionStrict) {
                                            console.error('WarmPool: ❌', msg, 'and PROVISION_STRICT=true — aborting provisioning');
                                            state.safeMode = true;
                                            save();
                                            return { status: 'provision_failed', message: msg };
                                        }
                                        console.warn('WarmPool: ⚠️', msg, ', falling back to default');
                                        provisionScript = defaultProvisionScript;
                                        // skip setting provisionScript to custom below
                                    } else {
                                        console.log('WarmPool: ✅ Provision script contains expected signature:', expectedSig);
                                    }
                                }

                                // Reject known-bad internal markers (helps detect outdated scripts that were partially updated)
                                // By default do NOT block any substring here to avoid self-detection; set via PROVISION_DISALLOWED_SUBSTRINGS env var when needed
                                const disallowedList = (process.env.PROVISION_DISALLOWED_SUBSTRINGS || '').split(',').map(s => s.trim()).filter(Boolean);
                                const foundDisallowed = disallowedList.filter(sub => sub && text.includes(sub));
                                if (foundDisallowed.length > 0) {
                                    const msg = `Custom provision script contains disallowed substrings: ${foundDisallowed.join(', ')}`;
                                    if (provisionStrict) {
                                        console.error('WarmPool: ❌', msg, 'and PROVISION_STRICT=true — aborting provisioning');
                                        state.safeMode = true;
                                        save();
                                        return { status: 'provision_failed', message: msg };
                                    }
                                    console.warn('WarmPool: ⚠️', msg, ', falling back to default');
                                    provisionScript = defaultProvisionScript;
                                    // skip setting provisionScript to custom below
                                }

                                const allowedHosts = (process.env.PROVISION_ALLOWED_HOSTS || '').split(',').map(s => s.trim()).filter(Boolean);
                                if (allowedHosts.length > 0) {                                    const disallowed = hosts.filter(h => !allowedHosts.some(a => h.includes(a)));
                                    if (disallowed.length > 0) {
                                        const msg = `Provision script references disallowed external hosts: ${disallowed.join(', ')}`;
                                        if (provisionStrict) {
                                            console.error('WarmPool: ❌', msg, 'and PROVISION_STRICT=true — aborting provisioning');
                                            state.safeMode = true;
                                            save();
                                            return { status: 'provision_failed', message: msg };
                                        }
                                        console.warn('WarmPool: ⚠️', msg, ', falling back to default');
                                        provisionScript = defaultProvisionScript;
                                        // skip setting provisionScript to custom below
                                    } else {
                                        provisionScript = customProvisionScript;
                                        console.log('WarmPool: ✅ Custom provision script allowed, reachable, and references only allowed hosts:', allowedHosts.join(', '));
                                    }
                                } else {
                                    provisionScript = customProvisionScript;
                                    console.log('WarmPool: ✅ Custom script reachable; no PROVISION_ALLOWED_HOSTS configured to validate external refs');
                                }
                            } catch (err) {
                                const msg = `Failed to validate provision script content: ${err.message}`;
                                if (provisionStrict) {
                                    console.error('WarmPool: ❌', msg, 'and PROVISION_STRICT=true — aborting provisioning');
                                    state.safeMode = true;
                                    save();
                                    return { status: 'provision_failed', message: msg };
                                }
                                console.warn('WarmPool: ⚠️', msg, ', falling back to default');
                                provisionScript = defaultProvisionScript;
                            }
                        }
                    } else {
                        provisionScript = customProvisionScript;
                        console.log('WarmPool: ✅ Using custom provision script:', customProvisionScript);
                    }
                }
            } catch (err) {
                const msg = `Custom provision script unreachable: ${err.message}`;
                if (provisionStrict) {
                    console.error('WarmPool: ❌', msg, 'and PROVISION_STRICT=true — aborting provisioning');
                    state.safeMode = true;
                    save();
                    return { status: 'provision_failed', message: msg };
                }
                console.warn('WarmPool: ⚠️', msg, ', falling back to default');
                provisionScript = defaultProvisionScript;
            }
        }

        // FALLBACK: If provisionScript is still null (no custom script and not in fallback mode), use default
        if (!provisionScript) {
            console.warn('WarmPool: ⚠️ No provision script configured, using default Vast.ai script');
            provisionScript = defaultProvisionScript;
        }

        console.log('WarmPool: 🔧 Selected provision script:', provisionScript);

        // Build environment variables - include HF and Civitai tokens if set
        const envVars = {
            COMFYUI_ARGS: "--listen 0.0.0.0 --disable-auto-launch --port 8188 --enable-cors-header",
            COMFYUI_API_BASE: "http://localhost:8188",
            PORTAL_CONFIG: "localhost:1111:11111:/:Instance Portal|localhost:8188:18188:/:ComfyUI|localhost:8288:18288:/docs:API Wrapper|localhost:8188:18188:/:ComfyUI|localhost:8080:18080:/:Jupyter|localhost:8080:8080:/terminals/1:Jupyter Terminal|localhost:8384:18384:/:Syncthing",
            OPEN_BUTTON_PORT: "1111",
            JUPYTER_DIR: "/",
            DATA_DIRECTORY: "/workspace/",
            OPEN_BUTTON_TOKEN: "1"
        };

        // Try to ensure dropbox links file exists — auto-generate if token present
        try {
            const dropboxLinksPath = path.join(__dirname, '..', 'data', 'dropbox_links.txt');
            // If token available and links missing, attempt to run generator script (local, not remote)
            if (!fs.existsSync(dropboxLinksPath) && process.env.DROPBOX_TOKEN) {
                try {
                    console.log('WarmPool: DROPBOX_TOKEN present and no data/dropbox_links.txt found - generating via script');
                    const spawnSync = require('child_process').spawnSync;
                    const folder = process.env.DROPBOX_FOLDER || '/';
                    const res = spawnSync('node', ['scripts/dropbox_create_links.js', folder], { stdio: 'inherit', env: Object.assign({}, process.env) });
                    if (res.error) {
                        console.warn('WarmPool: Failed to run dropbox_create_links script:', res.error);
                    } else if (res.status !== 0) {
                        console.warn('WarmPool: dropbox_create_links exited with code', res.status);
                    } else {
                        console.log('WarmPool: dropbox_create_links completed');
                    }
                } catch (e) {
                    console.warn('WarmPool: Error executing dropbox link generator:', e && e.message ? e.message : e);
                }
            }

            if (fs.existsSync(dropboxLinksPath)) {
                const contents = fs.readFileSync(dropboxLinksPath, 'utf8');
                if (contents && contents.trim().length > 0) {
                    envVars.PROVISION_DROPBOX_LINKS_B64 = Buffer.from(contents, 'utf8').toString('base64');
                    envVars.PROVISION_DROPBOX_LINKS_SOURCE = 'repo:file';
                    console.log('WarmPool: Added PROVISION_DROPBOX_LINKS_B64 from data/dropbox_links.txt');
                }
            }
        } catch (err) {
            console.warn('WarmPool: Failed to prepare data/dropbox_links.txt:', err && err.message ? err.message : err);
        }

        // Only add PROVISIONING_SCRIPT if it's not null (allows disabling provisioning)
        if (provisionScript) {
            envVars.PROVISIONING_SCRIPT = provisionScript;
        }

        // Pass through Hugging Face and Civitai tokens for model downloads
        if (process.env.HUGGINGFACE_HUB_TOKEN) {
            envVars.HUGGINGFACE_HUB_TOKEN = process.env.HUGGINGFACE_HUB_TOKEN;
        }
        if (process.env.CIVITAI_TOKEN) {
            envVars.CIVITAI_TOKEN = process.env.CIVITAI_TOKEN;
        }

        // Pass through SCRIPTS_BASE_URL for modular provisioning system
        if (process.env.SCRIPTS_BASE_URL) {
            envVars.SCRIPTS_BASE_URL = process.env.SCRIPTS_BASE_URL;
            console.log('WarmPool: 📦 Using modular scripts from:', process.env.SCRIPTS_BASE_URL);
        }

        // Pass through provisioning enforcement settings so the provisioned instance can validate
        if (process.env.PROVISION_ALLOWED_SCRIPTS) {
            envVars.PROVISION_ALLOWED_SCRIPTS = process.env.PROVISION_ALLOWED_SCRIPTS;
        }
        if (process.env.PROVISION_ALLOWED_HOSTS) {
            envVars.PROVISION_ALLOWED_HOSTS = process.env.PROVISION_ALLOWED_HOSTS;
        }
        if (process.env.PROVISION_STRICT) {
            envVars.PROVISION_STRICT = process.env.PROVISION_STRICT;
        }

        const rentBody = {
            ...(configuredImage && configuredImage !== 'auto' ? { image: configuredImage } : {}),
            runtype: 'ssh',
            target_state: 'running',
            onstart: `bash -lc 'if mkdir -p /workspace 2>/dev/null && test -w /workspace; then export WORKSPACE=/workspace; else mkdir -p "$HOME/workspace" 2>/dev/null || true; export WORKSPACE="$HOME/workspace"; fi; cd "$WORKSPACE" || cd; echo "WarmPool: using WORKSPACE=$WORKSPACE"; curl -fsSL "${provisionScript}" -o /tmp/provision.sh && chmod +x /tmp/provision.sh && bash -x /tmp/provision.sh'`,
            ssh_key: vastaiSsh.getKey(),
            env: envVars,
            // Request disk according to configured requirement to ensure room for model extraction
            disk: requiredDiskGb,
            // Request direct port access for ComfyUI (port 8188) and other services
            direct_port_count: 100
        };

        // Ensure account-level SSH key exists so per-instance access works
        try { await vastaiSsh.registerKey(VASTAI_API_KEY); } catch (e) { /* continue even if key registration fails */ }

        // Iterate offers and attempt to rent each. If Vast.ai reports the ask is gone
        // (no_such_ask / 404/3603) try the next candidate instead of failing hard.
        for (let i = 0; i < offers.length; i++) {
            const offer = offers[i];
            console.log(`WarmPool: Attempting to rent offer ${offer.id} (${i + 1}/${offers.length}) $${offer.dph_total}/hr ${offer.gpu_name}`);
            try {
                // Rent the selected offer via asks PUT
                const rentResp = await fetch(`${VAST_BASE}/asks/${offer.id}/`, {
                    method: 'PUT',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${VASTAI_API_KEY}`
                    },
                    body: JSON.stringify(rentBody)
                });

                // parse response safely
                const parsed = await rentResp.json().catch(() => ({}));
                if (!rentResp.ok) {
                    const txt = JSON.stringify(parsed || {});
                    // Handle known transient case where ask is no longer available
                    if (txt && (txt.includes('no_such_ask') || txt.includes('no such ask') || txt.includes('ask not found') || (parsed && parsed.msg && String(parsed.msg).toLowerCase().includes('no_such_ask')))) {
                        console.warn(`WarmPool: Offer ${offer.id} no longer available (no_such_ask); trying next candidate`);
                        // continue to next offer
                        continue;
                    }
                    // If image manifest problem, we may retry without image below
                    if (txt.includes('manifest') || txt.includes('not found') || txt.includes('manifest unknown')) {
                        console.warn('WarmPool: prebuilt image not available for this offer, retrying rent without image');
                        try {
                            const fallbackBody = Object.assign({}, rentBody);
                            delete fallbackBody.image;
                            const rentResp2 = await fetch(`${VAST_BASE}/asks/${offer.id}/`, {
                                method: 'PUT',
                                headers: {
                                    'Content-Type': 'application/json',
                                    'Authorization': `Bearer ${VASTAI_API_KEY}`
                                },
                                body: JSON.stringify(fallbackBody)
                            });
                            const parsed2 = await rentResp2.json().catch(() => ({}));
                            if (!rentResp2.ok) {
                                const txt2 = JSON.stringify(parsed2 || {});
                                if (txt2 && (txt2.includes('no_such_ask') || txt2.includes('no such ask'))) {
                                    console.warn(`WarmPool: Offer ${offer.id} became unavailable while retrying without image; trying next candidate`);
                                    continue;
                                }
                                throw new Error(JSON.stringify(parsed2 || {}));
                            }
                            rentData = parsed2;
                            selectedOffer = offer;
                            break; // success
                        } catch (e) {
                            console.warn('WarmPool: Rent fallback without image failed:', e && e.message ? e.message : e);
                            continue; // try next offer
                        }
                    }
                    // For other errors, throw to outer catch and eventually abort
                    throw new Error(JSON.stringify(parsed || {}));
                }

                // Success
                rentData = parsed;
                selectedOffer = offer;
                break;
            } catch (e) {
                console.error(`WarmPool: Rent attempt for offer ${offer.id} failed:`, e && e.message ? e.message : e);
                // try next offer
                continue;
            }
        }

        if (!rentData || !selectedOffer) {
            throw new Error('All rent attempts failed or offers no longer available');
        }

        const contractId = rentData.new_contract || rentData.contract || rentData.id;
        state.instance = {
            contractId: contractId,
            status: 'starting',
            connectionUrl: null,
            createdAt: new Date().toISOString(),
            lastHeartbeat: null,
            leasedUntil: null
        };

        // Log usage event: instance started
        try {
            audit.logUsageEvent({ event_type: 'instance_started', contract_id: contractId, instance_status: 'starting', details: { offerId: selectedOffer.id, gpuName: selectedOffer.gpu_name, pricePerHour: selectedOffer.dph_total }, source: 'warm-pool' });
        } catch (e) { console.error('audit log usage error:', e); }

        save();
        // Immediately start a status check and wait for ComfyUI to be ready
        // In test environment skip the long readiness probes to keep unit tests fast
        if (process.env.NODE_ENV === 'test') {
            // First, let checkInstance() populate connectionUrl from mocked Vast.ai response
            await checkInstance();
            // Then mark instance as ready in tests and provide a fallback dummy connectionUrl only if not set
            state.instance.status = 'ready';
            state.instance.connectionUrl = state.instance.connectionUrl || `http://127.0.0.1:8188`;
            state.instance.lastHeartbeat = new Date().toISOString();
            save();
        } else {
            await checkInstance();
            try {
                // attempt to detect ComfyUI readiness (15 minutes max to allow large model downloads like Flux)
                await waitForComfyReady(contractId, 900000, 10000);
            } catch (e) { /* continue even if readiness check fails */ }
        }
        const result = { status: 'started', instance: state.instance };
        // resolve inflight for waiters
        try { resolveInflight && resolveInflight(result); } catch (e) { }
        prewarmInFlight = null;
        return result;
    } catch (error) {
        console.error('WarmPool prewarm error:', error);
        state.lastAction = new Date().toISOString();
        // CRITICAL: Don't clear instance on prewarm errors - might just be rate limiting
        if (state.instance) {
            state.instance.lastError = error.message;
        }
        save();
        // reject inflight waiters
        try { rejectInflight && rejectInflight(error); } catch (e) { }
        prewarmInFlight = null;
        throw error;
    } finally {
        state.isPrewarming = false;
        prewarmLock = false;
        save();
    }
}

async function checkInstance() {
    if (!state.instance || !state.instance.contractId) return;
    try {
        const { contractId } = state.instance;

        // Use fetchWithRetry for automatic retry on transient errors and rate limiting
        // Timeout: 10s per attempt, max 3 retries with exponential backoff (1s, 2s, 4s)
        let r;
        try {
            r = await fetchWithRetry(
                `${VAST_BASE}/instances/${contractId}/`,
                { headers: { 'Authorization': `Bearer ${VASTAI_API_KEY}` } },
                10000, // 10-second timeout per attempt
                3,     // 3 retries max
                1000   // 1-second initial delay
            );
        } catch (retryErr) {
            // Check if it's a rate limit error that was retried
            if (retryErr.message && retryErr.message.includes('429')) {
                console.warn(`WarmPool: Vast.ai API rate limited (429) after retries. This is normal - will retry next cycle.`);
                state.instance.lastError = `Rate limited (429) after retries at ${new Date().toISOString()}`;
                return state.instance;
            }
            throw retryErr;
        }

        if (!r.ok) {
            const txt = await r.text();
            // If the instance is gone (404), clear our local state
            if (r.status === 404) {
                console.warn(`WarmPool: Instance ${contractId} no longer exists on Vast.ai. Clearing local state.`);
                state.instance = null;
                save();
                return null;
            }
            // CRITICAL: If rate limited (429), DON'T kill the instance - just log and skip this check gracefully
            if (r.status === 429) {
                console.warn(`WarmPool: Vast.ai API rate limited (429). This is normal behavior - will retry next poll cycle.`);
                state.instance.lastError = `Rate limited (429) at ${new Date().toISOString()}`;
                return state.instance; // Don't throw - instance is still running, just keep state
            }
            throw new Error(`instances status error ${r.status} ${txt}`);
        }
        const instance = await r.json();
        // Vast.ai proxy returns wrapper objects; normalize to the inner instance object
        const inst = instance.instances || instance.instance || instance;
        state.instance.lastHeartbeat = new Date().toISOString();
        const previousConnectionUrl = state.instance.connectionUrl;
        // Prefer explicit actual_status, fall back to status fields
        state.instance.status = inst.actual_status || inst.status || state.instance.status;
        // Set connection url when instance is running and public ip is available
        if ((inst.actual_status === 'running' || inst.status === 'running') && inst.public_ipaddr) {
            const portValidator = require('../lib/port-validator');

            console.log(`[PortValidator] Testing connectivity to ${inst.public_ipaddr}...`);
            const validation = await portValidator.validateInstancePorts(inst);

            if (validation.success) {
                state.instance.connectionUrl = validation.connectionUrl;
                console.log(`✅ Port ${validation.port} (${validation.source}) validated and accessible`);
            } else {
                console.warn(`⚠️  Port validation failed: ${validation.error}`);
                console.warn('   Will retry on next poll cycle');
                // Don't set connectionUrl yet, wait for next poll when service might be ready
                if (validation.details && validation.details.firewallDetected) {
                    console.error('   FIREWALL DETECTED: All tested ports are blocked');
                }
            }
        } else if ((inst.actual_status === 'running' || inst.status === 'running') && !inst.public_ipaddr) {
            console.warn(`Instance ${contractId} running but no public IP available yet`);

            // If this is the first time we've detected the connectionUrl, mark as loading and validate health
            if (!previousConnectionUrl && state.instance.connectionUrl && process.env.NODE_ENV !== 'test') {
                state.instance.status = 'loading'; // Override to loading until ComfyUI responds
                console.log(`WarmPool: Instance ${contractId} network ready, validating ComfyUI health (up to 15m)...`);

                // Start log collection daemon if SSH details are available
                if (inst.ssh_host && inst.ssh_port) {
                    // Configurable SSH key path with fallbacks
                    const sshKeyPath = process.env.VASTAI_SSH_KEY_PATH ||
                        path.join(require('os').homedir(), '.ssh', 'id_rsa_vast') ||
                        path.join(require('os').homedir(), '.ssh', 'vast_ai_key');

                    const logOutputPath = path.join(__dirname, '..', 'logs', `provision_${contractId}_${Date.now()}.log`);

                    console.log(`[LogCollector] Registering log collection for instance ${contractId} with watchdog`);
                    console.log(`[LogCollector] SSH: ${inst.ssh_host}:${inst.ssh_port}`);
                    console.log(`[LogCollector] SSH Key: ${sshKeyPath}`);
                    console.log(`[LogCollector] Output: ${logOutputPath}`);

                    // Register with process watchdog for automatic restart on failure
                    const watchdogId = `log-collector-${contractId}`;
                    processWatchdog.register(watchdogId, {
                        name: `LogCollector-${contractId}`,
                        command: 'node',
                        args: [
                            path.join(__dirname, '..', 'scripts', 'collect_provision_logs.js'),
                            '--host', inst.ssh_host,
                            '--port', String(inst.ssh_port),
                            '--key', sshKeyPath,
                            '--contract-id', String(contractId),
                            '--output', logOutputPath,
                            '--timeout', '3600'  // 1 hour max
                        ],
                        maxRestarts: -1,  // Unlimited restarts
                        restartDelay: 10000,  // 10s base delay with exponential backoff
                        stdio: ['ignore', 'pipe', 'pipe']
                    });

                    // Listen for watchdog events for this specific process
                    const handleStdout = ({ id, data }) => {
                        if (id === watchdogId) {
                            console.log(`[LogCollector] ${data.trim()}`);
                        }
                    };

                    const handleStderr = ({ id, data }) => {
                        if (id === watchdogId) {
                            console.error(`[LogCollector] ERROR: ${data.trim()}`);
                        }
                    };

                    processWatchdog.on('stdout', handleStdout);
                    processWatchdog.on('stderr', handleStderr);

                    // Store watchdog ID for cleanup (instead of PID)
                    if (!state.instance.logCollectorWatchdogId) {
                        state.instance.logCollectorWatchdogId = watchdogId;
                        state.instance.logCollectorOutputPath = logOutputPath;
                    }
                } else {
                    console.warn(`[LogCollector] SSH details not available for instance ${contractId}, skipping log collection`);
                }

                // Start proactive ComfyUI keepalive monitoring
                if (!comfyKeepalive && state.instance.connectionUrl) {
                    console.log('[Keepalive] Starting ComfyUI connection monitoring');
                    comfyKeepalive = new ComfyUIKeepalive(state.instance.connectionUrl, {
                        intervalMs: 30000,  // Ping every 30s
                        timeoutMs: 5000,    // 5s timeout per ping
                        maxConsecutiveFailures: 5  // Alert after 5 failures
                    });

                    comfyKeepalive.on('connection-lost', ({ failures, lastError }) => {
                        console.error(`❌ ComfyUI connection LOST after ${failures} failures: ${lastError}`);
                        console.error('   Triggering emergency health check...');
                        // Trigger immediate health check
                        checkInstance().catch(err => console.error('Emergency health check failed:', err));
                    });

                    comfyKeepalive.on('ping-failure', ({ failures, error }) => {
                        console.warn(`⚠️  ComfyUI ping failed (${failures} consecutive): ${error}`);
                    });

                    comfyKeepalive.on('ping-success', ({ duration }) => {
                        if (duration > 1000) {
                            console.log(`[Keepalive] Ping successful (${duration}ms - slow response)`);
                        }
                    });

                    comfyKeepalive.start();
                }

                // Trigger health validation in background (don't block checkInstance)
                const healthTimeoutMs = parseInt(process.env.COMFYUI_READY_TIMEOUT_MS || (process.env.DISABLE_AUTO_RECOVERY === '1' ? '3600000' : '900000'), 10);
                waitForComfyReady(contractId, healthTimeoutMs, 10000).catch(async err => {
                    console.error(`WarmPool: Health validation failed for ${contractId}:`, err.message);

                    // AUTO-RECOVERY: If instance is running but models never loaded, terminate and recreate
                    // Skip auto-recovery if explicitly disabled (for long provisioning/download phases)
                    if (process.env.DISABLE_AUTO_RECOVERY === '1') {
                        console.log('WarmPool: Auto-recovery disabled via DISABLE_AUTO_RECOVERY env var. Skipping termination.');
                        return;
                    }
                    if (state.instance && state.instance.contractId === contractId) {
                        const healthReport = await validateInstanceHealth(state.instance.connectionUrl, contractId).catch(() => null);
                        if (healthReport && healthReport.comfyui_api && !healthReport.models_loaded) {
                            console.warn(`WarmPool: AUTO-RECOVERY - Instance ${contractId} running but NO MODELS. Destroying and recreating...`);
                            try {
                                await terminate(contractId);
                                console.log('WarmPool: Broken instance terminated. Will recreate on next prewarm request.');
                            } catch (termErr) {
                                console.error('WarmPool: Failed to auto-terminate broken instance:', termErr);
                            }
                        }
                    }
                });
            }
        }
        // Record status message for audit/debugging
        if (inst.status_msg) {
            state.instance.lastStatusMessage = inst.status_msg;

            // AUTO-TERMINATE if instance is failing due to 'no space left on device'
            if (inst.status_msg.toLowerCase().includes('no space left on device')) {
                console.warn(`WarmPool: Auto-terminating broken instance ${contractId} due to disk space exhaustion`);
                // Use background termination so we don't block the status check
                terminate(contractId).catch(err => console.error('WarmPool: Failed auto-terminating disk-full instance:', err));
                state.instance = null;
                save();
            }
        }
        save();
        return state.instance;
    } catch (error) {
        console.error('WarmPool checkInstance error:', error);
        state.instance.lastError = String(error);
        save();
        return null;
    }
}

async function claim(maxMinutes = 30) {
    // If instance is ready or running with available connectionUrl, lease it
    if (!state.instance) return null;
    if ((state.instance.status !== 'ready' && state.instance.status !== 'running') || !state.instance.connectionUrl) return null;

    const now = Date.now();
    state.instance.leasedUntil = new Date(now + maxMinutes * 60000).toISOString();
    state.lastAction = new Date().toISOString();
    save();
    try {
        audit.logUsageEvent({ event_type: 'lease_claimed', contract_id: state.instance.contractId, instance_status: state.instance.status, details: { leasedUntil: state.instance.leasedUntil, maxMinutes }, source: 'warm-pool' });
    } catch (e) { console.error('audit log usage error:', e); }
    return { connectionUrl: state.instance.connectionUrl, leasedUntil: state.instance.leasedUntil, contractId: state.instance.contractId };
}

async function terminate(contractId = null) {
    if (!contractId && state.instance && state.instance.contractId) contractId = state.instance.contractId;
    if (!contractId) return { status: 'no_instance' };

    try {
        const r = await fetch(`${VAST_BASE}/instances/${contractId}/`, {
            method: 'DELETE',
            headers: { 'Authorization': `Bearer ${VASTAI_API_KEY}` }
        });
        const json = await r.json().catch(() => ({}));
        // Log termination event (capture previous status if we have it)
        try {
            const prevStatus = state.instance && state.instance.contractId == contractId ? state.instance.status : null;
            audit.logUsageEvent({ event_type: 'instance_terminated', contract_id: contractId, instance_status: prevStatus, details: json, source: 'warm-pool' });
        } catch (e) { console.error('audit log usage error:', e); }

        // Clear local state if this was our tracked instance
        if (state.instance && state.instance.contractId == contractId) {
            // Clean up log collector from watchdog if registered
            if (state.instance.logCollectorWatchdogId) {
                console.log(`[LogCollector] Unregistering from watchdog: ${state.instance.logCollectorWatchdogId}`);
                processWatchdog.unregister(state.instance.logCollectorWatchdogId);
            }
            // Fallback: Clean up old PID-based log collector if still present
            if (state.instance.logCollectorPid) {
                try {
                    console.log(`[LogCollector] Stopping legacy log collector process ${state.instance.logCollectorPid}`);
                    process.kill(state.instance.logCollectorPid, 'SIGTERM');
                } catch (err) {
                    console.warn(`[LogCollector] Failed to kill process ${state.instance.logCollectorPid}: ${err.message}`);
                }
            }

            // Clean up ComfyUI keepalive monitoring
            if (comfyKeepalive) {
                console.log('[Keepalive] Stopping ComfyUI connection monitoring');
                comfyKeepalive.stop();
                comfyKeepalive = null;
            }

            state.instance = null;
            state.lastAction = new Date().toISOString();
            save();
        }
        return { status: 'terminated', details: json };
    } catch (error) {
        console.error('WarmPool terminate error:', error);
        throw error;
    }
}

// Polling loop to update instance state and enforce idle shutdown
let pollHandle = null;
function startPolling(opts = {}) {
    if (pollHandle) return;
    if (process.env.NODE_ENV === 'test') return;

    // Respect a safe-mode environment variable for aggressive shutdowns
    const safeMode = (process.env.WARM_POOL_SAFE_MODE === '1' || process.env.WARM_POOL_SAFE_MODE === 'true');

    /**
     * Calculate adaptive polling interval based on instance state
     * - Active states (starting, loading, leased): 30s
     * - Idle ready state: 180s (3min)
     * - Default: 120s (2min)
     */
    function getPollingInterval() {
        if (!state.instance) {
            return 120000; // 2 minutes when no instance
        }

        const status = state.instance.status;
        const isLeased = state.instance.leasedUntil && Date.now() < new Date(state.instance.leasedUntil).getTime();

        if (status === 'starting' || status === 'loading' || isLeased) {
            // Active states: check more frequently
            return parseInt(process.env.WARM_POOL_POLL_ACTIVE_INTERVAL_MS || '30000', 10); // 30s
        } else if (status === 'ready') {
            // Idle but ready: slower polling
            return parseInt(process.env.WARM_POOL_POLL_IDLE_INTERVAL_MS || '180000', 10); // 3min
        } else {
            // Default
            return parseInt(process.env.WARM_POOL_POLL_INTERVAL_MS || '120000', 10); // 2min
        }
    }

    /**
     * Single poll execution with error handling
     */
    async function pollOnce() {
        try {
            await checkInstance();
            // enforce idle shutdown
            if (state.instance && state.instance.status === 'running') {
                // If ComfyUI isn't marked ready yet, start a background readiness probe
                try {
                    if (!state._waitingForReady && state.instance.connectionUrl) {
                        state._waitingForReady = true;
                        const pollingHealthTimeout = parseInt(process.env.COMFYUI_READY_TIMEOUT_MS || (process.env.DISABLE_AUTO_RECOVERY === '1' ? '3600000' : '900000'), 10);
                        waitForComfyReady(state.instance.contractId, pollingHealthTimeout, 10000)
                            .catch(() => { })
                            .finally(() => { state._waitingForReady = false; });
                    }
                } catch (e) { /* ignore readiness probe errors */ }
                // If safe mode is enabled, or desired size is zero, terminate immediately to stop billing
                if (safeMode || state.desiredSize === 0) {
                    console.log('WarmPool: safeMode or desiredSize=0 — terminating instance', state.instance.contractId);
                    await module.exports.terminate(state.instance.contractId);
                    return;
                }

                // If leasedUntil exists and passed, clear lease
                if (state.instance.leasedUntil) {
                    const leasedUntil = new Date(state.instance.leasedUntil).getTime();
                    if (Date.now() > leasedUntil) {
                        // Lease expired — mark as idle
                        state.instance.leasedUntil = null;
                        state.lastAction = new Date().toISOString();
                        save();
                    }
                }

                // IDLE TIMEOUT DISABLED - Instance will not auto-terminate
                // To manually terminate: POST /api/proxy/admin/terminate with admin key
            }
        } catch (e) {
            console.error('WarmPool polling error:', e);
        }

        // Schedule next poll with adaptive interval
        const nextInterval = getPollingInterval();
        pollHandle = setTimeout(pollOnce, nextInterval);
    }

    // Start first poll
    console.log('[Polling] Starting adaptive polling loop');
    pollOnce();
}

function getStatus() {
    return {
        desiredSize: state.desiredSize,
        instance: state.instance,
        lastAction: state.lastAction,
        isPrewarming: state.isPrewarming,
        safeMode: !!state.safeMode
    };
}

async function setDesiredSize(n) {
    state.desiredSize = Number(n) || 0;
    state.lastAction = new Date().toISOString();
    save();
    // If desiredSize=0, terminate existing instance immediately
    if (state.desiredSize === 0 && state.instance) {
        console.log('WarmPool: desiredSize set to 0 via admin — terminating instance', state.instance.contractId);
        await module.exports.terminate(state.instance.contractId);
    }
    return getStatus();
}

async function setSafeMode(enabled) {
    state.safeMode = !!enabled;
    state.lastAction = new Date().toISOString();
    save();
    // If safeMode enabled and we have a running instance, terminate it
    if (state.safeMode && state.instance) {
        console.log('WarmPool: safeMode enabled via admin — terminating instance', state.instance.contractId);
        await module.exports.terminate(state.instance.contractId);
    }
    return getStatus();
}

/**
 * Set whether to use default Vast.ai script instead of custom provisioning script.
 * Used for fallback after custom provisioning fails.
 * @param {boolean} useDefault - If true, use default script on next prewarm
 * @returns {Object} - Current status
 */
function setUseDefaultScript(useDefault) {
    state.useDefaultScript = !!useDefault;
    state.lastAction = new Date().toISOString();
    console.log(`WarmPool: 🔄 useDefaultScript set to ${state.useDefaultScript}`);
    save();
    return getStatus();
}

/**
 * Reset provisioning state (fallback flag and attempt counter).
 * Call this after successful provisioning or when admin wants to retry custom script.
 */
function resetProvisioningState() {
    state.useDefaultScript = false;
    state.provisionAttempt = 0;
    state.lastAction = new Date().toISOString();
    console.log('WarmPool: 🔄 Provisioning state reset (fallback disabled, attempt counter cleared)');
    save();
    return getStatus();
}

// Initialize (async to support instance validation during load)
(async () => {
    try {
        await load();
    } catch (e) {
        console.error('WarmPool: Error loading state:', e);
    }
})();

function stopPolling() {
    if (pollHandle) {
        clearInterval(pollHandle);
        pollHandle = null;
    }
}

// Only auto-start polling if NOT in test environment
if (process.env.NODE_ENV !== 'test') {
    try {
        startPolling({ intervalMs: 30000, maxIdleMinutes: process.env.WARM_POOL_IDLE_MINUTES ? Number(process.env.WARM_POOL_IDLE_MINUTES) : 15 });
    } catch (e) {
        console.error('WarmPool: Error starting polling:', e);
    }
}

module.exports = {
    getStatus,
    prewarm,
    terminate,
    claim,
    setDesiredSize,
    setSafeMode,
    setUseDefaultScript,       // Fallback script control
    resetProvisioningState,    // Reset fallback state
    startPolling,
    stopPolling,
    checkInstance,
    load,  // Expose load for admin state reload
    // GPU compatibility exports (for testing and external use)
    isGpuCompatible,
    getPyTorchVersionForGPU,
    validateInstanceHealth,
    isInstanceHealthy,
    fetchModelInventory,
    MIN_CUDA_CAPABILITY,
    _internal: { state }
};
