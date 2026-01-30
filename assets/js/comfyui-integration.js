/**
 * ComfyUI Integration for AI KINGS Studio
 * Handles workflow submission, polling, and image retrieval
 */

class ComfyUIIntegration {
    constructor() {
        this.baseUrl = 'http://127.0.0.1:8188';
        this.serviceType = 'local'; // 'local' or 'vastai'
        this.apiKey = null;
        this.clientId = this.generateClientId();
    }

    generateClientId() {
        return 'aikings_' + Math.random().toString(36).substring(2, 15);
    }

    /**
     * Set ComfyUI endpoint (local or via proxy)
     * @param {string} endpoint - Base URL for ComfyUI
     * @param {Object} options - Additional options like serviceType and apiKey
     */
    setEndpoint(endpoint, options = {}) {
        this.baseUrl = endpoint;
        this.serviceType = options.serviceType || 'local';
        this.apiKey = options.apiKey || null;
        console.log(`ComfyUI endpoint set to: ${endpoint} (${this.serviceType})`);
    }

    /**
     * Build a basic text-to-image workflow for ComfyUI
     * @param {Object} params - Generation parameters
     * @returns {Object} ComfyUI workflow JSON
     */
    buildWorkflow(params) {
        const {
            prompt = "beautiful fantasy character",
            negativePrompt = "ugly, bad anatomy, bad hands",
            width = 512,
            height = 768,
            steps = 25,
            cfgScale = 7,
            seed = Math.floor(Math.random() * 1000000000),
            sampler = "euler_ancestral",
            scheduler = "normal",
            denoise = 1.0,
            model = "dreamshaper_8.safetensors",
            checkpoint = null
        } = params;

        // Basic SDXL/SD1.5 workflow
        return {
            "1": {
                "inputs": {
                    "ckpt_name": checkpoint || model
                },
                "class_type": "CheckpointLoaderSimple"
            },
            "2": {
                "inputs": {
                    "text": prompt,
                    "clip": ["1", 1]
                },
                "class_type": "CLIPTextEncode"
            },
            "3": {
                "inputs": {
                    "text": negativePrompt,
                    "clip": ["1", 1]
                },
                "class_type": "CLIPTextEncode"
            },
            "4": {
                "inputs": {
                    "seed": seed,
                    "steps": steps,
                    "cfg": cfgScale,
                    "sampler_name": sampler,
                    "scheduler": scheduler,
                    "denoise": denoise,
                    "model": ["1", 0],
                    "positive": ["2", 0],
                    "negative": ["3", 0],
                    "latent_image": ["5", 0]
                },
                "class_type": "KSampler"
            },
            "5": {
                "inputs": {
                    "width": width,
                    "height": height,
                    "batch_size": 1
                },
                "class_type": "EmptyLatentImage"
            },
            "6": {
                "inputs": {
                    "samples": ["4", 0],
                    "vae": ["1", 2]
                },
                "class_type": "VAEDecode"
            },
            "7": {
                "inputs": {
                    "filename_prefix": "aikings",
                    "images": ["6", 0]
                },
                "class_type": "SaveImage"
            }
        };
    }

    /**
     * Submit workflow to ComfyUI
     * @param {Object} workflow - ComfyUI workflow JSON
     * @returns {Promise<Object>} Response with prompt_id
     */
    async submitWorkflow(workflow) {
        const url = `${this.baseUrl}/prompt`;

        try {
            const response = await fetch(url, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    ...(this.apiKey && { 'X-API-Key': this.apiKey })
                },
                body: JSON.stringify({
                    prompt: workflow,
                    client_id: this.clientId
                })
            });

            if (!response.ok) {
                const text = await response.text();
                throw new Error(`ComfyUI request failed: ${response.status} - ${text}`);
            }

