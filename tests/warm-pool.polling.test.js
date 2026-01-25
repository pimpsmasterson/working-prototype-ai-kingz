const assert = require('assert');
const sinon = require('sinon');
const nock = require('nock');
const { resetDb } = require('./helpers/test-helper');

describe('Warm-pool polling & idle shutdown', function() {
  let clock;
  let warmPool;

  before(function() {
    // Set API key before loading module
    process.env.VASTAI_API_KEY = 'dummy_vast_key';
  });

  beforeEach(function() {
    resetDb();
    nock.cleanAll();
    clock = sinon.useFakeTimers();
    // Re-require to get fresh state and start polling with controlled clock
    delete require.cache[require.resolve('../server/warm-pool')];
    warmPool = require('../server/warm-pool');
    // Manually start polling for tests that need it
    warmPool.startPolling({ intervalMs: 30000 });
  });

  afterEach(function() {
    warmPool.stopPolling();
    clock.restore();
    nock.cleanAll();
  });

  it('terminates instance when desiredSize is set to 0', async function() {
    // Seed with a running instance
    warmPool._internal.state.instance = { contractId: '777', status: 'running', createdAt: new Date().toISOString() };
    
    // Mock termination
    nock('https://console.vast.ai')
      .delete('/api/v0/instances/777/')
      .reply(200, { success: true });

    await warmPool.setDesiredSize(0);
    
    assert.strictEqual(warmPool._internal.state.instance, null);
    assert.strictEqual(warmPool._internal.state.desiredSize, 0);
  });

  it('terminates instance when safeMode is enabled', async function() {
    warmPool._internal.state.instance = { contractId: '777', status: 'running', createdAt: new Date().toISOString() };
    
    nock('https://console.vast.ai')
      .delete('/api/v0/instances/777/')
      .reply(200, { success: true });

    await warmPool.setSafeMode(true);
    
    assert.strictEqual(warmPool._internal.state.instance, null);
    assert.strictEqual(warmPool._internal.state.safeMode, true);
  });

  it('auto-terminates idle instance after timeout', async function() {
    // Stop any existing polling to ensure clean setup
    warmPool.stopPolling();
    
    // interval is 30s. default maxIdleMinutes is 15.
    // If we set lastAction to 16 minutes ago:
    const sixteenMinsAgo = new Date(Date.now() - 16 * 60 * 1000).toISOString();
    // Mutate existing state object properties
    Object.assign(warmPool._internal.state, {
      instance: { 
        contractId: '777', 
        status: 'running', 
        createdAt: sixteenMinsAgo,
        lastHeartbeat: sixteenMinsAgo,
        leasedUntil: null 
      },
      lastAction: sixteenMinsAgo
    });

    // Stub out checkInstance to avoid network race and stub terminate to clear state
    const checkStub = sinon.stub(warmPool, 'checkInstance').resolves();
    const terminateStub = sinon.stub(warmPool, 'terminate').callsFake(async (id) => {
      // emulate actual terminate clearing
      warmPool._internal.state.instance = null;
      warmPool._internal.state.lastAction = new Date().toISOString();
      return { status: 'terminated' };
    });

    // Now start polling which will call the stubbed functions
    warmPool.startPolling({ intervalMs: 30000 });

    // Tick one interval (30s) - this triggers the poll callback and subsequent termination
    await clock.tickAsync(30000);

    // Verify terminate was called and instance cleared
    assert.ok(terminateStub.called, 'terminate stub should be called');
    assert.strictEqual(warmPool._internal.state.instance, null, 'instance should be cleared after idle termination');

    checkStub.restore();
    terminateStub.restore();
  });

  it('clears lease when leasedUntil has passed without terminating', async function() {
    warmPool.stopPolling();
    const twoMinsAgo = new Date(Date.now() - 2 * 60 * 1000).toISOString();
    Object.assign(warmPool._internal.state, {
      instance: { 
        contractId: '888', 
        status: 'running', 
        createdAt: new Date().toISOString(),
        lastHeartbeat: new Date().toISOString(),
        leasedUntil: twoMinsAgo
      },
      lastAction: new Date().toISOString()
    });

    // Stub checkInstance to avoid network race
    const checkStub = sinon.stub(warmPool, 'checkInstance').resolves();

    warmPool.startPolling({ intervalMs: 30000 });
    await clock.tickAsync(30000);

    // After tick, lease should be cleared but instance should still exist
    assert.strictEqual(warmPool._internal.state.instance.leasedUntil, null);
    assert.ok(warmPool._internal.state.instance);

    checkStub.restore();
  });
});
