const puppeteer = require('puppeteer');
const assert = require('assert');

/**
 * PRODUCTION-GRADE E2E STUDIO TEST
 * This test validates the full user journey from Studio UI to Backend Result.
 * 
 * Requirements:
 * 1. vastai-proxy.js must be running on port 3000.
 * 2. studio.html must be served (using VS Code Live Server or similar).
 * 3. ComfyUI stub should be enabled in the proxy.
 */

async function runStudioE2ETest() {
    console.log('🚀 Starting Studio E2E Validation...');
    
    const browser = await puppeteer.launch({ 
        headless: false,
        defaultViewport: { width: 1280, height: 900 },
        args: ['--no-sandbox', '--disable-setuid-sandbox'] 
    });
    const page = await browser.newPage();
        
        // Forward page console and network responses for debugging
        page.on('console', msg => console.log('PAGE LOG:', msg.text()));
        page.on('pageerror', err => console.log('PAGE ERROR:', err && err.message ? err.message : String(err)));
        page.on('response', async res => {
            try {
                const url = res.url();
                if (url.includes('/api/proxy/generate')) {
                    console.log('NETWORK:', res.status(), res.request().method(), url);
                    const ct = res.headers()['content-type'] || '';
                    if (ct.includes('application/json')) {
                        const body = await res.json().catch(() => null);
                        console.log('NETWORK BODY:', body);
                    }
                }
            } catch (e) {}
        });
    try {
        // 1. Navigate to Studio
        console.log('--- Navigating to Studio UI ---');
        await page.goto('http://localhost:3000/studio.html'); 
        
        // 2. Assert Initial State
        console.log('--- Checking Initial State ---');
        await page.waitForSelector('#studio-prompt');
        const emptyState = await page.$eval('.empty-stage-state', el => el.style.display);
        assert.notStrictEqual(emptyState, 'none', 'Empty stage should be visible initially');

        // 3. Enter Prompt
        console.log('--- Submitting Generation Request ---');
        await page.type('#studio-prompt', 'A futuristic cybernetic queen, 8k, highly detailed');
        
        // 4. Click Generate
        await page.click('#btn-generate');

        // 5. Monitor Progress Bar
        console.log('--- Monitoring Progress Overlay ---');
        await page.waitForSelector('#generation-progress-container', { visible: true });
        
        const progressVisible = await page.$eval('#generation-progress-container', el => el.style.display !== 'none');
        assert.ok(progressVisible, 'Progress container should be visible');

        // 6. Wait for Completion (Long poll simulation)
        console.log('--- Waiting for Render Completion ---');
        await page.waitForSelector('#stage-image[src^="http"]', { timeout: 30000 });

        // 7. Assert Result Rendering
        const progressHidden = await page.$eval('#generation-progress-container', el => el.style.display === 'none');
        assert.ok(progressHidden, 'Progress container should be hidden after completion');

        const activeContentVisible = await page.$eval('.active-content', el => el.style.display !== 'none');
        assert.ok(activeContentVisible, 'Active content stage should be visible');

        const imgSrc = await page.$eval('#stage-image', el => el.src);
        console.log('✅ Success! Image rendered at:', imgSrc);

        // 8. Test Video Toggle
        console.log('--- Testing Video Workflow Toggle ---');
        await page.click('.workflow-btn[data-type="video"]');
        const videoBtnActive = await page.$eval('.workflow-btn[data-type="video"]', el => el.classList.contains('active'));
        assert.ok(videoBtnActive, 'Video workflow should be active');

    } catch (error) {
        console.error('❌ E2E Test Failed:', error);
        try {
            await page.screenshot({ path: 'tests/e2e-failure.png', fullPage: true });
            console.log('Saved debug screenshot to tests/e2e-failure.png');
        } catch (e) {
            console.warn('Failed to capture screenshot:', e.message || e);
        }
        process.exit(1);
    } finally {
        await browser.close();
        console.log('--- Test Completed ---');
    }
}

// Check if running as main
if (require.main === module) {
    runStudioE2ETest();
}

module.exports = runStudioE2ETest;
