#!/usr/bin/env node
// Fix the connectionUrl in warm_pool.db to use localhost:8188 (SSH tunnel)

const path = require('path');
const Database = require('better-sqlite3');

const DB_PATH = path.join(__dirname, '..', 'data', 'warm_pool.db');
console.log('Opening database:', DB_PATH);

const db = new Database(DB_PATH);

try {
  const row = db.prepare('SELECT instance FROM warm_pool WHERE id = 1').get();

  if (!row || !row.instance) {
    console.error('ERROR: No instance found in warm_pool table');
    process.exit(1);
  }

  const instance = JSON.parse(row.instance);
  console.log('Current connectionUrl:', instance.connectionUrl);
  console.log('Current contractId:', instance.contractId);
  console.log('Current status:', instance.status);

  if (instance.connectionUrl === 'http://localhost:8188') {
    console.log('connectionUrl is already correct - no update needed');
  } else {
    instance.connectionUrl = 'http://localhost:8188';
    db.prepare('UPDATE warm_pool SET instance = ? WHERE id = 1').run(JSON.stringify(instance));
    console.log('Updated connectionUrl to:', instance.connectionUrl);
  }

  // Verify the change
  const verify = db.prepare('SELECT instance FROM warm_pool WHERE id = 1').get();
  const verifyInstance = JSON.parse(verify.instance);
  console.log('Verified connectionUrl:', verifyInstance.connectionUrl);

} catch (err) {
  console.error('Error:', err.message);
  process.exit(1);
} finally {
  db.close();
}

console.log('Database update complete!');
