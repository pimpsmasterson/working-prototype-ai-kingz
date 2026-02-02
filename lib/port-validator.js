/**
 * Port Validator - Test port accessibility before marking instance ready
 *
 * Validates that detected ports are actually accessible via:
 * 1. TCP socket connectivity test
 * 2. HTTP endpoint validation (ComfyUI API check)
 * 3. Multi-candidate testing with fallback
 */

const net = require('net');
const { fetchWithTimeout } = require('./fetch-with-timeout');

/**
 * Test TCP connection to host:port
 * @param {string} host - Hostname or IP
 * @param {number} port - Port number
 * @param {number} timeoutMs - Timeout in milliseconds
 * @returns {Promise<{success: boolean, error?: string}>}
 */
function testTCPConnection(host, port, timeoutMs = 5000) {
  return new Promise((resolve) => {
    const socket = new net.Socket();
    let timedOut = false;

    const timeout = setTimeout(() => {
      timedOut = true;
      socket.destroy();
      resolve({ success: false, error: `TCP connection timeout after ${timeoutMs}ms` });
    }, timeoutMs);

    socket.on('connect', () => {
      clearTimeout(timeout);
      socket.destroy();
      if (!timedOut) {
        resolve({ success: true });
      }
    });

    socket.on('error', (err) => {
      clearTimeout(timeout);
      if (!timedOut) {
        resolve({ success: false, error: `TCP connection failed: ${err.message}` });
      }
    });

    try {
      socket.connect(port, host);
    } catch (err) {
      clearTimeout(timeout);
      resolve({ success: false, error: `TCP connection error: ${err.message}` });
    }
  });
}

/**
 * Test HTTP endpoint (ComfyUI API)
 * @param {string} url - Full URL to test
 * @param {number} timeoutMs - Timeout in milliseconds
 * @returns {Promise<{success: boolean, error?: string, data?: object}>}
 */
async function testHTTPEndpoint(url, timeoutMs = 10000) {
  try {
    const response = await fetchWithTimeout(url, {
      method: 'GET',
      headers: { 'Accept': 'application/json' }
    }, timeoutMs);

    if (!response.ok) {
      return {
        success: false,
        error: `HTTP ${response.status} ${response.statusText}`
      };
    }

    const data = await response.json();
    return { success: true, data };
  } catch (err) {
    return {
      success: false,
      error: `HTTP request failed: ${err.message}`
    };
  }
}

/**
 * Validate instance ports - test all candidates and return first working one
 * @param {object} instance - VastAI instance object
 * @returns {Promise<{success: boolean, connectionUrl?: string, port?: number, error?: string, details?: object}>}
 */
async function validateInstancePorts(instance) {
  const host = instance.public_ipaddr;

  if (!host) {
    return {
      success: false,
      error: 'No public IP address available'
    };
  }

  // Build list of port candidates in priority order
  const portCandidates = [];

  // Priority 1: Direct port 8188
  portCandidates.push({ port: 8188, source: 'direct' });

  // Priority 2: Mapped port 8188/tcp
  if (instance.ports && instance.ports['8188/tcp'] && instance.ports['8188/tcp'].length > 0) {
    const mappedPort = instance.ports['8188/tcp'][0].HostPort;
    if (mappedPort && mappedPort !== 8188) {
      portCandidates.push({ port: mappedPort, source: '8188/tcp mapped' });
    }
  }

  // Priority 3: Fallback port 18188/tcp
  if (instance.ports && instance.ports['18188/tcp'] && instance.ports['18188/tcp'].length > 0) {
    const fallbackPort = instance.ports['18188/tcp'][0].HostPort;
    if (fallbackPort) {
      portCandidates.push({ port: fallbackPort, source: '18188/tcp mapped' });
    }
  }

  if (portCandidates.length === 0) {
    return {
      success: false,
      error: 'No port candidates available for testing'
    };
  }

  const results = [];

  // Test each candidate in order
  for (const candidate of portCandidates) {
    const { port, source } = candidate;
    const connectionUrl = `http://${host}:${port}`;

    console.log(`[PortValidator] Testing ${source}: ${connectionUrl}`);

    // Step 1: TCP connectivity test (fast check)
    const tcpResult = await testTCPConnection(host, port, 5000);
    results.push({ port, source, tcpResult });

    if (!tcpResult.success) {
      console.log(`[PortValidator] TCP test failed for port ${port}: ${tcpResult.error}`);
      continue;
    }

    console.log(`[PortValidator] TCP connection successful to port ${port}`);

    // Step 2: HTTP endpoint validation (ComfyUI API check)
    const httpResult = await testHTTPEndpoint(`${connectionUrl}/system_stats`, 10000);
    results.push({ port, source, httpResult });

    if (!httpResult.success) {
      console.log(`[PortValidator] HTTP test failed for port ${port}: ${httpResult.error}`);
      continue;
    }

    console.log(`[PortValidator] HTTP endpoint validated for port ${port}`);

    // Success! This port is fully accessible
    return {
      success: true,
      connectionUrl,
      port,
      source,
      details: {
        tcpTest: tcpResult,
        httpTest: httpResult,
        tested: results
      }
    };
  }

  // All candidates failed
  const allPortsBlocked = results.every(r => r.tcpResult && !r.tcpResult.success);
  const firewallDetected = allPortsBlocked && results.length >= 2;

  return {
    success: false,
    error: firewallDetected
      ? 'All ports blocked - firewall or network issue detected'
      : 'All port candidates failed validation - service may not be ready',
    details: {
      tested: results,
      firewallDetected,
      portCandidates: portCandidates.map(c => c.port)
    }
  };
}

module.exports = {
  testTCPConnection,
  testHTTPEndpoint,
  validateInstancePorts
};
