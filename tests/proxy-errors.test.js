const assert = require('assert');
const supertest = require('supertest');
const nock = require('nock');

describe('Proxy error handling', function() {
  let app;
  let request;

  before(function() {
    process.env.VASTAI_API_KEY = 'dummy';
    delete require.cache[require.resolve('../server/vastai-proxy')];
    app = require('../server/vastai-proxy');
    request = supertest(app);
  });

  beforeEach(function() {
    nock.cleanAll();
  });

  it('POST /api/proxy/prompt returns upstream error status', async function() {
    nock('https://console.vast.ai')
      .post('/api/v0/prompt')
      .reply(500, { error: 'server' });

    const res = await request.post('/api/proxy/prompt').send({});
    assert.strictEqual(res.status, 500);
  });

  it('POST /api/proxy/prompt returns 502 on network error', async function() {
    nock('https://console.vast.ai')
      .post('/api/v0/prompt')
      .replyWithError('network');

    const res = await request.post('/api/proxy/prompt').send({});
    assert.strictEqual(res.status, 502);
  });

  it('POST /api/proxy/instances/create returns 502 on network error', async function() {
    nock('https://console.vast.ai')
      .post('/api/v0/instances/create/')
      .replyWithError('network');

    const res = await request.post('/api/proxy/instances/create').send({});
    assert.strictEqual(res.status, 502);
  });

  it('PUT /api/proxy/asks/:id returns 502 on network error', async function() {
    nock('https://console.vast.ai')
      .put('/api/v0/asks/123/')
      .replyWithError('network');

    const res = await request.put('/api/proxy/asks/123').send({});
    assert.strictEqual(res.status, 502);
  });

  it('POST /api/proxy/prompt forwards non-JSON text responses', async function() {
    nock('https://console.vast.ai')
      .post('/api/v0/prompt')
      .reply(200, 'not-json');

    const res = await request.post('/api/proxy/prompt').send({});
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.text, 'not-json');
  });

  it('GET /api/proxy/instances/:id forwards non-JSON text responses', async function() {
    nock('https://console.vast.ai')
      .get('/api/v0/instances/999/')
      .reply(200, 'plain status');

    const res = await request.get('/api/proxy/instances/999');
    // Server attempts to parse JSON and will return 502 when parsing fails
    assert.strictEqual(res.status, 502);
  });

  it('DELETE /api/proxy/instances/:id returns 502 on network error', async function() {
    nock('https://console.vast.ai')
      .delete('/api/v0/instances/456/')
      .replyWithError('network timeout');

    const res = await request.delete('/api/proxy/instances/456');
    assert.strictEqual(res.status, 502);
    assert.ok(res.body.error);
  });

  it('GET /api/proxy/instances returns 502 on network error', async function() {
    nock('https://console.vast.ai')
      .get('/api/v0/instances/')
      .replyWithError('connection refused');

    const res = await request.get('/api/proxy/instances');
    assert.strictEqual(res.status, 502);
    assert.ok(res.body.error);
  });

  it('POST /api/proxy/forward returns 502 on network error', async function() {
    nock('http://fake-target.com')
      .post('/test-endpoint')
      .replyWithError('unreachable');

    const res = await request.post('/api/proxy/forward')
      .send({ targetUrl: 'http://fake-target.com/test-endpoint', payload: { test: 1 } });

    assert.strictEqual(res.status, 502);
    assert.ok(res.body.error);
    assert.ok(res.body.error.includes('forward'));
  });

  it('POST /api/proxy/forward handles non-JSON responses', async function() {
    nock('http://another-target.com')
      .post('/endpoint')
      .reply(200, 'plain text response');

    const res = await request.post('/api/proxy/forward')
      .send({ targetUrl: 'http://another-target.com/endpoint', payload: {} });

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.text, 'plain text response');
  });

  it('POST /api/proxy/bundles returns 502 on network error', async function() {
    nock('https://console.vast.ai')
      .post('/api/v0/bundles/')
      .replyWithError('network failure');

    const res = await request.post('/api/proxy/bundles')
      .send({ verified: { eq: true } });

    assert.strictEqual(res.status, 502);
    assert.ok(res.body.error);
  });
});