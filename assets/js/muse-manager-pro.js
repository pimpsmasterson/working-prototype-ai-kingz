/**
 * AI KINGS - Professional Muse Management System
 * Comprehensive character creation and management for adult content AI generation
 * Designed for ComfyUI integration with reference images and advanced features
 */

// ============================================================================
// MUSE DATA MODEL
// ============================================================================

class MuseProfile {
    constructor(data = {}) {
        // Core Identity
        this.id = data.id || 'muse_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
        this.name = data.name || 'New Character';
        this.createdAt = data.createdAt || new Date().toISOString();
        this.updatedAt = data.updatedAt || new Date().toISOString();

        // Categories & Organization
        this.category = data.category || 'general'; // general, fantasy, celebrity-inspired, etc.
        this.tags = data.tags || [];
        this.isFavorite = data.isFavorite || false;
        this.isArchived = data.isArchived || false;

        // Basic Information
        this.basic = {
            age: data.basic?.age || '25',
            ageAppearance: data.basic?.ageAppearance || '25', // How old they appear vs actual age
            nationality: data.basic?.nationality || '',
            ethnicity: data.basic?.ethnicity || '',
            occupation: data.basic?.occupation || '', // For context in scenarios
        };

        // Physical Attributes - Body
        this.body = {
            height: data.body?.height || 'average', // petite, short, average, tall, very-tall
            heightCm: data.body?.heightCm || '', // Optional specific height
            build: data.body?.build || 'athletic', // petite, slim, athletic, curvy, voluptuous, muscular, plus-size
            bodyShape: data.body?.bodyShape || 'hourglass', // hourglass, pear, apple, rectangle, triangle
            skinTone: data.body?.skinTone || 'fair', // pale, fair, medium, olive, tan, brown, dark
            skinTexture: data.body?.skinTexture || 'smooth', // smooth, freckled, tattooed, scarred

            // Measurements (optional for precision)
            bust: data.body?.bust || '',
            bustCup: data.body?.bustCup || '', // For female characters
            waist: data.body?.waist || '',
            hips: data.body?.hips || '',

            // Additional details
            muscleTone: data.body?.muscleTone || 'toned', // soft, toned, athletic, muscular
            bodyHair: data.body?.bodyHair || 'minimal', // none, minimal, natural, abundant
        };

        // Physical Attributes - Face & Head
        this.face = {
            faceShape: data.face?.faceShape || 'oval', // oval, round, square, heart, diamond
            eyeColor: data.face?.eyeColor || 'brown',
            eyeShape: data.face?.eyeShape || 'almond', // almond, round, hooded, upturned, downturned
            eyeSize: data.face?.eyeSize || 'medium',

            hairColor: data.face?.hairColor || 'brown',
            hairLength: data.face?.hairLength || 'long', // pixie, short, shoulder, long, very-long
            hairStyle: data.face?.hairStyle || 'straight', // straight, wavy, curly, braided, updo
            hairTexture: data.face?.hairTexture || 'smooth',

            lips: data.face?.lips || 'full', // thin, medium, full, plump
            lipColor: data.face?.lipColor || 'natural',

            nose: data.face?.nose || 'average', // small, average, prominent, button, aquiline
            jawline: data.face?.jawline || 'defined', // soft, defined, sharp, strong
            cheekbones: data.face?.cheekbones || 'high', // subtle, moderate, high, prominent

            facialHair: data.face?.facialHair || 'none', // For male characters
            makeup: data.face?.makeup || 'natural', // none, natural, glamorous, dramatic, gothic
        };

        // Distinguishing Features
        this.features = {
            tattoos: data.features?.tattoos || [], // Array of {location, description, size}
            piercings: data.features?.piercings || [], // Array of {location, type}
            scars: data.features?.scars || [],
            birthmarks: data.features?.birthmarks || '',
            accessories: data.features?.accessories || [], // Jewelry, glasses, etc.
            uniqueTraits: data.features?.uniqueTraits || '', // Dimples, beauty marks, etc.
        };

        // Style & Preferences
        this.style = {
            fashionStyle: data.style?.fashionStyle || 'casual', // casual, elegant, sporty, gothic, punk, etc.
            preferredOutfits: data.style?.preferredOutfits || [], // Array of outfit descriptions
            lingerie: data.style?.lingerie || '', // Preferred lingerie style
            footwear: data.style?.footwear || '',
            nails: data.style?.nails || 'natural', // natural, manicured, long, painted

            // Context for generation
            personality: data.style?.personality || '', // Confident, shy, playful, dominant, etc.
            vibe: data.style?.vibe || 'sensual', // sensual, romantic, fierce, playful, etc.
        };

        // AI Generation Settings
        this.aiSettings = {
            // Reference Images
            referenceImages: data.aiSettings?.referenceImages || [], // Array of {url, type, weight}
            primaryReference: data.aiSettings?.primaryReference || null,

            // Model-Specific
            loraModels: data.aiSettings?.loraModels || [], // {name, weight, trigger}
            embeddings: data.aiSettings?.embeddings || [], // {name, trigger}
            controlNetSettings: data.aiSettings?.controlNetSettings || null,
            ipAdapterSettings: data.aiSettings?.ipAdapterSettings || null,

            // Prompt Templates
            positivePromptPrefix: data.aiSettings?.positivePromptPrefix || '',
            negativePromptAdditions: data.aiSettings?.negativePromptAdditions || '',
            qualityTags: data.aiSettings?.qualityTags || 'masterpiece, best quality, high resolution, detailed',
            styleTags: data.aiSettings?.styleTags || '',

            // Generation Preferences
            preferredCheckpoint: data.aiSettings?.preferredCheckpoint || '',
            preferredVAE: data.aiSettings?.preferredVAE || '',
            sampler: data.aiSettings?.sampler || 'DPM++ 2M Karras',
            steps: data.aiSettings?.steps || 30,
            cfgScale: data.aiSettings?.cfgScale || 7,

            // ComfyUI Workflow
            customWorkflow: data.aiSettings?.customWorkflow || null, // Custom ComfyUI workflow JSON
            workflowTemplate: data.aiSettings?.workflowTemplate || 'default',
        };

        // Variations
        this.variations = data.variations || []; // Array of {id, name, description, overrides}

        // Generation History
        this.generationHistory = data.generationHistory || []; // Array of {timestamp, prompt, imageUrl, settings}

        // Notes
        this.notes = data.notes || '';
    }

