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

let state = {
    desiredSize: 1,
    instance: null, // { contractId, status, connectionUrl, createdAt, lastHeartbeat, leasedUntil }
    lastAction: null,
    isPrewarming: false,
    safeMode: false
};

function load() {
    try {
        const row = db.getState();
        if (row) {
            state = Object.assign(state, row);
        }
    } catch (e) {
        console.error('WarmPool load failed:', e);
    }
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
    if (!VASTAI_API_KEY) throw new Error('VASTAI_API_KEY not set on server');
    if (state.isPrewarming) return { status: 'already_prewarming' };

    if (state.instance && (state.instance.status === 'starting' || state.instance.status === 'running')) {
        return { status: 'already_present', instance: state.instance };
    }

    state.isPrewarming = true;
    state.lastAction = new Date().toISOString();
    save();

    try {
        // Minimal bundle search: prefer cheap interruptible offers
        const searchParams = {
            verified: { eq: true },
            rentable: { eq: true },
            rented: { eq: false },
            type: 'bid',
            dph_total: { lte: 2.0 },
            gpu_ram: { gte: 8192 },
            order: [['dph_total', 'asc']]
        };

        // Robust bundle search with retries and a relaxed fallback
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
                    const offers = data.offers || [];
                    if (offers.length) return offers;
                    console.warn(`WarmPool: bundle search attempt ${i} returned 0 offers`);
                } catch (err) {
                    console.error(`WarmPool: bundle search attempt ${i} error:`, err && err.message ? err.message : err);
                }
                // backoff
                await new Promise(res => setTimeout(res, 1000 * i));
            }

            // Relaxed fallback: fall back to a minimal server search and filter client-side
            console.warn('WarmPool: no offers found in initial searches — trying minimal server search and client-side filtering');
            try {
                const r2 = await fetch(`${VAST_BASE}/bundles/`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${VASTAI_API_KEY}`
                    },
                    body: JSON.stringify({ order: [['dph_total','asc']] })
                });
                const data2 = await r2.json();
                const allOffers = data2.offers || [];
                // Apply client-side filtering equivalent to original params where possible
                const filtered = allOffers.filter(o => {
                    try {
                        if (params.verified && params.verified.eq === true && !(o.verification && (o.verification === 'verified' || o.verification === 'verifed' || o.verification === 'verifie'))) return false;
                        if (params.rentable && params.rentable.eq === true && !o.rentable) return false;
                        if (params.rented && params.rented.eq === false && o.rented) return false;
                        if (params.dph_total && params.dph_total.lte && o.dph_total > params.dph_total.lte) return false;
                        if (params.gpu_ram && params.gpu_ram.gte && o.gpu_ram < params.gpu_ram.gte) return false;
                    } catch (e) { return false; }
                    return true;
                });
                return filtered;
            } catch (err) {
                console.error('WarmPool: minimal bundle search error:', err && err.message ? err.message : err);
                return [];
            }
        }

        const offers = await searchBundles(searchParams);
        if (!offers.length) throw new Error('No offers found after retries and fallback');

        const offer = offers[0];

        // Rent the selected offer via asks PUT
        const rentBody = {
            image: 'pytorch/pytorch:latest',
            runtype: 'ssh',
            target_state: 'running',
            // Run ComfyUI in the foreground so the container stays alive. Use a shell wrapper
            onstart: `bash -lc "cd /root || exit 0; if [ ! -d ComfyUI ]; then git clone https://github.com/comfyanonymous/ComfyUI.git || true; fi; cd ComfyUI || exit 0; pip install -r requirements.txt || true; pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 || true; python main.py --listen 0.0.0.0 --port 8188"`,
            env: { 'PYTHONPATH': '/root/ComfyUI' },
            disk: 32
        };

        const rentResp = await fetch(`${VAST_BASE}/asks/${offer.id}/`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${VASTAI_API_KEY}`
            },
            body: JSON.stringify(rentBody)
        });

        const rentData = await rentResp.json();
        if (!rentResp.ok) {
            throw new Error(JSON.stringify(rentData));
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
        // Immediately start a status check
        await checkInstance();
        return { status: 'started', instance: state.instance };
    } catch (error) {
        console.error('WarmPool prewarm error:', error);
        state.lastAction = new Date().toISOString();
        save();
        throw error;
    } finally {
        state.isPrewarming = false;
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
            throw new Error(`instances status error ${r.status} ${txt}`);
        }
            const instance = await r.json();
        // Vast.ai proxy returns wrapper objects; normalize to the inner instance object
        const inst = instance.instances || instance.instance || instance;
        state.instance.lastHeartbeat = new Date().toISOString();
        // Prefer explicit actual_status, fall back to status fields
        state.instance.status = inst.actual_status || inst.status || state.instance.status;
        // Set connection url when instance is running and public ip is available
        if ((inst.actual_status === 'running' || inst.status === 'running') && inst.public_ipaddr) {
            state.instance.connectionUrl = `http://${inst.public_ipaddr}:8188`;
        }
        // Record status message for audit/debugging
        if (inst.status_msg) {
            state.instance.lastStatusMessage = inst.status_msg;
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
    // If instance is ready, lease it
    if (!state.instance) return null;
    if (state.instance.status !== 'running' || !state.instance.connectionUrl) return null;

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
load();

function stopPolling() {
    if (pollHandle) {
        clearInterval(pollHandle);
        pollHandle = null;
    }
}

// Only auto-start polling if NOT in test environment
if (process.env.NODE_ENV !== 'test') {
    startPolling({ intervalMs: 30000, maxIdleMinutes: process.env.WARM_POOL_IDLE_MINUTES ? Number(process.env.WARM_POOL_IDLE_MINUTES) : 15 });
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
    _internal: { state }
};
