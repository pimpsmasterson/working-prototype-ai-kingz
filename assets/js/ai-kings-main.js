/**
 * AI KINGS Main JavaScript - VELVET VOID EDITION
 * Features: GSAP Motion, Phosphor Icons, Seductive UI Logic
 */

class AIKingsApp {
  constructor() {
    this.videoData = null;
    this.filteredVideos = [];
    this.currentFilters = {
      category: 'all',
      sort: 'newest',
      search: '',
      view: 'grid',
      tags: []
    };
    this.lazyLoadObserver = null;

    this.init();
  }

  async init() {
    try {
      this.initMotion(); // Initialize GSAP
      await this.loadVideoData();
      this.setupEventListeners();
      this.initCollectionTabs(); // Initialize tabs first
      this.initializeComponents(); // Then initialize filters based on active tab
      this.setupLazyLoading();
      this.setupMagneticButtons();
    } catch (error) {
      console.error('Failed to initialize AI KINGS App:', error);
    }
  }

  initCollectionTabs() {
    const tabs = document.querySelectorAll('.collection-tab');
    if (tabs.length === 0) {
      console.warn('Collection tabs not found');
      return;
    }

    tabs.forEach(tab => {
      tab.addEventListener('click', (e) => {
        const section = e.currentTarget.dataset.section;
        
        console.log('Collection tab clicked:', section);
        
        // Update active state
        tabs.forEach(t => t.classList.remove('active'));
        e.currentTarget.classList.add('active');
        
        // Handle section switching
        this.switchCollectionSection(section);
      });
    });
    
    console.log('✅ Collection tabs initialized');
  }

  switchCollectionSection(section) {
    // Store current section
    this.currentSection = section;

    console.log('Switching to section:', section);

    // Get user's saved content from localStorage
    const savedContent = this.getUserSavedContent();
    
    console.log('Saved content loaded:', savedContent.length, 'items');

    // Filter content based on section
    let filtered = [];
    
    switch(section) {
      case 'saved':
        // Show saved/bookmarked content from localStorage
        filtered = savedContent.filter(item => 
          item.isSaved || item.isBookmarked || item.isFavorite
        );
        break;
      case 'images':
        // Show image content (items without videoUrl or with image type)
        filtered = savedContent.filter(item => 
          !item.videoUrl || item.type === 'image' || item.mediaType === 'image'
        );
        break;
      case 'videos':
        // Show video content
        filtered = savedContent.filter(item => 
          item.videoUrl && item.type !== 'image' && item.mediaType !== 'image'
        );
        break;
      default:
        filtered = savedContent;
    }

    console.log('Filtered content for', section + ':', filtered.length, 'items');

    // Update filters based on current content
    this.updateDynamicFilters(filtered);

    // Render filtered content
    this.renderGallery(filtered);
  }

  getUserSavedContent() {
    // Get user's saved/generated content from localStorage
    try {
      const savedItems = localStorage.getItem('ai-kings-saved-content');
      const generationHistory = localStorage.getItem('ai-kings-generation-history');
      
      let content = [];
      
      // Load saved content
      if (savedItems) {
        const parsed = JSON.parse(savedItems);
        content = Array.isArray(parsed) ? parsed : [];
      }
      
      // Load generation history as saved content
      if (generationHistory) {
        const history = JSON.parse(generationHistory);
        if (Array.isArray(history)) {
          // Convert generation history to video format
          const historyItems = history.map(item => ({
            id: item.id || `gen-${Date.now()}-${Math.random()}`,
            title: item.prompt || item.title || 'Generated Content',
            description: item.description || '',
            thumbnail: item.thumbnail || item.imageUrl || '',
            videoUrl: item.videoUrl || '',
            category: item.category || 'user-generated',
            tags: item.tags || this.extractTagsFromPrompt(item.prompt || ''),
            duration: item.duration || '0:00',
            views: 0,
            rating: 0,
            createdAt: item.createdAt || new Date().toISOString(),
            isAIGenerated: true,
            type: item.type || (item.videoUrl ? 'video' : 'image'),
            mediaType: item.mediaType || (item.videoUrl ? 'video' : 'image'),
            isSaved: true,
            isBookmarked: true
          }));
          content = [...content, ...historyItems];
        }
      }
      
      // If no saved content, return empty array
      return content.length > 0 ? content : [];
    } catch (error) {
      console.warn('Failed to load saved content:', error);
      return [];
    }
  }

