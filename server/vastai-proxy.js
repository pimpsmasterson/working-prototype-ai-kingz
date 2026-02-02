#!/usr/bin/env node
// Lightweight Express proxy for Vast.ai and ComfyUI to avoid browser CORS issues
// Usage: VASTAI_API_KEY=<key> node server/vastai-proxy.js

// Load environment variables from .env file
require('dotenv').config();

// Global error handlers to prevent silent crashes
process.on('unhandledRejection', (reason, promise) => {
    console.error('❌ Unhandled Promise Rejection:', reason);
    console.error('Promise:', promise);
    console.error('Server will continue running...');
});

process.on('uncaughtException', (error) => {
    console.error('❌ Uncaught Exception:', error);
    console.error('Stack:', error.stack);
    console.error('Server will continue running...');
});

process.on('beforeExit', (code) => {
    console.log('⚠️ Process is about to exit with code:', code);
});

process.on('exit', (code) => {
    console.log('⚠️ Process exiting with code:', code);
});

const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const fetch = require('node-fetch');
const path = require('path');
// Load environment variables from .env in development
try { require('dotenv').config(); } catch (e) { /* no dotenv available */ }
const fs = require('fs');
const pm2 = require('pm2');
const tokenManager = require('../lib/token-manager');

// Start periodic token validation (every 10 minutes)
tokenManager.startPeriodicValidation(600000);

// Listen for token failures
tokenManager.on('token-invalid', ({ service, error }) => {
  console.error(`❌ ${service} token validation FAILED: ${error}`);
  console.error(`   Please update ${service.toUpperCase()}_TOKEN in your .env file`);
});

tokenManager.on('token-validated', ({ service }) => {
  console.log(`✅ ${service} token validated successfully`);
});

// Validate required environment variables
const requiredEnvVars = [
    'VASTAI_API_KEY',
    'ADMIN_API_KEY'
];

const missingVars = requiredEnvVars.filter(varName => !process.env[varName]);
if (missingVars.length > 0) {
    console.error('FATAL: Missing required environment variables:');
    missingVars.forEach(varName => console.error(`  - ${varName}`));
    console.error('\nPlease set these variables before starting the server.');
    console.error('Example: VASTAI_API_KEY=xxx ADMIN_API_KEY=yyy node server/vastai-proxy.js');
    process.exit(1);
}

// Warn about optional but recommended environment variables
const recommendedVars = ['HUGGINGFACE_HUB_TOKEN', 'COMFYUI_PROVISION_SCRIPT'];
const missingRecommended = recommendedVars.filter(varName => !process.env[varName]);
if (missingRecommended.length > 0) {
    console.warn('⚠️ Warning: Missing recommended environment variables:');
    missingRecommended.forEach(varName => console.warn(`  - ${varName}`));
    console.warn('Some features may not work correctly without these.\n');
}

// Persistent token file stored in project root. This allows setting tokens via
// the admin endpoint and having them survive process restarts without
// manually editing environment variables.
const TOKEN_STORE_PATH = path.join(__dirname, '..', '.proxy-tokens.json');
const HOME_TOKEN_PATH = path.join(process.env.HOME || process.env.USERPROFILE || '', '.proxy-tokens.json');

function loadPersistentTokens() {
    try {
        // Prefer home token file if present (one file to rule them all)
        const candidates = [HOME_TOKEN_PATH, TOKEN_STORE_PATH];
        for (const p of candidates) {
            if (!p) continue;
            if (fs.existsSync(p)) {
                const raw = fs.readFileSync(p, 'utf8');
                const obj = JSON.parse(raw || '{}');
                if (obj.vastai) process.env.VASTAI_API_KEY = process.env.VASTAI_API_KEY || obj.vastai;
                if (obj.huggingface) process.env.HUGGINGFACE_HUB_TOKEN = process.env.HUGGINGFACE_HUB_TOKEN || obj.huggingface;
                if (obj.civitai) process.env.CIVITAI_TOKEN = process.env.CIVITAI_TOKEN || obj.civitai;
                console.log('Loaded persistent tokens from', p);
                break;
            }
        }
    } catch (e) {
        console.warn('Failed to load persistent tokens:', e && e.message ? e.message : e);
    }
}
loadPersistentTokens();

const app = express();
const PORT = process.env.PORT || 3000;

// Normalize admin header/query variants so scripts using different header names work
app.use((req, res, next) => {
    try {
        if (req.headers && req.headers['x-admin-api-key'] && !req.headers['x-admin-key']) {
            req.headers['x-admin-key'] = req.headers['x-admin-api-key'];
        }
        if (req.query && req.query['adminApiKey'] && !req.query.adminKey) {
            req.query.adminKey = req.query['adminApiKey'];
        }
    } catch (e) { /* ignore */ }
    next();
});

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

// Serve static files from workspace root
app.use(express.static(path.join(__dirname, '..')));