    // Generate AI prompt from muse profile
    generatePrompt(userPrompt = '', variation = null) {
        const parts = [];

        // Apply variation overrides if specified
        const profile = variation ? this.applyVariation(variation) : this;

        // Quality tags first
        if (profile.aiSettings.qualityTags) {
            parts.push(profile.aiSettings.qualityTags);
        }

        // Character description
        const charDesc = this.buildCharacterDescription(profile);
        parts.push(charDesc);

        // Style tags
        if (profile.aiSettings.styleTags) {
            parts.push(profile.aiSettings.styleTags);
        }

        // Positive prefix (custom tags from user)
        if (profile.aiSettings.positivePromptPrefix) {
            parts.push(profile.aiSettings.positivePromptPrefix);
        }

        // User's scene description
        if (userPrompt) {
            parts.push(userPrompt);
        }

        return parts.join(', ');
    }

    buildCharacterDescription(profile) {
        const desc = [];

        // Name and basic identity
        desc.push(`${profile.name}`);

        // Age appearance
        if (profile.basic.ageAppearance) {
            desc.push(`${profile.basic.ageAppearance} years old`);
        }

        // Ethnicity/Nationality
        if (profile.basic.ethnicity) {
            desc.push(profile.basic.ethnicity);
        }

        // Body description
        const bodyDesc = [];
        if (profile.body.height && profile.body.height !== 'average') {
            bodyDesc.push(profile.body.height);
        }
        if (profile.body.build) {
            bodyDesc.push(profile.body.build);
        }
        if (profile.body.bodyShape) {
            bodyDesc.push(`${profile.body.bodyShape} figure`);
        }
        if (bodyDesc.length > 0) {
            desc.push(bodyDesc.join(' '));
        }

        // Measurements (if specified)
        if (profile.body.bust && profile.body.waist && profile.body.hips) {
            desc.push(`${profile.body.bust}-${profile.body.waist}-${profile.body.hips}`);
        } else if (profile.body.bustCup) {
            desc.push(`${profile.body.bustCup} cup`);
        }

        // Skin
        if (profile.body.skinTone) {
            desc.push(`${profile.body.skinTone} skin`);
        }

        // Hair
        if (profile.face.hairLength && profile.face.hairColor && profile.face.hairStyle) {
            desc.push(`${profile.face.hairLength} ${profile.face.hairColor} ${profile.face.hairStyle} hair`);
        }

        // Eyes
        if (profile.face.eyeColor && profile.face.eyeShape) {
            desc.push(`${profile.face.eyeShape} ${profile.face.eyeColor} eyes`);
        }

        // Face features
        if (profile.face.lips && profile.face.lips !== 'medium') {
            desc.push(`${profile.face.lips} lips`);
        }

        // Makeup
        if (profile.face.makeup && profile.face.makeup !== 'none') {
            desc.push(`${profile.face.makeup} makeup`);
        }

        // Tattoos
        if (profile.features.tattoos && profile.features.tattoos.length > 0) {
            const tattooDesc = profile.features.tattoos.map(t =>
                `${t.description} tattoo on ${t.location}`
            ).join(', ');
            desc.push(tattooDesc);
        }

        // Piercings
        if (profile.features.piercings && profile.features.piercings.length > 0) {
            const piercingDesc = profile.features.piercings.map(p =>
                `${p.location} piercing`
            ).join(', ');
            desc.push(piercingDesc);
        }

        // Unique traits
        if (profile.features.uniqueTraits) {
            desc.push(profile.features.uniqueTraits);
        }

        // Fashion style / outfit context
        if (profile.style.fashionStyle) {
            desc.push(`${profile.style.fashionStyle} style`);
        }

        return desc.join(', ');
    }

