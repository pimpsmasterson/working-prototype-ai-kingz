# Admin Panel Access Guide - AI KINGS Platform

**Last Updated:** January 26, 2026  
**Status:** ✅ Production Ready for Presentation

---

## 🎯 Quick Access URLs

### Admin Panel
- **Primary URL:** http://localhost:3000/pages/admin-warm-pool.html
- **Alternative URL:** http://localhost:3000/admin/warm-pool
- **From Main Site:** Click the gear-six icon (🔧) in the studio sidebar navigation

### Main Platform
- **Homepage:** http://localhost:3000/pages/index.html
- **Studio (Embedded):** Embedded in homepage - scroll to hero section

---

## 🚀 How to Access During Your Presentation

### Option 1: Direct Admin Panel Access
1. **Start the server** (if not running):
   ```powershell
   npm run start:pm2
   ```

2. **Open your browser** and navigate to:
   ```
   http://localhost:3000/pages/admin-warm-pool.html
   ```

3. **Enter your admin key** in the authentication field and click "Refresh Status"

### Option 2: Navigate from Main Site
1. **Open the main platform**:
   ```
   http://localhost:3000/pages/index.html
   ```

2. **Locate the studio sidebar** (left side of hero section)

3. **Click the admin panel icon** (gear-six icon 🔧) - it's positioned above the regular Settings gear icon

4. **Admin panel opens in new tab** at the correct localhost:3000 address

---

## ✅ Pre-Presentation Checklist

### 1. Server Status Check
```powershell
# Check if server is running
pm2 status

# Expected output: vastai-proxy should be "online"
```

### 2. Health Endpoint Test
```powershell
# PowerShell
Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/health" -Method Get

# Expected output: { ok: true, message: "..." }
```

### 3. Admin Panel Access Test
- Open: http://localhost:3000/pages/admin-warm-pool.html
- Verify: Server URL indicator shows `http://localhost:3000`
- Check browser console for: `✅ Server health check passed`

### 4. Studio Embedding Test
- Open: http://localhost:3000/pages/index.html
- Scroll to hero section
- Verify: Studio interface is visible and interactive
- Verify: Admin panel icon (gear-six) is visible in sidebar

---

## 🔧 Admin Panel Features

### Server Management (PM2)
- ✅ Check PM2 Status
- ✅ Restart Server
- ✅ Stop Server
- ✅ Start Server

### GPU Warm-Pool Management
- ✅ One-Click NSFW GPU Setup (Prewarm)
- ✅ View Current Instance Details
- ✅ GPU Specifications & Cost
- ✅ Setup Progress Tracking
- ✅ Terminate Instance
- ✅ Run Health Check

### Configuration
- ✅ Runtime Token Management (HuggingFace, Civitai)
- ✅ ComfyUI Provision Script URL
- ✅ Minimum CUDA Capability Settings

### Emergency Controls
- ✅ Reset WarmPool State (Clear Cache)
- ✅ Proxy Health Status Indicator

### Audit Logs
- ✅ View Admin Actions History
- ✅ Filter by Date, Action, IP
- ✅ Paginated Results

---

## 🎨 Studio Integration Details

### Current Implementation Status
✅ **Studio Embedded**: Fully functional in homepage hero section  
✅ **Navigation Icons**: All sidebar icons operational  
✅ **Admin Panel Link**: Properly configured with correct port  
✅ **API Integration**: Uses localhost:3000 by default  

### Studio Features
- **Prompt Input**: Generate content from text descriptions
- **Muse System**: Character consistency across generations
- **Collection View**: Access saved content gallery
- **Settings Panel**: Configuration and preferences

### How Studio Connects to API
```javascript
// From assets/js/admin-warm-pool.js
const API_BASE = (window.__API_BASE__ || 'http://localhost:3000');

// All API calls use this base:
// - /api/proxy/health
// - /api/proxy/admin/warm-pool
// - /api/proxy/warm-pool/prewarm
// - etc.
```

---

## 📋 Presentation Flow Suggestion

