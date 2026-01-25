/**
 * API Key Configuration
 * 
 * IMPORTANT: For security, never commit your actual API key to version control.
 * 
 * To use this file:
 * 1. Replace 'YOUR_API_KEY_HERE' with your actual API key
 * 2. Make sure this file is in .gitignore if using git
 * 
 * Alternative: Use environment variables or a secure backend service
 */

// API Key Configuration
const API_KEY_CONFIG = {
  // Vast.ai API Key (for current setup)
  vastAi: 'YOUR_VAST_AI_API_KEY_HERE',
  
  // Anthropic/Claude API Key (if you want to add Claude integration)
  anthropic: 'YOUR_ANTHROPIC_API_KEY_HERE',
  
  // Load from localStorage if available (for user-entered keys)
  loadFromStorage: true
};

// Initialize API clients with keys
function initializeApiKeys() {
  // Load from localStorage if enabled and available
  if (API_KEY_CONFIG.loadFromStorage) {
    const storedVastKey = localStorage.getItem('vast_ai_api_key');
    const storedAnthropicKey = localStorage.getItem('anthropic_api_key');
    
    if (storedVastKey && storedVastKey !== 'YOUR_VAST_AI_API_KEY_HERE') {
      API_KEY_CONFIG.vastAi = storedVastKey;
    }
    
    if (storedAnthropicKey && storedAnthropicKey !== 'YOUR_ANTHROPIC_API_KEY_HERE') {
      API_KEY_CONFIG.anthropic = storedAnthropicKey;
    }
  }
  
  // Initialize Vast.ai API client
  if (window.aiKingsAPI && API_KEY_CONFIG.vastAi && API_KEY_CONFIG.vastAi !== 'YOUR_VAST_AI_API_KEY_HERE') {
    window.aiKingsAPI.initialize(API_KEY_CONFIG.vastAi);
    console.log('✅ Vast.ai API initialized');
  } else {
    console.warn('⚠️ Vast.ai API key not set. Using mock mode.');
  }
  
  // Initialize Anthropic API client (if you add Claude integration)
  if (window.anthropicAPI && API_KEY_CONFIG.anthropic && API_KEY_CONFIG.anthropic !== 'YOUR_ANTHROPIC_API_KEY_HERE') {
    // Initialize Anthropic client here when you add it
    console.log('✅ Anthropic API initialized');
  }
}

// Function to set API key from user input (for UI)
function setApiKeyFromInput(apiKey, type = 'vastAi') {
  if (!apiKey || apiKey.trim() === '') {
    console.error('API key cannot be empty');
    return false;
  }
  
  API_KEY_CONFIG[type] = apiKey.trim();
  
  // Save to localStorage
  if (API_KEY_CONFIG.loadFromStorage) {
    const storageKey = type === 'vastAi' ? 'vast_ai_api_key' : 'anthropic_api_key';
    localStorage.setItem(storageKey, apiKey.trim());
  }
  
  // Re-initialize
  initializeApiKeys();
  
  return true;
}

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeApiKeys);
} else {
  initializeApiKeys();
}

// Export for use in other scripts
window.API_KEY_CONFIG = API_KEY_CONFIG;
window.setApiKeyFromInput = setApiKeyFromInput;