    generateNegativePrompt() {
        const negative = [
            'ugly', 'deformed', 'disfigured', 'poorly drawn',
            'bad anatomy', 'wrong anatomy', 'extra limb', 'missing limb',
            'floating limbs', 'disconnected limbs', 'mutation', 'mutated',
            'blur', 'blurry', 'text', 'watermark', 'signature',
            'low quality', 'worst quality', 'low resolution'
        ];

        // Add custom negative prompt additions
        if (this.aiSettings.negativePromptAdditions) {
            negative.push(this.aiSettings.negativePromptAdditions);
        }

        return negative.join(', ');
    }

    applyVariation(variationId) {
        const variation = this.variations.find(v => v.id === variationId);
        if (!variation) return this;

        // Create a deep copy and apply overrides
        const modified = JSON.parse(JSON.stringify(this));
        Object.assign(modified, variation.overrides);

        return new MuseProfile(modified);
    }

    addVariation(name, description, overrides) {
        const variation = {
            id: 'var_' + Date.now(),
            name,
            description,
            overrides,
            createdAt: new Date().toISOString()
        };
        this.variations.push(variation);
        this.updatedAt = new Date().toISOString();
        return variation;
    }

    addToHistory(entry) {
        this.generationHistory.unshift({
            id: 'gen_' + Date.now(),
            timestamp: new Date().toISOString(),
            ...entry
        });

        // Keep last 50 generations
        if (this.generationHistory.length > 50) {
            this.generationHistory = this.generationHistory.slice(0, 50);
        }

        this.updatedAt = new Date().toISOString();
    }

    toJSON() {
        return {
            id: this.id,
            name: this.name,
            createdAt: this.createdAt,
            updatedAt: this.updatedAt,
            category: this.category,
            tags: this.tags,
            isFavorite: this.isFavorite,
            isArchived: this.isArchived,
            basic: this.basic,
            body: this.body,
            face: this.face,
            features: this.features,
            style: this.style,
            aiSettings: this.aiSettings,
            variations: this.variations,
            generationHistory: this.generationHistory,
            notes: this.notes
        };
    }

    static fromJSON(json) {
        return new MuseProfile(json);
    }
}

// ============================================================================
// STORAGE MANAGER - IndexedDB for images, localStorage for profiles
// ============================================================================