  extractTagsFromPrompt(prompt) {
    // Extract potential tags from user prompt
    if (!prompt) return [];
    
    const words = prompt.toLowerCase()
      .replace(/[^\w\s]/g, ' ')
      .split(/\s+/)
      .filter(word => word.length > 3);
    
    // Return unique words as potential tags
    return [...new Set(words)].slice(0, 10);
  }

  renderGallery(videos) {
    const grid = document.querySelector('.video-grid');
    if (!grid) return;

    if (videos.length === 0) {
      grid.innerHTML = `
        <div class="gallery-empty" style="grid-column: 1 / -1; text-align: center; padding: 3rem;">
          <i class="ph ph-folder-open" style="font-size: 3rem; opacity: 0.3; margin-bottom: 1rem;"></i>
          <h3 style="color: var(--text-main); margin-bottom: 0.5rem;">No content found</h3>
          <p style="color: var(--text-muted);">Try a different section or create new content.</p>
        </div>
      `;
      return;
    }

    grid.innerHTML = videos.map(video => this.createVideoCard(video)).join('');
    
    // Re-initialize lazy loading for new content
    this.setupLazyLoading();
    
    // Re-initialize parallax for new cards
    if (window.floatingCardsParallax) {
      window.floatingCardsParallax.observeCards();
    }
  }

  initMotion() {
    if (typeof gsap !== 'undefined' && typeof ScrollTrigger !== 'undefined') {
      gsap.registerPlugin(ScrollTrigger);

      // Hero Animation - Cinematic Entry
      const heroTl = gsap.timeline({ defaults: { ease: "power4.out" } });

      heroTl.from(".hero-cinematic", {
        opacity: 0,
        duration: 2
      })
        .from(".creation-zone-title", {
          y: 80,
          opacity: 0,
          duration: 1.8,
          filter: "blur(20px)",
          letterSpacing: "0.2em"
        }, 0.5)
        .from(".creation-zone-subtitle", {
          y: 40,
          opacity: 0,
          duration: 1.5,
          filter: "blur(10px)"
        }, "-=1.2")
        .from(".input-terminal-wrapper", {
          y: 60,
          opacity: 0,
          duration: 1.5,
          scale: 0.98,
          ease: "expo.out"
        }, "-=1.0");

      if (document.querySelector('.hero-bg-video')) {
        heroTl.to(".hero-bg-video", {
          opacity: 0.2,
          scale: 1.1,
          duration: 3
        }, 0);
      }

      // Parallax Background
      gsap.to(".hero-bg-video", {
        scrollTrigger: {
          trigger: ".hero-cinematic",
          start: "top top",
          end: "bottom top",
          scrub: true
        },
        yPercent: 30,
        scale: 1.1
      });

      // Section Headers - Reveal on Scroll
      gsap.utils.toArray('.ai-kings-section').forEach(section => {
        gsap.from(section.querySelectorAll('h2, .section-subtitle'), {
          scrollTrigger: {
            trigger: section,
            start: "top 85%",
            toggleActions: "play none none reverse"
          },
          y: 60,
          opacity: 0,
          duration: 1,
          stagger: 0.15,
          ease: "circ.out"
        });
      });

      // Video Grid Stagger (Premium Reveal)
      ScrollTrigger.batch(".video-card", {
        onEnter: batch => gsap.to(batch, {
          opacity: 1,
          y: 0,
          stagger: 0.1,
          duration: 0.8,
          ease: "power2.out",
          overwrite: true
        }),
        onLeave: batch => gsap.set(batch, { opacity: 0, y: 50 }) // Optional: fade out on leave
      });
    }
  }

  setupMagneticButtons() {
    const buttons = document.querySelectorAll('.btn-magnetic');
    buttons.forEach(btn => {
      const text = btn.querySelector('span'); // Assuming text is in a span for separate animation

      btn.addEventListener('mousemove', (e) => {
        const rect = btn.getBoundingClientRect();
        const x = e.clientX - rect.left - rect.width / 2;
        const y = e.clientY - rect.top - rect.height / 2;

        gsap.to(btn, {
          x: x * 0.3,
          y: y * 0.3,
          duration: 0.4,
          ease: "power2.out"
        });

        if (text) {
          gsap.to(text, {
            x: x * 0.1,
            y: y * 0.1,
            duration: 0.4,
            ease: "power2.out"
          });
        }
      });

      btn.addEventListener('mouseleave', () => {
        gsap.to([btn, text], {
          x: 0,
          y: 0,
          duration: 1,
          ease: "elastic.out(1, 0.3)"
        });
      });
    });
  }

