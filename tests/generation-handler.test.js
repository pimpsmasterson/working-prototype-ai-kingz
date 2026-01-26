const assert = require('assert');
const supertest = require('supertest');
const nock = require('nock');
const sinon = require('sinon');
const fs = require('fs');
const path = require('path');
const { resetDb } = require('./helpers/test-helper');
const db = require('../server/db');

describe('Generation Handler Tests', function() {
  let app;
  let request;
  let fetchStub;
  let fsStubs = {};

  before(function() {
    process.env.ADMIN_API_KEY = 'test_admin_key';
    process.env.VASTAI_API_KEY = 'dummy_vast_key';
    process.env.AUDIT_SALT = 'test_salt';

    // Clear cache to ensure fresh load
    delete require.cache[require.resolve('../server/warm-pool')];
    delete require.cache[require.resolve('../server/vastai-proxy')];
    delete require.cache[require.resolve('../server/generation-handler')];

    app = require('../server/vastai-proxy');
    request = supertest(app);
  });

  beforeEach(function() {
    resetDb();
    nock.cleanAll();

    // Stub file system operations
    fsStubs.existsSync = sinon.stub(fs, 'existsSync').returns(true);
    fsStubs.mkdirSync = sinon.stub(fs, 'mkdirSync');
    fsStubs.writeFileSync = sinon.stub(fs, 'writeFileSync');
    fsStubs.statSync = sinon.stub(fs, 'statSync').returns({ size: 1024000 });
  });

  afterEach(function() {
    // Restore all stubs
    Object.values(fsStubs).forEach(stub => {
      if (stub && stub.restore) stub.restore();
    });
    fsStubs = {};
  });

  describe('POST /api/proxy/generate - Job Creation', function() {
    it('creates job with valid prompt for image generation', async function() {
      const res = await request.post('/api/proxy/generate')
        .send({
          prompt: 'beautiful warrior princess',
          workflowType: 'image',
          settings: { width: 512, height: 768 }
        });

      assert.strictEqual(res.status, 200);
      assert.ok(res.body.jobId);
      assert.ok(res.body.jobId.startsWith('job_'));
      assert.strictEqual(res.body.status, 'pending');
      assert.ok(res.body.message.includes('Poll'));
      assert.ok(res.body.estimatedTime);
    });

    it('creates job with video workflow type', async function() {
      const res = await request.post('/api/proxy/generate')
        .send({
          prompt: 'dancing robot',
          workflowType: 'video',
          settings: { frames: 16, fps: 8 }
        });

      assert.strictEqual(res.status, 200);
      assert.ok(res.body.jobId);
      assert.strictEqual(res.body.status, 'pending');
      assert.ok(res.body.estimatedTime.includes('60-120'));
    });

    it('rejects request with empty prompt', async function() {
      const res = await request.post('/api/proxy/generate')
        .send({
          prompt: '',
          workflowType: 'image'
        });

      assert.strictEqual(res.status, 400);
      assert.ok(res.body.error);
      assert.ok(res.body.error.includes('required'));
    });

    it('rejects request with whitespace-only prompt', async function() {
      const res = await request.post('/api/proxy/generate')
        .send({
          prompt: '   ',
          workflowType: 'image'
        });

      assert.strictEqual(res.status, 400);
      assert.ok(res.body.error);
    });

    it('stores muse data when provided', async function() {
      const res = await request.post('/api/proxy/generate')
        .send({
          muse: { id: 'muse123', name: 'Aria' },
          prompt: 'portrait',
          workflowType: 'image'
        });

      assert.strictEqual(res.status, 200);

      // Verify muse data was stored
      const job = db.getJob(res.body.jobId);
      assert.strictEqual(job.muse_id, 'muse123');
      assert.strictEqual(job.muse_name, 'Aria');
    });

    it('applies default settings when not provided', async function() {
      const res = await request.post('/api/proxy/generate')
        .send({
          prompt: 'test prompt',
          workflowType: 'image'
        });

      assert.strictEqual(res.status, 200);

      const job = db.getJob(res.body.jobId);
      assert.strictEqual(job.width, 512);
      assert.strictEqual(job.height, 768);
      assert.strictEqual(job.steps, 25);
      assert.strictEqual(job.cfg_scale, 7);
      assert.strictEqual(job.sampler, 'euler_ancestral');
      assert.strictEqual(job.checkpoint, 'dreamshaper_8.safetensors');
    });

    it('applies custom settings when provided', async function() {
      const res = await request.post('/api/proxy/generate')
        .send({
          prompt: 'custom test',
          workflowType: 'image',
          settings: {
            width: 1024,
            height: 1024,
            steps: 30,
            cfgScale: 9,
            sampler: 'dpm_2',
            checkpoint: 'custom.safetensors',
            seed: 42
          }
        });

      assert.strictEqual(res.status, 200);

      const job = db.getJob(res.body.jobId);
      assert.strictEqual(job.width, 1024);
      assert.strictEqual(job.height, 1024);
      assert.strictEqual(job.steps, 30);
      assert.strictEqual(job.cfg_scale, 9);
      assert.strictEqual(job.sampler, 'dpm_2');
      assert.strictEqual(job.checkpoint, 'custom.safetensors');
      assert.strictEqual(job.seed, 42);
    });

    it('applies negative prompt default when not provided', async function() {
      const res = await request.post('/api/proxy/generate')
        .send({
          prompt: 'test',
          workflowType: 'image'
        });

      const job = db.getJob(res.body.jobId);
      assert.strictEqual(job.negative_prompt, 'ugly, deformed, bad anatomy');
    });

    it('uses custom negative prompt when provided', async function() {
      const res = await request.post('/api/proxy/generate')
        .send({
          prompt: 'test',
          negativePrompt: 'custom negative',
          workflowType: 'image'
        });

      const job = db.getJob(res.body.jobId);
      assert.strictEqual(job.negative_prompt, 'custom negative');
    });
  });

  describe('GET /api/proxy/generate/:jobId - Status Checking', function() {
    it('returns 404 for non-existent job', async function() {
      const res = await request.get('/api/proxy/generate/job_nonexistent');
      assert.strictEqual(res.status, 404);
      assert.ok(res.body.error);
    });

    it('returns pending status for new job', async function() {
      // Create a job
      const createRes = await request.post('/api/proxy/generate')
        .send({ prompt: 'test', workflowType: 'image' });

      const jobId = createRes.body.jobId;

      // Check status
      const res = await request.get(`/api/proxy/generate/${jobId}`);
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.status, 'pending');
      assert.strictEqual(res.body.jobId, jobId);
      assert.strictEqual(res.body.workflowType, 'image');
      assert.ok(res.body.progress >= 0);
      assert.ok(res.body.createdAt);
    });

    it('returns processing status with progress', async function() {
      // Create job and update to processing
      const createRes = await request.post('/api/proxy/generate')
        .send({ prompt: 'test', workflowType: 'image' });

      const jobId = createRes.body.jobId;
      db.updateJobStatus(jobId, 'processing', {
        started_at: new Date().toISOString(),
        comfyui_prompt_id: 'prompt_123'
      });

      const res = await request.get(`/api/proxy/generate/${jobId}`);
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.status, 'processing');
      assert.strictEqual(res.body.progress, 50); // Should be 50 when comfyui_prompt_id exists
    });

    it('returns completed status with result URLs', async function() {
      // Create job and update to completed
      const createRes = await request.post('/api/proxy/generate')
        .send({ prompt: 'test', workflowType: 'image' });

      const jobId = createRes.body.jobId;
      const job = db.getJob(jobId);

      db.updateJobStatus(jobId, 'completed', {
        result_path: '/path/to/image.png',
        result_url: `/api/gallery/content/${job.id}`,
        thumbnail_path: '/path/to/thumb.png',
        completed_at: new Date().toISOString(),
        generation_time_seconds: 25.5,
        file_size_bytes: 1024000
      });

      const res = await request.get(`/api/proxy/generate/${jobId}`);
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.status, 'completed');
      assert.strictEqual(res.body.progress, 100);
      assert.ok(res.body.result);
      assert.ok(res.body.result.url);
      assert.ok(res.body.result.thumbnailUrl);
      assert.ok(res.body.result.metadata);
      assert.strictEqual(res.body.result.metadata.generationTime, 25.5);
    });

    it('returns failed status with error message', async function() {
      const createRes = await request.post('/api/proxy/generate')
        .send({ prompt: 'test', workflowType: 'image' });

      const jobId = createRes.body.jobId;
      db.updateJobStatus(jobId, 'failed', {
        error_message: 'GPU timeout',
        completed_at: new Date().toISOString()
      });

      const res = await request.get(`/api/proxy/generate/${jobId}`);
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.status, 'failed');
      assert.strictEqual(res.body.error, 'GPU timeout');
      assert.strictEqual(res.body.progress, 0);
    });
  });

  describe('Progress Calculation', function() {
    it('calculates 10% progress for pending jobs', async function() {
      const createRes = await request.post('/api/proxy/generate')
        .send({ prompt: 'test', workflowType: 'image' });

      const res = await request.get(`/api/proxy/generate/${createRes.body.jobId}`);
      assert.strictEqual(res.body.progress, 10);
    });

    it('calculates 25% progress for processing without prompt_id', async function() {
      const createRes = await request.post('/api/proxy/generate')
        .send({ prompt: 'test', workflowType: 'image' });

      db.updateJobStatus(createRes.body.jobId, 'processing', {
        started_at: new Date().toISOString()
      });

      const res = await request.get(`/api/proxy/generate/${createRes.body.jobId}`);
      assert.strictEqual(res.body.progress, 25);
    });

    it('calculates 50% progress for processing with prompt_id', async function() {
      const createRes = await request.post('/api/proxy/generate')
        .send({ prompt: 'test', workflowType: 'image' });

      db.updateJobStatus(createRes.body.jobId, 'processing', {
        started_at: new Date().toISOString(),
        comfyui_prompt_id: 'prompt_123'
      });

      const res = await request.get(`/api/proxy/generate/${createRes.body.jobId}`);
      assert.strictEqual(res.body.progress, 50);
    });

    it('calculates 100% progress for completed jobs', async function() {
      const createRes = await request.post('/api/proxy/generate')
        .send({ prompt: 'test', workflowType: 'image' });

      const job = db.getJob(createRes.body.jobId);
      db.updateJobStatus(createRes.body.jobId, 'completed', {
        result_path: '/path/to/image.png',
        result_url: `/api/gallery/content/${job.id}`,
        completed_at: new Date().toISOString()
      });

      const res = await request.get(`/api/proxy/generate/${createRes.body.jobId}`);
      assert.strictEqual(res.body.progress, 100);
    });

    it('calculates 0% progress for failed jobs', async function() {
      const createRes = await request.post('/api/proxy/generate')
        .send({ prompt: 'test', workflowType: 'image' });

      db.updateJobStatus(createRes.body.jobId, 'failed', {
        error_message: 'Test error',
        completed_at: new Date().toISOString()
      });

      const res = await request.get(`/api/proxy/generate/${createRes.body.jobId}`);
      assert.strictEqual(res.body.progress, 0);
    });
  });

  describe('Job ID Generation', function() {
    it('generates unique job IDs for concurrent requests', async function() {
      const promises = Array(10).fill(null).map(() =>
        request.post('/api/proxy/generate')
          .send({ prompt: 'test', workflowType: 'image' })
      );

      const results = await Promise.all(promises);
      const jobIds = results.map(r => r.body.jobId);
      const uniqueIds = new Set(jobIds);

      assert.strictEqual(uniqueIds.size, 10, 'All job IDs should be unique');
      jobIds.forEach(id => {
        assert.ok(id.startsWith('job_'), 'Job ID should have correct prefix');
      });
    });
  });

  describe('Database Integration', function() {
    it('stores all job fields correctly', async function() {
      const res = await request.post('/api/proxy/generate')
        .send({
          muse: { id: 'muse_123', name: 'TestMuse' },
          prompt: 'detailed test prompt',
          negativePrompt: 'bad quality',
          workflowType: 'video',
          settings: {
            width: 640,
            height: 480,
            steps: 20,
            cfgScale: 8,
            seed: 12345,
            sampler: 'euler',
            checkpoint: 'test.safetensors',
            frames: 24,
            fps: 12
          }
        });

      const job = db.getJob(res.body.jobId);

      assert.strictEqual(job.job_id, res.body.jobId);
      assert.strictEqual(job.muse_id, 'muse_123');
      assert.strictEqual(job.muse_name, 'TestMuse');
      assert.strictEqual(job.prompt, 'detailed test prompt');
      assert.strictEqual(job.negative_prompt, 'bad quality');
      assert.strictEqual(job.workflow_type, 'video');
      assert.strictEqual(job.width, 640);
      assert.strictEqual(job.height, 480);
      assert.strictEqual(job.steps, 20);
      assert.strictEqual(job.cfg_scale, 8);
      assert.strictEqual(job.seed, 12345);
      assert.strictEqual(job.sampler, 'euler');
      assert.strictEqual(job.checkpoint, 'test.safetensors');
      assert.strictEqual(job.frame_count, 24);
      assert.strictEqual(job.fps, 12);
      assert.strictEqual(job.status, 'pending');
      assert.ok(job.created_at);
    });

    it('retrieves job by ID correctly', async function() {
      const createRes = await request.post('/api/proxy/generate')
        .send({ prompt: 'test', workflowType: 'image' });

      const job = db.getJob(createRes.body.jobId);
      assert.ok(job);
      assert.strictEqual(job.job_id, createRes.body.jobId);
    });

    it('updates job status correctly', async function() {
      const createRes = await request.post('/api/proxy/generate')
        .send({ prompt: 'test', workflowType: 'image' });

      const jobId = createRes.body.jobId;

      db.updateJobStatus(jobId, 'processing', {
        started_at: new Date().toISOString(),
        gpu_instance_id: 'gpu_123',
        gpu_type: 'vastai'
      });

      const job = db.getJob(jobId);
      assert.strictEqual(job.status, 'processing');
      assert.ok(job.started_at);
      assert.strictEqual(job.gpu_instance_id, 'gpu_123');
      assert.strictEqual(job.gpu_type, 'vastai');
    });
  });

  describe('Workflow Type Validation', function() {
    it('defaults to image workflow when not specified', async function() {
      const res = await request.post('/api/proxy/generate')
        .send({ prompt: 'test' });

      const job = db.getJob(res.body.jobId);
      assert.strictEqual(job.workflow_type, 'image');
      assert.strictEqual(job.frame_count, null);
      assert.strictEqual(job.fps, null);
    });

    it('sets video-specific fields for video workflow', async function() {
      const res = await request.post('/api/proxy/generate')
        .send({
          prompt: 'test',
          workflowType: 'video',
          settings: { frames: 32, fps: 16 }
        });

      const job = db.getJob(res.body.jobId);
      assert.strictEqual(job.workflow_type, 'video');
      assert.strictEqual(job.frame_count, 32);
      assert.strictEqual(job.fps, 16);
    });

    it('applies default video settings when not provided', async function() {
      const res = await request.post('/api/proxy/generate')
        .send({
          prompt: 'test',
          workflowType: 'video'
        });

      const job = db.getJob(res.body.jobId);
      assert.strictEqual(job.workflow_type, 'video');
      assert.strictEqual(job.frame_count, 16); // default
      assert.strictEqual(job.fps, 8); // default
    });
  });

  describe('Error Handling', function() {
    it('returns error when database operation fails', async function() {
      // Stub createJob to throw error
      const createJobStub = sinon.stub(db, 'createJob').throws(new Error('Database error'));

      try {
        const res = await request.post('/api/proxy/generate')
          .send({ prompt: 'test', workflowType: 'image' });

        assert.strictEqual(res.status, 500);
        assert.ok(res.body.error);
        assert.ok(res.body.error.includes('Database error'));
      } finally {
        createJobStub.restore();
      }
    });

    it('handles missing request body gracefully', async function() {
      const res = await request.post('/api/proxy/generate')
        .send({});

      assert.strictEqual(res.status, 400);
      assert.ok(res.body.error);
    });
  });

  describe('Async Generation Flow', function() {
    it('does not block on generation start', async function() {
      const startTime = Date.now();

      const res = await request.post('/api/proxy/generate')
        .send({ prompt: 'test', workflowType: 'image' });

      const elapsed = Date.now() - startTime;

      assert.strictEqual(res.status, 200);
      assert.ok(elapsed < 1000, 'Should respond immediately without waiting for generation');
    });

    it('allows multiple concurrent job submissions', async function() {
      const promises = Array(5).fill(null).map((_, i) =>
        request.post('/api/proxy/generate')
          .send({ prompt: `test ${i}`, workflowType: 'image' })
      );

      const results = await Promise.all(promises);

      results.forEach(res => {
        assert.strictEqual(res.status, 200);
        assert.ok(res.body.jobId);
      });
    });
  });

  describe('GET /api/proxy/generate/:jobId - Job Status', function() {
    it('returns 404 for non-existent job', async function() {
      const res = await request.get('/api/proxy/generate/nonexistent');

      assert.strictEqual(res.status, 404);
      assert.deepStrictEqual(res.body, { error: 'Job not found' });
    });

    it('returns job status for existing job', async function() {
      // Create a job first
      const createRes = await request.post('/api/proxy/generate')
        .send({ prompt: 'test prompt', workflowType: 'image' });

      assert.strictEqual(createRes.status, 200);
      const jobId = createRes.body.jobId;

      // Now get status
      const statusRes = await request.get(`/api/proxy/generate/${jobId}`);

      assert.strictEqual(statusRes.status, 200);
      assert.strictEqual(statusRes.body.jobId, jobId);
      assert.strictEqual(statusRes.body.status, 'pending');
      assert.strictEqual(statusRes.body.workflowType, 'image');
      assert.ok(statusRes.body.progress !== undefined);
    });

    it('returns completed job with generation time', async function() {
      // Create a job
      const createRes = await request.post('/api/proxy/generate')
        .send({ prompt: 'test prompt', workflowType: 'image' });

      assert.strictEqual(createRes.status, 200);
      const jobId = createRes.body.jobId;

      // Manually update job to completed with timestamps
      db.updateJobStatus(jobId, 'completed', {
        started_at: new Date(Date.now() - 10000).toISOString(),
        completed_at: new Date().toISOString(),
        generation_time_seconds: 10
      });

      // Check db
      const job = db.getJob(jobId);
      assert.strictEqual(job.generation_time_seconds, 10);
      assert.strictEqual(job.status, 'completed');

      // Get status
      const statusRes = await request.get(`/api/proxy/generate/${jobId}`);

      assert.strictEqual(statusRes.status, 200);
      assert.strictEqual(statusRes.body.status, 'completed');
      assert.ok(statusRes.body.result);
      assert.strictEqual(statusRes.body.result.metadata.generationTime, 10);
    });
  });
});
