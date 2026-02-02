/**
 * ComfyUI Keepalive - Proactive connection monitoring
 *
 * Sends lightweight pings to ComfyUI endpoint to detect connection loss early.
 * Emits events for monitoring and triggering recovery actions.
 */

const EventEmitter = require('events');
const { fetchWithTimeout } = require('./fetch-with-timeout');

class ComfyUIKeepalive extends EventEmitter {
  /**
   * @param {string} connectionUrl - Base URL of ComfyUI instance (e.g., http://IP:8188)
   * @param {object} options - Configuration options
   * @param {number} options.intervalMs - Ping interval in milliseconds (default: 30000)
   * @param {number} options.timeoutMs - Timeout per ping in milliseconds (default: 5000)
   * @param {number} options.maxConsecutiveFailures - Alert threshold (default: 5)
   */
  constructor(connectionUrl, options = {}) {
    super();
    this.connectionUrl = connectionUrl;
    this.intervalMs = options.intervalMs || parseInt(process.env.COMFYUI_KEEPALIVE_INTERVAL_MS || '30000', 10);
    this.timeoutMs = options.timeoutMs || parseInt(process.env.COMFYUI_KEEPALIVE_TIMEOUT_MS || '5000', 10);
    this.maxConsecutiveFailures = options.maxConsecutiveFailures || parseInt(process.env.COMFYUI_KEEPALIVE_MAX_FAILURES || '5', 10);

    this.intervalHandle = null;
    this.consecutiveFailures = 0;
    this.lastSuccessTime = null;
    this.lastError = null;
    this.isRunning = false;
    this.totalPings = 0;
    this.totalSuccesses = 0;
    this.totalFailures = 0;
  }

  /**
   * Send a single keepalive ping
   */
  async ping() {
    if (!this.connectionUrl) {
      this.emit('error', new Error('No connection URL configured'));
      return;
    }

    this.totalPings++;
    const pingStartTime = Date.now();

    try {
      const response = await fetchWithTimeout(
        `${this.connectionUrl}/system_stats`,
        {
          method: 'GET',
          headers: { 'Accept': 'application/json' }
        },
        this.timeoutMs
      );

      if (!response.ok) {
        throw new Error(`HTTP ${response.status} ${response.statusText}`);
      }

      // Success
      this.consecutiveFailures = 0;
      this.lastSuccessTime = new Date();
      this.lastError = null;
      this.totalSuccesses++;

      const pingDuration = Date.now() - pingStartTime;

      this.emit('ping-success', {
        duration: pingDuration,
        timestamp: this.lastSuccessTime,
        consecutiveFailures: this.consecutiveFailures
      });

      return { success: true, duration: pingDuration };
    } catch (err) {
      // Failure
      this.consecutiveFailures++;
      this.lastError = err.message;
      this.totalFailures++;

      this.emit('ping-failure', {
        error: err.message,
        failures: this.consecutiveFailures,
        timestamp: new Date()
      });

      // Check if we've hit the threshold for connection loss
      if (this.consecutiveFailures >= this.maxConsecutiveFailures) {
        this.emit('connection-lost', {
          failures: this.consecutiveFailures,
          lastError: this.lastError,
          lastSuccess: this.lastSuccessTime
        });
      }

      return { success: false, error: err.message };
    }
  }

  /**
   * Start keepalive monitoring
   */
  start() {
    if (this.isRunning) {
      console.log('[Keepalive] Already running');
      return;
    }

    console.log(`[Keepalive] Starting monitoring for ${this.connectionUrl}`);
    console.log(`[Keepalive] Interval: ${this.intervalMs}ms, Timeout: ${this.timeoutMs}ms, Max failures: ${this.maxConsecutiveFailures}`);

    this.isRunning = true;

    // Run first ping immediately
    this.ping().catch(err => {
      console.error('[Keepalive] Initial ping error:', err.message);
    });

    // Schedule periodic pings
    this.intervalHandle = setInterval(async () => {
      try {
        await this.ping();
      } catch (err) {
        console.error('[Keepalive] Ping error:', err.message);
      }
    }, this.intervalMs);

    this.emit('started', { connectionUrl: this.connectionUrl });
  }

  /**
   * Stop keepalive monitoring
   */
  stop() {
    if (!this.isRunning) {
      return;
    }

    console.log('[Keepalive] Stopping monitoring');

    if (this.intervalHandle) {
      clearInterval(this.intervalHandle);
      this.intervalHandle = null;
    }

    this.isRunning = false;
    this.emit('stopped', {
      totalPings: this.totalPings,
      totalSuccesses: this.totalSuccesses,
      totalFailures: this.totalFailures
    });
  }

  /**
   * Get current status
   */
  getStatus() {
    return {
      isRunning: this.isRunning,
      connectionUrl: this.connectionUrl,
      consecutiveFailures: this.consecutiveFailures,
      lastSuccessTime: this.lastSuccessTime,
      lastError: this.lastError,
      totalPings: this.totalPings,
      totalSuccesses: this.totalSuccesses,
      totalFailures: this.totalFailures,
      successRate: this.totalPings > 0
        ? ((this.totalSuccesses / this.totalPings) * 100).toFixed(2) + '%'
        : 'N/A'
    };
  }

  /**
   * Reset statistics
   */
  resetStats() {
    this.consecutiveFailures = 0;
    this.totalPings = 0;
    this.totalSuccesses = 0;
    this.totalFailures = 0;
    this.lastError = null;
    console.log('[Keepalive] Statistics reset');
  }
}

module.exports = ComfyUIKeepalive;
