const Database = require('better-sqlite3');
const path = require('path');
const dbPath = path.join(__dirname, '..', 'data', 'warm_pool.db');
const db = new Database(dbPath);
console.log('DB Path:', dbPath);
console.log('Tables:');
const tables = db.prepare("SELECT name, sql FROM sqlite_master WHERE type='table'").all();
tables.forEach(t => console.log('-', t.name));
console.log('\n--- admin_audit schema ---');
try { console.log(db.prepare("PRAGMA table_info(admin_audit)").all()); } catch(e) { console.error('admin_audit error:', e.message); }
console.log('\n--- usage_events schema ---');
try { console.log(db.prepare("PRAGMA table_info(usage_events)").all()); } catch(e) { console.error('usage_events error:', e.message); }
db.close();
