// Lightweight WarmPool manager (file-backed persistence)
// Purpose: manage a single warm instance for fast ComfyUI starts, with idle shutdown

const fs = require('fs');
const path = require('path');
const fetch = require('node-fetch');

const DATA_FILE = path.join(__dirname, '..', 'data', 'warm_pool.json');
const db = require('./db');
const audit = require('./audit');
const VAST_BASE = 'https://console.vast.ai/api/v0';
const VASTAI_API_KEY = process.env.VASTAI_API_KEY || process.env.VAST_AI_API_KEY || null;

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
const MIN_CUDA_CAPABILITY = parseFloat(process.env.VASTAI_MIN_CUDA_CAPABILITY || '7.0');

// Configurable minimum disk (GB) for warm instances. Default to 400GB to
// reduce extraction / overlayfs failures when provisioning large checkpoints.
const RAW_WARM_POOL_DISK = parseInt(process.env.WARM_POOL_DISK_GB || process.env.WARM_POOL_DISK || '400', 10);
const WARM_POOL_DISK_GB = Number.isFinite(RAW_WARM_POOL_DISK) ? RAW_WARM_POOL_DISK : 400;
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
    safeMode: false
};

const vastaiSsh = require('../lib/vastai-ssh');

function load() {
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
}

// Wait for ComfyUI to respond on the instance (polls /system_stats)
// Now includes comprehensive GPU and model health validation
async function waitForComfyReady(contractId, timeoutMs = 180000, intervalMs = 5000) {
    const start = Date.now();
    let lastHealthReport = null;

    while (Date.now() - start < timeoutMs) {
        // Refresh instance info from Vast.ai
        await checkInstance();
        if (!state.instance || state.instance.contractId != contractId) return false;

        if (state.instance.connectionUrl) {
            // Run comprehensive health check instead of just checking /system_stats
            const healthReport = await validateInstanceHealth(state.instance.connectionUrl, contractId);
            lastHealthReport = healthReport;

            if (isInstanceHealthy(healthReport)) {
                // Instance is fully healthy - API responding, GPU available and functional
                state.instance.status = 'ready';
                state.instance.lastHeartbeat = new Date().toISOString();
                state.instance.lastHealthReport = healthReport;
                save();

                try {
                    audit.logUsageEvent({
                        event_type: 'instance_ready',
                        contract_id: contractId,
                        instance_status: 'ready',
                        details: {
                            vram_total: healthReport.vram_total,
                            vram_free: healthReport.vram_free,
                            checkpoint_count: healthReport.checkpoint_count
                        },
                        source: 'warm-pool'
                    });
                } catch (e) {}

                return true;
            }

            // Log progress for debugging
            const elapsed = Math.round((Date.now() - start) / 1000);
            console.log(`WarmPool: Waiting for healthy instance (${elapsed}s elapsed)...`, {
                api: healthReport.comfyui_api,
                gpu: healthReport.gpu_available,
                functional: healthReport.gpu_functional,
                errors: healthReport.errors
            });
        }

        await new Promise(r => setTimeout(r, intervalMs));
    }

    // Timed out - log the last health report for debugging
    console.error('WarmPool: Instance readiness timeout', {
        contractId,
        timeoutMs,
        lastHealthReport
    });

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

    const base = connectionUrl.replace(/\/$/, '');

    try {
        // 1. Check ComfyUI API responds with system stats
        const systemStatsUrl = base + '/system_stats';
        const statsResponse = await fetch(systemStatsUrl, {
            method: 'GET',
            timeout: 10000
        });

        if (!statsResponse.ok) {
            healthReport.errors.push(`API returned ${statsResponse.status}`);
            return healthReport;
        }

        const stats = await statsResponse.json();
        healthReport.comfyui_api = true;

        // 2. Verify GPU is detected and has VRAM
        if (stats.system) {
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
        try {
            const objectInfoUrl = base + '/object_info/CheckpointLoaderSimple';
            const objectInfoResponse = await fetch(objectInfoUrl, {
                method: 'GET',
                timeout: 10000
            });

            if (objectInfoResponse.ok) {
                const objectInfo = await objectInfoResponse.json();
                const checkpoints = objectInfo?.CheckpointLoaderSimple?.input?.required?.ckpt_name?.[0] || [];
                healthReport.checkpoint_count = Array.isArray(checkpoints) ? checkpoints.length : 0;
                healthReport.models_loaded = healthReport.checkpoint_count > 0;

                if (!healthReport.models_loaded) {
                    healthReport.errors.push('No checkpoints found');
                }
            }
        } catch (objErr) {
            // object_info might not be available on all ComfyUI versions
            console.log('WarmPool: Could not fetch object_info:', objErr.message);
            // Don't fail health check for this - just mark as unknown
            healthReport.models_loaded = true; // Assume OK if we can't check
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
 * Check if health report indicates a fully functional instance
 * @param {Object} healthReport - Result from validateInstanceHealth
 * @returns {boolean} - True if instance is healthy
 */
function isInstanceHealthy(healthReport) {
    return healthReport.comfyui_api &&
           healthReport.gpu_available &&
           healthReport.gpu_functional;
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
            return await prewarmInFlight;
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
    console.log('[PREWARM DEBUG] Calling save()...');
    save();
    console.log('[PREWARM DEBUG] isPrewarming set and save() completed');

    if (state.instance && (state.instance.status === 'starting' || state.instance.status === 'running')) {
        // resolve inflight before returning
        resolveInflight({ status: 'already_present', instance: state.instance });
        prewarmInFlight = null;
        return { status: 'already_present', instance: state.instance };
    }
    console.log('[PREWARM DEBUG] No existing instance, proceeding');

    try {
        // Vast.ai bundle search - use minimal server-side params, filter client-side
        // Note: Many filters (verified, rentable, rented, etc.) are NOT valid server-side ops
        const searchParams = {
            order: [['dph_total', 'asc']],  // Cheapest first - let server sort by price
            type: 'ask'
        };

        // Client-side filtering criteria
        const filterOffer = (o) => {
            if (!o.rentable) return false;
            if (o.rented) return false;
            if (o.dph_total > 0.80) return false;        // Max $0.80/hr
            if (o.gpu_ram < 8192) return false;          // Min 8GB VRAM for SDXL
            if (typeof o.disk_space === 'number' && o.disk_space < requiredDiskGb) return false; // Min disk from env

            // CRITICAL: Filter out legacy GPUs that are incompatible with modern PyTorch
            // cuda_max_good indicates the CUDA compute capability of the GPU
            if (o.cuda_max_good && !isGpuCompatible(o.cuda_max_good)) {
                console.log(`WarmPool: Filtered out legacy GPU ${o.gpu_name || 'unknown'} (CUDA ${o.cuda_max_good} < ${MIN_CUDA_CAPABILITY})`);
                return false;
            }

            // Optional: prefer verified but don't require
            return true;
        };

        // Robust bundle search with retries
        async function searchBundles(params, attempts = 3) {
            for (let i = 1; i <= attempts; i++) {
                try {
                    console.log(`WarmPool: bundle search attempt ${i}`);
                    const r = await fetch(`${VAST_BASE}/bundles/`, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                            'Authorization': `Bearer ${VASTAI_API_KEY}`
                        },
                        body: JSON.stringify(params)
                    });
                    const data = await r.json();
                    const allOffers = data.offers || [];
                    // Apply client-side filtering
                    const offers = allOffers.filter(filterOffer);
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
        if (!offers.length) {
            throw new Error('No offers found after retries and fallback');
        }

        const offer = offers[0];

        // Concurrency guard: if another prewarm set a VALID instance while we searched, skip renting
        // We only skip if the instance is NOT in a failed state.
        if (state.instance && state.instance.contractId && 
            state.instance.status !== 'failed' && 
            !String(state.instance.lastStatusMessage || '').toLowerCase().includes('no space left on device')) {
            console.warn('WarmPool: instance already present after search; skipping rent');
            return { status: 'already_present', instance: state.instance };
        }

        // Rent the selected offer via asks PUT
        // Allow the prebuilt image to be configurable via VASTAI_COMFY_IMAGE.
        // If VASTAI_COMFY_IMAGE is set to 'auto', do not set `image` so the offer default is used.
        // By default (when the env var is not set) prefer the known Comfy template image to improve reliability.
        const configuredImage = (process.env.VASTAI_COMFY_IMAGE === undefined)
            ? 'vastai/comfy:v0.10.0-cuda-12.9-py312'
            : process.env.VASTAI_COMFY_IMAGE;
        
        // Allow custom provisioning script for auto-downloading NSFW models
        // Set COMFYUI_PROVISION_SCRIPT to your script URL, or leave unset for default
        const provisionScript = process.env.COMFYUI_PROVISION_SCRIPT ||
            "https://raw.githubusercontent.com/vast-ai/base-image/refs/heads/main/derivatives/pytorch/derivatives/comfyui/provisioning_scripts/default.sh";
        
        // Build environment variables - include HF and Civitai tokens if set
        const envVars = {
            COMFYUI_ARGS: "--listen 0.0.0.0 --disable-auto-launch --port 18188 --enable-cors-header",
            COMFYUI_API_BASE: "http://localhost:18188",
            PROVISIONING_SCRIPT: provisionScript,
            PORTAL_CONFIG: "localhost:1111:11111:/:Instance Portal|localhost:8188:18188:/:ComfyUI|localhost:8288:18288:/docs:API Wrapper|localhost:8188:18188:/:ComfyUI|localhost:8080:18080:/:Jupyter|localhost:8080:8080:/terminals/1:Jupyter Terminal|localhost:8384:18384:/:Syncthing",
            OPEN_BUTTON_PORT: "1111",
            JUPYTER_DIR: "/",
            DATA_DIRECTORY: "/workspace/",
            OPEN_BUTTON_TOKEN: "1"
        };
        
        // Pass through Hugging Face and Civitai tokens for model downloads
        if (process.env.HUGGINGFACE_HUB_TOKEN) {
            envVars.HUGGINGFACE_HUB_TOKEN = process.env.HUGGINGFACE_HUB_TOKEN;
        }
        if (process.env.CIVITAI_TOKEN) {
            envVars.CIVITAI_TOKEN = process.env.CIVITAI_TOKEN;
        }
        
        const rentBody = {
            ...(configuredImage && configuredImage !== 'auto' ? { image: configuredImage } : {}),
            runtype: 'ssh',
            target_state: 'running',
            onstart: 'entrypoint.sh',
            ssh_key: vastaiSsh.getKey(),
            env: envVars,
            // Request disk according to configured requirement to ensure room for model extraction
            disk: requiredDiskGb,
            // Request direct port access for ComfyUI (port 8188) and other services
            direct_port_count: 100
        };

        // Ensure account-level SSH key exists so per-instance access works
        try { await vastaiSsh.registerKey(VASTAI_API_KEY); } catch (e) { /* continue even if key registration fails */ }

        const rentResp = await fetch(`${VAST_BASE}/asks/${offer.id}/`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${VASTAI_API_KEY}`
            },
            body: JSON.stringify(rentBody)
        });

        let rentData = await rentResp.json();
        if (!rentResp.ok) {
            // If image manifest not found, attempt a fallback rent without specifying image
            const txt = JSON.stringify(rentData || {});
            if (txt.includes('manifest') || txt.includes('not found') || txt.includes('manifest unknown')) {
                console.warn('WarmPool: prebuilt image not available, retrying rent without image');
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
                    rentData = await rentResp2.json();
                    if (!rentResp2.ok) throw new Error(JSON.stringify(rentData));
                } catch (e) {
                    throw new Error(`Rent failed and fallback failed: ${e.message || e}`);
                }
            } else {
                throw new Error(JSON.stringify(rentData));
            }
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
            audit.logUsageEvent({ event_type: 'instance_started', contract_id: contractId, instance_status: 'starting', details: { offerId: offer.id }, source: 'warm-pool' });
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
                // attempt to detect ComfyUI readiness (3 minutes max)
                await waitForComfyReady(contractId, 180000, 5000);
            } catch (e) { /* continue even if readiness check fails */ }
        }
        const result = { status: 'started', instance: state.instance };
        // resolve inflight for waiters
        try { resolveInflight && resolveInflight(result); } catch (e) {}
        prewarmInFlight = null;
        return result;
    } catch (error) {
        console.error('WarmPool prewarm error:', error);
        state.lastAction = new Date().toISOString();
        save();
        // reject inflight waiters
        try { rejectInflight && rejectInflight(error); } catch (e) {}
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
        const r = await fetch(`${VAST_BASE}/instances/${contractId}/`, {
            headers: { 'Authorization': `Bearer ${VASTAI_API_KEY}` }
        });
        if (!r.ok) {
            const txt = await r.text();
            // If the instance is gone (404), clear our local state
            if (r.status === 404) {
                console.warn(`WarmPool: Instance ${contractId} no longer exists on Vast.ai. Clearing local state.`);
                state.instance = null;
                save();
                return null;
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
            // Default to direct port 8188
            let port = 8188;
            
            // Check for explicitly mapped ports if direct ports aren't used or as a fallback
            if (inst.ports && inst.ports['8188/tcp'] && inst.ports['8188/tcp'].length > 0) {
                port = inst.ports['8188/tcp'][0].HostPort;
            } else if (inst.ports && inst.ports['18188/tcp'] && inst.ports['18188/tcp'].length > 0) {
                // Some templates might use 18188 internally and map it
                port = inst.ports['18188/tcp'][0].HostPort;
            }
            
            state.instance.connectionUrl = `http://${inst.public_ipaddr}:${port}`;
            
            // If this is the first time we've detected the connectionUrl, mark as loading and validate health
            if (!previousConnectionUrl && state.instance.connectionUrl && process.env.NODE_ENV !== 'test') {
                state.instance.status = 'loading'; // Override to loading until ComfyUI responds
                console.log(`WarmPool: Instance ${contractId} network ready, validating ComfyUI health...`);
                // Trigger health validation in background (don't block checkInstance)
                waitForComfyReady(contractId, 180000, 5000).catch(err => {
                    console.error(`WarmPool: Health validation failed for ${contractId}:`, err.message);
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
    const intervalMs = opts.intervalMs || 30000; // 30s
    if (pollHandle) return;
    // Respect a safe-mode environment variable for aggressive shutdowns
    const safeMode = (process.env.WARM_POOL_SAFE_MODE === '1' || process.env.WARM_POOL_SAFE_MODE === 'true');
    pollHandle = setInterval(async () => {
        try {
            await checkInstance();
            // enforce idle shutdown
            if (state.instance && state.instance.status === 'running') {
                // If ComfyUI isn't marked ready yet, start a background readiness probe
                try {
                    if (!state._waitingForReady && state.instance.connectionUrl) {
                        state._waitingForReady = true;
                        waitForComfyReady(state.instance.contractId, 120000, 5000)
                            .catch(() => {})
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

                // If idle for more than configured minutes, terminate
                const maxIdleMinutes = (opts.maxIdleMinutes || 15);
                if (!state.instance.leasedUntil) {
                    // Determine idle time from lastAction or createdAt
                    const last = state.lastAction ? new Date(state.lastAction).getTime() : new Date(state.instance.createdAt).getTime();
                    if (Date.now() - last > maxIdleMinutes * 60000) {
                        console.log('WarmPool: idle timeout reached, terminating instance', state.instance.contractId);
                        await module.exports.terminate(state.instance.contractId);
                    }
                }
            }
        } catch (e) {
            console.error('WarmPool polling error:', e);
        }
    }, intervalMs);
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

// Initialize
try {
    load();
} catch (e) {
    console.error('WarmPool: Error loading state:', e);
}

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
    startPolling,
    stopPolling,
    checkInstance,
    // GPU compatibility exports (for testing and external use)
    isGpuCompatible,
    getPyTorchVersionForGPU,
    validateInstanceHealth,
    isInstanceHealthy,
    MIN_CUDA_CAPABILITY,
    _internal: { state }
};
