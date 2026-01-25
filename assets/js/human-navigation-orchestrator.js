// assets/js/human-navigation-orchestrator.js
class HumanNavigationOrchestrator {
    constructor() {
        this.navigation = document.querySelector('.main-navigation');
        this.pattern = this.navigation ? (this.navigation.querySelector('.navigation-pattern') || this.navigation) : null;

        if (!this.navigation) {
            console.warn('HumanNavigationOrchestrator: .main-navigation not found');
            return;
        }

        // State tracking
        this.state = {
            emotion: 'calm',
            cognitiveLoad: 0.3,
            energyLevel: 0.7,
            experienceLevel: 1,
            context: {}
        };

        // Initialize component controllers
        this.timing = new HumanTimingController();
        this.contextAware = new ContextAwareNavigation();
        this.variation = new ConsistentVariation();

        // Initialize human detection
        this.initEmotionDetection();
        this.initCognitiveLoadTracking();
        this.initEnergyMonitoring();
        this.initExperienceTracking();

        // Apply initial state
        this.applyHumanState();

        // Update on interaction
        this.bindInteractionEvents();
    }

    initEmotionDetection() {
        // Simplified emotion detection through interaction patterns
        const interactionHistory = [];

        document.addEventListener('mousemove', (e) => {
            const speed = this.calculateMouseSpeed(e);
            interactionHistory.push({
                timestamp: Date.now(),
                speed,
                position: { x: e.clientX, y: e.clientY }
            });

            // Keep last 50 interactions
            if (interactionHistory.length > 50) interactionHistory.shift();

            // Analyze for emotional patterns
            this.analyzeEmotionalPatterns(interactionHistory);
        });
    }

    analyzeEmotionalPatterns(history) {
        if (history.length < 10) return;

        const recent = history.slice(-10);
        const avgSpeed = recent.reduce((sum, h) => sum + h.speed, 0) / recent.length;
        const speedVariance = this.calculateVariance(recent.map(h => h.speed));

        // Emotional inference (simplified)
        const oldEmotion = this.state.emotion;
        if (avgSpeed > 15 && speedVariance > 5) {
            this.state.emotion = 'anxious';
        } else if (avgSpeed > 10 && speedVariance < 2) {
            this.state.emotion = 'confident';
        } else if (avgSpeed < 5 && speedVariance < 1) {
            this.state.emotion = 'calm';
        } else {
            this.state.emotion = 'curious';
        }

        if (oldEmotion !== this.state.emotion) {
            this.applyHumanState();
        }
    }

    initCognitiveLoadTracking() {
        // Track decision complexity
        let decisionCount = 0;
        let lastDecisionTime = Date.now();

        document.addEventListener('click', (e) => {
            const currentTime = Date.now();
            const timeSinceLast = currentTime - lastDecisionTime;

            // More frequent decisions = higher cognitive load
            if (timeSinceLast < 1000) decisionCount++;
            else decisionCount = Math.max(0, decisionCount - 1);

            this.state.cognitiveLoad = Math.min(1, decisionCount / 10);
            lastDecisionTime = currentTime;
            this.applyHumanState();
        });
    }

    initEnergyMonitoring() {
        // Monitor interaction fatigue
        let interactionCount = 0;
        let sessionStart = Date.now();

        const resetCounter = () => {
            const sessionLength = Date.now() - sessionStart;
            // More interactions in shorter time = lower energy
            this.state.energyLevel = Math.max(0.1, 1 - (interactionCount / 100));

            // Reset for next interval
            interactionCount = 0;
            sessionStart = Date.now();
            this.applyHumanState();
        };

        // Check every 2 minutes
        setInterval(resetCounter, 120000);

        // Count interactions
        ['click', 'scroll', 'mousemove', 'keydown'].forEach(event => {
            document.addEventListener(event, () => {
                interactionCount++;
            }, { passive: true });
        });
    }

    initExperienceTracking() {
        // In a real app, this would come from localStorage/DB
        this.state.experienceLevel = parseInt(localStorage.getItem('user_experience_level') || '1');

        // Increment experience slowly
        document.addEventListener('click', () => {
            const clicks = parseInt(localStorage.getItem('total_clicks') || '0') + 1;
            localStorage.setItem('total_clicks', clicks);
            if (clicks > 100 && this.state.experienceLevel < 2) {
                this.state.experienceLevel = 2;
                localStorage.setItem('user_experience_level', '2');
                this.applyHumanState();
            } else if (clicks > 500 && this.state.experienceLevel < 3) {
                this.state.experienceLevel = 3;
                localStorage.setItem('user_experience_level', '3');
                this.applyHumanState();
            }
        });
    }

    applyHumanState() {
        if (!this.pattern) return;

        // Apply all human state to CSS custom properties
        this.pattern.style.setProperty('--user-emotion', this.state.emotion);
        this.pattern.style.setProperty('--cognitive-load', this.state.cognitiveLoad);
        this.pattern.style.setProperty('--user-energy', this.state.energyLevel);
        this.pattern.style.setProperty('--user-experience', this.state.experienceLevel);

        // Set data attribute for CSS selectors
        this.pattern.dataset.emotion = this.state.emotion;
        this.pattern.dataset.cognitiveLoad =
            this.state.cognitiveLoad > 0.6 ? 'high' :
                this.state.cognitiveLoad > 0.3 ? 'medium' : 'low';

        // Update mouse position for curious state
        document.addEventListener('mousemove', (e) => {
            const x = (e.clientX / window.innerWidth) * 100;
            const y = (e.clientY / window.innerHeight) * 100;
            this.pattern.style.setProperty('--mouse-x', `${x}%`);
            this.pattern.style.setProperty('--mouse-y', `${y}%`);
        }, { passive: true });
    }

    bindInteractionEvents() {
        // Update state on user interaction
        ['scroll', 'mousemove', 'click'].forEach(event => {
            document.addEventListener(event, () => {
                this.applyHumanState();
            }, { passive: true });
        });
    }

    // Utility methods
    calculateMouseSpeed(event) {
        if (!this.lastMouseEvent) {
            this.lastMouseEvent = event;
            return 0;
        }

        const deltaX = event.clientX - this.lastMouseEvent.clientX;
        const deltaY = event.clientY - this.lastMouseEvent.clientY;
        const distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);
        const timeDelta = event.timeStamp - this.lastMouseEvent.timeStamp;

        this.lastMouseEvent = event;

        return timeDelta > 0 ? distance / timeDelta : 0;
    }

    calculateVariance(numbers) {
        const avg = numbers.reduce((a, b) => a + b) / numbers.length;
        const squareDiffs = numbers.map(n => Math.pow(n - avg, 2));
        return Math.sqrt(squareDiffs.reduce((a, b) => a + b) / numbers.length);
    }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    const orchestrator = new HumanNavigationOrchestrator();

    // Make available for debugging
    window.humanNavigation = orchestrator;
});
