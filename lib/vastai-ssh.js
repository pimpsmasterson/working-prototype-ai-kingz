const fs = require('fs');
const path = require('path');
const fetch = require('node-fetch');
const crypto = require('crypto');

const VAST_BASE = process.env.VASTAI_BASE_URL || 'https://console.vast.ai/api/v0';

// Prefer environment key, then file on disk, fallback to embedded repo key (the one generated for this session)
const DEFAULT_KEY_REPRO = 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDNKygrGeKHZRpSqTkdaP3btkpDPzyrP57j8iqh1KA6thiw3WAVJd2BS0Sd0WAeF1LuMqGEHEU2+5S5IneL11aqSHTGYf/AyjS4lTaj5maxq11fEaYNHjRiaU8lfA4fq0gWQpgrX5sOfI2Ikjo8ZKLh4UFtFQO2b+1uAKfTTxS5oh4AfVX/4mkLTyquZDjl5v9fVAX10Ecc+HELO1582t3XtKljJjC9Jd3M1foHLTVpQ7Xj7o1QpEGCVYBurwkWwhSdpks+82RNLlE7CzhPHmtlLykwFsK650dDc8uYWbIXM5cI7Jn4q8YO8018ggX0uyzNzrr7F7MEjTjlSLSLcJ03SYqXty5EAJPDPGtZaj9j5DGHNKa83l7XF/BDcJiGzCtowoMvNNUGTgcTG78Bm6E+x94ADsS597Yumde7oWIwYBZGYeciNnr9MWUj3S6smidMRyU3i57SpWNw6wJz8zcLuaiKtTU3/AQFcUISl0bjzKtqyEYULxdmcG/In0VQMrYmGl9ZldB4fB0YVVSijQGzukghn7CpomhRsT1llXHB4nyPlx8kvAMQKNHT+NcnoSox4qgjtsgTDz6NBIF0T7b49AdKStTTsJTXfheD60E3A3Vw3/J1QDV8ToW4zuzrFm8cdTKCBFiCNtUiB2oYyNykvPWNW571YOWW1MMWT4kJpw== vast-ai-comfyui';

function getKey() {
    if (process.env.VASTAI_SSH_KEY) return process.env.VASTAI_SSH_KEY;
    
    // Check for the generated key file
    const home = process.env.HOME || process.env.USERPROFILE || '';
    const keyPath = path.join(home, '.ssh', 'id_rsa_vast.pub');
    if (fs.existsSync(keyPath)) {
        try {
            return fs.readFileSync(keyPath, 'utf8').trim();
        } catch (e) {}
    }
    
    return DEFAULT_KEY_REPRO;
}

async function registerKey(apiKey) {
    if (!apiKey) {
        // nothing to do
        return false;
    }

    try {
        const res = await fetch(`${VAST_BASE}/ssh/`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${apiKey}`
            },
            body: JSON.stringify({ ssh_key: getKey() })
        });

        let j = null;
        try { j = await res.json(); } catch (e) { j = null; }

        if (res.ok) {
            console.log('vastai-ssh: SSH key registered');
            return true;
        }

        const msg = j ? JSON.stringify(j) : `status ${res.status}`;
        if (String(msg).toLowerCase().includes('already exists') || String(msg).toLowerCase().includes('already')) {
            console.log('vastai-ssh: SSH key already present');
            return true;
        }

        console.warn('vastai-ssh: failed to register key:', msg);
        return false;
    } catch (e) {
        console.error('vastai-ssh: error registering key:', e && e.message ? e.message : e);
        return false;
    }
}

/**
 * Get SSH public key fingerprint for debugging
 * @param {string} publicKey - SSH public key string
 * @returns {string} SHA256 fingerprint
 */
function getKeyFingerprint(publicKey) {
    try {
        // Extract base64 part from SSH public key (format: "ssh-rsa AAAAB... comment")
        const parts = publicKey.trim().split(' ');
        if (parts.length < 2) return 'invalid-key-format';

        const base64Key = parts[1];
        const binaryKey = Buffer.from(base64Key, 'base64');

        // Generate SHA256 fingerprint
        const hash = crypto.createHash('sha256').update(binaryKey).digest();
        const fingerprint = hash.toString('base64').replace(/=+$/, '');

        return `SHA256:${fingerprint}`;
    } catch (err) {
        return `error: ${err.message}`;
    }
}

/**
 * Validate SSH key registration with Vast.ai
 * @param {string} apiKey - Vast.ai API key
 * @returns {Promise<boolean>} true if key is registered
 */
async function validateKeyRegistration(apiKey) {
    if (!apiKey) {
        console.warn('vastai-ssh: No API key provided for validation');
        return false;
    }

    try {
        const publicKey = getKey();
        const fingerprint = getKeyFingerprint(publicKey);

        console.log(`vastai-ssh: Validating SSH key registration`);
        console.log(`vastai-ssh: Key fingerprint: ${fingerprint}`);

        // Fetch registered SSH keys from Vast.ai
        const res = await fetch(`${VAST_BASE}/ssh/`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${apiKey}`
            }
        });

        if (!res.ok) {
            console.warn(`vastai-ssh: Failed to fetch SSH keys (HTTP ${res.status})`);
            return false;
        }

        const keys = await res.json();

        // Check if our key is in the list
        if (Array.isArray(keys)) {
            const ourFingerprint = fingerprint.replace('SHA256:', '');
            const isRegistered = keys.some(k => {
                const keyFp = getKeyFingerprint(k.ssh_key || '').replace('SHA256:', '');
                return keyFp === ourFingerprint;
            });

            if (isRegistered) {
                console.log('vastai-ssh: ✅ SSH key is registered');
                return true;
            } else {
                console.warn('vastai-ssh: ⚠️  SSH key NOT found in registered keys');
                console.warn('vastai-ssh: This may cause authentication failures on instances');
                return false;
            }
        }

        return false;
    } catch (err) {
        console.error('vastai-ssh: Error validating key registration:', err.message);
        return false;
    }
}

module.exports = { getKey, registerKey, getKeyFingerprint, validateKeyRegistration };
