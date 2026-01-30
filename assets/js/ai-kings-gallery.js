/**
 * AI KINGS Gallery Manager
 * Handles dynamic loading of generated content into the Index gallery grid.
 */

class GalleryManager {
    constructor() {
        this.galleryGrid = document.querySelector('.video-grid');
        this.tabs = document.querySelectorAll('.collection-tab');
        this.currentFilter = 'all'; // 'all', 'video', 'image', 'saved'
        this.items = []; // Local cache of fetched items

        this.init();
    }

    getApiUrl(path) {
        const port = window.location.port;
        if (port && parseInt(port) >= 5500 && parseInt(port) <= 5510) {
            return `http://localhost:3000${path}`;
        }
        return path;
    }

    init() {
        if (!this.galleryGrid) return;

        // Bind tab events
        this.tabs.forEach(tab => {
            tab.addEventListener('click', (e) => {
                // Remove active class from all
                this.tabs.forEach(t => t.classList.remove('active'));
                // Add to clicked
                const target = e.currentTarget;
                target.classList.add('active');

                // Update filter
                const section = target.dataset.section; // 'saved' (all for now), 'images', 'videos'
                this.currentFilter = section === 'saved' ? 'all' : section.replace('s', ''); // remove 's' to match workflowType roughly

                this.renderGallery();
            });
        });

        // Initial load
        this.loadGallery();
    }

    async loadGallery() {
        try {
            this.showLoading();

            const response = await fetch(this.getApiUrl('/api/gallery?limit=50'));
            if (!response.ok) throw new Error('Failed to load gallery');

            const data = await response.json();
            this.items = data.items || [];

            this.renderGallery();
        } catch (error) {
            console.error('Gallery load error:', error);
            this.showError();
        }
    }

    showLoading() {
        this.galleryGrid.innerHTML = `
            <div class="video-card-skeleton"></div>
            <div class="video-card-skeleton"></div>
            <div class="video-card-skeleton"></div>
            <div class="video-card-skeleton"></div>
        `;
    }

    showError() {
        this.galleryGrid.innerHTML = `
            <div class="gallery-empty">
                <div class="gallery-empty-icon"><i class="ph ph-warning-circle"></i></div>
                <h3 class="gallery-empty-title">Connection Interrupted</h3>
                <p class="gallery-empty-text">Unable to retrieve your Quantum Manifestations.</p>
                <button class="ai-kings-btn ai-kings-btn-secondary" onclick="window.location.reload()">Retry</button>
            </div>
        `;
    }

    renderGallery() {
        if (this.items.length === 0) {
            this.showEmptyState();
            return;
        }

        const filteredItems = this.items.filter(item => {
            if (this.currentFilter === 'all') return true;
            // Map 'video' filter to 'video' workflowType, 'image' to 'txt2img'/'img2img' or just not video?
            // The server returns workflow_type. Let's assume 'video' is video, rest are images.
            if (this.currentFilter === 'video') return item.workflowType === 'video';
            if (this.currentFilter === 'image') return item.workflowType !== 'video';
            return true;
        });

        if (filteredItems.length === 0) {
            this.galleryGrid.innerHTML = `
                <div class="gallery-empty">
                    <div class="gallery-empty-icon"><i class="ph ph-image"></i></div>
                    <h3 class="gallery-empty-title">No content found</h3>
                    <p class="gallery-empty-text">No ${this.currentFilter}s in your collection yet.</p>
                </div>
            `;
            return;
        }

        this.galleryGrid.innerHTML = filteredItems.map(item => this.createCardHTML(item)).join('');

        // Bind click events for viewing
        this.galleryGrid.querySelectorAll('.video-card').forEach(card => {
            card.addEventListener('click', () => {
                const id = card.dataset.id;
                const item = this.items.find(i => i.id == id); // loose equality for string/int id
                if (item) this.openLightbox(item);
            });
        });
    }

    createCardHTML(item) {
        const isVideo = item.workflowType === 'video';
        const typeLabel = isVideo ? 'VIDEO' : 'IMAGE';

        // Format relative time (basic implementation)
        const date = new Date(item.createdAt);
        const dateStr = date.toLocaleDateString();

        return `
            <div class="video-card" data-id="${item.id}">
                <div class="video-card-thumbnail">
                    <img src="${item.thumbnailUrl}" alt="${item.prompt}" loading="lazy" onerror="this.src='assets/images/placeholder_dark.jpg'">
                    <div class="video-card-play-overlay">
                        <div class="video-card-play-btn">
                            <i class="ph ${isVideo ? 'ph-play' : 'ph-arrows-out'}"></i>
                        </div>
                    </div>
                    <div class="video-card-duration">${typeLabel}</div>
                    <div class="video-card-ai-badge">AI</div>
                </div>
                <div class="video-card-content">
                    <h4 class="video-card-title" title="${item.prompt}">${item.prompt || 'Untitled Manifestation'}</h4>
                    <div class="video-card-meta">
                        <span class="video-card-views">${item.museName || 'Unknown Muse'}</span>
                        <span class="video-card-date">${dateStr}</span>
                    </div>
                    <div class="video-card-tags">
                         <span class="video-card-category">${item.workflowType === 'video' ? 'Motion' : 'Still'}</span>
                    </div>
                </div>
            </div>
        `;
    }

    // Simple lightbox/modal logic
    openLightbox(item) {
        // Reuse the casting room modal structure or a new one?
        // Index.html has a generic modal structure maybe?
        // Let's create a simple overlay dynamically or redirect to direct view
        // For MVP, just open in new tab or use a basic alert/overlay
        // Ideally we'd play the video in place or in a modal.

        // Checking if we have a generic modal we can repurpose.
        // For now, let's just log or open link
        if (item.contentUrl) {
            window.open(item.contentUrl, '_blank');
        }
    }

    showEmptyState() {
        this.galleryGrid.innerHTML = `
            <div class="gallery-empty">
                <div class="gallery-empty-icon"><i class="ph ph-sparkle"></i></div>
                <h3 class="gallery-empty-title">Your Canvas is Blank</h3>
                <p class="gallery-empty-text">Visit the Studio to start creating your first masterpiece.</p>
                <a href="#ai-creation-zone" class="ai-kings-btn ai-kings-btn-primary">Go to Studio</a>
            </div>
        `;
    }
}

// Initialize on load
document.addEventListener('DOMContentLoaded', () => {
    window.galleryManager = new GalleryManager();
});
