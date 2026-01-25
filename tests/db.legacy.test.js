const assert = require('assert');
const db = require('../server/db');

describe('DB compatibility and updates', function() {
  it('aliases model_checkpoint to checkpoint on getJob and getAllJobs', function() {
    const jobId = 'test_job_' + Date.now();
    // Insert directly using SQL to simulate older schema where model_checkpoint is present
    db.db.prepare(`INSERT INTO generated_content (job_id, prompt, model_checkpoint, status) VALUES (?, ?, ?, ?)`)
      .run(jobId, 'test prompt', 'legacy_model.ckpt', 'pending');

    const job = db.getJob(jobId);
    assert.strictEqual(job.checkpoint, 'legacy_model.ckpt');

    const all = db.getAllJobs({});
    const found = all.find(j => j.job_id === jobId);
    assert.ok(found);
    assert.strictEqual(found.checkpoint, 'legacy_model.ckpt');

    // Cleanup
    db.deleteJob(jobId);
  });

  it('updateJobStatus updates with and without extra fields', function() {
    const jobId = 'test_job_' + Date.now();
    db.createJob({ jobId, prompt: 'p', workflowType: 'image' });

    // Update only status
    db.updateJobStatus(jobId, 'processing');
    let job = db.getJob(jobId);
    assert.strictEqual(job.status, 'processing');

    // Update with extra fields
    db.updateJobStatus(jobId, 'completed', { result_path: '/tmp/x.png', file_size_bytes: 1234 });
    job = db.getJob(jobId);
    assert.strictEqual(job.status, 'completed');
    assert.strictEqual(job.result_path, '/tmp/x.png');
    assert.strictEqual(job.file_size_bytes, 1234);

    // Cleanup
    db.deleteJob(jobId);
  });
});