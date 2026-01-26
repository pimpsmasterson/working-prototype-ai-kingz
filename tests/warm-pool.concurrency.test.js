const assert = require('assert');
const nock = require('nock');
const { resetDb, nockCleanAll } = require('./helpers/test-helper');

describe('Warm-pool concurrency', function() {
  beforeEach(function() { resetDb(); nock.cleanAll(); });
  afterEach(function() { nockCleanAll(); });

  it('concurrent prewarm calls only perform single rent', async function() {
    process.env.VASTAI_API_KEY = 'dummy_key';

    // Track PUT request count
    let putCount = 0;

    // Mock bundle search (find offers)
    nock('https://console.vast.ai')
      .post('/api/v0/bundles/')
      .reply(200, { offers: [{ id: 5, dph_total: 0.5, gpu_ram: 16000, disk_space: 250, rentable: true, rented: false }] });

    // Mock SSH key registration
    nock('https://console.vast.ai')
      .post('/api/v0/ssh/')
      .reply(200, { success: true });

    // Mock the PUT request - allow it to be called multiple times but track the count
    nock('https://console.vast.ai')
      .put('/api/v0/asks/5/', () => {
        putCount++;
        return true; // Accept any body
      })
      .times(2) // Allow up to 2 calls to avoid unhandled rejections
      .reply(200, { new_contract: 1001 });

    // Mock instances GET for the returned contract so checkInstance doesn't error (allow multiple for polling)
    nock('https://console.vast.ai')
      .get(/\/api\/v0\/instances\/\d+\/$/)
      .times(10)
      .reply(200, { status: 'running', public_ipaddr: '10.0.0.1' });

    // Mock ComfyUI readiness check
    nock('http://10.0.0.1:8188')
      .get('/system_stats')
      .times(2) // Allow multiple checks
      .reply(200, {
        system: { ram_total: 32000 },
        devices: [{ name: 'NVIDIA GPU' }]
      });

    const { reloadWarmPoolWithEnv } = require('./helpers/test-helper');
    const warmPool = reloadWarmPoolWithEnv({ VASTAI_API_KEY: 'dummy_key' });

    // Kick off two simultaneous prewarms
    const [a, b] = await Promise.allSettled([warmPool.prewarm(), warmPool.prewarm()]);

    // At least one should settle successfully (fulfilled)
    const someFulfilled = [a, b].some(r => r.status === 'fulfilled');
    assert.ok(someFulfilled, 'at least one prewarm promise should have settled successfully');

    // Verify only one PUT was actually made (concurrency control working)
    assert.strictEqual(putCount, 1, 'expected exactly one PUT /asks/5 to have been called (concurrency prevented duplicate)');
  });
});
