const path = require('path');
const fs = require('fs');
const Database = require('better-sqlite3');

const DB_PATH = path.join(__dirname, '..', 'data', 'warm_pool.db');
if (!fs.existsSync(path.dirname(DB_PATH))) fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });

const db = new Database(DB_PATH);

// Single-row warm_pool to store state
db.exec(`CREATE TABLE IF NOT EXISTS warm_pool (
  id INTEGER PRIMARY KEY CHECK(id = 1),
  desiredSize INTEGER,
  instance TEXT,
  lastAction TEXT,
  isPrewarming INTEGER
)`);
// Ensure safeMode column exists (migration for older DBs)
const tableInfo = db.prepare("PRAGMA table_info(warm_pool)").all();
const hasSafeMode = tableInfo.some(r => r.name === 'safeMode');
if (!hasSafeMode) {
  db.exec('ALTER TABLE warm_pool ADD COLUMN safeMode INTEGER DEFAULT 0');
}

// Audit and usage events tables
db.exec(`CREATE TABLE IF NOT EXISTS admin_audit (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts TEXT,
  admin_fingerprint TEXT,
  ip TEXT,
  route TEXT,
  action TEXT,
  details TEXT,
  outcome TEXT
)`);

// Migrate legacy usage_events table if needed
const usageTableInfo = db.prepare("PRAGMA table_info(usage_events)").all();
const hasLegacySchema = usageTableInfo.some(r => r.name === 'contractId' || r.name === 'timestamp');
const hasNewSchema = usageTableInfo.some(r => r.name === 'ts' && r.name !== 'timestamp');

if (hasLegacySchema && !hasNewSchema) {
  console.log('Migrating usage_events from legacy schema to new schema...');
  // Rename old table, create new one, copy data
  db.exec('ALTER TABLE usage_events RENAME TO usage_events_legacy');
  db.exec(`CREATE TABLE usage_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts TEXT,
    event_type TEXT,
    contract_id TEXT,
    instance_status TEXT,
    duration_seconds INTEGER,
    details TEXT,
    source TEXT
  )`);
  // Copy legacy data to new schema
  db.exec(`INSERT INTO usage_events (ts, event_type, contract_id, instance_status, details, source)
    SELECT timestamp, 'legacy_event', contractId, status, notes, 'migration'
    FROM usage_events_legacy`);
  // Drop legacy table after successful migration
  db.exec('DROP TABLE usage_events_legacy');
  console.log('Migration complete.');
} else if (!usageTableInfo.length) {
  // Table doesn't exist, create it fresh
  db.exec(`CREATE TABLE IF NOT EXISTS usage_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts TEXT,
    event_type TEXT,
    contract_id TEXT,
    instance_status TEXT,
    duration_seconds INTEGER,
    details TEXT,
    source TEXT
  )`);
}

// Ensure row exists
const init = db.prepare('INSERT OR IGNORE INTO warm_pool (id, desiredSize, instance, lastAction, isPrewarming) VALUES (1, 1, NULL, NULL, 0)');
init.run();

console.log('DB ready:', DB_PATH);

function getState() {
  const row = db.prepare('SELECT desiredSize, instance, lastAction, isPrewarming, safeMode FROM warm_pool WHERE id = 1').get();
  return {
    desiredSize: row.desiredSize,
    instance: row.instance ? JSON.parse(row.instance) : null,
    lastAction: row.lastAction,
    isPrewarming: !!row.isPrewarming,
    safeMode: !!row.safeMode
  };
}

function saveState(state) {
  const instanceStr = state.instance ? JSON.stringify(state.instance) : null;
  db.prepare('UPDATE warm_pool SET desiredSize = ?, instance = ?, lastAction = ?, isPrewarming = ?, safeMode = ? WHERE id = 1')
    .run(state.desiredSize, instanceStr, state.lastAction, state.isPrewarming ? 1 : 0, state.safeMode ? 1 : 0);
}

module.exports = { getState, saveState, db };
