// Fix database connectionUrl to use localhost tunnel
const Database = require('better-sqlite3');
const path = require('path');

const DB_PATH = path.join(__dirname, '..', 'data', 'warm_pool.db');
const db = new Database(DB_PATH);

try {
    // Check current instances
    const instances = db.prepare('SELECT contractId, connectionUrl, status FROM instances').all();
    console.log('\nCurrent instances:');
    console.table(instances);

    if (instances.length === 0) {
        console.log('\n⚠️ No instances found in database.');
        process.exit(0);
    }

    // Update all running instances to use localhost tunnel
    const result = db.prepare(`
        UPDATE instances 
        SET connectionUrl = ? 
        WHERE status = 'running'
    `).run('http://localhost:8188');

    console.log(`\n✅ Updated ${result.changes} instance(s) to use http://localhost:8188`);

    // Show updated state
    const updated = db.prepare('SELECT contractId, connectionUrl, status FROM instances').all();
    console.log('\nUpdated instances:');
    console.table(updated);

} catch (error) {
    console.error('❌ Error updating database:', error);
    process.exit(1);
} finally {
    db.close();
}
