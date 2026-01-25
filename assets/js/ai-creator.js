/**
 * AI KINGS Creator
 * AI content generation interface with Vast.ai integration
 */

class AIKingsCreator {
  constructor() {
    this.isGenerating = false;
    this.currentJob = null;
    this.generationHistory = [];
    this.apiConfig = null;

    this.init();
  }

  async init() {
    try {
      await this.loadApiConfig();
      this.setupEventListeners();
      this.loadGenerationHistory();
      this.setupFormValidation();
      console.log('AI KINGS Creator initialized');
    } catch (error) {
      console.error('Failed to initialize AI Creator:', error);
    }
  }

  async loadApiConfig() {
    try {
      const response = await fetch('assets/js/api-config.js');
      if (response.ok) {
        // Load API configuration
        this.apiConfig = {
          vastAiEndpoint: 'https://api.vast.ai/v1',
          apiKey: null, // Will be loaded from environment
          pollingInterval: 5000,
          maxRetries: 3
        };
      }
    } catch (error) {
      console.warn('API config not found, using mock mode:', error);
      this.apiConfig = { mockMode: true };
    }
  }

  setupEventListeners() {
    // Form submission
    const form = document.querySelector('.ai-prompt-form');
    if (form) {
      form.addEventListener('submit', (e) => this.handleFormSubmit(e));
    }

    // Prompt input validation
    const promptTextarea = document.querySelector('.prompt-textarea');
    if (promptTextarea) {
      promptTextarea.addEventListener('input', (e) => this.validatePrompt(e));
      promptTextarea.addEventListener('blur', (e) => this.validatePrompt(e));
    }

    // Control panel triggers - expand/collapse
    document.querySelectorAll('.control-panel-trigger').forEach(trigger => {
      trigger.addEventListener('click', (e) => this.togglePanel(e));
    });

    // Control option selection
    document.querySelectorAll('.control-option').forEach(option => {
      option.addEventListener('click', (e) => this.selectOption(e));
    });

    // Close panels when clicking outside
    document.addEventListener('click', (e) => {
      if (!e.target.closest('.control-panel')) {
        this.closeAllPanels();
      }
      if (e.target.closest('.example-card')) {
        this.loadExamplePrompt(e);
      }
    });

    // Preview button
    const previewBtn = document.querySelector('.preview-btn');
    if (previewBtn) {
      previewBtn.addEventListener('click', () => this.showPreview());
    }
  }

  togglePanel(e) {
    e.stopPropagation();
    const trigger = e.currentTarget;
    const panel = trigger.closest('.control-panel');
    const isExpanded = trigger.getAttribute('aria-expanded') === 'true';

    // Close all other panels
    document.querySelectorAll('.control-panel').forEach(p => {
      if (p !== panel) {
        p.classList.remove('active');
        const t = p.querySelector('.control-panel-trigger');
        if (t) {
          t.setAttribute('aria-expanded', 'false');
        }
      }
    });

    // Toggle current panel
    if (isExpanded) {
      panel.classList.remove('active');
      trigger.setAttribute('aria-expanded', 'false');
    } else {
      panel.classList.add('active');
      trigger.setAttribute('aria-expanded', 'true');
    }
  }

  selectOption(e) {
    e.stopPropagation();
    const option = e.currentTarget;
    const panel = option.closest('.control-panel');
    const controlName = option.getAttribute('data-control-name');
    const value = option.getAttribute('data-value');

    // Update selected state
    panel.querySelectorAll('.control-option').forEach(opt => {
      opt.removeAttribute('data-selected');
    });
    option.setAttribute('data-selected', 'true');

    // Update hidden input
    const hiddenInput = panel.querySelector(`input[name="${controlName}"]`);
    if (hiddenInput) {
      hiddenInput.value = value;
    }

    // Update displayed value
    const valueDisplay = panel.querySelector('.control-value');
    if (valueDisplay) {
      const title = option.querySelector('.option-title')?.textContent || value;
      const meta = option.querySelector('.option-meta')?.textContent;
      valueDisplay.textContent = meta ? `${title} (${meta})` : title;
    }

    // Close panel after selection
    panel.classList.remove('active');
    const trigger = panel.querySelector('.control-panel-trigger');
    if (trigger) {
      trigger.setAttribute('aria-expanded', 'false');
    }

    // Update preview
    this.updatePreview();
  }

