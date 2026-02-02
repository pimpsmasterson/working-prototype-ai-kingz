/**
 * Token Manager - Centralized token validation with caching and periodic checks
 *
 * Validates tokens for VastAI, HuggingFace, and Civitai before expensive operations.
 * Provides event-based monitoring for token failures.
 */

const EventEmitter = require('events');
const { fetchWithTimeout } = require('./fetch-with-timeout');

class TokenManager extends EventEmitter {
  constructor() {
    super();
    this.validationCache = new Map();
    this.cacheExpiryMs = parseInt(process.env.TOKEN_VALIDATION_CACHE_MS || '300000', 10); // 5 min default
    this.periodicInterval = null;
  }

  /**
   * Get token from environment
   */
  getToken(service) {
    const envVars = {
      vastai: ['VASTAI_API_KEY', 'VAST_AI_API_KEY'],
      huggingface: ['HUGGINGFACE_HUB_TOKEN', 'HF_TOKEN'],
      civitai: ['CIVITAI_TOKEN', 'CIVITAI_API_KEY']
    };

    const vars = envVars[service.toLowerCase()] || [];
    for (const varName of vars) {
      if (process.env[varName]) {
        return process.env[varName];
      }
    }
    return null;
  }

  /**
   * Validate token format (basic checks before API call)
   */
  validateTokenFormat(service, token) {
    if (!token || typeof token !== 'string') {
      return { valid: false, error: 'Token is missing or invalid type' };
    }

    const minLengths = {
      vastai: 32,      // VastAI tokens are typically 40-64 chars
      huggingface: 30, // HF tokens start with 'hf_' + 30+ chars
      civitai: 32      // Civitai tokens are 32+ chars
    };

    const minLength = minLengths[service.toLowerCase()] || 20;
    if (token.length < minLength) {
      return { valid: false, error: `Token too short (min ${minLength} chars)` };
    }

    // Check for common placeholders
    const placeholders = ['your_token_here', 'replace_me', 'example', 'test123'];
    if (placeholders.some(p => token.toLowerCase().includes(p))) {
      return { valid: false, error: 'Token appears to be a placeholder' };
    }

    return { valid: true };
  }

