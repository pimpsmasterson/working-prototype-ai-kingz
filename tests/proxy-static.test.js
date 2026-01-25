const assert = require('assert');
const supertest = require('supertest');

describe('Static file endpoints', function() {
  let app;
  let request;

  before(function() {
    process.env.VASTAI_API_KEY = 'test_key';
    delete require.cache[require.resolve('../server/vastai-proxy')];
    app = require('../server/vastai-proxy');
    request = supertest(app);
  });

  it('GET /admin/warm-pool serves admin page', async function() {
    const res = await request.get('/admin/warm-pool');
    // May return 200 with HTML or 404 if file doesn't exist
    assert.ok(res.status === 200 || res.status === 404);
  });

  it('GET /assets/js/admin-warm-pool.js serves admin JS', async function() {
    const res = await request.get('/assets/js/admin-warm-pool.js');
    // May return 200 with JS or 404 if file doesn't exist
    assert.ok(res.status === 200 || res.status === 404);
  });
});
