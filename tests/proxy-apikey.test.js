const assert = require('assert');
const supertest = require('supertest');

describe('API key validation', function() {
  this.timeout(10000); // Increase timeout for module reloading

  it('checkApiKeyOrDie returns 500 when VASTAI_API_KEY is not set', function() {
    // Save original key
    const originalKey = process.env.VASTAI_API_KEY;

    try {
      // Unset the key temporarily
      delete process.env.VASTAI_API_KEY;
      delete process.env.VAST_AI_API_KEY;
      process.env.FORCE_MISSING_VAST_KEY = '1';

      // Re-require the app to pick up the missing key and get middleware
      delete require.cache[require.resolve('../server/vastai-proxy')];
      const app = require('../server/vastai-proxy');
      const check = app.checkApiKeyOrDie;

      // Minimal mocks
      const req = {};
      let sentStatus = null;
      let sentBody = null;
      const res = {
        status(code) { sentStatus = code; return this; },
        json(obj) { sentBody = obj; }
      };
      let nextCalled = false;
      const next = () => { nextCalled = true; };

      check(req, res, next);

      assert.strictEqual(sentStatus, 500);
      assert.ok(sentBody.error && sentBody.error.includes('VASTAI_API_KEY'));
      assert.strictEqual(nextCalled, false);
    } finally {
      // Restore key
      process.env.VASTAI_API_KEY = originalKey;
      delete process.env.VAST_AI_API_KEY;
      delete process.env.FORCE_MISSING_VAST_KEY;

      // Re-require to restore original state
      delete require.cache[require.resolve('../server/vastai-proxy')];
      require('../server/vastai-proxy');
    }
  });

  it('requireAdmin middleware allows valid admin key to proceed', async function() {
    process.env.ADMIN_API_KEY = 'test_admin';
    process.env.VASTAI_API_KEY = 'test_vast';

    delete require.cache[require.resolve('../server/vastai-proxy')];
    const app = require('../server/vastai-proxy');
    const request = supertest(app);

    // This endpoint uses requireAdmin middleware indirectly via its own check
    // Let's test an endpoint that definitely calls next() on success
    const warmPool = require('../server/warm-pool');
    warmPool._internal.state.instance = null;

    const res = await request.post('/api/proxy/admin/warm-pool')
      .set('x-admin-key', 'test_admin')
      .send({ desiredSize: 1 });

    // Should succeed and call next(), resulting in 200
    assert.strictEqual(res.status, 200);
  });
});
