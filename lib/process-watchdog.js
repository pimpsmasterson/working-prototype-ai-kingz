/**
 * Process Watchdog - Auto-restart critical daemons on crash
 *
 * Monitors registered processes and automatically restarts them on failure.
 * Features exponential backoff for rapid crashes.
 */

const EventEmitter = require('events');
const { spawn } = require('child_process');

class ProcessWatchdog extends EventEmitter {
  constructor() {
    super();
    this.processes = new Map(); // id -> { config, state }
    this.monitoringInterval = null;
    this.isRunning = false;
    this.healthCheckIntervalMs = 30000; // Check every 30s
  }

  /**
   * Register a process for supervision
   * @param {string} id - Unique identifier for this process
   * @param {object} config - Process configuration
   * @param {string} config.name - Display name
   * @param {string} config.command - Command to execute
   * @param {array} config.args - Command arguments
   * @param {number} config.maxRestarts - Max restarts (-1 = unlimited, default: -1)
   * @param {number} config.restartDelay - Base restart delay in ms (default: 10000)
   * @param {array} config.stdio - stdio configuration (default: ['ignore', 'pipe', 'pipe'])
   */
  register(id, config) {
    if (this.processes.has(id)) {
      console.log(`[Watchdog] Process ${id} already registered, updating config`);
      this.unregister(id);
    }

    const processState = {
      config: {
        name: config.name || id,
        command: config.command,
        args: config.args || [],
        maxRestarts: config.maxRestarts !== undefined ? config.maxRestarts : -1,
        restartDelay: config.restartDelay || 10000,
        stdio: config.stdio || ['ignore', 'pipe', 'pipe']
      },
      state: {
        pid: null,
        process: null,
        status: 'registered', // registered, starting, running, failed, stopped
        restartCount: 0,
        consecutiveCrashes: 0,
        lastStartTime: null,
        lastCrashTime: null,
        lastError: null
      }
    };

    this.processes.set(id, processState);
    console.log(`[Watchdog] Registered process: ${config.name} (${id})`);

    // Start immediately if watchdog is running
    if (this.isRunning) {
      this.startProcess(id);
    }

    this.emit('registered', { id, name: config.name });
  }

  /**
   * Unregister and stop a process
   */
  unregister(id) {
    const entry = this.processes.get(id);
    if (!entry) return;

    console.log(`[Watchdog] Unregistering process: ${entry.config.name} (${id})`);

    // Stop the process if running
    if (entry.state.process) {
      try {
        entry.state.process.kill('SIGTERM');
      } catch (err) {
        console.warn(`[Watchdog] Error killing process ${id}:`, err.message);
      }
    }

    this.processes.delete(id);
    this.emit('unregistered', { id, name: entry.config.name });
  }

  /**
   * Start a specific process
   */
  startProcess(id) {
    const entry = this.processes.get(id);
    if (!entry) {
      console.error(`[Watchdog] Cannot start: process ${id} not registered`);
      return;
    }

    const { config, state } = entry;

    // Check if already running
    if (state.process && !state.process.killed) {
      console.log(`[Watchdog] Process ${config.name} already running (PID: ${state.pid})`);
      return;
    }

    // Check max restarts
    if (config.maxRestarts >= 0 && state.restartCount >= config.maxRestarts) {
      console.error(`[Watchdog] Process ${config.name} exceeded max restarts (${config.maxRestarts})`);
      state.status = 'failed';
      this.emit('process-failed', { id, name: config.name, restartCount: state.restartCount });
      return;
    }

    // Calculate backoff delay if this is a restart
    let delayMs = 0;
    if (state.restartCount > 0) {
      // Exponential backoff based on consecutive crashes
      const backoffFactor = Math.min(state.consecutiveCrashes, 6); // Cap at 64s
      delayMs = Math.min(config.restartDelay * Math.pow(2, backoffFactor), 60000); // Max 60s
    }

    const doStart = () => {
      console.log(`[Watchdog] Starting process: ${config.name} (attempt ${state.restartCount + 1})`);
      state.status = 'starting';
      state.lastStartTime = new Date();

      try {
        const childProcess = spawn(config.command, config.args, {
          detached: false,
          stdio: config.stdio
        });

        state.process = childProcess;
        state.pid = childProcess.pid;
        state.status = 'running';
        state.restartCount++;

        console.log(`[Watchdog] Process ${config.name} started (PID: ${state.pid})`);
        this.emit('process-started', { id, name: config.name, pid: state.pid, restartCount: state.restartCount });

        // Attach event handlers
        childProcess.on('exit', (code, signal) => {
          const now = new Date();
          const runtime = state.lastStartTime ? (now - state.lastStartTime) / 1000 : 0;

          console.log(`[Watchdog] Process ${config.name} exited (code: ${code}, signal: ${signal}, runtime: ${runtime}s)`);

          state.status = 'failed';
          state.lastCrashTime = now;
          state.lastError = `Exit code ${code}, signal ${signal}`;

          // Check if this is a rapid crash (< 60s runtime)
          if (runtime < 60) {
            state.consecutiveCrashes++;
          } else {
            state.consecutiveCrashes = 0; // Reset on stable run
          }

          // Auto-restart if watchdog is running
          if (this.isRunning) {
            console.log(`[Watchdog] Scheduling restart for ${config.name} (consecutive crashes: ${state.consecutiveCrashes})`);
            this.emit('process-restarted', { id, name: config.name, restartCount: state.restartCount, consecutiveCrashes: state.consecutiveCrashes });
            setTimeout(() => this.startProcess(id), 5000); // 5s base delay before calling startProcess (which adds backoff)
          }
        });

        childProcess.on('error', (err) => {
          console.error(`[Watchdog] Process ${config.name} error:`, err.message);
          state.lastError = err.message;
        });

        // Forward stdout/stderr if stdio is piped
        if (config.stdio[1] === 'pipe' && childProcess.stdout) {
          childProcess.stdout.on('data', (data) => {
            this.emit('stdout', { id, name: config.name, data: data.toString() });
          });
        }

        if (config.stdio[2] === 'pipe' && childProcess.stderr) {
          childProcess.stderr.on('data', (data) => {
            this.emit('stderr', { id, name: config.name, data: data.toString() });
          });
        }
      } catch (err) {
        console.error(`[Watchdog] Failed to spawn ${config.name}:`, err.message);
        state.status = 'failed';
        state.lastError = err.message;
        this.emit('process-failed', { id, name: config.name, error: err.message });
      }
    };

    if (delayMs > 0) {
      console.log(`[Watchdog] Delaying restart of ${config.name} by ${delayMs}ms (backoff)`);
      setTimeout(doStart, delayMs);
    } else {
      doStart();
    }
  }

