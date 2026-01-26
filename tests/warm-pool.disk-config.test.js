const assert = require('assert');
const nock = require('nock');
const { resetDb } = require('./helpers/test-helper');

describe('WarmPool disk configurability', function() {
  beforeEach(function() {
    resetDb();
    process.env.VASTAI_API_KEY = 'dummy';
    process.env.WARM_POOL_DISK_GB = '120';
    // Make sure module reloads with new env
    delete require.cache[require.resolve('../server/warm-pool')];
  });

  it('filters offers by disk and requests configured disk in rent body', async function() {
    const warmPool = require('../server/warm-pool');
    // Short-circuit readiness checks to keep test fast
    warmPool.waitForComfyReady = async () => true;

    // Mock SSH key registration
    nock('https://console.vast.ai')
      .post('/api/v0/ssh/')
      .reply(200, { ok: true });

    // Mock bundles: one offer with insufficient disk, one with enough
    const offers = [
      { id: '11', rentable: true, rented: false, dph_total: 0.5, gpu_ram: 16384, disk_space: 64 },
      { id: '42', rentable: true, rented: false, dph_total: 0.6, gpu_ram: 16384, disk_space: 200 }
    ];

    nock('https://console.vast.ai')
      .post('/api/v0/bundles/')
      .reply(200, { offers });

    let capturedRentBody = null;
    nock('https://console.vast.ai')
      .put('/api/v0/asks/42/', body => {
        capturedRentBody = body;
        return true;
      })
      .reply(200, { new_contract: 'contract-42' });

    // Mock instances lookup (checkInstance) to avoid external calls
    nock('https://console.vast.ai')
      .get('/api/v0/instances/contract-42/')
      .reply(200, { instances: { actual_status: 'running', public_ipaddr: '127.0.0.1', status: 'running' } });

    const res = await warmPool.prewarm();
    assert.ok(res.instance, 'Expected instance to be created');
    assert.strictEqual(res.instance.contractId, 'contract-42');
    assert.ok(capturedRentBody, 'Rent PUT body was not captured');

    // The requested disk should equal the configured WARM_POOL_DISK_GB (120), clamped by warm-pool
    const expectedDisk = parseInt(process.env.WARM_POOL_DISK_GB, 10);
    assert.strictEqual(Number(capturedRentBody.disk), expectedDisk);
  });
});
