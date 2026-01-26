# Plan: Studio End-to-End Validation (Phase 1 Finalization)

This plan outlines the final steps to bridge the gap between the backend generation engine and the Studio UI, ensuring a fully functional, professional-grade workflow that is ready for production testing.

## 1. UI Infrastructure Updates (`studio.html`)
The UI must be updated to support the new multi-modal capabilities of the backend.

### 1.1 Progress Bar & Video Container
Add a dedicated progress bar and a `<video>` element for video workflows.
- **File**: `studio.html`
- **Location**: Inside `.canvas-wrapper`
- **Component**: 
  ```html
  <div class="progress-container" id="generation-progress-container" style="display: none;">
      <div class="progress-bar-rail">
          <div class="progress-bar-fill" id="generation-progress-fill"></div>
      </div>
      <span class="progress-label" id="generation-progress-text">0%</span>
  </div>
  <div class="active-content" style="display: none;">
      <img id="stage-image" src="" alt="Generated Content">
      <video id="stage-video" controls loop autoplay muted style="display: none; max-width: 100%; border-radius: 8px;"></video>
      <div class="stage-overlay-actions">...</div>
  </div>
  ```

### 1.2 Workflow Selector
Add a toggle to switch between Image and Video generation.
- **Location**: Inside `.dock-header`
- **Component**:
  ```html
  <div class="workflow-selector">
      <button class="workflow-btn active" data-type="image"><i class="ph ph-image"></i> Image</button>
      <button class="workflow-btn" data-type="video"><i class="ph ph-video-camera"></i> Video</button>
  </div>
  ```

## 2. Frontend Logic Refinement (`assets/js/ai-kings-studio-pro.js`)
Replace the hardcoded behavior with dynamic workflow handling.

### 2.1 Dynamic Workflow Detection
```javascript
getWorkflowType() {
    const activeBtn = document.querySelector('.workflow-btn.active');
    return activeBtn ? activeBtn.getAttribute('data-type') : 'image';
}
```

### 2.2 Rich Status Updates
Update `pollJobStatus` to drive the new progress bar UI.
```javascript
// Inside pollJobStatus
const progressContainer = document.getElementById('generation-progress-container');
const progressFill = document.getElementById('generation-progress-fill');
const progressText = document.getElementById('generation-progress-text');

if (progressContainer) progressContainer.style.display = 'flex';
if (progressFill) progressFill.style.width = `${status.progress}%`;
if (progressText) progressText.textContent = `${status.progress}%`;
```

### 2.3 Integrated Media Rendering
Update `displayResult` to handle both `img` and `video` formats.
```javascript
async displayResult(result) {
    const img = document.getElementById('stage-image');
    const video = document.getElementById('stage-video');
    
    if (result.workflowType === 'video') {
        img.style.display = 'none';
        video.src = result.imageUrl;
        video.style.display = 'block';
    } else {
        video.style.display = 'none';
        img.src = result.imageUrl;
        img.style.display = 'block';
    }
    // ... animation logic
}
```

## 3. Automated E2E Browser Testing (`tests/studio-e2e.test.js`)
Implement a professional test suite using Puppeteer to validate the entire click-to-render flow.

### 3.1 Test Coverage
- **Scenario**: User generates an image.
  - Assert: Terminal input accepts text.
  - Assert: Generate button triggers "generating" state.
  - Assert: Progress bar appears and increments.
  - Assert: Workflow result (image) appears on stage.
- **Scenario**: User switches to Video and generates.
  - Assert: Workflow toggle updates state.
  - Assert: Final result renders in `<video>` tag.

## 4. Execution Roadmap
1. **Apply UI Changes**: Modify `studio.html` and `ai-kings-studio.css`.
2. **Apply JS Changes**: Update `ai-kings-studio-pro.js`.
3. **Environment Setup**: Ensure `vastai-proxy.js` is running with the `ComfyStub` enabled for local validation.
4. **Run E2E Suite**: Execute `node tests/studio-e2e.test.js` and verify stability.
