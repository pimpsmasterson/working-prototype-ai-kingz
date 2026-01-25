const assert = require('assert');
const supertest = require('supertest');
const { resetDb } = require('./helpers/test-helper');
const sinon = require('sinon');

describe('Admin warm-pool endpoints', function() {
  let app;
  let request;

  before(function() {
    process.env.ADMIN_API_KEY = 'admin_test';
    process.env.VASTAI_API_KEY = 'vast_test';

    delete require.cache[require.resolve('../server/vastai-proxy')];
    app = require('../server/vastai-proxy');
    request = supertest(app);
  });

  beforeEach(function() {
    resetDb();
  });

  it('GET /api/proxy/warm-pool handles errors from getStatus', async function() {
    const warmPool = require('../server/warm-pool');
    const stub = sinon.stub(warmPool, 'getStatus').throws(new Error('status error'));

    const res = await request.get('/api/proxy/warm-pool');

    assert.strictEqual(res.status, 500);
    assert.ok(res.body.error);

    stub.restore();
  });

  it('GET /api/proxy/admin/warm-pool handles errors from getStatus', async function() {
    const warmPool = require('../server/warm-pool');
    const stub = sinon.stub(warmPool, 'getStatus').throws(new Error('status error'));

    const res = await request.get('/api/proxy/admin/warm-pool')
      .set('x-admin-key', 'admin_test');

    assert.strictEqual(res.status, 500);
    assert.ok(res.body.error);

    stub.restore();
  });

  it('POST /api/proxy/admin/warm-pool sets only desiredSize when safeMode is undefined', async function() {
    const warmPool = require('../server/warm-pool');
    warmPool._internal.state.instance = null;

    const res = await request.post('/api/proxy/admin/warm-pool')
      .set('x-admin-key', 'admin_test')
      .send({ desiredSize: 2 });

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.desiredSize, 2);
  });

  it('POST /api/proxy/admin/warm-pool sets only safeMode when desiredSize is undefined', async function() {
    const warmPool = require('../server/warm-pool');
    warmPool._internal.state.instance = null;

    const res = await request.post('/api/proxy/admin/warm-pool')
      .set('x-admin-key', 'admin_test')
      .send({ safeMode: true });

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.safeMode, true);
  });

  it('POST /api/proxy/admin/warm-pool handles errors from setDesiredSize/setSafeMode', async function() {
    const warmPool = require('../server/warm-pool');
    const stub = sinon.stub(warmPool, 'setDesiredSize').rejects(new Error('set error'));

    const res = await request.post('/api/proxy/admin/warm-pool')
      .set('x-admin-key', 'admin_test')
      .send({ desiredSize: 1 });

    assert.strictEqual(res.status, 500);
    assert.ok(res.body.error);

    stub.restore();
  });

  it('POST /api/proxy/admin/warm-pool rejects invalid admin key', async function() {
    const res = await request.post('/api/proxy/admin/warm-pool')
      .set('x-admin-key', 'wrong_key')
      .send({ desiredSize: 1 });

    assert.strictEqual(res.status, 403);
    assert.ok(res.body.error);
  });

  it('POST /api/proxy/admin/warm-pool handles audit log errors gracefully', async function() {
    const warmPool = require('../server/warm-pool');
    const audit = require('../server/audit');
    const auditStub = sinon.stub(audit, 'logAdminEvent').throws(new Error('audit failed'));

    warmPool._internal.state.instance = null;

    const res = await request.post('/api/proxy/admin/warm-pool')
      .set('x-admin-key', 'admin_test')
      .send({ desiredSize: 1 });

    // Should still succeed despite audit error
    assert.strictEqual(res.status, 200);

    auditStub.restore();
  });
});
