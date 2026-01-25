// assets/js/navigation-timing.js
class HumanTimingController {
    constructor() {
        // Research: Humans perceive delays over 100ms as "waiting"
        // But perceive 50-100ms delays as "instant" (Jakob's Law)
        this.perceptionThresholds = {
            instant: 100,     // Feels immediate
            responsive: 300,  // Feels natural
            waiting: 500,     // Feels slow
            frustrating: 1000 // Feels broken
        };

        // Adaptive timing based on user behavior
        this.userPatienceProfile = this.calculatePatienceProfile();
    }

    calculatePatienceProfile() {
        // NOT based on averages, but on THIS user's behavior
        const scrollBehavior = this.analyzeScrollRhythm();
        const clickPattern = this.analyzeInteractionCadence();

        return {
            preferredResponseTime: Math.min(
                300, // Default
                scrollBehavior.averagePause * 0.8 // Adapt to user's natural rhythm
            ),
            acceptableLoadTime: 1000 + (clickPattern.urgency * 500),
            animationDuration: 200 + (scrollBehavior.smoothness * 100)
        };
    }

    analyzeScrollRhythm() {
        // Simplified analysis for prototype
        return { averagePause: 300, smoothness: 0.5 };
    }

    analyzeInteractionCadence() {
        // Simplified analysis for prototype
        return { urgency: 0.5 };
    }

    createResponsiveNavigation() {
        // Pattern appears with human-perceived "emergence" not "pop-in"
        const patternReveal = `
      @keyframes human-reveal {
        0% { 
          opacity: 0;
          transform: translateY(-10px) scale(0.98);
          filter: blur(2px);
        }
        20% { 
          opacity: 0.3;
          transform: translateY(-5px) scale(0.99);
          filter: blur(1px);
        }
        100% { 
          opacity: 1;
          transform: translateY(0) scale(1);
          filter: blur(0);
        }
      }
    `;

        // Apply with variable timing based on user profile
        document.documentElement.style.setProperty(
            '--pattern-reveal-duration',
            `${this.userPatienceProfile.animationDuration}ms`
        );
    }
}
