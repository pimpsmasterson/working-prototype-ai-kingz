const assert = require('assert');

describe('API key middleware (unit)', function() {
  this.timeout(10000); // Increase timeout for module reloading

  it('returns 500 when VASTAI_API_KEY is not set', function() {
    // Save original key
    const originalKey = process.env.VASTAI_API_KEY;
    try {
      delete process.env.VASTAI_API_KEY;
      delete process.env.VAST_AI_API_KEY;
      process.env.FORCE_MISSING_VAST_KEY = '1';

      // Require app fresh and get the middleware directly
      delete require.cache[require.resolve('../server/vastai-proxy')];
      const app = require('../server/vastai-proxy');
      const check = app.checkApiKeyOrDie;

      // Build minimal mocks
      const req = {};
      let sentStatus = null;
      let sentBody = null;
      const res = {
        status(code) { sentStatus = code; return this; },
        json(obj) { sentBody = obj; }
      };

      let nextCalled = false;
      const next = () => { nextCalled = true; };

      // Call middleware directly
      check(req, res, next);

      // Assertions: should not call next and should send 500
      assert.strictEqual(sentStatus, 500);
      assert.ok(sentBody && sentBody.error && sentBody.error.includes('VASTAI_API_KEY'));
      assert.strictEqual(nextCalled, false);
    } finally {
      // Restore
      if (typeof originalKey !== 'undefined') process.env.VASTAI_API_KEY = originalKey;
      else delete process.env.VASTAI_API_KEY;
      delete process.env.VAST_AI_API_KEY;
      delete process.env.FORCE_MISSING_VAST_KEY;
      delete require.cache[require.resolve('../server/vastai-proxy')];
      require('../server/vastai-proxy');
    }
  });
});