            const data = await response.json();
            console.log('Workflow submitted:', data);
            return data;

        } catch (error) {
            console.error('ComfyUI submission error:', error);
            throw error;
        }
    }

    /**
     * Get workflow execution history
     * @param {string} promptId - Prompt ID to check
     * @returns {Promise<Object>} History data
     */
    async getHistory(promptId) {
        const url = `${this.baseUrl}/history/${promptId}`;

        try {
            const response = await fetch(url, {
                headers: {
                    ...(this.apiKey && { 'X-API-Key': this.apiKey })
                }
            });

            if (!response.ok) {
                throw new Error(`Failed to get history: ${response.status}`);
            }

            return await response.json();
        } catch (error) {
            console.error('History fetch error:', error);
            throw error;
        }
    }

    /**
     * Get generated image URL
     * @param {string} filename - Image filename
     * @param {string} subfolder - Subfolder path
     * @param {string} type - Image type (output, input, temp)
     * @returns {Promise<string>} Image URL or data URL
     */
    async getImage(filename, subfolder = '', type = 'output') {
        const params = new URLSearchParams({
            filename,
            subfolder,
            type
        });

        const url = `${this.baseUrl}/view?${params}`;

        try {
            const response = await fetch(url, {
                headers: {
                    ...(this.apiKey && { 'X-API-Key': this.apiKey })
                }
            });

            if (!response.ok) {
                throw new Error(`Failed to get image: ${response.status}`);
            }

            // Convert to blob and create object URL
            const blob = await response.blob();
            return URL.createObjectURL(blob);

        } catch (error) {
            console.error('Image fetch error:', error);
            throw error;
        }
    }

    /**
     * Check if ComfyUI is available
     * @returns {Promise<boolean>}
     */
    async isAvailable() {
        try {
            const url = `${this.baseUrl}/system_stats`;

            const response = await fetch(url, {
                method: 'GET',
                headers: {
                    ...(this.apiKey && { 'X-API-Key': this.apiKey })
                }
            });

            return response.ok;
        } catch (error) {
            console.error('ComfyUI availability check failed:', error);
            return false;
        }
    }

    /**
     * Get available models/checkpoints
     * @returns {Promise<Array>} List of available models
     */
    async getModels() {
        try {
            const url = `${this.baseUrl}/object_info`;

            const response = await fetch(url, {
                headers: {
                    ...(this.apiKey && { 'X-API-Key': this.apiKey })
                }
            });

            if (!response.ok) {
                throw new Error('Failed to fetch models');
            }

            const data = await response.json();

            // Extract checkpoint names
            if (data.CheckpointLoaderSimple?.input?.required?.ckpt_name) {
                return data.CheckpointLoaderSimple.input.required.ckpt_name[0];
            }

            return [];
        } catch (error) {
            console.error('Model fetch error:', error);
            return [];
        }
    }

    /**
     * Build AnimateDiff video workflow
     * @param {Object} params - Generation parameters including frames and fps
     * @returns {Object} ComfyUI workflow JSON for video
     */
    buildVideoWorkflow(params) {
        const {
            prompt = "beautiful fantasy character",
            negativePrompt = "ugly, bad anatomy",
            width = 512,
            height = 512,
            steps = 20,
            cfgScale = 7,
            frames = 16,
            fps = 8,
            seed = Math.floor(Math.random() * 1000000000),
            checkpoint = "dreamshaper_8.safetensors",
            motionModule = "mm_sd_v15_v2.ckpt"
        } = params;

        return {
            "1": {
                "inputs": { "ckpt_name": checkpoint },
                "class_type": "CheckpointLoaderSimple"
            },
            "2": {
                "inputs": { "text": prompt, "clip": ["1", 1] },
                "class_type": "CLIPTextEncode"
            },
            "3": {
                "inputs": { "text": negativePrompt, "clip": ["1", 1] },
                "class_type": "CLIPTextEncode"
            },
            "4": {
                "inputs": { "model_name": motionModule },
                "class_type": "AnimateDiffLoader"
            },
            "5": {
                "inputs": {
                    "width": width,
                    "height": height,
                    "batch_size": frames
                },
                "class_type": "EmptyLatentImage"
            },
            "6": {
                "inputs": {
                    "seed": seed,
                    "steps": steps,
                    "cfg": cfgScale,
                    "sampler_name": "euler",
                    "scheduler": "normal",
                    "denoise": 1.0,
                    "model": ["4", 0], // AnimateDiff model output
                    "positive": ["2", 0],
                    "negative": ["3", 0],
                    "latent_image": ["5", 0]
                },
                "class_type": "KSampler"
            },
            "7": {
                "inputs": {
                    "samples": ["6", 0],
                    "vae": ["1", 2]
                },
                "class_type": "VAEDecode"
            },
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
}

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = ComfyUIIntegration;
}
