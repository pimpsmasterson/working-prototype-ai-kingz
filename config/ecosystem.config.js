module.exports = {
  apps: [{
    name: 'vastai-proxy',
    script: 'server/vastai-proxy.js',
    cwd: './',
    env: {
      NODE_ENV: 'development',
      // Development defaults - copy sensitive values into a .env for production
        ADMIN_API_KEY: process.env.ADMIN_API_KEY || 'secure_admin_key_change_me',
        // NOTE: For local demo only - use a real Vast.ai API key in production via .env
        VASTAI_API_KEY: process.env.VASTAI_API_KEY || 'demo_vastai_key',
    },
    env_production: {
      NODE_ENV: 'production'
    }
  }]
};