### 1. Show Main Platform (2 min)
- Navigate to http://localhost:3000/pages/index.html
- Highlight the luxurious design and branding
- Scroll to show embedded studio interface

### 2. Demonstrate Studio (3 min)
- Show prompt input and generate button
- Open Muse panel to show character creation
- Explain how consistent characters work

### 3. Access Admin Panel (1 min)
- Click admin panel icon in studio sidebar
- **OR** directly open http://localhost:3000/pages/admin-warm-pool.html
- Show server status indicator

### 4. Show GPU Management (4 min)
- Explain warm-pool concept (pre-configured GPU ready to go)
- Click "Prewarm GPU Now" button
- Show real-time status updates
- Demonstrate health check feature
- Show PM2 server controls

---

## 🐛 Troubleshooting

### Issue: Admin panel shows "Failed to fetch"
**Solution:**
```powershell
# Restart the server
pm2 restart vastai-proxy

# OR start if not running
npm run start:pm2
```

### Issue: Admin panel icon not visible
**Solution:**
- Clear browser cache and reload page
- Verify you're on http://localhost:3000/pages/index.html
- Check browser console for JavaScript errors

### Issue: Port 3000 already in use
**Solution:**
```powershell
# Find process using port 3000
Get-Process -Id (Get-NetTCPConnection -LocalPort 3000).OwningProcess

# Kill if needed
taskkill /PID <process_id> /F

# Restart server
npm run start:pm2
```

### Issue: Stale warm-pool state (stuck "already prewarming")
**Solution:**
1. Click "Reset WarmPool State" button in Emergency section
2. Or manually reset DB:
   ```powershell
   node -e "const db=require('./server/db').db; db.prepare('UPDATE warm_pool SET instance = NULL, isPrewarming = 0 WHERE id = 1').run(); console.log('reset');"
   ```
3. Restart server: `pm2 restart vastai-proxy`

---

## 🔐 Environment Variables Required

The server requires these environment variables to run:

```bash
# Required
VASTAI_API_KEY=your_vast_ai_api_key_here
ADMIN_API_KEY=your_admin_password_here

# Optional (for model downloads)
HUGGINGFACE_HUB_TOKEN=your_hf_token_here
CIVITAI_TOKEN=your_civitai_token_here

# Optional (audit logging)
AUDIT_SALT=random_salt_for_hmac
```

**For presentation:** Ensure these are set in your terminal session or `.env` file before running `npm run start:pm2`

---

## 📊 Current Status Summary

- **Server Port:** 3000 (configurable via `PORT` env var)
- **Admin Panel Path:** `/pages/admin-warm-pool.html` or `/admin/warm-pool`
- **Static Files:** Served from workspace root via `express.static`
- **Admin Icon:** Gear-six (🔧) in studio sidebar, above Settings
- **Admin Link:** Opens in new tab at `http://localhost:3000/pages/admin-warm-pool.html`
- **Auto Status Check:** Admin panel pings `/api/proxy/health` on load
- **API Base:** Defaults to `localhost:3000`, respects `window.__API_BASE__` override

---

## 🎯 Key Improvements Made

1. ✅ Added admin panel icon to studio sidebar navigation
2. ✅ Configured icon to open admin panel in new tab
3. ✅ Updated admin panel branding (AI KINGS instead of Fetish King)
4. ✅ Added server URL indicator in admin panel
5. ✅ Added auto-health check on admin panel load
6. ✅ Verified all API endpoints use correct localhost:3000 base
7. ✅ Confirmed studio embedding is fully functional
8. ✅ Verified PM2 server management integration

---

## 📞 Need Help During Presentation?

**Quick Commands:**
```powershell
# Check server status
pm2 status

# View server logs
pm2 logs vastai-proxy

# Restart everything
pm2 restart vastai-proxy

# Check health
curl http://localhost:3000/api/proxy/health
```

**Emergency Reset:**
```powershell
pm2 kill
npm run start:pm2
```

---

**Ready for your presentation! 🚀**
