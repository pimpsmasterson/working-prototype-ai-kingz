const path = require('path');
const { spawn } = require('child_process');
const sinon = require('sinon');
const nock = require('nock');
const db = require('../../server/db');

process.env.NODE_ENV = 'test';
// Tests expect smaller ephemeral disk sizes; allow overriding the warm-pool disk
// during tests to avoid filtering out mocked offers. Default to 120GB for tests.
process.env.WARM_POOL_DISK_GB = process.env.WARM_POOL_DISK_GB || '120';

function resetDb() {
  try {
    // Clear audit, usage events, and generated content, and reset warm_pool state row to defaults
    db.db.prepare('DELETE FROM admin_audit').run();
    db.db.prepare('DELETE FROM usage_events').run();
    db.db.prepare('DELETE FROM generated_content').run();
    db.db.prepare("UPDATE warm_pool SET instance = NULL, desiredSize = 1, lastAction = NULL, isPrewarming = 0, safeMode = 0 WHERE id = 1").run();

    // Also reset in-memory warm-pool state (if module loaded in this process)
    try {
      const warmPool = require('../../server/warm-pool');
      // Mutate existing state object to preserve the original module reference
      if (warmPool._internal && warmPool._internal.state) {
        Object.assign(warmPool._internal.state, { desiredSize: 1, instance: null, lastAction: null, isPrewarming: false, safeMode: false });
        // Persist the reset state in DB
        require('../../server/db').saveState(warmPool._internal.state);
      }
    } catch (e) { /* ignore if warm-pool not yet loaded */ }
  } catch (e) {
    // If tables don't exist for some reason, surface error
    throw e;
  }
}

async function startServer(port = 0, env = {}) {
  // Spawn the server as a child process and wait for it to log the ready message
  return new Promise((resolve, reject) => {
    const chosenPort = port || process.env.TEST_PORT || 0;
    const args = ['server/vastai-proxy.js'];
    const p = spawn(process.execPath, args, {
      env: Object.assign({}, process.env, env, { PORT: chosenPort }),
      stdio: ['ignore', 'pipe', 'pipe']
    });

    let stdout = '';
    let stderr = '';
    const readyMsg = 'Vast.ai proxy running on http://localhost:';

    const onData = (d) => {
      stdout += d.toString();
      if (stdout.includes(readyMsg)) {
        // extract the actual port (if not provided)
        const m = stdout.match(/Vast.ai proxy running on http:\/\/localhost:(\d+)\//);
        const actualPort = (m && m[1]) ? Number(m[1]) : chosenPort;
        cleanupListeners();
        resolve({ proc: p, port: actualPort });
      }
    };
    const onErr = (d) => { stderr += d.toString(); };
    const onExit = (code) => { cleanupListeners(); reject(new Error('Server exited early with code ' + code + '\n' + stderr)); };

    function cleanupListeners() {
      p.stdout.removeListener('data', onData);
      p.stderr.removeListener('data', onErr);
      p.removeListener('exit', onExit);
    }

    p.stdout.on('data', onData);
    p.stderr.on('data', onErr);
    p.on('exit', onExit);
  });
}

async function stopServer(proc) {
  if (!proc || !proc.kill) return;
  return new Promise((resolve) => {
    proc.once('exit', () => resolve());
    proc.kill();
    // Fallback resolve after timeout
    setTimeout(resolve, 2000);
  });
}

function requireWarmPoolWithClock() {
  // Install fake timers before requiring the module so intervals are deterministic
  const clock = sinon.useFakeTimers({ now: Date.now() });
  // Clear require cache for deterministic reloads
  delete require.cache[require.resolve('../../server/warm-pool')];
  const warmPool = require('../../server/warm-pool');
  return { clock, warmPool, restore: () => clock.restore() };
}

function reloadWarmPoolWithEnv(env = {}) {
  // Merge env updates and re-require the module so module-scoped constants are refreshed
  Object.assign(process.env, env);
  delete require.cache[require.resolve('../../server/warm-pool')];
  return require('../../server/warm-pool');
}

function nockCleanAll() {
  nock.cleanAll();
  nock.enableNetConnect('127.0.0.1');
}

module.exports = { resetDb, startServer, stopServer, requireWarmPoolWithClock, reloadWarmPoolWithEnv, nock, nockCleanAll };
