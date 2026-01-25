const assert = require('assert');
const supertest = require('supertest');
const { resetDb } = require('./helpers/test-helper');
const db = require('../server/db');

describe('Admin endpoints & audit', function() {
  let app;
  let request;

  before(async function() {
    resetDb();
    // Set env vars before requiring app
    process.env.ADMIN_API_KEY = 'test_admin_key';
    process.env.VASTAI_API_KEY = 'dummy';
    
    // Clear cache to ensure env vars are picked up
    delete require.cache[require.resolve('../server/vastai-proxy')];
    app = require('../server/vastai-proxy');
    request = supertest(app);
  });

  it('rejects admin requests without key and logs auth attempts', async function() {
    const res = await request.get('/api/proxy/admin/warm-pool');
    assert.strictEqual(res.status, 403);

    const rows = db.db.prepare('SELECT * FROM admin_audit WHERE action = ? ORDER BY id DESC LIMIT 1').all('auth_attempt');
    assert.ok(rows.length >= 1, 'auth attempt should be logged');
  });

  it('accepts admin set and records audit event', async function() {
    const nock = require('nock');
    
    // Mock the terminate call that happens when desiredSize is set to 0
    nock('https://console.vast.ai')
      .delete('/api/v0/instances/456/')
      .reply(200, { success: true });
    
    const res = await request.post('/api/proxy/admin/warm-pool')
      .set('x-admin-key', 'test_admin_key')
      .send({ desiredSize: 0 });

    assert.strictEqual(res.status, 200);
    const rows = db.db.prepare('SELECT * FROM admin_audit WHERE action = ? ORDER BY id DESC LIMIT 1').all('set_warm_pool');
    assert.ok(rows.length >= 1, 'set_warm_pool should be logged');
  });
});