  closeAllPanels() {
    document.querySelectorAll('.control-panel').forEach(panel => {
      panel.classList.remove('active');
      const trigger = panel.querySelector('.control-panel-trigger');
      if (trigger) {
        trigger.setAttribute('aria-expanded', 'false');
      }
    });
  }

  setupFormValidation() {
    // Real-time validation for prompt input
    const promptTextarea = document.querySelector('.prompt-textarea');
    if (promptTextarea) {
      const validator = new PromptValidator(promptTextarea);
      validator.init();
    }
  }

  validatePrompt(e) {
    const textarea = e.target;
    const value = textarea.value.trim();
    const isValid = value.length >= 10 && value.length <= 500;

    textarea.classList.toggle('invalid', !isValid);
    textarea.classList.toggle('valid', isValid);

    // Update character count
    this.updateCharacterCount(value.length);

    // Update submit button state
    const submitBtn = document.querySelector('.generate-btn');
    if (submitBtn) {
      submitBtn.disabled = !isValid || this.isGenerating;
    }

    return isValid;
  }

  updateCharacterCount(count) {
    const counter = document.querySelector('.character-count');
    if (counter) {
      counter.textContent = `${count}/500`;
      counter.classList.toggle('warning', count > 450);
      counter.classList.toggle('error', count > 500);
    }
  }

  async handleFormSubmit(e) {
    e.preventDefault();

    if (this.isGenerating) return;

    const formData = this.getFormData();
    if (!this.validateFormData(formData)) return;

    try {
      await this.startGeneration(formData);
    } catch (error) {
      console.error('Generation failed:', error);
      this.showError('Failed to start generation. Please try again.');
    }
  }

  getFormData() {
    const form = document.querySelector('.ai-prompt-form');
    if (!form) return null;

    const formData = new FormData(form);
    
    // Get values from hidden inputs (from control panels)
    const contentType = formData.get('contentType') || 'video';
    const style = formData.get('style') || 'realistic';
    const theme = formData.get('theme') || 'general';
    const quality = formData.get('quality') || 'medium';
    
    // Map quality values to expected format
    const qualityMap = {
      'medium': 'HD',
      'high': '4K'
    };
    
    return {
      prompt: formData.get('prompt')?.trim(),
      contentType: contentType,
      style: style,
      theme: theme,
      quality: qualityMap[quality] || quality,
      duration: formData.get('duration') || 'medium'
    };
  }

  validateFormData(data) {
    if (!data.prompt || data.prompt.length < 10) {
      this.showError('Please enter a prompt with at least 10 characters.');
      return false;
    }

    if (data.prompt.length > 500) {
      this.showError('Prompt must be 500 characters or less.');
      return false;
    }

    return true;
  }

  async startGeneration(formData) {
    this.isGenerating = true;
    this.updateGenerationUI('starting');

    try {
      if (this.apiConfig.mockMode) {
        await this.mockGeneration(formData);
      } else {
        await this.realGeneration(formData);
      }
    } catch (error) {
      console.error('Generation error:', error);
      this.handleGenerationError(error);
    } finally {
      this.isGenerating = false;
    }
  }

  async realGeneration(formData) {
    // Submit job to Vast.ai API
    const jobResponse = await this.submitJobToVastAi(formData);
    this.currentJob = jobResponse.job;

    // Start polling for status
    await this.pollGenerationStatus();
  }

  async submitJobToVastAi(formData) {
    const payload = {
      prompt: formData.prompt,
      content_type: formData.contentType,
      style: formData.style,
      theme: formData.theme,
      quality: formData.quality,
      duration: formData.duration,
      timestamp: new Date().toISOString()
    };

    const response = await fetch(`${this.apiConfig.vastAiEndpoint}/generate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.apiConfig.apiKey}`
      },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      throw new Error(`API request failed: ${response.status}`);
    }

