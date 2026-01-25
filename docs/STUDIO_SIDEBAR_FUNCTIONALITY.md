# Studio Sidebar Navigation - Functionality Guide

## Overview
The studio sidebar contains 4 main navigation buttons that provide quick access to different sections of the AI KINGS platform.

---

## Button Functions

### 1. **Studio** (Paint Brush Icon) 🎨
**Location:** Top button, currently active  
**Function:** 
- Opens/stays in the Studio interface
- This is the main content creation area
- Allows users to generate AI content using prompts and muses
- Active state indicates you're currently in the studio

**Tooltip:** "Studio - Create new content"

---

### 2. **Collection** (Images Icon) 🖼️
**Location:** Second button from top  
**Function:**
- Scrolls to the "My Collection" section below
- Shows saved/bookmarked content
- Displays user's generated images and videos
- Provides access to saved content organized by tabs (Saved, Images, Videos)

**Tooltip:** "Collection - View saved content"

**JavaScript Action:**
```javascript
// Scrolls to #main-gallery section
// Updates active state
// Shows user's saved content
```

---

### 3. **The Muse** (Users Icon) 👥
**Location:** Third button from top  
**Function:**
- Opens "The Casting Room" modal
- Allows users to create and manage character muses
- Edit muse details (name, age, body type, visual traits)
- Select active muse for content generation
- Muse traits are automatically injected into generation prompts

**Tooltip:** "The Muse - Manage characters"

**Modal Features:**
- Muse roster/list on the left
- Muse editor form on the right
- Create new muses
- Edit existing muses
- Active muse indicator in dock

**JavaScript Action:**
```javascript
// Opens modal overlay
// Shows muse management interface
// Handled by TheMuseManager class
```

---

### 4. **Settings** (Gear Icon) ⚙️
**Location:** Bottom button (after spacer)  
**Function:**
- Opens settings/preferences panel
- Future features will include:
  - Generation preferences (quality, style)
  - Storage options
  - Privacy controls
  - Account settings
  - Export/import settings

**Tooltip:** "Settings - Preferences & options"

**Current Implementation:**
- Shows alert with coming soon message
- Placeholder for future settings modal

**JavaScript Action:**
```javascript
// Currently shows alert
// Future: Opens settings modal/panel
```

---

## Visual States

### Active State
- Gold color (`var(--gold-primary)`)
- Light background highlight
- Indicates current section

### Hover State
- Gold color
- Background highlight
- Tooltip appears
- Smooth transition

### Tooltip Behavior
- Appears on hover
- Positioned to the right of button
- Dark background with gold border
- Smooth fade-in animation
- Arrow pointer connecting to button

---

## User Flow Examples

### Creating Content
1. User is in Studio (active)
2. Selects Muse (opens modal)
3. Enters prompt in dock
4. Clicks "Manifest" to generate
5. Result appears in canvas

### Viewing Saved Content
1. User clicks Collection button
2. Page scrolls to "My Collection" section
3. Can switch between Saved/Images/Videos tabs
4. Content filtered by selection

### Managing Muses
1. User clicks The Muse button
2. Modal opens with muse roster
3. Can create, edit, or select muses
4. Active muse shown in dock indicator

---

## Technical Implementation

### CSS Classes
- `.nav-item` - Base button style
- `.nav-item.active` - Active state
- `.nav-item:hover` - Hover state
- `[data-tooltip]` - Tooltip content attribute

### JavaScript Classes
- `StudioApp` - Main studio application
- `TheMuseManager` - Muse management system
- Event listeners on each button
- Smooth scroll behavior for Collection

### Accessibility
- `aria-label` attributes on all buttons
- Keyboard navigation support
- Screen reader friendly
- Focus states

---

## Future Enhancements

1. **Settings Panel**
   - Full modal implementation
   - Preference categories
   - Save/load settings

2. **Collection Integration**
   - Direct content management
   - Quick save from studio
   - Batch operations

3. **Keyboard Shortcuts**
   - `S` - Studio
   - `C` - Collection
   - `M` - Muse
   - `G` - Settings (gear)

4. **Visual Feedback**
   - Loading states
   - Notification badges
   - Activity indicators

---

**Last Updated:** 2026-01-24
