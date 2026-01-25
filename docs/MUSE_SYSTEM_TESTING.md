# AI KINGS - Muse System Testing Guide

**Version:** 1.0  
**Date:** January 24, 2026  
**Purpose:** Comprehensive testing procedures for the enhanced muse system

---

## Quick Start Testing

### Prerequisites
1. Open `studio.html` in a modern browser (Chrome, Edge, Firefox)
2. ComfyUI running on `http://127.0.0.1:8188` (for full workflow testing)
3. Browser console open (F12) to monitor any errors

### Initial Smoke Test (5 minutes)

```bash
# Open studio.html in browser
# 1. Click "The Muse" button in sidebar
# 2. Click "New" button to create character
# 3. Enter name in Basic Info tab
# 4. Click through all 10 tabs
# 5. Click "Save Character"
# 6. Verify character appears in sidebar list
# 7. Click character to reload it
# 8. Verify all fields populated correctly
```

**Expected Result:** Character saves to localStorage and reloads successfully

---

## Detailed Test Plan

### Test Suite 1: Data Model Validation ✅

#### Test 1.1: Profile Creation
```javascript
// Open browser console
const muse = new MuseProfile({
    name: 'Test Character',
    basic: { age: '25', ethnicity: 'Caucasian' },
    body: { height: 'tall', build: 'athletic' }
});

console.log(muse.id); // Should start with 'muse_'
console.log(muse.name); // 'Test Character'
console.log(muse.basic.age); // '25'
console.log(muse.body.height); // 'tall'
```

**Expected Result:** Profile created with all default values + overrides

#### Test 1.2: Prompt Generation
```javascript
const prompt = muse.generatePrompt('wearing red dress in ballroom');
console.log(prompt);
// Should include: quality tags, character description, user prompt
```

**Expected Result:** Formatted prompt string with character details

#### Test 1.3: Negative Prompt Generation
```javascript
const negative = muse.generateNegativePrompt();
console.log(negative);
// Should include standard negatives
```

**Expected Result:** Comma-separated negative tags

#### Test 1.4: Variation System
```javascript
muse.addVariation('Casual', 'Everyday outfit', {
    'style.fashionStyle': 'casual',
    'style.preferredOutfits': ['jeans', 't-shirt']
});

console.log(muse.variations.length); // 1
const modified = muse.applyVariation(muse.variations[0].id);
console.log(modified.style.fashionStyle); // 'casual'
```

**Expected Result:** Variation created and overrides applied

#### Test 1.5: History Tracking
```javascript
muse.addToHistory({
    prompt: 'test prompt',
    imageUrl: 'http://example.com/image.png',
    settings: { seed: 12345, steps: 30 }
});

console.log(muse.generationHistory.length); // 1
console.log(muse.generationHistory[0].timestamp); // ISO date
```

**Expected Result:** History entry added with timestamp

---

### Test Suite 2: Storage System 🗄️

#### Test 2.1: IndexedDB Initialization
```javascript
const storage = new MuseStorageManager();
storage.init().then(() => {
    console.log('IndexedDB initialized:', storage.db);
}).catch(err => {
    console.error('Init failed:', err);
});
```

**Expected Result:** Database opens without errors

#### Test 2.2: Reference Image Upload
**Manual Test:**
1. Open Muse modal
2. Create/select character
3. Go to "References" tab
4. Click upload button (if implemented) or drag image
5. Verify image appears in grid
6. Check browser DevTools > Application > IndexedDB > AIKingsMuseDB > referenceImages

**Expected Result:** Image stored as base64 with metadata

#### Test 2.3: localStorage Save/Load
```javascript
const storage = new MuseStorageManager();
const muse = new MuseProfile({ name: 'Storage Test' });

storage.saveMuseProfiles([muse]);
console.log('Saved to localStorage');

const loaded = storage.loadMuseProfiles();
console.log('Loaded:', loaded.length, 'profiles');
console.log('First profile:', loaded[0].name);
```

**Expected Result:** Profile saved and loaded successfully

#### Test 2.4: Export Profile
**Manual Test:**
1. Open Muse modal
2. Select character
3. Click "Export" button
4. Verify JSON file downloads
5. Open file and verify structure

**Expected JSON Structure:**
```json
{
    "version": "1.0",
    "exportedAt": "2026-01-24T...",
    "profile": {
        "id": "muse_...",
        "name": "...",
        "basic": {...},
        "body": {...}
        // ... all fields
    }
}
```

#### Test 2.5: Import Profile
**Manual Test:**
1. Export a character (Test 2.4)
2. Click "Import" button
3. Select exported JSON file
4. Verify character appears in list with new ID
5. Verify all fields populated correctly

**Expected Result:** Character imported with unique ID

