/**
 * AI KINGS STUDIO - Application Logic
 * Handles the Studio UI, Muse System, and Generation interactions.
 */

class TheMuseManager {
    constructor(app) {
        this.app = app;
        this.muses = [
            { id: 'm1', name: 'Default Model', age: '24', body: 'athletic', traits: 'Standard training base' }
        ];
        this.activeMuseId = null;

        this.initUI();
    }

    initUI() {
        // UI Elements
        this.modal = document.getElementById('muse-modal');
        this.rosterEl = document.getElementById('muse-roster');
        this.btnPanel = document.getElementById('btn-muse-panel');
        this.btnClose = document.querySelector('.close-modal');
        this.btnSave = document.getElementById('btn-save-muse');
        this.indicator = document.getElementById('dock-muse-indicator').querySelector('.value');

        // Event Listeners
        this.btnPanel.addEventListener('click', () => this.openModal());
        this.btnClose.addEventListener('click', () => this.closeModal());
        this.btnSave.addEventListener('click', () => this.saveCurrentMuse());
        document.getElementById('btn-new-muse').addEventListener('click', () => this.createNewMuse());

        // Initial Render
        this.renderRoster();
    }

    openModal() {
        this.modal.classList.add('active');
    }

    closeModal() {
        this.modal.classList.remove('active');
    }

    renderRoster() {
        this.rosterEl.innerHTML = '';
        this.muses.forEach(muse => {
            const el = document.createElement('div');
            el.className = `muse-item ${this.activeMuseId === muse.id ? 'active' : ''}`;
            el.innerHTML = `
                <div class="muse-avatar">${muse.name.substring(0, 2).toUpperCase()}</div>
                <div class="muse-info">
                    <div class="muse-name">${muse.name}</div>
                    <div class="muse-meta text-muted" style="font-size:0.7rem">${muse.body}</div>
                </div>
            `;
            el.addEventListener('click', () => this.selectMuse(muse.id));
            this.rosterEl.appendChild(el);
        });
    }

    selectMuse(id) {
        this.activeMuseId = id;
        const muse = this.muses.find(m => m.id === id);

        // Populate Editor
        document.getElementById('muse-name').value = muse.name;
        document.getElementById('muse-age').value = muse.age;
        document.getElementById('muse-body').value = muse.body;
        document.getElementById('muse-traits').value = muse.traits;

        // Update Dock Indicator
        this.indicator.textContent = muse.name;

        this.renderRoster();
    }

    createNewMuse() {
        const newMuse = {
            id: 'm' + Date.now(),
            name: 'New Muse',
            age: '',
            body: 'slim',
            traits: ''
        };
        this.muses.push(newMuse);
        this.selectMuse(newMuse.id);
    }

    saveCurrentMuse() {
        if (!this.activeMuseId) return;

        const muse = this.muses.find(m => m.id === this.activeMuseId);
        muse.name = document.getElementById('muse-name').value;
        muse.age = document.getElementById('muse-age').value;
        muse.body = document.getElementById('muse-body').value;
        muse.traits = document.getElementById('muse-traits').value;

        this.renderRoster();
        this.indicator.textContent = muse.name;

        // Notify user (simple toast replacement)
        alert(`Muse "${muse.name}" saved! Traits locked.`);
    }

    getActiveMuse() {
        return this.muses.find(m => m.id === this.activeMuseId);
    }
}

class StudioApp {
    constructor() {
        this.museManager = new TheMuseManager(this);
        this.promptInput = document.getElementById('studio-prompt');
        this.generateBtn = document.getElementById('btn-generate');
        this.stage = document.getElementById('main-canvas-container');

        this.init();
    }

    init() {
        this.generateBtn.addEventListener('click', () => this.generateContent());
        this.setupSidebarNavigation();

        // Add basic button animations via GSAP if available
        if (typeof gsap !== 'undefined') {
            gsap.from(".studio-sidebar", { x: -50, opacity: 0, duration: 0.8, ease: "power2.out" });
            gsap.from(".studio-dock", { y: 50, opacity: 0, duration: 0.8, delay: 0.2, ease: "power2.out" });
        }
    }

    setupSidebarNavigation() {
        // Studio button - already active, does nothing (stays in studio)
        const studioBtn = document.querySelector('.nav-item[data-tooltip*="Studio"]');
        if (studioBtn) {
            studioBtn.addEventListener('click', () => {
                // Scroll to studio or ensure it's visible
                document.querySelector('.hero-studio-wrapper')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
            });
        }

        // Collection button - scroll to collection section
        const collectionBtn = document.getElementById('btn-collection');
        if (collectionBtn) {
            collectionBtn.addEventListener('click', () => {
                const collectionSection = document.getElementById('main-gallery');
                if (collectionSection) {
                    collectionSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
                    // Update active state
                    document.querySelectorAll('.nav-item').forEach(item => item.classList.remove('active'));
                    collectionBtn.classList.add('active');
                }
            });
        }

        // Muse button - already handled by TheMuseManager
        // Settings button
        const settingsBtn = document.getElementById('btn-settings');
        if (settingsBtn) {
            settingsBtn.addEventListener('click', () => {
                // Open settings modal or panel
                this.openSettings();
            });
        }

        // Update active state on click
        document.querySelectorAll('.nav-item').forEach(item => {
            item.addEventListener('click', (e) => {
                // Don't update if clicking muse button (handled separately)
                if (e.currentTarget.id !== 'btn-muse-panel') {
                    document.querySelectorAll('.nav-item').forEach(nav => nav.classList.remove('active'));
                    e.currentTarget.classList.add('active');
                }
            });
        });
    }

    openSettings() {
        // Create or show settings modal
        alert('Settings panel - Coming soon!\n\nThis will include:\n- Generation preferences\n- Quality settings\n- Storage options\n- Privacy controls');
    }

    generateContent() {
        const prompt = this.promptInput.value;
        const muse = this.museManager.getActiveMuse();

        if (!prompt) return;

        // Construct final prompt with Muse Injection
        let finalPrompt = prompt;
        if (muse) {
            finalPrompt = `[Character: ${muse.name}, ${muse.age}yo, ${muse.body}, ${muse.traits}] ${prompt}`;
        }

        console.log("Generating with PROMPT:", finalPrompt);

        // UI Feedback
        this.generateBtn.innerHTML = `<span><i class="ph ph-spinner ph-spin"></i> Dreaming...</span>`;

        // Mock Generation Delay
        setTimeout(() => {
            this.generateBtn.innerHTML = `<span>Manifest</span>`;
            this.showResult();
        }, 2000);
    }

    showResult() {
        // Show a placeholder image for now
        const stageOverlay = this.stage.querySelector('.empty-stage-state');
        const activeContent = this.stage.querySelector('.active-content');
        const img = activeContent.querySelector('img');

        stageOverlay.style.display = 'none';
        activeContent.style.display = 'block';

        // Correct path to asset
        img.src = "assets/images/ai-kings-og.jpg";

        // Animate entrance
        if (typeof gsap !== 'undefined') {
            gsap.from(img, { scale: 0.95, opacity: 0, duration: 0.5 });
        }
    }
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    window.studioApp = new StudioApp();
});
