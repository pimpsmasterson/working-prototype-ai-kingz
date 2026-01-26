const assert = require('assert');
const supertest = require('supertest');
const nock = require('nock');
const { resetDb } = require('./helpers/test-helper');
const db = require('../server/db');

describe('Admin logs and ComfyUI proxy', function() {
  this.timeout(10000); // Increase timeout for server startup

  let app;
  let request;

  before(function() {
    process.env.ADMIN_API_KEY = 'admin_key_test';
    process.env.VASTAI_API_KEY = 'vast_test_key';
    
    delete require.cache[require.resolve('../server/vastai-proxy')];
    app = require('../server/vastai-proxy');
    request = supertest(app);
  });

  beforeEach(function() {
    resetDb();
    nock.cleanAll();
  });

  it('GET /api/proxy/admin/logs returns logs with valid key', async function() {
    // Seed some audit logs
    const audit = require('../server/audit');
    audit.logAdminEvent({ adminKey: 'admin_key_test', ip: '127.0.0.1', route: '/test', action: 'test_action', outcome: 'ok' });
    
    const res = await request.get('/api/proxy/admin/logs?limit=10')
      .set('x-admin-key', 'admin_key_test');
    
    assert.strictEqual(res.status, 200);
    assert.ok(Array.isArray(res.body.rows));
    assert.ok(res.body.total >= 1);
  });

  it('GET /api/proxy/admin/logs filters by action', async function() {
    const audit = require('../server/audit');
    audit.logAdminEvent({ adminKey: 'admin_key_test', ip: '127.0.0.1', route: '/test', action: 'filter_test', outcome: 'ok' });
    audit.logAdminEvent({ adminKey: 'admin_key_test', ip: '127.0.0.1', route: '/test2', action: 'other_action', outcome: 'ok' });
    
    const res = await request.get('/api/proxy/admin/logs?action=filter_test')
      .set('x-admin-key', 'admin_key_test');
    
    assert.strictEqual(res.status, 200);
    assert.ok(res.body.rows.some(r => r.action === 'filter_test'));
  });

  it('GET /api/proxy/admin/logs rejects invalid key', async function() {
    const res = await request.get('/api/proxy/admin/logs')
      .set('x-admin-key', 'wrong_key');

    assert.strictEqual(res.status, 403);
  });

  it('GET /api/proxy/admin/logs handles database errors gracefully', async function() {
    const dbMod = require('../server/db');
    const sinon = require('sinon');

    // Stub db.prepare to throw an error
    const prepareStub = sinon.stub(dbMod.db, 'prepare').throws(new Error('DB error'));

    const res = await request.get('/api/proxy/admin/logs')
      .set('x-admin-key', 'admin_key_test');

    assert.strictEqual(res.status, 500);
    assert.ok(res.body.error);

    prepareStub.restore();
  });

  it('POST /api/proxy/warm-pool/terminate requires admin key', async function() {
    const res = await request.post('/api/proxy/warm-pool/terminate')
      .send({ instanceId: '123' });
    
    assert.strictEqual(res.status, 403);
  });

  it('POST /api/proxy/warm-pool/terminate works with admin key', async function() {
    const warmPool = require('../server/warm-pool');
    warmPool._internal.state.instance = { contractId: '999', status: 'running', createdAt: new Date().toISOString() };
    
    nock('https://console.vast.ai')
      .delete('/api/v0/instances/999/')
      .reply(200, { success: true });
    
    const res = await request.post('/api/proxy/warm-pool/terminate')
      .set('x-admin-key', 'admin_key_test')
      .send({ instanceId: '999' });
    
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.status, 'terminated');
  });

  it('/api/proxy/comfy/* forwards to warm instance', async function() {
    const warmPool = require('../server/warm-pool');
    warmPool._internal.state.instance = {
      contractId: '777',
      status: 'running',
      connectionUrl: 'http://10.0.0.1:8188',
      createdAt: new Date().toISOString()
    };

    nock('http://10.0.0.1:8188')
      .get('/queue')
      .reply(200, { queue_running: [], queue_pending: [] });

    // Assert warm-pool status is visible to proxy
    const poolStatus = require('../server/warm-pool').getStatus();
    assert.ok(poolStatus.instance && poolStatus.instance.connectionUrl === 'http://10.0.0.1:8188');

    const res = await request.get('/api/proxy/comfy/queue');

    assert.strictEqual(res.status, 200);
    assert.ok(res.body.queue_running !== undefined);
  });

  it('/api/proxy/comfy/* forwards POST requests with body', async function() {
    const warmPool = require('../server/warm-pool');
    warmPool._internal.state.instance = {
      contractId: '888',
      status: 'running',
      connectionUrl: 'http://10.0.0.3:8188',
      createdAt: new Date().toISOString()
    };

    nock('http://10.0.0.3:8188')
      .post('/prompt', { workflow: 'test' })
      .reply(200, { prompt_id: 'abc123' });

    const res = await request.post('/api/proxy/comfy/prompt')
      .send({ workflow: 'test' });

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.prompt_id, 'abc123');
  });

  it('/api/proxy/comfy returns 404 when no instance available', async function() {
    const warmPool = require('../server/warm-pool');
    warmPool._internal.state.instance = null;

    const res = await request.get('/api/proxy/comfy/queue');

    assert.strictEqual(res.status, 404);
    assert.ok(res.body.error.includes('no warm instance'));
  });

  it('/api/proxy/comfy returns 502 on upstream network error', async function() {
    const warmPool = require('../server/warm-pool');
    warmPool._internal.state.instance = {
      contractId: '888',
      status: 'running',
      connectionUrl: 'http://10.0.0.2:8188',
      createdAt: new Date().toISOString()
    };

    nock('http://10.0.0.2:8188')
      .get('/queue')
      .replyWithError('connection refused');

    const res = await request.get('/api/proxy/comfy/queue');

    assert.strictEqual(res.status, 502);
    assert.ok(res.body.error.includes('comfy proxy error'));
  });

  it('POST /api/proxy/warm-pool/prewarm handles errors', async function() {
    const warmPool = require('../server/warm-pool');
    const sinon = require('sinon');

    // Stub prewarm to throw
    const prewarmStub = sinon.stub(warmPool, 'prewarm').rejects(new Error('prewarm failed'));

    const res = await request.post('/api/proxy/warm-pool/prewarm')
      .set('x-admin-api-key', 'admin_key_test');

    assert.strictEqual(res.status, 500);
    assert.ok(res.body.error);

    prewarmStub.restore();
  });

  it('POST /api/proxy/warm-pool/terminate handles errors', async function() {
    const warmPool = require('../server/warm-pool');
    const sinon = require('sinon');

    // Stub terminate to throw
    const terminateStub = sinon.stub(warmPool, 'terminate').rejects(new Error('terminate failed'));

    const res = await request.post('/api/proxy/warm-pool/terminate')
      .set('x-admin-key', 'admin_key_test')
      .send({ instanceId: '999' });

    assert.strictEqual(res.status, 500);
    assert.ok(res.body.error);

    terminateStub.restore();
  });
});
