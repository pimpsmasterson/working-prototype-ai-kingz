#!/usr/bin/env node
// Lightweight Express proxy for Vast.ai and ComfyUI to avoid browser CORS issues
// Usage: VASTAI_API_KEY=<key> node server/vastai-proxy.js

const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const fetch = require('node-fetch');
// Load environment variables from .env in development
try { require('dotenv').config(); } catch (e) { /* no dotenv available */ }

const app = express();
const PORT = process.env.PORT || 3000;

// Load critical tokens from environment — do not commit secrets to code
const VASTAI_API_KEY = process.env.VASTAI_API_KEY || process.env.VAST_AI_API_KEY || null;
const HUGGINGFACE_HUB_TOKEN = process.env.HUGGINGFACE_HUB_TOKEN || null;
const CIVITAI_TOKEN = process.env.CIVITAI_TOKEN || null;

// In production, fail fast when critical secrets are missing
if (process.env.NODE_ENV === 'production') {
    if (!VASTAI_API_KEY) {
        console.error('FATAL: VASTAI_API_KEY is required in production. Set environment variable VASTAI_API_KEY and restart.');
        process.exit(1);
    }
    if (!process.env.ADMIN_API_KEY) {
        console.error('FATAL: ADMIN_API_KEY is required in production. Set ADMIN_API_KEY and restart.');
        process.exit(1);
    }
} else {
    if (!VASTAI_API_KEY) console.warn('Warning: VASTAI_API_KEY is not set. Some proxy operations will fail until set.');
    if (!process.env.ADMIN_API_KEY) console.warn('Warning: ADMIN_API_KEY not set. Using development default.');
}

// Make sure other modules can read the variables
if (!process.env.VASTAI_API_KEY && VASTAI_API_KEY) process.env.VASTAI_API_KEY = VASTAI_API_KEY;
if (!process.env.VAST_AI_API_KEY && VASTAI_API_KEY) process.env.VAST_AI_API_KEY = VASTAI_API_KEY;
if (!process.env.HUGGINGFACE_HUB_TOKEN && HUGGINGFACE_HUB_TOKEN) process.env.HUGGINGFACE_HUB_TOKEN = HUGGINGFACE_HUB_TOKEN;
if (!process.env.CIVITAI_TOKEN && CIVITAI_TOKEN) process.env.CIVITAI_TOKEN = CIVITAI_TOKEN;

const VAST_BASE = 'https://console.vast.ai/api/v0';

app.use(cors());
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ extended: true }));

function checkApiKeyOrDie(req, res, next) {
    if (!VASTAI_API_KEY) {
        return res.status(500).json({ error: 'Server VASTAI_API_KEY not configured in environment' });
    }
    next();
}

const warmPool = require('./warm-pool');
const audit = require('./audit');

app.get('/api/proxy/health', (req, res) => {
    const pool = warmPool.getStatus();
    const status = pool.instance && pool.instance.status ? pool.instance.status : 'running';
    res.json({ status, ok: true, now: new Date().toISOString(), warmPool: { desiredSize: pool.desiredSize, instance: pool.instance ? { contractId: pool.instance.contractId, status: pool.instance.status } : null } });
});

