#!/usr/bin/env node

/**
 * Vast.ai Automated ComfyUI Instance Launcher
 * Command-line tool for fully automated GPU instance deployment
 */

const https = require('https');
const fs = require('fs');
const path = require('path');
const vastaiSsh = require('../lib/vastai-ssh');

class VastAIAutomator {
    constructor() {
        this.apiKey = process.env.VASTAI_API_KEY || 'c0c517ae844d08ee03354fcf8cc9909eaaec857ed6e0a54128b3490a54808a4f';
        this.baseUrl = 'https://console.vast.ai/api/v0';
        this.sshKey = vastaiSsh.getKey();

        // Token checks for model downloads
        this.hfToken = process.env.HUGGINGFACE_HUB_TOKEN || process.env.HUGGINGFACE_TOKEN || null;
        this.civitaiToken = process.env.CIVITAI_TOKEN || null;
        if (!this.hfToken) console.warn('Hugging Face token not found in environment. Large model downloads may fail.');
        if (!this.civitaiToken) console.warn('Civitai token not found in environment. Some model downloads may require manual steps.');
    }

    async makeRequest(endpoint, options = {}) {
        // Follow up to 5 redirects and show verbose info on non-200 responses
        const maxRedirects = 5;

        const doRequest = (url, redirectsLeft) => new Promise((resolve, reject) => {
            const requestOptions = {
                method: options.method || 'GET',
                headers: {
                    'Authorization': `Bearer ${this.apiKey}`,
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    ...options.headers
                }
            };

            const req = https.request(url, requestOptions, (res) => {
                // Handle redirects
                if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location && redirectsLeft > 0) {
                    const nextUrl = res.headers.location.startsWith('http') ? res.headers.location : `${this.baseUrl}${res.headers.location}`;
                    return resolve(doRequest(nextUrl, redirectsLeft - 1));
                }

                let data = '';
                res.on('data', (chunk) => data += chunk);
                res.on('end', () => {
                    let parsed = data;
                    try { parsed = JSON.parse(data); } catch (e) { /* keep raw */ }

                    if (res.statusCode !== 200) {
                        // Verbose diagnostic logging for easier debugging
                        console.warn(`HTTP ${res.statusCode} from ${url}`);
                        console.warn('Response headers:', res.headers);
                        console.warn('Response body (truncated):', typeof parsed === 'string' ? parsed.slice(0, 1024) : parsed);
                    }

                    resolve({ statusCode: res.statusCode, data: parsed, headers: res.headers });
                });
            });

            req.on('error', (err) => reject(err));

            if (options.body) {
                req.write(JSON.stringify(options.body));
            }

            req.end();
        });

