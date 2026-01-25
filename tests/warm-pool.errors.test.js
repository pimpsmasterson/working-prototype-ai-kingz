const assert = require('assert');
const nock = require('nock');
const { resetDb, nockCleanAll } = require('./helpers/test-helper');

describe('Warm-pool error handling', function() {
  this.timeout(10000);
  beforeEach(function() { resetDb(); nock.cleanAll(); });
  afterEach(function() { nockCleanAll(); });

  it('prewarm failure when no offers', async function() {
    process.env.VASTAI_API_KEY = 'dummy_key';

    // bundles returns empty offers
    nock('https://console.vast.ai')
      .post('/api/v0/bundles/')
      .times(3)
      .reply(200, { offers: [] });

    const { reloadWarmPoolWithEnv } = require('./helpers/test-helper');
    const warmPool = reloadWarmPoolWithEnv({ VASTAI_API_KEY: 'dummy_key' });
    try {
      await warmPool.prewarm();
      assert.fail('prewarm should throw when no offers available');
    } catch (e) {
      assert.ok(e.message && e.message.includes('No offers'), 'expected no offers error');
    }
  });

  it('prewarm handles 500 from asks PUT gracefully', async function() {
    process.env.VASTAI_API_KEY = 'dummy_key';

    nock('https://console.vast.ai')
      .post('/api/v0/bundles/')
      .reply(200, { offers: [{ id: 55, dph_total: 0.5, rentable: true, rented: false, verification: 'verified', gpu_ram: 8192 }] });

    nock('https://console.vast.ai')
      .put('/api/v0/asks/55/')
      .reply(500, { error: 'server error' });

    const { reloadWarmPoolWithEnv } = require('./helpers/test-helper');
    const warmPool = reloadWarmPoolWithEnv({ VASTAI_API_KEY: 'dummy_key' });
    try {
      await warmPool.prewarm();
      assert.fail('prewarm should throw on rent error');
    } catch (e) {
      assert.ok(e.message, 'expected error thrown');
    }
  });
});
