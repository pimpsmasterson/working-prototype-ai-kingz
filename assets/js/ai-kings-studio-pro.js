/**
 * AI KINGS STUDIO - Professional Edition
 * Integrates with ComfyUI and Professional Muse Management System
 */

class StudioAppPro {
    constructor() {
        this.museManager = null;
        this.comfyUI = null;
        this.promptInput = null;
        this.generateBtn = null;
        this.stage = null;

        this.isGenerating = false;

        // Cloud service configurations
        this.cloudServices = {
            vastai: {
                name: 'Vast.ai',
                apiUrl: 'https://console.vast.ai/api/v0',
                requiresApiKey: true,
                defaultTemplate: 12345, // RTX 3090 template ID
                gpuOptions: ['RTX 3090', 'RTX 4090', 'A100', 'H100']
            }
        };

        this.init();
    }

    async init() {
        try {
            // Initialize Professional Muse Manager
            this.museManager = new MuseManager(this);
            await this.museManager.init();

            // Get ComfyUI integration from muse manager
            this.comfyUI = this.museManager.comfyUI;

            // Load cloud service configuration
            this.loadCloudConfig();

            // Configure ComfyUI endpoint with cloud service
            this.configureCloudEndpoint();

            // Update cloud status indicator
            this.updateCloudStatus();

            // Check server-side tokens (Hugging Face / Civitai) used by the proxy
            this.checkServerTokens();

            // Get UI elements
            this.promptInput = document.getElementById('studio-prompt');
            this.generateBtn = document.getElementById('btn-generate');
            this.stage = document.getElementById('main-canvas-container');

            // Bind events
            this.bindEvents();

            // Bind settings modal events
            this.bindSettingsEvents();

            // Setup animations
            this.setupAnimations();

            console.log('Studio App Pro initialized successfully');
        } catch (error) {
            console.error('Failed to initialize Studio App Pro:', error);
            if (error && error.stack) {
                console.error(error.stack);
            } else {
                try { console.error(String(error)); } catch (e) { /* ignore */ }
            }
            this.showError('Failed to initialize studio. Check console for details.');
        }
    }

    loadCloudConfig() {
        const config = localStorage.getItem('aikings_cloud_config');
        if (config) {
            try {
                this.cloudConfig = JSON.parse(config);
            } catch (error) {
                console.error('Failed to parse cloud config:', error);
                this.cloudConfig = null;
            }
        }
    }

    configureCloudEndpoint() {
        if (this.cloudConfig && this.cloudConfig.service === 'vastai') {
            // Use Vast.ai
            if (!this.cloudConfig.apiKey) {
                console.error('Vast.ai API key not configured. Please set up your API key.');
                this.showError('Vast.ai API key is required. Please configure it in settings.');
                return;
            }
            this.comfyUI.setEndpoint('/api/proxy', {
                serviceType: 'vastai',
                apiKey: this.cloudConfig.apiKey
            });
            console.log('Connected to Vast.ai');
        } else {
            // Require user to configure API key - don't use hard-coded defaults
            console.warn('No cloud config found. Please configure your Vast.ai API key in settings.');
            this.showError('Please configure your Vast.ai API key in settings to continue.');
            console.log('Auto-connected to Vast.ai with provided API key');
        }
    }