  async loadVideoData() {
    // Bulletproof: Use hardcoded data store if available (bypasses CORS/file protocol fetch issues)
    if (window.AI_KINGS_DATA) {
      console.log('Using Bulletproof Data Store');
      this.videoData = window.AI_KINGS_DATA;
      this.filteredVideos = [...this.videoData.videos];
      this.renderGallery();
      return;
    }

    const paths = ['data/videos.json', '../data/videos.json'];

    for (const path of paths) {
      try {
        const response = await fetch(path);
        if (response.ok) {
          this.videoData = await response.json();
          this.filteredVideos = [...this.videoData.videos];
          this.renderGallery();
          return; // Success
        }
      } catch (error) {
        console.warn(`Failed to load video data from ${path}`, error);
      }
    }

    console.error('Could not load video data from any path.');
    this.showError('Failed to load video content.');
  }

  setupEventListeners() {
    // Filter controls - will be set up dynamically in updateDynamicFilters
    // setupFilterListeners() is called after filters are rendered

    // Sort control
    const sortSelect = document.querySelector('.sort-select');
    if (sortSelect) {
      sortSelect.addEventListener('change', (e) => this.handleSortChange(e));
    }

    // View toggle
    document.querySelectorAll('.view-toggle-btn').forEach(btn => {
      btn.addEventListener('click', (e) => this.handleViewToggle(e));
    });

    // Nav Toggle
    const navToggle = document.querySelector('.nav-toggle');
    if (navToggle) {
      navToggle.addEventListener('click', (e) => this.toggleMobileNav(e));
    }

    // Smooth Scroll
    window.addEventListener('scroll', () => this.handleScroll());
  }

  initializeComponents() {
    // Check if we have any content, if not, offer test data
    const content = this.getUserSavedContent();
    
    if (content.length === 0) {
      // No content yet - load test data for demonstration
      console.log('No saved content found. Loading test data...');
      this.loadTestData();
      const testContent = this.getUserSavedContent();
      this.updateDynamicFilters(testContent);
      if (testContent.length > 0) {
        this.renderGallery(testContent);
      }
    } else {
      // Initialize filters based on current content
      // If collection tabs exist, start with saved content
      const savedTab = document.querySelector('.collection-tab[data-section="saved"]');
      if (savedTab && savedTab.classList.contains('active')) {
        this.switchCollectionSection('saved');
      } else {
        // Otherwise, initialize with all user content
        this.updateDynamicFilters(content);
        if (content.length > 0) {
          this.renderGallery(content);
        }
      }
    }
  }

