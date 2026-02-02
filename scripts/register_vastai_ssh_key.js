#!/usr/bin/env node
const fs = require('fs');
const os = require('os');
const path = require('path');

const vastai = require('../lib/vastai-ssh');

const PUBLIC_KEY = process.env.PUBLIC_KEY || null;
const home = process.env.HOME || process.env.USERPROFILE || os.homedir();
const sshDir = path.join(home, '.ssh');
const pubPath = path.join(sshDir, 'id_rsa_vast.pub');

if (!fs.existsSync(sshDir)) {
  fs.mkdirSync(sshDir, { recursive: true, mode: 0o700 });
}

if (PUBLIC_KEY) {
  fs.writeFileSync(pubPath, PUBLIC_KEY.trim() + '\n', { mode: 0o600, encoding: 'utf8' });
  console.log('Wrote public key to', pubPath);
} else if (!fs.existsSync(pubPath)) {
  console.error('No public key provided and', pubPath, 'not found. Set PUBLIC_KEY env var or create the file.');
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
    console.error('Failed to register SSH key');
    process.exit(2);
  }
}).catch(err => {
  console.error('Error registering SSH key:', err);
  process.exit(3);
});
