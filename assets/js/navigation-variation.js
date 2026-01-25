// assets/js/navigation-variation.js
class ConsistentVariation {
    constructor() {
        this.basePattern = this.createBasePattern();
        this.variationRules = this.defineVariationRules();
        this.currentVariation = 0;

        // Subtle variation every 24 hours
        this.scheduleVariations();
    }

    createBasePattern() {
        // Consistent hexagonal foundation
        return `
      <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <pattern id="hexBase" width="100" height="100" patternUnits="userSpaceOnUse">
            <path d="M50,0 L100,25 L100,75 L50,100 L0,75 L0,25 Z" 
                  fill="var(--gold-cognitive)" 
                  fill-opacity="0.08"/>
          </pattern>
        </defs>
      </svg>
    `;
    }

    defineVariationRules() {
        // Rules for variation while maintaining recognition
        return [
            { /* Variation 0: Morning */
                rotate: 0,
                scale: 1,
                opacity: 0.12,
                accentColor: 'var(--gold-emotional)',
                animation: 'gentle-drift 20s linear infinite'
            },
            { /* Variation 1: Afternoon */
                rotate: 30,
                scale: 1.1,
                opacity: 0.15,
                accentColor: 'var(--gold-cognitive)',
                animation: 'subtle-pulse 15s ease-in-out infinite'
            },
            { /* Variation 2: Evening */
                rotate: -15,
                scale: 0.95,
                opacity: 0.1,
                accentColor: 'var(--gold-forgiving)',
                animation: 'slow-breath 25s ease-in-out infinite'
            }
        ];
    }

    scheduleVariations() {
        // Periodically apply variations
        setInterval(() => {
            this.applyVariation(this.currentVariation + 1);
        }, 86400000); // 24 hours
    }

    applyVariation(variationIndex) {
        const variation = this.variationRules[variationIndex % this.variationRules.length];
        const patternElement = document.querySelector('.navigation-pattern') || document.querySelector('.main-navigation');

        if (patternElement && patternElement.animate) {
            // Apply with smooth transition
            patternElement.animate([
                { transform: `rotate(${variation.rotate}deg) scale(${variation.scale})` },
                { opacity: variation.opacity }
            ], {
                duration: 1000,
                easing: 'cubic-bezier(0.2, 0.9, 0.3, 1.1)',
                fill: 'forwards'
            });
        }

        this.currentVariation = variationIndex;
    }
}
