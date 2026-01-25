const assert = require('assert');
const nock = require('nock');
const { resetDb } = require('./helpers/test-helper');

describe('WarmPool unit behaviors', function() {
  beforeEach(function() {
    resetDb();
    process.env.VASTAI_API_KEY = 'dummy';
  });

  it('terminate returns no_instance when none present', async function() {
    const warmPool = require('../server/warm-pool');
    // Ensure no instance
    warmPool._internal.state.instance = null;
    const res = await warmPool.terminate();
    assert.strictEqual(res.status, 'no_instance');
  });

  it('checkInstance handles upstream failures gracefully', async function() {
    const warmPool = require('../server/warm-pool');
    warmPool._internal.state.instance = { contractId: '555', status: 'running' };

    // Simulate network error
    nock('https://console.vast.ai')
      .get('/api/v0/instances/555/')
      .replyWithError('network');

    const res = await warmPool.checkInstance();
    assert.strictEqual(res, null);
    // Ensure lastError was captured on the instance
    assert.ok(warmPool._internal.state.instance && warmPool._internal.state.instance.lastError);
  });
});