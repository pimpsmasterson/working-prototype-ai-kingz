/**
 * AI KINGS Generation Handler
 * Core orchestration for image and video generation
 * Handles: job creation → GPU claiming → workflow building → ComfyUI submission → polling → file storage
 */

const { createJob, updateJobStatus, getJob } = require('./db');
const warmPool = require('./warm-pool');
const fetch = require('node-fetch');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// ============================================================================
// MAIN API ENDPOINTS
// ============================================================================

/**
 * POST /api/proxy/generate
 * Main generation orchestrator - creates job and starts async generation
 */
async function handleGenerate(req, res) {
  const jobId = generateJobId();
  const { muse, prompt, negativePrompt, settings, workflowType = 'image' } = req.body;

  // Validate input
  if (!prompt || prompt.trim().length === 0) {
    return res.status(400).json({ error: 'Prompt is required' });
  }

  try {
    // 1. Create job record in database
    const jobData = {
      jobId,
      museId: muse?.id || null,
      museName: muse?.name || null,
      prompt,
      negativePrompt: negativePrompt || 'ugly, deformed, bad anatomy',
      workflowType,
      workflowJson: null, // Will be set after building
      seed: settings?.seed || Math.floor(Math.random() * 1000000000),
      steps: settings?.steps || 25,
      cfgScale: settings?.cfgScale || 7,
      width: settings?.width || 512,
      height: settings?.height || 768,
      sampler: settings?.sampler || 'euler_ancestral',
      checkpoint: settings?.checkpoint || 'dreamshaper_8.safetensors',
      frameCount: workflowType === 'video' ? (settings?.frames || 16) : null,
      fps: workflowType === 'video' ? (settings?.fps || 8) : null
    };

    require('./db').createJob(jobData);
    console.log(`[Job ${jobId}] Created: ${workflowType} generation for prompt "${prompt.substring(0, 50)}..."`);

    // 2. Start async generation (don't block response)
    // In test environment we guard background generation to avoid external network calls
    if (process.env.NODE_ENV !== 'test' || process.env.ENABLE_ASYNC_GENERATION === '1') {
      generateAsync(jobId, jobData, muse).catch(err => {
        console.error(`[Job ${jobId}] Failed:`, err);
        updateJobStatus(jobId, 'failed', {
          error_message: err.message,
          completed_at: new Date().toISOString()
        });
      });
    } else {
      // In test mode background generation is disabled by default (enable with ENABLE_ASYNC_GENERATION=1)
      console.log(`[Job ${jobId}] Background generation deferred (test mode)`);
    }

    // 3. Return immediately with job ID
    res.json({
      jobId,
      status: 'pending',
      message: 'Generation started. Poll GET /api/proxy/generate/:jobId for status',
      estimatedTime: workflowType === 'video' ? '60-120 seconds' : '20-40 seconds'
    });

  } catch (error) {
    console.error('[Generation] Initialization error:', error);
    res.status(500).json({ error: error.message, jobId });
  }
}

/**
 * GET /api/proxy/generate/:jobId
 * Check job status and get results
 */
function getJobStatus(req, res) {
  const { jobId } = req.params;
  const job = getJob(jobId);

  if (!job) {
    return res.status(404).json({ error: 'Job not found' });
  }

  const response = {
    jobId: job.job_id,
    status: job.status,
    workflowType: job.workflow_type,
    progress: calculateProgress(job),
    createdAt: job.created_at,
    error: job.error_message
  };

  if (job.status === 'completed') {
    response.result = {
      url: `/api/gallery/content/${job.id}`,
      thumbnailUrl: `/api/gallery/thumbnail/${job.id}`,
      metadata: {
        width: job.width,
        height: job.height,
        seed: job.seed,
        steps: job.steps,
        generationTime: job.generation_time_seconds,
        workflowType: job.workflow_type,
        frameCoun: job.frame_count,
        fps: job.fps
      }
    };
  }

  res.json(response);
}

// ============================================================================
// ASYNC GENERATION FLOW
// ============================================================================

/**
 * Background generation process
 * Orchestrates the full pipeline: claim GPU → build workflow → submit → poll → save
 */
