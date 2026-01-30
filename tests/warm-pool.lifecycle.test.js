const assert = require('assert');
const path = require('path');
const { resetDb, nock, nockCleanAll } = require('./helpers/test-helper');
const db = require('../server/db');

describe('Warm-pool lifecycle (mocked)', function () {
  this.timeout(10000); // Increase timeout for async operations

  beforeEach(function () {
    resetDb();
    nock.cleanAll();
  });

  afterEach(function () { nockCleanAll(); });

  it('prewarm happy-path — rents an offer and becomes running', async function () {
    process.env.VASTAI_API_KEY = 'dummy_key';

    // Mock SSH key registration
    nock('https://console.vast.ai')
      .post('/api/v0/ssh/')
      .reply(200, { success: true });

    // Mock bundles -> one offer
    nock('https://console.vast.ai')
      .post('/api/v0/bundles/')
      .reply(200, { offers: [{ id: 123, dph_total: 0.5, rentable: true, rented: false, verification: 'verified', gpu_ram: 12288, disk_space: 320, reliability: 0.99, inet_down: 600 }] });

    // Mock asks PUT -> rent
    nock('https://console.vast.ai')
      .put('/api/v0/asks/123/')
      .reply(200, { new_contract: 777 });

    // Mock instances GET -> running with public_ip (allow multiple calls for readiness polling)
    nock('https://console.vast.ai')
      .get('/api/v0/instances/777/')
      .times(10)
      .reply(200, { status: 'running', public_ipaddr: '1.2.3.4' });

    // Mock ComfyUI readiness check
    nock('http://1.2.3.4:8188')
      .get('/system_stats')
      .reply(200, {
        system: { ram_total: 32000 },
        devices: [{ name: 'NVIDIA GPU' }]
      });

    const { reloadWarmPoolWithEnv } = require('./helpers/test-helper');
    const warmPool = reloadWarmPoolWithEnv({ VASTAI_API_KEY: 'dummy_key' });

    const res = await warmPool.prewarm();
    assert.strictEqual(res.status, 'started');

    const status = warmPool.getStatus();
    assert.ok(status.instance, 'instance should be present');
    assert.strictEqual(status.instance.status, 'ready');
    assert.ok(status.instance.connectionUrl && status.instance.connectionUrl.includes('1.2.3.4'));

    const rows = db.db.prepare('SELECT * FROM usage_events WHERE event_type = ?').all('instance_started');
    assert.ok(rows.length >= 1, 'instance_started event should be recorded');
  });

  it('claim sets lease and logs usage', async function () {
    process.env.VASTAI_API_KEY = 'dummy_key';

    // Pre-seed the state with a running instance
    const { reloadWarmPoolWithEnv } = require('./helpers/test-helper');
    const warmPool = reloadWarmPoolWithEnv({ VASTAI_API_KEY: 'dummy_key' });
    warmPool._internal.state.instance = { contractId: '888', status: 'running', connectionUrl: 'http://1.2.3.4:8188', createdAt: new Date().toISOString(), lastHeartbeat: new Date().toISOString(), leasedUntil: null };
    warmPool._internal.state.lastAction = new Date().toISOString();
    // Persist
    require('../server/db').saveState ? require('../server/db').saveState(warmPool._internal.state) : null;

    const claim = await warmPool.claim(1);
    assert.ok(claim.leasedUntil, 'leasedUntil should be set');

    const rows = db.db.prepare('SELECT * FROM usage_events WHERE event_type = ?').all('lease_claimed');
    assert.ok(rows.length >= 1, 'lease_claimed event should be recorded');
  });

  it('terminate clears tracked instance and logs termination', async function () {
    process.env.VASTAI_API_KEY = 'dummy_key';

    // Setup mock delete
    nock('https://console.vast.ai')
      .delete('/api/v0/instances/999/')
      .reply(200, { success: true });

    const { reloadWarmPoolWithEnv } = require('./helpers/test-helper');
    const warmPool = reloadWarmPoolWithEnv({ VASTAI_API_KEY: 'dummy_key' });
    warmPool._internal.state.instance = { contractId: '999', status: 'running', connectionUrl: 'http://1.2.3.4:8188', createdAt: new Date().toISOString(), lastHeartbeat: new Date().toISOString(), leasedUntil: null };
    warmPool._internal.state.lastAction = new Date().toISOString();

    const res = await warmPool.terminate('999');
    assert.strictEqual(res.status, 'terminated');
    const status = warmPool.getStatus();
    assert.strictEqual(status.instance, null);

    const rows = db.db.prepare('SELECT * FROM usage_events WHERE event_type = ?').all('instance_terminated');
    assert.ok(rows.length >= 1, 'instance_terminated event should be recorded');
  });
});
