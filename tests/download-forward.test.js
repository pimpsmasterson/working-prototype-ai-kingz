const assert = require('assert');
const supertest = require('supertest');
const nock = require('nock');

describe('Civitai download and forward endpoints', function() {
  let app;
  let request;

  before(function() {
    process.env.VASTAI_API_KEY = 'dummy';
    delete require.cache[require.resolve('../server/vastai-proxy')];
    app = require('../server/vastai-proxy');
    request = supertest(app);
  });

  beforeEach(function() {
    nock.cleanAll();
  });

  it('POST /api/proxy/download-civitai returns 400 without modelId', async function() {
    const res = await request.post('/api/proxy/download-civitai').send({});
    assert.strictEqual(res.status, 400);
    assert.ok(res.body.error.includes('modelId'));
  });

  it('POST /api/proxy/download-civitai proxies happy path and returns file buffer', async function() {
    // Mock civitai model info
    nock('https://civitai.com')
      .get('/api/v1/models/abc')
      .reply(200, { modelVersions: [{ files: [{ downloadUrl: 'http://files.example.com/file.dat' }] }] });

    // Mock the actual file download
    nock('http://files.example.com')
      .get('/file.dat')
      .reply(200, Buffer.from('binarydata'));

    const res = await request.post('/api/proxy/download-civitai').send({ modelId: 'abc' });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.headers['content-disposition'], 'attachment; filename="abc.safetensors"');
    assert.ok(res.body.length > 0);
  });

  it('POST /api/proxy/download-civitai returns 403 when download access denied', async function() {
    nock('https://civitai.com')
      .get('/api/v1/models/private')
      .reply(200, { modelVersions: [{ files: [{ downloadUrl: 'http://files.example.com/private.dat' }] }] });

    nock('http://files.example.com')
      .get('/private.dat')
      .reply(403);

    const res = await request.post('/api/proxy/download-civitai').send({ modelId: 'private' });
    assert.strictEqual(res.status, 403);
    assert.ok(res.body.error && res.body.error.includes('CIVITAI_TOKEN'));
  });

  it('POST /api/proxy/download-civitai handles missing download URL', async function() {
    nock('https://civitai.com')
      .get('/api/v1/models/nofile')
      .reply(200, { modelVersions: [] });

    const res = await request.post('/api/proxy/download-civitai').send({ modelId: 'nofile' });
    assert.strictEqual(res.status, 500);
    assert.ok(res.body.error && res.body.error.includes('No download URL'));
  });

  it('POST /api/proxy/download-civitai handles upstream API error', async function() {
    nock('https://civitai.com')
      .get('/api/v1/models/badapi')
      .reply(500, { error: 'server' });

    const res = await request.post('/api/proxy/download-civitai').send({ modelId: 'badapi' });
    assert.strictEqual(res.status, 500);
    assert.ok(res.body.error && res.body.error.includes('Civitai API'));
  });

  it('POST /api/proxy/download-civitai handles download failure statuses', async function() {
    nock('https://civitai.com')
      .get('/api/v1/models/dlfail')
      .reply(200, { modelVersions: [{ files: [{ downloadUrl: 'http://files.example.com/fail.dat' }] }] });

    nock('http://files.example.com')
      .get('/fail.dat')
      .reply(500);

    const res = await request.post('/api/proxy/download-civitai').send({ modelId: 'dlfail' });
    assert.strictEqual(res.status, 500);
    assert.ok(res.body.error && res.body.error.includes('Download failed'));
  });

  it('POST /api/proxy/forward returns 400 when targetUrl missing', async function() {
    const res = await request.post('/api/proxy/forward').send({});
    assert.strictEqual(res.status, 400);
  });

  it('POST /api/proxy/forward proxies JSON and returns JSON result', async function() {
    nock('http://example.com')
      .post('/echo')
      .reply(200, { ok: true });

    const res = await request.post('/api/proxy/forward').send({ targetUrl: 'http://example.com/echo', payload: { a: 1 } });
    assert.strictEqual(res.status, 200);
    assert.deepStrictEqual(res.body, { ok: true });
  });

  it('POST /api/proxy/forward proxies non-JSON and returns text', async function() {
    nock('http://example.com')
      .post('/text')
      .reply(200, 'plain text');

    const res = await request.post('/api/proxy/forward').send({ targetUrl: 'http://example.com/text' });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.text, 'plain text');
  });
});