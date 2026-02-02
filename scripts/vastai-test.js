/**
 * Vast.ai Integration Test & Automation
 * Tests the cloud GPU connection and provides automated instance management
 */

class VastAITest {
    constructor() {
        this.apiKey = 'c0c517ae844d08ee03354fcf8cc9909eaaec857ed6e0a54128b3490a54808a4f';
        this.baseUrl = 'https://console.vast.ai/api/v0';
        const vastaiSsh = require('./lib/vastai-ssh');
        this.sshKey = vastaiSsh.getKey();
    }

    async testConnection() {
        try {
            console.log('Testing Vast.ai API connection...');

            const response = await fetch(`${this.baseUrl}/auth/me`, {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${this.apiKey}`,
                    'Content-Type': 'application/json'
                }
            });

            if (response.ok) {
                const data = await response.json();
                console.log('✅ Vast.ai API connection successful!');
                console.log('User info:', data);
                return true;
            } else {
                console.error('❌ Vast.ai API connection failed:', response.status, response.statusText);
                return false;
            }
        } catch (error) {
            console.error('❌ Vast.ai API connection error:', error);
            return false;
        }
    }

    async setupSSHKey() {
        try {
            console.log('Setting up SSH key for automated access...');

            const response = await fetch(`${this.baseUrl}/ssh/`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.apiKey}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    ssh_key: this.sshKey
                })
            });

            if (response.ok) {
                const data = await response.json();
                console.log('✅ SSH key added successfully!');
                console.log('Key ID:', data.key.id);
                return data.key.id;
            } else {
                const errorData = await response.json();
                console.log('SSH key setup response:', errorData);
                if (errorData.error && errorData.error.includes('already exists')) {
                    console.log('✅ SSH key already exists in account');
                    return true;
                }
                console.error('❌ SSH key setup failed:', response.status, response.statusText);
                return false;
            }
        } catch (error) {
            console.error('❌ SSH key setup error:', error);
            return false;
        }
    }

    async createComfyUITemplate() {
        try {
            console.log('Creating ComfyUI template for automated instances...');

            const response = await fetch(`${this.baseUrl}/template/`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.apiKey}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    name: 'ComfyUI-Auto-Setup',
                    image: 'pytorch/pytorch:latest',
                    tag: '@vastai-automatic-tag',
                    runtype: 'ssh',
                    onstart: `
# Install ComfyUI and dependencies
cd /root &&
git clone https://github.com/comfyanonymous/ComfyUI.git &&
cd ComfyUI &&
pip install -r requirements.txt &&
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 &&

# Start ComfyUI in background
setsid nohup python main.py --listen 0.0.0.0 --port 8188 > comfyui.log 2>&1 < /dev/null &
                    `.trim(),
                    env: {
                        'PYTHONPATH': '/root/ComfyUI'
                    },
                    recommended_disk_space: 32
                })
            });

            if (response.ok) {
                const data = await response.json();
                console.log('✅ ComfyUI template created successfully!');
                console.log('Template ID:', data.template.id);
                console.log('Template Hash:', data.template.hash_id);
                return data.template;
            } else {
                console.error('❌ Template creation failed:', response.status, response.statusText);
                const errorData = await response.json();
                console.error('Error details:', errorData);
                return null;
            }
        } catch (error) {
            console.error('❌ Template creation error:', error);
            return null;
        }
    }

    async searchAvailableOffers(complexity = 'medium', isNSFW = false) {
        try {
            const networkRequirement = isNSFW ? 800 : 50; // 800Mbps+ for NSFW ComfyUI workflows
            console.log(`🔍 Searching for GPU instances optimized for ${complexity} complexity${isNSFW ? ' (NSFW/High-Speed Network)' : ''}...`);

            // Define GPU requirements based on complexity
            const complexityConfig = {
                'low': {
                    minFlops: 10,      // TFLOPs
                    minRam: 8,         // GB
                    maxPrice: 0.5,     // $/hour
                    priority: 'speed'
                },
                'medium': {
                    minFlops: 20,
                    minRam: 16,
                    maxPrice: 1.0,
                    priority: 'balanced'
                },
                'high': {
                    minFlops: 50,
                    minRam: 24,
                    maxPrice: 2.0,
                    priority: 'power'
                },
                'ultra': {
                    minFlops: 100,
                    minRam: 48,
                    maxPrice: 5.0,
                    priority: 'maximum'
                }
            };

            const config = complexityConfig[complexity] || complexityConfig.medium;

            const searchParams = {
                verified: { eq: true },
                rentable: { eq: true },
                rented: { eq: false },
                type: 'bid', // interruptible for cost savings
                dph_total: { lte: config.maxPrice },
                total_flops: { gte: config.minFlops },
                gpu_ram: { gte: config.minRam * 1024 }, // Convert GB to MB
                reliability: { gte: 0.95 }, // High reliability for stable performance
                inet_down: { gte: networkRequirement }, // Prioritize high-speed networks for NSFW workflows
                inet_up: { gte: 10 },   // Minimum 10 MB/s upload
                order: [
                    ['inet_down', 'desc'], // Network speed first for NSFW workflows
                    ['score', 'desc'], // Overall score second
                    ['reliability', 'desc'], // Then reliability
                    ['dph_total', 'asc'] // Finally cost
                ]
            };

            const response = await fetch(`${this.baseUrl}/bundles/`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.apiKey}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(searchParams)
            });

            if (response.ok) {
                let offers = (await response.json()).offers || [];

                // Calculate performance scores for each offer
                offers = offers.map(offer => ({
                    ...offer,
                    performanceScore: this.calculatePerformanceScore(offer, config.priority),
                    networkScore: this.calculateNetworkScore(offer),
                    reliabilityScore: offer.reliability || 0,
                    valueScore: this.calculateValueScore(offer)
                }));

                // Sort by composite score
                offers.sort((a, b) => {
                    const scoreA = a.performanceScore * 0.4 + a.networkScore * 0.3 + a.reliabilityScore * 0.2 + a.valueScore * 0.1;
                    const scoreB = b.performanceScore * 0.4 + b.networkScore * 0.3 + b.reliabilityScore * 0.2 + b.valueScore * 0.1;
                    return scoreB - scoreA; // Higher scores first
                });

                // Filter top candidates
                const topOffers = offers.slice(0, 10);

                console.log(`✅ Found ${topOffers.length} optimized GPU offers for ${complexity} complexity:`);
                topOffers.forEach((offer, i) => {
                    const perf = Math.round(offer.performanceScore * 100) / 100;
                    const net = Math.round(offer.networkScore * 100) / 100;
                    const rel = Math.round(offer.reliabilityScore * 1000) / 10;
                    console.log(`${i+1}. ${offer.gpu_name} (${offer.num_gpus}x) - $${offer.dph_total}/hr`);
                    console.log(`   ↳ Perf: ${perf}, Network: ${net} MB/s, Reliability: ${rel}%, ${offer.geolocation}`);
                });

                return topOffers;
            } else {
                console.error('❌ Offer search failed:', response.status, response.statusText);
                return [];
            }
        } catch (error) {
            console.error('❌ Offer search error:', error);
            return [];
        }
    }

    calculatePerformanceScore(offer, priority) {
        const flops = offer.total_flops || 0;
        const dlperf = offer.dlperf || 0;
        const memBw = offer.gpu_mem_bw || 0;
        const vram = offer.gpu_total_ram || 0;

        // Weight factors based on priority
        const weights = {
            speed: { flops: 0.3, dlperf: 0.4, memBw: 0.2, vram: 0.1 },
            balanced: { flops: 0.25, dlperf: 0.25, memBw: 0.25, vram: 0.25 },
            power: { flops: 0.4, dlperf: 0.3, memBw: 0.2, vram: 0.1 },
            maximum: { flops: 0.5, dlperf: 0.2, memBw: 0.2, vram: 0.1 }
        };

        const w = weights[priority];
        return (flops * w.flops + dlperf * w.dlperf + memBw * w.memBw + vram * w.vram) / 1000;
    }

    calculateNetworkScore(offer) {
        const downSpeed = offer.inet_down || 0;
        const upSpeed = offer.inet_up || 0;
        const downCost = offer.inet_down_cost || 0;
        const upCost = offer.inet_up_cost || 0;

        // Favor high speed with reasonable cost
        const speedScore = Math.min(downSpeed / 100, 1) * 0.7 + Math.min(upSpeed / 50, 1) * 0.3;
        const costPenalty = Math.max(0, (downCost - 0.01) * 100); // Penalize high costs

        return Math.max(0, speedScore - costPenalty);
    }

    calculateValueScore(offer) {
        // Support multiple potential keys returned by the API and avoid divide-by-zero
        const flopsPerDollar = offer.flops_per_dphtotal || offer.flops_per_dph_total || offer.flops_per_price || offer.flops_per_dph || 0;
        const dlperfPerDollar = offer.dlperf_per_dphtotal || offer.dlperf_per_dph_total || offer.dlperf_per_price || 0;
        const total = flopsPerDollar + dlperfPerDollar;
        if (!total || total <= 0) return 0;
        return total / 2000;
    }

    determineComplexity(userRequest) {
        if (!userRequest) return { complexity: 'medium', isNSFW: false };

        const text = userRequest.toLowerCase();
        let isNSFW = false;

        // NSFW content detection
        const nsfwKeywords = ['nsfw', 'nude', 'naked', 'adult', 'erotic', 'porn', 'sex', 'hentai', 'anime girl', 'waifu'];
        isNSFW = nsfwKeywords.some(keyword => text.includes(keyword));

        // Ultra high complexity indicators
        if (text.includes('4k') || text.includes('8k') || text.includes('video') ||
            text.includes('animation') || text.includes('complex scene') ||
            text.includes('high resolution') || text.includes('professional') ||
            text.includes('wan') || text.includes('video generation')) {
            return { complexity: 'ultra', isNSFW };
        }

        // High complexity indicators
        if (text.includes('hd') || text.includes('high quality') || text.includes('detailed') ||
            text.includes('complex') || text.includes('multiple subjects') ||
            text.includes('intricate') || text.includes('photorealistic') ||
            text.includes('realistic') || text.includes('pony')) {
            return { complexity: 'high', isNSFW };
        }

        // Low complexity indicators
        if (text.includes('simple') || text.includes('basic') || text.includes('quick') ||
            text.includes('sketch') || text.includes('draft') || text.includes('low quality')) {
            return { complexity: 'low', isNSFW };
        }

        return { complexity: 'medium', isNSFW };
    }

    async launchAutomatedInstance(complexity = 'medium', isNSFW = false) {
        try {
            console.log('🚀 Launching automated ComfyUI instance...');

            // First get available offers
            const offers = await this.searchAvailableOffers(complexity, isNSFW);
            if (offers.length === 0) {
                console.error('❌ No suitable GPU offers found');
                return null;
            }

            const selectedOffer = offers[0]; // Use the best scored offer
            console.log(`🎯 Selected: ${selectedOffer.gpu_name} (${selectedOffer.num_gpus}x) for $${selectedOffer.dph_total}/hr`);
            console.log(`   ↳ Network: ${selectedOffer.inet_down}↓/${selectedOffer.inet_up}↑ MB/s ${isNSFW ? '(Optimized for NSFW workflows)' : ''}`);
            console.log(`   ↳ Performance: ${Math.round(selectedOffer.total_flops)} TFLOPs, ${selectedOffer.gpu_total_ram}MB VRAM`);
            console.log(`   ↳ Reliability: ${Math.round(selectedOffer.reliability * 100)}%`);

            const response = await fetch(`${this.baseUrl}/asks/${selectedOffer.id}/`, {
                method: 'PUT',
                headers: {
                    'Authorization': `Bearer ${this.apiKey}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    image: 'pytorch/pytorch:latest',
                    template_id: templateId,
                    runtype: 'ssh',
                    target_state: 'running',
                    onstart: `
# Install ComfyUI and dependencies
cd /root &&
git clone https://github.com/comfyanonymous/ComfyUI.git &&
cd ComfyUI &&
pip install -r requirements.txt &&
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 &&

# Start ComfyUI in background
setsid nohup python main.py --listen 0.0.0.0 --port 8188 > comfyui.log 2>&1 < /dev/null &
                    `.trim(),
                    env: {
                        'PYTHONPATH': '/root/ComfyUI'
                    },
                    disk: 32
                })
            });

