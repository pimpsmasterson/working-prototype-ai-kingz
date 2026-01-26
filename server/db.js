const path = require('path');
const fs = require('fs');
const Database = require('better-sqlite3');

// Initialize database with comprehensive error handling
let db;
try {
  const DB_PATH = path.join(__dirname, '..', 'data', 'warm_pool.db');
  if (!fs.existsSync(path.dirname(DB_PATH))) {
    fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });
  }

  db = new Database(DB_PATH);

  // Enable Write-Ahead Logging for better concurrency and crash resistance
  db.pragma('journal_mode = WAL');
  // Set busy timeout to 5 seconds to handle lock contention
  db.pragma('busy_timeout = 5000');

  console.log('Database initialized:', DB_PATH);
} catch (e) {
  console.error('FATAL: Failed to initialize database:', e);
  console.error('Stack:', e.stack);
  console.error('This usually means: file permissions issue, disk full, or corrupted database file');
  process.exit(1);
}

// Wrap all schema initialization in error handling
try {
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

  // Generated content table for tracking image/video generation jobs
  db.exec(`CREATE TABLE IF NOT EXISTS generated_content (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id TEXT UNIQUE NOT NULL,
    user_id TEXT,
    muse_id TEXT,
    muse_name TEXT,

    -- Generation Parameters
    prompt TEXT NOT NULL,
    negative_prompt TEXT,
    workflow_type TEXT DEFAULT 'image',
    workflow_json TEXT,

    -- Technical Settings
    seed INTEGER,
    steps INTEGER,
    cfg_scale REAL,
    width INTEGER,
    height INTEGER,
    sampler TEXT,
    model_checkpoint TEXT,

    -- Video-Specific
    frame_count INTEGER,
    fps INTEGER,
    duration_seconds REAL,

    -- Results
    status TEXT DEFAULT 'pending',
    comfyui_prompt_id TEXT,
    result_path TEXT,
    result_url TEXT,
    thumbnail_path TEXT,
    file_size_bytes INTEGER,

    -- GPU Instance Info
    gpu_instance_id TEXT,
    gpu_type TEXT,
    generation_time_seconds REAL,
    cost_usd REAL,

    -- Metadata
    created_at TEXT DEFAULT (datetime('now')),
    started_at TEXT,
    completed_at TEXT,
    error_message TEXT,

    -- Organization
    is_favorite INTEGER DEFAULT 0,
    is_archived INTEGER DEFAULT 0,
    tags TEXT
  )`);

  // Ensure migration: add nsfw and workflow_template columns if missing
  const genTableInfo = db.prepare("PRAGMA table_info(generated_content)").all();
  const hasNsfw = genTableInfo.some(r => r.name === 'nsfw');
  const hasWorkflowTemplate = genTableInfo.some(r => r.name === 'workflow_template');
  if (!hasNsfw) {
    try { db.exec('ALTER TABLE generated_content ADD COLUMN nsfw INTEGER DEFAULT 0'); } catch (e) { /* ignore */ }
  }
  if (!hasWorkflowTemplate) {
    try { db.exec('ALTER TABLE generated_content ADD COLUMN workflow_template TEXT'); } catch (e) { /* ignore */ }
  }

  // Create indexes for performance
  db.exec(`CREATE INDEX IF NOT EXISTS idx_generated_content_muse ON generated_content(muse_id)`);
  db.exec(`CREATE INDEX IF NOT EXISTS idx_generated_content_status ON generated_content(status)`);
  db.exec(`CREATE INDEX IF NOT EXISTS idx_generated_content_created ON generated_content(created_at DESC)`);
  db.exec(`CREATE INDEX IF NOT EXISTS idx_generated_content_job ON generated_content(job_id)`);

  console.log('DB schema ready');
} catch (e) {
  console.error('FATAL: Database schema initialization failed:', e);
  console.error('Stack:', e.stack);
  console.error('This usually means: schema migration failed, constraint violations, or corrupted database');
  process.exit(1);
}

// Verify db is ready before exporting
if (!db) {
  throw new Error('Database failed to initialize - check error logs above');
}

function getState() {
  const row = db.prepare('SELECT desiredSize, instance, lastAction, isPrewarming, safeMode FROM warm_pool WHERE id = 1').get();
  if (!row) return null; // No state saved yet
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
  // Use INSERT OR REPLACE to ensure row exists
  db.prepare('INSERT OR REPLACE INTO warm_pool (id, desiredSize, instance, lastAction, isPrewarming, safeMode) VALUES (1, ?, ?, ?, ?, ?)')
    .run(state.desiredSize, instanceStr, state.lastAction, state.isPrewarming ? 1 : 0, state.safeMode ? 1 : 0);
}

