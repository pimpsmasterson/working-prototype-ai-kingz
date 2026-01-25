/**
 * AI KINGS - Muse Manager
 * Main manager class for professional character/muse management
 */

class MuseManager {
    constructor(app) {
        this.app = app;
        this.muses = [];
        this.activeMuseId = null;
        this.activeMuse = null;
        this.activeVariationId = null;

        this.storage = new MuseStorageManager();
        this.comfyUI = new ComfyUIIntegration();

        // UI Elements
        this.modal = null;
        this.currentTab = 'basic';

        // Categories
        this.categories = [
            { id: 'general', name: 'General', icon: 'user' },
            { id: 'fantasy', name: 'Fantasy', icon: 'sparkle' },
            { id: 'cosplay', name: 'Cosplay', icon: 'mask-happy' },
            { id: 'celebrity', name: 'Celebrity-Inspired', icon: 'star' },
            { id: 'anime', name: 'Anime/Hentai', icon: 'film' },
            { id: 'custom', name: 'Custom', icon: 'palette' }
        ];

        this.init();
    }

    async init() {
        try {
            // Initialize storage
            await this.storage.init();

            // Load saved muses
            this.muses = this.storage.loadMuseProfiles();

            // Create default muse if none exist
            if (this.muses.length === 0) {
                this.createDefaultMuse();
            }

            // Initialize UI
            this.initUI();

            console.log('Muse Manager initialized with', this.muses.length, 'muses');
        } catch (error) {
            console.error('Failed to initialize Muse Manager:', error);
        }
    }

    createDefaultMuse() {
        const defaultMuse = new MuseProfile({
            name: 'Starter Character',
            category: 'general',
            basic: {
                age: '25',
                ageAppearance: '25',
                ethnicity: 'Caucasian'
            },
            body: {
                height: 'average',
                build: 'athletic',
                bodyShape: 'hourglass',
                skinTone: 'fair'
            },
            face: {
                eyeColor: 'blue',
                hairColor: 'blonde',
                hairLength: 'long',
                hairStyle: 'straight'
            }
        });

        this.muses.push(defaultMuse);
        this.save();
    }

    initUI() {
        // Get modal element
        this.modal = document.getElementById('muse-modal-pro');
        if (!this.modal) {
            console.warn('Muse modal not found - UI features disabled');
            return;
        }

        // Bind events
        this.bindEvents();

        // Render initial state
        this.renderMuseList();
    }

