#!/usr/bin/env node
/**
 * Provision Log Collector Daemon
 *
 * Polls remote provision logs via SSH and streams them to local filesystem.
 * Survives SSH disconnects with retry logic.
 *
 * Usage:
 *   node collect_provision_logs.js \
 *     --host ssh3.vast.ai \
 *     --port 14842 \
 *     --key ~/.ssh/vast_ai_key \
 *     --contract-id 12345 \
 *     --output ./logs/provision_12345_1234567890.log \
 *     --timeout 3600
 */

const { Client } = require('ssh2');
const fs = require('fs');
const path = require('path');

// Parse command line arguments
const args = process.argv.slice(2);
const config = {
  host: null,
  port: 22,
  key: null,
  contractId: null,
  output: null,
  timeout: 3600,  // 1 hour default
  pollInterval: 30,  // 30 seconds
  remoteLogPath: '/workspace/provision_v3.log'
};

for (let i = 0; i < args.length; i += 2) {
  const key = args[i].replace(/^--/, '');
  const value = args[i + 1];

  if (key === 'port' || key === 'timeout' || key === 'poll-interval') {
    config[key.replace(/-([a-z])/g, (m, p1) => p1.toUpperCase())] = parseInt(value, 10);
  } else {
    config[key.replace(/-([a-z])/g, (m, p1) => p1.toUpperCase())] = value;
  }
}

// Validate required arguments
if (!config.host || !config.key || !config.output) {
  console.error('Error: Missing required arguments');
  console.error('Required: --host, --key, --output');
  console.error('Optional: --port (default: 22), --timeout (default: 3600), --contract-id');
  process.exit(1);
}

// Ensure output directory exists
const outputDir = path.dirname(config.output);
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

// Initialize local log file
fs.writeFileSync(config.output, `# Provision Log Collection Started: ${new Date().toISOString()}\n` +
  `# Remote: ${config.host}:${config.port}\n` +
  `# Contract ID: ${config.contractId || 'N/A'}\n` +
  `# Remote log: ${config.remoteLogPath}\n` +
  `${'='.repeat(80)}\n\n`, { flag: 'w' });

console.log(`[LogCollector] Starting log collection from ${config.host}:${config.port}`);
console.log(`[LogCollector] Output: ${config.output}`);
console.log(`[LogCollector] Timeout: ${config.timeout}s, Poll interval: ${config.pollInterval}s`);

// State tracking
let lastLineCount = 0;
let pollAttempts = 0;
let consecutiveFailures = 0;
let isComplete = false;
let startTime = Date.now();
let pollTimer = null;

// SSH connection pooling
let sshClient = null;

// Completion markers to detect provisioning end
const COMPLETION_MARKERS = [
  '✅ ComfyUI setup complete',
  '✅ PROVISIONING COMPLETE',
  'ComfyUI started successfully',
  'FATAL:',
  'CRITICAL ERROR:',
  'Provisioning failed'
];

const ERROR_MARKERS = [
  'FATAL:',
  'CRITICAL ERROR:',
  'Provisioning failed',
  'Connection refused',
  'No space left on device'
];

/**
 * Read SSH private key with error handling
 */
function readSSHKey() {
  try {
    const keyPath = config.key.replace(/^~/, process.env.HOME || process.env.USERPROFILE);
    return fs.readFileSync(keyPath, 'utf8');
  } catch (err) {
    console.error(`[LogCollector] Error reading SSH key: ${err.message}`);
    process.exit(1);
  }
}

const privateKey = readSSHKey();

/**
 * Execute SSH command with timeout and error handling
 */