  /**
   * Validate VastAI token by calling the API
   */
  async validateVastAIToken(token) {
    try {
      const formatCheck = this.validateTokenFormat('vastai', token);
      if (!formatCheck.valid) {
        return { valid: false, error: formatCheck.error };
      }

      // Test with GET /instances endpoint (lightweight)
      const response = await fetchWithTimeout(
        'https://console.vast.ai/api/v0/instances/',
        {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Accept': 'application/json'
          }
        },
        10000
      );

      if (response.status === 401) {
        return { valid: false, error: 'Token authentication failed (401)' };
      }

      if (response.status === 403) {
        return { valid: false, error: 'Token forbidden (403)' };
      }

      if (!response.ok) {
        return { valid: false, error: `API returned ${response.status}` };
      }

      return { valid: true, testedAt: new Date().toISOString() };
    } catch (err) {
      return { valid: false, error: `API test failed: ${err.message}` };
    }
  }

  /**
   * Validate HuggingFace token
   */
  async validateHuggingFaceToken(token) {
    try {
      const formatCheck = this.validateTokenFormat('huggingface', token);
      if (!formatCheck.valid) {
        return { valid: false, error: formatCheck.error };
      }

      // Test with whoami endpoint
      const response = await fetchWithTimeout(
        'https://huggingface.co/api/whoami-v2',
        {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Accept': 'application/json'
          }
        },
        10000
      );

      if (response.status === 401) {
        return { valid: false, error: 'Token authentication failed (401)' };
      }

      if (!response.ok) {
        return { valid: false, error: `API returned ${response.status}` };
      }

      const data = await response.json();
      return {
        valid: true,
        testedAt: new Date().toISOString(),
        user: data.name || data.fullname
      };
    } catch (err) {
      return { valid: false, error: `API test failed: ${err.message}` };
    }
  }

  /**
   * Validate Civitai token
   */
  async validateCivitaiToken(token) {
    try {
      const formatCheck = this.validateTokenFormat('civitai', token);
      if (!formatCheck.valid) {
        return { valid: false, error: formatCheck.error };
      }

      // Test with user info endpoint
      const response = await fetchWithTimeout(
        `https://civitai.com/api/v1/models?token=${token}&limit=1`,
        {
          method: 'GET',
          headers: {
            'Accept': 'application/json'
          }
        },
        10000
      );

      if (response.status === 401) {
        return { valid: false, error: 'Token authentication failed (401)' };
      }

      if (!response.ok) {
        return { valid: false, error: `API returned ${response.status}` };
      }

      return { valid: true, testedAt: new Date().toISOString() };
    } catch (err) {
      return { valid: false, error: `API test failed: ${err.message}` };
    }
  }

  /**
   * Get cached validation result if still valid
   */
  getCachedValidation(service) {
    const cached = this.validationCache.get(service);
    if (!cached) return null;

    const age = Date.now() - cached.timestamp;
    if (age > this.cacheExpiryMs) {
      this.validationCache.delete(service);
      return null;
    }

    return cached.result;
  }

  /**
   * Cache validation result
   */
  setCachedValidation(service, result) {
    this.validationCache.set(service, {
      result,
      timestamp: Date.now()
    });
  }

  /**
   * Validate all configured tokens
   * @param {boolean} useCache - Use cached results if available
   * @returns {Promise<{vastai: object, huggingface: object, civitai: object}>}
   */
  async validateAll(useCache = true) {
    const results = {};

    // VastAI
    const vastaiToken = this.getToken('vastai');
    if (vastaiToken) {
      const cached = useCache ? this.getCachedValidation('vastai') : null;
      if (cached) {
        results.vastai = cached;
      } else {
        results.vastai = await this.validateVastAIToken(vastaiToken);
        this.setCachedValidation('vastai', results.vastai);

        if (results.vastai.valid) {
          this.emit('token-validated', { service: 'vastai', result: results.vastai });
        } else {
          this.emit('token-invalid', { service: 'vastai', error: results.vastai.error });
        }
      }
    } else {
      results.vastai = { valid: false, error: 'Token not configured' };
    }

    // HuggingFace
    const hfToken = this.getToken('huggingface');
    if (hfToken) {
      const cached = useCache ? this.getCachedValidation('huggingface') : null;
      if (cached) {
        results.huggingface = cached;
      } else {
        results.huggingface = await this.validateHuggingFaceToken(hfToken);
        this.setCachedValidation('huggingface', results.huggingface);

        if (results.huggingface.valid) {
          this.emit('token-validated', { service: 'huggingface', result: results.huggingface });
        } else {
          this.emit('token-invalid', { service: 'huggingface', error: results.huggingface.error });
        }
      }
    } else {
      results.huggingface = { valid: false, error: 'Token not configured' };
    }

    // Civitai
    const civitaiToken = this.getToken('civitai');
    if (civitaiToken) {
      const cached = useCache ? this.getCachedValidation('civitai') : null;
      if (cached) {
        results.civitai = cached;
      } else {
        results.civitai = await this.validateCivitaiToken(civitaiToken);
        this.setCachedValidation('civitai', results.civitai);

        if (results.civitai.valid) {
          this.emit('token-validated', { service: 'civitai', result: results.civitai });
        } else {
          this.emit('token-invalid', { service: 'civitai', error: results.civitai.error });
        }
      }
    } else {
      results.civitai = { valid: false, error: 'Token not configured' };
    }

    return results;
  }

  /**
   * Start periodic validation
   */
  startPeriodicValidation(intervalMs = 600000) {
    if (this.periodicInterval) {
      console.log('[TokenManager] Periodic validation already running');
      return;
    }

    console.log(`[TokenManager] Starting periodic token validation (every ${intervalMs/1000}s)`);

    this.periodicInterval = setInterval(async () => {
      console.log('[TokenManager] Running periodic token validation...');
      try {
        await this.validateAll(false); // Force fresh validation
      } catch (err) {
        console.error('[TokenManager] Periodic validation error:', err.message);
      }
    }, intervalMs);

    // Run first validation immediately
    this.validateAll(false).catch(err => {
      console.error('[TokenManager] Initial validation error:', err.message);
    });
  }

  /**
   * Stop periodic validation
   */
  stopPeriodicValidation() {
    if (this.periodicInterval) {
      clearInterval(this.periodicInterval);
      this.periodicInterval = null;
      console.log('[TokenManager] Periodic validation stopped');
    }
  }

  /**
   * Clear all cached validation results
   */
  clearCache() {
    this.validationCache.clear();
    console.log('[TokenManager] Validation cache cleared');
  }
}

// Export singleton instance
module.exports = new TokenManager();