    bindEvents() {
        // Open modal button
        const openBtn = document.getElementById('btn-muse-panel');
        if (openBtn) {
            openBtn.addEventListener('click', () => this.openModal());
        }

        // Close modal button
        const closeBtn = this.modal?.querySelector('.close-modal');
        if (closeBtn) {
            closeBtn.addEventListener('click', () => this.closeModal());
        }

        // Close on outside click
        this.modal?.addEventListener('click', (e) => {
            if (e.target === this.modal) {
                this.closeModal();
            }
        });

        // New muse button
        const newMuseBtn = document.getElementById('btn-new-muse-pro');
        if (newMuseBtn) {
            newMuseBtn.addEventListener('click', () => this.createNewMuse());
        }

        // Tab switching
        document.querySelectorAll('.editor-tab-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const tab = e.target.dataset.tab;
                this.switchTab(tab);
            });
        });

        // Save muse button
        const saveBtn = document.getElementById('btn-save-muse-pro');
        if (saveBtn) {
            saveBtn.addEventListener('click', () => this.saveActiveMuse());
        }

        // Delete muse button
        const deleteBtn = document.getElementById('btn-delete-muse');
        if (deleteBtn) {
            deleteBtn.addEventListener('click', () => this.deleteActiveMuse());
        }

        // Export/Import buttons
        const exportBtn = document.getElementById('btn-export-muse');
        if (exportBtn) {
            exportBtn.addEventListener('click', () => this.exportActiveMuse());
        }

        const importBtn = document.getElementById('btn-import-muse');
        if (importBtn) {
            importBtn.addEventListener('click', () => this.importMuse());
        }

        // Category filter
        const categoryFilter = document.getElementById('muse-category-filter');
        if (categoryFilter) {
            categoryFilter.addEventListener('change', () => this.renderMuseList());
        }

        // Search
        const searchInput = document.getElementById('muse-search');
        if (searchInput) {
            searchInput.addEventListener('input', () => this.renderMuseList());
        }

        // Reference image upload
        const refImageInput = document.getElementById('reference-image-upload');
        if (refImageInput) {
            refImageInput.addEventListener('change', (e) => this.handleReferenceImageUpload(e));
        }
    }

    openModal() {
        if (!this.modal) return;
        this.modal.classList.add('active');

        // Select first muse if none selected
        if (!this.activeMuseId && this.muses.length > 0) {
            this.selectMuse(this.muses[0].id);
        }
    }

    closeModal() {
        if (!this.modal) return;
        this.modal.classList.remove('active');
    }

    switchTab(tabName) {
        this.currentTab = tabName;

        // Update tab buttons
        document.querySelectorAll('.editor-tab-btn').forEach(btn => {
            btn.classList.toggle('active', btn.dataset.tab === tabName);
        });

        // Update tab panels
        document.querySelectorAll('.editor-tab-panel').forEach(panel => {
            panel.classList.toggle('active', panel.dataset.tab === tabName);
        });
    }

    renderMuseList() {
        const listContainer = document.getElementById('muse-list-container');
        if (!listContainer) return;

        // Get filters
        const categoryFilter = document.getElementById('muse-category-filter')?.value || 'all';
        const searchTerm = document.getElementById('muse-search')?.value.toLowerCase() || '';

        // Filter muses
        let filtered = this.muses.filter(muse => {
            if (muse.isArchived) return false;
            if (categoryFilter !== 'all' && muse.category !== categoryFilter) return false;
            if (searchTerm && !muse.name.toLowerCase().includes(searchTerm)) return false;
            return true;
        });

        // Sort: favorites first, then by updated date
        filtered.sort((a, b) => {
            if (a.isFavorite && !b.isFavorite) return -1;
            if (!a.isFavorite && b.isFavorite) return 1;
            return new Date(b.updatedAt) - new Date(a.updatedAt);
        });

        // Render
        listContainer.innerHTML = filtered.map(muse => `
            <div class="muse-card ${this.activeMuseId === muse.id ? 'active' : ''}"
                 data-muse-id="${muse.id}">
                <div class="muse-card-header">
                    <div class="muse-avatar">
                        ${muse.aiSettings.primaryReference ?
                            `<img src="${muse.aiSettings.primaryReference}" alt="${muse.name}">` :
                            `<div class="avatar-placeholder">${muse.name.substring(0, 2).toUpperCase()}</div>`
                        }
                    </div>
                    <div class="muse-card-info">
                        <div class="muse-card-name">
                            ${muse.name}
                            ${muse.isFavorite ? '<i class="ph-fill ph-star"></i>' : ''}
                        </div>
                        <div class="muse-card-meta">
                            ${muse.category} • ${muse.basic.ethnicity || 'N/A'}
                        </div>
                        ${muse.tags.length > 0 ? `
                            <div class="muse-card-tags">
                                ${muse.tags.slice(0, 3).map(tag => `<span class="tag-chip">${tag}</span>`).join('')}
                            </div>
                        ` : ''}
                    </div>
                </div>
                <div class="muse-card-stats">
                    <span>${muse.generationHistory.length} generations</span>
                    <span>${muse.variations.length} variations</span>
                </div>
            </div>
        `).join('');

        // Bind click events
        listContainer.querySelectorAll('.muse-card').forEach(card => {
            card.addEventListener('click', () => {
                const museId = card.dataset.museId;
                this.selectMuse(museId);
            });
        });
    }

    selectMuse(museId) {
        this.activeMuseId = museId;
        this.activeMuse = this.muses.find(m => m.id === museId);

        if (!this.activeMuse) {
            console.error('Muse not found:', museId);
            return;
        }

        // Update active state in list
        document.querySelectorAll('.muse-card').forEach(card => {
            card.classList.toggle('active', card.dataset.museId === museId);
        });

        // Populate editor
        this.populateEditor(this.activeMuse);

        // Update dock indicator
        this.updateDockIndicator();

        // Switch to basic tab
        this.switchTab('basic');
    }

    populateEditor(muse) {
        // Basic Info Tab
        this.setInputValue('muse-name', muse.name);
        this.setInputValue('muse-age', muse.basic.age);
        this.setInputValue('muse-age-appearance', muse.basic.ageAppearance);
        this.setInputValue('muse-nationality', muse.basic.nationality);
        this.setInputValue('muse-ethnicity', muse.basic.ethnicity);
        this.setInputValue('muse-occupation', muse.basic.occupation);
        this.setInputValue('muse-category', muse.category);

        // Tags
        this.renderTags(muse.tags);

        // Body Tab
        this.setInputValue('muse-height', muse.body.height);
        this.setInputValue('muse-height-cm', muse.body.heightCm);
        this.setInputValue('muse-build', muse.body.build);
        this.setInputValue('muse-body-shape', muse.body.bodyShape);
        this.setInputValue('muse-skin-tone', muse.body.skinTone);
        this.setInputValue('muse-skin-texture', muse.body.skinTexture);
        this.setInputValue('muse-bust', muse.body.bust);
        this.setInputValue('muse-bust-cup', muse.body.bustCup);
        this.setInputValue('muse-waist', muse.body.waist);
        this.setInputValue('muse-hips', muse.body.hips);
        this.setInputValue('muse-muscle-tone', muse.body.muscleTone);
        this.setInputValue('muse-body-hair', muse.body.bodyHair);

        // Face Tab
        this.setInputValue('muse-face-shape', muse.face.faceShape);
        this.setInputValue('muse-eye-color', muse.face.eyeColor);
        this.setInputValue('muse-eye-shape', muse.face.eyeShape);
        this.setInputValue('muse-eye-size', muse.face.eyeSize);
        this.setInputValue('muse-hair-color', muse.face.hairColor);
        this.setInputValue('muse-hair-length', muse.face.hairLength);
        this.setInputValue('muse-hair-style', muse.face.hairStyle);
        this.setInputValue('muse-hair-texture', muse.face.hairTexture);
        this.setInputValue('muse-lips', muse.face.lips);
        this.setInputValue('muse-lip-color', muse.face.lipColor);
        this.setInputValue('muse-nose', muse.face.nose);
        this.setInputValue('muse-jawline', muse.face.jawline);
        this.setInputValue('muse-cheekbones', muse.face.cheekbones);
        this.setInputValue('muse-facial-hair', muse.face.facialHair);
        this.setInputValue('muse-makeup', muse.face.makeup);

        // Features Tab
        this.renderFeatures(muse.features);

        // Style Tab
        this.setInputValue('muse-fashion-style', muse.style.fashionStyle);
        this.setInputValue('muse-lingerie', muse.style.lingerie);
        this.setInputValue('muse-footwear', muse.style.footwear);
        this.setInputValue('muse-nails', muse.style.nails);
        this.setInputValue('muse-personality', muse.style.personality);
        this.setInputValue('muse-vibe', muse.style.vibe);

        // AI Settings Tab
        this.setInputValue('muse-positive-prefix', muse.aiSettings.positivePromptPrefix);
        this.setInputValue('muse-negative-additions', muse.aiSettings.negativePromptAdditions);
        this.setInputValue('muse-quality-tags', muse.aiSettings.qualityTags);
        this.setInputValue('muse-style-tags', muse.aiSettings.styleTags);
        this.setInputValue('muse-checkpoint', muse.aiSettings.preferredCheckpoint);
        this.setInputValue('muse-vae', muse.aiSettings.preferredVAE);
        this.setInputValue('muse-sampler', muse.aiSettings.sampler);
        this.setInputValue('muse-steps', muse.aiSettings.steps);
        this.setInputValue('muse-cfg-scale', muse.aiSettings.cfgScale);

        // Reference Images
        this.renderReferenceImages(muse);

        // Variations
        this.renderVariations(muse.variations);

        // Generation History
        this.renderGenerationHistory(muse.generationHistory);

        // Notes
        this.setInputValue('muse-notes', muse.notes);
    }

    setInputValue(id, value) {
        const element = document.getElementById(id);
        if (!element) return;

        if (element.type === 'checkbox') {
            element.checked = value;
        } else {
            element.value = value || '';
        }
    }

    renderTags(tags) {
        const container = document.getElementById('muse-tags-container');
        if (!container) return;

        container.innerHTML = tags.map(tag => `
            <span class="tag-chip editable">
                ${tag}
                <button class="tag-remove" data-tag="${tag}">×</button>
            </span>
        `).join('') + `
            <button class="btn-add-tag" id="btn-add-tag">+ Add Tag</button>
        `;

        // Bind remove tag
        container.querySelectorAll('.tag-remove').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const tag = e.target.dataset.tag;
                this.removeTag(tag);
            });
        });

        // Bind add tag
        const addBtn = container.querySelector('#btn-add-tag');
        if (addBtn) {
            addBtn.addEventListener('click', () => this.addTag());
        }
    }

    renderFeatures(features) {
        // Tattoos
        const tattoosContainer = document.getElementById('tattoos-list');
        if (tattoosContainer && features.tattoos) {
            tattoosContainer.innerHTML = features.tattoos.map((tattoo, idx) => `
                <div class="feature-item">
                    <input type="text" placeholder="Location" value="${tattoo.location || ''}" data-type="tattoo" data-idx="${idx}" data-field="location" class="ai-input small">
                    <input type="text" placeholder="Description" value="${tattoo.description || ''}" data-type="tattoo" data-idx="${idx}" data-field="description" class="ai-input">
                    <select data-type="tattoo" data-idx="${idx}" data-field="size" class="ai-select small">
                        <option value="small" ${tattoo.size === 'small' ? 'selected' : ''}>Small</option>
                        <option value="medium" ${tattoo.size === 'medium' ? 'selected' : ''}>Medium</option>
                        <option value="large" ${tattoo.size === 'large' ? 'selected' : ''}>Large</option>
                    </select>
                    <button class="btn-icon-small remove-feature" data-type="tattoo" data-idx="${idx}">×</button>
                </div>
            `).join('') + '<button class="btn-add-feature" data-type="tattoo">+ Add Tattoo</button>';
        }

        // Piercings
        const piercingsContainer = document.getElementById('piercings-list');
        if (piercingsContainer && features.piercings) {
            piercingsContainer.innerHTML = features.piercings.map((piercing, idx) => `
                <div class="feature-item">
                    <input type="text" placeholder="Location" value="${piercing.location || ''}" data-type="piercing" data-idx="${idx}" data-field="location" class="ai-input small">
                    <input type="text" placeholder="Type" value="${piercing.type || ''}" data-type="piercing" data-idx="${idx}" data-field="type" class="ai-input">
                    <button class="btn-icon-small remove-feature" data-type="piercing" data-idx="${idx}">×</button>
                </div>
            `).join('') + '<button class="btn-add-feature" data-type="piercing">+ Add Piercing</button>';
        }

        // Unique traits
        this.setInputValue('muse-unique-traits', features.uniqueTraits);

        // Bind feature management events
        this.bindFeatureEvents();
    }

    bindFeatureEvents() {
        document.querySelectorAll('.btn-add-feature').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const type = e.target.dataset.type;
                this.addFeature(type);
            });
        });

        document.querySelectorAll('.remove-feature').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const type = e.target.dataset.type;
                const idx = parseInt(e.target.dataset.idx);
                this.removeFeature(type, idx);
            });
        });
    }

    addFeature(type) {
        if (!this.activeMuse) return;

        if (type === 'tattoo') {
            this.activeMuse.features.tattoos.push({ location: '', description: '', size: 'medium' });
        } else if (type === 'piercing') {
            this.activeMuse.features.piercings.push({ location: '', type: '' });
        }

        this.renderFeatures(this.activeMuse.features);
    }

    removeFeature(type, idx) {
        if (!this.activeMuse) return;

        if (type === 'tattoo') {
            this.activeMuse.features.tattoos.splice(idx, 1);
        } else if (type === 'piercing') {
            this.activeMuse.features.piercings.splice(idx, 1);
        }

        this.renderFeatures(this.activeMuse.features);
    }

    async renderReferenceImages(muse) {
        const container = document.getElementById('reference-images-container');
        if (!container) return;

        try {
            const images = await this.storage.getReferenceImages(muse.id);

            container.innerHTML = images.map(img => `
                <div class="reference-image-item ${muse.aiSettings.primaryReference === img.id ? 'primary' : ''}">
                    <img src="${img.data}" alt="${img.fileName}">
                    <div class="reference-image-actions">
                        <button class="btn-icon-small" data-action="set-primary" data-image-id="${img.id}" title="Set as primary">
                            <i class="ph ph-star"></i>
                        </button>
                        <button class="btn-icon-small" data-action="delete" data-image-id="${img.id}" title="Delete">
                            <i class="ph ph-trash"></i>
                        </button>
                    </div>
                </div>
            `).join('') + `
                <div class="reference-image-upload">
                    <label for="reference-image-upload">
                        <i class="ph ph-upload"></i>
                        <span>Upload Reference</span>
                    </label>
                    <input type="file" id="reference-image-upload" accept="image/*" multiple style="display: none;">
                </div>
            `;

            // Bind image actions
            container.querySelectorAll('[data-action]').forEach(btn => {
                btn.addEventListener('click', (e) => {
                    const action = e.currentTarget.dataset.action;
                    const imageId = e.currentTarget.dataset.imageId;
                    this.handleReferenceImageAction(action, imageId);
                });
            });
        } catch (error) {
            console.error('Failed to load reference images:', error);
        }
    }

    async handleReferenceImageUpload(event) {
        if (!this.activeMuse) return;

        const files = Array.from(event.target.files);

        for (const file of files) {
            try {
                const imageData = await this.storage.saveReferenceImage(this.activeMuse.id, file);
                console.log('Reference image uploaded:', imageData.fileName);
            } catch (error) {
                console.error('Failed to upload reference image:', error);
                alert('Failed to upload image: ' + file.name);
            }
        }

        // Refresh display
        await this.renderReferenceImages(this.activeMuse);

        // Clear input
        event.target.value = '';
    }

    async handleReferenceImageAction(action, imageId) {
        if (!this.activeMuse) return;

        if (action === 'set-primary') {
            this.activeMuse.aiSettings.primaryReference = imageId;
            await this.renderReferenceImages(this.activeMuse);
            this.save();
        } else if (action === 'delete') {
            if (confirm('Delete this reference image?')) {
                await this.storage.deleteReferenceImage(imageId);
                if (this.activeMuse.aiSettings.primaryReference === imageId) {
                    this.activeMuse.aiSettings.primaryReference = null;
                }
                await this.renderReferenceImages(this.activeMuse);
                this.save();
            }
        }
    }

    renderVariations(variations) {
        const container = document.getElementById('variations-container');
        if (!container) return;

        container.innerHTML = variations.map(variation => `
            <div class="variation-card" data-variation-id="${variation.id}">
                <div class="variation-info">
                    <div class="variation-name">${variation.name}</div>
                    <div class="variation-description">${variation.description}</div>
                </div>
                <div class="variation-actions">
                    <button class="btn-small" data-action="use" data-variation-id="${variation.id}">Use</button>
                    <button class="btn-icon-small" data-action="delete" data-variation-id="${variation.id}">×</button>
                </div>
            </div>
        `).join('') + `
            <button class="btn-add-variation" id="btn-add-variation">+ Add Variation</button>
        `;

        // Bind events
        const addBtn = container.querySelector('#btn-add-variation');
        if (addBtn) {
            addBtn.addEventListener('click', () => this.addVariation());
        }

        container.querySelectorAll('[data-action]').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const action = e.currentTarget.dataset.action;
                const variationId = e.currentTarget.dataset.variationId;
                this.handleVariationAction(action, variationId);
            });
        });
    }

    addVariation() {
        const name = prompt('Variation name (e.g., "Office Outfit", "Gym Look"):');
        if (!name) return;

        const description = prompt('Description (optional):') || '';

        // Create variation with current muse state as base
        const overrides = {
            style: { ...this.activeMuse.style }
        };

        this.activeMuse.addVariation(name, description, overrides);
        this.renderVariations(this.activeMuse.variations);
        this.save();
    }

    handleVariationAction(action, variationId) {
        if (action === 'use') {
            this.activeVariationId = variationId;
            this.updateDockIndicator();
            alert('Variation selected! It will be used for the next generation.');
        } else if (action === 'delete') {
            if (confirm('Delete this variation?')) {
                this.activeMuse.variations = this.activeMuse.variations.filter(v => v.id !== variationId);
                this.renderVariations(this.activeMuse.variations);
                this.save();
            }
        }
    }

    renderGenerationHistory(history) {
        const container = document.getElementById('generation-history-container');
        if (!container) return;

        if (history.length === 0) {
            container.innerHTML = '<div class="empty-state">No generations yet</div>';
            return;
        }

        container.innerHTML = history.slice(0, 20).map(entry => `
            <div class="history-card">
                ${entry.imageUrl ? `<img src="${entry.imageUrl}" alt="Generated" class="history-thumbnail">` : ''}
                <div class="history-info">
                    <div class="history-date">${new Date(entry.timestamp).toLocaleString()}</div>
                    <div class="history-prompt">${entry.prompt || 'N/A'}</div>
                </div>
            </div>
        `).join('');
    }

    createNewMuse() {
        const name = prompt('Enter character name:');
        if (!name) return;

        const newMuse = new MuseProfile({ name });
        this.muses.push(newMuse);
        this.save();
        this.renderMuseList();
        this.selectMuse(newMuse.id);
    }

    saveActiveMuse() {
        if (!this.activeMuse) return;

        // Collect all form data
        this.activeMuse.name = this.getInputValue('muse-name');
        this.activeMuse.category = this.getInputValue('muse-category');

        // Basic
        this.activeMuse.basic.age = this.getInputValue('muse-age');
        this.activeMuse.basic.ageAppearance = this.getInputValue('muse-age-appearance');
        this.activeMuse.basic.nationality = this.getInputValue('muse-nationality');
        this.activeMuse.basic.ethnicity = this.getInputValue('muse-ethnicity');
        this.activeMuse.basic.occupation = this.getInputValue('muse-occupation');

        // Body
        this.activeMuse.body.height = this.getInputValue('muse-height');
        this.activeMuse.body.heightCm = this.getInputValue('muse-height-cm');
        this.activeMuse.body.build = this.getInputValue('muse-build');
        this.activeMuse.body.bodyShape = this.getInputValue('muse-body-shape');
        this.activeMuse.body.skinTone = this.getInputValue('muse-skin-tone');
        this.activeMuse.body.skinTexture = this.getInputValue('muse-skin-texture');
        this.activeMuse.body.bust = this.getInputValue('muse-bust');
        this.activeMuse.body.bustCup = this.getInputValue('muse-bust-cup');
        this.activeMuse.body.waist = this.getInputValue('muse-waist');
        this.activeMuse.body.hips = this.getInputValue('muse-hips');
        this.activeMuse.body.muscleTone = this.getInputValue('muse-muscle-tone');
        this.activeMuse.body.bodyHair = this.getInputValue('muse-body-hair');

        // Face
        this.activeMuse.face.faceShape = this.getInputValue('muse-face-shape');
        this.activeMuse.face.eyeColor = this.getInputValue('muse-eye-color');
        this.activeMuse.face.eyeShape = this.getInputValue('muse-eye-shape');
        this.activeMuse.face.eyeSize = this.getInputValue('muse-eye-size');
        this.activeMuse.face.hairColor = this.getInputValue('muse-hair-color');
        this.activeMuse.face.hairLength = this.getInputValue('muse-hair-length');
        this.activeMuse.face.hairStyle = this.getInputValue('muse-hair-style');
        this.activeMuse.face.hairTexture = this.getInputValue('muse-hair-texture');
        this.activeMuse.face.lips = this.getInputValue('muse-lips');
        this.activeMuse.face.lipColor = this.getInputValue('muse-lip-color');
        this.activeMuse.face.nose = this.getInputValue('muse-nose');
        this.activeMuse.face.jawline = this.getInputValue('muse-jawline');
        this.activeMuse.face.cheekbones = this.getInputValue('muse-cheekbones');
        this.activeMuse.face.facialHair = this.getInputValue('muse-facial-hair');
        this.activeMuse.face.makeup = this.getInputValue('muse-makeup');

        // Features - collect from dynamic inputs
        this.collectFeaturesFromForm();

        // Style
        this.activeMuse.style.fashionStyle = this.getInputValue('muse-fashion-style');
        this.activeMuse.style.lingerie = this.getInputValue('muse-lingerie');
        this.activeMuse.style.footwear = this.getInputValue('muse-footwear');
        this.activeMuse.style.nails = this.getInputValue('muse-nails');
        this.activeMuse.style.personality = this.getInputValue('muse-personality');
        this.activeMuse.style.vibe = this.getInputValue('muse-vibe');

        // AI Settings
        this.activeMuse.aiSettings.positivePromptPrefix = this.getInputValue('muse-positive-prefix');
        this.activeMuse.aiSettings.negativePromptAdditions = this.getInputValue('muse-negative-additions');
        this.activeMuse.aiSettings.qualityTags = this.getInputValue('muse-quality-tags');
        this.activeMuse.aiSettings.styleTags = this.getInputValue('muse-style-tags');
        this.activeMuse.aiSettings.preferredCheckpoint = this.getInputValue('muse-checkpoint');
        this.activeMuse.aiSettings.preferredVAE = this.getInputValue('muse-vae');
        this.activeMuse.aiSettings.sampler = this.getInputValue('muse-sampler');
        this.activeMuse.aiSettings.steps = parseInt(this.getInputValue('muse-steps')) || 30;
        this.activeMuse.aiSettings.cfgScale = parseFloat(this.getInputValue('muse-cfg-scale')) || 7;

        // Notes
        this.activeMuse.notes = this.getInputValue('muse-notes');

        // Update timestamp
        this.activeMuse.updatedAt = new Date().toISOString();

        // Save to storage
        this.save();

        // Update displays
        this.renderMuseList();
        this.updateDockIndicator();

        alert(`Character "${this.activeMuse.name}" saved successfully!`);
    }

    getInputValue(id) {
        const element = document.getElementById(id);
        if (!element) return '';

        if (element.type === 'checkbox') {
            return element.checked;
        }
        return element.value || '';
    }

    collectFeaturesFromForm() {
        // Collect tattoos
        const tattoos = [];
        document.querySelectorAll('[data-type="tattoo"]').forEach(input => {
            const idx = parseInt(input.dataset.idx);
            const field = input.dataset.field;

            if (!tattoos[idx]) {
                tattoos[idx] = {};
            }

            tattoos[idx][field] = input.value;
        });
        this.activeMuse.features.tattoos = tattoos.filter(t => t.location || t.description);

        // Collect piercings
        const piercings = [];
        document.querySelectorAll('[data-type="piercing"]').forEach(input => {
            const idx = parseInt(input.dataset.idx);
            const field = input.dataset.field;

            if (!piercings[idx]) {
                piercings[idx] = {};
            }

            piercings[idx][field] = input.value;
        });
        this.activeMuse.features.piercings = piercings.filter(p => p.location || p.type);

        // Unique traits
        this.activeMuse.features.uniqueTraits = this.getInputValue('muse-unique-traits');
    }

    deleteActiveMuse() {
        if (!this.activeMuse) return;

        if (!confirm(`Delete character "${this.activeMuse.name}"? This cannot be undone.`)) {
            return;
        }

        this.muses = this.muses.filter(m => m.id !== this.activeMuse.id);
        this.save();

        // Select another muse
        if (this.muses.length > 0) {
            this.selectMuse(this.muses[0].id);
        } else {
            this.activeMuse = null;
            this.activeMuseId = null;
        }

        this.renderMuseList();
    }

    exportActiveMuse() {
        if (!this.activeMuse) return;
        this.storage.exportProfile(this.activeMuse, false);
    }

    async importMuse() {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = '.json';

        input.addEventListener('change', async (e) => {
            const file = e.target.files[0];
            if (!file) return;

            try {
                const imported = await this.storage.importProfile(file);
                this.muses.push(imported);
                this.save();
                this.renderMuseList();
                this.selectMuse(imported.id);
                alert(`Character "${imported.name}" imported successfully!`);
            } catch (error) {
                console.error('Import failed:', error);
                alert('Failed to import character. Please check the file format.');
            }
        });

        input.click();
    }

    addTag() {
        const tag = prompt('Enter tag:');
        if (!tag) return;

        if (!this.activeMuse.tags.includes(tag)) {
            this.activeMuse.tags.push(tag);
            this.renderTags(this.activeMuse.tags);
            this.save();
        }
    }

    removeTag(tag) {
        this.activeMuse.tags = this.activeMuse.tags.filter(t => t !== tag);
        this.renderTags(this.activeMuse.tags);
        this.save();
    }

    save() {
        this.storage.saveMuseProfiles(this.muses);
    }

    updateDockIndicator() {
        const indicator = document.getElementById('dock-muse-indicator');
        if (!indicator) return;

        const valueSpan = indicator.querySelector('.value');
        if (!valueSpan) return;

        if (this.activeMuse) {
            let text = this.activeMuse.name;
            if (this.activeVariationId) {
                const variation = this.activeMuse.variations.find(v => v.id === this.activeVariationId);
                if (variation) {
                    text += ` (${variation.name})`;
                }
            }
            valueSpan.textContent = text;
        } else {
            valueSpan.textContent = 'None Selected';
        }
    }

    getActiveMuse() {
        return this.activeMuse;
    }

    getActiveVariation() {
        return this.activeVariationId;
    }
}

// Export
window.MuseManager = MuseManager;