// Warm-pool endpoints
app.get('/api/proxy/warm-pool', (req, res) => {
    try {
        res.json(warmPool.getStatus());
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// Simple admin authentication (API key via header 'x-admin-key')
const ADMIN_API_KEY = process.env.ADMIN_API_KEY || 'admin_dev_key';
if (!process.env.ADMIN_API_KEY) process.env.ADMIN_API_KEY = ADMIN_API_KEY;
function requireAdmin(req, res, next) {
    const key = req.headers['x-admin-key'] || req.query.adminKey;
    if (!key || key !== process.env.ADMIN_API_KEY) return res.status(403).json({ error: 'forbidden - invalid admin key' });
    next();
}

// Log admin auth attempts: wrap requireAdmin-like checks where needed
function logAuthAttempt(req, success) {
    try {
        const ip = req.ip || req.connection && req.connection.remoteAddress;
        audit.logAdminEvent({ adminKey: req.headers['x-admin-key'] || req.query.adminKey, ip, route: req.originalUrl, action: 'auth_attempt', outcome: success ? 'success' : 'failure' });
    } catch (e) {
        console.error('logAuthAttempt error:', e);
    }
}

// Admin endpoints for warm-pool control
app.get('/api/proxy/admin/warm-pool', (req, res) => {
    // perform auth check with logging
    const key = req.headers['x-admin-key'] || req.query.adminKey;
    if (!key || key !== process.env.ADMIN_API_KEY) {
        logAuthAttempt(req, false);
        return res.status(403).json({ error: 'forbidden - invalid admin key' });
    }
    logAuthAttempt(req, true);
    try {
        res.json(warmPool.getStatus());
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

app.post('/api/proxy/admin/warm-pool', express.json(), async (req, res) => {
    const key = req.headers['x-admin-key'] || req.query.adminKey;
    if (!key || key !== process.env.ADMIN_API_KEY) {
        logAuthAttempt(req, false);
        return res.status(403).json({ error: 'forbidden - invalid admin key' });
    }
    logAuthAttempt(req, true);
    try {
        const { desiredSize, safeMode } = req.body || {};
        const before = warmPool.getStatus();
        let result = before;
        if (typeof desiredSize !== 'undefined') {
            result = await warmPool.setDesiredSize(desiredSize);
        }
        if (typeof safeMode !== 'undefined') {
            result = await warmPool.setSafeMode(!!safeMode);
        }
        // Audit log the admin change
        try {
            audit.logAdminEvent({ adminKey: key, ip: req.ip || req.connection && req.connection.remoteAddress, route: req.originalUrl, action: 'set_warm_pool', details: { before, after: result }, outcome: 'ok' });
        } catch (e) { console.error('audit log error:', e); }
        res.json(result);
    } catch (e) {
        console.error('admin set warm-pool error:', e);
        res.status(500).json({ error: e.message });
    }
});

// Admin logs listing (protected)
app.get('/api/proxy/admin/logs', (req, res) => {
    const key = req.headers['x-admin-key'] || req.query.adminKey;
    if (!key || key !== process.env.ADMIN_API_KEY) {
        logAuthAttempt(req, false);
        return res.status(403).json({ error: 'forbidden - invalid admin key' });
    }
    logAuthAttempt(req, true);

    const limit = Math.min(100, Number(req.query.limit || 50));
    const offset = Number(req.query.offset || 0);
    const since = req.query.since;
    const actionFilter = req.query.action;

    const db = require('./db').db;
    try {
        const where = [];
        const params = [];
        if (since) { where.push('ts >= ?'); params.push(since); }
        if (actionFilter) { where.push('action = ?'); params.push(actionFilter); }
        const whereClause = where.length ? ('WHERE ' + where.join(' AND ')) : '';

        const totalRow = db.prepare(`SELECT COUNT(*) as c FROM admin_audit ${whereClause}`).get(...params);
        const rows = db.prepare(
            `SELECT id, ts, admin_fingerprint, ip, route, action, details, outcome
             FROM admin_audit ${whereClause}
             ORDER BY ts DESC
             LIMIT ? OFFSET ?`
        ).all(...params, limit, offset);

        const parsed = rows.map(r => {
            let details = null;
            try { details = r.details ? JSON.parse(r.details) : null; } catch (e) { details = r.details; }
            return { id: r.id, ts: r.ts, admin_fingerprint: r.admin_fingerprint, ip: r.ip, route: r.route, action: r.action, details, outcome: r.outcome };
        });

        // Audit the log read
        try {
            audit.logAdminEvent({ adminKey: key, ip: req.ip || req.connection && req.connection.remoteAddress, route: req.originalUrl, action: 'view_logs', details: { limit, offset, since, action: actionFilter }, outcome: 'ok' });
        } catch (e) { console.error('audit log error:', e); }

        res.json({ total: totalRow ? totalRow.c : 0, rows: parsed });
    } catch (e) {
        console.error('admin logs error:', e);
        res.status(500).json({ error: e.message });
    }
});

// Forward arbitrary ComfyUI requests to the active warm instance.
// Example: POST /api/proxy/comfy/flow -> proxied to http://<instance>:8188/flow
app.use('/api/proxy/comfy', async (req, res) => {
    try {
        const pool = warmPool.getStatus();
        if (!pool.instance || !pool.instance.connectionUrl) return res.status(404).json({ error: 'no warm instance available' });
        const targetBase = pool.instance.connectionUrl.replace(/\/$/, '');
        const forwardPath = req.originalUrl.replace(/^\/api\/proxy\/comfy/, '');
        const targetUrl = targetBase + (forwardPath || '/');

        const opts = {
            method: req.method,
            headers: Object.assign({}, req.headers),
            // do not forward host header
        };

        // Remove headers that might cause issues
        delete opts.headers.host;

        if (['POST','PUT','PATCH'].includes(req.method.toUpperCase())) {
            opts.body = JSON.stringify(req.body || {});
            opts.headers['content-type'] = 'application/json';
        }

        const r = await fetch(targetUrl, opts);
        const text = await r.text();
        try { return res.status(r.status).json(JSON.parse(text)); } catch(e) { return res.status(r.status).send(text); }

    } catch (e) {
        console.error('comfy proxy error:', e);
        res.status(502).json({ error: 'comfy proxy error', details: e.message });
    }
});

app.post('/api/proxy/warm-pool/prewarm', async (req, res) => {
    try {
        const result = await warmPool.prewarm();
        res.status(200).json(result);
    } catch (e) {
        console.error('warm-pool prewarm error:', e);
        res.status(500).json({ error: e.message });
    }
});

// Protected termination endpoint
app.post('/api/proxy/warm-pool/terminate', async (req, res) => {
    const key = req.headers['x-admin-key'] || req.query.adminKey;
    if (!key || key !== process.env.ADMIN_API_KEY) {
        logAuthAttempt(req, false);
        return res.status(403).json({ error: 'forbidden - invalid admin key' });
    }
    logAuthAttempt(req, true);
    try {
        const { instanceId } = req.body || {};
        const before = warmPool.getStatus();
        const result = await warmPool.terminate(instanceId);
        // Audit admin termination
        try {
            audit.logAdminEvent({ adminKey: key, ip: req.ip || req.connection && req.connection.remoteAddress, route: req.originalUrl, action: 'terminate', details: { instanceId, before, result }, outcome: 'ok' });
        } catch (e) { console.error('audit log error:', e); }
        res.json(result);
    } catch (e) {
        console.error('warm-pool terminate error:', e);
        res.status(500).json({ error: e.message });
    }
});

// Serve the admin UI page and its JS
app.get('/admin/warm-pool', (req, res) => {
    res.sendFile(require('path').join(__dirname, '..', 'pages', 'admin-warm-pool.html'));
});
app.get('/assets/js/admin-warm-pool.js', (req, res) => {
    res.sendFile(require('path').join(__dirname, '..', 'assets', 'js', 'admin-warm-pool.js'));
});

app.post('/api/proxy/warm-pool/claim', async (req, res) => {
    try {
        const body = req.body || {};
        const maxMinutes = typeof body.maxMinutes !== 'undefined' ? body.maxMinutes : (typeof body.maxSessionMinutes !== 'undefined' ? body.maxSessionMinutes : 30);
        const claim = await warmPool.claim(maxMinutes || 30);
        if (!claim) return res.status(404).json({ error: 'no available instance' });
        res.json(claim);
    } catch (e) {
        console.error('warm-pool claim error:', e);
        res.status(500).json({ error: e.message });
    }
});

// Proxy ComfyUI prompt - server-side fetch avoids CORS and follows redirects
app.post('/api/proxy/prompt', checkApiKeyOrDie, async (req, res) => {
    try {
        const target = `${VAST_BASE}/prompt`;
        const r = await fetch(target, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${VASTAI_API_KEY}`
            },
            body: JSON.stringify(req.body),
            // Node fetch will follow redirects by default
        });

        const text = await r.text();
        try {
            const json = JSON.parse(text);
            return res.status(r.status).json(json);
        } catch (e) {
            return res.status(r.status).send(text);
        }
    } catch (error) {
        console.error('Proxy /prompt error:', error);
        return res.status(502).json({ error: 'Proxy error', details: error.message });
    }
});

// Instance management proxies
app.post('/api/proxy/instances/create', checkApiKeyOrDie, async (req, res) => {
    try {
        const r = await fetch(`${VAST_BASE}/instances/create/`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${VASTAI_API_KEY}`
            },
            body: JSON.stringify(req.body)
        });
        const json = await r.json();
        res.status(r.status).json(json);
    } catch (error) {
        console.error('Proxy create instance error:', error);
        res.status(502).json({ error: 'Proxy error', details: error.message });
    }
});

// Search for available GPU offers
app.post('/api/proxy/bundles', checkApiKeyOrDie, async (req, res) => {
    try {
        const r = await fetch(`${VAST_BASE}/bundles/`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${VASTAI_API_KEY}`
            },
            body: JSON.stringify(req.body)
        });
        const json = await r.json();
        res.status(r.status).json(json);
    } catch (error) {
        console.error('Proxy bundles search error:', error);
        res.status(502).json({ error: 'Proxy error', details: error.message });
    }
});

// Rent an instance (PUT to /asks/:id/)
app.put('/api/proxy/asks/:id', checkApiKeyOrDie, async (req, res) => {
    try {
        const { id } = req.params;
        const r = await fetch(`${VAST_BASE}/asks/${id}/`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${VASTAI_API_KEY}`
            },
            body: JSON.stringify(req.body)
        });
        const json = await r.json();
        res.status(r.status).json(json);
    } catch (error) {
        console.error('Proxy rent instance error:', error);
        res.status(502).json({ error: 'Proxy error', details: error.message });
    }
});

app.get('/api/proxy/instances/:id', checkApiKeyOrDie, async (req, res) => {
    try {
        const { id } = req.params;
        const r = await fetch(`${VAST_BASE}/instances/${id}/`, {
            headers: { 'Authorization': `Bearer ${VASTAI_API_KEY}` }
        });
        const json = await r.json();
        res.status(r.status).json(json);
    } catch (error) {
        console.error('Proxy get instance error:', error);
        res.status(502).json({ error: 'Proxy error', details: error.message });
    }
});

app.delete('/api/proxy/instances/:id', checkApiKeyOrDie, async (req, res) => {
    try {
        const { id } = req.params;
        const r = await fetch(`${VAST_BASE}/instances/${id}/`, {
            method: 'DELETE',
            headers: { 'Authorization': `Bearer ${VASTAI_API_KEY}` }
        });
        const json = await r.json();
        res.status(r.status).json(json);
    } catch (error) {
        console.error('Proxy delete instance error:', error);
        res.status(502).json({ error: 'Proxy error', details: error.message });
    }
});

app.get('/api/proxy/instances', checkApiKeyOrDie, async (req, res) => {
    try {
        const r = await fetch(`${VAST_BASE}/instances/`, {
            headers: { 'Authorization': `Bearer ${VASTAI_API_KEY}` }
        });
        const json = await r.json();
        res.status(r.status).json(json);
    } catch (error) {
        console.error('Proxy list instances error:', error);
        res.status(502).json({ error: 'Proxy error', details: error.message });
    }
});

// Add Civitai API integration for model downloads
async function downloadCivitaiModel(modelId) {
    const apiUrl = `https://civitai.com/api/v1/models/${modelId}`;
    const civitaiToken = process.env.CIVITAI_TOKEN || null;
    const headers = civitaiToken ? { Authorization: `Bearer ${civitaiToken}` } : {};

    try {
        const response = await fetch(apiUrl, { headers });
        if (!response.ok) throw new Error(`Civitai API error: ${response.status}`);

        const modelData = await response.json();
        const downloadUrl = modelData.modelVersions[0]?.files[0]?.downloadUrl;
        if (!downloadUrl) throw new Error('No download URL found');

        // Attempt to download the model file; pass civitai token if we have one
        const downloadResponse = await fetch(downloadUrl, { headers });
        if (!downloadResponse.ok) {
            // Provide a helpful error if token is likely required
            if (downloadResponse.status === 403 || downloadResponse.status === 401) {
                throw new Error('Download access denied (401/403). Ensure CIVITAI_TOKEN is set on the server for private model downloads.');
            }
            throw new Error(`Download failed: ${downloadResponse.status}`);
        }

        return await downloadResponse.buffer();
    } catch (error) {
        console.error('Civitai download error:', error);
        throw error;
    }
}

// Add endpoint to download Civitai models
app.post('/api/proxy/download-civitai', async (req, res) => {
    const { modelId } = req.body;
    const civitaiToken = process.env.CIVITAI_TOKEN || null;

    if (!modelId) return res.status(400).json({ error: 'modelId required' });

    try {
        const buffer = await downloadCivitaiModel(modelId);
        res.setHeader('Content-Type', 'application/octet-stream');
        res.setHeader('Content-Disposition', `attachment; filename="${modelId}.safetensors"`);
        res.send(buffer);
    } catch (error) {
        console.error('download-civitai error:', error.message);
        if (error.message && error.message.includes('CIVITAI_TOKEN')) {
            return res.status(403).json({ error: error.message });
        }
        res.status(500).json({ error: error.message });
    }
});

// Dev helper: forward a request from the proxy to any target URL (useful to reach ComfyUI on remote instance)
// WARNING: This is a development convenience. Do NOT enable unrestricted forwarding in production.
app.post('/api/proxy/forward', checkApiKeyOrDie, async (req, res) => {
    const { targetUrl, payload } = req.body || {};
    if (!targetUrl) return res.status(400).json({ error: 'targetUrl required' });

    try {
        const r = await fetch(targetUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload || {})
        });

        const text = await r.text();
        try {
            const json = JSON.parse(text);
            return res.status(r.status).json(json);
        } catch (e) {
            return res.status(r.status).send(text);
        }
    } catch (error) {
        console.error('Proxy forward error:', error);
        res.status(502).json({ error: 'Proxy forward error', details: error.message });
    }
});

