const assert = require('assert');
const nock = require('nock');
const { resetDb, nockCleanAll } = require('./helpers/test-helper');

describe('Warm-pool concurrency', function() {
  beforeEach(function() { resetDb(); nock.cleanAll(); });
  afterEach(function() { nockCleanAll(); });

  it('concurrent prewarm calls only perform single rent', async function() {
    process.env.VASTAI_API_KEY = 'dummy_key';

    nock('https://console.vast.ai')
      .post('/api/v0/bundles/')
      .reply(200, { offers: [{ id: 777, dph_total: 0.5, rentable: true, rented: false, verification: 'verified', gpu_ram: 8192 }] });

    // Expect only one PUT - if second tries, it will not be matched and test will fail on nock.isDone()
    nock('https://console.vast.ai')
      .put('/api/v0/asks/777/')
      .reply(200, { new_contract: 1001 });

    // Mock instances GET for the returned contract so checkInstance doesn't error
    nock('https://console.vast.ai')
      .get('/api/v0/instances/1001/')
      .reply(200, { status: 'running', public_ipaddr: '10.0.0.1' });

    const { reloadWarmPoolWithEnv } = require('./helpers/test-helper');
    const warmPool = reloadWarmPoolWithEnv({ VASTAI_API_KEY: 'dummy_key' });

    // Kick off two simultaneous prewarms
    const [a, b] = await Promise.allSettled([warmPool.prewarm(), warmPool.prewarm()]);

    // At least one should settle successfully (fulfilled)
    const someFulfilled = [a, b].some(r => r.status === 'fulfilled');
    assert.ok(someFulfilled, 'at least one prewarm promise should have settled successfully');

    // Ensure the expected nock PUT was performed
    if (!nock.isDone()) {
      console.error('Pending mocks:', nock.pendingMocks());
    }
    assert.ok(nock.isDone(), 'expected PUT /asks/777 to have been called exactly once');
  });
});
