require('dotenv').config();

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
      COMFYUI_PROVISION_SCRIPT: process.env.COMFYUI_PROVISION_SCRIPT,
      PORT: process.env.PORT || '3000',
      WARM_POOL_SAFE_MODE: process.env.WARM_POOL_SAFE_MODE || '0',
      WARM_POOL_IDLE_MINUTES: process.env.WARM_POOL_IDLE_MINUTES || '15',
      COMFYUI_TUNNEL_URL: process.env.COMFYUI_TUNNEL_URL || 'http://localhost:8188'
    },
    env_production: {
      NODE_ENV: 'production'
    }
  }]
};