function execSSHCommand(command, timeoutMs = 30000) {
  return new Promise((resolve, reject) => {
    if (!sshClient || !sshClient._sock || sshClient._sock.destroyed) {
      // Re-establish connection
      sshClient = new Client();

      const connTimeout = setTimeout(() => {
        reject(new Error('SSH connection timeout'));
        sshClient.end();
      }, timeoutMs);

      sshClient
        .on('ready', () => {
          clearTimeout(connTimeout);
          executeCommand();
        })
        .on('error', (err) => {
          clearTimeout(connTimeout);
          reject(err);
        })
        .connect({
          host: config.host,
          port: config.port,
          username: 'root',
          privateKey: privateKey,
          readyTimeout: parseInt(process.env.SSH_READY_TIMEOUT_MS || '30000', 10),
          keepaliveInterval: parseInt(process.env.SSH_KEEPALIVE_INTERVAL_MS || '10000', 10),
          keepaliveCountMax: parseInt(process.env.SSH_KEEPALIVE_MAX_MISS || '3', 10),
          algorithms: {
            // Use modern, fast cipher suites
            cipher: ['aes128-gcm@openssh.com', 'aes128-ctr'],
            serverHostKey: ['ssh-ed25519', 'ecdsa-sha2-nistp256']
          }
        });
    } else {
      executeCommand();
    }

    function executeCommand() {
      const cmdTimeout = setTimeout(() => {
        reject(new Error('Command execution timeout'));
      }, timeoutMs);

      sshClient.exec(command, (err, stream) => {
        if (err) {
          clearTimeout(cmdTimeout);
          return reject(err);
        }

        let stdout = '';
        let stderr = '';

        stream
          .on('close', (code, signal) => {
            clearTimeout(cmdTimeout);
            if (code !== 0) {
              reject(new Error(`Command failed with exit code ${code}: ${stderr}`));
            } else {
              resolve(stdout);
            }
          })
          .on('data', (data) => {
            stdout += data.toString();
          })
          .stderr.on('data', (data) => {
            stderr += data.toString();
          });
      });
    }
  });
}

/**
 * Proactive SSH health monitoring - sends keepalive commands
 */
let healthCheckInterval = null;

function startSSHHealthMonitoring() {
  if (healthCheckInterval) return;

  healthCheckInterval = setInterval(async () => {
    // Check if connection is dead
    if (!sshClient || !sshClient._sock || sshClient._sock.destroyed) {
      console.log('[LogCollector] Dead SSH connection detected, will reconnect on next poll');
      sshClient = null;
      return;
    }

    // Send lightweight keepalive command
    try {
      await execSSHCommand('echo "keepalive"', 5000);
      if (consecutiveFailures > 0) {
        console.log('[LogCollector] SSH health check passed, connection restored');
        consecutiveFailures = 0;
      }
    } catch (err) {
      console.warn('[LogCollector] SSH health check failed:', err.message);
      sshClient = null; // Force reconnect
    }
  }, 30000); // Every 30 seconds
}

function stopSSHHealthMonitoring() {
  if (healthCheckInterval) {
    clearInterval(healthCheckInterval);
    healthCheckInterval = null;
  }
}

/**
 * Poll remote log file and append new lines to local file
 */
