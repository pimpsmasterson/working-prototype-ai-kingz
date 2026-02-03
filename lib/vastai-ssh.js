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
  const keyPath = process.env.VASTAI_SSH_KEY_PATH || path.join(sshDir, 'id_rsa_vast');
  const pubPath = keyPath + '.pub';

  // Ensure SSH directory exists with proper permissions
  if (!fs.existsSync(sshDir)) {
    fs.mkdirSync(sshDir, { recursive: true, mode: 0o700 });
  }

  // Generate key if it doesn't exist
  if (!fs.existsSync(keyPath) || !fs.existsSync(pubPath)) {
    console.log('🔄 Creating new SSH key for Vast.ai...');
    const { generateKeyPairSync } = require('crypto');
    
    try {
      const { publicKey, privateKey } = generateKeyPairSync('rsa', {
        modulusLength: 4096,
        publicKeyEncoding: {
          type: 'spki',
          format: 'pem'
        },
        privateKeyEncoding: {
          type: 'pkcs8',
          format: 'pem'
        }
      });

      // Convert to OpenSSH format
      const openSshPublicKey = `ssh-rsa ${publicKey.trim().split('\n')[1]}`;
      
      fs.writeFileSync(keyPath, privateKey, { mode: 0o600 });
      fs.writeFileSync(pubPath, openSshPublicKey, { mode: 0o644 });
      
      console.log('✅ SSH key created:', keyPath);
    } catch (err) {
      console.error('❌ Failed to generate SSH key:', err);
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
      const existingKeys = await fetch(`${VAST_BASE}/ssh/`, {
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json'
        }
      }).then(r => r.json());

      const exists = existingKeys.some(key => key.key.includes(fingerprint));
      if (exists) {
        console.log('✅ SSH key already registered with Vast.ai');
        return true;
      }
    } catch (checkErr) {
      console.warn('⚠️  Could not check existing keys, proceeding with upload', checkErr.message);
    }

    // Register new key
    const response = await fetch(`${VAST_BASE}/ssh/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        name: `ssh_key_${Date.now()}`,
        key: publicKeyContent.trim()
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