// ============================================================================
// GENERATION CONTENT MANAGEMENT
// ============================================================================

/**
 * Create a new generation job
 * @param {Object} jobData - Job parameters
 * @returns {Object} SQLite run result
 */
function createJob(jobData) {
  const stmt = db.prepare(`
    INSERT INTO generated_content
    (job_id, muse_id, muse_name, prompt, negative_prompt, workflow_type,
     workflow_json, seed, steps, cfg_scale, width, height, sampler, model_checkpoint,
     frame_count, fps, status, nsfw, workflow_template)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);

  return stmt.run(
    jobData.jobId,
    jobData.museId || null,
    jobData.museName || null,
    jobData.prompt,
    jobData.negativePrompt || null,
    jobData.workflowType || 'image',
    jobData.workflowJson || null,
    jobData.seed || null,
    jobData.steps || null,
    jobData.cfgScale || null,
    jobData.width || null,
    jobData.height || null,
    jobData.sampler || null,
    jobData.checkpoint || null,
    jobData.frameCount || null,
    jobData.fps || null,
    'pending',
    jobData.nsfw ? 1 : 0,
    jobData.workflowTemplate || null
  );
}

/**
 * Update job status and optional fields
 * @param {string} jobId - Job ID
 * @param {string} status - New status (pending, processing, completed, failed)
 * @param {Object} updates - Additional fields to update
 * @returns {Object} SQLite run result
 */
function updateJobStatus(jobId, status, updates = {}) {
  const fields = Object.keys(updates);
  const values = Object.values(updates);

  if (fields.length === 0) {
    // Only update status
    const stmt = db.prepare('UPDATE generated_content SET status = ? WHERE job_id = ?');
    return stmt.run(status, jobId);
  }

  const setClause = fields.map(f => `${f} = ?`).join(', ');
  const stmt = db.prepare(`
    UPDATE generated_content
    SET status = ?, ${setClause}
    WHERE job_id = ?
  `);

  return stmt.run(status, ...values, jobId);
}

/**
 * Get job by job_id
 * @param {string} jobId - Job ID
 * @returns {Object|undefined} Job record or undefined if not found
 */
function getJob(jobId) {
  const row = db.prepare('SELECT * FROM generated_content WHERE job_id = ?').get(jobId);
  if (!row) return null;
  // Backwards compatibility: alias model_checkpoint -> checkpoint
  if (typeof row.checkpoint === 'undefined' && typeof row.model_checkpoint !== 'undefined') {
    row.checkpoint = row.model_checkpoint;
  }
  return row;
}

/**
 * Get all jobs (with optional filters)
 * @param {Object} filters - Optional filters (museId, status, limit, offset)
 * @returns {Array} Array of job records
 */
function getAllJobs(filters = {}) {
  let query = 'SELECT * FROM generated_content WHERE 1=1';
  const params = [];

  if (filters.museId) {
    query += ' AND muse_id = ?';
    params.push(filters.museId);
  }

  if (filters.status && filters.status !== 'all') {
    query += ' AND status = ?';
    params.push(filters.status);
  }

  query += ' ORDER BY created_at DESC';

  if (filters.limit) {
    query += ' LIMIT ?';
    params.push(filters.limit);

    if (filters.offset) {
      query += ' OFFSET ?';
      params.push(filters.offset);
    }
  }

  const rows = db.prepare(query).all(...params);
  // Alias model_checkpoint -> checkpoint for compatibility
  return rows.map(r => {
    if (typeof r.checkpoint === 'undefined' && typeof r.model_checkpoint !== 'undefined') {
      r.checkpoint = r.model_checkpoint;
    }
    return r;
  });
}

/**
 * Delete a job and its associated files
 * @param {string} jobId - Job ID or database ID
 * @returns {Object} SQLite run result
 */
function deleteJob(jobId) {
  // Try both job_id and id columns
  return db.prepare('DELETE FROM generated_content WHERE job_id = ? OR id = ?').run(jobId, jobId);
}

module.exports = {
  getState,
  saveState,
  db,
  createJob,
  updateJobStatus,
  getJob,
  getAllJobs,
  deleteJob
};
