/**
 * LUXURY MODERN CROWN LOGO ANIMATION v7.0
 * Confident & Aspirational Design
 * Features: Elegant Entrance, Radiant Sparkle, Smooth 3D Depth
 */

document.addEventListener('DOMContentLoaded', () => {
    // Check for reduced motion preference
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    const logoTL = gsap.timeline({
        defaults: { ease: "power2.out" },
        paused: false
    });

    const crownContainer = document.querySelector('.crown-container');
    const crownBase = document.querySelector('.crown-base');
    const crownBaseHighlight = document.querySelector('.crown-base-highlight');
    const crownBaseShadow = document.querySelector('.crown-base-shadow');
    const crownPeaks = document.querySelectorAll('.crown-peak');
    const peakSheens = document.querySelectorAll('.peak-sheen');
    const baseStuds = document.querySelectorAll('.base-stud');
    const diamonds = document.querySelectorAll('.diamond');
    const logoText = document.querySelector('.logo-text');
    const aiPart = document.querySelector('.ai-part');

    if (!crownBase || crownPeaks.length === 0 || !logoText) return;

    // ==========================================
    // ELEGANT ENTRANCE ANIMATION
    // ==========================================

    // Prepare crown for elegant rise from below
    gsap.set(crownContainer, {
        y: 30,
        opacity: 0,
        scale: 0.9
    });

    // Prepare base band
    gsap.set(crownBase, {
        opacity: 0,
        scaleX: 0.8,
        transformOrigin: "center center"
    });
    gsap.set([crownBaseHighlight, crownBaseShadow], {
        opacity: 0
    });
    gsap.set(baseStuds, {
        opacity: 0,
        scale: 0
    });

    // Prepare peaks
    crownPeaks.forEach((peak) => {
        gsap.set(peak, {
            opacity: 0,
            scaleY: 0,
            transformOrigin: "center bottom"
        });
    });
    gsap.set(peakSheens, {
        opacity: 0
    });

    // 1. CROWN RISES ELEGANTLY (From below, confident entrance)
    logoTL.to(crownContainer, {
        y: 0,
        opacity: 1,
        scale: 1,
        duration: 1.0,
        ease: "power3.out"
    })
        // 2. BASE BAND EXPANDS (Radiates outward)
        .to(crownBase, {
            opacity: 1,
            scaleX: 1,
            duration: 0.8,
            ease: "back.out(1.2)"
        }, "-=0.5")
        .to([crownBaseHighlight, crownBaseShadow], {
            opacity: [0.8, 0.6],
            duration: 0.5
        }, "-=0.4")
        .to(baseStuds, {
            opacity: 0.7,
            scale: 1,
            duration: 0.5,
            stagger: {
                amount: 0.3,
                from: "center"
            },
            ease: "back.out(1.5)"
        }, "-=0.5")
        // 3. PEAKS ASCEND (Graceful upward growth)
        .to(crownPeaks, {
            opacity: 1,
            scaleY: 1,
            duration: 0.9,
            stagger: {
                amount: 0.5,
                from: "center"
            },
            ease: "power3.out"
        }, "-=0.4")
        .to(peakSheens, {
            opacity: [0.5, 0.5, 0.6, 0.5, 0.5],
            duration: 0.6,
            stagger: {
                amount: 0.4,
                from: "center"
            }
        }, "-=0.7")
        // 4. DIAMONDS APPEAR (Brilliant, radiant reveal)
        .to(diamonds, {
            opacity: 1,
            scale: 1,
            duration: 0.7,
            stagger: {
                amount: 0.5,
                from: "center"
            },
            ease: "elastic.out(1, 0.5)"
        }, "-=0.5")
        // 5. TEXT REVEAL (Confident, uplifting)
        .to(logoText, {
            opacity: 1,
            y: 0,
            duration: 0.9,
            ease: "power2.out"
        }, "-=0.5");

    // ==========================================
    // RADIANT DIAMOND SPARKLE (Gentle & Elegant)
    // ==========================================

    function createRadiantSparkle() {
        diamonds.forEach((diamond, index) => {
            const randomDelay = Math.random() * 3;

            // Gentle glow pulse only - no floating or rotation
            gsap.to(diamond, {
                filter: "drop-shadow(0 0 6px rgba(255, 255, 255, 1)) drop-shadow(0 0 12px rgba(240, 248, 255, 0.8)) drop-shadow(0 0 18px rgba(255, 215, 0, 0.3))",
                duration: 0.8,
                repeat: -1,
                yoyo: true,
                repeatDelay: 1.5 + Math.random() * 2,
                delay: randomDelay,
                ease: "sine.inOut"
            });
        });
    }

    // Start diamond sparkle after entrance
    logoTL.call(createRadiantSparkle, null, "+=0.3");

    // ==========================================
    // SMOOTH 3D DEPTH EFFECT (Hover)
    // ==========================================

    const nexus = document.getElementById('logo-nexus');
    if (nexus) {
        nexus.addEventListener('mouseenter', () => {
            // Text gold shine sweep
            gsap.to(aiPart, {
                backgroundPosition: "200% center",
                duration: 1.2,
                ease: "power2.inOut"
            });

            // Elegant 3D separation: Base back, peaks forward
            gsap.to('.crown-base-layer', {
                y: 1.5,
                scale: 0.99,
                duration: 0.6,
                ease: "power2.out"
            });

            gsap.to(crownPeaks, {
                y: -2,
                scale: 1.02,
                duration: 0.6,
                ease: "power2.out"
            });

            gsap.to(diamonds, {
                y: -3,
                scale: 1.15,
                filter: "drop-shadow(0 0 10px rgba(255, 255, 255, 1)) drop-shadow(0 0 20px rgba(240, 248, 255, 1)) drop-shadow(0 0 30px rgba(255, 215, 0, 0.5))",
                duration: 0.5,
                ease: "back.out(1.3)"
            });

            // Enhanced radiant glow
            gsap.to('.crown-svg', {
                filter: "drop-shadow(0 8px 20px rgba(255, 215, 0, 0.45)) drop-shadow(0 4px 12px rgba(253, 185, 49, 0.3))",
                scale: 1.03,
                duration: 0.5
            });
        });

        nexus.addEventListener('mouseleave', () => {
            // Reset text shine
            gsap.to(aiPart, {
                backgroundPosition: "0% center",
                duration: 1,
                ease: "power2.inOut"
            });

            // Reset 3D depth
            gsap.to('.crown-base-layer', {
                y: 0,
                scale: 1,
                duration: 0.7,
                ease: "power2.inOut"
            });

            gsap.to(crownPeaks, {
                y: 0,
                scale: 1,
                duration: 0.7,
                ease: "power2.inOut"
            });

            gsap.to(diamonds, {
                y: 0,
                scale: 1,
                filter: "drop-shadow(0 0 4px rgba(255, 255, 255, 1)) drop-shadow(0 0 8px rgba(240, 248, 255, 0.6))",
                duration: 0.6,
                ease: "power2.inOut"
            });

            // Reset glow
            gsap.to('.crown-svg', {
                filter: "drop-shadow(0 6px 15px rgba(255, 215, 0, 0.35)) drop-shadow(0 2px 8px rgba(253, 185, 49, 0.2))",
                scale: 1,
                duration: 0.7
            });
        });
    }

    // ==========================================
    // GENTLE FLOATING MOTION (Living Elegance)
    // ==========================================

    if (!prefersReducedMotion) {
        // Crown floats with graceful, uplifting movement
        gsap.to(".crown-container", {
            y: -2,
            duration: 3,
            repeat: -1,
            yoyo: true,
            ease: "sine.inOut"
        });

        // Text floats independently
        gsap.to(".logo-text", {
            y: -1,
            duration: 3.5,
            repeat: -1,
            yoyo: true,
            ease: "sine.inOut"
        });

        // Metallic sheen shimmer
        gsap.to(peakSheens, {
            opacity: 0.7,
            duration: 2.5,
            repeat: -1,
            yoyo: true,
            ease: "sine.inOut",
            stagger: {
                amount: 0.8,
                from: "edges"
            }
        });
    }

    // ==========================================
    // PERFORMANCE OPTIMIZATION
    // ==========================================

    const logoObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                logoTL.play();
            } else {
                logoTL.pause();
            }
        });
    }, { threshold: 0.1 });

    const logoNexus = document.getElementById('logo-nexus');
    if (logoNexus) {
        logoObserver.observe(logoNexus);
    }
});
