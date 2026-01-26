const Database = require('better-sqlite3');
const path = require('path');
const DB_PATH = path.join(__dirname, '..', 'data', 'warm_pool.db');

console.log('Resetting warm_pool state in database:', DB_PATH);
const db = new Database(DB_PATH);

try {
  db.prepare('UPDATE warm_pool SET instance = NULL, isPrewarming = 0 WHERE id = 1').run();
  console.log('✅ WarmPool state reset successfully.');
} catch (e) {
  console.error('❌ Failed to reset state:', e);
} finally {
  db.close();
}