    bindEvents() {
        // Generate button
        if (this.generateBtn) {
            this.generateBtn.addEventListener('click', () => this.generateContent());
        }

        // Workflow selector buttons
        document.querySelectorAll('.workflow-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('.workflow-btn').forEach(b => {
                    b.classList.remove('active');
                    b.style.background = 'transparent';
                    b.style.color = 'rgba(255,255,255,0.6)';
                    b.style.borderColor = 'rgba(255,255,255,0.1)';
                });
                btn.classList.add('active');
                btn.style.background = 'rgba(255,255,255,0.1)';
                btn.style.color = 'white';
                btn.style.borderColor = 'rgba(255,255,255,0.2)';
                console.log('Workflow changed to:', btn.getAttribute('data-type'));
            });
        });

        // Enter key on prompt input
        if (this.promptInput) {
            this.promptInput.addEventListener('keydown', (e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    this.generateContent();
                }
            });
        }

        // Sidebar navigation
        this.setupSidebarNavigation();
    }

    setupSidebarNavigation() {
        // Studio button
        const studioBtn = document.querySelector('.nav-item[data-tooltip*="Studio"]');
        if (studioBtn) {
            studioBtn.addEventListener('click', () => {
                const heroStudio = document.querySelector('.hero-studio-wrapper');
                if (heroStudio) {
                    heroStudio.scrollIntoView({ behavior: 'smooth', block: 'start' });
                }
            });
        }

        // Collection button
        const collectionBtn = document.querySelector('.nav-item[data-tooltip*="Collection"]');
        if (collectionBtn) {
            collectionBtn.addEventListener('click', () => {
                const collection = document.getElementById('main-gallery');
                if (collection) {
                    collection.scrollIntoView({ behavior: 'smooth', block: 'start' });
                    this.updateActiveNavItem(collectionBtn);
                }
            });
        }

        // Settings button
        const settingsBtn = document.querySelector('.nav-item[data-tooltip*="Settings"]');
        if (settingsBtn) {
            settingsBtn.addEventListener('click', () => this.openSettings());
        }

        // Settings modal events
        this.bindSettingsEvents();

        // Update active state on nav clicks
        document.querySelectorAll('.nav-item').forEach(item => {
            item.addEventListener('click', (e) => {
                // Don't update if clicking muse button (handled by muse manager)
                if (e.currentTarget.id !== 'btn-muse-panel') {
                    this.updateActiveNavItem(e.currentTarget);
                }
            });
        });
    }

    async checkServerTokens() {
        try {
            const r = await fetch('/api/proxy/check-tokens');
            if (!r.ok) return;
            const info = await r.json();
            if (!info.huggingface || !info.civitai) {
                const msg = `Server tokens: HuggingFace=${info.huggingface ? 'OK' : 'MISSING'}, Civitai=${info.civitai ? 'OK' : 'MISSING'}`;
                console.warn(msg);
                // Show non-blocking banner for admins
                const banner = document.createElement('div');
                banner.className = 'proxy-token-warning';
                banner.style = 'background:#f8d7da;color:#721c24;padding:10px;margin-bottom:10px;border-radius:6px;';
                banner.textContent = 'Proxy tokens missing: set HUGGINGFACE_HUB_TOKEN and/or CIVITAI_TOKEN on the server for automated model installs.';
                const container = document.querySelector('#studio-controls') || document.body;
                container.prepend(banner);
            } else {
                console.log('Server tokens are present for model downloads');
            }
        } catch (error) {
            console.warn('Failed to check server tokens:', error);
        }
    }

    updateActiveNavItem(activeItem) {
        document.querySelectorAll('.nav-item').forEach(nav => nav.classList.remove('active'));
        activeItem.classList.add('active');
    }

    setupAnimations() {
        if (typeof gsap !== 'undefined') {
            gsap.from(".studio-sidebar", { x: -50, opacity: 0, duration: 0.8, ease: "power2.out" });
            gsap.from(".studio-dock", { y: 50, opacity: 0, duration: 0.8, delay: 0.2, ease: "power2.out" });
        }
    }

    async generateContent() {
        if (this.isGenerating) return;

        const prompt = this.promptInput?.value?.trim();
        if (!prompt) {
            this.showError('Please enter a prompt');
            return;
        }

        const activeMuse = this.museManager.getActiveMuse();
        const activeVariation = this.museManager.getActiveVariation();

        if (!activeMuse) {
            this.showWarning('No character selected. Generating without character context.');
        }

        this.isGenerating = true;
        this.updateGenerateButton('generating');

        try {
            // Generate with ComfyUI
            const result = await this.generateWithComfyUI(activeMuse, prompt, activeVariation);

            // Show result
            await this.displayResult(result);

            // Add to history
            if (activeMuse && result.imageUrl) {
                activeMuse.addToHistory({
                    prompt: prompt,
                    imageUrl: result.imageUrl,
                    settings: result.settings
                });
                this.museManager.save();
            }

            this.showSuccess('Generation complete!');

        } catch (error) {
            console.error('Generation failed:', error);
            this.showError(error.message || 'Generation failed. Check console for details.');
        } finally {
            this.isGenerating = false;
            this.updateGenerateButton('idle');
        }
    }

    async generateWithComfyUI(muse, userPrompt, variationId = null) {
        try {
            // Ensure GPU is ready before starting generation (auto-prewarm if needed)
            await this.ensureGPUReady();

            // Build request payload for new backend endpoint
            const workflowType = this.getWorkflowType(); // 'image' or 'video' from UI toggle

            const payload = {
                muse: muse ? {
                    id: muse.id,
                    name: muse.name,
                    basic: muse.basic,
                    body: muse.body,
                    face: muse.face,
                    style: muse.style,
                    aiSettings: muse.aiSettings
                } : null,
                prompt: muse ? muse.generatePrompt(userPrompt, variationId) : userPrompt,
                negativePrompt: muse ? muse.generateNegativePrompt() : 'ugly, deformed, bad anatomy',
                settings: {
                    width: 512,
                    height: 768,
                    steps: muse?.aiSettings?.steps || 25,
                    cfgScale: muse?.aiSettings?.cfgScale || 7,
                    seed: Math.floor(Math.random() * 1000000000),
                    sampler: muse?.aiSettings?.sampler || 'euler_ancestral',
                    checkpoint: muse?.aiSettings?.preferredCheckpoint || 'dreamshaper_8.safetensors',
                    frames: workflowType === 'video' ? 16 : undefined,
                    fps: workflowType === 'video' ? 8 : undefined
                },
                workflowType
            };

            // Submit to generation handler
            const response = await fetch('/api/proxy/generate', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });

            if (!response.ok) {
                const error = await response.json();
                throw new Error(error.error || 'Generation failed');
            }

            const { jobId, estimatedTime } = await response.json();
            console.log(`Generation job started: ${jobId}`);

            // Show estimated time to user
            this.showInfo(`Generating ${workflowType}... Estimated time: ${estimatedTime}`);

            // Poll for completion
            return await this.pollJobStatus(jobId);

        } catch (error) {
            console.error('Generation error:', error);
            this.showError(`Generation failed: ${error.message}`);
            throw error; // No more mock fallback
        }
    }

    /**
     * Poll job status until complete
     */
    async pollJobStatus(jobId, maxAttempts = 120) {
        const progressContainer = document.getElementById('generation-progress-container');
        const progressFill = document.getElementById('generation-progress-fill');
        const progressText = document.getElementById('generation-progress-text');

        if (progressContainer) {
            progressContainer.style.display = 'flex';
            if (typeof gsap !== 'undefined') {
                gsap.fromTo(progressContainer, { opacity: 0 }, { opacity: 1, duration: 0.3 });
            }
        }

        for (let i = 0; i < maxAttempts; i++) {
            await new Promise(resolve => setTimeout(resolve, 3000)); // 3 second intervals

            try {
                const response = await fetch(`/api/proxy/generate/${jobId}`);

                if (!response.ok) {
                    throw new Error(`Status check failed: ${response.status}`);
                }

                const status = await response.json();

                // Update UI with progress
                this.updateGenerateButton('generating',
                    `${status.workflowType === 'video' ? 'Rendering video' : 'Generating image'}... ${status.progress}%`
                );

                if (progressFill) progressFill.style.width = `${status.progress}%`;
                if (progressText) progressText.textContent = `${status.workflowType === 'video' ? 'RENDERING' : 'GENERATING'}... ${status.progress}%`;

                if (status.status === 'completed') {
                    if (progressContainer) {
                        if (typeof gsap !== 'undefined') {
                            await gsap.to(progressContainer, { opacity: 0, duration: 0.3 }).vars.onComplete;
                        }
                        progressContainer.style.display = 'none';
                    }
                    return {
                        success: true,
                        imageUrl: status.result.url,
                        thumbnailUrl: status.result.thumbnailUrl,
                        settings: status.result.metadata,
                        workflowType: status.workflowType
                    };
                }

                if (status.status === 'failed') {
                    if (progressContainer) progressContainer.style.display = 'none';

                    // Handle GPU-specific errors with actionable message
                    if (status.errorCode === 'NO_GPU_AVAILABLE' && status.errorDetails?.canPrewarm) {
                        throw new Error('No GPU available. The system will auto-start one on your next attempt.');
                    }

                    throw new Error(status.error || 'Generation failed');
                }

                // Continue polling if pending or processing

            } catch (error) {
                console.error(`Polling attempt ${i + 1} failed:`, error);
                if (i === maxAttempts - 1) {
                    if (progressContainer) progressContainer.style.display = 'none';
                    throw error;
                }
            }
        }

        if (progressContainer) progressContainer.style.display = 'none';
        throw new Error('Generation timeout after 6 minutes');
    }

    /**
     * Get workflow type from UI (image or video)
     */
    getWorkflowType() {
        const activeBtn = document.querySelector('.workflow-btn.active');
        return activeBtn ? activeBtn.getAttribute('data-type') : 'image';
    }

    async tryClaimWarmPool() {
        try {
            const r = await fetch('/api/proxy/warm-pool/claim', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ maxSessionMinutes: 30 })
            });
            if (!r.ok) {
                const err = await r.json().catch(() => ({}));
                console.warn('Warm claim not available', err);
                return null;
            }
            const claim = await r.json();
            this.showInfo('Warm instance claimed — attaching to session.');
            return claim;
        } catch (error) {
            console.error('tryClaimWarmPool error:', error);
            return null;
        }
    }

    /**
     * Check GPU availability status
     */
    async checkGPUStatus() {
        try {
            const response = await fetch('/api/proxy/gpu-status');
            if (!response.ok) {
                return { canGenerate: false, canPrewarm: true, status: 'unavailable', message: 'Unable to check GPU status' };
            }
            return await response.json();
        } catch (error) {
            console.error('GPU status check failed:', error);
            return { canGenerate: false, canPrewarm: true, status: 'unavailable', message: 'Unable to check GPU status' };
        }
    }

    /**
     * Ensure GPU is ready for generation, auto-prewarming if necessary
     */
    async ensureGPUReady() {
        const status = await this.checkGPUStatus();

        if (status.canGenerate) {
            console.log('[GPU] Instance ready for generation');
            return;
        }

        // GPU not ready - need to prewarm or wait
        if (status.canPrewarm) {
            // No instance available - start prewarming
            this.showInfo('Starting GPU instance... This may take 2-5 minutes.');
            this.updateGenerateButton('generating', 'Starting GPU...');

            try {
                const prewarmRes = await fetch('/api/proxy/warm-pool/prewarm', { method: 'POST' });
                if (!prewarmRes.ok) {
                    const error = await prewarmRes.json();
                    throw new Error(error.error || 'Failed to start GPU instance');
                }
                console.log('[GPU] Prewarm initiated');
            } catch (error) {
                console.error('[GPU] Prewarm failed:', error);
                throw new Error('Failed to start GPU instance: ' + error.message);
            }
        } else {
            // Instance is starting/initializing - just need to wait
            this.showInfo(status.message + (status.estimatedReadyTime ? ` (${status.estimatedReadyTime})` : ''));
            this.updateGenerateButton('generating', status.message);
        }

        // Poll until ready (max 5 minutes)
        const maxWaitMs = 5 * 60 * 1000;
        const pollIntervalMs = 5000;
        const startTime = Date.now();

        while (Date.now() - startTime < maxWaitMs) {
            await new Promise(r => setTimeout(r, pollIntervalMs));

            const newStatus = await this.checkGPUStatus();

            if (newStatus.canGenerate) {
                this.showSuccess('GPU instance is ready!');
                console.log('[GPU] Instance ready after waiting');
                return;
            }

            // Update progress message
            if (newStatus.status === 'starting') {
                this.updateGenerateButton('generating', 'GPU starting...');
            } else if (newStatus.status === 'initializing') {
                this.updateGenerateButton('generating', 'Initializing ComfyUI...');
            } else if (newStatus.status === 'prewarming') {
                this.updateGenerateButton('generating', 'Preparing GPU...');
            }
        }

        throw new Error('GPU instance startup timed out after 5 minutes. Please try again.');
    }

    async pollComfyUIStatus(response) {
        const promptId = response.prompt_id;
        const maxAttempts = 120; // 10 minutes max
        let attempts = 0;

        return new Promise((resolve, reject) => {
            const poll = async () => {
                try {
                    const history = await this.comfyUI.getHistory(promptId);

                    if (history[promptId]) {
                        const status = history[promptId].status;

                        if (status.completed) {
                            // Get output images
                            const outputs = history[promptId].outputs;
                            const imageNodes = Object.keys(outputs).filter(key =>
                                outputs[key].images && outputs[key].images.length > 0
                            );

                            if (imageNodes.length > 0) {
                                const firstImage = outputs[imageNodes[0]].images[0];
                                const imageUrl = await this.comfyUI.getImage(
                                    firstImage.filename,
                                    firstImage.subfolder,
                                    firstImage.type
                                );

                                resolve({
                                    success: true,
                                    imageUrl: imageUrl,
                                    settings: { promptId }
                                });
                                return;
                            }
                        } else if (status.error) {
                            reject(new Error('ComfyUI generation failed: ' + status.error));
                            return;
                        }
                    }

                    attempts++;
                    if (attempts >= maxAttempts) {
                        reject(new Error('Generation timed out'));
                        return;
                    }

                    // Poll again after 5 seconds
                    setTimeout(poll, 5000);

                } catch (error) {
                    reject(error);
                }
            };

            poll();
        });
    }

    async mockGeneration(muse, userPrompt) {
        // Mock generation with delay
        console.log('Using mock generation (ComfyUI not available)');

        const stages = [
            { message: 'Initializing...', progress: 10 },
            { message: 'Building prompt...', progress: 25 },
            { message: 'Generating...', progress: 50 },
            { message: 'Processing...', progress: 75 },
            { message: 'Finalizing...', progress: 90 }
        ];

        for (const stage of stages) {
            this.updateGenerateButton('generating', stage.message);
            await new Promise(resolve => setTimeout(resolve, 1000));
        }

        // Return placeholder result
        return {
            success: true,
            imageUrl: 'assets/images/ai-kings-og.jpg', // Placeholder
            settings: { mock: true }
        };
    }

    async displayResult(result) {
        if (!this.stage) return;

        const emptyState = this.stage.querySelector('.empty-stage-state');
        const activeContent = this.stage.querySelector('.active-content');
        const img = document.getElementById('stage-image');
        const video = document.getElementById('stage-video');

        if (emptyState) emptyState.style.display = 'none';
        if (activeContent) activeContent.style.display = 'flex';

        if (result.workflowType === 'video') {
            if (img) img.style.display = 'none';
            if (video) {
                video.src = result.imageUrl;
                video.style.display = 'block';
                video.play().catch(e => console.warn('Autoplay failed:', e));
                
                if (typeof gsap !== 'undefined') {
                    gsap.from(video, { scale: 0.95, opacity: 0, duration: 0.5 });
                }
            }
        } else if (img && result.imageUrl) {
            if (video) video.style.display = 'none';
            img.src = result.imageUrl;
            img.style.display = 'block';

            // Animate entrance
            if (typeof gsap !== 'undefined') {
                gsap.from(img, { scale: 0.95, opacity: 0, duration: 0.5 });
            }
        }
    }

    updateGenerateButton(state, message = '') {
        if (!this.generateBtn) return;

        switch (state) {
            case 'generating':
                this.generateBtn.disabled = true;
                this.generateBtn.innerHTML = `
                    <span>
                        <i class="ph ph-spinner ph-spin"></i>
                        ${message || 'Dreaming...'}
                    </span>
                `;
                break;

            case 'idle':
            default:
                this.generateBtn.disabled = false;
                this.generateBtn.innerHTML = '<span>Manifest</span>';
                break;
        }
    }

    openSettings() {
        const modal = document.getElementById('settings-modal');
        if (!modal) {
            console.error('Settings modal not found');
            return;
        }

        // Load current values
        const serviceSelect = modal.querySelector('#cloud-service-select');
        const apiKeyInput = modal.querySelector('#vastai-api-key');
        const localEndpointInput = modal.querySelector('#local-comfyui-endpoint');

        // Set current service
        if (this.cloudConfig && this.cloudConfig.service) {
            serviceSelect.value = this.cloudConfig.service;
        } else {
            serviceSelect.value = 'local';
        }

        // Set API key if available
        if (this.cloudConfig && this.cloudConfig.apiKey) {
            apiKeyInput.value = this.cloudConfig.apiKey;
        } else {
            apiKeyInput.value = '';
        }

        // Set local endpoint
        const localEndpoint = localStorage.getItem('comfyui_endpoint') || 'http://127.0.0.1:8188';
        localEndpointInput.value = localEndpoint;

        // Show modal
        modal.style.display = 'flex';
        modal.classList.add('active');
    }

    bindSettingsEvents() {
        const modal = document.getElementById('settings-modal');
        if (!modal) return;

        // Close modal events
        const closeBtn = modal.querySelector('.modal-close');
        const cancelBtn = modal.querySelector('#settings-cancel');
        const backdrop = modal.querySelector('.modal-backdrop');

        [closeBtn, cancelBtn, backdrop].forEach(el => {
            if (el) {
                el.addEventListener('click', () => {
                    modal.style.display = 'none';
                    modal.classList.remove('active');
                });
            }
        });

        // Save settings
        const saveBtn = modal.querySelector('#settings-save');
        if (saveBtn) {
            saveBtn.addEventListener('click', () => this.saveSettings());
        }

        // Service change handler
        const serviceSelect = modal.querySelector('#cloud-service-select');
        if (serviceSelect) {
            serviceSelect.addEventListener('change', (e) => {
                const vastaiSection = modal.querySelector('#vastai-settings');
                if (e.target.value === 'vastai') {
                    vastaiSection.style.display = 'block';
                } else {
                    vastaiSection.style.display = 'none';
                }
            });
        }

        // Vast.ai instance controls
        const startInstanceBtn = modal.querySelector('#start-vastai-instance');
        const stopInstanceBtn = modal.querySelector('#stop-vastai-instance');

        if (startInstanceBtn) {
            startInstanceBtn.addEventListener('click', async () => {
                try {
                    this.updateInstanceStatus('Starting Vast.ai instance...');
                    await this.comfyUI.startVastAIInstance();
                    this.updateInstanceStatus('Vast.ai instance started successfully');
                    this.showSuccess('Vast.ai instance started!');
                } catch (error) {
                    console.error('Failed to start Vast.ai instance:', error);
                    this.updateInstanceStatus('Failed to start instance');
                    this.showError('Failed to start Vast.ai instance: ' + error.message);
                }
            });
        }

        if (stopInstanceBtn) {
            stopInstanceBtn.addEventListener('click', async () => {
                try {
                    this.updateInstanceStatus('Stopping Vast.ai instance...');
                    await this.comfyUI.stopVastAIInstance();
                    this.updateInstanceStatus('Vast.ai instance stopped');
                    this.showSuccess('Vast.ai instance stopped!');
                } catch (error) {
                    console.error('Failed to stop Vast.ai instance:', error);
                    this.updateInstanceStatus('Failed to stop instance');
                    this.showError('Failed to stop Vast.ai instance: ' + error.message);
                }
            });
        }

        // Warm Pool controls
        const warmPoolStatusText = modal.querySelector('#warm-pool-status-text');
        const warmPoolPrewarm = modal.querySelector('#warm-pool-prewarm');
        const warmPoolTerminate = modal.querySelector('#warm-pool-terminate');

        this.warmPoolInfo = null;

        this.updateWarmPoolStatus = async () => {
            try {
                const r = await fetch('http://localhost:3000/api/proxy/warm-pool');
                if (!r.ok) return;
                const data = await r.json();
                this.warmPoolInfo = data;
                const status = (data.instance && data.instance.status) ? data.instance.status : 'empty';
                warmPoolStatusText.textContent = status;
            } catch (e) {
                console.error('Failed to update warm pool status:', e);
            }
        };

        if (warmPoolPrewarm) {
            warmPoolPrewarm.addEventListener('click', async () => {
                try {
                    warmPoolPrewarm.disabled = true;
                    this.showInfo('Scheduling warm instance...');
                    const r = await fetch('http://localhost:3000/api/proxy/warm-pool/prewarm', { method: 'POST' });
                    if (!r.ok) throw new Error('prewarm failed');
                    this.showSuccess('Warm instance requested. It may take a few minutes.');
                    await this.updateWarmPoolStatus();
                } catch (e) {
                    console.error(e);
                    this.showError('Warm prewarm failed');
                } finally {
                    warmPoolPrewarm.disabled = false;
                }
            });
        }

        if (warmPoolTerminate) {
            warmPoolTerminate.addEventListener('click', async () => {
                try {
                    if (!this.warmPoolInfo || !this.warmPoolInfo.instance || !this.warmPoolInfo.instance.contractId) {
                        this.showWarning('No warm instance to terminate');
                        return;
                    }
                    warmPoolTerminate.disabled = true;
                    const body = JSON.stringify({ instanceId: this.warmPoolInfo.instance.contractId });
                    const r = await fetch('http://localhost:3000/api/proxy/warm-pool/terminate', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body });
                    if (!r.ok) throw new Error('terminate failed');
                    this.showSuccess('Warm instance terminated');
                    await this.updateWarmPoolStatus();
                } catch (e) {
                    console.error(e);
                    this.showError('Warm terminate failed');
                } finally {
                    warmPoolTerminate.disabled = false;
                }
            });
        }

        // Start polling warm pool status every 15s
        try { this.updateWarmPoolStatus(); } catch(e){}
        if (!this.warmPoolPollHandle) this.warmPoolPollHandle = setInterval(() => this.updateWarmPoolStatus(), 15000);
    }

    async saveSettings() {
        const modal = document.getElementById('settings-modal');
        const serviceSelect = modal.querySelector('#cloud-service-select');
        const apiKeyInput = modal.querySelector('#vastai-api-key');
        const localEndpointInput = modal.querySelector('#local-comfyui-endpoint');

        const service = serviceSelect.value;
        const apiKey = apiKeyInput.value.trim();
        const localEndpoint = localEndpointInput.value.trim();

        // Validate inputs
        if (service === 'vastai' && !apiKey) {
            this.showError('Vast.ai API key is required');
            return;
        }

        if (service === 'local' && !localEndpoint) {
            this.showError('Local ComfyUI endpoint is required');
            return;
        }

        // Save configuration
        if (service === 'vastai') {
            this.cloudConfig = {
                service: 'vastai',
                apiKey: apiKey
            };
            localStorage.setItem('aikings_cloud_config', JSON.stringify(this.cloudConfig));
            this.comfyUI.setEndpoint('http://localhost:3000/api/proxy', {
                serviceType: 'vastai',
                apiKey: apiKey
            });
        } else {
            // Local service
            localStorage.setItem('comfyui_endpoint', localEndpoint);
            this.comfyUI.setEndpoint(localEndpoint);
            // Clear cloud config
            this.cloudConfig = null;
            localStorage.removeItem('aikings_cloud_config');
        }

        // Close modal
        modal.style.display = 'none';
        modal.classList.remove('active');

        // Update cloud status indicator
        this.updateCloudStatus();

        this.showSuccess('Settings saved successfully!');
    }

    updateInstanceStatus(message) {
        const statusEl = document.getElementById('vastai-instance-status');
        if (statusEl) {
            statusEl.textContent = message;
        }
    }

    updateCloudStatus() {
        const statusDot = document.getElementById('status-dot');
        const statusText = document.getElementById('status-text');

        if (!statusDot || !statusText) return;

        if (this.cloudConfig && this.cloudConfig.service === 'vastai') {
            statusDot.className = 'status-dot connected';
            statusText.textContent = 'Vast.ai';
        } else {
            statusDot.className = 'status-dot error';
            statusText.textContent = 'Local';
        }
    }

    showSuccess(message) {
        this.showNotification(message, 'success');
    }

    showError(message) {
        this.showNotification(message, 'error');
    }

    showWarning(message) {
        this.showNotification(message, 'warning');
    }

    showInfo(message) {
        this.showNotification(message, 'info');
    }

    showNotification(message, type = 'info') {
        const notification = document.createElement('div');
        notification.className = `studio-notification ${type}`;

        const icons = {
            success: '✓',
            error: '✕',
            warning: '⚠',
            info: 'ℹ'
        };

        notification.innerHTML = `
            <div class="notification-content">
                <span class="notification-icon">${icons[type] || icons.info}</span>
                <span class="notification-message">${message}</span>
            </div>
        `;

        notification.style.cssText = `
            position: fixed;
            top: 2rem;
            right: 2rem;
            background: ${this.getNotificationColor(type)};
            color: ${type === 'success' ? '#000' : '#fff'};
            padding: 1rem 1.5rem;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
            z-index: 10000;
            animation: slideIn 0.3s ease;
            font-weight: 500;
        `;

        document.body.appendChild(notification);

        setTimeout(() => {
            notification.style.animation = 'slideOut 0.3s ease';
            setTimeout(() => notification.remove(), 300);
        }, 5000);
    }

    getNotificationColor(type) {
        const colors = {
            success: '#d4af37',
            error: '#c41e3a',
            warning: '#ff9800',
            info: '#2196F3'
        };
        return colors[type] || colors.info;
    }
}

// Add notification animations
const notificationStyles = document.createElement('style');
notificationStyles.textContent = `
    @keyframes slideIn {
        from { transform: translateX(100%); opacity: 0; }
        to { transform: translateX(0); opacity: 1; }
    }

    @keyframes slideOut {
        from { transform: translateX(0); opacity: 1; }
        to { transform: translateX(100%); opacity: 0; }
    }

    .notification-content {
        display: flex;
        align-items: center;
        gap: 0.75rem;
    }

    .notification-icon {
        font-size: 1.25rem;
        font-weight: bold;
    }
`;
document.head.appendChild(notificationStyles);

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.studioAppPro = new StudioAppPro();
});
