# 🤖 AI KINGS - AI-Powered Adult Content Generation Platform

[![Tests](https://github.com/YOUR_USERNAME/ai-kings/workflows/Tests/badge.svg)](https://github.com/YOUR_USERNAME/ai-kings/actions)
[![Coverage](https://img.shields.io/badge/coverage-89.64%25_statements_75.62%25_branches-brightgreen)](https://github.com/YOUR_USERNAME/ai-kings)

**fetishking.com** - Professional AI-powered platform for creating custom adult content with advanced character systems and cloud GPU management.

## ✨ Features

### 🎨 **Advanced Character Creation (Muse System)**
- **39+ customization options** - Build detailed characters with physical attributes, personality, and style
- **Reference image support** - Upload photos for AI consistency using IP-Adapter technology
- **Character variations** - Same character, different outfits/scenarios
- **Generation history** - Track all creations per character

### 🚀 **Cloud GPU Management (Warm Pool)**
- **Automatic GPU rental** from Vast.ai marketplace
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
git clone https://github.com/YOUR_USERNAME/ai-kings.git
cd ai-kings

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

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Proxy Server  │    │   Vast.ai API   │
│   (HTML/CSS/JS) │◄──►│   (Express.js)  │◄──►│   (Cloud GPUs)  │
│                 │    │                 │    │                 │
│ • Studio UI     │    │ • API proxying  │    │ • GPU rental    │
│ • Muse manager  │    │ • Auth & audit  │    │ • Instance mgmt │
│ • Gallery       │    │ • Error handling│    │ • ComfyUI       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                ▲
                                │
                    ┌─────────────────┐
                    │   Database      │
                    │   (SQLite)      │
                    │                 │
                    │ • Warm pool     │
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
- **Statements**: 89.64%
- **Branches**: 75.62%
- **Functions**: 92.72%
- **Lines**: 91.74%

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
```

## 📊 API Endpoints

### Public Endpoints
- `GET /api/proxy/health` - Server health check
- `POST /api/proxy/bundles` - Search GPU offers
- `POST /api/proxy/warm-pool/prewarm` - Start GPU instance
- `POST /api/proxy/warm-pool/claim` - Claim running instance

### Admin Endpoints (Require ADMIN_API_KEY)
- `GET /admin/warm-pool` - Admin dashboard
- `POST /api/proxy/admin/set-tokens` - Configure API tokens
- `POST /api/proxy/admin/warm-pool` - Manage warm pool settings

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