---

### Test Suite 3: UI Functionality 🖼️

#### Test 3.1: Tab Navigation
**Manual Test:**
1. Open Muse modal
2. Click each tab: Basic, Body, Face, Features, Style, References, AI Settings, Variations, History, Notes
3. Verify content changes for each tab
4. Verify active tab highlighted

**Expected Result:** All 10 tabs accessible and display correct content

#### Test 3.2: Form Input Persistence
**Manual Test:**
1. Create new character
2. Fill in fields across multiple tabs:
   - Basic: Name "Test", Age "28"
   - Body: Height "tall", Build "athletic"
   - Face: Eye Color "blue", Hair Color "blonde"
3. Click "Save Character"
4. Select different character
5. Return to "Test" character
6. Verify all fields retained values

**Expected Result:** All inputs persist after save/load cycle

#### Test 3.3: Search Functionality
**Manual Test:**
1. Create 3+ characters with different names
2. Type partial name in search box
3. Verify filtered results

**Expected Result:** Real-time filtering works

#### Test 3.4: Category Filter
**Manual Test:**
1. Create characters in different categories
2. Select category from dropdown
3. Verify only matching characters shown

**Expected Result:** Filtering by category works

#### Test 3.5: Favorite Toggle
**Manual Test:**
1. Click star/heart icon on character card
2. Verify isFavorite updates
3. Filter by favorites
4. Verify only favorites shown

**Expected Result:** Favorite status persists

---

### Test Suite 4: ComfyUI Integration 🤖

#### Test 4.1: Endpoint Configuration
```javascript
const comfy = new ComfyUIIntegration();
comfy.setEndpoint('http://127.0.0.1:8188');
console.log('Endpoint set:', comfy.baseUrl);
```

**Expected Result:** Endpoint configured

#### Test 4.2: Default Workflow Generation
```javascript
const muse = new MuseProfile({ name: 'Workflow Test' });
const comfy = new ComfyUIIntegration();

const prompt = muse.generatePrompt('standing in studio');
const negative = muse.generateNegativePrompt();
const workflow = comfy.createDefaultWorkflow(muse, prompt, negative, {
    width: 512,
    height: 768,
    seed: 123456
});

console.log('Workflow nodes:', Object.keys(workflow));
console.log('Positive prompt node:', workflow['6'].inputs.text);
```

**Expected Result:** Workflow JSON with all required nodes

#### Test 4.3: Prompt Injection
```javascript
const customWorkflow = {
    "1": {
        "class_type": "CLIPTextEncode",
        "inputs": { "text": "old positive prompt" }
    },
    "2": {
        "class_type": "CLIPTextEncode",
        "inputs": { "text": "bad quality, ugly, worst quality" }
    }
};

const comfy = new ComfyUIIntegration();
const modified = comfy.injectPromptsIntoWorkflow(
    customWorkflow,
    'NEW POSITIVE PROMPT',
    'NEW NEGATIVE PROMPT'
);

console.log('Node 1:', modified['1'].inputs.text); // NEW POSITIVE PROMPT
console.log('Node 2:', modified['2'].inputs.text); // NEW NEGATIVE PROMPT
```

**Expected Result:** Prompts correctly injected into workflow nodes

#### Test 4.4: Full Generation Flow (Requires ComfyUI Running)

**Prerequisites:**
- ComfyUI running on http://127.0.0.1:8188
- Model loaded (e.g., `realisticVisionV51_v51VAE.safetensors`)

**Manual Test:**
1. Ensure ComfyUI is running and accessible
2. Open studio.html
3. Create character with:
   - Name: "ComfyUI Test"
   - Body: athletic build, fair skin
   - Face: blue eyes, blonde hair
   - AI Settings: Set preferred checkpoint to your model name
4. In Studio prompt input, type: "standing in photo studio, professional photography"
5. Click "Manifest" button
6. Monitor browser console for API calls
7. Check ComfyUI terminal for job submission
8. Wait for generation to complete
9. Verify image appears on canvas

**Expected Result:** 
- POST to `/prompt` successful
- Job appears in ComfyUI queue
- Image generates successfully
- Image displayed in studio
- History entry added to character

**Console Output to Verify:**
```
ComfyUI submission: POST http://127.0.0.1:8188/prompt
Response: { prompt_id: "uuid-here" }
Polling for completion...
Generation complete!
History updated for character
```

#### Test 4.5: Workflow with Variation
**Manual Test:**
1. Create character
2. Add variation: "Business Attire" with overrides
3. Generate with variation selected
4. Verify prompt includes variation overrides

**Expected Result:** Variation attributes reflected in generated prompt

---

### Test Suite 5: Advanced Features 🚀