  loadTestData() {
    // Generate test data for demonstration
    const testContent = [
      {
        id: 'test-001',
        title: 'BDSM Domination Scene',
        description: 'AI-generated BDSM content featuring dominant scenarios',
        thumbnail: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&q=80&w=400',
        videoUrl: '',
        category: 'bdsm',
        tags: ['bdsm', 'domination', 'fetish', 'kink', 'leather'],
        duration: '12:15',
        views: 28300,
        rating: 4.9,
        createdAt: new Date(Date.now() - 86400000).toISOString(),
        isAIGenerated: true,
        type: 'image',
        mediaType: 'image',
        isSaved: true,
        isBookmarked: true
      },
      {
        id: 'test-002',
        title: 'Roleplay Fantasy Encounter',
        description: 'Fantasy roleplay scenario with elaborate costumes',
        thumbnail: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&q=80&w=400',
        videoUrl: 'https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4',
        category: 'roleplay',
        tags: ['roleplay', 'fantasy', 'costume', 'kink', 'fetish'],
        duration: '8:42',
        views: 15420,
        rating: 4.8,
        createdAt: new Date(Date.now() - 172800000).toISOString(),
        isAIGenerated: true,
        type: 'video',
        mediaType: 'video',
        isSaved: true,
        isBookmarked: false
      },
      {
        id: 'test-003',
        title: 'Submission Training Session',
        description: 'Submissive training and discipline content',
        thumbnail: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&q=80&w=400',
        videoUrl: '',
        category: 'submission',
        tags: ['submission', 'training', 'discipline', 'bdsm', 'kink'],
        duration: '15:27',
        views: 45700,
        rating: 4.6,
        createdAt: new Date(Date.now() - 259200000).toISOString(),
        isAIGenerated: true,
        type: 'image',
        mediaType: 'image',
        isSaved: true,
        isBookmarked: true
      },
      {
        id: 'test-004',
        title: 'Group Scene Video',
        description: 'Multiple participant scenario',
        thumbnail: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&q=80&w=400',
        videoUrl: 'https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4',
        category: 'group',
        tags: ['group', 'multiple', 'party', 'fetish'],
        duration: '18:45',
        views: 32100,
        rating: 4.8,
        createdAt: new Date(Date.now() - 345600000).toISOString(),
        isAIGenerated: true,
        type: 'video',
        mediaType: 'video',
        isSaved: true,
        isBookmarked: false
      },
      {
        id: 'test-005',
        title: 'Anal Focus Content',
        description: 'Anal-focused fetish content',
        thumbnail: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&q=80&w=400',
        videoUrl: '',
        category: 'anal',
        tags: ['anal', 'fetish', 'kink', 'hardcore'],
        duration: '11:52',
        views: 19200,
        rating: 4.7,
        createdAt: new Date(Date.now() - 432000000).toISOString(),
        isAIGenerated: true,
        type: 'image',
        mediaType: 'image',
        isSaved: true,
        isBookmarked: true
      },
      {
        id: 'test-006',
        title: 'Oral Pleasure Session',
        description: 'Oral-focused content',
        thumbnail: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&q=80&w=400',
        videoUrl: 'https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4',
        category: 'oral',
        tags: ['oral', 'pleasure', 'fetish', 'kink'],
        duration: '6:33',
        views: 9900,
        rating: 4.7,
        createdAt: new Date(Date.now() - 518400000).toISOString(),
        isAIGenerated: true,
        type: 'video',
        mediaType: 'video',
        isSaved: true,
        isBookmarked: false
      }
    ];

    // Save test data to localStorage
    try {
      localStorage.setItem('ai-kings-saved-content', JSON.stringify(testContent));
      console.log('✅ Test data loaded:', testContent.length, 'items');
      return true;
    } catch (error) {
      console.error('Failed to load test data:', error);
      return false;
    }
  }

  handleScroll() {
    const nav = document.querySelector('.main-navigation');
    if (nav) {
      if (window.scrollY > 50) nav.classList.add('scrolled');
      else nav.classList.remove('scrolled');
    }
  }

  createVideoCard(video, context = 'grid') {
    return `
      <div class="video-card card-voyeur ${video.isAIGenerated ? 'ai-generated' : ''}" 
           data-video-id="${video.id}"
           role="article"
           aria-label="Video: ${video.title}, ${video.duration}, ${this.formatNumber(video.views)} views, ${video.rating} stars"
           tabindex="0">
        <div class="video-card-thumbnail card-img-bg" style="background-image: url('${video.thumbnail}')">
          <img src="${video.thumbnail}" 
               alt="${video.title}"
               loading="lazy"
               decoding="async"
               data-video-id="${video.id}"
               style="display: none;">
          <div class="video-card-play-overlay" aria-hidden="true">
            <div class="video-card-play-btn" aria-label="Play ${video.title}">
              <i class="ph-fill ph-play"></i>
            </div>
          </div>
          <div class="video-card-duration" aria-label="Duration: ${video.duration}">${video.duration}</div>
        </div>
        <div class="video-card-content card-content-overlay">
          <h3 class="video-card-title">${video.title}</h3>
          <div class="video-card-meta">
            <div class="video-card-views" aria-label="${this.formatNumber(video.views)} views">
              <i class="ph ph-eye" aria-hidden="true"></i> ${this.formatNumber(video.views)}
            </div>
            <div class="video-card-rating" aria-label="Rating: ${video.rating} stars">
              <i class="ph-fill ph-star text-gold" aria-hidden="true"></i> ${video.rating}
            </div>
          </div>
        </div>
      </div>
    `;
  }

  createEmptyState() {
    return `
      <div class="gallery-empty">
        <div class="gallery-empty-icon">
          <div class="empty-icon-circle">
            <span><i class="ph ph-film-slash"></i></span>
          </div>
        </div>
        <h3 class="gallery-empty-title">No videos found</h3>
        <p class="gallery-empty-text">Try adjusting your filters or search terms to discover amazing AI-generated content.</p>
        <button class="ai-kings-btn ai-kings-btn-secondary reset-filters-btn">
          <span><i class="ph ph-arrow-counter-clockwise"></i></span> Reset Filters
        </button>
      </div>
    `;
  }


