/**
 * AI KINGS API Configuration
 * Vast.ai GPU API integration configuration
 */

const AIKingsAPIConfig = {
  // Vast.ai API Configuration
  vast: {
    baseUrl: 'https://api.vast.ai/v1',
    endpoints: {
      generate: '/generate',
      status: '/status',
      cancel: '/cancel',
      instances: '/instances',
      templates: '/templates'
    },

    // API Key - Set via initialize() method or setApiKey()
    apiKey: null,

    // Request configuration
    request: {
      timeout: 30000, // 30 seconds
      retries: 3,
      retryDelay: 1000, // 1 second
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    },

    // Generation parameters
    generation: {
      defaultModel: 'stable-diffusion-xl',
      supportedModels: [
        'stable-diffusion-xl',
        'dalle-3',
        'midjourney-v5',
        'stable-diffusion-2.1',
        'stable-diffusion-1.5'
      ],

      // Quality presets
      qualityPresets: {
        low: { width: 512, height: 512, steps: 20 },
        medium: { width: 768, height: 768, steps: 30 },
        high: { width: 1024, height: 1024, steps: 50 },
        ultra: { width: 1536, height: 1536, steps: 75 }
      },

      // Content type configurations
      contentTypes: {
        image: {
          formats: ['png', 'jpg', 'webp'],
          defaultFormat: 'png',
          maxSize: '10MB'
        },
        video: {
          formats: ['mp4', 'webm'],
          defaultFormat: 'mp4',
          maxDuration: 60, // seconds
          maxSize: '100MB',
          fps: 30
        }
      },

      // Pricing (per generation)
      pricing: {
        image: {
          low: 0.02,
          medium: 0.05,
          high: 0.10,
          ultra: 0.20
        },
        video: {
          short: 0.50,  // 5-15 seconds
          medium: 1.00, // 16-30 seconds
          long: 2.00    // 31-60 seconds
        }
      }
    },

    // Status polling configuration
    polling: {
      interval: 5000, // 5 seconds
      maxAttempts: 120, // 10 minutes max
      backoffMultiplier: 1.2,
      statusMap: {
        'pending': 'queued',
        'running': 'generating',
        'completed': 'completed',
        'failed': 'failed',
        'cancelled': 'cancelled'
      }
    }
  },

  // Response format definitions
  response: {
    success: {
      status: 'success',
      data: {},
      timestamp: null
    },

    error: {
      status: 'error',
      error: {
        code: null,
        message: null,
        details: null
      },
      timestamp: null
    },

    generation: {
      job: {
        id: null,
        status: null,
        progress: 0,
        estimatedTime: null,
        createdAt: null,
        updatedAt: null
      },

      result: {
        id: null,
        type: null, // 'image' or 'video'
        url: null,
        thumbnail: null,
        metadata: {
          prompt: null,
          model: null,
          parameters: {},
          generationTime: null,
          cost: null
        }
      }
    }
  },

  // Error handling
  errors: {
    codes: {
      INVALID_API_KEY: 'INVALID_API_KEY',
      INSUFFICIENT_CREDITS: 'INSUFFICIENT_CREDITS',
      INVALID_PROMPT: 'INVALID_PROMPT',
      MODEL_UNAVAILABLE: 'MODEL_UNAVAILABLE',
      GENERATION_FAILED: 'GENERATION_FAILED',
      TIMEOUT: 'TIMEOUT',
      NETWORK_ERROR: 'NETWORK_ERROR',
      RATE_LIMITED: 'RATE_LIMITED'
    },

    messages: {
      INVALID_API_KEY: 'Invalid API key. Please check your Vast.ai API credentials.',
      INSUFFICIENT_CREDITS: 'Insufficient credits. Please top up your Vast.ai account.',
      INVALID_PROMPT: 'Invalid prompt. Please check your input and try again.',
      MODEL_UNAVAILABLE: 'Selected AI model is currently unavailable. Please try another model.',
      GENERATION_FAILED: 'Generation failed. Please try again or contact support.',
      TIMEOUT: 'Generation timed out. Please try again.',
      NETWORK_ERROR: 'Network error. Please check your connection and try again.',
      RATE_LIMITED: 'Rate limit exceeded. Please wait before making another request.'
    }
  },

  // Webhook configuration (optional)
  webhooks: {
    enabled: false,
    endpoint: null,
    secret: null,
    events: ['generation.completed', 'generation.failed']
  },

  // Analytics and tracking
  analytics: {
    enabled: true,
    events: {
      generationStarted: 'generation_started',
      generationCompleted: 'generation_completed',
      generationFailed: 'generation_failed',
      apiError: 'api_error'
    }
  },

  // Development/Testing configuration
  development: {
    mockMode: false,
    mockDelay: 3000,
    mockResponses: {
      success: {
        job: {
          id: 'mock-job-123',
          status: 'completed',
          progress: 100,
          result: {
            id: 'mock-result-456',
            type: 'video',
            url: 'https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4',
            thumbnail: 'https://via.placeholder.com/400x225/2a2a2a/ffffff?text=AI+Generated',
            metadata: {
              prompt: 'Mock generation result',
              model: 'stable-diffusion-xl',
              generationTime: 30,
              cost: 0.10
            }
          }
        }
      },
      error: {
        error: {
          code: 'GENERATION_FAILED',
          message: 'Mock generation failed'
        }
      }
    }
  }
};

/**
 * API Client Class for Vast.ai integration
 */
