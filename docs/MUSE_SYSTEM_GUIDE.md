# AI KINGS - Professional Muse Management System

## Complete Integration Guide for Adult Content AI Generation

---

## Table of Contents

1. [Overview](#overview)
2. [What's Been Built](#whats-been-built)
3. [System Architecture](#system-architecture)
4. [Features](#features)
5. [Setup & Integration](#setup--integration)
6. [Using the System](#using-the-system)
7. [ComfyUI Integration](#comfyui-integration)
8. [Advanced Features](#advanced-features)
9. [Troubleshooting](#troubleshooting)

---

## Overview

The Professional Muse Management System is a comprehensive character creation and management solution designed specifically for adult content AI generation with ComfyUI integration.

### Why This Redesign?

The original muse system was too basic for professional adult content generation:
- ❌ Only 4 basic fields (name, age, body type, traits)
- ❌ Poor prompt engineering (simple string concatenation)
- ❌ No character consistency features
- ❌ No reference image support
- ❌ No proper AI model integration

### What's New

The professional system includes:
- ✅ **70+ Character Attributes** - Comprehensive physical and personality details
- ✅ **Reference Image System** - Upload and manage character reference photos
- ✅ **ComfyUI Integration** - Direct workflow integration with proper parameter injection
- ✅ **Character Variations** - Save outfit/scenario variations per character
- ✅ **Generation History** - Track what you've created with each character
- ✅ **Advanced Prompt Engineering** - Proper positive/negative prompts with quality tags
- ✅ **Import/Export** - Share and backup character profiles
- ✅ **Professional UI** - Multi-tab editor with organized sections

---

## What's Been Built

### New Files Created

1. **`assets/js/muse-manager-pro.js`**
   - Core data models (MuseProfile class)
   - Storage management (IndexedDB + localStorage)
   - ComfyUI integration class
   - ~650 lines of professional code

2. **`assets/js/muse-manager.js`**
   - Main manager class with CRUD operations
   - UI rendering and event handling
   - Feature management (tattoos, piercings, variations)
   - Import/export functionality
   - ~850 lines

3. **`assets/js/ai-kings-studio-pro.js`**
   - Updated studio app integrating professional muse system
   - ComfyUI generation workflow
   - Mock generation fallback
   - Notification system
   - ~350 lines

4. **`assets/css/muse-manager-pro.css`**
   - Complete professional UI styling
   - Multi-tab editor layout
   - Responsive design
   - Custom scrollbars and animations
   - ~650 lines

5. **`muse-modal-professional.html`**
   - Complete HTML structure (reference/template)
   - All 10 tabs fully structured
   - Ready-to-use form fields

### Updated Files

1. **`studio.html`**
   - Replaced old muse modal with professional version
   - Added CSS and JS script references
   - Updated initialization code

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         USER INTERFACE                       │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Multi-Tab Character Editor (10 Tabs)              │    │
│  │  - Basic Info  - Body  - Face  - Features          │    │
│  │  - Style - References - AI Settings - Variations   │    │
│  │  - History - Notes                                  │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                      MUSE MANAGER                            │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │  MuseProfile     │  │  MuseManager     │                │
│  │  (Data Model)    │  │  (Controller)    │                │
│  └──────────────────┘  └──────────────────┘                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                         STORAGE                              │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │  IndexedDB       │  │  localStorage    │                │
│  │  (Ref Images)    │  │  (Profiles)      │                │
│  └──────────────────┘  └──────────────────┘                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    COMFYUI INTEGRATION                       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  - Workflow Generation                               │  │
│  │  - Parameter Injection                               │  │
│  │  - Prompt Engineering                                │  │
│  │  - Job Submission & Polling                          │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ↓
                      ComfyUI Server
                   (http://127.0.0.1:8188)
```

---

## Features

### 1. Comprehensive Character Profiles

#### Basic Information
- Character name
- Age (actual and appearance)
- Nationality & ethnicity
- Occupation (for context)
- Category & tags

#### Body Attributes
- Height (descriptive + optional cm)
- Build (petite, slim, athletic, curvy, voluptuous, muscular, plus-size)
- Body shape (hourglass, pear, apple, rectangle, triangle)
- Skin tone (7 options from pale to dark)
- Measurements (bust, cup size, waist, hips)
- Muscle tone
- Body hair

#### Face & Hair
- Face shape, jawline, cheekbones
- Eye color, shape, size
- Hair color, length, style, texture
- Lips, nose
- Makeup style
- Facial hair (for male characters)

#### Distinguishing Features
- **Tattoos** (location, description, size) - Dynamic list
- **Piercings** (location, type) - Dynamic list
- Scars, birthmarks
- Accessories
- Unique traits

#### Style & Persona
- Fashion style
- Lingerie preferences
- Footwear
- Nails
- Personality description
- Overall vibe

### 2. Reference Image System

- **Upload Multiple Images** - Store character reference photos
- **Primary Reference Selection** - Mark one for IP-Adapter/ControlNet
- **IndexedDB Storage** - Efficient storage for images
- **Visual Gallery** - See all references at a glance
- **Quick Actions** - Set primary, delete

### 3. AI Settings

#### Prompt Engineering
- **Quality Tags** - Default: "masterpiece, best quality, high resolution, detailed"
- **Style Tags** - "photorealistic, cinematic, studio lighting", etc.
- **Positive Prefix** - Additional tags for every generation
- **Negative Additions** - Custom negative prompts

#### ComfyUI Configuration
- Preferred checkpoint model
- Preferred VAE
- Sampler (default: DPM++ 2M Karras)
- Steps (default: 30)
- CFG Scale (default: 7)
- Custom workflow JSON support

### 4. Character Variations

Create multiple versions of the same character:
- Different outfits ("Office Look", "Gym Outfit", "Lingerie")
- Different scenarios
- Style variations
- Each variation can override specific attributes

### 5. Generation History

- Automatically track all generations per character
- Store prompt, image URL, and settings
- Last 50 generations kept
- Visual thumbnail gallery
- Click to view details

### 6. Import/Export

- **Export Character** - Save as JSON file
- **Import Character** - Load from JSON
- Share characters between projects
- Backup critical characters

---

## Setup & Integration

### Prerequisites

1. **ComfyUI Installation** (for actual AI generation)
   - Install ComfyUI: https://github.com/comfyanonymous/ComfyUI
   - Run ComfyUI server: `python main.py`
   - Default endpoint: `http://127.0.0.1:8188`

2. **AI Models** (place in ComfyUI directories)
   - SD 1.5 or SDXL checkpoint
   - VAE file
   - Optional: LoRAs, embeddings for character consistency
   - Optional: IP-Adapter for reference images

### Quick Start

1. **Open studio.html in your browser**
   ```
   Open: working prototype/studio.html
   ```

2. **Click "The Muse" button** in the sidebar
   - Professional casting room modal will open

3. **Create your first character**
   - Click "+ New" button
   - Enter character name
   - Fill in basic info tab
   - Add body, face details
   - Upload reference images (optional)
   - Configure AI settings
   - Click "Save Character"

4. **Generate content**
   - Select your character from the list (it becomes active)
   - Type a scene prompt: "standing in a luxury bedroom, sultry pose, dramatic lighting"
   - Click "Manifest"

### File Structure

```
working prototype/
├── studio.html                        ← Main studio page (UPDATED)
├── assets/
│   ├── css/
│   │   ├── muse-manager-pro.css      ← NEW: Professional UI styles
│   │   └── ...
│   └── js/
│       ├── muse-manager-pro.js       ← NEW: Core data models & storage
│       ├── muse-manager.js           ← NEW: Main manager class
│       ├── ai-kings-studio-pro.js    ← NEW: Updated studio app
│       └── ...
├── docs/
│   └── MUSE_SYSTEM_GUIDE.md          ← This file
└── muse-modal-professional.html       ← HTML reference/template
```

---

## Using the System

### Creating a Character

1. **Basic Information Tab**
   - Enter name, age, ethnicity
   - Choose category (General, Fantasy, Cosplay, etc.)
   - Add tags for organization

2. **Body Tab**
   - Select height, build, body shape
   - Choose skin tone
   - Optionally add measurements

3. **Face & Hair Tab**
   - Define facial features
   - Set hair color, length, style
   - Choose makeup style

4. **Features Tab**
   - Add tattoos (+ button to add more)
   - Add piercings
   - Describe unique traits

5. **Style & Persona Tab**
   - Fashion preferences
   - Lingerie style
   - Personality description

6. **References Tab**
   - Upload reference photos
   - Mark primary reference for face consistency

7. **AI Settings Tab**
   - Configure quality tags
   - Set preferred model/VAE
   - Adjust generation parameters

8. **Save** - Click "Save Character" in footer

### Generating with a Character

1. **Select Character** - Click on character card in sidebar
2. **Choose Variation** (optional) - Go to Variations tab, click "Use"
3. **Enter Scene Prompt** - Type your scene description
4. **Generate** - Click "Manifest"

The system will:
- Build comprehensive prompt from character attributes
- Inject it into ComfyUI workflow
- Submit generation job
- Poll for completion
- Display result
- Add to character's history

### Managing Characters

#### Search & Filter
- **Search** - Type in search box to filter by name
- **Category Filter** - Dropdown to filter by category
- **Favorites** - Star characters to keep them at the top

#### Import/Export
- **Export** - Click "Export" in footer → saves JSON file
- **Import** - Click "Import" → select JSON file

#### Delete
- Click "Delete" in footer → confirms before deleting

---

## ComfyUI Integration

### How It Works

1. **Prompt Generation**
   ```javascript
   // Character description is automatically built from profile
   const prompt = muse.generatePrompt(userPrompt, variationId);

   // Example output:
   // "masterpiece, best quality, high resolution, Seraphina, 25 years old,
   //  Caucasian, athletic hourglass figure, 36C-26-38, fair skin,
   //  long blonde straight hair, almond blue eyes, full lips, natural makeup,
   //  dragon tattoo on shoulder, wearing elegant evening dress, standing in
   //  a luxury bedroom, sultry pose, dramatic lighting"
   ```

2. **Negative Prompt**
   ```javascript
   const negativePrompt = muse.generateNegativePrompt();

   // Output:
   // "ugly, deformed, disfigured, poorly drawn, bad anatomy, mutation,
   //  blur, low quality, worst quality"
   ```

3. **Workflow Injection**
   - Takes your custom ComfyUI workflow JSON (or uses default)
   - Finds CLIP Text Encode nodes
   - Injects positive/negative prompts
   - Submits to ComfyUI API

4. **Result Polling**
   - Polls `/history/{prompt_id}` every 5 seconds
   - Checks for completion or errors
   - Retrieves output images
   - Displays in studio

### Configuring ComfyUI Endpoint

1. Click "Settings" button in studio sidebar
2. Enter ComfyUI URL (default: `http://127.0.0.1:8188`)
3. URL is saved to localStorage

### Using Custom Workflows

You can use your own ComfyUI workflows:

1. Export workflow from ComfyUI (API format)
2. Open character in editor
3. Go to AI Settings tab
4. Paste workflow JSON into `customWorkflow` field (or add via code)

The system will automatically inject prompts into CLIP Text Encode nodes.

### Mock Generation Mode

If ComfyUI is not running, the system falls back to **mock generation**:
- Simulates generation process with progress updates
- Shows placeholder image
- Useful for testing UI without running ComfyUI

---

## Advanced Features

### Character Variations

**Use Case:** Same character, different outfits/scenarios

1. Go to Variations tab
2. Click "+ Add Variation"
3. Enter name: "Gym Outfit"
4. Description: "Athletic wear at the gym"
5. System saves current character state as base
6. When generating, click "Use" on variation

**How it works:**
- Variation stores overrides to base character
- When selected, it merges with base character
- Example: Change `fashionStyle` from "elegant" to "sporty"

### LoRA and Embedding Support

Add to character AI Settings:

```javascript
muse.aiSettings.loraModels = [
    {
        name: 'character_lora.safetensors',
        weight: 0.8,
        trigger: 'special_trigger'
    }
];

muse.aiSettings.embeddings = [
    {
        name: 'face_embedding',
        trigger: 'face_embed'
    }
];
```

System will inject these into ComfyUI workflow.

### Bulk Operations

**Export All Characters:**
```javascript
const allMuses = window.studioAppPro.museManager.muses;
allMuses.forEach(muse => {
    window.studioAppPro.museManager.storage.exportProfile(muse);
});
```

**Clear All History:**
```javascript
muse.generationHistory = [];
window.studioAppPro.museManager.save();
```

### Programmatic Access

Access via browser console:

```javascript
// Get active muse
const muse = window.studioAppPro.museManager.getActiveMuse();

// Generate prompt preview
console.log(muse.generatePrompt("sitting on a throne"));

// Get all muses
const allMuses = window.studioAppPro.museManager.muses;

// Create muse programmatically
const newMuse = new MuseProfile({
    name: "Aurora",
    basic: { ethnicity: "Asian", age: "23" },
    body: { build: "slim", skinTone: "fair" }
});
window.studioAppPro.museManager.muses.push(newMuse);
window.studioAppPro.museManager.save();
```

---

## Troubleshooting

### Issue: "ComfyUI request failed"

**Solution:**
- Check ComfyUI server is running
- Verify endpoint URL in Settings
- Check browser console for CORS errors
- Ensure ComfyUI has `--listen` flag if on network

### Issue: Reference images not uploading

**Solution:**
- Check browser supports IndexedDB (all modern browsers do)
- Ensure image is valid format (JPG, PNG, WebP)
- Try smaller image size (< 5MB recommended)
- Check browser console for errors

### Issue: Character prompts not working well

**Solution:**
- Review AI Settings → Quality Tags
- Add model-specific trigger words
- Adjust negative prompt additions
- Try different samplers/steps in AI Settings
- Check if checkpoint model supports your descriptors

### Issue: Generation stuck "Dreaming..."

**Solution:**
- Check ComfyUI console for errors
- Verify workflow is valid
- Ensure model files exist in ComfyUI
- Try mock generation mode to test UI
- Reduce steps/resolution if ComfyUI is overloaded

### Issue: Lost characters after browser refresh

**Solution:**
- Characters are in localStorage - check if localStorage is enabled
- Try different browser
- Export characters as backup (Import/Export buttons)
- Check browser console for storage errors

---

## API Reference

### MuseProfile Class

```javascript
const muse = new MuseProfile({
    name: 'Character Name',
    basic: { age: '25', ethnicity: 'Caucasian' },
    body: { build: 'athletic', skinTone: 'fair' },
    face: { eyeColor: 'blue', hairColor: 'blonde' }
});

// Generate prompts
const prompt = muse.generatePrompt(userPrompt, variationId);
const negative = muse.generateNegativePrompt();

// Add variation
muse.addVariation('Variation Name', 'Description', overrides);

// Add to history
muse.addToHistory({ prompt, imageUrl, settings });

// Serialize
const json = muse.toJSON();
const restored = MuseProfile.fromJSON(json);
```

### MuseManager Class

```javascript
const manager = window.studioAppPro.museManager;

// CRUD operations
manager.createNewMuse();
manager.selectMuse(museId);
manager.saveActiveMuse();
manager.deleteActiveMuse();

// Import/Export
manager.exportActiveMuse();
await manager.importMuse();

// Get active muse
const muse = manager.getActiveMuse();
const variation = manager.getActiveVariation();
```

### ComfyUIIntegration Class

```javascript
const comfy = window.studioAppPro.comfyUI;

// Set endpoint
comfy.setEndpoint('http://127.0.0.1:8188');

// Generate
const result = await comfy.generateWithMuse(muse, prompt, variation, settings);

// Custom workflow
const workflow = comfy.buildWorkflow(muse, positivePrompt, negativePrompt, settings);
const response = await comfy.submitWorkflow(workflow);
```

---

## Best Practices

### 1. Character Creation

- **Start Simple** - Fill basic info first, add details later
- **Use References** - Upload at least 1-2 reference images
- **Be Specific** - More details = better consistency
- **Test Prompts** - Generate with different prompts to verify

### 2. Prompt Engineering

- **Quality Tags Matter** - Always include "masterpiece, best quality"
- **Negative Prompts** - Add common issues to negative (bad hands, blur, etc.)
- **Style Consistency** - Use consistent style tags across generations
- **Model-Specific** - Research your checkpoint model's preferred tags

### 3. Organization

- **Use Categories** - Organize characters by type
- **Tag Everything** - Use tags for easy filtering
- **Favorite Important Ones** - Star your best characters
- **Export Backups** - Regularly export important characters

### 4. Performance

- **Limit History** - System keeps last 50 generations (auto-cleanup)
- **Optimize Images** - Compress reference images before upload
- **Close Unused Tabs** - Browser performance
- **Archive Old Characters** - Keep active roster manageable

---

## Next Steps & Future Enhancements

### Potential Additions

1. **Character Templates** - Pre-made character profiles
2. **Batch Generation** - Generate multiple variations at once
3. **Collection View** - Gallery of all generated images
4. **Advanced Workflow Editor** - Visual ComfyUI workflow builder
5. **Cloud Sync** - Sync characters across devices
6. **Sharing Platform** - Community character marketplace
7. **A1111 Integration** - Support for Automatic1111 in addition to ComfyUI

---

## Support & Contact

For issues or questions about this system:

1. **Check Console** - Browser DevTools → Console for errors
2. **Review This Guide** - Troubleshooting section
3. **Test Components**:
   - Muse Manager: `window.studioAppPro.museManager`
   - ComfyUI: `window.studioAppPro.comfyUI`
   - Storage: Check localStorage and IndexedDB

---

## Changelog

### Version 1.0.0 (Initial Release)

**Complete Redesign**
- ✅ Professional muse management system
- ✅ 70+ character attributes
- ✅ Reference image system (IndexedDB)
- ✅ ComfyUI integration
- ✅ Character variations
- ✅ Generation history
- ✅ Import/Export functionality
- ✅ Advanced prompt engineering
- ✅ Multi-tab professional UI
- ✅ Responsive design

**Files Created:**
- `muse-manager-pro.js` (650 lines)
- `muse-manager.js` (850 lines)
- `ai-kings-studio-pro.js` (350 lines)
- `muse-manager-pro.css` (650 lines)
- `muse-modal-professional.html`
- `MUSE_SYSTEM_GUIDE.md`

**Files Updated:**
- `studio.html` - Integrated professional muse system

---

## License

This system is part of the AI KINGS prototype for adult content generation.
All code is proprietary to the client.

---

**End of Guide** - For technical support, refer to the code comments in the source files.