            if (response.ok) {
                const data = await response.json();
                console.log('✅ Instance launched successfully!');
                console.log('Contract ID:', data.new_contract);
                return data.new_contract;
            } else {
                console.error('❌ Instance launch failed:', response.status, response.statusText);
                const errorData = await response.json();
                console.error('Error details:', errorData);
                return null;
            }
        } catch (error) {
            console.error('❌ Instance launch error:', error);
            return null;
        }
    }

    async checkInstanceStatus(contractId) {
        try {
            const response = await fetch(`${this.baseUrl}/instances/${contractId}/`, {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${this.apiKey}`,
                    'Content-Type': 'application/json'
                }
            });

            if (response.ok) {
                const data = await response.json();
                console.log(`Instance status: ${data.actual_status}`);
                if (data.actual_status === 'running') {
                    console.log(`SSH Access: ssh root@${data.public_ipaddr}`);
                    console.log(`ComfyUI URL: http://${data.public_ipaddr}:8188`);
                }
                return data;
            } else {
                console.error('❌ Status check failed:', response.status, response.statusText);
                return null;
            }
        } catch (error) {
            console.error('❌ Status check error:', error);
            return null;
        }
    }

    async testInstanceListing() {
        try {
            console.log('Testing instance listing...');

            const response = await fetch(`${this.baseUrl}/instances`, {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${this.apiKey}`,
                    'Content-Type': 'application/json'
                }
            });

            if (response.ok) {
                const data = await response.json();
                console.log('✅ Instance listing successful!');
                console.log('Instances:', data);
                return data;
            } else {
                console.error('❌ Instance listing failed:', response.status, response.statusText);
                return null;
            }
        } catch (error) {
            console.error('❌ Instance listing error:', error);
            return null;
        }
    }

    async runFullAutomation(userRequest = null) {
        console.log('🚀 Starting full automated ComfyUI instance setup...');

        // Determine complexity and NSFW requirements from user request
        const { complexity, isNSFW } = this.determineComplexity(userRequest);
        console.log(`🎯 Determined complexity level: ${complexity.toUpperCase()}`);
        if (isNSFW) {
            console.log(`🔞 NSFW content detected - prioritizing 800Mbps+ networks`);
        }

        // Step 1: Test connection
        const connected = await this.testConnection();
        if (!connected) return;

        // Step 2: Setup SSH key
        const sshSetup = await this.setupSSHKey();
        if (!sshSetup) return;

        // Step 3: Create template (optional, can use direct launch)
        const template = await this.createComfyUITemplate();

        // Step 4: Launch instance with determined complexity
        const contractId = await this.launchAutomatedInstance(complexity, isNSFW);
        if (!contractId) return;

        // Step 5: Monitor status
        console.log('⏳ Monitoring instance startup (this may take 5-10 minutes)...');
        let attempts = 0;
        const maxAttempts = 60; // 10 minutes

        while (attempts < maxAttempts) {
            await new Promise(resolve => setTimeout(resolve, 10000)); // Wait 10 seconds
            const status = await this.checkInstanceStatus(contractId);

            if (status && status.actual_status === 'running') {
                console.log('🎉 Instance is ready!');
                console.log(`SSH: ssh -i ~/.ssh/vast_ai_comfyui root@${status.public_ipaddr}`);
                console.log(`ComfyUI: http://${status.public_ipaddr}:8188`);
                break;
            }

            attempts++;
            if (attempts % 6 === 0) { // Every minute
                console.log(`Still waiting... (${attempts/6} minutes elapsed)`);
            }
        }

        if (attempts >= maxAttempts) {
            console.log('⚠️ Instance startup timed out. Check status manually.');
        }
    }
}

    async testConnection() {
        try {
            console.log('Testing Vast.ai API connection...');

            const response = await fetch(`${this.baseUrl}/auth/me`, {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${this.apiKey}`,
                    'Content-Type': 'application/json'
                }
            });

            if (response.ok) {
                const data = await response.json();
                console.log('✅ Vast.ai API connection successful!');
                console.log('User info:', data);
                return true;
            } else {
                console.error('❌ Vast.ai API connection failed:', response.status, response.statusText);
                return false;
            }
        } catch (error) {
            console.error('❌ Vast.ai API connection error:', error);
            return false;
        }
    }

    async testInstanceListing() {
        try {
            console.log('Testing instance listing...');

            const response = await fetch(`${this.baseUrl}/instances`, {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${this.apiKey}`,
                    'Content-Type': 'application/json'
                }
            });

            if (response.ok) {
                const data = await response.json();
                console.log('✅ Instance listing successful!');
                console.log('Instances:', data);
                return data;
            } else {
                console.error('❌ Instance listing failed:', response.status, response.statusText);
                return null;
            }
        } catch (error) {
            console.error('❌ Instance listing error:', error);
            return null;
        }
    }
}

// Run test when page loads
document.addEventListener('DOMContentLoaded', async () => {
    const test = new VastAITest();
    const resultsDiv = document.getElementById('results');

    const log = (message, type = 'info') => {
        const div = document.createElement('div');
        div.className = type;
        div.textContent = `[${new Date().toLocaleTimeString()}] ${message}`;
        resultsDiv.appendChild(div);
        console.log(message);
    };

    log('🧪 Starting Vast.ai integration tests...');

    const connectionOk = await test.testConnection();
    if (connectionOk) {
        log('✅ API connection test passed!', 'success');
        const instances = await test.testInstanceListing();
        if (instances) {
            log(`✅ Found ${instances.length} instances`, 'success');
        } else {
            log('❌ Instance listing failed', 'error');
        }
    } else {
        log('❌ API connection test failed', 'error');
    }

    log('🧪 Tests completed!');
});</content>
<parameter name="filePath">c:\Users\samsc\OneDrive\Desktop\working protoype\vastai-test.html