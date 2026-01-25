const VastAIAutomator = require('../vastai-auto.js');

(async () => {
    const automator = new VastAIAutomator();

    console.log('--- Testing determineComplexity ---');
    const tests = [
        'create a photorealistic NSFW portrait',
        'generate anime hentai video with WAN',
        '4K realistic sex scene animation',
        'quick sketch',
        'simple portrait',
        'generate a pony character, anime',
    ];

    for (const t of tests) {
        const r = automator.determineComplexity(t);
        console.log(t, '=>', r);
    }

    console.log('\n--- Testing generateModelDownloads ---');
    console.log('NSFW, ultra:\n', automator.generateModelDownloads(true, 'ultra').slice(0, 800));
    console.log('\nNon-NSFW, medium:\n', automator.generateModelDownloads(false, 'medium').slice(0, 800));
})();