#### Test 5.1: Dynamic Tattoo/Piercing Lists
**Manual Test:**
1. Go to Features tab
2. Add tattoo: location "right shoulder", description "rose", size "medium"
3. Add piercing: location "navel", type "ring"
4. Save character
5. Reload character
6. Verify tattoos and piercings persist

**Expected Result:** Arrays properly saved and loaded

#### Test 5.2: Tag Management
**Manual Test:**
1. Go to Basic Info tab
2. Add tags: "blonde", "athletic", "confident"
3. Verify tags displayed
4. Remove tag
5. Save and reload

**Expected Result:** Tag array updates correctly

#### Test 5.3: Notes Field
**Manual Test:**
1. Go to Notes tab
2. Type multi-line text
3. Save character
4. Reload
5. Verify text preserved with line breaks

**Expected Result:** Free-form text persists

#### Test 5.4: History Display
**Manual Test:**
1. Generate 3+ images with same character
2. Go to History tab
3. Verify all generations listed with:
   - Timestamp
   - Thumbnail (if implemented)
   - Prompt used
   - Settings

**Expected Result:** Last 50 generations displayed in reverse chronological order

#### Test 5.5: Character Deletion
**Manual Test:**
1. Create test character
2. Select it
3. Click "Delete" button
4. Confirm deletion
5. Verify character removed from list
6. Verify removed from localStorage

**Expected Result:** Character and associated data deleted

---

## Performance Testing

### Load Test: Multiple Characters
```javascript
// Create 50 characters
const storage = new MuseStorageManager();
const profiles = [];

for (let i = 0; i < 50; i++) {
    profiles.push(new MuseProfile({
        name: `Character ${i}`,
        category: ['general', 'fantasy', 'cosplay'][i % 3]
    }));
}

console.time('Save 50 profiles');
storage.saveMuseProfiles(profiles);
console.timeEnd('Save 50 profiles');

console.time('Load 50 profiles');
const loaded = storage.loadMuseProfiles();
console.timeEnd('Load 50 profiles');

console.log('Loaded:', loaded.length, 'profiles');
```

**Expected Result:** Operations complete in < 1 second

### Load Test: Large Reference Images
**Manual Test:**
1. Upload 10 high-resolution images (5MB+ each) to one character
2. Monitor IndexedDB size in DevTools
3. Test load time for character with many images

**Expected Result:** No browser crashes, reasonable load times

---

## Browser Compatibility

### Test on Multiple Browsers

| Browser | Version | Status |
|---------|---------|--------|
| Chrome | Latest | ✅ |
| Edge | Latest | ✅ |
| Firefox | Latest | ✅ |
| Safari | Latest | ⚠️ (Test IndexedDB) |
| Opera | Latest | ✅ |

**Test:**
1. Open studio.html in each browser
2. Run Suite 1-3 tests
3. Verify localStorage and IndexedDB work
4. Check console for errors

---

## Error Handling Tests

### Test Error Scenarios

#### Scenario 1: Invalid JSON Import
**Manual Test:**
1. Create text file with invalid JSON: `{ invalid }`
2. Try to import
3. Verify error message displayed

**Expected Result:** Graceful error handling

#### Scenario 2: ComfyUI Offline
**Manual Test:**
1. Stop ComfyUI server
2. Try to generate image
3. Verify error message

**Expected Result:** User-friendly error, no crash

#### Scenario 3: localStorage Full
```javascript
// Fill localStorage
try {
    for (let i = 0; i < 10000; i++) {
        localStorage.setItem(`test${i}`, 'x'.repeat(10000));
    }
} catch (e) {
    console.log('localStorage full');
}

// Try to save profile
const storage = new MuseStorageManager();
const muse = new MuseProfile({ name: 'Test' });
storage.saveMuseProfiles([muse]); // Should handle gracefully
```

**Expected Result:** Error caught and reported

#### Scenario 4: IndexedDB Unavailable
**Manual Test:**
1. Open incognito/private window (some browsers restrict IndexedDB)
2. Try to upload reference image
3. Verify fallback behavior or error message

**Expected Result:** Graceful degradation

---

## Regression Testing Checklist

Run after any code changes:

- [ ] All tabs navigable
- [ ] Character save/load works
- [ ] Search and filter functional
- [ ] Import/export works
- [ ] Prompt generation includes all attributes
- [ ] ComfyUI integration functional (if server available)
- [ ] No console errors
- [ ] localStorage persists after browser restart
- [ ] IndexedDB images survive reload

---

## Automated Testing Script

Save as `test-muse-system.html`:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Muse System Tests</title>
    <script src="assets/js/muse-manager-pro.js"></script>
