const crypto = require('crypto');
const dbModule = require('./db');
const db = dbModule.db;

const AUDIT_SALT = process.env.AUDIT_SALT || 'dev_audit_salt';

function fingerprintKey(key) {
  if (!key) return null;
  return crypto.createHmac('sha256', AUDIT_SALT).update(String(key)).digest('hex');
}

const insertAdminStmt = db.prepare('INSERT INTO admin_audit (ts, admin_fingerprint, ip, route, action, details, outcome) VALUES (?, ?, ?, ?, ?, ?, ?)');
function logAdminEvent({ adminKey, ip, route, action, details, outcome }) {
  try {
    const fp = adminKey ? fingerprintKey(adminKey) : null;
    insertAdminStmt.run(new Date().toISOString(), fp, ip || null, route || null, action || null, details ? JSON.stringify(details) : null, outcome || null);
  } catch (e) {
    console.error('audit.logAdminEvent error:', e);
  }
}

// Prepare usage insert statements based on existing table schema (handle legacy variants)
let insertUsageStmt = null;
let insertUsageLegacyStmt = null;
try {
  const cols = db.prepare("PRAGMA table_info(usage_events)").all().map(r => r.name);
  const hasNew = cols.includes('ts') && cols.includes('event_type');
  const hasLegacy = cols.includes('contractId') && cols.includes('timestamp');
  if (hasNew) {
    insertUsageStmt = db.prepare('INSERT INTO usage_events (ts, event_type, contract_id, instance_status, duration_seconds, details, source) VALUES (?, ?, ?, ?, ?, ?, ?)');
  }
  if (hasLegacy) {
    insertUsageLegacyStmt = db.prepare('INSERT INTO usage_events (contractId, timestamp, status, costEstimate, notes) VALUES (?, ?, ?, ?, ?)');
  }
} catch (e) {
  console.error('audit schema detection error:', e);
}
function logUsageEvent({ event_type, contract_id, instance_status, duration_seconds, details, source }) {
  const ts = new Date().toISOString();
  // Try new schema first if prepared
  if (insertUsageStmt) {
    try {
      insertUsageStmt.run(ts, event_type || null, contract_id || null, instance_status || null, typeof duration_seconds === 'number' ? duration_seconds : null, details ? JSON.stringify(details) : null, source || null);
      return;
    } catch (e) {
      console.error('audit.logUsageEvent new-schema insert failed:', e);
    }
  }
  // Fallback to legacy schema if prepared
  if (insertUsageLegacyStmt) {
    try {
      const notes = details ? JSON.stringify({ event_type, details, source }) : null;
      const costEstimate = null;
      insertUsageLegacyStmt.run(contract_id || null, ts, instance_status || null, costEstimate, notes);
      return;
    } catch (e2) {
      console.error('audit.logUsageEvent legacy insert failed:', e2);
    }
  }
  console.error('audit.logUsageEvent: no usable insert statement for usage_events table');
}

function cleanupRetention(days) {
  const d = Number(days || process.env.ADMIN_AUDIT_RETENTION_DAYS || 90);
  const cutoff = new Date(Date.now() - d * 24 * 60 * 60 * 1000).toISOString();
  try {
    db.prepare('DELETE FROM admin_audit WHERE ts < ?').run(cutoff);
  } catch (e) {
    console.error('audit.cleanupRetention admin_audit error:', e);
  }
  // Clean usage_events with new schema column
  try {
    db.prepare('DELETE FROM usage_events WHERE ts < ?').run(cutoff);
  } catch (e) {
    // Ignore if table doesn't exist or ts column missing (migration will fix)
    console.error('audit.cleanupRetention usage_events error (non-fatal):', e.message);
  }
}

module.exports = { logAdminEvent, logUsageEvent, fingerprintKey, cleanupRetention };
