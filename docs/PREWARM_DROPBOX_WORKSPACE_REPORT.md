# Detailed Report: Creating a Pre-Warmed GPU Instance with Full Dropbox Workspace Transfer

## Overview
This report provides a comprehensive guide on provisioning a Vast.ai GPU instance that pre-warms a pool while enabling seamless transfer of the full finished workspace from Dropbox. The process leverages the project's warm-pool orchestration system, which maintains one ready GPU instance for ComfyUI generation jobs, combined with Dropbox integration for reliable model and workspace downloads.

## Key Components
- **Warm-Pool Orchestration**: Managed in `server/warm-pool.js`, handles instance lifecycle, Vast.ai API integration, and health monitoring.
- **Dropbox Integration**: Uses `scripts/dropbox_create_links.js` to generate direct download links, stored in `data/dropbox_links.txt`.
- **Provisioning Script**: Embedded script that downloads models from multiple sources (HuggingFace, Civitai, Dropbox) and sets up ComfyUI.
- **Admin Endpoints**: Available in `server/vastai-proxy.js` for manual control and monitoring.

## Prerequisites
1. **Environment Variables**:
   - `VASTAI_API_KEY`: Your Vast.ai API key.
   - `ADMIN_API_KEY`: For admin endpoint access.
   - `DROPBOX_TOKEN`: Dropbox access token with sharing scopes.
   - `DROPBOX_FOLDER`: Path to your models/workspace folder in Dropbox (e.g., `/YourModels`).
   - Optional: `HUGGINGFACE_HUB_TOKEN`, `CIVITAI_TOKEN` for additional sources.

2. **Dependencies**:
   - Node.js and npm installed.
   - Vast.ai account with sufficient credits.
   - Dropbox app with appropriate permissions.

## Step-by-Step Process

### Phase 1: Preparation
1. **Install Dependencies**:
   Run `npm install` in the project root to ensure all packages are available.

2. **Generate Dropbox Links**:
   Execute the following command to create direct download links for your workspace:
   ```
   DROPBOX_TOKEN=your_token node scripts/dropbox_create_links.js /YourModels
   ```
   This generates `data/dropbox_links.txt` with base64-encoded links for provisioning.

   If the token is set in environment, the server can auto-generate links during prewarm.

3. **Set Environment Variables**:
   Configure your environment:
   ```bash
   $env:VASTAI_API_KEY='your_vastai_key'
   $env:ADMIN_API_KEY='your_admin_key'
   $env:DROPBOX_TOKEN='your_dropbox_token'
   $env:DROPBOX_FOLDER='/YourModels'
   ```

### Phase 2: Instance Creation and Provisioning
4. **Start the Server**:
   Use one of the one-click scripts, e.g., `one-click-start-fixed.ps1`, which starts the server under PM2 and triggers prewarm.

5. **Trigger Prewarm**:
   The system automatically searches for suitable GPU offers via Vast.ai API (`GET /api/v0/bundles/`) with filtering:
   - CUDA ≥6.0, VRAM ≥16GB, Disk ≥500GB.
   - Price ≤$3.00/hr, Reliability ≥95%.
   - Excludes certain regions and GPUs.

   Once an offer is selected, it rents the instance and executes the provisioning script.

6. **Provisioning Execution**:
   The instance runs the embedded provision script, which:
   - Downloads models from HuggingFace (primary), Civitai, and Dropbox (fallback).
   - Uses `aria2c` for parallel downloads with timeouts and speed checks.
   - Sets up ComfyUI with custom nodes and workflows.

   Dropbox links are passed via `PROVISION_DROPBOX_LINKS_B64` environment variable.

7. **Health Validation**:
   The system polls the instance until ComfyUI is ready (up to 15 minutes), checking:
   - ComfyUI API availability.
   - GPU status and VRAM usage (<90%).

### Phase 3: Ready for Generation
8. **Job Orchestration**:
   Submit generation requests via `POST /api/proxy/generate`. The warm instance handles jobs, polling for completion.

## Automation Scripts
- **One-Click Start**: `one-click-start-fixed.ps1` - Starts server and prewarms instance.
- **Admin Endpoints**:
  - `POST /api/proxy/admin/warm-pool/prewarm` - Manual prewarm.
  - `GET /api/proxy/admin/warm-pool/status` - Check status.
  - `POST /api/proxy/admin/warm-pool/reprovision` - Force reprovision.

## Troubleshooting
- **Provisioning Failures**: Check logs in `logs/` or run `npm run inspect-db` for audit trails.
- **Dropbox Issues**: Ensure token has `files.content.read`, `files.metadata.read`, `sharing.write` scopes.
- **Vast.ai Errors**: Verify API key and credits; check for rate limits.
- **Health Checks Failing**: Increase timeouts or check instance connectivity.

## Cost and Optimization
- Instances cost ~$3/hr; prewarming maintains one ready instance.
- Filtering prioritizes cheapest offers while meeting requirements.
- Use `WARM_POOL_DISK_GB` to adjust disk space (default 500GB).

## Conclusion
This process enables reliable, automated GPU provisioning with full Dropbox workspace transfer, ensuring custom models and configurations are available on the instance. For further details, refer to `server/warm-pool.js` and `docs/DROPBOX_INTEGRATION.md`.