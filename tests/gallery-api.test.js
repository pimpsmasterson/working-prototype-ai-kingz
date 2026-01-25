const assert = require('assert');
const supertest = require('supertest');
const sinon = require('sinon');
const fs = require('fs');
const path = require('path');
const { resetDb } = require('./helpers/test-helper');
const db = require('../server/db');

describe('Gallery API Tests', function() {
  let app;
  let request;
  let fsStubs = {};

  before(function() {
    process.env.ADMIN_API_KEY = 'test_admin_key';
    process.env.VASTAI_API_KEY = 'dummy_vast_key';
    process.env.AUDIT_SALT = 'test_salt';

    // Clear cache to ensure fresh load
    delete require.cache[require.resolve('../server/warm-pool')];
    delete require.cache[require.resolve('../server/vastai-proxy')];

    app = require('../server/vastai-proxy');
    request = supertest(app);
  });

  beforeEach(function() {
    resetDb();

    // Stub file system operations
    fsStubs.existsSync = sinon.stub(fs, 'existsSync');
    fsStubs.createReadStream = sinon.stub(fs, 'createReadStream');
    fsStubs.unlinkSync = sinon.stub(fs, 'unlinkSync');
  });

  afterEach(function() {
    // Restore all stubs
    Object.values(fsStubs).forEach(stub => {
      if (stub && stub.restore) stub.restore();
    });
    fsStubs = {};
  });

  describe('GET /api/gallery/content/:id - Content Retrieval', function() {
    it('returns 404 for non-existent content', async function() {
      const res = await request.get('/api/gallery/content/999999');
      assert.strictEqual(res.status, 404);
      assert.ok(res.body.error);
      assert.ok(res.body.error.includes('Content not found'));
    });

    it('returns 404 when file does not exist on disk', async function() {
      // Create a job entry without actual file
      const jobData = {
        jobId: 'job_test_123',
        museId: null,
        museName: null,
        prompt: 'test',
        workflowType: 'image',
        seed: 12345,
        steps: 25,
        cfgScale: 7,
        width: 512,
        height: 768,
        sampler: 'euler_ancestral',
        checkpoint: 'test.safetensors'
      };
      db.createJob(jobData);
      const job = db.getJob('job_test_123');

      db.updateJobStatus('job_test_123', 'completed', {
        result_path: '/path/to/nonexistent.png',
        result_url: `/api/gallery/content/${job.id}`,
        completed_at: new Date().toISOString()
      });

      fsStubs.existsSync.returns(false);

      const res = await request.get(`/api/gallery/content/${job.id}`);
      assert.strictEqual(res.status, 404);
      assert.ok(res.body.error);
      assert.ok(res.body.error.includes('File not found'));
    });

    it('serves image content with correct content-type', async function() {
      const jobData = {
        jobId: 'job_image_test',
        museId: null,
        museName: null,
        prompt: 'test image',
        workflowType: 'image',
        seed: 12345,
        steps: 25,
        cfgScale: 7,
        width: 512,
        height: 768,
        sampler: 'euler_ancestral',
        checkpoint: 'test.safetensors'
      };
      db.createJob(jobData);
      const job = db.getJob('job_image_test');

      db.updateJobStatus('job_image_test', 'completed', {
        result_path: '/path/to/image.png',
        result_url: `/api/gallery/content/${job.id}`,
        completed_at: new Date().toISOString()
      });

      fsStubs.existsSync.returns(true);

      // Create a mock readable stream
      const mockStream = {
        pipe: sinon.stub().returnsThis(),
        on: sinon.stub().returnsThis()
      };
      fsStubs.createReadStream.returns(mockStream);

      const res = await request.get(`/api/gallery/content/${job.id}`);
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.headers['content-type'], 'image/png');
    });

    it('serves video content with correct content-type', async function() {
      const jobData = {
        jobId: 'job_video_test',
        museId: null,
        museName: null,
        prompt: 'test video',
        workflowType: 'video',
        seed: 12345,
        steps: 25,
        cfgScale: 7,
        width: 512,
        height: 768,
        sampler: 'euler',
        checkpoint: 'test.safetensors',
        frameCount: 16,
        fps: 8
      };
      db.createJob(jobData);
      const job = db.getJob('job_video_test');

      db.updateJobStatus('job_video_test', 'completed', {
        result_path: '/path/to/video.mp4',
        result_url: `/api/gallery/content/${job.id}`,
        completed_at: new Date().toISOString()
      });

      fsStubs.existsSync.returns(true);

      const mockStream = {
        pipe: sinon.stub().returnsThis(),
        on: sinon.stub().returnsThis()
      };
      fsStubs.createReadStream.returns(mockStream);

      const res = await request.get(`/api/gallery/content/${job.id}`);
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.headers['content-type'], 'video/mp4');
    });

    it('finds content by job_id when id not found', async function() {
      const jobData = {
        jobId: 'job_find_test',
        museId: null,
        museName: null,
        prompt: 'test',
        workflowType: 'image',
        seed: 12345,
        steps: 25,
        cfgScale: 7,
        width: 512,
        height: 768,
        sampler: 'euler_ancestral',
        checkpoint: 'test.safetensors'
      };
      db.createJob(jobData);

      db.updateJobStatus('job_find_test', 'completed', {
        result_path: '/path/to/image.png',
        result_url: '/api/gallery/content/job_find_test',
        completed_at: new Date().toISOString()
      });

      fsStubs.existsSync.returns(true);

      const mockStream = {
        pipe: sinon.stub().returnsThis(),
        on: sinon.stub().returnsThis()
      };
      fsStubs.createReadStream.returns(mockStream);

      // Request by job_id instead of database id
      const res = await request.get('/api/gallery/content/job_find_test');
      assert.strictEqual(res.status, 200);
    });
  });

  describe('GET /api/gallery/thumbnail/:id - Thumbnail Retrieval', function() {
    it('returns 404 for non-existent thumbnail', async function() {
      const res = await request.get('/api/gallery/thumbnail/999999');
      assert.strictEqual(res.status, 404);
      assert.ok(res.body.error);
    });

    it('serves thumbnail for image', async function() {
      const jobData = {
        jobId: 'job_thumb_test',
        museId: null,
        museName: null,
        prompt: 'test',
        workflowType: 'image',
        seed: 12345,
        steps: 25,
        cfgScale: 7,
        width: 512,
        height: 768,
        sampler: 'euler_ancestral',
        checkpoint: 'test.safetensors'
      };
      db.createJob(jobData);
      const job = db.getJob('job_thumb_test');

      db.updateJobStatus('job_thumb_test', 'completed', {
        result_path: '/path/to/image.png',
        result_url: `/api/gallery/content/${job.id}`,
        completed_at: new Date().toISOString()
      });

      fsStubs.existsSync.returns(true);

      const mockStream = {
        pipe: sinon.stub().returnsThis(),
        on: sinon.stub().returnsThis()
      };
      fsStubs.createReadStream.returns(mockStream);

      const res = await request.get(`/api/gallery/thumbnail/${job.id}`);
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.headers['content-type'], 'image/png');
    });
  });

  describe('GET /api/gallery - Gallery Listing', function() {
    beforeEach(function() {
      // Create multiple test jobs
      const jobs = [
        {
          jobId: 'job_1',
          museId: 'muse_a',
          museName: 'Character A',
          prompt: 'portrait 1',
          workflowType: 'image',
          seed: 1,
          steps: 25,
          cfgScale: 7,
          width: 512,
          height: 768,
          sampler: 'euler_ancestral',
          checkpoint: 'test.safetensors'
        },
        {
          jobId: 'job_2',
          museId: 'muse_a',
          museName: 'Character A',
          prompt: 'portrait 2',
          workflowType: 'image',
          seed: 2,
          steps: 25,
          cfgScale: 7,
          width: 512,
          height: 768,
          sampler: 'euler_ancestral',
          checkpoint: 'test.safetensors'
        },
        {
          jobId: 'job_3',
          museId: 'muse_b',
          museName: 'Character B',
          prompt: 'video 1',
          workflowType: 'video',
          seed: 3,
          steps: 25,
          cfgScale: 7,
          width: 512,
          height: 768,
          sampler: 'euler',
          checkpoint: 'test.safetensors',
          frameCount: 16,
          fps: 8
        }
      ];

      jobs.forEach(jobData => {
        db.createJob(jobData);
        const job = db.getJob(jobData.jobId);
        db.updateJobStatus(jobData.jobId, 'completed', {
          result_path: `/path/to/${jobData.jobId}.png`,
          result_url: `/api/gallery/content/${job.id}`,
          completed_at: new Date().toISOString(),
          generation_time_seconds: 25
        });
      });

      // Add one pending job
      db.createJob({
        jobId: 'job_pending',
        museId: 'muse_a',
        museName: 'Character A',
        prompt: 'pending',
        workflowType: 'image',
        seed: 4,
        steps: 25,
        cfgScale: 7,
        width: 512,
        height: 768,
        sampler: 'euler_ancestral',
        checkpoint: 'test.safetensors'
      });
    });

    it('lists all completed items by default', async function() {
      const res = await request.get('/api/gallery');
      assert.strictEqual(res.status, 200);
      assert.ok(Array.isArray(res.body.items));
      assert.strictEqual(res.body.items.length, 3); // Only completed jobs
      assert.strictEqual(res.body.total, 3);
      assert.strictEqual(res.body.limit, 50);
      assert.strictEqual(res.body.offset, 0);

      res.body.items.forEach(item => {
        assert.ok(item.id);
        assert.ok(item.jobId);
        assert.ok(item.prompt);
        assert.strictEqual(item.status, 'completed');
        assert.ok(item.thumbnailUrl);
        assert.ok(item.contentUrl);
        assert.ok(item.createdAt);
      });
    });

    it('filters by muse ID', async function() {
      const res = await request.get('/api/gallery?museId=muse_a');
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.items.length, 2); // Only muse_a jobs
      assert.strictEqual(res.body.total, 2);

      res.body.items.forEach(item => {
        assert.strictEqual(item.museName, 'Character A');
      });
    });

    it('filters by status', async function() {
      const res = await request.get('/api/gallery?status=pending');
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.items.length, 1);
      assert.strictEqual(res.body.items[0].status, 'pending');
      assert.strictEqual(res.body.items[0].contentUrl, null); // No content URL for pending
    });

    it('lists all statuses when status=all', async function() {
      const res = await request.get('/api/gallery?status=all');
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.items.length, 4); // All jobs (3 completed + 1 pending)
      assert.strictEqual(res.body.total, 4);
    });

    it('applies pagination with limit', async function() {
      const res = await request.get('/api/gallery?limit=2');
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.items.length, 2);
      assert.strictEqual(res.body.limit, 2);
      assert.strictEqual(res.body.total, 3);
    });

    it('applies pagination with offset', async function() {
      const res = await request.get('/api/gallery?limit=2&offset=2');
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.items.length, 1); // Only 1 item left after offset 2
      assert.strictEqual(res.body.offset, 2);
    });

    it('combines filters (museId + status)', async function() {
      const res = await request.get('/api/gallery?museId=muse_a&status=all');
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.items.length, 3); // 2 completed + 1 pending for muse_a
      assert.strictEqual(res.body.total, 3);

      res.body.items.forEach(item => {
        assert.strictEqual(item.museName, 'Character A');
      });
    });

    it('returns empty array when no matches found', async function() {
      const res = await request.get('/api/gallery?museId=nonexistent');
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.items.length, 0);
      assert.strictEqual(res.body.total, 0);
    });

    it('includes generation time for completed items', async function() {
      const res = await request.get('/api/gallery');
      assert.strictEqual(res.status, 200);

      const completedItem = res.body.items.find(item => item.status === 'completed');
      assert.ok(completedItem);
      assert.strictEqual(completedItem.generationTime, 25);
    });
  });

  describe('DELETE /api/gallery/:id - Content Deletion', function() {
    it('returns 404 for non-existent content', async function() {
      const res = await request.delete('/api/gallery/999999');
      assert.strictEqual(res.status, 404);
      assert.ok(res.body.error);
    });

    it('deletes content and file successfully', async function() {
      // Create a job
      const jobData = {
        jobId: 'job_delete_test',
        museId: null,
        museName: null,
        prompt: 'to be deleted',
        workflowType: 'image',
        seed: 12345,
        steps: 25,
        cfgScale: 7,
        width: 512,
        height: 768,
        sampler: 'euler_ancestral',
        checkpoint: 'test.safetensors'
      };
      db.createJob(jobData);
      const job = db.getJob('job_delete_test');

      db.updateJobStatus('job_delete_test', 'completed', {
        result_path: '/path/to/delete.png',
        result_url: `/api/gallery/content/${job.id}`,
        completed_at: new Date().toISOString()
      });

      fsStubs.existsSync.returns(true);
      fsStubs.unlinkSync.returns(undefined);

      const res = await request.delete(`/api/gallery/${job.id}`);
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.success, true);
      assert.ok(res.body.message.includes('deleted'));

      // Verify file deletion was attempted
      assert.ok(fsStubs.unlinkSync.calledOnce);
      assert.ok(fsStubs.unlinkSync.calledWith('/path/to/delete.png'));

      // Verify database deletion
      const deletedJob = db.getJob('job_delete_test');
      assert.strictEqual(deletedJob, null);
    });

    it('deletes database entry even if file deletion fails', async function() {
      const jobData = {
        jobId: 'job_delete_fail',
        museId: null,
        museName: null,
        prompt: 'delete with file error',
        workflowType: 'image',
        seed: 12345,
        steps: 25,
        cfgScale: 7,
        width: 512,
        height: 768,
        sampler: 'euler_ancestral',
        checkpoint: 'test.safetensors'
      };
      db.createJob(jobData);
      const job = db.getJob('job_delete_fail');

      db.updateJobStatus('job_delete_fail', 'completed', {
        result_path: '/path/to/error.png',
        result_url: `/api/gallery/content/${job.id}`,
        completed_at: new Date().toISOString()
      });

      fsStubs.existsSync.returns(true);
      fsStubs.unlinkSync.throws(new Error('Disk error'));

      const res = await request.delete(`/api/gallery/${job.id}`);
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.success, true);

      // Verify database deletion still occurred
      const deletedJob = db.getJob('job_delete_fail');
      assert.strictEqual(deletedJob, null);
    });

    it('deletes by job_id when id not found', async function() {
      const jobData = {
        jobId: 'job_delete_by_jobid',
        museId: null,
        museName: null,
        prompt: 'delete test',
        workflowType: 'image',
        seed: 12345,
        steps: 25,
        cfgScale: 7,
        width: 512,
        height: 768,
        sampler: 'euler_ancestral',
        checkpoint: 'test.safetensors'
      };
      db.createJob(jobData);

      db.updateJobStatus('job_delete_by_jobid', 'completed', {
        result_path: '/path/to/image.png',
        result_url: '/api/gallery/content/job_delete_by_jobid',
        completed_at: new Date().toISOString()
      });

      fsStubs.existsSync.returns(true);
      fsStubs.unlinkSync.returns(undefined);

      // Delete by job_id
      const res = await request.delete('/api/gallery/job_delete_by_jobid');
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.success, true);

      // Verify deletion
      const deletedJob = db.getJob('job_delete_by_jobid');
      assert.strictEqual(deletedJob, null);
    });

    it('handles deletion when file does not exist on disk', async function() {
      const jobData = {
        jobId: 'job_no_file',
        museId: null,
        museName: null,
        prompt: 'no file',
        workflowType: 'image',
        seed: 12345,
        steps: 25,
        cfgScale: 7,
        width: 512,
        height: 768,
        sampler: 'euler_ancestral',
        checkpoint: 'test.safetensors'
      };
      db.createJob(jobData);
      const job = db.getJob('job_no_file');

      db.updateJobStatus('job_no_file', 'completed', {
        result_path: '/path/to/nonexistent.png',
        result_url: `/api/gallery/content/${job.id}`,
        completed_at: new Date().toISOString()
      });

      fsStubs.existsSync.returns(false);

      const res = await request.delete(`/api/gallery/${job.id}`);
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.success, true);

      // Verify file deletion was not attempted
      assert.ok(fsStubs.unlinkSync.notCalled);

      // Verify database deletion occurred
      const deletedJob = db.getJob('job_no_file');
      assert.strictEqual(deletedJob, null);
    });
  });

  describe('Integration - Full Gallery Workflow', function() {
    it('creates job, completes it, lists it, and deletes it', async function() {
      // 1. Create job
      const createRes = await request.post('/api/proxy/generate')
        .send({
          muse: { id: 'muse_workflow', name: 'WorkflowMuse' },
          prompt: 'integration test',
          workflowType: 'image'
        });

      assert.strictEqual(createRes.status, 200);
      const jobId = createRes.body.jobId;

      // 2. Mark as completed
      const job = db.getJob(jobId);
      db.updateJobStatus(jobId, 'completed', {
        result_path: '/path/to/workflow.png',
        result_url: `/api/gallery/content/${job.id}`,
        completed_at: new Date().toISOString(),
        generation_time_seconds: 30
      });

      // 3. List gallery and verify it appears
      const listRes = await request.get('/api/gallery?museId=muse_workflow');
      assert.strictEqual(listRes.status, 200);
      assert.strictEqual(listRes.body.items.length, 1);
      assert.strictEqual(listRes.body.items[0].prompt, 'integration test');

      // 4. Delete it
      fsStubs.existsSync.returns(true);
      fsStubs.unlinkSync.returns(undefined);

      const deleteRes = await request.delete(`/api/gallery/${job.id}`);
      assert.strictEqual(deleteRes.status, 200);

      // 5. Verify it's gone from gallery
      const listAfterDelete = await request.get('/api/gallery?museId=muse_workflow');
      assert.strictEqual(listAfterDelete.status, 200);
      assert.strictEqual(listAfterDelete.body.items.length, 0);
    });
  });
});
