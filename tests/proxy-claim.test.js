const assert = require('assert');
const supertest = require('supertest');
const { resetDb } = require('./helpers/test-helper');

describe('Warm-pool claim endpoint', function() {
  let app;
  let request;

  before(function() {
    process.env.VASTAI_API_KEY = 'test_key';
    process.env.ADMIN_API_KEY = 'admin_key';

    delete require.cache[require.resolve('../server/vastai-proxy')];
    app = require('../server/vastai-proxy');
    request = supertest(app);
  });

  beforeEach(function() {
    resetDb();
  });

  it('POST /api/proxy/warm-pool/claim handles claim errors gracefully', async function() {
    const warmPool = require('../server/warm-pool');

    // Set up state to trigger claim failure
    warmPool._internal.state.instance = null;

    const res = await request.post('/api/proxy/warm-pool/claim')
      .send({ maxMinutes: 30 });

    assert.strictEqual(res.status, 404);
    assert.ok(res.body.error);
  });

  it('POST /api/proxy/warm-pool/claim succeeds when instance available', async function() {
    const warmPool = require('../server/warm-pool');

    // Set up a ready instance (ComfyUI responsive)
    warmPool._internal.state.instance = {
      contractId: '123',
      status: 'ready',
      connectionUrl: 'http://1.2.3.4:8188',
      createdAt: new Date().toISOString()
    };

    const res = await request.post('/api/proxy/warm-pool/claim')
      .send({ maxMinutes: 60 });

    assert.strictEqual(res.status, 200);
    assert.ok(res.body.connectionUrl);
  });

  it('POST /api/proxy/warm-pool/claim handles exceptions during claim', async function() {
    const warmPool = require('../server/warm-pool');
    const sinon = require('sinon');

    // Stub claim to throw an error
    const claimStub = sinon.stub(warmPool, 'claim').rejects(new Error('claim failed'));

    const res = await request.post('/api/proxy/warm-pool/claim')
      .send({ maxMinutes: 30 });

    assert.strictEqual(res.status, 500);
    assert.ok(res.body.error);

    claimStub.restore();
  });
});
