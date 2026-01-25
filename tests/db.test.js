const assert = require('assert');
const dbModule = require('../server/db');

describe('DB Module Migration Paths', function() {
  // These tests verify that migration code paths exist and tables have expected schema
  // The actual migration execution is tested by manipulating the existing warm_pool.db

  it('verifies warm_pool table has safeMode column (migration adds it if missing)', function() {
    const tableInfo = dbModule.db.prepare("PRAGMA table_info(warm_pool)").all();
    const hasSafeMode = tableInfo.some(r => r.name === 'safeMode');
    assert.strictEqual(hasSafeMode, true, 'safeMode column should exist (added by migration if missing)');
  });

  it('verifies usage_events table has new schema columns', function() {
    const tableInfo = dbModule.db.prepare("PRAGMA table_info(usage_events)").all();
    const hasTs = tableInfo.some(r => r.name === 'ts');
    const hasEventType = tableInfo.some(r => r.name === 'event_type');
    const hasContractId = tableInfo.some(r => r.name === 'contract_id');

    assert.strictEqual(hasTs, true, 'ts column should exist');
    assert.strictEqual(hasEventType, true, 'event_type column should exist');
    assert.strictEqual(hasContractId, true, 'contract_id column should exist');
  });

  it('can save and restore state with safeMode', function() {
    const state = dbModule.getState();
    const newState = {
      ...state,
      safeMode: true,
      desiredSize: 0
    };

    dbModule.saveState(newState);
    const restored = dbModule.getState();

    assert.strictEqual(restored.safeMode, true, 'safeMode should be saved and restored');
    assert.strictEqual(restored.desiredSize, 0, 'desiredSize should be saved');
  });
});
