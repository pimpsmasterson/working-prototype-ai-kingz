#!/usr/bin/env node
const fs = require('fs');
const os = require('os');
const path = require('path');

const vastai = require('../lib/vastai-ssh');

const PUBLIC_KEY = process.env.PUBLIC_KEY || null;

// Let library determine the correct key path and generate key if necessary
let keyPath;
try {
  keyPath = process.env.VASTAI_SSH_KEY_PATH || vastai.getKey();
} catch (err) {
  console.error('Failed to determine or generate SSH key path:', err.message);
  process.exit(3);
}

const pubPath = keyPath + '.pub';

if (PUBLIC_KEY) {
  fs.writeFileSync(pubPath, PUBLIC_KEY.trim() + '\n', { mode: 0o600, encoding: 'utf8' });
  console.log('Wrote public key to', pubPath);
} else if (!fs.existsSync(pubPath)) {
  console.error('No public key provided and', pubPath, 'not found. Set PUBLIC_KEY env var, set VASTAI_SSH_KEY_PATH, or create the file.');
  process.exit(1);
} else {
  console.log('Using existing public key at', pubPath);
}

const apiKey = process.env.VASTAI_API_KEY || null;

vastai.registerKey(apiKey).then(ok => {
  if (ok) {
    console.log('SSH key registered (or already present)');
    process.exit(0);
  } else {
    if (!apiKey) {
      console.warn('No VASTAI_API_KEY provided; public key written locally at', pubPath);
      process.exit(0);
    }
    console.error('Failed to register SSH key');
    process.exit(2);
  }
}).catch(err => {
  console.error('Error registering SSH key:', err);
  process.exit(3);
});
