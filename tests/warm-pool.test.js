const nock = require('nock');
const assert = require('assert');
const path = require('path');
// simple smoke test skeleton - more assertions and coverage to be added
describe('WarmPool (mocked Vast.ai)', function() {
  before(() => {
    process.env.VASTAI_API_KEY = 'dummy';
  });

  it('should find offers and prewarm (mocked)', async function() {
    // Mock bundles
    nock('https://console.vast.ai')
      .post('/api/v0/bundles/')
      .reply(200, { offers: [{ id: 1, dph_total: 0.5, gpu_ram: 16384 }] });

    // TODO: Mock asks PUT /asks/:id and instances endpoints
    assert.ok(true);
  });
});
