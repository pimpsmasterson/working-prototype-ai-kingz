Vast.ai Proxy (server/vastai-proxy.js)

Purpose:
- Provide a same-origin server-side proxy for Vast.ai and ComfyUI operations to avoid browser CORS issues.
- Centralize VAST.ai API key and optional Hugging Face / Civitai tokens for model downloads.

Usage:
1. Install dependencies (from project root):
   npm install express node-fetch@2 cors body-parser

2. Set environment variables (recommended):
   - VASTAI_API_KEY (required for proxying Vast.ai API)
   - HUGGINGFACE_HUB_TOKEN (optional, for automated Hugging Face downloads on instances). Example (PowerShell): `setx HUGGINGFACE_HUB_TOKEN "hf_your_token_here"` or for current session: `$env:HUGGINGFACE_HUB_TOKEN = "hf_your_token_here"`
   - CIVITAI_TOKEN (optional, for programmatic Civitai downloads on instances)

3. Start the proxy locally:
   VASTAI_API_KEY=<your_key> node server/vastai-proxy.js

Endpoints:
- GET  /api/proxy/health            -> Quick health check
- POST /api/proxy/prompt            -> Proxy ComfyUI prompt submissions to Vast.ai
- POST /api/proxy/instances/create -> Create an instance (proxy to Vast.ai)
- GET  /api/proxy/instances/:id     -> Check instance status
- DELETE /api/proxy/instances/:id  -> Stop instance
- GET  /api/proxy/instances        -> List instances
- GET  /api/proxy/check-tokens     -> Check presence of HF/Civitai/Vast.ai tokens on server (returns booleans)
- POST /api/proxy/admin/set-tokens -> (LOCALHOST ONLY) Set `HUGGINGFACE_HUB_TOKEN` and/or `CIVITAI_TOKEN` at runtime for the running proxy process (non-persistent)

Example (from the machine running the proxy):
  curl -X POST http://localhost:3000/api/proxy/admin/set-tokens -H "Content-Type: application/json" -d '{"huggingface":"hf_xxx","civitai":"civ_xxx"}'

Notes:
- The proxy will follow redirects and provides clearer server-side errors back to the UI.
- For fully automated model downloads, set HUGGINGFACE_HUB_TOKEN and CIVITAI_TOKEN on the server.
- For security, run the proxy on a protected server or behind authentication in production.