class MuseStorageManager {
    constructor() {
        this.dbName = 'AIKingsMuseDB';
        this.dbVersion = 1;
        this.db = null;
        this.storeName = 'referenceImages';
    }

    async init() {
        return new Promise((resolve, reject) => {
            const request = indexedDB.open(this.dbName, this.dbVersion);

            request.onerror = () => reject(request.error);
            request.onsuccess = () => {
                this.db = request.result;
                resolve();
            };

            request.onupgradeneeded = (event) => {
                const db = event.target.result;

                // Create object store for reference images
                if (!db.objectStoreNames.contains(this.storeName)) {
                    const objectStore = db.createObjectStore(this.storeName, { keyPath: 'id' });
                    objectStore.createIndex('museId', 'museId', { unique: false });
                }
            };
        });
    }

    async saveReferenceImage(museId, file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();

            reader.onload = async (e) => {
                const imageData = {
                    id: 'img_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9),
                    museId: museId,
                    data: e.target.result,
                    fileName: file.name,
                    fileType: file.type,
                    fileSize: file.size,
                    uploadedAt: new Date().toISOString()
                };

                const transaction = this.db.transaction([this.storeName], 'readwrite');
                const objectStore = transaction.objectStore(this.storeName);
                const request = objectStore.add(imageData);

                request.onsuccess = () => resolve(imageData);
                request.onerror = () => reject(request.error);
            };

            reader.onerror = () => reject(reader.error);
            reader.readAsDataURL(file);
        });
    }

    async getReferenceImages(museId) {
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction([this.storeName], 'readonly');
            const objectStore = transaction.objectStore(this.storeName);
            const index = objectStore.index('museId');
            const request = index.getAll(museId);

            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
        });
    }

    async deleteReferenceImage(imageId) {
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction([this.storeName], 'readwrite');
            const objectStore = transaction.objectStore(this.storeName);
            const request = objectStore.delete(imageId);

            request.onsuccess = () => resolve();
            request.onerror = () => reject(request.error);
        });
    }

    saveMuseProfiles(profiles) {
        const data = profiles.map(p => p.toJSON());
        localStorage.setItem('aiKingsMuseProfiles', JSON.stringify(data));
    }

    loadMuseProfiles() {
        const data = localStorage.getItem('aiKingsMuseProfiles');
        if (!data) return [];

        try {
            const parsed = JSON.parse(data);
            return parsed.map(p => MuseProfile.fromJSON(p));
        } catch (error) {
            console.error('Failed to load muse profiles:', error);
            return [];
        }
    }

    exportProfile(profile, includeImages = false) {
        const exportData = {
            version: '1.0',
            exportedAt: new Date().toISOString(),
            profile: profile.toJSON(),
            images: includeImages ? [] : null // TODO: Include base64 images if requested
        };

        const blob = new Blob([JSON.stringify(exportData, null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `muse_${profile.name.replace(/[^a-z0-9]/gi, '_').toLowerCase()}_${Date.now()}.json`;
        a.click();
        URL.revokeObjectURL(url);
    }

    async importProfile(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();

            reader.onload = (e) => {
                try {
                    const importData = JSON.parse(e.target.result);
                    const profile = MuseProfile.fromJSON(importData.profile);

                    // Generate new ID to avoid conflicts
                    profile.id = 'muse_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
                    profile.createdAt = new Date().toISOString();
                    profile.updatedAt = new Date().toISOString();

                    resolve(profile);
                } catch (error) {
                    reject(error);
                }
            };

            reader.onerror = () => reject(reader.error);
            reader.readAsText(file);
        });
    }
}

// ============================================================================
// COMFYUI INTEGRATION WITH CLOUD SUPPORT
// ============================================================================

class ComfyUIIntegration {
    constructor() {
        this.baseUrl = 'http://127.0.0.1:8188'; // Default ComfyUI endpoint
        this.apiKey = null;
        this.serviceType = 'local'; // 'local', 'vastai'
        this.authHeaders = {};
        this.workflows = {};
        this.vastai = {
            instanceId: null,
            instanceStatus: 'stopped',
            connectionUrl: null,
            lastHealthCheck: null
        };
    }

