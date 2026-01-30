// server/comfy-workflows.js - ComfyUI workflow templates and helpers
// Now uses template-based system with pre-flight validation support
// Maintains backward compatibility with legacy buildImageWorkflow/buildVideoWorkflow functions

const workflowLoader = require('./workflow-loader');
const { validateWorkflow, throwValidationError } = require('./workflow-validator');

// ============================================================================
// TEMPLATE-BASED WORKFLOW BUILDER (NEW - RECOMMENDED)
// ============================================================================

/**
 * Build workflow from template with optional validation
 * This is the primary function for new code
 *
 * @param {Object} params - Generation parameters (prompt, seed, width, height, etc.)
 * @param {string} type - 'image' or 'video'
 * @param {string} template - Specific template name (optional, auto-selected if null)
 * @param {Object} modelInventory - Available models for validation (optional)
 * @returns {Object} - ComfyUI workflow JSON
 */
function buildWorkflow(params = {}, type = 'image', template = null, modelInventory = null) {
  let templateName;

  // Determine which template to use
  if (template && workflowLoader.hasTemplate(template)) {
    // Explicit template requested
    templateName = template;
  } else if (params.loraName) {
    // LoRA requested - use fetish template
    templateName = 'fetish_image_lora';
  } else if (params.nsfw && type === 'video') {
    templateName = 'nsfw_video_animatediff';
  } else if (params.nsfw) {
    templateName = 'nsfw_image_pony';
  } else if (type === 'video') {
    templateName = 'nsfw_video_animatediff';
  } else {
    // Default SFW image template
    templateName = 'sfw_image_dreamshaper';
  }

  // Try to use template system, fall back to legacy if template not found
  let workflow;
  try {
    workflow = workflowLoader.hydrateTemplate(templateName, params);
  } catch (error) {
    console.warn(`Workflow template '${templateName}' not found, using legacy builder:`, error.message);
    // Fall back to legacy builders
    if (type === 'video') {
      return buildVideoWorkflowLegacy(params);
    }
    return buildImageWorkflowLegacy(params);
  }

  // Validate against available models if inventory provided
  if (modelInventory) {
    const validation = validateWorkflow(workflow, modelInventory);
    if (!validation.valid) {
      throwValidationError(validation);
    }
  }

  return workflow;
}

// ============================================================================
// LEGACY WORKFLOW BUILDERS (BACKWARD COMPATIBILITY)
// ============================================================================

/**
 * Legacy image workflow builder - maintained for backward compatibility
 * New code should use buildWorkflow() with templates instead
 */
function buildImageWorkflow(params = {}) {
  // Try template system first
  try {
    const templateName = params.nsfw ? 'nsfw_image_pony' : 'sfw_image_dreamshaper';
    return workflowLoader.hydrateTemplate(templateName, params);
  } catch (error) {
    // Fall back to inline builder
    return buildImageWorkflowLegacy(params);
  }
}

/**
 * Legacy video workflow builder - maintained for backward compatibility
 * New code should use buildWorkflow() with templates instead
 */
function buildVideoWorkflow(params = {}) {
  // Try template system first
  try {
    return workflowLoader.hydrateTemplate('nsfw_video_animatediff', params);
  } catch (error) {
    // Fall back to inline builder
    return buildVideoWorkflowLegacy(params);
  }
}

// ============================================================================
// INLINE LEGACY BUILDERS (FALLBACK)
// ============================================================================

