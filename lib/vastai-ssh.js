const fs = require('fs');
const path = require('path');
const os = require('os');
const fetch = require('node-fetch');
const crypto = require('crypto');

const VAST_BASE = 'https://console.vast.ai/api/v0';

/**
 * Get or create SSH key for Vast.ai
 */
function getKey() {
  const home = process.env.HOME || process.env.USERPROFILE || os.homedir();
  const sshDir = path.join(home, '.ssh');
  const keyPath = process.env.VASTAI_SSH_KEY_PATH || path.join(sshDir, 'id_vast');
  const pubPath = keyPath + '.pub';

  // Ensure SSH directory exists
  if (!fs.existsSync(sshDir)) {
    fs.mkdirSync(sshDir, { recursive: true });
  }

  // Generate key if it doesn't exist
  if (!fs.existsSync(keyPath) || !fs.existsSync(pubPath)) {
    console.log('🔄 Generating new SSH key for Vast.ai (using ssh-keygen)...');

    const { execSync } = require('child_process');
    try {
      // Allow overriding key type via env var; default to ed25519 for modern, compact keys
      const keyType = process.env.VASTAI_SSH_KEY_TYPE || 'ed25519';
      let cmd;
      if (keyType === 'ed25519') {
        cmd = `ssh-keygen -t ed25519 -f "${keyPath}" -N "" -C "ai-kings-vastai"`;
      } else if (keyType === 'rsa') {
        const bits = process.env.VASTAI_SSH_KEY_BITS || 4096;
        cmd = `ssh-keygen -t rsa -b ${bits} -f "${keyPath}" -N "" -C "ai-kings-vastai"`;
      } else {
        throw new Error(`Unsupported VASTAI_SSH_KEY_TYPE: ${keyType}`);
      }

      // Use ssh-keygen for proper OpenSSH format
      execSync(cmd, { stdio: 'inherit' });
      console.log('✅ SSH key created:', keyPath);

      // Set sensible permissions for private key
      if (process.platform === 'win32') {
        try {
          // Restrict permissions to current user on Windows
          const user = process.env.USERDOMAIN && process.env.USERNAME ? `${process.env.USERDOMAIN}\\${process.env.USERNAME}` : process.env.USERNAME;
          execSync(`icacls "${keyPath}" /inheritance:r /grant:r "${user}:R"`, { stdio: 'inherit' });
          console.log('✅ Set Windows ACLs on private key');
        } catch (e) {
          console.warn('⚠️  Failed to adjust Windows ACLs for key:', e.message);
        }
      } else {
        try {
          fs.chmodSync(keyPath, 0o600);
          fs.chmodSync(pubPath, 0o644);
        } catch (e) {
          console.warn('⚠️  Failed to chmod key files:', e.message);
        }
      }

    } catch (err) {
      console.error('❌ Failed to generate SSH key with ssh-keygen:', err.message);
      // Fallback is intentionally omitted to avoid registering junk keys
      throw err;
    }
  }

  return keyPath;
}

/**
 * Register SSH key with Vast.ai account
 */
async function registerKey(apiKey) {
  if (!apiKey) {
    console.warn('⚠️  No VASTAI_API_KEY provided, skipping SSH key registration');
    return false;
  }

  const keyPath = getKey();
  const pubPath = keyPath + '.pub';

  try {
    const publicKeyContent = fs.readFileSync(pubPath, 'utf8');
    const fingerprint = crypto.createHash('sha256').update(publicKeyContent.trim()).digest('hex').substring(0, 16);

    // Check if key already exists
    try {
      const existingKeysRaw = await fetch(`${VAST_BASE}/ssh/`, {
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json'
        }
      }).then(r => r.json());

      // Normalize response to an array of key objects (defensive)
      let existingKeys = [];
      if (Array.isArray(existingKeysRaw)) {
        existingKeys = existingKeysRaw;
      } else if (existingKeysRaw && Array.isArray(existingKeysRaw.results)) {
        existingKeys = existingKeysRaw.results;
      } else if (existingKeysRaw && Array.isArray(existingKeysRaw.keys)) {
        existingKeys = existingKeysRaw.keys;
      }

      const pubTrim = publicKeyContent.trim();
      const exists = existingKeys.some(k => {
        if (!k) return false;
        // Some API responses may include 'key' or 'public_key' properties
        const keyText = k.key || k.public_key || '';
        if (!keyText) return false;
        if (keyText.includes(pubTrim)) return true; // exact key match
        // Fallback: check any stored fingerprint field
        if (k.fingerprint && String(k.fingerprint).includes(fingerprint)) return true;
        return false;
      });

      if (exists) {
        console.log('✅ SSH key already registered with Vast.ai');
        return true;
      }
    } catch (checkErr) {
      console.warn('⚠️  Could not check existing keys, proceeding with upload', checkErr && checkErr.message ? checkErr.message : String(checkErr));
    }

    // Register new key (Vast.ai API expects 'ssh_key' field)
    const response = await fetch(`${VAST_BASE}/ssh/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        ssh_key: publicKeyContent.trim()
      })
    });

    if (response.ok) {
      console.log('✅ SSH key successfully registered with Vast.ai');
      return true;
    } else {
      const errorText = await response.text();
      if (errorText.includes('already exists') || errorText.includes('duplicate')) {
        console.log('✅ SSH key already registered (duplicate check passed)');
        return true;
      }
      throw new Error(`SSH key registration failed: ${errorText}`);
    }

  } catch (err) {
    console.error('❌ Failed to register SSH key:', err.message);
    throw err;
  }
}

/**
 * Get SSH connection string for an instance
 */
function getConnectionString(instance) {
  const sshHost = instance.ssh_host || instance.host;
  const sshPort = instance.ssh_port || instance.machine_ssh_port || 22;
  const keyPath = getKey();

  if (!sshHost || !sshPort) {
    throw new Error('Missing SSH connection details for instance');
  }

  return {
    sshArgs: [
      '-o', 'StrictHostKeyChecking=no',
      '-o', 'ConnectTimeout=10',
      '-o', 'UserKnownHostsFile=/dev/null',
      '-p', String(sshPort),
      '-i', keyPath
    ],
    sshHost: `root@${sshHost}`,
    connectionString: `ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o UserKnownHostsFile=/dev/null -p ${sshPort} -i "${keyPath}" root@${sshHost}`
  };
}

/**
 * Execute command via SSH on instance (utility function)
 */
async function sshExec(instance, command, timeoutMs = 30000) {
  const { exec } = require('child_process');
  const connectionInfo = getConnectionString(instance);
  const args = connectionInfo.sshArgs.concat([connectionInfo.sshHost, command]);

  return new Promise((resolve, reject) => {
    const fullCommand = `ssh ${args.map(a => a.includes(' ') ? `"${a}"` : a).join(' ')}`;

    exec(fullCommand, { timeout: timeoutMs }, (error, stdout, stderr) => {
      if (error) {
        reject(Object.assign(error, { stdout, stderr }));
      } else {
        resolve({ stdout, stderr });
      }
    });
  });
}

/**
 * Test SSH connectivity to instance
 */
async function testConnection(instance, timeoutMs = 10000) {
  try {
    const result = await sshExec(instance, 'echo "SSH_TEST_OK"', timeoutMs);
    return result.stdout.trim() === 'SSH_TEST_OK';
  } catch (err) {
    console.warn('SSH connection test failed:', err.message);
    return false;
  }
}

module.exports = {
  getKey,
  registerKey,
  getConnectionString,
  sshExec,
  testConnection
};