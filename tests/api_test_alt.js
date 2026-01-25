const VastAIAutomator = require('../vastai-auto.js');

(async () => {
    const automator = new VastAIAutomator();
    automator.baseUrl = 'https://api.vast.ai/api/v0';

    console.log('--- Testing API connection (alternate baseUrl) ---');
    const resp = await automator.makeRequest('/auth/me');
    console.log('Result object:', JSON.stringify(resp, null, 2));
})();