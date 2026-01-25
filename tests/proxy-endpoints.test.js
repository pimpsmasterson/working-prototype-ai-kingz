const assert = require('assert');
const supertest = require('supertest');
const nock = require('nock');
const { resetDb } = require('./helpers/test-helper');

describe('Proxy Vast.ai endpoints', function() {
  let app;
  let request;

  before(function() {
    process.env.VASTAI_API_KEY = 'test_vast_key';
    process.env.ADMIN_API_KEY = 'test_admin_key';
    
    delete require.cache[require.resolve('../server/vastai-proxy')];
    app = require('../server/vastai-proxy');
    request = supertest(app);
  });

  beforeEach(function() {
    nock.cleanAll();
  });

  it('POST /api/proxy/bundles proxies to Vast.ai', async function() {
    nock('https://console.vast.ai')
      .post('/api/v0/bundles/')
      .reply(200, { offers: [{ id: 1, dph_total: 0.5 }] });

    const res = await request.post('/api/proxy/bundles')
      .send({ verified: { eq: true } });

    assert.strictEqual(res.status, 200);
    assert.ok(res.body.offers);
  });

  it('GET /api/proxy/instances/:id proxies instance status', async function() {
    nock('https://console.vast.ai')
      .get('/api/v0/instances/123/')
      .reply(200, { instances: [{ id: 123, actual_status: 'running' }] });

    const res = await request.get('/api/proxy/instances/123');
    
    assert.strictEqual(res.status, 200);
    assert.ok(res.body.instances);
  });

  it('DELETE /api/proxy/instances/:id proxies termination', async function() {
    nock('https://console.vast.ai')
      .delete('/api/v0/instances/123/')
      .reply(200, { success: true });

    const res = await request.delete('/api/proxy/instances/123');
    
    assert.strictEqual(res.status, 200);
    assert.ok(res.body.success);
  });

  it('GET /api/proxy/instances lists all instances', async function() {
    nock('https://console.vast.ai')
      .get('/api/v0/instances/')
      .reply(200, { instances: [] });

    const res = await request.get('/api/proxy/instances');
    
    assert.strictEqual(res.status, 200);
    assert.ok(Array.isArray(res.body.instances));
  });

  it('PUT /api/proxy/asks/:id rents an instance', async function() {
    nock('https://console.vast.ai')
      .put('/api/v0/asks/456/')
      .reply(200, { new_contract: 789 });

    const res = await request.put('/api/proxy/asks/456')
      .send({ image: 'pytorch/pytorch:latest' });

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.new_contract, 789);
  });

  it('POST /api/proxy/instances/create proxies instance creation', async function() {
    nock('https://console.vast.ai')
      .post('/api/v0/instances/create/')
      .reply(200, { success: true, new_contract: 456 });

    const res = await request.post('/api/proxy/instances/create')
      .send({ image: 'pytorch/pytorch', runtype: 'ssh' });

    assert.strictEqual(res.status, 200);
    assert.ok(res.body.success);
    assert.strictEqual(res.body.new_contract, 456);
  });

  it('POST /api/proxy/admin/set-tokens rejects requests from non-localhost when trust proxy is enabled', async function() {
    // Enable trust proxy so X-Forwarded-For can influence req.ip
    app.set('trust proxy', true);
    const res = await request.post('/api/proxy/admin/set-tokens')
      .set('X-Forwarded-For', '8.8.8.8')
      .send({ huggingface: 'hf_value' });
    assert.strictEqual(res.status, 403);
    app.set('trust proxy', false);
  });

  it('app can be started and stopped via listen/close', async function() {
    const srv = app.listen(0);
    const addr = srv.address();
    assert.ok(addr && addr.port);
    await new Promise((res) => srv.close(res));
  });
});