    // Enhanced endpoint configuration with cloud support
    setEndpoint(url, options = {}) {
        this.baseUrl = url;
        this.serviceType = options.serviceType || 'local';
        this.apiKey = options.apiKey || null;

        // Load saved vastai config if available
        const savedConfig = localStorage.getItem('vastai_config');
        if (savedConfig) {
            try {
                this.vastai = JSON.parse(savedConfig);
                console.log('Loaded saved Vast.ai config:', this.vastai);
            } catch (e) {
                console.error('Failed to parse saved vastai config:', e);
            }
        }

        // Set authentication headers based on service
        this.setAuthHeaders();

        // Initialize cloud service if needed
        if (this.serviceType === 'vastai' && this.apiKey) {
            this.initializeVastAI();
        }
    }

    setAuthHeaders() {
        this.authHeaders = {};

        switch (this.serviceType) {
            case 'vastai':
                if (this.apiKey) {
                    this.authHeaders['Authorization'] = `Bearer ${this.apiKey}`;
                }
                break;
            // Add other services...
        }
    }

    async initializeVastAI() {
        try {
            // Load saved Vast.ai configuration
            const vastConfig = localStorage.getItem('vastai_config');
            if (vastConfig) {
                this.vastai = { ...this.vastai, ...JSON.parse(vastConfig) };
            }

            // Check if we have a running instance
            if (this.vastai.instanceId) {
                await this.checkVastAIInstance();
            }
        } catch (error) {
            console.error('Failed to initialize Vast.ai:', error);
        }
    }

    async checkVastAIInstance() {
        if (!this.vastai.instanceId || !this.apiKey) return;

        try {
            const response = await fetch(`http://localhost:3000/api/proxy/instances/${this.vastai.instanceId}/`, {
                headers: this.authHeaders
            });

            if (response.ok) {
                const instance = await response.json();
                this.vastai.instanceStatus = instance.actual_status;
                this.vastai.lastHealthCheck = new Date().toISOString();

                // Update connection URL if running
                if (instance.actual_status === 'running') {
                    this.vastai.connectionUrl = `http://${instance.public_ipaddr}:${instance.port}`;
                    this.baseUrl = this.vastai.connectionUrl;
                }

                // Save updated config
                localStorage.setItem('vastai_config', JSON.stringify(this.vastai));
            }
        } catch (error) {
            console.error('Vast.ai instance check failed:', error);
            this.vastai.instanceStatus = 'error';
        }
    }

