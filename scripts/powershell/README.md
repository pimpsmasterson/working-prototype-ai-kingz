# PowerShell Scripts (scripts/powershell)

This folder centralizes all PowerShell utilities used by AI KINGS.

## Purpose
- Keep all `.ps1` files in a single location for clarity and easier maintenance.
- Provide wrapper scripts at the repository root for convenience so users can run common tasks without changing directories.

## Recommended usage
- For most users, run the root wrappers (they forward to the canonical scripts):
  - `.	est-extended-video.ps1` (root wrapper)
  - `.	est-civitai.ps1` (root wrapper)
  - `.	est-proxy.ps1` (root wrapper)
  - `start-tunnel.bat` / `.	est-extended-video.ps1` etc.

- If you prefer to execute or edit scripts directly, use the canonical paths:
  - `.	ools\scripts\powershell\start-proxy.ps1` or
  - `.\\scripts\\powershell\\test-extended-video.ps1`

## Files of Interest
- `start-proxy.ps1` - Start the proxy with recommended environment variables
- `start-server.ps1` - Start the Node.js server (wrapper present at repo root)
- `start-tunnel.ps1` - Create an SSH tunnel to a running instance
- `test-extended-video.ps1` - Automated test for extended video workflows
- `export-workflows.ps1` - Export ComfyUI workflows via API
- `rotate-logs.ps1` - Rotate and prune local logs

## Notes
- Root-level wrapper scripts exist to preserve compatibility with existing docs and shortcuts.
- Update this README if you add more entry-point scripts.
