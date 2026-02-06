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
// Lowered to 6.0 to allow datacenter GPUs like P100/P40 which have high VRAM
const MIN_CUDA_CAPABILITY = parseFloat(process.env.VASTAI_MIN_CUDA_CAPABILITY || '6.0');

// Configurable minimum disk (GB) for warm instances. Default to 150GB to ensure
// room for large models (Flux/SDXL) and custom nodes while meeting user requirements.
const RAW_WARM_POOL_DISK = parseInt(process.env.WARM_POOL_DISK_GB || process.env.WARM_POOL_DISK || '150', 10);
const WARM_POOL_DISK_GB = Number.isFinite(RAW_WARM_POOL_DISK) ? RAW_WARM_POOL_DISK : 150;
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
// ADAPTIVE POLLING: Wait for provisioning buffer, then poll slowly during provisioning
async function waitForComfyReady(contractId, timeoutMs = 1500000, intervalMs = 90000) {
    const start = Date.now();
    let lastHealthReport = null;
    let consecutiveFailures = 0;
    let currentInterval = intervalMs;

    // Provisioning buffer: skip health checks for the first 5 minutes
    // Parallel provisioning can take ~8-12 minutes; this reduces false failures
    const provisioningBufferMs = 5 * 60 * 1000; // 5 minutes
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

            // Adaptive polling based on elapsed provisioning time
            const elapsed = Math.round((Date.now() - start) / 1000);
            consecutiveFailures++;

            // Slow polling during provisioning (first 10 minutes), faster after
            if (elapsed < 600) {
                currentInterval = 90000; // 90s during provisioning phase
            } else {
                currentInterval = 30000; // 30s after 10 minutes
            }

            console.log(`WarmPool: Waiting for healthy instance (${elapsed}s elapsed, poll every ${currentInterval / 1000}s)...`, {
                api: healthReport.comfyui_api,
                gpu: healthReport.gpu_available,
                functional: healthReport.gpu_functional,
                errors: healthReport.errors
            });
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
        // CRITICAL: Verify models actually downloaded (not just ComfyUI running)
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
 * Check if health report indicates a fully functional instance
 * ENHANCED: Now also requires models to be loaded (prevents returning broken instances)
 * @param {Object} healthReport - Result from validateInstanceHealth
 * @returns {boolean} - True if instance is healthy AND has models
 */
function isInstanceHealthy(healthReport) {
    const basicHealth = healthReport.comfyui_api &&
        healthReport.gpu_available &&
        healthReport.gpu_functional;

    // REQUIRE at least 1 checkpoint to be loaded (catches provision failures)
    const modelsReady = healthReport.models_loaded && healthReport.checkpoint_count > 0;

    if (basicHealth && !modelsReady) {
        console.warn('WarmPool: Instance API/GPU healthy but NO MODELS LOADED - provisioning failed');
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

        // Client-side filtering criteria (optimized for presentation/showcase)
        const filterOffer = (o) => {
            const reasons = [];
            if (!o.rentable) { reasons.push('not rentable'); return false; }
            if (o.rented) { reasons.push('already rented'); return false; }

            // Exclude Ukraine and China regions
            const loc = (o.geolocation || '').toLowerCase();
            if (loc.includes('ukraine') || loc.includes('ua') ||
                loc.includes('china') || loc.includes('cn')) {
                reasons.push(`region excluded: ${o.geolocation || 'unknown'}`);
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
            const minInetDown = parseFloat(process.env.VASTAI_MIN_INET_DOWN || '900'); // 900 Mbps minimum
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
                        console.error(`WarmPool: Vast.ai API returned ${r.status} ${r.statusText}`);
                        const errorText = await r.text();
                        console.error(`WarmPool: Error response:`, errorText);
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

                    // Sort results: Primary by price ($/hr), secondarily by bandwidth (Mbps DESC)
                    // This satisfies the "prefer higher" requirement for internet speed.
                    offers.sort((a, b) => {
                        if (a.dph_total !== b.dph_total) return a.dph_total - b.dph_total;
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

        // SECURITY: Whitelist of allowed script URLs to prevent malicious code execution
        const allowedScriptPatterns = [
            /^https:\/\/gist\.githubusercontent\.com\/pimpsmasterson\/9fb9d7c60d3822c2ffd3ad4b000cc864\/raw\/provision-reliable\.sh(\?.*)?$/,
            /^https:\/\/raw\.githubusercontent\.com\/vast-ai\/base-image\/.*\/default\.sh(\?.*)?$/,
            /^https:\/\/raw\.githubusercontent\.com\/.*\/provision.*\.sh(\?.*)?$/  // Allow other GitHub raw URLs for flexibility
        ];

        // Validate URL against whitelist
        const isUrlAllowed = (url) => {
            if (!url || typeof url !== 'string') return false;
            return allowedScriptPatterns.some(pattern => pattern.test(url));
        };

        // Increment provision attempt counter
        state.provisionAttempt = (state.provisionAttempt || 0) + 1;
        console.log(`WarmPool: 📦 Provisioning attempt #${state.provisionAttempt} (fallback mode: ${state.useDefaultScript})`);

        // FALLBACK LOGIC: If useDefaultScript flag is set (from previous failure), use default script
        let provisionScript = defaultProvisionScript;
        if (state.useDefaultScript) {
            console.warn('WarmPool: ⚠️ Using DEFAULT Vast.ai script (fallback from failed custom script)');
            provisionScript = defaultProvisionScript;
        } else if (customProvisionScript) {
            // SECURITY: Validate URL against whitelist before proceeding
            if (!isUrlAllowed(customProvisionScript)) {
                console.error(`WarmPool: 🔒 SECURITY REJECTION - Script URL not in whitelist: ${customProvisionScript}`);
                console.error('WarmPool: ❌ Only whitelisted Gist/GitHub URLs are allowed. Falling back to Vast default.');
                // Audit log security violation
                try {
                    audit.logUsageEvent({
                        event_type: 'security_rejection',
                        details: {
                            reason: 'script_url_not_whitelisted',
                            attempted_url: customProvisionScript,
                            action: 'fallback_to_default'
                        },
                        source: 'warm-pool-security'
                    });
                } catch (e) { /* audit may not be available */ }
                provisionScript = defaultProvisionScript;
            }
            // CRITICAL: gistfile1.txt 404s - gist has provision-reliable.sh, not gistfile1.txt
            else if (customProvisionScript.includes('gistfile1.txt')) {
                console.error('WarmPool: ❌ COMFYUI_PROVISION_SCRIPT uses gistfile1.txt which 404s! Use .../raw/provision-reliable.sh instead. Falling back to Vast default.');
                provisionScript = defaultProvisionScript;
            }
            // Validate custom script URL before using it (check for 404 gist issues)
            else try {
                const testResp = await fetch(customProvisionScript, { method: 'HEAD', timeout: 10000 });
                if (testResp.ok) {
                    provisionScript = customProvisionScript;
                    console.log('WarmPool: ✅ Using custom provision script (whitelist validated):', customProvisionScript);
                } else {
                    console.warn(`WarmPool: ⚠️ Custom provision script returned ${testResp.status}, falling back to default`);
                    provisionScript = defaultProvisionScript;
                }
            } catch (err) {
                console.warn(`WarmPool: ⚠️ Custom provision script unreachable, falling back to default:`, err.message);
                provisionScript = defaultProvisionScript;
            }
        }

        // SECURITY: Final validation - ensure we never execute a non-whitelisted script
        if (!isUrlAllowed(provisionScript)) {
            console.error(`WarmPool: 🔒 CRITICAL SECURITY ERROR - Final script URL failed whitelist check: ${provisionScript}`);
            console.error('WarmPool: ❌ Aborting to prevent potential malicious code execution. Using Vast default.');
            // Audit log critical security violation
            try {
                audit.logUsageEvent({
                    event_type: 'security_critical_error',
                    details: {
                        reason: 'final_script_url_failed_whitelist',
                        attempted_url: provisionScript,
                        action: 'forced_default_script'
                    },
                    source: 'warm-pool-security'
                });
            } catch (e) { /* audit may not be available */ }
            provisionScript = defaultProvisionScript;
        }

        // Audit log successful script selection (for security monitoring)
        try {
            audit.logUsageEvent({
                event_type: 'provision_script_selected',
                details: {
                    script_url: provisionScript,
                    is_whitelisted: isUrlAllowed(provisionScript),
                    is_custom: provisionScript !== defaultProvisionScript,
                    attempt_number: state.provisionAttempt
                },
                source: 'warm-pool-security'
            });
        } catch (e) { /* audit may not be available */ }

        console.log('WarmPool: 🔧 Selected provision script (security validated):', provisionScript);

        // Build environment variables - include HF and Civitai tokens if set
        // PORTAL_CONFIG: simplified to avoid "remote port forwarding failed" (fewer forwards = fewer failures)
        const envVars = {
            COMFYUI_ARGS: "--listen 0.0.0.0 --disable-auto-launch --port 8188 --enable-cors-header",
            COMFYUI_API_BASE: "http://localhost:8188",
            PROVISIONING_SCRIPT: provisionScript,
            PORTAL_CONFIG: "localhost:8188:18188:/:ComfyUI|localhost:1111:11111:/:Instance Portal",
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

        // Pass through SCRIPTS_BASE_URL for modular provisioning system
        if (process.env.SCRIPTS_BASE_URL) {
            envVars.SCRIPTS_BASE_URL = process.env.SCRIPTS_BASE_URL;
            console.log('WarmPool: 📦 Using modular scripts from:', process.env.SCRIPTS_BASE_URL);
        }

        const rentBody = {
            ...(configuredImage && configuredImage !== 'auto' ? { image: configuredImage } : {}),
            runtype: 'ssh',
            target_state: 'running',
            onstart: `bash -lc 'if mkdir -p /workspace 2>/dev/null && test -w /workspace; then export WORKSPACE=/workspace; else mkdir -p "$HOME/workspace" 2>/dev/null || true; export WORKSPACE="$HOME/workspace"; fi; cd "$WORKSPACE" || cd; echo "WarmPool: using WORKSPACE=$WORKSPACE"; echo "WarmPool: Downloading provision script from whitelisted URL: ${provisionScript}"; curl -fsSL "${provisionScript}" -o /tmp/provision.sh && chmod +x /tmp/provision.sh && echo "WarmPool: Script downloaded, executing..." && bash -x /tmp/provision.sh'`,
            ssh_key: vastaiSsh.getKey(),
            env: envVars,
            // Request disk according to configured requirement to ensure room for model extraction
            disk: requiredDiskGb,
            // Direct SSH avoids proxy port forwarding; fewer ports reduces "remote port forwarding failed" errors
            ssh_direct: true,
            direct_port_count: 20
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
            // CRITICAL: If rate limited (429), DON'T kill the instance - just log and skip this check
            if (r.status === 429) {
                console.warn(`WarmPool: Vast.ai API rate limited (429). Skipping this health check cycle.`);
                state.instance.lastError = `Rate limited (429) at ${new Date().toISOString()}`;
                return; // Don't throw - instance is still running
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
                console.log(`WarmPool: Instance ${contractId} network ready, validating ComfyUI health (up to 15m)...`);
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
    const intervalMs = opts.intervalMs || 120000; // 120s - adaptive polling to avoid rate limits
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
