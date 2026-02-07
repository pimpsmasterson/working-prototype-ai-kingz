const path = require('path');
// Load .env from project root (explicit path - cwd may vary when PM2 loads this)
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

// Canonical provision script: gist 3a4b637b117355b429a29e80acc72a1d (v5.2 image provisioner, file: gistfile1.txt) - used when .env has no COMFYUI_PROVISION_SCRIPT
const PROVISION_SCRIPT = 'https://gist.githubusercontent.com/pimpsmasterson/3a4b637b117355b429a29e80acc72a1d/raw/gistfile1.txt';

module.exports = {
  apps: [{
    name: 'vastai-proxy',
    script: 'server/vastai-proxy.js',
    cwd: './',
    env: {
      NODE_ENV: 'development',
      ADMIN_API_KEY: process.env.ADMIN_API_KEY || 'secure_admin_key_change_me',
      VASTAI_API_KEY: process.env.VASTAI_API_KEY,
      HUGGINGFACE_HUB_TOKEN: process.env.HUGGINGFACE_HUB_TOKEN,
      CIVITAI_TOKEN: process.env.CIVITAI_TOKEN,
      AUDIT_SALT: process.env.AUDIT_SALT,
      SCRIPTS_BASE_URL: process.env.SCRIPTS_BASE_URL,
      COMFYUI_PROVISION_SCRIPT: PROVISION_SCRIPT,
      PORT: process.env.PORT || '3000',
      WARM_POOL_SAFE_MODE: process.env.WARM_POOL_SAFE_MODE || '0',
      WARM_POOL_IDLE_MINUTES: process.env.WARM_POOL_IDLE_MINUTES || '15',
      WARM_POOL_DISK_GB: process.env.WARM_POOL_DISK_GB || '600',
      COMFYUI_TUNNEL_URL: process.env.COMFYUI_TUNNEL_URL || 'http://localhost:8188',
      VASTAI_MIN_INET_DOWN: process.env.VASTAI_MIN_INET_DOWN || '500',
      VASTAI_MIN_GPU_RAM_MB: process.env.VASTAI_MIN_GPU_RAM_MB || '12288'
    },
    env_production: {
      NODE_ENV: 'production'
    }
  }]
};