function buildImageWorkflowLegacy(params = {}) {
  const {
    prompt = 'beautiful fantasy',
    negativePrompt = 'ugly, deformed, bad anatomy',
    width = 512,
    height = 768,
    steps = 25,
    cfgScale = 7,
    seed = Math.floor(Math.random() * 1000000000),
    sampler = 'euler_ancestral',
    checkpoint = 'dreamshaper_8.safetensors'
  } = params;

  return {
    "1": { "inputs": { "ckpt_name": checkpoint }, "class_type": "CheckpointLoaderSimple" },
    "2": { "inputs": { "text": prompt, "clip": ["1", 1] }, "class_type": "CLIPTextEncode" },
    "3": { "inputs": { "text": negativePrompt, "clip": ["1", 1] }, "class_type": "CLIPTextEncode" },
    "4": {
      "inputs": {
        "seed": seed,
        "steps": steps,
        "cfg": cfgScale,
        "sampler_name": sampler,
        "scheduler": "normal",
        "denoise": 1.0,
        "model": ["1", 0],
        "positive": ["2", 0],
        "negative": ["3", 0],
        "latent_image": ["5", 0]
      },
      "class_type": "KSampler"
    },
    "5": { "inputs": { "width": width, "height": height, "batch_size": 1 }, "class_type": "EmptyLatentImage" },
    "6": { "inputs": { "samples": ["4", 0], "vae": ["1", 2] }, "class_type": "VAEDecode" },
    "7": { "inputs": { "filename_prefix": "aikings", "images": ["6", 0] }, "class_type": "SaveImage" }
  };
}

function buildVideoWorkflowLegacy(params = {}) {
  const {
    prompt = 'cinematic animation',
    negativePrompt = 'ugly, deformed, bad anatomy',
    width = 512,
    height = 512,
    steps = 30,
    cfgScale = 7,
    seed = Math.floor(Math.random() * 1000000000),
    frames = 16,
    fps = 8,
    sampler = 'euler',
    checkpoint = 'dreamshaper_8.safetensors'
  } = params;

  return {
    "1": { "inputs": { "ckpt_name": checkpoint }, "class_type": "CheckpointLoaderSimple" },
    "2": { "inputs": { "text": prompt, "clip": ["1", 1] }, "class_type": "CLIPTextEncode" },
    "3": { "inputs": { "text": negativePrompt, "clip": ["1", 1] }, "class_type": "CLIPTextEncode" },
    "4": { "inputs": { "model_name": "mm_sd_v15_v2.ckpt", "beta_schedule": "sqrt_linear (AnimateDiff)" }, "class_type": "AnimateDiffLoader" },
    "5": { "inputs": { "width": width, "height": height, "batch_size": frames }, "class_type": "EmptyLatentImage" },
    "6": {
      "inputs": {
        "seed": seed,
        "steps": steps,
        "cfg": cfgScale,
        "sampler_name": sampler,
        "scheduler": "normal",
        "denoise": 1.0,
        "model": ["4", 0],
        "positive": ["2", 0],
        "negative": ["3", 0],
        "latent_image": ["5", 0]
      },
      "class_type": "KSampler"
    },
    "7": { "inputs": { "samples": ["6", 0], "vae": ["1", 2] }, "class_type": "VAEDecode" },
    "8": {
      "inputs": {
        "images": ["7", 0],
        "fps": fps,
        "format": "video/h264-mp4",
        "filename_prefix": "aikings_video"
      },
      "class_type": "VHS_VideoCombine"
    }
  };
}

// ============================================================================
// TEMPLATE DISCOVERY API
// ============================================================================

/**
 * List available workflow templates
 * @returns {Array} - Array of template info objects
 */
function listTemplates() {
  try {
    return workflowLoader.listTemplates();
  } catch (error) {
    console.warn('Failed to list templates:', error.message);
    return [];
  }
}

/**
 * Get required models for a specific template
 * @param {string} templateName - Template name
 * @returns {Object} - Required models config
 */
function getRequiredModels(templateName) {
  return workflowLoader.getRequiredModels(templateName);
}

/**
 * Check if a template exists
 * @param {string} templateName - Template name
 * @returns {boolean}
 */
function hasTemplate(templateName) {
  return workflowLoader.hasTemplate(templateName);
}

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  // Primary API (use these)
  buildWorkflow,
  listTemplates,
  getRequiredModels,
  hasTemplate,

  // Legacy API (backward compatibility)
  buildImageWorkflow,
  buildVideoWorkflow
};
