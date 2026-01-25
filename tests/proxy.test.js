const assert = require('assert');
const supertest = require('supertest');
const nock = require('nock');
const { resetDb } = require('./helpers/test-helper');
const db = require('../server/db');

describe('Proxy API Endpoints', function() {
  let app;
  let request;

  before(function() {
    process.env.ADMIN_API_KEY = 'test_admin_key';
    process.env.VASTAI_API_KEY = 'dummy_vast_key';
    process.env.AUDIT_SALT = 'test_salt';
    
    // Clear cache for both to ensure they see the env vars and each other
    delete require.cache[require.resolve('../server/warm-pool')];
    delete require.cache[require.resolve('../server/vastai-proxy')];
    
    app = require('../server/vastai-proxy');
    request = supertest(app);
  });

  beforeEach(function() {
    resetDb();
    nock.cleanAll();
  });

  it('GET /api/proxy/health returns 200', async function() {
    const res = await request.get('/api/proxy/health');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.status, 'running');
  });

  it('GET /api/proxy/check-tokens returns token presence', async function() {
    const res = await request.get('/api/proxy/check-tokens');
    assert.strictEqual(res.status, 200);
    assert.ok(res.body.vastai);
  });

  it('POST /api/proxy/admin/set-tokens works from localhost', async function() {
    const res = await request.post('/api/proxy/admin/set-tokens')
      .send({ huggingface: 'hf_test', civitai: 'cv_test' });
    
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.huggingface, true);
    assert.strictEqual(res.body.civitai, true);
    assert.strictEqual(process.env.HUGGINGFACE_HUB_TOKEN, 'hf_test');
  });

  it('POST /api/proxy/warm-pool/prewarm calls warm-pool prewarm', async function() {
    // Mock Vast.ai responses that prewarm calls
    nock('https://console.vast.ai')
      .post('/api/v0/bundles/')
      .reply(200, { offers: [{ id: 123, dph_total: 0.1, gpu_ram: 16384 }] });
    
    nock('https://console.vast.ai')
      .put('/api/v0/asks/123/')
      .reply(200, { new_contract: 456 });
    
    // Mock checkInstance call that happens immediately after prewarm
    nock('https://console.vast.ai')
      .get('/api/v0/instances/456/')
      .reply(200, { instances: [{ id: 456, actual_status: 'starting' }] });

    const res = await request.post('/api/proxy/warm-pool/prewarm');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.status, 'started');
  });

  it('POST /api/proxy/warm-pool/claim calls warm-pool claim', async function() {
    // Reset and manually set an instance in state to claim
    resetDb();
    const warmPool = require('../server/warm-pool');
    const db = require('../server/db');
    
    // Set up a running instance (mutate original state to keep module internals consistent)
    Object.assign(warmPool._internal.state, {
      instance: { 
        contractId: '456', 
        status: 'running', 
        connectionUrl: 'http://1.1.1.1:8188', 
        createdAt: new Date().toISOString(),
        lastHeartbeat: new Date().toISOString(),
        leasedUntil: null
      },
      desiredSize: 1,
      safeMode: false
    });
    
    // Persist to DB
    db.saveState(warmPool._internal.state);
    
    const res = await request.post('/api/proxy/warm-pool/claim')
      .send({ maxMinutes: 60 });
    
    assert.strictEqual(res.status, 200);
    assert.ok(res.body.leasedUntil);
  });

  it('GET /api/proxy/warm-pool returns status', async function() {
    const res = await request.get('/api/proxy/warm-pool');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(typeof res.body.desiredSize, 'number');
  });
});
