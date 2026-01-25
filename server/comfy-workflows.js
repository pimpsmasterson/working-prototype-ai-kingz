// Centralized ComfyUI workflow templates and helpers
// Exports: buildImageWorkflow(params), buildVideoWorkflow(params), buildWorkflow(params, type)

function buildImageWorkflow(params = {}) {
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

function buildVideoWorkflow(params = {}) {
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
    checkpoint = 'mm_sd_v15_v2.ckpt'
  } = params;

  return {
    "1": { "inputs": { "ckpt_name": checkpoint }, "class_type": "CheckpointLoaderSimple" },
    "2": { "inputs": { "text": prompt, "clip": ["1", 1] }, "class_type": "CLIPTextEncode" },
    "3": { "inputs": { "text": negativePrompt, "clip": ["1", 1] }, "class_type": "CLIPTextEncode" },
    "4": { "inputs": { "model_name": checkpoint }, "class_type": "AnimateDiffLoader" },
    "5": { "inputs": { "width": width, "height": height, "batch_size": frames }, "class_type": "EmptyLatentImage" },
    "6": {
      "inputs": {
        "seed": seed,
        "steps": steps,
        "cfg": cfgScale,
        "sampler_name": "euler",
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

function buildWorkflow(params = {}, type = 'image') {
  if (type === 'video') return buildVideoWorkflow(params);
  return buildImageWorkflow(params);
}

module.exports = {
  buildImageWorkflow,
  buildVideoWorkflow,
  buildWorkflow
};
