const assert = require('assert');
const audit = require('../server/audit');
const db = require('../server/db');
const { resetDb } = require('./helpers/test-helper');

describe('Audit Module', function() {
  beforeEach(function() {
    resetDb();
  });

  it('logs admin actions with key fingerprinting', function() {
    const key = 'secret-admin-key';
    audit.logAdminEvent({ adminKey: key, action: 'test_action', details: { foo: 'bar' }, ip: '1.2.3.4' });
    
    const rows = db.db.prepare('SELECT * FROM admin_audit WHERE action = ?').all('test_action');
    assert.strictEqual(rows.length, 1);
    assert.strictEqual(rows[0].action, 'test_action');
    assert.ok(rows[0].admin_fingerprint);
    assert.notStrictEqual(rows[0].admin_fingerprint, key);
    assert.strictEqual(rows[0].ip, '1.2.3.4');
    
    const details = JSON.parse(rows[0].details);
    assert.strictEqual(details.foo, 'bar');
  });

  it('logUsageEvent records events correctly', function() {
    audit.logUsageEvent({ event_type: 'instance_started', contract_id: '777', details: { gpu: '3090' } });
    
    const rows = db.db.prepare('SELECT * FROM usage_events WHERE event_type = ?').all('instance_started');
    assert.strictEqual(rows.length, 1);
    assert.strictEqual(rows[0].contract_id, '777');
    const details = JSON.parse(rows[0].details);
    assert.strictEqual(details.gpu, '3090');
  });

  it('cleanupRetention removes old records', function() {
    // Insert a very old record manually
    const oldTimestamp = new Date(Date.now() - 40 * 24 * 60 * 60 * 1000).toISOString(); // 40 days ago
    db.db.prepare('INSERT INTO admin_audit (ts, action, admin_fingerprint, details) VALUES (?, ?, ?, ?)').run(
      oldTimestamp, 'old_action', 'fingerprint', '{}'
    );
    
    // Run cleanup
    audit.cleanupRetention(30); // 30 days
    
    const rows = db.db.prepare('SELECT * FROM admin_audit WHERE action = ?').all('old_action');
    assert.strictEqual(rows.length, 0, 'Old record should be cleaned up');
  });

  it('cleanupRetention keeps recent records', function() {
    const freshTimestamp = new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString(); // 5 days ago
    db.db.prepare('INSERT INTO admin_audit (ts, action, admin_fingerprint, details) VALUES (?, ?, ?, ?)').run(
      freshTimestamp, 'fresh_action', 'fingerprint', '{}'
    );
    
    audit.cleanupRetention(30);
    
    const rows = db.db.prepare('SELECT * FROM admin_audit WHERE action = ?').all('fresh_action');
    assert.strictEqual(rows.length, 1, 'Fresh record should be kept');
  });

  it('fingerprintKey returns null for falsy and stable hash otherwise', function() {
    assert.strictEqual(audit.fingerprintKey(null), null);
    const h1 = audit.fingerprintKey('k');
    const h2 = audit.fingerprintKey('k');
    assert.strictEqual(typeof h1, 'string');
    assert.strictEqual(h1, h2);
  });

  it('logAdminEvent handles missing adminKey', function() {
    audit.logAdminEvent({ ip: '9.9.9.9', route: '/no-key', action: 'nokey' });
    const row = db.db.prepare('SELECT * FROM admin_audit WHERE action = ? ORDER BY id DESC LIMIT 1').get('nokey');
    assert.strictEqual(row.admin_fingerprint, null);
  });

  it('logUsageEvent falls back to legacy schema when present', function() {
    // Backup current table
    try {
      db.db.prepare('CREATE TABLE IF NOT EXISTS usage_events_backup AS SELECT * FROM usage_events').run();
    } catch (e) {
      // ignore if already exists
    }
    // Drop the usage_events table
    db.db.prepare('DROP TABLE IF EXISTS usage_events').run();
    // Create a legacy-style usage_events table
    db.db.prepare('CREATE TABLE usage_events (contractId TEXT, timestamp TEXT, status TEXT, costEstimate REAL, notes TEXT)').run();

    // Re-require audit module so it detects legacy schema
    delete require.cache[require.resolve('../server/audit')];
    const auditLegacy = require('../server/audit');

    auditLegacy.logUsageEvent({ event_type: 'legacy_event', contract_id: 'C1', instance_status: 'idle', details: { x: 1 }, source: 'test' });

    const rows = db.db.prepare('SELECT * FROM usage_events').all();
    assert.ok(rows.length >= 1);
    const last = rows[rows.length - 1];
    assert.strictEqual(last.contractId, 'C1');

    // Trigger admin log insertion failure branch by renaming admin_audit and ensuring logAdminEvent handles it
    db.db.prepare('ALTER TABLE admin_audit RENAME TO admin_audit_tmp').run();
    try {
      const auditModule = require('../server/audit');
      // Should not throw even if insert fails
      auditModule.logAdminEvent({ adminKey: 'k', action: 'will_fail' });
    } finally {
      // Restore table
      db.db.prepare('ALTER TABLE admin_audit_tmp RENAME TO admin_audit').run();
    }

    // Restore original usage_events table
    db.db.prepare('DROP TABLE IF EXISTS usage_events').run();
    db.db.prepare('CREATE TABLE IF NOT EXISTS usage_events AS SELECT * FROM usage_events_backup').run();
    db.db.prepare('DROP TABLE IF EXISTS usage_events_backup').run();

    // Reread original audit module
    delete require.cache[require.resolve('../server/audit')];
    require('../server/audit');
  });

  it('logUsageEvent handles missing usage_events table gracefully', function() {
    // Backup usage_events
    db.db.prepare('CREATE TABLE IF NOT EXISTS usage_events_test_backup AS SELECT * FROM usage_events').run();

    // Drop usage_events to trigger schema detection with no table
    db.db.prepare('DROP TABLE IF EXISTS usage_events').run();

    // Re-require audit to detect missing table
    delete require.cache[require.resolve('../server/audit')];
    const auditNoTable = require('../server/audit');

    // Should not throw even when table is missing
    auditNoTable.logUsageEvent({ event_type: 'test', contract_id: 'X' });

    // Restore usage_events from backup
    db.db.prepare('DROP TABLE IF EXISTS usage_events').run();
    db.db.prepare('ALTER TABLE usage_events_test_backup RENAME TO usage_events').run();

    // Restore modules
    delete require.cache[require.resolve('../server/audit')];
    require('../server/audit');
  });

  it('cleanupRetention handles errors when deleting from admin_audit', function() {
    // Rename admin_audit to trigger error during cleanup
    try {
      db.db.prepare('ALTER TABLE admin_audit RENAME TO admin_audit_bak').run();
      // Should not throw despite table missing
      audit.cleanupRetention(30);
    } finally {
      // Restore table if it was renamed
      try {
        db.db.prepare('ALTER TABLE admin_audit_bak RENAME TO admin_audit').run();
      } catch (e) {
        // Table might not have been renamed if test failed early
      }
    }
  });

  it('cleanupRetention handles errors when deleting from usage_events', function() {
    // Rename usage_events to trigger error
    try {
      db.db.prepare('ALTER TABLE usage_events RENAME TO usage_events_bak').run();
      // Should not throw despite table missing
      audit.cleanupRetention(30);
    } finally {
      // Restore table if it was renamed
      try {
        db.db.prepare('ALTER TABLE usage_events_bak RENAME TO usage_events').run();
      } catch (e) {
        // Table might not have been renamed if test failed early
      }
    }
  });
});