  updateFilterChips() {
    // This method is now replaced by updateDynamicFilters
    // Kept for backwards compatibility
    const currentContent = this.getCurrentContentForFilters();
    this.updateDynamicFilters(currentContent);
  }

  getCurrentContentForFilters() {
    // Get content based on current section
    if (this.currentSection) {
      return this.getUserSavedContent();
    }
    
    // Fallback to videoData if no section selected
    return this.videoData?.videos || [];
  }

  updateDynamicFilters(content) {
    const filterContainer = document.querySelector('.gallery-filters');
    if (!filterContainer) {
      console.warn('Filter container not found');
      return;
    }

    // Handle empty content
    if (!content || content.length === 0) {
      filterContainer.innerHTML = `
        <button class="filter-chip active" data-filter-id="all" data-filter-type="all">
          All <span class="filter-count">0</span>
        </button>
        <div style="color: var(--text-muted); padding: 1rem; font-size: 0.875rem;">
          No content yet. Generate or save content to see filters.
        </div>
      `;
      return;
    }

    // Extract unique categories and tags from user's actual content
    const filterMap = new Map(); // Use single map to avoid duplicates

    content.forEach(item => {
      // Collect categories (prioritize categories over tags)
      if (item.category) {
        const catId = item.category.toLowerCase().replace(/\s+/g, '-');
        const catName = item.category.charAt(0).toUpperCase() + item.category.slice(1);
        if (!filterMap.has(catId)) {
          filterMap.set(catId, {
            id: catId,
            name: catName,
            count: 0,
            type: 'category',
            priority: 1 // Categories have higher priority
          });
        }
        filterMap.get(catId).count++;
      }

      // Collect tags (only if not already a category)
      if (item.tags && Array.isArray(item.tags)) {
        item.tags.forEach(tag => {
          const tagId = tag.toLowerCase().replace(/\s+/g, '-');
          const tagName = tag.charAt(0).toUpperCase() + tag.slice(1);
          
          // Skip if already exists as category
          if (filterMap.has(tagId) && filterMap.get(tagId).type === 'category') {
            return;
          }
          
          if (!filterMap.has(tagId) && tag.length > 2) {
            filterMap.set(tagId, {
              id: tagId,
              name: tagName,
              count: 0,
              type: 'tag',
              priority: 2 // Tags have lower priority
            });
          }
          if (filterMap.has(tagId)) {
            filterMap.get(tagId).count++;
          }
        });
      }
    });

    // Build filters array
    const filters = [
      { id: 'all', name: 'All', count: content.length, type: 'all', priority: 0 }
    ];

    // Add filters (categories first, then popular tags)
    filterMap.forEach(filter => {
      // Only add tags if they appear in 2+ items
      if (filter.type === 'tag' && filter.count < 2) {
        return;
      }
      filters.push(filter);
    });

    // Sort by priority (categories first), then by count
    filters.sort((a, b) => {
      if (a.priority !== b.priority) return a.priority - b.priority;
      return (b.count || 0) - (a.count || 0);
    });
    
    // Limit to 15 filters
    const displayFilters = filters.slice(0, 15);

    // Store old active filter
    const activeFilter = filterContainer.querySelector('.filter-chip.active');
    const activeFilterId = activeFilter?.dataset.filterId || 'all';

    // Render filter chips
    if (displayFilters.length === 0) {
      filterContainer.innerHTML = `
        <button class="filter-chip active" data-filter-id="all" data-filter-type="all">
          All <span class="filter-count">0</span>
        </button>
      `;
    } else {
      filterContainer.innerHTML = displayFilters.map(filter => `
        <button class="filter-chip ${filter.id === activeFilterId ? 'active' : ''}"
                data-filter-id="${filter.id}"
                data-filter-type="${filter.type}"
                title="${filter.count || 0} items">
          <span class="filter-text">${filter.name}</span>
          ${filter.count > 0 ? `<span class="filter-count">${filter.count}</span>` : ''}
        </button>
      `).join('');
    }

    // Animate filter chips with GSAP
    this.animateFilterChips();

    // Re-attach event listeners
    this.setupFilterListeners();
    
    console.log('✅ Filters updated:', displayFilters.length, 'filters from', content.length, 'items');
  }