</head>
<body>
    <h1>Muse System Test Results</h1>
    <pre id="results"></pre>
    
    <script>
        const results = [];
        
        function test(name, fn) {
            try {
                fn();
                results.push(`✅ ${name}`);
            } catch (error) {
                results.push(`❌ ${name}: ${error.message}`);
            }
        }
        
        // Run tests
        test('MuseProfile creation', () => {
            const muse = new MuseProfile({ name: 'Test' });
            if (!muse.id.startsWith('muse_')) throw new Error('Invalid ID');
            if (muse.name !== 'Test') throw new Error('Name mismatch');
        });
        
        test('Prompt generation', () => {
            const muse = new MuseProfile({ 
                name: 'Test',
                basic: { age: '25' },
                body: { height: 'tall' }
            });
            const prompt = muse.generatePrompt('test scene');
            if (!prompt.includes('Test')) throw new Error('Name not in prompt');
            if (!prompt.includes('test scene')) throw new Error('Scene not in prompt');
        });
        
        test('Variation system', () => {
            const muse = new MuseProfile({ name: 'Test' });
            muse.addVariation('Test Var', 'Desc', { 'body.height': 'short' });
            if (muse.variations.length !== 1) throw new Error('Variation not added');
        });
        
        test('History tracking', () => {
            const muse = new MuseProfile({ name: 'Test' });
            muse.addToHistory({ prompt: 'test', imageUrl: 'http://test.com' });
            if (muse.generationHistory.length !== 1) throw new Error('History not added');
        });
        
        test('JSON serialization', () => {
            const muse = new MuseProfile({ name: 'Test' });
            const json = muse.toJSON();
            const restored = MuseProfile.fromJSON(json);
            if (restored.name !== 'Test') throw new Error('Restoration failed');
        });
        
        test('Storage manager init', async () => {
            const storage = new MuseStorageManager();
            await storage.init();
            if (!storage.db) throw new Error('DB not initialized');
        });
        
        test('ComfyUI integration', () => {
            const comfy = new ComfyUIIntegration();
            comfy.setEndpoint('http://test.com');
            if (comfy.baseUrl !== 'http://test.com') throw new Error('Endpoint not set');
        });
        
        test('Workflow generation', () => {
            const muse = new MuseProfile({ name: 'Test' });
            const comfy = new ComfyUIIntegration();
            const workflow = comfy.createDefaultWorkflow(muse, 'pos', 'neg', {});
            if (!workflow['3']) throw new Error('KSampler node missing');
            if (!workflow['6']) throw new Error('Positive prompt node missing');
        });
        
        // Display results
        document.getElementById('results').textContent = results.join('\n');
        
        const passed = results.filter(r => r.startsWith('✅')).length;
        const total = results.length;
        
        document.body.insertAdjacentHTML('beforeend', 
            `<h2>Results: ${passed}/${total} passed</h2>`
        );
    </script>
</body>
</html>
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Muse System Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Node
        uses: actions/setup-node@v2
        with:
          node-version: '18'
      - name: Install dependencies
        run: npm install puppeteer
      - name: Run tests
        run: node test-runner.js
```

---

## Test Results Log Template

```markdown
# Test Run: [Date]

## Environment
- Browser: Chrome 120
- OS: Windows 11
- ComfyUI: v0.1.0 (running/not running)

## Suite 1: Data Model
- [x] Profile creation
- [x] Prompt generation
- [x] Negative prompt
- [x] Variations
- [x] History tracking

## Suite 2: Storage
- [x] IndexedDB init
- [x] Image upload
- [x] localStorage save/load
- [x] Export
- [x] Import

## Suite 3: UI
- [x] Tab navigation
- [x] Form persistence
- [x] Search
- [x] Category filter
- [x] Favorites

## Suite 4: ComfyUI
- [x] Endpoint config
- [x] Workflow generation
- [x] Prompt injection
- [ ] Full generation (ComfyUI not running)
- [x] Variation generation

## Suite 5: Advanced
- [x] Tattoos/piercings
- [x] Tags
- [x] Notes
- [x] History display
- [x] Character deletion

## Issues Found
None

## Performance
- 50 character load: 120ms
- Image upload: 450ms

## Pass Rate: 28/29 (96.5%)
```

---

## Conclusion

This testing guide provides comprehensive coverage of the Muse System. Run the Quick Start test immediately, then work through detailed suites as needed. For CI/CD, implement the automated test script.

**Next Steps:**
1. Run Quick Start test
2. Complete Suite 1-3 (no ComfyUI required)
3. Set up ComfyUI for Suite 4
4. Document any issues found
5. Create test results log

**Support:**
- Check browser console for errors
- Review MUSE_SYSTEM_ENHANCEMENT.md for architecture
- Verify all files loaded correctly in Network tab
