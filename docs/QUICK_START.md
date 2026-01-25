# AI KINGS Muse System - Quick Start Guide

## 🚀 Get Started in 5 Minutes

### Step 1: Open the Studio
Open `studio.html` in your web browser.

### Step 2: Access The Casting Room
Click the **"The Muse"** button (👥 icon) in the left sidebar.

### Step 3: Create Your First Character

1. **Click "+ New"** button
2. **Enter Basic Info**
   - Name: e.g., "Scarlett Phoenix"
   - Age: e.g., "26"
   - Ethnicity: e.g., "Caucasian"

3. **Click "Body" Tab**
   - Build: Athletic
   - Body Shape: Hourglass
   - Skin Tone: Fair

4. **Click "Face & Hair" Tab**
   - Eye Color: Green
   - Hair Color: Red
   - Hair Length: Long
   - Hair Style: Wavy

5. **Click "Save Character"** (bottom right)

### Step 4: Generate Content

1. **Select your character** from the sidebar (it shows as "active")
2. **Type a scene prompt** in the bottom input:
   ```
   standing in a luxury penthouse, wearing red evening gown,
   dramatic lighting, confident pose
   ```
3. **Click "Manifest"**

---

## 📋 Key Features Cheat Sheet

### Character Editor Tabs

| Tab | What It's For |
|-----|---------------|
| **Basic Info** | Name, age, ethnicity, category, tags |
| **Body** | Height, build, measurements, skin tone |
| **Face & Hair** | Eyes, lips, nose, hair color/style, makeup |
| **Features** | Tattoos, piercings, unique traits |
| **Style & Persona** | Fashion, lingerie, personality, vibe |
| **References** | Upload reference images |
| **AI Settings** | Quality tags, ComfyUI settings |
| **Variations** | Save outfit/scenario variations |
| **History** | View past generations |
| **Notes** | Ideas and notes about character |

### Essential AI Settings (AI Settings Tab)

```
Quality Tags: masterpiece, best quality, high resolution, detailed
Style Tags: photorealistic, cinematic lighting, professional photography
Sampler: DPM++ 2M Karras
Steps: 30
CFG Scale: 7
```

### ComfyUI Setup

1. **Install ComfyUI**: https://github.com/comfyanonymous/ComfyUI
2. **Run ComfyUI**: `python main.py`
3. **In Studio**: Click Settings (⚙️) → Enter `http://127.0.0.1:8188`

---

## 💡 Pro Tips

### For Best Results

1. **Upload Reference Images**
   - Go to References tab
   - Upload 2-3 clear photos
   - Mark one as "Primary"

2. **Be Specific with Attributes**
   - More details = better consistency
   - Fill out at least: Body, Face, Hair

3. **Use Variations**
   - Create base character
   - Go to Variations tab
   - Add: "Office Outfit", "Gym Look", "Evening Wear"
   - Select variation before generating

4. **Organize with Tags**
   - Add tags: "redhead", "athletic", "professional"
   - Use Category dropdown to filter
   - Star (⭐) favorites

### Common Prompts

**Portrait:**
```
close-up portrait, looking at camera, soft studio lighting,
professional headshot, shallow depth of field
```

**Full Body:**
```
full body shot, standing pose, studio lighting,
white background, fashion photography
```

**Scene:**
```
sitting on modern sofa, luxury apartment interior,
golden hour lighting, candid pose, relaxed expression
```

**Action:**
```
walking down city street, sunset, urban background,
confident stride, casual outfit, cinematic composition
```

---

## 🔧 Troubleshooting Quick Fixes

| Problem | Solution |
|---------|----------|
| Character not generating | Select character from sidebar first |
| "ComfyUI request failed" | Check ComfyUI is running at http://127.0.0.1:8188 |
| Reference image won't upload | Ensure image is JPG/PNG and < 5MB |
| Lost characters | Export characters regularly (Export button) |
| Generation stuck | Check ComfyUI console for errors |

---

## 📦 Import/Export

### Export Character
1. Select character
2. Click "Export" button (bottom left)
3. Saves as `muse_character_name.json`

### Import Character
1. Click "Import" button
2. Select `.json` file
3. Character added to your roster

---

## 🎯 Workflow Example

**Creating a Character Library:**

1. **Create Base Character**
   - Full physical details
   - Upload 2-3 references
   - Save

2. **Add Variations**
   - "Casual" - jeans and t-shirt
   - "Business" - suit and heels
   - "Lingerie" - lace set
   - "Workout" - athletic wear

3. **Generate Set**
   - Select "Casual" variation
   - Generate: "sitting in coffee shop"
   - Select "Business" variation
   - Generate: "standing in office"
   - Etc.

4. **Review History**
   - Go to History tab
   - See all 4 generations
   - Best ones saved automatically

---

## 📞 Need Help?

- **Full Guide**: See `MUSE_SYSTEM_GUIDE.md` for complete documentation
- **Code Reference**: Check source code comments
- **Browser Console**: Press F12 to see error messages
- **Test System**:
  ```javascript
  // In browser console:
  window.studioAppPro.museManager.getActiveMuse()
  ```

---

## ✨ What Makes This Professional

### Old System
- 4 basic fields
- Simple string concatenation
- No images
- No history

### New System
- **70+ attributes** for precise character definition
- **Reference images** with IndexedDB storage
- **ComfyUI integration** with proper workflow injection
- **Character variations** for different scenarios
- **Generation history** tracking
- **Import/Export** for sharing/backup
- **Professional UI** with 10 organized tabs

---

**Ready to create?** Open `studio.html` and start building your character library!