        return doRequest(`${this.baseUrl}${endpoint}`, maxRedirects);
    }

    async testConnection() {
        console.log('🔗 Testing Vast.ai API connection...');
        const response = await this.makeRequest('/auth/me');

        if (response.statusCode === 200) {
            console.log('✅ API connection successful!');
            return true;
        } else {
            console.error('❌ API connection failed:', response.statusCode);
            return false;
        }
    }

    async setupSSHKey() {
        console.log('🔑 Setting up SSH key...');
        return await vastaiSsh.registerKey(this.apiKey);
    }

    async searchOffers(complexity = 'medium', isNSFW = false) {
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
            disk_space: { gte: 250 }, // 250GB minimum for provision-reliable.sh
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

        const response = await this.makeRequest('/bundles/', {
            method: 'POST',
            body: searchParams
        });

        if (response.statusCode === 200) {
            let offers = response.data.offers || [];

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
            console.error('❌ Offer search failed:', response.statusCode);
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
        // normalize to a small value to keep comparable ranges
        return total / 2000;
    }

    generateModelDownloads(isNSFW, complexity) {
        let downloads = '';

        // Helper: don't block startup on very large downloads. Run in background with retries.
        const bgDownload = (cmd) => `nohup sh -c "(for i in 1 2 3; do ${cmd} && break || sleep 10; done)" >/var/log/model-downloads.log 2>&1 &`;

        // Warn about missing credentials and perform token-aware downloads
        downloads += `
# NOTE: This boot-time installer attempts automated downloads but requires credentials for Hugging Face and Civitai.
# - Set HUGGINGFACE_HUB_TOKEN in the environment before launch (or run ` + "'huggingface-cli login'" + `)
# - Set CIVITAI_TOKEN in the environment if you want programmatic civitai downloads. Otherwise the script will notify and skip.
`;

        if (isNSFW) {
            downloads += `
# NSFW-optimized models (backgrounded downloads)
mkdir -p /root/ComfyUI/models/checkpoints /root/ComfyUI/models/loras /root/ComfyUI/models/vae &&
cd /root/ComfyUI/models/checkpoints &&
`;

            // WAN 1.3B (consumer-friendly) - Hugging Face requires token
            downloads += `
echo "Starting WAN T2V-1.3B download (may require HUGGINGFACE_HUB_TOKEN)..." &&
` + bgDownload(`huggingface-cli download Wan-AI/Wan2.1-T2V-1.3B --local-dir ./Wan2.1-T2V-1.3B --quiet || echo 'WAN 1.3B download failed'`) + `
`;

            // Civitai downloads (token-aware)
            downloads += `
if [ -z "\${CIVITAI_TOKEN}" ]; then echo "⚠ CIVITAI_TOKEN not set - RealVisXL/PonyXL/Counterfeit will require manual download or set CIVITAI_TOKEN."; else
  echo "Downloading RealVisXL..." && ${bgDownload('wget -O RealVisXL_V5.0.safetensors "https://civitai.com/api/download/models/798204?token=\${CIVITAI_TOKEN}" || echo "RealVisXL download failed"')}
  echo "Downloading PonyXL..." && ${bgDownload('wget -O PonyXL.safetensors "https://civitai.com/api/download/models/290640?token=\${CIVITAI_TOKEN}" || echo "PonyXL download failed"')}
  echo "Downloading Counterfeit..." && ${bgDownload('wget -O CounterfeitV30.safetensors "https://civitai.com/api/download/models/241562?token=\${CIVITAI_TOKEN}" || echo "Counterfeit download failed"')}
fi
`;

            if (complexity === 'ultra') {
                downloads += `
# WAN 14B is very large and may require multi-GPU or offloading. Attempt background download (requires HUGGINGFACE_HUB_TOKEN)
` + bgDownload(`huggingface-cli download Wan-AI/Wan2.1-T2V-14B --local-dir ./Wan2.1-T2V-14B --quiet || echo 'WAN 14B download failed - consider multi-GPU/offload steps'`) + `
`;
            }

            downloads += `
cd /root/ComfyUI &&
`;
        } else {
            // Standard SFW models
            downloads += `
# Standard model downloads (background)
mkdir -p /root/ComfyUI/models/checkpoints &&
cd /root/ComfyUI/models/checkpoints &&
` + bgDownload(`huggingface-cli download stabilityai/stable-diffusion-xl-base-1.0 --local-dir ./sd_xl_base_1.0 --quiet || echo 'SDXL base download failed'`) + `
` + bgDownload(`huggingface-cli download stabilityai/stable-diffusion-xl-refiner-1.0 --local-dir ./sd_xl_refiner_1.0 --quiet || echo 'SDXL refiner download failed'`) + `
cd /root/ComfyUI &&
`;
        }

        // Install ComfyUI custom nodes for WAN support
        downloads += `
# Install ComfyUI WAN nodes
cd /root/ComfyUI/custom_nodes &&
if [ ! -d "ComfyUI-WanVideoWrapper" ]; then git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git; fi &&
cd ComfyUI-WanVideoWrapper &&
pip install -r requirements.txt || echo "ComfyUI WAN node install had issues" &&
cd /root/ComfyUI &&
`;

        return downloads;
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

    async launchInstance(complexity = 'medium', isNSFW = false) {
        const offers = await this.searchOffers(complexity, isNSFW);
        if (offers.length === 0) {
            console.error('❌ No suitable GPU offers found');
            return null;
        }

        const selectedOffer = offers[0];
        console.log(`🎯 Selected: ${selectedOffer.gpu_name} (${selectedOffer.num_gpus}x) for $${selectedOffer.dph_total}/hr`);
        console.log(`   ↳ Network: ${selectedOffer.inet_down}↓/${selectedOffer.inet_up}↑ MB/s ${isNSFW ? '(Optimized for NSFW workflows)' : ''}`);
        console.log(`   ↳ Performance: ${Math.round(selectedOffer.total_flops)} TFLOPs, ${selectedOffer.gpu_total_ram}MB VRAM`);
        console.log(`   ↳ Reliability: ${Math.round(selectedOffer.reliability * 100)}%`);

        console.log('🚀 Launching ComfyUI instance with NSFW optimizations...');

        // Generate model download commands based on NSFW requirements
        const modelDownloads = this.generateModelDownloads(isNSFW, complexity);

        const response = await this.makeRequest(`/asks/${selectedOffer.id}/`, {
            method: 'PUT',
            body: {
                image: 'nvidia/cuda:12.4.0-devel-ubuntu24.04',  // Clean Ubuntu base - no pre-configured provisioning
                runtype: 'ssh',
                target_state: 'running',
                onstart: `
#!/bin/bash
set -e
export WORKSPACE=/workspace
export CIVITAI_TOKEN="${this.civitaiToken || ''}"
export HUGGINGFACE_HUB_TOKEN="${this.hfToken || ''}"

# Download and execute custom provision script
cd /workspace
curl -fsSL "https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw" -o provision-reliable.sh
chmod +x provision-reliable.sh

# Run provision script in detached screen session (survives SSH disconnects)
screen -dmS provision bash -c "./provision-reliable.sh 2>&1 | tee provision.log"

# Monitor provisioning status
echo "🚀 Provisioning started in screen session 'provision'"
echo "📝 Logs: /workspace/provision.log"
echo "🔗 To attach: screen -r provision"
                `.trim(),
                env: Object.assign({
                    'WORKSPACE': '/workspace',
                    'PYTHONPATH': '/workspace/ComfyUI',
                    'MIN_DISK_GB': '200'  // Provision script requires minimum 200GB
                },
                // Pass down tokens if available so instance can perform automated downloads
                (this.hfToken ? { 'HUGGINGFACE_HUB_TOKEN': this.hfToken } : {}),
                (this.civitaiToken ? { 'CIVITAI_TOKEN': this.civitaiToken } : {})
                ),
                disk: 250  // 250GB for models + workflows + cache (provision needs 200GB+)
            }
        });

        if (response.statusCode === 200) {
            const contractId = response.data.new_contract;
            console.log(`✅ Instance launched! Contract ID: ${contractId}`);
            return contractId;
        } else {
            console.error('❌ Instance launch failed:', response.statusCode, response.data);
            return null;
        }
    }

    async checkStatus(contractId) {
        const response = await this.makeRequest(`/instances/${contractId}/`);

        if (response.statusCode === 200) {
            return response.data;
        } else {
            console.error('❌ Status check failed:', response.statusCode);
            return null;
        }
    }

    async waitForReady(contractId, maxWaitMinutes = 15) {
        console.log('⏳ Waiting for instance to be ready...');

        for (let i = 0; i < maxWaitMinutes * 6; i++) { // Check every 10 seconds
            const status = await this.checkStatus(contractId);

            if (status && status.actual_status === 'running') {
                console.log('🎉 Instance is ready!');
                console.log(`SSH: ssh -i ~/.ssh/vast_ai_comfyui root@${status.public_ipaddr}`);
                console.log(`ComfyUI: http://${status.public_ipaddr}:8188`);

                // Save connection info
                const connectionInfo = {
                    contractId,
                    ip: status.public_ipaddr,
                    gpu: status.gpu_name,
                    costPerHour: status.dph_total,
                    launchedAt: new Date().toISOString()
                };

                fs.writeFileSync('vastai-instance.json', JSON.stringify(connectionInfo, null, 2));
                console.log('💾 Connection info saved to vastai-instance.json');

                return status;
            }

            await new Promise(resolve => setTimeout(resolve, 10000));

            if (i % 6 === 0) { // Every minute
                console.log(`Still waiting... (${Math.floor(i/6) + 1} minutes elapsed)`);
            }
        }

        console.log('⚠️ Instance startup timed out');
        return null;
    }

    async runAutomation(userRequest = null) {
        console.log('🤖 Starting automated ComfyUI deployment...');

        // Determine complexity and NSFW requirements from user request
        const { complexity, isNSFW } = this.determineComplexity(userRequest);
        console.log(`🎯 Determined complexity level: ${complexity.toUpperCase()}`);
        if (isNSFW) {
            console.log(`🔞 NSFW content detected - prioritizing 800Mbps+ networks and optimized models`);
        }

        // Test connection
        if (!await this.testConnection()) return;

        // Setup SSH key
        if (!await this.setupSSHKey()) return;

        // Launch instance with determined complexity and NSFW flag
        const contractId = await this.launchInstance(complexity, isNSFW);
        if (!contractId) return;

        // Wait for ready
        await this.waitForReady(contractId);
    }

    async stopInstance(contractId) {
        console.log(`🛑 Stopping instance ${contractId}...`);
        const response = await this.makeRequest(`/instances/${contractId}/`, {
            method: 'DELETE'
        });

        if (response.statusCode === 200) {
            console.log('✅ Instance stopped successfully');
            return true;
        } else {
            console.error('❌ Failed to stop instance:', response.statusCode);
            return false;
        }
    }
}

// CLI interface
async function main() {
    const automator = new VastAIAutomator();
    const command = process.argv[2];
    const param = process.argv[3];

    switch (command) {
        case 'launch':
            const userRequest = param || process.argv.slice(3).join(' ');
            await automator.runAutomation(userRequest);
            break;
        case 'stop':
            if (!param) {
                console.error('Usage: node vastai-auto.js stop <contract_id>');
                process.exit(1);
            }
            await automator.stopInstance(param);
            break;
        case 'status':
            if (!param) {
                console.error('Usage: node vastai-auto.js status <contract_id>');
                process.exit(1);
            }
            const status = await automator.checkStatus(param);
            if (status) {
                console.log('Status:', status.actual_status);
                if (status.actual_status === 'running') {
                    console.log(`IP: ${status.public_ipaddr}`);
                    console.log(`ComfyUI: http://${status.public_ipaddr}:8188`);
                }
            }
            break;
        case 'search':
            const complexity = param || 'medium';
            await automator.searchOffers(complexity);
            break;
        default:
            console.log('Vast.ai ComfyUI Automator with NSFW & WAN Video Support');
            console.log('');
            console.log('Usage:');
            console.log('  node vastai-auto.js launch [description]    # Launch with auto-detected complexity & NSFW detection');
            console.log('  node vastai-auto.js stop <id>               # Stop instance by contract ID');
            console.log('  node vastai-auto.js status <id>             # Check instance status');
            console.log('  node vastai-auto.js search [complexity]     # Search offers (low/medium/high/ultra)');
            console.log('');
            console.log('Complexity levels:');
            console.log('  low: Basic tasks, simple images');
            console.log('  medium: Standard quality, normal workflows');
            console.log('  high: High quality, detailed work, photorealistic');
            console.log('  ultra: 4K/8K video, complex animations, WAN models');
            console.log('');
            console.log('NSFW Support:');
            console.log('  Automatically detects NSFW content and prioritizes 800Mbps+ networks');
            console.log('  Downloads WAN 2.1, RealVisXL, PonyXL, Counterfeit-V3.0 models');
            console.log('  Optimized for photorealistic, anime, and video NSFW generation');
            console.log('');
            console.log('Examples:');
            console.log('  node vastai-auto.js launch "create a photorealistic NSFW portrait"');
            console.log('  node vastai-auto.js launch "generate anime hentai video with WAN"');
            console.log('  node vastai-auto.js launch "4K realistic sex scene animation"');
            console.log('  node vastai-auto.js search high');
    }
}

if (require.main === module) {
    main().catch(console.error);
}

module.exports = VastAIAutomator;