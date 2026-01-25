/**
 * Floating Cards Parallax Effect
 * Mouse-tracking parallax with 3D tilt effects
 * Performance optimized with requestAnimationFrame and throttling
 */

class FloatingCardParallax {
  constructor() {
    this.cards = [];
    this.reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    this.animationFrameId = null;
    this.pendingUpdates = new Map();
    
    // Throttle mouse events to 60fps
    this.throttledUpdate = this.throttle(this.updateCard.bind(this), 16);
    
    this.init();
  }

  init() {
    // Listen for reduced motion changes
    window.matchMedia('(prefers-reduced-motion: reduce)').addEventListener('change', (e) => {
      this.reducedMotion = e.matches;
      if (this.reducedMotion) {
        this.resetAllCards();
      }
    });

    // Initialize cards
    this.observeCards();
    
    // Re-observe when new cards are added
    const observer = new MutationObserver(() => {
      this.observeCards();
    });
    
    const grid = document.querySelector('.video-grid');
    if (grid) {
      observer.observe(grid, { childList: true, subtree: true });
    }
  }

  observeCards() {
    this.cards = Array.from(document.querySelectorAll('.video-card'));
    this.cards.forEach((card, index) => {
      const thumbnail = card.querySelector('.video-card-thumbnail');
      if (thumbnail && !card.dataset.parallaxInitialized) {
        card.dataset.parallaxInitialized = 'true';
        
        // Set will-change for performance
        thumbnail.style.willChange = 'transform';
        
        // Mouse events (desktop)
        card.addEventListener('mousemove', (e) => {
          if (!this.reducedMotion) {
            this.pendingUpdates.set(card, { event: e, thumbnail });
            this.scheduleUpdate();
          }
        });
        
        card.addEventListener('mouseleave', () => {
          this.resetCard(card, thumbnail);
        });
        
        // Touch events (mobile) - tap to reveal
        card.addEventListener('touchstart', () => {
          if (!this.reducedMotion) {
            thumbnail.style.transform = 'translate3d(0, 0, 0) scale(1.05)';
          }
        }, { passive: true });
        
        // Keyboard navigation
        card.addEventListener('focus', () => {
          card.classList.add('keyboard-focused');
        });
        
        card.addEventListener('blur', () => {
          card.classList.remove('keyboard-focused');
        });
      }
    });
  }

  scheduleUpdate() {
    if (!this.animationFrameId) {
      this.animationFrameId = requestAnimationFrame(() => {
        this.processUpdates();
        this.animationFrameId = null;
      });
    }
  }

  processUpdates() {
    this.pendingUpdates.forEach(({ event, thumbnail }, card) => {
      this.updateCard(event, card, thumbnail);
    });
    this.pendingUpdates.clear();
  }

  updateCard(e, card, thumbnail) {
    const rect = card.getBoundingClientRect();
    const centerX = rect.left + rect.width / 2;
    const centerY = rect.top + rect.height / 2;
    
    const deltaX = (e.clientX - centerX) / rect.width;
    const deltaY = (e.clientY - centerY) / rect.height;
    
    // Moderate intensity: 15px max movement
    const moveX = deltaX * 15;
    const moveY = deltaY * 15;
    
    // Smooth rotation for 3D depth (subtle)
    const rotateX = deltaY * 5;
    const rotateY = deltaX * -5;
    
    // Apply transform with GPU acceleration
    thumbnail.style.transform = `
      translate3d(${moveX}px, ${moveY}px, 0)
      rotateX(${rotateX}deg)
      rotateY(${rotateY}deg)
      scale(1.05)
    `;
    
    // Update CSS custom property for glow effect
    const mouseXPercent = ((e.clientX - rect.left) / rect.width) * 100;
    const mouseYPercent = ((e.clientY - rect.top) / rect.height) * 100;
    thumbnail.style.setProperty('--mouse-x', `${mouseXPercent}%`);
    thumbnail.style.setProperty('--mouse-y', `${mouseYPercent}%`);
  }

  resetCard(card, thumbnail) {
    thumbnail.style.transform = 'translate3d(0, 0, 0) rotateX(0) rotateY(0) scale(1)';
    thumbnail.style.setProperty('--mouse-x', '50%');
    thumbnail.style.setProperty('--mouse-y', '50%');
  }

  resetAllCards() {
    this.cards.forEach(card => {
      const thumbnail = card.querySelector('.video-card-thumbnail');
      if (thumbnail) {
        this.resetCard(card, thumbnail);
      }
    });
  }

  throttle(func, limit) {
    let inThrottle;
    return function(...args) {
      if (!inThrottle) {
        func.apply(this, args);
        inThrottle = true;
        setTimeout(() => inThrottle = false, limit);
      }
    };
  }
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    window.floatingCardsParallax = new FloatingCardParallax();
  });
} else {
  window.floatingCardsParallax = new FloatingCardParallax();
}