  animateFilterChips() {
    if (typeof gsap === 'undefined') return;

    const chips = document.querySelectorAll('.filter-chip');
    if (chips.length === 0) return;

    // Stagger animation for filter chips
    gsap.fromTo(chips, 
      {
        opacity: 0,
        y: -10,
        scale: 0.9
      },
      {
        opacity: 1,
        y: 0,
        scale: 1,
        duration: 0.4,
        stagger: 0.03,
        ease: "back.out(1.2)"
      }
    );
  }

  setupFilterListeners() {
    // Remove old listeners and add new ones
    document.querySelectorAll('.filter-chip').forEach(chip => {
      // Remove existing listeners by cloning
      const newChip = chip.cloneNode(true);
      chip.parentNode.replaceChild(newChip, chip);
      
      // Add click listener
      newChip.addEventListener('click', (e) => this.handleFilterClick(e));
      
      // Add GSAP hover animations
      if (typeof gsap !== 'undefined') {
        this.setupFilterHoverAnimation(newChip);
      }
    });
    
    console.log('✅ Filter listeners attached');
  }

  setupFilterHoverAnimation(chip) {
    if (typeof gsap === 'undefined') return;

    // Mouse tracking for glow effect
    chip.addEventListener('mousemove', (e) => {
      const rect = chip.getBoundingClientRect();
      const x = ((e.clientX - rect.left) / rect.width) * 100;
      const y = ((e.clientY - rect.top) / rect.height) * 100;
      chip.style.setProperty('--mouse-x', `${x}%`);
      chip.style.setProperty('--mouse-y', `${y}%`);
    });

    chip.addEventListener('mouseenter', () => {
      if (chip.classList.contains('active')) return;
      
      gsap.to(chip, {
        scale: 1.05,
        y: -2,
        duration: 0.3,
        ease: "power2.out"
      });
    });

    chip.addEventListener('mouseleave', () => {
      if (chip.classList.contains('active')) return;
      
      gsap.to(chip, {
        scale: 1,
        y: 0,
        duration: 0.3,
        ease: "power2.out"
      });
    });
  }

  // ... (Preserve other methods like loadVideoData specifics if needed, but simplified here for updating) ...

  formatNumber(num) {
    if (num >= 1000000) return (num / 1000000).toFixed(1) + 'M';
    else if (num >= 1000) return (num / 1000).toFixed(1) + 'K';
    return num.toString();
  }

  handleFilterClick(e) {
    const chip = e.target.closest('.filter-chip');
    if (!chip) {
      console.warn('Filter chip not found');
      return;
    }

    // Animate filter selection with GSAP
    if (typeof gsap !== 'undefined') {
      // Pulse animation on click
      gsap.to(chip, {
        scale: 0.95,
        duration: 0.1,
        yoyo: true,
        repeat: 1,
        ease: "power2.inOut"
      });
    }

    // Get all chips
    const allChips = document.querySelectorAll('.filter-chip');
    const filterId = chip.dataset.filterId;
    const filterType = chip.dataset.filterType;

    console.log('Filter clicked:', filterId, filterType);

    // Animate active state change
    if (typeof gsap !== 'undefined') {
      allChips.forEach(c => {
        if (c === chip) {
          gsap.to(c, {
            scale: 1.1,
            duration: 0.2,
            ease: "back.out(1.5)",
            onComplete: () => {
              c.classList.add('active');
              gsap.to(c, { scale: 1, duration: 0.2 });
            }
          });
        } else {
          c.classList.remove('active');
          gsap.to(c, {
            scale: 1,
            duration: 0.2
          });
        }
      });
    } else {
      // Fallback without GSAP
      allChips.forEach(c => c.classList.remove('active'));
      chip.classList.add('active');
    }

    // Get current content based on section
    let content = this.getCurrentContentForFilters();
    
    console.log('Current content:', content.length, 'items');

    // Apply filter
    if (filterId === 'all') {
      // Show all content
      console.log('Showing all content');
      this.renderGallery(content);
    } else {
      // Filter by category or tag
      const filtered = content.filter(item => {
        if (filterType === 'category') {
          const itemCategory = item.category?.toLowerCase().replace(/\s+/g, '-');
          return itemCategory === filterId;
        } else if (filterType === 'tag') {
          const itemTags = item.tags || [];
          return itemTags.some(tag => 
            tag.toLowerCase().replace(/\s+/g, '-') === filterId
          );
        }
        return false;
      });

      console.log('Filtered content:', filtered.length, 'items');
      this.renderGallery(filtered);
    }
  }

