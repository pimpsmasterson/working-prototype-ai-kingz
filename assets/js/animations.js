/**
 * AI KINGS - PREMIUM ANIMATIONS SYSTEM v1.0
 * GSAP-powered motion design for exclusive aesthetic.
 */

document.addEventListener('DOMContentLoaded', () => {
    // Register GSAP Plugins
    gsap.registerPlugin(ScrollTrigger);

    // Initial Logo Entrance Animation
    initLogoEntrance();

    // Setup Global Interactions
    initGlobalInteractions();
});

/**
 * High-end entrance for the Crown Logo
 */
function initLogoEntrance() {
    const logo = document.querySelector('.logo-nexus');
    if (!logo) return;

    const tl = gsap.timeline({ defaults: { ease: "power4.out" } });

    // 1. Reveal Crown Container
    tl.fromTo('.crown-container',
        { opacity: 0, scale: 0.8, y: -20 },
        { opacity: 1, scale: 1, y: 0, duration: 1.2 }
    );

    // 2. Animate Spires (Gasp/Stagger effect)
    tl.fromTo('.crown-spire',
        { opacity: 0, y: 15 },
        { opacity: 1, y: 0, duration: 0.8, stagger: 0.1, ease: "back.out(1.7)" },
        "-=0.6"
    );

    // 3. Jewel Terminal Sparkle
    tl.fromTo('.terminal-jewel',
        { opacity: 0, scale: 0 },
        { opacity: 1, scale: 1, duration: 0.6, stagger: 0.05, ease: "elastic.out(1, 0.3)" },
        "-=0.4"
    );

    // 4. Logo Text Reveal
    tl.to('.logo-text',
        { opacity: 1, y: 0, duration: 1, stagger: 0.2 },
        "-=0.5"
    );

    // 5. Ambient Pulse for Jewels (Infinite)
    gsap.to('.terminal-jewel', {
        filter: "url(#crownSpecular) brightness(1.5) drop-shadow(0 0 5px rgba(255, 245, 231, 0.5))",
        duration: 2,
        repeat: -1,
        yoyo: true,
        stagger: {
            each: 0.3,
            from: "center"
        }
    });
}

/**
 * Hover effects and global micro-interactions
 */
function initGlobalInteractions() {
    // Logo Hover Glow
    const logo = document.querySelector('.logo-nexus');
    if (logo) {
        logo.addEventListener('mouseenter', () => {
            gsap.to('.crown-svg', {
                scale: 1.05,
                filter: "drop-shadow(0 0 15px rgba(212, 175, 55, 0.6))",
                duration: 0.4
            });
            gsap.to('.ai-part', {
                backgroundPosition: "100% 0",
                duration: 0.8,
                ease: "power2.inOut"
            });
        });

        logo.addEventListener('mouseleave', () => {
            gsap.to('.crown-svg', {
                scale: 1,
                filter: "drop-shadow(0 4px 8px rgba(0, 0, 0, 0.4))",
                duration: 0.4
            });
            gsap.to('.ai-part', {
                backgroundPosition: "0% 0",
                duration: 0.8
            });
        });
    }

    // Scroll-based reveal for sections
    const reveals = document.querySelectorAll('.animate-on-scroll');
    reveals.forEach(el => {
        gsap.from(el, {
            scrollTrigger: {
                trigger: el,
                start: "top 85%",
                toggleActions: "play none none none"
            },
            opacity: 0,
            y: 30,
            duration: 1,
            ease: "power3.out"
        });
    });
}