  /**
   * Health check - verify PIDs are still alive
   */
  healthCheck() {
    for (const [id, entry] of this.processes.entries()) {
      const { config, state } = entry;

      if (state.status === 'running' && state.pid) {
        try {
          // Check if process is still alive (signal 0 doesn't kill, just checks)
          process.kill(state.pid, 0);
          // Process is alive
        } catch (err) {
          // Process is dead
          console.warn(`[Watchdog] Health check detected dead process: ${config.name} (PID: ${state.pid})`);
          state.status = 'failed';
          state.lastError = 'Process died unexpectedly';
          state.process = null;

          // Restart if watchdog is running
          if (this.isRunning) {
            this.startProcess(id);
          }
        }
      }
    }
  }

  /**
   * Start watchdog monitoring
   */
  start() {
    if (this.isRunning) {
      console.log('[Watchdog] Already running');
      return;
    }

    console.log('[Watchdog] Starting process supervision');
    this.isRunning = true;

    // Start all registered processes
    for (const id of this.processes.keys()) {
      this.startProcess(id);
    }

    // Start health check monitoring
    this.monitoringInterval = setInterval(() => {
      this.healthCheck();
    }, this.healthCheckIntervalMs);

    this.emit('started');
  }

  /**
   * Stop watchdog monitoring
   */
  stop() {
    if (!this.isRunning) {
      return;
    }

    console.log('[Watchdog] Stopping process supervision');
    this.isRunning = false;

    // Stop health monitoring
    if (this.monitoringInterval) {
      clearInterval(this.monitoringInterval);
      this.monitoringInterval = null;
    }

    // Stop all processes (but don't unregister them)
    for (const [id, entry] of this.processes.entries()) {
      if (entry.state.process) {
        try {
          console.log(`[Watchdog] Stopping ${entry.config.name}`);
          entry.state.process.kill('SIGTERM');
          entry.state.status = 'stopped';
        } catch (err) {
          console.warn(`[Watchdog] Error stopping ${entry.config.name}:`, err.message);
        }
      }
    }

    this.emit('stopped');
  }

  /**
   * Get status of all processes
   */
  getStatus() {
    const status = {};
    for (const [id, entry] of this.processes.entries()) {
      status[id] = {
        name: entry.config.name,
        pid: entry.state.pid,
        status: entry.state.status,
        restartCount: entry.state.restartCount,
        consecutiveCrashes: entry.state.consecutiveCrashes,
        lastStartTime: entry.state.lastStartTime,
        lastCrashTime: entry.state.lastCrashTime,
        lastError: entry.state.lastError
      };
    }
    return status;
  }

  /**
   * Get status of specific process
   */
  getProcessStatus(id) {
    const entry = this.processes.get(id);
    if (!entry) return null;

    return {
      name: entry.config.name,
      pid: entry.state.pid,
      status: entry.state.status,
      restartCount: entry.state.restartCount,
      consecutiveCrashes: entry.state.consecutiveCrashes,
      lastStartTime: entry.state.lastStartTime,
      lastCrashTime: entry.state.lastCrashTime,
      lastError: entry.state.lastError
    };
  }
}

// Export singleton instance
module.exports = new ProcessWatchdog();
