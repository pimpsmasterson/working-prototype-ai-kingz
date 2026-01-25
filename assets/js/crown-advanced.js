/**
 * IMPERIAL CROWN - ADVANCED GSAP ANIMATION v8.0
 * Professional Luxury Brand Animation
 * Techniques: Gradient Animation, Parallax Depth, Staggered Sequencing, Metallic Sheen
 */

document.addEventListener('DOMContentLoaded', () => {
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    // Main timeline with advanced sequencing
    const masterTL = gsap.timeline({
        defaults: { ease: "power2.inOut" },
        paused: false
    });

    // Element selections
    const crownContainer = document.querySelector('.crown-container');
    const baseTier = document.querySelector('.base-tier');
    const lowerRing = document.querySelector('.lower-ring');
    const crownBody = document.querySelector('.crown-body');
    const fleurOrnaments = document.querySelector('.fleur-ornaments');
    const peakJewels = document.querySelector('.peak-jewels');
    const chains = document.querySelector('.chains');
    const logoText = document.querySelector('.logo-text');
    const aiPart = document.querySelector('.ai-part');

    if (!crownContainer || !logoText) return;

    // ==========================================
    // ADVANCED GRADIENT ANIMATION (Metallic Sheen)
    // ==========================================

    function animateMetallicSheen() {
        // Animate gold gradient offsets for dynamic metallic shine
        const goldGradients = document.querySelectorAll('#deepGold stop, #darkGold stop');

        goldGradients.forEach((stop, index) => {
            gsap.to(stop, {
                attr: {
                    stopColor: gsap.utils.random(["#FFD700", "#DAA520", "#B8860B"], true)
                },
                duration: 3,
                repeat: -1,
                yoyo: true,
                ease: "sine.inOut",
                delay: index * 0.2
            });
        });
    }

    // ==========================================
    // IMPERIAL ENTRANCE SEQUENCE (Multi-Stage Build)
    // ==========================================

    // Stage 1: Crown descends from above with authority
    gsap.set(crownContainer, {
        y: -80,
        opacity: 0,
        scale: 0.85
    });

    // Stage 2: Prepare individual tiers (hidden)
    gsap.set([baseTier, lowerRing, crownBody], {
        opacity: 0,
        scale: 0.9,
        transformOrigin: "center bottom"
    });

    gsap.set([fleurOrnaments, peakJewels], {
        opacity: 0,
        scale: 0
    });

    gsap.set(chains, {
        opacity: 0
    });

    // Build the crown layer by layer
    masterTL
        // 1. Crown container descends powerfully
        .to(crownContainer, {
            y: 0,
            opacity: 1,
            scale: 1,
            duration: 1.2,
            ease: "power4.out"
        })
        // 2. Base tier materializes (foundation first)
        .to(baseTier, {
            opacity: 1,
            scale: 1,
            duration: 0.8,
            ease: "back.out(1.5)"
        }, "-=0.6")
        // 3. Lower jeweled ring expands
        .to(lowerRing, {
            opacity: 1,
            scale: 1,
            duration: 0.9,
            ease: "elastic.out(1, 0.6)"
        }, "-=0.3")
        // 4. Main crown body rises (arches grow)
        .to(crownBody, {
            opacity: 1,
            scale: 1,
            duration: 1.0,
            ease: "power3.out"
        }, "-=0.4")
        // 5. Fleur-de-lis ornaments pop in (staggered from center)
        .to(fleurOrnaments, {
            opacity: 1,
            scale: 1,
            duration: 0.7,
            ease: "back.out(2.5)"
        }, "-=0.5")
        // 6. Peak jewels appear with brilliance (staggered)
        .to(peakJewels, {
            opacity: 1,
            scale: 1,
            duration: 0.8,
            ease: "elastic.out(1, 0.5)"
        }, "-=0.4")
        // 7. Decorative chains fade in
        .to(chains, {
            opacity: 0.4,
            duration: 0.6,
            ease: "sine.inOut"
        }, "-=0.5")
        // 8. Text reveal
        .to(logoText, {
            opacity: 1,
            y: 0,
            duration: 1.0,
            ease: "power2.out"
        }, "-=0.4");

    // Start metallic sheen animation after entrance
    masterTL.call(animateMetallicSheen, null, "+=0.3");

    // ==========================================
    // JEWEL SPARKLE (Staggered, Randomized)
    // ==========================================

    function createJewelSparkle() {
        const jewels = document.querySelectorAll('.peak-jewels ellipse, .lower-ring ellipse, .base-tier circle');

        jewels.forEach((jewel, index) => {
            const randomDelay = Math.random() * 2;
            const randomDuration = 1 + Math.random() * 1.5;

            // Glow pulse
            gsap.to(jewel, {
                attr: {
                    opacity: 1
                },
                filter: `drop-shadow(0 0 ${4 + Math.random() * 4}px rgba(255,255,255,0.9)) drop-shadow(0 0 ${8 + Math.random() * 6}px currentColor)`,
                duration: randomDuration,
                repeat: -1,
                yoyo: true,
                delay: randomDelay,
                ease: "sine.inOut"
            });
        });
    }

    masterTL.call(createJewelSparkle, null, "+=0.2");

    // ==========================================
    // 3D PARALLAX DEPTH (Advanced Hover)
    // ==========================================

    const nexus = document.getElementById('logo-nexus');

    if (nexus) {
        // Track mouse position for parallax
        let mouseX = 0;
        let mouseY = 0;

        nexus.addEventListener('mousemove', (e) => {
            const rect = nexus.getBoundingClientRect();
            mouseX = (e.clientX - rect.left - rect.width / 2) / rect.width;
            mouseY = (e.clientY - rect.top - rect.height / 2) / rect.height;
        });

        nexus.addEventListener('mouseenter', () => {
            // Text gold shine
            gsap.to(aiPart, {
                backgroundPosition: "200% center",
                duration: 1.5,
                ease: "power2.inOut"
            });

            // Advanced parallax layering
            // Base tier: Moves back (furthest layer)
            gsap.to(baseTier, {
                x: () => mouseX * -5,
                y: () => mouseY * -5 + 2,
                scale: 0.98,
                duration: 0.6,
                ease: "power2.out"
            });

            // Lower ring: Middle depth
            gsap.to(lowerRing, {
                x: () => mouseX * -3,
                y: () => mouseY * -3,
                scale: 0.99,
                duration: 0.6,
                ease: "power2.out"
            });

            // Crown body: Comes forward
            gsap.to(crownBody, {
                x: () => mouseX * 2,
                y: () => mouseY * 2 - 2,
                scale: 1.02,
                duration: 0.6,
                ease: "power2.out"
            });

            // Ornaments: Front layer (most parallax)
            gsap.to([fleurOrnaments, peakJewels], {
                x: () => mouseX * 4,
                y: () => mouseY * 4 - 3,
                scale: 1.05,
                duration: 0.5,
                ease: "back.out(1.3)"
            });

            // Enhanced glow
            gsap.to('.crown-svg', {
                filter: "drop-shadow(0 12px 30px rgba(218, 165, 32, 0.6)) drop-shadow(0 6px 18px rgba(184, 134, 11, 0.4))",
                scale: 1.04,
                duration: 0.5
            });
        });

        nexus.addEventListener('mouseleave', () => {
            // Reset text
            gsap.to(aiPart, {
                backgroundPosition: "0% center",
                duration: 1.2,
                ease: "power2.inOut"
            });

            // Reset all layers smoothly
            gsap.to([baseTier, lowerRing, crownBody, fleurOrnaments, peakJewels], {
                x: 0,
                y: 0,
                scale: 1,
                duration: 0.8,
                ease: "power2.inOut"
            });

            // Reset glow
            gsap.to('.crown-svg', {
                filter: "drop-shadow(0 8px 20px rgba(218, 165, 32, 0.5)) drop-shadow(0 4px 12px rgba(184, 134, 11, 0.3))",
                scale: 1,
                duration: 0.8
            });
        });
    }

    // ==========================================
    // GENTLE BREATHING (Imperial Presence)
    // ==========================================

    if (!prefersReducedMotion) {
        // Crown breathes with regal presence
        gsap.to(crownContainer, {
            y: -3,
            duration: 4,
            repeat: -1,
            yoyo: true,
            ease: "sine.inOut"
        });

        // Text breathes independently
        gsap.to(logoText, {
            y: -1.5,
            duration: 4.5,
            repeat: -1,
            yoyo: true,
            ease: "sine.inOut"
        });

        // Chains sway gently
        gsap.to(chains, {
            opacity: 0.6,
            duration: 3,
            repeat: -1,
            yoyo: true,
            ease: "sine.inOut"
        });
    }

    // ==========================================
    // PERFORMANCE OPTIMIZATION
    // ==========================================

    const logoObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                masterTL.play();
            } else {
                masterTL.pause();
            }
        });
    }, { threshold: 0.1 });

    const logoNexus = document.getElementById('logo-nexus');
    if (logoNexus) {
        logoObserver.observe(logoNexus);
    }
});