class AIKingsAPIClient {
  constructor(config = AIKingsAPIConfig) {
    this.config = config;
    this.baseUrl = config.vast.baseUrl;
    this.apiKey = config.vast.apiKey;
    this.requestConfig = config.vast.request;
  }

  /**
   * Initialize API client with API key
   */
  initialize(apiKey) {
    this.apiKey = apiKey;
  }

  /**
   * Make authenticated API request
   */
  async request(endpoint, options = {}) {
    const url = `${this.baseUrl}${endpoint}`;
    const config = {
      method: options.method || 'GET',
      headers: {
        ...this.requestConfig.headers,
        'Authorization': `Bearer ${this.apiKey}`,
        ...options.headers
      },
      ...options
    };

    if (options.body && typeof options.body === 'object') {
      config.body = JSON.stringify(options.body);
    }

    let attempt = 0;
    while (attempt < this.requestConfig.retries) {
      try {
        const response = await this.fetchWithTimeout(url, config);

        if (response.ok) {
          return await response.json();
        }

        // Handle specific error codes
        const errorData = await response.json().catch(() => ({}));
        throw new APIError(response.status, errorData.error?.message || response.statusText, errorData);

      } catch (error) {
        attempt++;

        if (attempt >= this.requestConfig.retries || error instanceof APIError) {
          throw error;
        }

        // Wait before retry
        await this.delay(this.requestConfig.retryDelay * attempt);
      }
    }
  }

  /**
   * Fetch with timeout
   */
  async fetchWithTimeout(url, options = {}) {
    const { timeout = this.requestConfig.timeout } = options;

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);

    try {
      const response = await fetch(url, {
        ...options,
        signal: controller.signal
      });
      clearTimeout(timeoutId);
      return response;
    } catch (error) {
      clearTimeout(timeoutId);
      if (error.name === 'AbortError') {
        throw new APIError(408, 'Request timeout');
      }
      throw error;
    }
  }

  /**
   * Start AI generation
   */
  async generateContent(params) {
    const endpoint = this.config.vast.endpoints.generate;
    const payload = this.buildGenerationPayload(params);

    return await this.request(endpoint, {
      method: 'POST',
      body: payload
    });
  }

  /**
   * Check generation status
   */
  async getGenerationStatus(jobId) {
    const endpoint = `${this.config.vast.endpoints.status}/${jobId}`;
    return await this.request(endpoint);
  }

  /**
   * Cancel generation
   */
  async cancelGeneration(jobId) {
    const endpoint = `${this.config.vast.endpoints.cancel}/${jobId}`;
    return await this.request(endpoint, {
      method: 'POST'
    });
  }

  /**
   * Get available instances
   */
  async getInstances() {
    const endpoint = this.config.vast.endpoints.instances;
    return await this.request(endpoint);
  }

  /**
   * Build generation payload
   */
  buildGenerationPayload(params) {
    const {
      prompt,
      contentType = 'image',
      model = this.config.vast.generation.defaultModel,
      quality = 'medium',
      style,
      theme
    } = params;

    const qualitySettings = this.config.vast.generation.qualityPresets[quality];
    const contentConfig = this.config.vast.generation.contentTypes[contentType];

    return {
      prompt: prompt,
      content_type: contentType,
      model: model,
      quality: quality,
      parameters: {
        ...qualitySettings,
        style: style,
        theme: theme,
        format: contentConfig.defaultFormat
      },
      webhook_url: this.config.webhooks.enabled ? this.config.webhooks.endpoint : null,
      metadata: {
        source: 'ai-kings-platform',
        timestamp: new Date().toISOString()
      }
    };
  }

  /**
   * Calculate estimated cost
   */
  calculateCost(params) {
    const { contentType, quality, duration } = params;
    const pricing = this.config.vast.generation.pricing[contentType];

    if (contentType === 'video') {
      if (duration <= 15) return pricing.short;
      if (duration <= 30) return pricing.medium;
      return pricing.long;
    }

    return pricing[quality] || pricing.medium;
  }

  /**
   * Delay utility
   */
  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Validate API key
   */
  async validateApiKey() {
    try {
      await this.getInstances();
      return true;
    } catch (error) {
      return false;
    }
  }
}

/**
 * Custom API Error class
 */
class APIError extends Error {
  constructor(status, message, details = {}) {
    super(message);
    this.name = 'APIError';
    this.status = status;
    this.details = details;
  }
}

/**
 * Webhook handler for real-time updates
 */
class AIKingsWebhookHandler {
  constructor(config = AIKingsAPIConfig.webhooks) {
    this.config = config;
    this.listeners = new Map();
  }

  /**
   * Register event listener
   */
  on(event, callback) {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, []);
    }
    this.listeners.get(event).push(callback);
  }

  /**
   * Handle incoming webhook
   */
  async handleWebhook(payload) {
    const { event, data } = payload;

    if (this.listeners.has(event)) {
      const listeners = this.listeners.get(event);
      listeners.forEach(callback => {
        try {
          callback(data);
        } catch (error) {
          console.error(`Webhook listener error for event ${event}:`, error);
        }
      });
    }
  }

  /**
   * Verify webhook signature (if implemented)
   */
  verifySignature(payload, signature) {
    if (!this.config.secret) return true;

    // Implement signature verification logic
    // Return true if valid, false otherwise
    return true;
  }
}

// Global instances
window.aiKingsAPI = new AIKingsAPIClient();
window.aiKingsWebhooks = new AIKingsWebhookHandler();

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    AIKingsAPIConfig,
    AIKingsAPIClient,
    AIKingsWebhookHandler,
    APIError
  };
}