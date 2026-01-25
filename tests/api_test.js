const VastAIAutomator = require('../vastai-auto.js');

(async () => {
    const automator = new VastAIAutomator();

    console.log('--- Testing API connection (detailed) ---');
    const resp = await automator.makeRequest('/auth/me');
    console.log('Result object:', JSON.stringify(resp, null, 2));
})();