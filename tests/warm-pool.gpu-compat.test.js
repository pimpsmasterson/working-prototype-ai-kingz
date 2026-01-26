const assert = require('assert');
const nock = require('nock');
const { resetDb, reloadWarmPoolWithEnv, nockCleanAll } = require('./helpers/test-helper');

describe('WarmPool GPU Compatibility', function() {
    this.timeout(10000);

    beforeEach(function() {
        resetDb();
        nock.cleanAll();
    });

    afterEach(function() {
        nockCleanAll();
    });

    describe('isGpuCompatible', function() {
        it('should reject legacy GPUs with CUDA < 7.0', function() {
            const warmPool = reloadWarmPoolWithEnv({ VASTAI_API_KEY: 'dummy' });

            // TITAN Xp, GTX 1080 Ti - CUDA 6.1 (Pascal)
            assert.strictEqual(warmPool.isGpuCompatible(6.1), false);
            assert.strictEqual(warmPool.isGpuCompatible('6.1'), false);

            // GTX 1070 - CUDA 6.1
            assert.strictEqual(warmPool.isGpuCompatible(6.1), false);
        });

        it('should accept modern GPUs with CUDA >= 7.0', function() {
            const warmPool = reloadWarmPoolWithEnv({ VASTAI_API_KEY: 'dummy' });

            // V100 - CUDA 7.0 (Volta)
            assert.strictEqual(warmPool.isGpuCompatible(7.0), true);

            // RTX 2080 Ti - CUDA 7.5 (Turing)
            assert.strictEqual(warmPool.isGpuCompatible(7.5), true);

            // A100 - CUDA 8.0 (Ampere)
            assert.strictEqual(warmPool.isGpuCompatible(8.0), true);

            // RTX 3090 - CUDA 8.6 (Ampere)
            assert.strictEqual(warmPool.isGpuCompatible(8.6), true);

            // RTX 4090 - CUDA 8.9 (Ada)
            assert.strictEqual(warmPool.isGpuCompatible(8.9), true);
        });

        it('should allow unknown CUDA capability (defensive)', function() {
            const warmPool = reloadWarmPoolWithEnv({ VASTAI_API_KEY: 'dummy' });

            // If cuda_max_good is missing or invalid, allow it (will fail at health check)
            assert.strictEqual(warmPool.isGpuCompatible(undefined), true);
            assert.strictEqual(warmPool.isGpuCompatible(null), true);
            assert.strictEqual(warmPool.isGpuCompatible('unknown'), true);
        });

        it('should respect custom MIN_CUDA_CAPABILITY env var', function() {
            // Set minimum to 8.0 (only Ampere and newer)
            const warmPool = reloadWarmPoolWithEnv({
                VASTAI_API_KEY: 'dummy',
                VASTAI_MIN_CUDA_CAPABILITY: '8.0'
            });

            // Now 7.5 (Turing) should be rejected
            assert.strictEqual(warmPool.isGpuCompatible(7.5), false);

            // 8.0+ should still be accepted
            assert.strictEqual(warmPool.isGpuCompatible(8.0), true);
            assert.strictEqual(warmPool.isGpuCompatible(8.6), true);
        });
    });

    describe('getPyTorchVersionForGPU', function() {
        it('should return legacy PyTorch for CUDA <= 6.1', function() {
            const warmPool = reloadWarmPoolWithEnv({ VASTAI_API_KEY: 'dummy' });

            const config = warmPool.getPyTorchVersionForGPU(6.1);

            assert.strictEqual(config.torch, 'torch==2.0.1+cu118');
            assert.strictEqual(config.torchvision, 'torchvision==0.15.2+cu118');
            assert.strictEqual(config.cudaVersion, '11.8');
            assert.strictEqual(config.isLegacy, true);
        });

        it('should return modern PyTorch for CUDA >= 7.0', function() {
            const warmPool = reloadWarmPoolWithEnv({ VASTAI_API_KEY: 'dummy' });

            const config = warmPool.getPyTorchVersionForGPU(8.6);

            assert.strictEqual(config.torch, 'torch==2.9.1+cu128');
            assert.strictEqual(config.torchvision, 'torchvision==0.20.1+cu128');
            assert.strictEqual(config.cudaVersion, '12.8');
            assert.strictEqual(config.isLegacy, false);
        });

        it('should return modern PyTorch for unknown capability', function() {
            const warmPool = reloadWarmPoolWithEnv({ VASTAI_API_KEY: 'dummy' });

            const config = warmPool.getPyTorchVersionForGPU(undefined);

            assert.strictEqual(config.isLegacy, false);
            assert.strictEqual(config.cudaVersion, '12.8');
        });
    });

    describe('prewarm GPU filtering', function() {
        it('should filter out legacy GPUs during bundle search', async function() {
            process.env.VASTAI_API_KEY = 'dummy_key';

            // Mock SSH key registration
            nock('https://console.vast.ai')
                .post('/api/v0/ssh/')
                .reply(200, { success: true });

            // Mock bundles with mixed GPU types
            nock('https://console.vast.ai')
                .post('/api/v0/bundles/')
                .reply(200, {
                    offers: [
                        // Legacy GPU - should be filtered out
                        { id: 1, gpu_name: 'TITAN Xp', cuda_max_good: 6.1, dph_total: 0.3, rentable: true, rented: false, gpu_ram: 12288, disk_space: 250 },
                        // Legacy GPU - should be filtered out
                        { id: 2, gpu_name: 'GTX 1080 Ti', cuda_max_good: 6.1, dph_total: 0.25, rentable: true, rented: false, gpu_ram: 11264, disk_space: 250 },
                        // Modern GPU - should be selected (cheapest compatible)
                        { id: 3, gpu_name: 'RTX 3090', cuda_max_good: 8.6, dph_total: 0.5, rentable: true, rented: false, gpu_ram: 24576, disk_space: 250 },
                        // Modern GPU - more expensive
                        { id: 4, gpu_name: 'RTX 4090', cuda_max_good: 8.9, dph_total: 0.7, rentable: true, rented: false, gpu_ram: 24576, disk_space: 250 }
                    ]
                });

            // Mock asks PUT for the RTX 3090 (id: 3) - this should be selected
            nock('https://console.vast.ai')
                .put('/api/v0/asks/3/')
                .reply(200, { new_contract: 999 });

            // Mock instance status check
            nock('https://console.vast.ai')
                .get('/api/v0/instances/999/')
                .times(10)
                .reply(200, { status: 'running', public_ipaddr: '1.2.3.4' });

            // Mock ComfyUI health check
            nock('http://1.2.3.4:8188')
                .get('/system_stats')
                .reply(200, {
                    system: { vram_total: 24576, vram_free: 20000 }
                });

            const warmPool = reloadWarmPoolWithEnv({ VASTAI_API_KEY: 'dummy_key' });

            const result = await warmPool.prewarm();

            assert.strictEqual(result.status, 'started');
            // The RTX 3090 (id: 3) should have been selected, not the cheaper legacy GPUs
            assert.ok(result.instance, 'instance should be created');
        });

        it('should fail gracefully if no compatible GPUs found', async function() {
            process.env.VASTAI_API_KEY = 'dummy_key';

            // Mock SSH key registration
            nock('https://console.vast.ai')
                .post('/api/v0/ssh/')
                .reply(200, { success: true });

            // Mock bundles with ONLY legacy GPUs
            nock('https://console.vast.ai')
                .post('/api/v0/bundles/')
                .times(3) // Will retry 3 times
                .reply(200, {
                    offers: [
                        { id: 1, gpu_name: 'TITAN Xp', cuda_max_good: 6.1, dph_total: 0.3, rentable: true, rented: false, gpu_ram: 12288, disk_space: 250 },
                        { id: 2, gpu_name: 'GTX 1080 Ti', cuda_max_good: 6.1, dph_total: 0.25, rentable: true, rented: false, gpu_ram: 11264, disk_space: 250 }
                    ]
                });

            const warmPool = reloadWarmPoolWithEnv({ VASTAI_API_KEY: 'dummy_key' });

            try {
                await warmPool.prewarm();
                assert.fail('Should have thrown an error');
            } catch (error) {
                assert.ok(error.message.includes('No offers found'), 'Should indicate no compatible offers');
            }
        });
    });

    describe('validateInstanceHealth', function() {
        it('should pass health check for healthy instance', async function() {
            const warmPool = reloadWarmPoolWithEnv({ VASTAI_API_KEY: 'dummy' });

            // Mock healthy ComfyUI instance
            nock('http://test-instance:8188')
                .get('/system_stats')
                .reply(200, {
                    system: { vram_total: 24576, vram_free: 20000 }
                });

            nock('http://test-instance:8188')
                .get('/object_info/CheckpointLoaderSimple')
                .reply(200, {
                    CheckpointLoaderSimple: {
                        input: {
                            required: {
                                ckpt_name: [['model1.safetensors', 'model2.safetensors']]
                            }
                        }
                    }
                });

            const report = await warmPool.validateInstanceHealth('http://test-instance:8188', 'test-123');

            assert.strictEqual(report.comfyui_api, true);
            assert.strictEqual(report.gpu_available, true);
            assert.strictEqual(report.gpu_functional, true);
            assert.strictEqual(report.vram_total, 24576);
            assert.strictEqual(report.vram_free, 20000);
            assert.strictEqual(warmPool.isInstanceHealthy(report), true);
        });

        it('should fail health check if GPU VRAM exhausted', async function() {
            const warmPool = reloadWarmPoolWithEnv({ VASTAI_API_KEY: 'dummy' });

            // Mock instance with exhausted VRAM
            nock('http://test-instance:8188')
                .get('/system_stats')
                .reply(200, {
                    system: { vram_total: 24576, vram_free: 1000 } // Only 4% free
                });

            const report = await warmPool.validateInstanceHealth('http://test-instance:8188', 'test-123');

            assert.strictEqual(report.comfyui_api, true);
            assert.strictEqual(report.gpu_available, true);
            assert.strictEqual(report.gpu_functional, false); // Should fail due to low VRAM
            assert.ok(report.errors.some(e => e.includes('VRAM exhausted')));
            assert.strictEqual(warmPool.isInstanceHealthy(report), false);
        });

        it('should fail health check if no GPU detected', async function() {
            const warmPool = reloadWarmPoolWithEnv({ VASTAI_API_KEY: 'dummy' });

            // Mock instance with no GPU
            nock('http://test-instance:8188')
                .get('/system_stats')
                .reply(200, {
                    system: { vram_total: 0, vram_free: 0 }
                });

            const report = await warmPool.validateInstanceHealth('http://test-instance:8188', 'test-123');

            assert.strictEqual(report.comfyui_api, true);
            assert.strictEqual(report.gpu_available, false);
            assert.ok(report.errors.some(e => e.includes('No GPU')));
            assert.strictEqual(warmPool.isInstanceHealthy(report), false);
        });

        it('should fail health check if API not responding', async function() {
            const warmPool = reloadWarmPoolWithEnv({ VASTAI_API_KEY: 'dummy' });

            // Mock API failure
            nock('http://test-instance:8188')
                .get('/system_stats')
                .reply(500, 'Internal Server Error');

            const report = await warmPool.validateInstanceHealth('http://test-instance:8188', 'test-123');

            assert.strictEqual(report.comfyui_api, false);
            assert.ok(report.errors.some(e => e.includes('500')));
            assert.strictEqual(warmPool.isInstanceHealthy(report), false);
        });
    });
});