async function generateAsync(jobId, jobData, muse) {
  let instance = null;

  try {
    // 1. Claim GPU instance
    console.log(`[Job ${jobId}] Claiming GPU instance...`);
    instance = await claimGPUInstance(jobData.workflowType);

    require('./db').updateJobStatus(jobId, 'processing', {
      started_at: new Date().toISOString(),
      gpu_instance_id: instance.contractId || 'local',
      gpu_type: instance.type
    });

    console.log(`[Job ${jobId}] Using ${instance.type} GPU: ${instance.contractId || 'local'}`);

    // 2. Build workflow
    console.log(`[Job ${jobId}] Building ${jobData.workflowType} workflow...`);
    const workflow = buildWorkflowForJob(jobData, muse);

    require('./db').updateJobStatus(jobId, 'processing', {
      workflow_json: JSON.stringify(workflow)
    });

    // 3. Submit to ComfyUI
    console.log(`[Job ${jobId}] Submitting to ComfyUI...`);
    const submitResult = await submitToComfyUI(instance, workflow);

    require('./db').updateJobStatus(jobId, 'processing', {
      comfyui_prompt_id: submitResult.prompt_id
    });

    console.log(`[Job ${jobId}] ComfyUI prompt_id: ${submitResult.prompt_id}`);

    // 4. Poll for completion
    console.log(`[Job ${jobId}] Polling for completion...`);
    const result = await pollComfyUIUntilComplete(instance, submitResult.prompt_id, jobData.workflowType);

    // 5. Download and save
    console.log(`[Job ${jobId}] Downloading result...`);
    const savedPath = await downloadAndSave(instance, result, jobId, jobData.workflowType);

    // 6. Create thumbnail (if image)
    let thumbnailPath = null;
    if (jobData.workflowType === 'image') {
      thumbnailPath = savedPath; // For MVP, use same file
      // Future: Use sharp/jimp to create actual thumbnail
    }

    // 7. Calculate generation time
    const job = getJob(jobId);
    const generationTime = calculateGenerationTime(job);

    // 8. Mark complete
    require('./db').updateJobStatus(jobId, 'completed', {
      result_path: savedPath,
      result_url: `/api/gallery/content/${jobId}`,
      thumbnail_path: thumbnailPath,
      completed_at: new Date().toISOString(),
      generation_time_seconds: generationTime,
      file_size_bytes: fs.statSync(savedPath).size
    });

    console.log(`[Job ${jobId}] Completed successfully in ${generationTime}s (${fs.statSync(savedPath).size} bytes)`);

  } catch (error) {
    console.error(`[Job ${jobId}] Generation failed:`, error);

    require('./db').updateJobStatus(jobId, 'failed', {
      error_message: error.message,
      completed_at: new Date().toISOString()
    });

    throw error;
  }
}

// ============================================================================
// GPU INSTANCE MANAGEMENT
// ============================================================================

/**
 * Claim GPU instance from warm pool or use local ComfyUI
 */
async function claimGPUInstance(workflowType) {
  // Try warm pool first
  try {
    const claim = await warmPool.claim(30); // 30 minute lease

    if (claim && claim.connectionUrl) {
      console.log(`[GPU] Claimed warm instance: ${claim.contractId} for ${workflowType}`);
      return {
        type: 'vastai',
        connectionUrl: claim.connectionUrl,
        contractId: claim.contractId,
        isWarm: true
      };
    }
  } catch (err) {
    console.warn('[GPU] Warm pool claim failed:', err.message);
  }

  // Fall back to local ComfyUI
  console.log('[GPU] Using local ComfyUI instance');
  return {
    type: 'local',
    connectionUrl: 'http://127.0.0.1:8188',
    contractId: null,
    isWarm: false
  };
}

// ============================================================================
// WORKFLOW BUILDING
// ============================================================================

const comfyWorkflows = require('./comfy-workflows');

/**
 * Build ComfyUI workflow based on job type
 */
function buildWorkflowForJob(jobData, muse) {
  const baseParams = {
    prompt: jobData.prompt,
    negativePrompt: jobData.negativePrompt,
    width: jobData.width,
    height: jobData.height,
    steps: jobData.steps,
    cfgScale: jobData.cfgScale,
    seed: jobData.seed,
    sampler: jobData.sampler,
    checkpoint: jobData.checkpoint
  };

  return comfyWorkflows.buildWorkflow(
    jobData.workflowType === 'video' ? { ...baseParams, frames: jobData.frameCount, fps: jobData.fps } : baseParams,
    jobData.workflowType
  );
}


// ============================================================================
// COMFYUI COMMUNICATION
// ============================================================================

/**
 * Submit workflow to ComfyUI instance
 */