async function pollLogs() {
  pollAttempts++;

  // Check timeout
  const elapsed = (Date.now() - startTime) / 1000;
  if (elapsed > config.timeout) {
    console.log(`[LogCollector] Timeout reached (${config.timeout}s), terminating`);
    await appendToLocalLog(`\n${'='.repeat(80)}\n# Log collection TIMEOUT after ${config.timeout}s\n`);
    cleanup(124);  // Timeout exit code
    return;
  }

  try {
    // Get current line count of remote log
    const wcOutput = await execSSHCommand(`wc -l ${config.remoteLogPath} 2>/dev/null || echo "0 ${config.remoteLogPath}"`, 10000);
    const currentLineCount = parseInt(wcOutput.trim().split(/\s+/)[0], 10);

    if (isNaN(currentLineCount)) {
      console.warn(`[LogCollector] Could not parse line count, retrying...`);
      scheduleNextPoll(consecutiveFailures);
      return;
    }

    // If new lines available, fetch them
    if (currentLineCount > lastLineCount) {
      const linesToFetch = currentLineCount - lastLineCount;
      console.log(`[LogCollector] Fetching ${linesToFetch} new lines (${lastLineCount} -> ${currentLineCount})`);

      // Fetch new lines using tail
      const startLine = lastLineCount + 1;
      const newLines = await execSSHCommand(`tail -n +${startLine} ${config.remoteLogPath} 2>/dev/null`, 30000);

      if (newLines) {
        await appendToLocalLog(newLines);
        lastLineCount = currentLineCount;

        // Check for completion markers
        const linesArray = newLines.split('\n');
        for (const line of linesArray) {
          for (const marker of COMPLETION_MARKERS) {
            if (line.includes(marker)) {
              console.log(`[LogCollector] Detected completion marker: "${marker}"`);

              // Check if it's an error marker
              const isError = ERROR_MARKERS.some(em => line.includes(em));
              isComplete = true;

              await appendToLocalLog(`\n${'='.repeat(80)}\n# Log collection COMPLETE: ${marker}\n`);
              cleanup(isError ? 1 : 0);
              return;
            }
          }
        }
      }

      consecutiveFailures = 0;  // Reset on success
    } else if (currentLineCount === lastLineCount) {
      console.log(`[LogCollector] No new lines (${currentLineCount}), waiting...`);
    } else {
      // Line count decreased - log file might have been rotated
      console.warn(`[LogCollector] Line count decreased (${lastLineCount} -> ${currentLineCount}), log file may have been rotated`);
      lastLineCount = 0;  // Reset and re-fetch
    }

    consecutiveFailures = 0;
    scheduleNextPoll(0);

  } catch (error) {
    consecutiveFailures++;
    console.error(`[LogCollector] Poll failed (attempt ${consecutiveFailures}): ${error.message}`);

    // Apply exponential backoff on repeated failures, but NEVER permanently give up
    const maxFailures = parseInt(process.env.SSH_MAX_CONSECUTIVE_FAILURES || '999999', 10);
    if (consecutiveFailures >= maxFailures) {
      // Apply exponential backoff but continue trying
      const backoffMs = Math.min(Math.pow(2, Math.min(consecutiveFailures - maxFailures, 10)) * 1000, 300000);
      console.warn(`[LogCollector] ${consecutiveFailures} consecutive failures, backing off ${backoffMs/1000}s before retry`);
      await new Promise(r => setTimeout(r, backoffMs));
      // Reset counter to maxFailures to apply backoff repeatedly without overflow
      consecutiveFailures = maxFailures;
    }

    scheduleNextPoll(consecutiveFailures);
  }
}

/**
 * Append content to local log file
 */
async function appendToLocalLog(content) {
  return new Promise((resolve, reject) => {
    fs.appendFile(config.output, content, (err) => {
      if (err) {
        console.error(`[LogCollector] Error writing to local log: ${err.message}`);
        reject(err);
      } else {
        resolve();
      }
    });
  });
}

/**
 * Schedule next poll with exponential backoff on failures
 */
function scheduleNextPoll(failureCount) {
  if (isComplete) return;

  const baseInterval = config.pollInterval * 1000;  // Convert to ms
  const backoff = Math.min(Math.pow(2, failureCount) * 1000, 60000);  // Max 60s backoff
  const nextPollDelay = baseInterval + backoff;

  console.log(`[LogCollector] Next poll in ${nextPollDelay / 1000}s`);

  if (pollTimer) clearTimeout(pollTimer);
  pollTimer = setTimeout(pollLogs, nextPollDelay);
}

/**
 * Cleanup and exit
 */
function cleanup(exitCode = 0) {
  stopSSHHealthMonitoring();

  if (pollTimer) {
    clearTimeout(pollTimer);
    pollTimer = null;
  }

  if (sshClient) {
    sshClient.end();
    sshClient = null;
  }

  console.log(`[LogCollector] Exiting with code ${exitCode}`);
  console.log(`[LogCollector] Total poll attempts: ${pollAttempts}`);
  console.log(`[LogCollector] Total lines collected: ${lastLineCount}`);
  console.log(`[LogCollector] Local log: ${config.output}`);

  process.exit(exitCode);
}

// Handle process signals
process.on('SIGINT', () => {
  console.log('\n[LogCollector] Received SIGINT, shutting down...');
  cleanup(130);
});

process.on('SIGTERM', () => {
  console.log('\n[LogCollector] Received SIGTERM, shutting down...');
  cleanup(143);
});

// Start polling and health monitoring
console.log('[LogCollector] Starting first poll...');
console.log('[LogCollector] Starting SSH health monitoring (30s interval)...');
startSSHHealthMonitoring();
pollLogs();