    return await response.json();
  }

  async pollGenerationStatus() {
    const maxPolls = 120; // 10 minutes max (120 * 5 seconds)
    let pollCount = 0;

    const poll = async () => {
      try {
        const status = await this.checkGenerationStatus(this.currentJob.id);

        this.updateGenerationProgress(status);

        if (status.status === 'completed') {
          await this.handleGenerationComplete(status);
          return;
        } else if (status.status === 'failed') {
          throw new Error('Generation failed: ' + status.error);
        } else if (pollCount >= maxPolls) {
          throw new Error('Generation timed out');
        }

        pollCount++;
        setTimeout(poll, this.apiConfig.pollingInterval);
      } catch (error) {
        throw error;
      }
    };

    await poll();
  }

  async checkGenerationStatus(jobId) {
    const response = await fetch(`${this.apiConfig.vastAiEndpoint}/status/${jobId}`, {
      headers: {
        'Authorization': `Bearer ${this.apiConfig.apiKey}`
      }
    });

    if (!response.ok) {
      throw new Error(`Status check failed: ${response.status}`);
    }

    return await response.json();
  }

  async mockGeneration(formData) {
    // Simulate AI generation process
    this.updateGenerationUI('starting');

    const stages = [
      { stage: 'analyzing', message: 'Analyzing prompt...', progress: 10, delay: 1000 },
      { stage: 'preparing', message: 'Preparing AI models...', progress: 25, delay: 2000 },
      { stage: 'generating', message: 'Generating content...', progress: 50, delay: 5000 },
      { stage: 'processing', message: 'Processing results...', progress: 75, delay: 3000 },
      { stage: 'finalizing', message: 'Finalizing output...', progress: 90, delay: 2000 }
    ];

    for (const stage of stages) {
      await new Promise(resolve => setTimeout(resolve, stage.delay));
      this.updateGenerationProgress({
        status: 'running',
        stage: stage.stage,
        message: stage.message,
        progress: stage.progress
      });
    }

    // Simulate completion
    const mockResult = {
      id: 'mock-' + Date.now(),
      url: 'https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4',
      thumbnail: 'https://via.placeholder.com/400x225/2a2a2a/ffffff?text=AI+Generated',
      prompt: formData.prompt,
      contentType: formData.contentType,
      createdAt: new Date().toISOString()
    };

    await this.handleGenerationComplete({ result: mockResult });
  }

  updateGenerationUI(status) {
    const statusContainer = document.querySelector('.status-container');
    const generateBtn = document.querySelector('.generate-btn');

    if (!statusContainer || !generateBtn) return;

    switch (status) {
      case 'starting':
        statusContainer.style.display = 'block';
        generateBtn.classList.add('loading');
        generateBtn.disabled = true;
        generateBtn.textContent = 'Starting...';
        break;
      case 'idle':
        statusContainer.style.display = 'none';
        generateBtn.classList.remove('loading');
        generateBtn.disabled = false;
        generateBtn.textContent = 'Generate';
        break;
    }
  }

  updateGenerationProgress(status) {
    const progressFill = document.querySelector('.progress-fill');
    const progressText = document.querySelector('.progress-text');
    const statusTitle = document.querySelector('.status-title');
    const statusMessage = document.querySelector('.status-message');

    if (progressFill) progressFill.style.width = `${status.progress || 0}%`;
    if (progressText) progressText.textContent = `${status.progress || 0}%`;
    if (statusTitle) statusTitle.textContent = this.getStatusTitle(status.stage || status.status);
    if (statusMessage) statusMessage.textContent = status.message || 'Processing...';

    // Update status icon
    this.updateStatusIcon(status.status, status.stage);
  }

  getStatusTitle(stage) {
    const titles = {
      'analyzing': 'Analyzing',
      'preparing': 'Preparing',
      'generating': 'Generating',
      'processing': 'Processing',
      'finalizing': 'Finalizing',
      'completed': 'Complete!',
      'failed': 'Failed'
    };
    return titles[stage] || 'Processing';
  }

  updateStatusIcon(status, stage) {
    const icon = document.querySelector('.status-icon');
    if (!icon) return;

    icon.className = 'status-icon';

    if (status === 'completed') {
      icon.classList.add('success');
    } else if (status === 'failed') {
      icon.classList.add('error');
    } else {
      icon.classList.add('generating');
    }
  }

  async handleGenerationComplete(status) {
    this.updateGenerationUI('idle');

    const result = status.result;
    this.displayResult(result);
    this.saveToHistory(result);

    // Show success message
    this.showSuccess('Generation completed successfully!');

    // Add to gallery if it exists
    if (window.aiKingsApp) {
      this.addToGallery(result);
    }
  }

  handleGenerationError(error) {
    this.updateGenerationUI('idle');
    this.updateGenerationProgress({
      status: 'failed',
      message: error.message || 'Generation failed. Please try again.'
    });
    this.showError(error.message || 'Generation failed. Please try again.');
  }

  displayResult(result) {
    const previewContainer = document.querySelector('.result-preview');
    if (!previewContainer) return;

    const previewContent = document.querySelector('.preview-content');
    const previewTitle = document.querySelector('.preview-title');

    if (previewTitle) {
      previewTitle.textContent = result.contentType === 'video' ? 'Generated Video' : 'Generated Image';
    }

    if (previewContent && result.url) {
      if (result.contentType === 'video') {
        previewContent.innerHTML = `
          <video controls preload="metadata" style="width: 100%; height: 100%; object-fit: contain;">
            <source src="${result.url}" type="video/mp4">
            Your browser does not support the video tag.
          </video>
        `;
      } else {
        previewContent.innerHTML = `<img src="${result.url}" alt="Generated content" style="width: 100%; height: 100%; object-fit: contain;">`;
      }
    }

    previewContainer.style.display = 'block';
  }

  saveToHistory(result) {
    this.generationHistory.unshift({
      ...result,
      timestamp: new Date().toISOString()
    });

    // Keep only last 10 items
    if (this.generationHistory.length > 10) {
      this.generationHistory = this.generationHistory.slice(0, 10);
    }

    localStorage.setItem('ai-kings-generation-history', JSON.stringify(this.generationHistory));
  }

  loadGenerationHistory() {
    try {
      const history = localStorage.getItem('ai-kings-generation-history');
      if (history) {
        this.generationHistory = JSON.parse(history);
      }
    } catch (error) {
      console.warn('Failed to load generation history:', error);
    }
  }

  addToGallery(result) {
    // Add the generated content to the video gallery
    const newVideo = {
      id: result.id,
      title: this.generateTitleFromPrompt(result.prompt),
      description: `AI-generated ${result.contentType} based on: "${result.prompt}"`,
      thumbnail: result.thumbnail || result.url,
      videoUrl: result.url,
      category: 'ai-generated',
      tags: ['AI', 'generated', result.contentType],
      duration: result.contentType === 'video' ? '0:30' : 'N/A',
      views: 0,
      rating: 0,
      createdAt: result.createdAt,
      isTrending: false,
      isFeatured: false,
      isAIGenerated: true,
      generationPrompt: result.prompt
    };

    // Add to video data
    if (window.aiKingsApp && window.aiKingsApp.videoData) {
      window.aiKingsApp.videoData.videos.unshift(newVideo);
      window.aiKingsApp.renderGallery();
    }
  }

  generateTitleFromPrompt(prompt) {
    // Generate a title from the prompt
    const words = prompt.split(' ').slice(0, 6);
    return words.join(' ') + (words.length >= 6 ? '...' : '');
  }

  showPreview() {
    const formData = this.getFormData();
    if (!formData || !formData.prompt) {
      this.showError('Please enter a prompt first.');
      return;
    }

    // Show preview of what will be generated
    const preview = {
      prompt: formData.prompt,
      contentType: formData.contentType,
      style: formData.style,
      theme: formData.theme
    };

    this.displayPreview(preview);
  }

  displayPreview(preview) {
    const previewContainer = document.querySelector('.result-preview');
    const previewContent = document.querySelector('.preview-content');
    const previewTitle = document.querySelector('.preview-title');

    if (previewTitle) {
      previewTitle.textContent = 'Generation Preview';
    }

    if (previewContent) {
      previewContent.innerHTML = `
        <div style="padding: 2rem; text-align: center; color: var(--ai-kings-text-secondary);">
          <div style="font-size: 3rem; margin-bottom: 1rem;">🎬</div>
          <h4 style="margin-bottom: 1rem; color: var(--ai-kings-gold);">
            ${preview.contentType === 'video' ? 'Video' : 'Image'} Generation Preview
          </h4>
          <p style="margin-bottom: 1rem;"><strong>Prompt:</strong> ${preview.prompt}</p>
          <p style="margin-bottom: 1rem;"><strong>Style:</strong> ${preview.style}</p>
          <p style="margin-bottom: 1rem;"><strong>Theme:</strong> ${preview.theme}</p>
          <p style="color: var(--ai-kings-text-muted); font-size: 0.9rem;">
            This is a preview. Click "Generate" to start the actual AI generation process.
          </p>
        </div>
      `;
    }

    if (previewContainer) {
      previewContainer.style.display = 'block';
    }
  }

  loadExamplePrompt(e) {
    const exampleCard = e.target.closest('.example-card');
    if (!exampleCard) return;

    const promptText = exampleCard.querySelector('.example-prompt')?.textContent;
    if (promptText) {
      const textarea = document.querySelector('.prompt-textarea');
      if (textarea) {
        textarea.value = promptText.trim();
        textarea.dispatchEvent(new Event('input'));
        textarea.focus();
      }
    }
  }

  updatePreview() {
    // Update live preview as user changes options
    const previewBtn = document.querySelector('.preview-btn');
    if (previewBtn) {
      const formData = this.getFormData();
      previewBtn.disabled = !formData || !formData.prompt || formData.prompt.length < 10;
    }
    
    // Trigger any preview updates if needed
    if (window.aiKingsCreator && typeof window.aiKingsCreator.updatePreviewDisplay === 'function') {
      window.aiKingsCreator.updatePreviewDisplay();
    }
  }

  showError(message) {
    this.showNotification(message, 'error');
  }

  showSuccess(message) {
    this.showNotification(message, 'success');
  }

  showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `ai-kings-notification ${type}`;
    notification.innerHTML = `
      <div class="notification-content">
        <span class="notification-icon">${type === 'error' ? '❌' : type === 'success' ? '✅' : 'ℹ️'}</span>
        <span class="notification-message">${message}</span>
      </div>
    `;

    notification.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      background: ${type === 'error' ? 'var(--ai-kings-red)' : type === 'success' ? 'var(--ai-kings-gold)' : 'var(--ai-kings-dark)'};
      color: ${type === 'success' ? 'var(--ai-kings-black)' : 'var(--ai-kings-text)'};
      padding: 1rem 1.5rem;
      border-radius: var(--ai-kings-radius);
      box-shadow: var(--ai-kings-shadow);
      z-index: 1000;
      max-width: 400px;
      animation: slideIn 0.3s ease;
    `;

    document.body.appendChild(notification);

    setTimeout(() => {
      notification.style.animation = 'slideOut 0.3s ease';
      setTimeout(() => notification.remove(), 300);
    }, 5000);
  }
}

/**
 * Prompt Validator Class
 */
class PromptValidator {
  constructor(textarea) {
    this.textarea = textarea;
    this.minLength = 10;
    this.maxLength = 500;
  }

  init() {
    this.createUI();
    this.bindEvents();
  }

  createUI() {
    // Add character counter
    const counter = document.createElement('div');
    counter.className = 'character-count';
    counter.textContent = '0/500';

    // Insert after textarea
    this.textarea.parentNode.insertBefore(counter, this.textarea.nextSibling);
  }

  bindEvents() {
    this.textarea.addEventListener('input', () => this.validate());
    this.textarea.addEventListener('blur', () => this.validate());
  }

  validate() {
    const value = this.textarea.value.trim();
    const isValid = value.length >= this.minLength && value.length <= this.maxLength;

    this.textarea.classList.toggle('invalid', !isValid && value.length > 0);
    this.textarea.classList.toggle('valid', isValid);

    this.updateCounter(value.length);

    return isValid;
  }

  updateCounter(count) {
    const counter = this.textarea.parentNode.querySelector('.character-count');
    if (counter) {
      counter.textContent = `${count}/${this.maxLength}`;
      counter.classList.toggle('warning', count > this.maxLength * 0.9);
      counter.classList.toggle('error', count > this.maxLength);
    }
  }
}

// CSS for notifications and validation
const additionalStyles = `
<style>
.ai-kings-notification {
  font-family: var(--ai-kings-font-primary);
}

.character-count {
  text-align: right;
  font-size: 0.8rem;
  color: var(--ai-kings-text-muted);
  margin-top: 0.5rem;
}

.character-count.warning {
  color: #ff9800;
}

.character-count.error {
  color: var(--ai-kings-red);
}

.prompt-textarea.invalid {
  border-color: var(--ai-kings-red) !important;
  box-shadow: 0 0 0 3px rgba(196, 30, 58, 0.1) !important;
}

.prompt-textarea.valid {
  border-color: var(--ai-kings-gold) !important;
  box-shadow: 0 0 0 3px rgba(212, 175, 55, 0.1) !important;
}

@keyframes slideIn {
  from { transform: translateX(100%); opacity: 0; }
  to { transform: translateX(0); opacity: 1; }
}

@keyframes slideOut {
  from { transform: translateX(0); opacity: 1; }
  to { transform: translateX(100%); opacity: 0; }
}
</style>
`;

// Inject styles
document.head.insertAdjacentHTML('beforeend', additionalStyles);

// Initialize the AI creator when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  window.aiKingsCreator = new AIKingsCreator();
});