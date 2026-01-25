
// ===========================================
// AIKINGZ PROTOTYPE JAVASCRIPT
// Add your custom JavaScript functionality here
// ===========================================

document.addEventListener('DOMContentLoaded', function() {
  console.log('AIKINGZ Prototype loaded successfully!');

  // Mobile navigation toggle
  const navToggle = document.querySelector('.nav-toggle');
  const navMenu = document.querySelector('.nav-menu');

  if (navToggle && navMenu) {
    navToggle.addEventListener('click', function() {
      navMenu.style.display = navMenu.style.display === 'flex' ? 'none' : 'flex';
      navMenu.style.flexDirection = 'column';
      navMenu.style.position = 'absolute';
      navMenu.style.top = '100%';
      navMenu.style.left = '0';
      navMenu.style.width = '100%';
      navMenu.style.backgroundColor = '#2c3e50';
    });
  }

  // Smooth scrolling for anchor links
  const anchorLinks = document.querySelectorAll('a[href^="#"]');
  anchorLinks.forEach(link => {
    link.addEventListener('click', function(e) {
      const targetId = this.getAttribute('href').substring(1);
      const targetElement = document.getElementById(targetId);

      if (targetElement) {
        e.preventDefault();
        targetElement.scrollIntoView({
          behavior: 'smooth'
        });
      }
    });
  });

  // Add loading class removal
  document.body.classList.remove('loading');
  document.body.classList.add('loaded');

  // Placeholder for custom functionality
  // Add your own JavaScript code below this line

  // Example: Add click tracking to buttons
  const buttons = document.querySelectorAll('.cta-button, button');
  buttons.forEach(button => {
    button.addEventListener('click', function() {
      console.log('Button clicked:', this.textContent);
      // Add your analytics or custom logic here
    });
  });

  // Example: Lazy load images (if needed)
  const images = document.querySelectorAll('img[data-src]');
  const imageObserver = new IntersectionObserver((entries, observer) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const img = entry.target;
        img.src = img.dataset.src;
        img.classList.remove('lazy');
        observer.unobserve(img);
      }
    });
  });

  images.forEach(img => imageObserver.observe(img));
});

// Global functions for customization
window.AIKINGZ = {
  // Add your custom functions here
  customize: function(element, content) {
    if (element) {
      element.innerHTML = content;
    }
  },

  addEvent: function(element, event, callback) {
    if (element) {
      element.addEventListener(event, callback);
    }
  },

  // Example utility function
  showMessage: function(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.textContent = message;
    notification.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      background: ${type === 'error' ? '#e74c3c' : '#27ae60'};
      color: white;
      padding: 1rem;
      border-radius: 4px;
      z-index: 10000;
      animation: slideIn 0.3s ease;
    `;

    document.body.appendChild(notification);

    setTimeout(() => {
      notification.remove();
    }, 3000);
  }
};
