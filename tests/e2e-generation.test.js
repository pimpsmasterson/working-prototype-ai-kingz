const assert = require('assert');
const supertest = require('supertest');
const sinon = require('sinon');
const fs = require('fs');
const path = require('path');
const { createComfyStub } = require('./helpers/comfy-stub');
const { resetDb } = require('./helpers/test-helper');
const db = require('../server/db');

describe('E2E Generation (ComfyUI stub) Tests', function() {
  this.timeout(15000); // Increase timeout for E2E tests

  let app;
  let request;
  let stubServer;
  let stubListener;
  let appListener;
  let fsStubs = {};
  let warmPool;

  before(function(done) {
    this.timeout(10000); // Timeout for setup
    process.env.ADMIN_API_KEY = 'test_admin_key';
    process.env.VASTAI_API_KEY = 'dummy_vast_key';
    process.env.AUDIT_SALT = 'test_salt';

    // Load app
    delete require.cache[require.resolve('../server/vastai-proxy')];
    delete require.cache[require.resolve('../server/generation-handler')];
    delete require.cache[require.resolve('../server/warm-pool')];

    app = require('../server/vastai-proxy');
    warmPool = require('../server/warm-pool');
    request = supertest(app);

    // Start actual server on port 3000 for generation-handler to connect to
    appListener = app.listen(3000, done);
  });

  after(function(done) {
    this.timeout(5000);
    if (appListener && appListener.close) appListener.close(done);
    else done();
  });

  beforeEach(async function() {
    resetDb();

    // Enable background generation in test for E2E
    process.env.ENABLE_ASYNC_GENERATION = '1';

    // Start comfy stub on 8188
    const comfyApp = createComfyStub();
    stubListener = comfyApp.listen(8188);

    // Configure warm pool to point to our stub (simulating a running remote instance)
    warmPool._internal.state.instance = {
      contractId: 'test_e2e_contract',
      status: 'running',
      connectionUrl: 'http://127.0.0.1:8188',
      createdAt: new Date().toISOString(),
      lastHeartbeat: new Date().toISOString(),
      leasedUntil: null
    };
    warmPool._internal.state.isPrewarming = false;

    // Stub disk writes to capture savePath and buffer
    fsStubs.writeFileSync = sinon.stub(fs, 'writeFileSync').callsFake((p, buf) => {
      // create a fake file entry in db as if saved
      // No-op here; tests will assert that this was called
      return true;
    });

    fsStubs.existsSync = sinon.stub(fs, 'existsSync').returns(true);
    fsStubs.statSync = sinon.stub(fs, 'statSync').returns({ size: 12345 });
  });

  afterEach(function(done) {
    // Restore stubs
    Object.values(fsStubs).forEach(st => { if (st && st.restore) st.restore(); });
    fsStubs = {};

    // Disable background generation after test
    delete process.env.ENABLE_ASYNC_GENERATION;

    // Clear warm pool state
    warmPool._internal.state.instance = null;
    warmPool._internal.state.isPrewarming = false;

    // Close comfy stub
    this.timeout(5000);
    if (stubListener && stubListener.close) stubListener.close(done); else done();
  });

  it('completes image generation end-to-end', async function() {
    this.timeout(10000);

    // Submit job
    const createRes = await request.post('/api/proxy/generate').send({ prompt: 'e2e image test', workflowType: 'image' });
    assert.strictEqual(createRes.status, 200);
    const jobId = createRes.body.jobId;

    // Poll until completed (simple retry loop) - allow for ComfyUI poll interval
    let statusRes;
    for (let i = 0; i < 60; i++) {
      statusRes = await request.get(`/api/proxy/generate/${jobId}`);
      if (statusRes.body.status === 'completed' || statusRes.body.status === 'failed') break;
      await new Promise(r => setTimeout(r, 200));
    }

    assert.strictEqual(statusRes.body.status, 'completed');

    // Ensure file write was attempted
    assert.ok(fsStubs.writeFileSync.called, 'Expected writeFileSync to be called');

    // Validate DB was updated
    const job = db.getJob(jobId);
    assert.strictEqual(job.status, 'completed');
    assert.ok(job.result_path || job.result_url);
  });

  it('completes video generation end-to-end', async function() {
    this.timeout(15000);

    const createRes = await request.post('/api/proxy/generate').send({ prompt: 'e2e video test', workflowType: 'video', settings: { frames: 8, fps: 8 } });
    assert.strictEqual(createRes.status, 200);
    const jobId = createRes.body.jobId;

    let statusRes;
    for (let i = 0; i < 40; i++) {
      statusRes = await request.get(`/api/proxy/generate/${jobId}`);
      if (statusRes.body.status === 'completed' || statusRes.body.status === 'failed') break;
      await new Promise(r => setTimeout(r, 200));
    }

    assert.strictEqual(statusRes.body.status, 'completed');
    assert.ok(fsStubs.writeFileSync.called, 'Expected writeFileSync for video');

    const job = db.getJob(jobId);
    assert.strictEqual(job.status, 'completed');
    assert.ok(job.result_path || job.result_url);
  });
});
