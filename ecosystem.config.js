module.exports = {
  apps: [{
    name: 'vastai-proxy',
    script: 'server/vastai-proxy.js',
    cwd: './',
    env: {
      NODE_ENV: 'development',
    },
    env_production: {
      NODE_ENV: 'production'
    }
  }]
};