    async startVastAIInstance(templateId = null) {
        if (!this.apiKey) throw new Error('Vast.ai API key required');

        // Prevent concurrent launches
        if (this.vastai.isLaunching) {
            console.warn('An instance launch is already in progress.');
            return null;
        }

        // If an instance ID exists, check its status first
        if (this.vastai.instanceId) {
            await this.checkVastAIInstance();
            if (this.vastai.instanceStatus === 'starting' || this.vastai.instanceStatus === 'running') {
                console.log('Instance already exists and is starting/running:', this.vastai.instanceId);
                return this.vastai.instanceId;
            }
        }

        try {
            // Mark launching state immediately to avoid race conditions
            this.vastai.isLaunching = true;
            this.vastai.instanceStatus = 'starting';
            localStorage.setItem('vastai_config', JSON.stringify(this.vastai));

            // Disable start buttons in UI if present
            try { document.querySelectorAll('#start-vastai-instance').forEach(b => b.disabled = true); } catch(e){}

            console.log('🔍 Searching for available GPU offers...');
            
            // Step 1: Search for available offers
            const searchParams = {
                verified: { eq: true },
                rentable: { eq: true },
                rented: { eq: false },
                type: 'bid',
                dph_total: { lte: 1.0 }, // Max $1/hour
                gpu_ram: { gte: 8192 }, // Min 8GB VRAM
                reliability: { gte: 0.90 },
                order: [['dph_total', 'asc']] // Sort by price
            };

            const searchResponse = await fetch('http://localhost:3000/api/proxy/bundles', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(searchParams)
            });

            if (!searchResponse.ok) {
                throw new Error(`Offer search failed: ${searchResponse.status}`);
            }

            const searchData = await searchResponse.json();
            const offers = searchData.offers || [];
            
            if (offers.length === 0) {
                throw new Error('No suitable GPU offers found');
            }

            const selectedOffer = offers[0];
            console.log(`✅ Selected: ${selectedOffer.gpu_name} for $${selectedOffer.dph_total}/hr`);

            // Step 2: Rent the instance
            const rentResponse = await fetch(`http://localhost:3000/api/proxy/asks/${selectedOffer.id}`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    image: 'pytorch/pytorch:latest',
                    runtype: 'ssh',
                    target_state: 'running',
                    onstart: `
cd /root &&
git clone https://github.com/comfyanonymous/ComfyUI.git &&
cd ComfyUI &&
pip install -r requirements.txt &&
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 &&
nohup python main.py --listen 0.0.0.0 --port 8188 > comfyui.log 2>&1 &
                    `.trim(),
                    env: { 'PYTHONPATH': '/root/ComfyUI' },
                    disk: 32
                })
            });

            if (!rentResponse.ok) {
                const errorText = await rentResponse.text();
                throw new Error(`Instance rental failed: ${rentResponse.status} - ${errorText}`);
            }

            const result = await rentResponse.json();
            this.vastai.instanceId = result.new_contract || result.id || null;
            this.vastai.instanceStatus = 'starting';

            // Save config
            localStorage.setItem('vastai_config', JSON.stringify(this.vastai));

            console.log('✅ Vast.ai instance starting:', this.vastai.instanceId || result.new_contract || result.id);
            
            // Start polling for instance readiness
            this.startInstancePolling();
            
            return this.vastai.instanceId;
        } catch (error) {
            console.error('Failed to start Vast.ai instance:', error);
            // Reset launching state on error
            this.vastai.isLaunching = false;
            this.vastai.instanceStatus = 'error';
            localStorage.setItem('vastai_config', JSON.stringify(this.vastai));
            throw error;
        } finally {
            // Re-enable start buttons in UI
            try { document.querySelectorAll('#start-vastai-instance').forEach(b => b.disabled = false); } catch(e){}
            // Keep isLaunching true until instance transitions via polling
        }

        } catch (error) {
            console.error('Failed to start Vast.ai instance:', error);
            throw error;
        }
    }

    async stopVastAIInstance() {
        if (!this.vastai.instanceId || !this.apiKey) return;

        try {
            // Stop polling
            this.stopInstancePolling();
            
            // Proxy the delete request through the server to avoid CORS and to use server-side auth
            const response = await fetch(`http://localhost:3000/api/proxy/instances/${this.vastai.instanceId}/`, {
                method: 'DELETE'
            });

            if (response.ok) {
                this.vastai.instanceStatus = 'stopped';
                this.vastai.connectionUrl = null;
                this.vastai.instanceId = null;
                this.baseUrl = 'http://127.0.0.1:8188'; // Reset to local

                // Save updated config
                localStorage.setItem('vastai_config', JSON.stringify(this.vastai));

                console.log('Vast.ai instance stopped');
            }
        } catch (error) {
            console.error('Failed to stop Vast.ai instance:', error);
            throw error;
        }
    }

    startInstancePolling() {
        // Clear existing polling if any
        this.stopInstancePolling();
        
        console.log('⏱️ Starting instance status polling...');
        this.pollingInterval = setInterval(async () => {
            await this.checkVastAIInstance();
            
            // If instance is ready, stop polling
            if (this.vastai.connectionUrl) {
                console.log('✅ Instance is ready! URL:', this.vastai.connectionUrl);
                this.stopInstancePolling();
            }
        }, 30000); // Check every 30 seconds
    }

    stopInstancePolling() {
        if (this.pollingInterval) {
            clearInterval(this.pollingInterval);
            this.pollingInterval = null;
        }
    }

    async listVastAIInstances() {
        if (!this.apiKey) return [];

        try {
            const response = await fetch('http://localhost:3000/api/proxy/instances', {
                headers: this.authHeaders
            });

            if (response.ok) {
                const instances = await response.json();
                return instances.instances || [];
            }
        } catch (error) {
            console.error('Failed to list Vast.ai instances:', error);
        }

        return [];
    }

    async generateWithMuse(muse, userPrompt, variation = null, settings = {}) {
        // Ensure Vast.ai instance is running if using cloud
        if (this.serviceType === 'vastai') {
            await this.ensureVastAIInstance();
        }

        const prompt = muse.generatePrompt(userPrompt, variation);
        const negativePrompt = muse.generateNegativePrompt();

        // Build ComfyUI workflow
        const workflow = this.buildWorkflow(muse, prompt, negativePrompt, settings);

        // Submit to ComfyUI
        return await this.submitWorkflow(workflow);
    }

    async ensureVastAIInstance() {
        // Check current status
        await this.checkVastAIInstance();

        if (this.vastai.instanceStatus === 'stopped') {
            console.log('Starting Vast.ai instance...');
            await this.startVastAIInstance();

            // Wait for instance to be ready (this could take several minutes)
            let attempts = 0;
            while (attempts < 60) { // 5 minutes max
                await new Promise(resolve => setTimeout(resolve, 5000)); // Wait 5 seconds
                await this.checkVastAIInstance();

                if (this.vastai.instanceStatus === 'running') {
                    console.log('Vast.ai instance ready!');
                    return;
                }

                attempts++;
            }

            throw new Error('Vast.ai instance failed to start within timeout');
        } else if (this.vastai.instanceStatus === 'running') {
            // Instance is already running
            return;
        } else {
            throw new Error(`Vast.ai instance status: ${this.vastai.instanceStatus}`);
        }
    }

    async generateWithMuse(muse, userPrompt, variation = null, settings = {}) {
        const prompt = muse.generatePrompt(userPrompt, variation);
        const negativePrompt = muse.generateNegativePrompt();

        // Build ComfyUI workflow
        const workflow = this.buildWorkflow(muse, prompt, negativePrompt, settings);

        // Submit to ComfyUI
        return await this.submitWorkflow(workflow);
    }

    buildWorkflow(muse, positivePrompt, negativePrompt, settings) {
        // Use custom workflow if defined, otherwise use default template
        if (muse.aiSettings.customWorkflow) {
            return this.injectPromptsIntoWorkflow(
                muse.aiSettings.customWorkflow,
                positivePrompt,
                negativePrompt
            );
        }

        // Default workflow template
        return this.createDefaultWorkflow(muse, positivePrompt, negativePrompt, settings);
    }

    createDefaultWorkflow(muse, positivePrompt, negativePrompt, settings) {
        // This is a simplified example - actual ComfyUI workflows are more complex
        const workflow = {
            "3": { // KSampler node
                "inputs": {
                    "seed": settings.seed || Math.floor(Math.random() * 1000000000),
                    "steps": muse.aiSettings.steps || 30,
                    "cfg": muse.aiSettings.cfgScale || 7,
                    "sampler_name": muse.aiSettings.sampler || "dpmpp_2m_karras",
                    "scheduler": "karras",
                    "denoise": 1,
                    "model": ["4", 0],
                    "positive": ["6", 0],
                    "negative": ["7", 0],
                    "latent_image": ["5", 0]
                },
                "class_type": "KSampler"
            },
            "4": { // Load Checkpoint
                "inputs": {
                    "ckpt_name": muse.aiSettings.preferredCheckpoint || "model.safetensors"
                },
                "class_type": "CheckpointLoaderSimple"
            },
            "5": { // Empty Latent Image
                "inputs": {
                    "width": settings.width || 512,
                    "height": settings.height || 768,
                    "batch_size": 1
                },
                "class_type": "EmptyLatentImage"
            },
            "6": { // Positive Prompt
                "inputs": {
                    "text": positivePrompt,
                    "clip": ["4", 1]
                },
                "class_type": "CLIPTextEncode"
            },
            "7": { // Negative Prompt
                "inputs": {
                    "text": negativePrompt,
                    "clip": ["4", 1]
                },
                "class_type": "CLIPTextEncode"
            },
            "8": { // VAE Decode
                "inputs": {
                    "samples": ["3", 0],
                    "vae": ["4", 2]
                },
                "class_type": "VAEDecode"
            },
            "9": { // Save Image
                "inputs": {
                    "filename_prefix": `AIKings_${muse.name}`,
                    "images": ["8", 0]
                },
                "class_type": "SaveImage"
            }
        };

        // Add LoRA nodes if specified
        if (muse.aiSettings.loraModels && muse.aiSettings.loraModels.length > 0) {
            // TODO: Inject LoRA nodes into workflow
        }

        // Add IPAdapter nodes if reference images exist
        if (muse.aiSettings.primaryReference) {
            // TODO: Inject IPAdapter nodes
        }

        return workflow;
    }

    injectPromptsIntoWorkflow(workflow, positivePrompt, negativePrompt) {
        // Clone workflow
        const modified = JSON.parse(JSON.stringify(workflow));

        // Find and update prompt nodes
        Object.keys(modified).forEach(nodeId => {
            const node = modified[nodeId];
            if (node.class_type === 'CLIPTextEncode') {
                // Determine if positive or negative based on common patterns
                const currentText = (node.inputs.text || '').toLowerCase();
                if (currentText.includes('negative') || currentText.includes('bad') || currentText.includes('worst')) {
                    node.inputs.text = negativePrompt;
                } else {
                    node.inputs.text = positivePrompt;
                }
            }
        });

        return modified;
    }

    async submitWorkflow(workflow) {
        try {
            if (this.serviceType === 'vastai') {
                // Check instance status before submitting
                await this.checkVastAIInstance();
                
                // Auto-launch instance if not available
                if (!this.vastai.connectionUrl) {
                    // Check if already launching
                    if (this.vastai.instanceStatus === 'starting' && this.vastai.instanceId) {
                        throw new Error('Instance is already launching (ID: ' + this.vastai.instanceId + '). Please wait 5-10 minutes, then try again.');
                    }
                    
                    console.log('⚠️ No Vast.ai instance running. Auto-launching...');
                    const contractId = await this.startVastAIInstance();
                    if (contractId) {
                        throw new Error('Instance launching. Please wait 5-10 minutes for setup, then try again.');
                    }
                    throw new Error('Failed to launch Vast.ai instance. Check console for details.');
                }
                
                // When using Vast.ai, forward the request via the server proxy to the running instance
                const forwardBody = {
                    targetUrl: `${this.vastai.connectionUrl}/prompt`,
                    payload: {
                        prompt: workflow,
                        client_id: 'aikings_' + Date.now()
                    }
                };

                const response = await fetch('http://localhost:3000/api/proxy/forward', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(forwardBody)
                });

                if (!response.ok) {
                    const errorText = await response.text();
                    throw new Error(`ComfyUI request failed: ${response.status} - ${errorText}`);
                }

                return await response.json();
            } else {
                // Local ComfyUI
                const url = `${this.baseUrl}/prompt`;
                const response = await fetch(url, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        ...this.authHeaders
                    },
                    body: JSON.stringify({
                        prompt: workflow,
                        client_id: 'aikings_' + Date.now()
                    })
                });

                if (!response.ok) {
                    const errorText = await response.text();
                    throw new Error(`ComfyUI request failed: ${response.status} - ${errorText}`);
                }

                return await response.json();
            }
        } catch (error) {
            console.error('ComfyUI submission error:', error);

            // Enhanced error handling for cloud services
            if (this.serviceType === 'vastai') {
                if (error.message.includes('Failed to fetch') || error.message.includes('NetworkError')) {
                    throw new Error('Cannot connect to Vast.ai instance. It may still be starting up.');
                }
            }

            throw error;
        }
    }

    async getHistory(promptId) {
        try {
            const response = await fetch(`${this.baseUrl}/history/${promptId}`);
            if (!response.ok) {
                throw new Error(`Failed to get history: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error('ComfyUI history error:', error);
            throw error;
        }
    }

    async getImage(filename, subfolder = '', type = 'output') {
        const params = new URLSearchParams({
            filename,
            subfolder,
            type
        });
        return `${this.baseUrl}/view?${params.toString()}`;
    }
}

// Export classes
window.MuseProfile = MuseProfile;
window.MuseStorageManager = MuseStorageManager;
window.ComfyUIIntegration = ComfyUIIntegration;