  handleSortChange(e) {
    this.currentFilters.sort = e.target.value;
    console.log("Sorting by", this.currentFilters.sort);
    this.renderGallery();
  }

  handleViewToggle(e) {
    const btn = e.target.closest('.view-toggle-btn');
    if (btn) {
      document.querySelectorAll('.view-toggle-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      this.currentFilters.view = btn.dataset.view;
      this.renderGallery();
    }
  }

  toggleMobileNav(e) {
    const nav = document.querySelector('.nav-menu');
    const toggle = document.querySelector('.nav-toggle');
    if (nav && toggle) {
      nav.classList.toggle('active');
      toggle.setAttribute('aria-expanded', nav.classList.contains('active'));
    }
  }

  renderGallery() {
    // Render main gallery grid
    const galleryGrid = document.querySelector('.video-grid');
    if (galleryGrid && this.filteredVideos.length > 0) {
      galleryGrid.innerHTML = this.filteredVideos.map(v => this.createVideoCard(v, 'grid')).join('');
      
      // Re-initialize lazy loading for new content
      this.setupLazyLoading();
      
      // Re-initialize parallax for new cards
      if (window.floatingCardsParallax) {
        window.floatingCardsParallax.observeCards();
      }
    } else if (galleryGrid) {
      galleryGrid.innerHTML = this.createEmptyState();
    }
  }

  showError(message) {
    console.error('AI KINGS Error:', message);
    // Could display a toast notification here
  }

  saveContentToUserCollection(contentItem) {
    // Save user-generated/saved content to localStorage
    try {
      const savedItems = this.getUserSavedContent();
      
      // Check if item already exists
      const existingIndex = savedItems.findIndex(item => item.id === contentItem.id);
      
      if (existingIndex >= 0) {
        // Update existing item
        savedItems[existingIndex] = { ...savedItems[existingIndex], ...contentItem };
      } else {
        // Add new item
        savedItems.push({
          ...contentItem,
          isSaved: true,
          createdAt: contentItem.createdAt || new Date().toISOString()
        });
      }
      
      // Save to localStorage
      localStorage.setItem('ai-kings-saved-content', JSON.stringify(savedItems));
      
      // Update filters if on saved/images/videos section
      if (this.currentSection) {
        this.switchCollectionSection(this.currentSection);
      } else {
        this.updateDynamicFilters(savedItems);
      }
      
      return true;
    } catch (error) {
      console.error('Failed to save content:', error);
      return false;
    }
  }

  setupLazyLoading() {
    if ('IntersectionObserver' in window) {
      this.lazyLoadObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            const img = entry.target;
            if (img.dataset.src) {
              img.src = img.dataset.src;
              img.removeAttribute('data-src');
              this.lazyLoadObserver.unobserve(img);
            }
          }
        });
      }, { rootMargin: '100px' });

      document.querySelectorAll('img[data-src]').forEach(img => {
        this.lazyLoadObserver.observe(img);
      });
    }
  }
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
  window.aiKingsApp = new AIKingsApp();
  
  // Expose test functions to console for debugging
  window.testFilters = {
    loadTestData: () => {
      if (window.aiKingsApp) {
        window.aiKingsApp.loadTestData();
        window.aiKingsApp.initializeComponents();
        console.log('✅ Test data loaded! Refresh filters and content.');
      }
    },
    clearTestData: () => {
      localStorage.removeItem('ai-kings-saved-content');
      localStorage.removeItem('ai-kings-generation-history');
      console.log('✅ Test data cleared!');
      if (window.aiKingsApp) {
        window.aiKingsApp.initializeComponents();
      }
    },
    showContent: () => {
      if (window.aiKingsApp) {
        const content = window.aiKingsApp.getUserSavedContent();
        console.log('Current saved content:', content);
        return content;
      }
    },
    refreshFilters: () => {
      if (window.aiKingsApp) {
        const content = window.aiKingsApp.getCurrentContentForFilters();
        window.aiKingsApp.updateDynamicFilters(content);
        console.log('✅ Filters refreshed!');
      }
    }
  };
  
  console.log('🧪 Test functions available:');
  console.log('  testFilters.loadTestData() - Load sample content');
  console.log('  testFilters.clearTestData() - Clear all saved content');
  console.log('  testFilters.showContent() - Show current saved content');
  console.log('  testFilters.refreshFilters() - Refresh filter chips');
});