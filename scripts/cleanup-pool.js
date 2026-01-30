// Clean up warm pool database
const Database = require('better-sqlite3');
const path = require('path');

const dbPath = path.join(__dirname, '..', 'data', 'warm_pool.db');
const db = new Database(dbPath);

console.log('Before cleanup:');
const before = db.prepare('SELECT * FROM warm_pool').all();
console.log(JSON.stringify(before, null, 2));

// Clear the instance
db.prepare('UPDATE warm_pool SET instance = NULL, isPrewarming = 0 WHERE id = 1').run();

console.log('\nAfter cleanup:');
const after = db.prepare('SELECT * FROM warm_pool').all();
console.log(JSON.stringify(after, null, 2));

db.close();
console.log('\n✅ Warm pool cleared!');
