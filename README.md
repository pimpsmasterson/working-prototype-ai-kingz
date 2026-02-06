# 🤖 AI KINGS - AI-Powered Adult Content Generation Platform

[![Tests](https://github.com/pimpsmasterson/working-prototype-ai-kingz/workflows/Tests/badge.svg)](https://github.com/pimpsmasterson/working-prototype-ai-kingz/actions)
[![Coverage](https://img.shields.io/badge/coverage-41.96%25_statements_32.85%25_branches-brightgreen)](https://github.com/pimpsmasterson/working-prototype-ai-kingz)

**fetishking.com** - Professional AI-powered platform for creating custom adult content with advanced character systems and cloud GPU management.

## ✨ Features

### 🎨 **Advanced Character Creation (Muse System)**
- **39+ customization options** - Build detailed characters with physical attributes, personality, and style
- **Reference image support** - Upload photos for AI consistency using IP-Adapter technology
- **Character variations** - Same character, different outfits/scenarios
- **Generation history** - Track all creations per character
    
    ### ⚡ **"Smart Boot" System**
    - **Zero-Config Start**: No manual SSH/setup required.
    - **Auto-Recovery**: Detects missing GPUs and provisions them instantly.
    - **One-Click Connect**: Automated `connect.ps1` script to SSH into instances.
    - **Live Feedback**: Real-time status in Studio UI and granular logs.

### 🚀 **Fully Automated Cloud GPU Management (Warm Pool)**
- **One-Click GPU Rental** from Vast.ai marketplace via admin panel
- **Automated NSFW Setup** - Pre-configured ComfyUI with Pony Diffusion V6 XL and fetish LoRAs
- **Provisioning note (2026-02-03)**: Default Dropbox model links were embedded directly into the provisioning scripts for deterministic downloads. See `docs/DROPBOX_INTEGRATION.md` for details.
- **Idle shutdown** - Auto-terminate after 15 minutes to save costs
- **Safe mode** - Emergency shutdown for cost control
- **Real-time monitoring** - 30-second health checks
- **Admin dashboard** - Full control and audit logging

### 🔧 **Professional Backend**
- **Express.js server** with comprehensive API endpoints
- **SQLite database** with automatic migrations
- **Audit logging** - All admin actions tracked with HMAC fingerprinting
- **Error handling** - Robust recovery from network/API failures
- **Security** - API key validation, admin authentication

### 🧪 **Production-Ready Testing**
- **95 passing tests** with comprehensive coverage
- **89.64% statement coverage**, **75.62% branch coverage**
- **CI/CD pipeline** - Automated testing on Node.js 18, 20, 22
- **Deterministic tests** - No flaky behavior, full isolation

## 🚀 Quick Start

### Prerequisites
- Node.js 18+ (tested on 18, 20, 22)
- Vast.ai API key (for GPU rental)
- Optional: Hugging Face token (for model downloads)
- Optional: Civitai token (for adult model downloads)

### Installation

```bash
# Clone the repository
git clone https://github.com/pimpsmasterson/working-prototype-ai-kingz.git
cd working-prototype-ai-kingz

# Install dependencies
npm install

# Set up environment variables
cp .env.example .env
# Edit .env with your API keys

# Run tests to verify everything works
npm test

# Start the server
npm start
```

### Access the Platform
- **Studio**: http://localhost:3000/studio.html
- **Admin Dashboard**: http://localhost:3000/admin/warm-pool
- **Health Check**: http://localhost:3000/api/proxy/health

### One-Click Start (PM2 + Prewarm)
We provide a `one-click-start.ps1` script that starts the server under PM2, waits for the HTTP health check, and triggers the warm-pool prewarm which attempts to rent a Vast.ai instance. See `docs/ONE-CLICK-START.md` for details and troubleshooting steps.

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Proxy Server  │    │   Vast.ai API   │
│   (HTML/CSS/JS) │◄──►│   (Express.js)  │◄──►│   (Cloud GPUs)  │
│                 │    │                 │    │                 │
│ • Studio UI     │    │ • API proxying  │    │ • GPU rental    │
│ • Muse manager  │    │ • Warm pool mgmt│    │ • Instance mgmt │
│ • Gallery       │    │ • Auth & audit  │    │ • ComfyUI       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                ▲
                                │
                    ┌─────────────────┐
                    │   Database      │
                    │   (SQLite)      │
                    │                 │
                    │ • Instance state│
                    │ • Audit logs    │
                    │ • Usage events  │
                    └─────────────────┘
```

## 🧪 Testing

```bash
# Run all tests
npm test

# Run with coverage report
npm run coverage

# Run specific test file
npm test -- tests/warm-pool.test.js
```

### Test Coverage
- **Statements**: 41.96%
- **Branches**: 32.85%
- **Functions**: 45.01%
- **Lines**: 42.27%

## 🚀 Deployment

### Development
```bash
npm start
```

### Production (PM2)
```bash
npm install -g pm2
pm2 start ecosystem.config.js
```

### Docker (Future)
```bash
# Coming soon
```

## 🔐 Environment Variables

```bash
# Required
VASTAI_API_KEY=your_vast_ai_key
ADMIN_API_KEY=secure_admin_password

# Optional
HUGGINGFACE_TOKEN=your_huggingface_token
CIVITAI_TOKEN=your_civitai_token
AUDIT_SALT=random_salt_for_hashing
WARM_POOL_IDLE_MINUTES=15
COMFYUI_PROVISION_SCRIPT=https://gist.githubusercontent.com/pimpsmasterson/9fb9d7c60d3822c2ffd3ad4b000cc864/raw/provision-reliable.sh
# Enforce provisioning to use only the allowed script(s)
PROVISION_ALLOWED_SCRIPTS=https://gist.githubusercontent.com/pimpsmasterson/9fb9d7c60d3822c2ffd3ad4b000cc864/raw/
PROVISION_STRICT=true
SCRIPTS_BASE_URL=https://gist.githubusercontent.com/pimpsmasterson/9fb9d7c60d3822c2ffd3ad4b000cc864/raw
```

## 📊 API Endpoints

### Public Endpoints
- `GET /api/proxy/health` - Server health check
- `POST /api/proxy/bundles` - Search GPU offers
- `POST /api/proxy/warm-pool/prewarm` - Start GPU instance
- `POST /api/proxy/warm-pool/claim` - Claim running instance

### Generation Endpoints (Image & Video)
- `POST /api/proxy/generate` - Start a generation job (returns `jobId`)
  - Body (JSON):
    - `prompt` (string, required)
    - `workflowType` (`image` | `video`, default `image`)
    - `muse` (object, optional): character data (id, name, attributes)
    - `settings` (object, optional): width, height, steps, cfgScale, sampler, seed, frames, fps, checkpoint
  - Response: `{ jobId, status: 'pending', message, estimatedTime }`

- `GET /api/proxy/generate/:jobId` - Poll job status and retrieve results
  - Response: `{ jobId, status, progress, createdAt, result?: { url, thumbnailUrl, metadata } }`

### Gallery Endpoints
- `GET /api/gallery` - List generated content with filters: `?museId=`, `?status=completed|pending|failed|all`, `?limit=`, `?offset=`
- `GET /api/gallery/content/:id` - Stream the generated image or video by ID (or `job_id`)
- `GET /api/gallery/thumbnail/:id` - Stream thumbnail image for content
- `DELETE /api/gallery/:id` - Delete content (file + DB entry)

Example: Submit an image generation request using curl

```bash
curl -X POST http://localhost:3000/api/proxy/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt":"beautiful warrior","workflowType":"image","settings":{"width":512,"height":768}}'
```

Example: Check job status (replace JOB_ID)

```bash
curl http://localhost:3000/api/proxy/generate/JOB_ID
```

### Admin Endpoints (Require ADMIN_API_KEY)
- `GET /admin/warm-pool` - Admin dashboard
- `POST /api/proxy/admin/set-tokens` - Configure API tokens
- `POST /api/proxy/admin/warm-pool` - Manage warm pool settings

## 🤖 Automated NSFW GPU Setup

The platform features fully automated GPU provisioning for NSFW content generation:

### Model Stack
- **Base Model**: Pony Diffusion V6 XL - Optimized for detailed, stylized adult content
- **LoRAs**: Curated selection of fetish-specific LoRAs (shared clothes, x-ray, cunnilingus, etc.)
- **Video**: AnimateDiff integration for dynamic NSFW animations
- **Workflows**: Pre-built ComfyUI workflows for image and video generation

### Automated Process
1. **Admin Panel**: Click "Prewarm GPU" in the admin dashboard
2. **GPU Rental**: Automatically selects and rents RTX 3070/3080 from Vast.ai
3. **Provisioning**: Downloads models, LoRAs, and installs ComfyUI nodes
4. **Workflow Setup**: Deploys NSFW-optimized generation workflows
5. **Ready State**: GPU is fully configured for fetish content generation

**Note (2026-02-03)**: SSH permission fixes in provisioning scripts have been disabled to prevent hangs during setup. Provisioning should now complete without timeouts.

### Manual Setup (if automated provisioning fails)
If the automated setup doesn't work, you can manually configure the GPU:

1. **SSH into the instance** using the Vast.ai web interface
2. **Run the provisioning script**:
   ```bash
   wget https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw/provision-reliable.sh
   chmod +x fetish-king-nsfw-provision.sh
   ./fetish-king-nsfw-provision.sh
   ```
   **Note**: SSH permission fixes are disabled in the script to prevent hangs. If you encounter permission issues, you may need to manually adjust permissions after provisioning.
3. **Restart ComfyUI** if needed

### Troubleshooting
- **Instance not accessible**: Wait 5-10 minutes for provisioning to complete
- **Provisioning failed**: Check Vast.ai logs or SSH in to debug
- **Models not downloading**: Verify HuggingFace/Civitai tokens are set
- **Provisioning hangs**: SSH permission fixes have been disabled to prevent timeouts. If hangs occur, check the provision script logs for errors.

### Provisioning Options (Vendor Image vs Manual Driver Install)

- **Option A — Vendor CUDA Image (recommended)**: Use a cloud marketplace image labeled with the correct CUDA runtime for your GPU (e.g., "Ubuntu + NVIDIA CUDA 12.x"). This image already contains tested NVIDIA drivers and usually has Docker + container runtimes configured. Fastest and least error-prone.

- **Option B — Manual Driver + NVIDIA Container Toolkit**: Use a clean Ubuntu image and let the provisioner install NVIDIA drivers and `nvidia-container-toolkit`. This offers more control but can require a reboot and may fail on providers that enforce Secure Boot or restrict kernel module installs. To enable this behavior set `INSTALL_NVIDIA_DRIVERS=true` in your environment before running the provisioning script.

If you are unsure, start with Option A. If your provider does not offer a CUDA-enabled image for your chosen GPU, then use Option B.

### Instance Health Recovery

If a warm-pool instance fails to provision correctly (ECONNREFUSED, checkpoint_count: 0):

#### 1. Check Health Status
```bash
# PowerShell
Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool/health" `
  -Headers @{ "x-admin-key" = "YOUR_ADMIN_KEY" }

# curl
curl "http://localhost:3000/api/proxy/admin/warm-pool/health" \
  -H "x-admin-key: YOUR_ADMIN_KEY"
```

#### 2. Check Warm-Pool Status
```bash
curl "http://localhost:3000/api/proxy/admin/warm-pool/status" \
  -H "x-admin-key: YOUR_ADMIN_KEY"
```

#### 3. Force Reprovision with Default Script
If custom provisioning fails, use the reprovision endpoint to terminate and recreate:
```bash
# Use default Vast.ai script (fallback mode)
curl -X POST "http://localhost:3000/api/proxy/admin/warm-pool/reprovision" \
  -H "x-admin-key: YOUR_ADMIN_KEY" \
  -H "Content-Type: application/json" \
  -d '{"useDefaultScript": true}'

# Reset fallback and retry custom script
curl -X POST "http://localhost:3000/api/proxy/admin/warm-pool/reprovision" \
  -H "x-admin-key: YOUR_ADMIN_KEY" \
  -H "Content-Type: application/json" \
  -d '{"resetFallback": true}'
```

#### 4. Manual Instance Inspection (via Vast.ai SSH)
```bash
# Check ComfyUI process
docker ps -a | grep comfy

# Check container logs
docker logs <container_id> --tail 200

# Check disk usage
df -h && du -sh /workspace/ComfyUI/models/*

# Test ComfyUI locally
curl http://localhost:8188/system_stats
```

#### Common Failure Patterns
| Error | Cause | Fix |
|-------|-------|-----|
| `ECONNREFUSED 8188` | ComfyUI not running | Check container logs, restart container |
| `checkpoint_count: 0` | Model downloads failed | Check disk space, rate limits, tokens |
| Health stuck "loading" | Large model downloads | Wait 15+ min, check download progress |
| `no space left on device` | Disk full | Use larger instance (WARM_POOL_DISK_GB) |

### Admin Dashboard Features
- **One-Click GPU Rental**: No manual commands or IDE required
- **Real-Time Status**: Monitor provisioning progress
- **Cost Control**: Automatic shutdown after idle periods
- **Audit Trail**: All actions logged with timestamps
- **Reprovision Button**: Force fallback to default script when custom fails

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Run tests (`npm test`)
4. Commit changes (`git commit -m 'Add amazing feature'`)
5. Push to branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## 📝 License

This project is proprietary software. All rights reserved.

## 🆘 Support

For support or questions:
- Check the [documentation](./docs/)
- Review [test files](./tests/) for usage examples
- Open an issue on GitHub

---

**Built with ❤️ for the adult content creation community**</content>
<parameter name="filePath">README.md