function checkApiKeyOrDie(req, res, next) {
    // Read from environment at request time to make behavior deterministic during tests
    // TEST HOOK: when `FORCE_MISSING_VAST_KEY` is set to '1', treat the key as missing.
    if (process.env.FORCE_MISSING_VAST_KEY === '1') {
        return res.status(500).json({ error: 'Server VASTAI_API_KEY not configured in environment (forced missing for tests)' });
    }

    const key = process.env.VASTAI_API_KEY || process.env.VAST_AI_API_KEY || null;
    if (!key) {
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

// GPU status endpoint - check availability before generation
app.get('/api/proxy/gpu-status', (req, res) => {
    try {
        const pool = warmPool.getStatus();
        const instance = pool.instance;

        let status = 'unavailable';
        let message = 'No GPU instance available';
        let canGenerate = false;
        let canPrewarm = true;
        let estimatedReadyTime = null;

        if (pool.isPrewarming) {
            status = 'prewarming';
            message = 'GPU instance is being prepared';
            canPrewarm = false;
            estimatedReadyTime = '2-5 minutes';
        } else if (instance) {
            if (instance.status === 'running' && instance.connectionUrl) {
                status = 'ready';
                message = 'GPU instance is ready for generation';
                canGenerate = true;
                canPrewarm = false;
            } else if (instance.status === 'starting') {
                status = 'starting';
                message = 'GPU instance is starting up';
                canPrewarm = false;
                estimatedReadyTime = '1-3 minutes';
            } else if (instance.status === 'running') {
                status = 'initializing';
                message = 'GPU instance is initializing ComfyUI';
                canPrewarm = false;
                estimatedReadyTime = '1-2 minutes';
            }
        }

        res.json({
            status,
            message,
            canGenerate,
            canPrewarm,
            estimatedReadyTime,
            instance: instance ? {
                contractId: instance.contractId,
                status: instance.status,
                hasConnectionUrl: !!instance.connectionUrl
            } : null
        });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// Simple admin authentication (API key via header 'x-admin-key')
const ADMIN_API_KEY = process.env.ADMIN_API_KEY || null;
const INSECURE_ADMIN_DEFAULTS = ['secure_admin_key_change_me', 'admin_dev_key', 'admin', 'changeme', 'password', '1234'];

if (!ADMIN_API_KEY) {
    if (process.env.NODE_ENV === 'production') {
        console.error('FATAL: ADMIN_API_KEY is required in production. Set ADMIN_API_KEY and restart. Example: ADMIN_API_KEY=your-strong-key pm2 restart vastai-proxy --update-env');
        process.exit(1);
    } else {
        console.warn('⚠️ Warning: ADMIN_API_KEY is not set. Running in development mode without admin auth. This is NOT safe for production.');
    }
} else {
    if (process.env.NODE_ENV === 'production' && INSECURE_ADMIN_DEFAULTS.includes(ADMIN_API_KEY.toLowerCase())) {
        console.error('FATAL: ADMIN_API_KEY appears to be a default/insecure value. Set a strong ADMIN_API_KEY and restart with: pm2 restart vastai-proxy --update-env');
        process.exit(1);
    }
}

function requireAdmin(req, res, next) {
    const key = req.headers['x-admin-key'] || req.headers['x-admin-api-key'] || req.query.adminKey;
    if (!process.env.ADMIN_API_KEY) {
        return res.status(403).json({ error: 'forbidden - admin authentication not configured on server' });
    }
    if (!key || key !== process.env.ADMIN_API_KEY) {
        try { logAuthAttempt(req, false); } catch (e) {}
        return res.status(403).json({ error: 'forbidden - invalid admin key' });
    }
    try { logAuthAttempt(req, true); } catch (e) {}
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
function warmPoolCompat(status) {
    return {
        desiredSize: status.desiredSize,
        instances: status.instance ? [status.instance] : [],
        lastAction: status.lastAction,
        isPrewarming: !!status.isPrewarming,
        safeMode: !!status.safeMode
    };
}

app.get('/api/proxy/admin/warm-pool', (req, res) => {
    // perform auth check with logging
    const key = req.headers['x-admin-key'] || req.query.adminKey;
    if (!key || key !== process.env.ADMIN_API_KEY) {
        logAuthAttempt(req, false);
        return res.status(403).json({ error: 'forbidden - invalid admin key' });
    }
    logAuthAttempt(req, true);
    try {
        const status = warmPool.getStatus();
        res.json(warmPoolCompat(status));
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// Backwards-compatible alias used by some tests/scripts
app.get('/api/proxy/admin/warm-pool/status', (req, res) => {
    const key = req.headers['x-admin-key'] || req.query.adminKey;
    if (!key || key !== process.env.ADMIN_API_KEY) {
        logAuthAttempt(req, false);
        return res.status(403).json({ error: 'forbidden - invalid admin key' });
    }
    logAuthAttempt(req, true);
    try {
        const status = warmPool.getStatus();
        res.json(warmPoolCompat(status));
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

// Admin termination (protected)
app.post('/api/proxy/admin/terminate', express.json(), async (req, res) => {
    const key = req.headers['x-admin-key'] || req.query.adminKey;
    if (!key || key !== process.env.ADMIN_API_KEY) {
        return res.status(403).json({ error: 'forbidden' });
    }
    try {
        const { contractId } = req.body || {};
        const result = await warmPool.terminate(contractId);
        res.json(result);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// Admin state reload from database (protected) - reloads without resetting
app.post('/api/proxy/admin/reload-state', express.json(), (req, res) => {
    const key = req.headers['x-admin-key'] || req.query.adminKey;
    if (!key || key !== process.env.ADMIN_API_KEY) {
        return res.status(403).json({ error: 'forbidden' });
    }
    try {
        // Force warm-pool module to reload state from database
        if (typeof warmPool.load === 'function') {
            warmPool.load();
            const status = warmPool.getStatus();
            res.json({ status: 'ok', message: 'WarmPool state reloaded from database', warmPool: status });
        } else {
            res.status(500).json({ error: 'warmPool.load not available' });
        }
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Admin state reset (protected)
app.post('/api/proxy/admin/reset-state', express.json(), async (req, res) => {
    const key = req.headers['x-admin-key'] || req.query.adminKey;
    if (!key || key !== process.env.ADMIN_API_KEY) {
        return res.status(403).json({ error: 'forbidden' });
    }
    try {
        const db = require('./db').db;
        db.prepare('UPDATE warm_pool SET instance = NULL, isPrewarming = 0 WHERE id = 1').run();

        // Force warm-pool module to reload state (now async with instance validation)
        if (typeof warmPool.load === 'function') {
            await warmPool.load();
        }

        // Audit the reset
        try {
            audit.logAdminEvent({
                adminKey: key,
                ip: req.ip || (req.connection && req.connection.remoteAddress),
                route: req.originalUrl,
                action: 'reset_state',
                details: { note: 'Manual state reset from admin UI' },
                outcome: 'ok'
            });
        } catch (e) { }

        // Return updated state for confirmation
        // Note: Use db.getState() directly since warmPool doesn't export this function
        const currentState = require('./db').getState();
        res.json({
            status: 'ok',
            message: 'WarmPool state reset successfully',
            state: {
                instance: currentState.instance,
                isPrewarming: currentState.isPrewarming,
                lastAction: currentState.lastAction
            }
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Admin reprovision endpoint - terminate and recreate with fallback script option
// Use this when provisioning fails repeatedly to force fallback to default Vast.ai script
app.post('/api/proxy/admin/warm-pool/reprovision', express.json(), async (req, res) => {
    const key = req.headers['x-admin-key'] || req.query.adminKey;
    if (!key || key !== process.env.ADMIN_API_KEY) {
        logAuthAttempt(req, false);
        return res.status(403).json({ error: 'forbidden - invalid admin key' });
    }
    logAuthAttempt(req, true);

    try {
        const { useDefaultScript = true, resetFallback = false } = req.body || {};
        const pool = warmPool.getStatus();
        const previousContract = pool.instance?.contractId || null;

        console.log(`WarmPool: 🔄 Admin triggered reprovision (useDefaultScript: ${useDefaultScript}, resetFallback: ${resetFallback})`);

        // Audit the reprovision request
        try {
            audit.logAdminEvent({
                adminKey: key,
                ip: req.ip || (req.connection && req.connection.remoteAddress),
                route: req.originalUrl,
                action: 'reprovision',
                details: {
                    useDefaultScript,
                    resetFallback,
                    previousContract,
                    previousStatus: pool.instance?.status
                },
                outcome: 'started'
            });
        } catch (e) { console.error('audit log error:', e); }

        // Terminate existing instance if present
        if (previousContract) {
            console.log(`WarmPool: 🗑️ Terminating existing instance ${previousContract} before reprovision`);
            await warmPool.terminate(previousContract);
        }

        // Handle fallback flag
        if (resetFallback && typeof warmPool.resetProvisioningState === 'function') {
            // Reset fallback mode to try custom script again
            warmPool.resetProvisioningState();
        } else if (useDefaultScript && typeof warmPool.setUseDefaultScript === 'function') {
            // Force use of default script
            warmPool.setUseDefaultScript(true);
        }

        // Trigger new prewarm
        const result = await warmPool.prewarm();

        res.json({
            status: 'reprovisioning',
            message: useDefaultScript
                ? 'Terminated old instance, starting new one with default Vast.ai script'
                : 'Terminated old instance, starting new one with custom script',
            previousContract,
            result
        });
    } catch (e) {
        console.error('WarmPool: reprovision error:', e);

        // Audit the failure
        try {
            audit.logAdminEvent({
                adminKey: key,
                ip: req.ip || (req.connection && req.connection.remoteAddress),
                route: req.originalUrl,
                action: 'reprovision',
                details: { error: e.message },
                outcome: 'error'
            });
        } catch (auditErr) { console.error('audit log error:', auditErr); }

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

// Instance health check endpoint (protected)
// Returns comprehensive health report for the current warm instance
app.get('/api/proxy/admin/warm-pool/health', async (req, res) => {
    const key = req.headers['x-admin-key'] || req.query.adminKey;
    if (!key || key !== process.env.ADMIN_API_KEY) {
        return res.status(403).json({ error: 'forbidden' });
    }

    try {
        const pool = warmPool.getStatus();
        if (!pool.instance || !pool.instance.connectionUrl) {
            return res.json({
                healthy: false,
                error: 'No active instance',
                instance: null
            });
        }

        // Run comprehensive health check
        const healthReport = await warmPool.validateInstanceHealth(
            pool.instance.connectionUrl,
            pool.instance.contractId
        );

        const isHealthy = warmPool.isInstanceHealthy(healthReport);

        // Audit the health check
        try {
            audit.logAdminEvent({
                adminKey: key,
                ip: req.ip || req.connection && req.connection.remoteAddress,
                route: req.originalUrl,
                action: 'health_check',
                details: { contractId: pool.instance.contractId, healthy: isHealthy },
                outcome: isHealthy ? 'ok' : 'unhealthy'
            });
        } catch (e) { console.error('audit log error:', e); }

        res.json({
            healthy: isHealthy,
            instance: {
                contractId: pool.instance.contractId,
                status: pool.instance.status,
                connectionUrl: pool.instance.connectionUrl
            },
            healthReport
        });
    } catch (e) {
        console.error('Health check error:', e);
        res.status(500).json({ error: e.message });
    }
});

// Get current environment configuration (protected, sensitive values masked)
app.get('/api/proxy/admin/config', (req, res) => {
    const key = req.headers['x-admin-key'] || req.query.adminKey;
    if (!key || key !== process.env.ADMIN_API_KEY) {
        return res.status(403).json({ error: 'forbidden' });
    }

    // Return current config with sensitive values masked
    res.json({
        VASTAI_API_KEY: process.env.VASTAI_API_KEY ? '***configured***' : 'NOT SET',
        ADMIN_API_KEY: process.env.ADMIN_API_KEY ? '***configured***' : 'NOT SET',
        HUGGINGFACE_HUB_TOKEN: process.env.HUGGINGFACE_HUB_TOKEN ? '***configured***' : 'NOT SET',
        CIVITAI_TOKEN: process.env.CIVITAI_TOKEN ? '***configured***' : 'NOT SET',
        COMFYUI_PROVISION_SCRIPT: process.env.COMFYUI_PROVISION_SCRIPT || 'NOT SET (using default)',
        WARM_POOL_DISK_GB: process.env.WARM_POOL_DISK_GB || process.env.WARM_POOL_DISK || '150',
        VASTAI_MIN_CUDA_CAPABILITY: warmPool.MIN_CUDA_CAPABILITY,
        VASTAI_COMFY_IMAGE: process.env.VASTAI_COMFY_IMAGE || 'vastai/comfy:v0.10.0-cuda-12.9-py312',
        WARM_POOL_SAFE_MODE: process.env.WARM_POOL_SAFE_MODE || '0',
        WARM_POOL_IDLE_MINUTES: process.env.WARM_POOL_IDLE_MINUTES || '15',
        PORT: process.env.PORT || '3000'
    });
});

// ============================================================================
// WORKFLOW TEMPLATE API
// ============================================================================

const comfyWorkflows = require('./comfy-workflows');

// List available workflow templates (public endpoint)
app.get('/api/proxy/workflow-templates', (req, res) => {
    try {
        const templates = comfyWorkflows.listTemplates();
        res.json({ templates });
    } catch (error) {
        console.error('Failed to list workflow templates:', error);
        res.status(500).json({ error: error.message });
    }
});

// Get required models for a specific template (public endpoint)
app.get('/api/proxy/workflow-templates/:name/requirements', (req, res) => {
    try {
        const { name } = req.params;

        if (!comfyWorkflows.hasTemplate(name)) {
            return res.status(404).json({
                error: `Template '${name}' not found`,
                available: comfyWorkflows.listTemplates().map(t => t.name)
            });
        }

        const requirements = comfyWorkflows.getRequiredModels(name);
        res.json({ template: name, requirements });
    } catch (error) {
        console.error('Failed to get template requirements:', error);
        res.status(500).json({ error: error.message });
    }
});

// Get model inventory from current warm instance (admin endpoint)
app.get('/api/proxy/admin/model-inventory', (req, res) => {
    const key = req.headers['x-admin-key'] || req.query.adminKey;
    if (!key || key !== process.env.ADMIN_API_KEY) {
        return res.status(403).json({ error: 'forbidden' });
    }

    try {
        const pool = warmPool.getStatus();

        if (!pool.instance) {
            return res.status(404).json({
                error: 'No instance available',
                hint: 'Prewarm an instance first'
            });
        }

        if (!pool.instance.modelInventory) {
            return res.status(404).json({
                error: 'Model inventory not yet available',
                hint: 'Instance must be fully ready (status: ready)',
                instanceStatus: pool.instance.status
            });
        }

        res.json({
            contractId: pool.instance.contractId,
            status: pool.instance.status,
            inventory: pool.instance.modelInventory
        });
    } catch (error) {
        console.error('Failed to get model inventory:', error);
        res.status(500).json({ error: error.message });
    }
});

// Refresh model inventory from instance (admin endpoint)
app.post('/api/proxy/admin/model-inventory/refresh', async (req, res) => {
    const key = req.headers['x-admin-key'] || req.query.adminKey;
    if (!key || key !== process.env.ADMIN_API_KEY) {
        return res.status(403).json({ error: 'forbidden' });
    }

    try {
        const pool = warmPool.getStatus();

        if (!pool.instance || !pool.instance.connectionUrl) {
            return res.status(404).json({
                error: 'No running instance with connection URL',
                hint: 'Instance must be running and have a connection URL'
            });
        }

        // Fetch fresh inventory
        const inventory = await warmPool.fetchModelInventory(pool.instance.connectionUrl);

        // Update state (note: we can't directly modify state here, but the inventory is returned)
        res.json({
            message: 'Model inventory refreshed',
            contractId: pool.instance.contractId,
            inventory
        });
    } catch (error) {
        console.error('Failed to refresh model inventory:', error);
        res.status(500).json({ error: error.message });
    }
});

// Update environment configuration (protected)
// This persists tokens to .proxy-tokens.json for restart survival
app.post('/api/proxy/admin/config', express.json(), (req, res) => {
    const key = req.headers['x-admin-key'] || req.query.adminKey;
    if (!key || key !== process.env.ADMIN_API_KEY) {
        return res.status(403).json({ error: 'forbidden' });
    }

    const {
        huggingface_token,
        civitai_token,
        provision_script,
        min_cuda_capability,
        warm_pool_disk_gb
    } = req.body || {};

    const updates = {};

    // Update tokens in memory and persist
    if (huggingface_token !== undefined) {
        process.env.HUGGINGFACE_HUB_TOKEN = huggingface_token;
        updates.huggingface = huggingface_token;
    }
    if (civitai_token !== undefined) {
        process.env.CIVITAI_TOKEN = civitai_token;
        updates.civitai = civitai_token;
    }
    if (provision_script !== undefined) {
        process.env.COMFYUI_PROVISION_SCRIPT = provision_script;
    }
    if (min_cuda_capability !== undefined) {
        process.env.VASTAI_MIN_CUDA_CAPABILITY = String(min_cuda_capability);
    }
    if (typeof warm_pool_disk_gb !== 'undefined' && warm_pool_disk_gb !== null) {
        // Accept numeric or string values; store as string in env for consistency
        process.env.WARM_POOL_DISK_GB = String(warm_pool_disk_gb);
        updates.warm_pool_disk_gb = String(warm_pool_disk_gb);
    }

    // Persist token updates
    if (Object.keys(updates).length > 0) {
        try {
            let existing = {};
            if (fs.existsSync(TOKEN_STORE_PATH)) {
                existing = JSON.parse(fs.readFileSync(TOKEN_STORE_PATH, 'utf8') || '{}');
            }
            Object.assign(existing, updates);
            fs.writeFileSync(TOKEN_STORE_PATH, JSON.stringify(existing, null, 2));
        } catch (e) {
            console.error('Failed to persist tokens:', e);
        }
    }

    // Audit the config change
    try {
        audit.logAdminEvent({
            adminKey: key,
            ip: req.ip || req.connection && req.connection.remoteAddress,
            route: req.originalUrl,
            action: 'update_config',
            details: {
                huggingface_token: huggingface_token ? 'updated' : 'unchanged',
                civitai_token: civitai_token ? 'updated' : 'unchanged',
                provision_script: provision_script ? 'updated' : 'unchanged',
                min_cuda_capability: min_cuda_capability || 'unchanged',
                warm_pool_disk_gb: typeof warm_pool_disk_gb !== 'undefined' ? 'updated' : 'unchanged'
            },
            outcome: 'ok'
        });
    } catch (e) { console.error('audit log error:', e); }

    res.json({
        success: true,
        message: 'Configuration updated',
        note: 'Some changes may require restarting the warm pool instance to take effect'
    });
});

// ============================================================================
// PM2 SERVER MANAGEMENT ENDPOINTS (localhost only + admin key)
// ============================================================================

// Helper to check localhost
function isLocalhost(req) {
    const remote = req.ip || (req.connection && req.connection.remoteAddress);
    return ['::1', '127.0.0.1', '::ffff:127.0.0.1'].includes(remote);
}

// PM2 Restart endpoint
app.post('/api/proxy/admin/pm2/restart', express.json(), (req, res) => {
    const key = req.headers['x-admin-key'] || req.query.adminKey;
    if (!key || key !== process.env.ADMIN_API_KEY) {
        logAuthAttempt(req, false);
        return res.status(403).json({ error: 'forbidden - invalid admin key' });
    }
    if (!isLocalhost(req)) {
        return res.status(403).json({ error: 'forbidden - PM2 control only allowed from localhost' });
    }
    logAuthAttempt(req, true);

    pm2.connect((err) => {
        if (err) {
            console.error('PM2 connect error:', err);
            return res.status(500).json({ error: 'Failed to connect to PM2', details: err.message });
        }

        pm2.restart('vastai-proxy', (err) => {
            pm2.disconnect();
            if (err) {
                console.error('PM2 restart error:', err);
                // Audit the failed restart
                try {
                    audit.logAdminEvent({
                        adminKey: key,
                        ip: req.ip || (req.connection && req.connection.remoteAddress),
                        route: req.originalUrl,
                        action: 'pm2_restart',
                        details: { error: err.message },
                        outcome: 'error'
                    });
                } catch (e) { console.error('audit log error:', e); }
                return res.status(500).json({ error: 'Failed to restart via PM2', details: err.message });
            }

            // Audit successful restart
            try {
                audit.logAdminEvent({
                    adminKey: key,
                    ip: req.ip || (req.connection && req.connection.remoteAddress),
                    route: req.originalUrl,
                    action: 'pm2_restart',
                    details: { processName: 'vastai-proxy' },
                    outcome: 'ok'
                });
            } catch (e) { console.error('audit log error:', e); }

            res.json({ success: true, message: 'Server restart initiated via PM2' });
        });
    });
});

// PM2 Stop endpoint
app.post('/api/proxy/admin/pm2/stop', express.json(), (req, res) => {
    const key = req.headers['x-admin-key'] || req.query.adminKey;
    if (!key || key !== process.env.ADMIN_API_KEY) {
        logAuthAttempt(req, false);
        return res.status(403).json({ error: 'forbidden - invalid admin key' });
    }
    if (!isLocalhost(req)) {
        return res.status(403).json({ error: 'forbidden - PM2 control only allowed from localhost' });
    }
    logAuthAttempt(req, true);

    pm2.connect((err) => {
        if (err) {
            console.error('PM2 connect error:', err);
            return res.status(500).json({ error: 'Failed to connect to PM2', details: err.message });
        }

        pm2.stop('vastai-proxy', (err) => {
            pm2.disconnect();
            if (err) {
                console.error('PM2 stop error:', err);
                try {
                    audit.logAdminEvent({
                        adminKey: key,
                        ip: req.ip || (req.connection && req.connection.remoteAddress),
                        route: req.originalUrl,
                        action: 'pm2_stop',
                        details: { error: err.message },
                        outcome: 'error'
                    });
                } catch (e) { console.error('audit log error:', e); }
                return res.status(500).json({ error: 'Failed to stop via PM2', details: err.message });
            }

            try {
                audit.logAdminEvent({
                    adminKey: key,
                    ip: req.ip || (req.connection && req.connection.remoteAddress),
                    route: req.originalUrl,
                    action: 'pm2_stop',
                    details: { processName: 'vastai-proxy' },
                    outcome: 'ok'
                });
            } catch (e) { console.error('audit log error:', e); }

            res.json({ success: true, message: 'Server stopped via PM2' });
        });
    });
});

// PM2 Start endpoint
app.post('/api/proxy/admin/pm2/start', express.json(), (req, res) => {
    const key = req.headers['x-admin-key'] || req.query.adminKey;
    if (!key || key !== process.env.ADMIN_API_KEY) {
        logAuthAttempt(req, false);
        return res.status(403).json({ error: 'forbidden - invalid admin key' });
    }
    if (!isLocalhost(req)) {
        return res.status(403).json({ error: 'forbidden - PM2 control only allowed from localhost' });
    }
    logAuthAttempt(req, true);

    pm2.connect((err) => {
        if (err) {
            console.error('PM2 connect error:', err);
            return res.status(500).json({ error: 'Failed to connect to PM2', details: err.message });
        }

        pm2.start('vastai-proxy', (err) => {
            pm2.disconnect();
            if (err) {
                console.error('PM2 start error:', err);
                try {
                    audit.logAdminEvent({
                        adminKey: key,
                        ip: req.ip || (req.connection && req.connection.remoteAddress),
                        route: req.originalUrl,
                        action: 'pm2_start',
                        details: { error: err.message },
                        outcome: 'error'
                    });
                } catch (e) { console.error('audit log error:', e); }
                return res.status(500).json({ error: 'Failed to start via PM2', details: err.message });
            }

            try {
                audit.logAdminEvent({
                    adminKey: key,
                    ip: req.ip || (req.connection && req.connection.remoteAddress),
                    route: req.originalUrl,
                    action: 'pm2_start',
                    details: { processName: 'vastai-proxy' },
                    outcome: 'ok'
                });
            } catch (e) { console.error('audit log error:', e); }

            res.json({ success: true, message: 'Server started via PM2' });
        });
    });
});

// PM2 Status endpoint - get current PM2 process status
app.get('/api/proxy/admin/pm2/status', (req, res) => {
    const key = req.headers['x-admin-key'] || req.query.adminKey;
    if (!key || key !== process.env.ADMIN_API_KEY) {
        logAuthAttempt(req, false);
        return res.status(403).json({ error: 'forbidden - invalid admin key' });
    }
    logAuthAttempt(req, true);

    pm2.connect((err) => {
        if (err) {
            return res.status(500).json({ error: 'Failed to connect to PM2', details: err.message });
        }

        pm2.describe('vastai-proxy', (err, processDescription) => {
            pm2.disconnect();
            if (err) {
                return res.status(500).json({ error: 'Failed to get PM2 status', details: err.message });
            }

            if (!processDescription || processDescription.length === 0) {
                return res.json({
                    managed: false,
                    message: 'Process not managed by PM2. Start with: npm run start:pm2'
                });
            }

            const proc = processDescription[0];
            res.json({
                managed: true,
                name: proc.name,
                status: proc.pm2_env.status,
                pid: proc.pid,
                uptime: proc.pm2_env.pm_uptime ? Date.now() - proc.pm2_env.pm_uptime : null,
                restarts: proc.pm2_env.restart_time,
                memory: proc.monit ? proc.monit.memory : null,
                cpu: proc.monit ? proc.monit.cpu : null
            });
        });
    });
});

// Forward arbitrary ComfyUI requests to the active warm instance.
// Example: POST /api/proxy/comfy/flow -> proxied to http://<instance>:8188/flow
// Set COMFYUI_TUNNEL_URL=http://localhost:8188 to use SSH tunnel instead of public IP
app.use('/api/proxy/comfy', async (req, res) => {
    try {
        const pool = warmPool.getStatus();
        if (!pool.instance) return res.status(404).json({ error: 'no warm instance available' });
        // Use SSH tunnel override if set, otherwise use instance connectionUrl
        const tunnelUrl = process.env.COMFYUI_TUNNEL_URL;
        const targetBase = (tunnelUrl || pool.instance.connectionUrl || '').replace(/\/$/, '');
        if (!targetBase) return res.status(404).json({ error: 'no connection URL available' });
        const forwardPath = req.originalUrl.replace(/^\/api\/proxy\/comfy/, '');
        const targetUrl = targetBase + (forwardPath || '/');

        const opts = {
            method: req.method,
            headers: Object.assign({}, req.headers),
            // do not forward host header
        };

        // Remove headers that might cause issues
        delete opts.headers.host;

        if (['POST', 'PUT', 'PATCH'].includes(req.method.toUpperCase())) {
            opts.body = JSON.stringify(req.body || {});
            opts.headers['content-type'] = 'application/json';
        }

        const r = await fetch(targetUrl, opts);

        // Check content type to handle binary data (images) correctly
        const contentType = r.headers.get('content-type') || '';
        if (contentType.startsWith('image/') || contentType === 'application/octet-stream') {
            // Binary data - forward as buffer
            const buffer = await r.buffer();
            res.set('Content-Type', contentType);
            return res.status(r.status).send(buffer);
        }

        // Text/JSON data
        const text = await r.text();
        try { return res.status(r.status).json(JSON.parse(text)); } catch (e) { return res.status(r.status).send(text); }

    } catch (e) {
        console.error('comfy proxy error:', e);
        res.status(502).json({ error: 'comfy proxy error', details: e.message });
    }
});

app.post('/api/proxy/warm-pool/prewarm', async (req, res) => {
    try {
        console.log('[DEBUG] Prewarm endpoint hit');
        // Log all headers for diagnosis
        console.log('[DEBUG] Headers:', JSON.stringify(req.headers));
        const key = req.headers['x-admin-api-key'] || req.headers['x-admin-key'] || req.query.adminKey;
        console.log('[DEBUG] Key received:', key ? `${key.substring(0, 4)}...` : 'NONE');
        console.log('[DEBUG] Expected key:', process.env.ADMIN_API_KEY ? `${process.env.ADMIN_API_KEY.substring(0, 4)}...` : 'NOT SET');

        if (!key || key !== process.env.ADMIN_API_KEY) {
            console.log('[DEBUG] Auth failed');
            try { logAuthAttempt(req, false); } catch (e) { console.error('audit error:', e); }
            return res.status(403).json({ error: 'forbidden - invalid admin key' });
        }
        console.log('[DEBUG] Auth passed');
        try { logAuthAttempt(req, true); } catch (e) { console.error('audit error:', e); }

        console.log('[Prewarm] Starting warm-pool prewarm...');
        console.log('[DEBUG] About to call warmPool.prewarm()');
        const result = await warmPool.prewarm();
        console.log('[Prewarm] Success:', result);

        // Audit admin prewarm
        try {
            audit.logAdminEvent({ adminKey: key, ip: req.ip || req.connection && req.connection.remoteAddress, route: req.originalUrl, action: 'prewarm', details: result, outcome: 'ok' });
        } catch (e) { console.error('audit log error:', e); }

        res.status(200).json(result);
    } catch (e) {
        console.error('[Prewarm] Error:', e);
        res.status(500).json({ error: e.message, stack: e.stack });
    }
});

// Backwards-compatible admin alias for prewarm
app.post('/api/proxy/admin/warm-pool/prewarm', express.json(), async (req, res) => {
    try {
        const key = req.headers['x-admin-api-key'] || req.headers['x-admin-key'] || req.query.adminKey;
        if (!key || key !== process.env.ADMIN_API_KEY) {
            logAuthAttempt(req, false);
            return res.status(403).json({ error: 'forbidden - invalid admin key' });
        }
        logAuthAttempt(req, true);
        const result = await warmPool.prewarm();
        try { audit.logAdminEvent({ adminKey: key, ip: req.ip || req.connection && req.connection.remoteAddress, route: req.originalUrl, action: 'prewarm', details: result, outcome: 'ok' }); } catch (e) { console.error('audit log error:', e); }
        res.status(200).json(result);
    } catch (e) {
        console.error('[Admin Prewarm] Error:', e);
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

app.post('/api/proxy/warm-pool/claim', express.json(), async (req, res) => {
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
    const remote = req.ip || req.connection && req.connection.remoteAddress;
    if (!['::1', '127.0.0.1', '::ffff:127.0.0.1'].includes(remote)) {
        return res.status(403).json({ error: 'Forbidden - set tokens only allowed from localhost' });
    }

    const { huggingface, civitai, vastai } = req.body || {};
    if (huggingface) process.env.HUGGINGFACE_HUB_TOKEN = huggingface;
    if (civitai) process.env.CIVITAI_TOKEN = civitai;
    if (vastai) process.env.VASTAI_API_KEY = vastai;

    // Persist tokens to a local file so they survive restarts
    try {
        const toSave = {
            huggingface: process.env.HUGGINGFACE_HUB_TOKEN || null,
            civitai: process.env.CIVITAI_TOKEN || null,
            vastai: process.env.VASTAI_API_KEY || null
        };
        fs.writeFileSync(TOKEN_STORE_PATH, JSON.stringify(toSave, null, 2), { mode: 0o600 });
        console.log('Persisted tokens to .proxy-tokens.json (local only)');
    } catch (e) {
        console.error('Failed to persist tokens:', e && e.message ? e.message : e);
    }

    res.json({ huggingface: !!process.env.HUGGINGFACE_HUB_TOKEN, civitai: !!process.env.CIVITAI_TOKEN, vastai: !!process.env.VASTAI_API_KEY });
});

// Validate all tokens (tests actual API connectivity)
app.post('/api/proxy/admin/validate-tokens', requireAdmin, async (req, res) => {
  try {
    console.log('[TokenManager] Admin requested token validation');
    const results = await tokenManager.validateAll(false); // Force validation, bypass cache
    res.json({ success: true, validation: results });
  } catch (err) {
    console.error('[TokenManager] Validation error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// Update token at runtime (without restart) and validate
app.post('/api/proxy/admin/update-token', requireAdmin, async (req, res) => {
  try {
    const { service, token } = req.body;
    if (!service || !token) {
      return res.status(400).json({ error: 'service and token required' });
    }

    // Map service name to environment variable
    const envVarMap = {
      vastai: 'VASTAI_API_KEY',
      huggingface: 'HUGGINGFACE_HUB_TOKEN',
      civitai: 'CIVITAI_TOKEN'
    };

    const envVar = envVarMap[service.toLowerCase()];
    if (!envVar) {
      return res.status(400).json({ error: `Unknown service: ${service}` });
    }

    // Update environment variable
    process.env[envVar] = token;
    console.log(`[TokenManager] Updated ${service} token at runtime`);

    // Clear cache and validate new token
    tokenManager.clearCache();
    const result = await tokenManager.validateAll(false);

    res.json({ success: true, validation: result });
  } catch (err) {
    console.error('[TokenManager] Token update error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// ============================================================================
// GENERATION & GALLERY ENDPOINTS
// ============================================================================

const generationHandler = require('./generation-handler');
const db = require('./db');
// Note: fs is already required at the top of the file

// Generation endpoints
app.post('/api/proxy/generate', generationHandler.handleGenerate);
app.get('/api/proxy/generate/:jobId', generationHandler.getJobStatus);

// Gallery endpoints

// Serve generated content (image or video)
app.get('/api/gallery/content/:id', (req, res) => {
    const { id } = req.params;

    // Try by ID first, then by job_id
    let job = db.db.prepare('SELECT * FROM generated_content WHERE id = ?').get(id);
    if (!job) {
        job = db.db.prepare('SELECT * FROM generated_content WHERE job_id = ?').get(id);
    }

    if (!job || !job.result_path) {
        return res.status(404).json({ error: 'Content not found' });
    }

    if (!fs.existsSync(job.result_path)) {
        return res.status(404).json({ error: 'File not found on disk' });
    }

    // Set correct content type
    const contentType = job.workflow_type === 'video' ? 'video/mp4' : 'image/png';
    res.setHeader('Content-Type', contentType);

    // Stream file
    const stream = fs.createReadStream(job.result_path);
    stream.pipe(res);

    // In test environment, some tests stub streams and do not emit end; ensure response finishes
    if (process.env.NODE_ENV === 'test') {
        setImmediate(() => { if (!res.writableEnded) res.end(); });
    }
});

// Get thumbnail (for MVP, same as content)
app.get('/api/gallery/thumbnail/:id', (req, res) => {
    // For MVP, redirect to content endpoint
    // Future: Generate actual thumbnails with sharp/jimp
    const { id } = req.params;

    let job = db.db.prepare('SELECT * FROM generated_content WHERE id = ?').get(id);
    if (!job) {
        job = db.db.prepare('SELECT * FROM generated_content WHERE job_id = ?').get(id);
    }

    if (!job || !job.result_path) {
        return res.status(404).json({ error: 'Content not found' });
    }

    if (!fs.existsSync(job.result_path)) {
        return res.status(404).json({ error: 'File not found on disk' });
    }

    // For images, serve same file; for videos, we'd ideally generate a thumbnail
    const contentType = job.workflow_type === 'video' ? 'video/mp4' : 'image/png';
    res.setHeader('Content-Type', contentType);

    const stream = fs.createReadStream(job.result_path);
    stream.pipe(res);

    if (process.env.NODE_ENV === 'test') {
        setImmediate(() => { if (!res.writableEnded) res.end(); });
    }
});

// List gallery items
app.get('/api/gallery', (req, res) => {
    const { museId, status = 'completed', limit = 50, offset = 0 } = req.query;

    const filters = {
        museId: museId || null,
        status: status,
        limit: parseInt(limit),
        offset: parseInt(offset)
    };

    try {
        const items = db.getAllJobs(filters);

        // Count total for pagination
        let countQuery = 'SELECT COUNT(*) as total FROM generated_content WHERE 1=1';
        const countParams = [];

        if (museId) {
            countQuery += ' AND muse_id = ?';
            countParams.push(museId);
        }

        if (status !== 'all') {
            countQuery += ' AND status = ?';
            countParams.push(status);
        }

        const count = db.db.prepare(countQuery).get(...countParams);

        res.json({
            items: items.map(item => ({
                id: item.id,
                jobId: item.job_id,
                museName: item.muse_name,
                prompt: item.prompt,
                status: item.status,
                workflowType: item.workflow_type,
                thumbnailUrl: `/api/gallery/thumbnail/${item.id}`,
                contentUrl: item.status === 'completed' ? `/api/gallery/content/${item.id}` : null,
                createdAt: item.created_at,
                generationTime: item.generation_time_seconds
            })),
            total: count.total,
            limit: parseInt(limit),
            offset: parseInt(offset)
        });
    } catch (error) {
        console.error('Gallery list error:', error);
        res.status(500).json({ error: error.message });
    }
});

// Delete generated content
app.delete('/api/gallery/:id', (req, res) => {
    const { id } = req.params;
    const job = db.db.prepare('SELECT * FROM generated_content WHERE id = ? OR job_id = ?').get(id, id);

    if (!job) {
        return res.status(404).json({ error: 'Content not found' });
    }

    // Delete file from disk
    if (job.result_path && fs.existsSync(job.result_path)) {
        try {
            fs.unlinkSync(job.result_path);
            console.log(`[Gallery] Deleted file: ${job.result_path}`);
        } catch (err) {
            console.error('[Gallery] Failed to delete file:', err);
        }
    }

    // Delete from database
    db.deleteJob(id);

    res.json({ success: true, message: 'Content deleted' });
});

// Call cleanupRetention at startup to prune old logs (best-effort)
try {
    audit && typeof audit.cleanupRetention === 'function' && audit.cleanupRetention();
} catch (e) { /* ignore */ }

// Wrapper for starting the server
function startProxy(port = PORT) {
    const server = app.listen(port, '0.0.0.0', () => {
        const addr = server.address();
        const boundPort = addr ? addr.port : port;
        console.log(`Vast.ai proxy running on http://localhost:${boundPort}/ (ready)`);
    });

    // Set server timeout to 30 minutes (1800000ms) to allow for long-running operations
    // like prewarm (which can take 5-15 minutes for provisioning)
    server.timeout = 1800000; // 30 minutes
    server.keepAliveTimeout = 65000; // Slightly higher than default nginx timeout
    server.headersTimeout = 66000; // Should be higher than keepAliveTimeout

    console.log(`Server timeouts configured: timeout=${server.timeout}ms, keepAlive=${server.keepAliveTimeout}ms`);

    return server;
}

// Only listen if run directly
if (require.main === module) {
    console.log('[DEBUG] Starting server... require.main === module is true');
    console.log('[DEBUG] PORT:', PORT);
    try {
        const server = startProxy(PORT);
        server.on('error', (err) => {
            console.error('❌ Server error:', err);
            if (err.code === 'EADDRINUSE') {
                console.error(`Port ${PORT} is already in use`);
                process.exit(1);
            }
        });
        server.on('listening', () => {
            console.log('[DEBUG] Server is now listening');
            const addr = server.address();
            console.log('[DEBUG] Server bound to:', addr);
            try { checkPm2EnvConsistency(); } catch (e) { /* non-fatal */ }
            // Keep process alive
            setInterval(() => {}, 1 << 30);
        });

// Check PM2 environment for mismatched ADMIN_API_KEY (non-fatal advisory)
function checkPm2EnvConsistency() {
    try {
        pm2.connect((err) => {
            if (err) { console.warn('PM2 check skipped (pm2 not available):', err.message); return; }
            pm2.list((err, list) => {
                if (err) { pm2.disconnect(); return; }
                for (const proc of list) {
                    try {
                        if (proc && (proc.name === 'vastai-proxy' || (proc.pm2_env && proc.pm2_env.pm_exec_path && proc.pm2_env.pm_exec_path.indexOf('server/vastai-proxy.js') !== -1))) {
                            const pm2EnvAdmin = proc.pm2_env && proc.pm2_env.env && proc.pm2_env.env.ADMIN_API_KEY;
                            if (pm2EnvAdmin && pm2EnvAdmin !== process.env.ADMIN_API_KEY) {
                                console.warn('⚠️ PM2 env ADMIN_API_KEY differs from current process ADMIN_API_KEY. If you updated .env, run: pm2 restart vastai-proxy --update-env');
                            }
                        }
                    } catch (e) { /* ignore per-process */ }
                }
                pm2.disconnect();
            });
        });
    } catch (e) {
        console.warn('PM2 env consistency check failed:', e && e.message ? e.message : e);
    }
}
        console.log('[DEBUG] startProxy() called, server object:', !!server);
    } catch (err) {
        console.error('❌ Failed to start server:', err);
        process.exit(1);
    }
}

// Export the middleware for deterministic unit testing
app.checkApiKeyOrDie = checkApiKeyOrDie;

module.exports = app;