async function submitToComfyUI(instance, workflow) {
  const url = instance.type === 'vastai'
    ? 'http://localhost:3000/api/proxy/comfy/prompt'
    : `${instance.connectionUrl}/prompt`;

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      prompt: workflow,
      client_id: 'aikings_server_' + Date.now()
    })
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`ComfyUI submission failed: ${response.status} - ${text}`);
  }

  return await response.json();
}

/**
 * Poll ComfyUI until generation completes
 */
async function pollComfyUIUntilComplete(instance, promptId, workflowType) {
  const maxAttempts = workflowType === 'video' ? 120 : 60; // 10min for video, 5min for image
  const pollInterval = 5000; // 5 seconds

  for (let i = 0; i < maxAttempts; i++) {
    await sleep(pollInterval);

    try {
      const url = instance.type === 'vastai'
        ? `http://localhost:3000/api/proxy/comfy/history/${promptId}`
        : `${instance.connectionUrl}/history/${promptId}`;

      const response = await fetch(url);
      if (!response.ok) continue;

      const history = await response.json();

      if (!history[promptId]) continue; // Still processing

      const execution = history[promptId];

      // Check if completed
      if (execution.status?.completed) {
        const outputs = execution.outputs;

        // For video: find video output node
        if (workflowType === 'video') {
          const videoNode = Object.values(outputs).find(o => o.gifs && o.gifs.length > 0);
          if (videoNode && videoNode.gifs[0]) {
            return {
              type: 'video',
              filename: videoNode.gifs[0].filename,
              subfolder: videoNode.gifs[0].subfolder || '',
              fileType: videoNode.gifs[0].type || 'output'
            };
          }
        }

        // For image: find image output node
        const imageNode = Object.values(outputs).find(o => o.images && o.images.length > 0);
        if (imageNode && imageNode.images[0]) {
          return {
            type: 'image',
            filename: imageNode.images[0].filename,
            subfolder: imageNode.images[0].subfolder || '',
            fileType: imageNode.images[0].type || 'output'
          };
        }

        throw new Error('No output found in ComfyUI result');
      }

      // Check if failed
      if (execution.status?.status_str === 'error') {
        throw new Error(execution.status.error || 'ComfyUI execution failed');
      }

    } catch (error) {
      if (i === maxAttempts - 1) throw error; // Re-throw on last attempt
      console.warn(`[ComfyUI] Polling attempt ${i + 1} failed:`, error.message);
    }
  }

  throw new Error(`Generation timeout after ${maxAttempts * pollInterval / 1000} seconds`);
}

// ============================================================================
// FILE STORAGE
// ============================================================================

/**
 * Download result from ComfyUI and save to disk
 */
async function downloadAndSave(instance, result, jobId, workflowType) {
  const { filename, subfolder, fileType } = result;

  // Build URL
  const params = new URLSearchParams({ filename, subfolder, type: fileType });
  const url = instance.type === 'vastai'
    ? `http://localhost:3000/api/proxy/comfy/view?${params}`
    : `${instance.connectionUrl}/view?${params}`;

  // Download
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to download ${workflowType}: ${response.status}`);
  }

  const buffer = await response.buffer();

  // Save to disk
  const extension = workflowType === 'video' ? 'mp4' : 'png';
  const saveDir = path.join(__dirname, '..', 'data', 'generated');
  if (!fs.existsSync(saveDir)) {
    fs.mkdirSync(saveDir, { recursive: true });
  }

  const savePath = path.join(saveDir, `${jobId}.${extension}`);
  fs.writeFileSync(savePath, buffer);

  console.log(`[Storage] Saved ${workflowType} to: ${savePath} (${buffer.length} bytes)`);

  return savePath;
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Calculate progress percentage based on job status
 */
function calculateProgress(job) {
  if (job.status === 'completed') return 100;
  if (job.status === 'failed') return 0;
  if (job.status === 'processing') {
    // If we have ComfyUI prompt ID, we're at least 50% through
    if (job.comfyui_prompt_id) return 50;
    return 25;
  }
  return 10; // pending
}

/**
 * Calculate generation time from job timestamps
 */
function calculateGenerationTime(job) {
  if (!job.started_at || !job.completed_at) return null;

  const start = new Date(job.started_at);
  const end = new Date(job.completed_at);
  return (end - start) / 1000; // seconds
}

/**
 * Generate unique job ID
 */
function generateJobId() {
  return 'job_' + Date.now() + '_' + crypto.randomBytes(4).toString('hex');
}

/**
 * Sleep utility
 */
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  handleGenerate,
  getJobStatus
};
