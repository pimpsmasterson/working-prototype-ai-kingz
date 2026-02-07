#!/usr/bin/env node
/**
 * Push scripts/provision-reliable.sh to the GitHub Gist used by COMFYUI_PROVISION_SCRIPT.
 * Uses GITHUB_TOKEN from .env. Gist ID is from .env.example / docs (pimpsmasterson/c3f61f20067d498b6699d1bdbddea395).
 * No random files: reads only scripts/provision-reliable.sh and updates the existing gist.
 */
const path = require('path');
const fs = require('fs');
const fetch = require('node-fetch');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const GIST_ID = '3a4b637b117355b429a29e80acc72a1d';
const PROVISION_PATH = path.join(__dirname, 'provision-image-only.sh');
const GIST_API = `https://api.github.com/gists/${GIST_ID}`;

async function main() {
  const token = process.env.GITHUB_TOKEN || process.env.GH_TOKEN || process.env.NEED_KEY;
  if (!token) {
    console.error('Missing GITHUB_TOKEN, GH_TOKEN, or NEED_KEY in .env. Add a GitHub personal access token with gist scope.');
    process.exit(1);
  }

  if (!fs.existsSync(PROVISION_PATH)) {
    console.error('Provision script not found:', PROVISION_PATH);
    process.exit(1);
  }

  const content = fs.readFileSync(PROVISION_PATH, 'utf8');
  const payload = {
    description: 'AI Kings ComfyUI Image Only Provisioner (provision-image-only.sh)',
    files: {
      'provision-image-only.sh': { content }
    }
  };

  // GitHub REST API: use Bearer (required for fine-grained PATs), Accept, and API version
  const res = await fetch(GIST_API, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token.trim()}`,
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(payload)
  });

  if (!res.ok) {
    const text = await res.text();
    console.error('Gist update failed:', res.status, res.statusText, text);
    process.exit(1);
  }

  const data = await res.json();
  console.log('Gist updated successfully.');
  console.log('Raw URL (use in COMFYUI_PROVISION_SCRIPT):', data.files['provision-reliable.sh']?.raw_url || 'https://gist.githubusercontent.com/pimpsmasterson/' + GIST_ID + '/raw');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
