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
            fashionStyle: data.style && data.style.fashionStyle ? data.style.fashionStyle : 'casual',
            lingerie: data.style && data.style.lingerie ? data.style.lingerie : '',
            footwear: data.style && data.style.footwear ? data.style.footwear : '',
            nails: data.style && data.style.nails ? data.style.nails : 'natural',
            personality: data.style && data.style.personality ? data.style.personality : '',
            vibe: data.style && data.style.vibe ? data.style.vibe : ''
        };

        // AI Settings
        this.aiSettings = {
            qualityTags: data.aiSettings && data.aiSettings.qualityTags ? data.aiSettings.qualityTags : 'masterpiece, best quality, high resolution',
            styleTags: data.aiSettings && data.aiSettings.styleTags ? data.aiSettings.styleTags : 'photorealistic, cinematic lighting',
            positivePrefix: data.aiSettings && data.aiSettings.positivePrefix ? data.aiSettings.positivePrefix : '',
            negativeAdditions: data.aiSettings && data.aiSettings.negativeAdditions ? data.aiSettings.negativeAdditions : '',
            preferredCheckpoint: data.aiSettings && data.aiSettings.preferredCheckpoint ? data.aiSettings.preferredCheckpoint : '',
            preferredVAE: data.aiSettings && data.aiSettings.preferredVAE ? data.aiSettings.preferredVAE : '',
            sampler: data.aiSettings && data.aiSettings.sampler ? data.aiSettings.sampler : 'DPM++ 2M Karras',
            steps: data.aiSettings && data.aiSettings.steps ? data.aiSettings.steps : 30,
            cfgScale: data.aiSettings && data.aiSettings.cfgScale ? data.aiSettings.cfgScale : 7,
            loraModels: data.aiSettings && data.aiSettings.loraModels ? data.aiSettings.loraModels : [],
            primaryReference: data.aiSettings && data.aiSettings.primaryReference ? data.aiSettings.primaryReference : null,
            referenceImages: data.aiSettings && data.aiSettings.referenceImages ? data.aiSettings.referenceImages : []
        };

        // Variations
        this.variations = data.variations || [];

        // Generation History
        this.generationHistory = data.generationHistory || [];

        // Notes
        this.notes = data.notes || '';
    }

    static fromJSON(json) {
        return new MuseProfile(json);
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

    addVariation(name, description, overrides) {
        const variation = {
            id: 'var_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9),
            name: name,
            description: description || '',
            overrides: overrides || {},
            createdAt: new Date().toISOString()
        };
        this.variations.push(variation);
        return variation;
    }

    addToHistory(entry) {
        const historyEntry = {
            ...entry,
            timestamp: new Date().toISOString()
        };
        this.generationHistory.unshift(historyEntry);
        // Keep only last 100 entries
        if (this.generationHistory.length > 100) {
            this.generationHistory = this.generationHistory.slice(0, 100);
        }
    }

    generatePrompt(userPrompt, variationId = null) {
        const parts = [];

        // Add quality tags
        if (this.aiSettings.qualityTags) {
            parts.push(this.aiSettings.qualityTags);
        }

        // Add style tags
        if (this.aiSettings.styleTags) {
            parts.push(this.aiSettings.styleTags);
        }

        // Add positive prefix
        if (this.aiSettings.positivePrefix) {
            parts.push(this.aiSettings.positivePrefix);
        }

        // Build character description
        const charDesc = [];

        // Basic attributes
        if (this.basic.age) charDesc.push(`${this.basic.age} year old`);
        if (this.basic.ethnicity) charDesc.push(this.basic.ethnicity);
        charDesc.push('woman');

        // Face attributes
        if (this.face.hairColor && this.face.hairLength) {
            charDesc.push(`${this.face.hairLength} ${this.face.hairColor} hair`);
        }
        if (this.face.eyeColor) charDesc.push(`${this.face.eyeColor} eyes`);

        // Body attributes
        if (this.body.build) charDesc.push(`${this.body.build} build`);
        if (this.body.skinTone) charDesc.push(`${this.body.skinTone} skin`);

        if (charDesc.length > 0) {
            parts.push(charDesc.join(', '));
        }

        // Apply variation overrides if specified
        if (variationId) {
            const variation = this.variations.find(v => v.id === variationId);
            if (variation && variation.overrides) {
                // Add variation-specific style
                if (variation.overrides.style) {
                    parts.push(variation.overrides.style.fashionStyle || '');
                }
            }
        }

        // Add user prompt
        if (userPrompt) {
            parts.push(userPrompt);
        }

        return parts.filter(p => p).join(', ');
    }

    generateNegativePrompt() {
        const negativeParts = [
            'ugly', 'deformed', 'bad anatomy', 'bad proportions',
            'extra limbs', 'mutated hands', 'poorly drawn face',
            'blurry', 'watermark', 'text', 'signature'
        ];

        if (this.aiSettings.negativeAdditions) {
            negativeParts.push(this.aiSettings.negativeAdditions);
        }

        return negativeParts.join(', ');
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

    async exportProfile(profile, includeImages = false) {
        let images = [];
        if (includeImages) {
            try {
                images = await this.getReferenceImages(profile.id);
            } catch (e) {
                console.warn('Failed to fetch reference images for export:', e);
            }
        }

        const exportData = {
            version: '1.0',
            exportedAt: new Date().toISOString(),
            profile: profile.toJSON(),
            images: includeImages ? images : null
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

// ComfyUIIntegration is loaded from assets/js/comfyui-integration.js

// Export classes
window.MuseProfile = MuseProfile;
window.MuseStorageManager = MuseStorageManager;