// Check presence of required tokens (Hugging Face / Civitai / Vast.ai)
app.get('/api/proxy/check-tokens', (req, res) => {
    res.json({
        huggingface: !!process.env.HUGGINGFACE_HUB_TOKEN,
        civitai: !!process.env.CIVITAI_TOKEN,
        vastai: !!VASTAI_API_KEY
    });
});

// Admin helper: set tokens at runtime (LOCALHOST ONLY). This stores tokens in process.env for the running process only.
app.post('/api/proxy/admin/set-tokens', (req, res) => {
    // Only allow local requests
    const remote = req.ip || req.connection.remoteAddress;
    if (!['::1','127.0.0.1','::ffff:127.0.0.1'].includes(remote)) {
        return res.status(403).json({ error: 'Forbidden - set tokens only allowed from localhost' });
    }

    const { huggingface, civitai } = req.body || {};
    if (huggingface) process.env.HUGGINGFACE_HUB_TOKEN = huggingface;
    if (civitai) process.env.CIVITAI_TOKEN = civitai;

    res.json({ huggingface: !!process.env.HUGGINGFACE_HUB_TOKEN, civitai: !!process.env.CIVITAI_TOKEN });
});

// Call cleanupRetention at startup to prune old logs (best-effort)
try {
    audit && typeof audit.cleanupRetention === 'function' && audit.cleanupRetention();
} catch (e) { /* ignore */ }

// Wrapper for starting the server
function startProxy(port = PORT) {
    return app.listen(port, '0.0.0.0', () => {
        console.log(`Vast.ai proxy running on http://localhost:${port}/ (ready)`);
    });
}

// Only listen if run directly
if (require.main === module) {
    startProxy(PORT);
}

module.exports = app;
