/**
 * Fetch with Timeout and Retry
 *
 * Wraps node-fetch with automatic timeout and exponential backoff retry.
 * Prevents hanging on network issues and handles transient errors gracefully.
 *
 * @module fetch-with-timeout
 */

const fetch = require('node-fetch');
// Robust AbortController detection: prefer global if it's a constructor; otherwise try
// require('abort-controller') and handle different module shapes. If not available
// (or not a constructor), fall back to a Promise.race timeout which does not abort
// the underlying request but prevents hangs.
let AbortController;
try {
    if (typeof globalThis !== 'undefined' && typeof globalThis.AbortController === 'function') {
        AbortController = globalThis.AbortController;
    } else {
        const ac = require('abort-controller');
        AbortController = (typeof ac === 'function') ? ac : (ac && (ac.default || ac.AbortController));
        if (typeof AbortController !== 'function') AbortController = null;
    }
} catch (e) {
    AbortController = null;
}

/**
 * Fetch with automatic timeout protection
 * @param {string} url - URL to fetch
 * @param {object} options - Fetch options (method, headers, body, etc.)
 * @param {number} timeoutMs - Timeout in milliseconds (default: 30000)
 * @returns {Promise<Response>} Fetch response
 * @throws {Error} On timeout or fetch failure
 */
async function fetchWithTimeout(url, options = {}, timeoutMs = 30000) {
    if (AbortController) {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), timeoutMs);

        try {
            const response = await fetch(url, {
                ...options,
                signal: controller.signal
            });
            clearTimeout(timeout);
            return response;
        } catch (err) {
            clearTimeout(timeout);
            if (err && err.name === 'AbortError') {
                throw new Error(`Request timeout after ${timeoutMs}ms: ${url}`);
            }
            throw err;
        }
    }

    // Fallback: if AbortController is not available/usable, use Promise.race to
    // enforce a timeout without attempting to abort the underlying request.
    const timeoutPromise = new Promise((_, reject) => setTimeout(() => reject(new Error(`Request timeout after ${timeoutMs}ms: ${url}`)), timeoutMs));
    return Promise.race([fetch(url, options), timeoutPromise]);
}

/**
 * Fetch with automatic retry and exponential backoff
 * @param {string} url - URL to fetch
 * @param {object} options - Fetch options
 * @param {number} timeoutMs - Timeout per attempt (default: 30000)
 * @param {number} maxRetries - Maximum retry attempts (default: 3)
 * @param {number} initialDelayMs - Initial delay before first retry (default: 1000)
 * @returns {Promise<Response>} Fetch response
 */
async function fetchWithRetry(url, options = {}, timeoutMs = 30000, maxRetries = 3, initialDelayMs = 1000) {
    let lastError;
    let delay = initialDelayMs;

    for (let attempt = 0; attempt <= maxRetries; attempt++) {
        try {
            const response = await fetchWithTimeout(url, options, timeoutMs);

            // Only retry on transient server errors (5xx) or rate limits (429)
            if (response.status >= 500 || response.status === 429) {
                if (attempt < maxRetries) {
                    console.warn(`fetch-with-retry: HTTP ${response.status} for ${url}, retrying in ${delay}ms (attempt ${attempt + 1}/${maxRetries})`);
                    await sleep(delay);
                    delay *= 2; // Exponential backoff
                    continue;
                }
            }

            // Success or non-retryable error
            return response;

        } catch (err) {
            lastError = err;

            // Retry on network errors or timeouts
            if (attempt < maxRetries) {
                console.warn(`fetch-with-retry: ${err.message}, retrying in ${delay}ms (attempt ${attempt + 1}/${maxRetries})`);
                await sleep(delay);
                delay *= 2; // Exponential backoff
            }
        }
    }

    // All retries exhausted
    throw new Error(`All ${maxRetries} retry attempts failed for ${url}: ${lastError.message}`);
}

/**
 * Sleep helper for delays
 * @param {number} ms - Milliseconds to sleep
 * @returns {Promise<void>}
 */
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

module.exports = {
    fetchWithTimeout,
    fetchWithRetry
};
