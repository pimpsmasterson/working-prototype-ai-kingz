#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║   👑 AI KINGS COMFYUI - VIDEO PROVISIONER v3.1 (VIDEO-ONLY)                   ║
# ║                                                                               ║
# ║   Purpose: Provisioner optimized for video generation workflows.
# ║   - Larger disk & longer timeouts for big video models and caches
# ║   - Passes video-specific env flags to the reliable provisioner
# ╚═══════════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

# Export overrides tailored for video workloads
export PROVISION_SCRIPT_TYPE="video"
export PROVISION_EXPECTED_SIGNATURE="AI KINGS COMFYUI - VIDEO PROVISIONER v3.1"
# Require larger disk for video workflows (default overridable by env)
export MIN_DISK_GB="${MIN_DISK_GB:-800}"
# Prefer larger GPUs for video (recommend >= 24GB total)
export VASTAI_MIN_GPU_RAM_MB="${VASTAI_MIN_GPU_RAM_MB:-24576}"
# Allow a higher max hourly cost for video workloads (tunable)
export WARM_POOL_MAX_DPH="${WARM_POOL_MAX_DPH:-8.00}"
# Mark for the main provisioner (if it supports targeted selections)
export VIDEO_ONLY=1

logmsg() { echo "$(date '+%H:%M:%S') $*"; }

logmsg "Starting Video-only provisioner (delegates to provision-reliable.sh)"

# Prefer local copy if present; otherwise download the canonical reliable provisioner and run it.
SCRIPTS_DIR="${SCRIPTS_DIR:-./scripts}"
if [[ -f "$SCRIPTS_DIR/provision-reliable.sh" ]]; then
  bash "$SCRIPTS_DIR/provision-reliable.sh" "$@"
else
  logmsg "No local provision-reliable.sh found; downloading canonical script and executing"
  TMP=$(mktemp -d)
  curl -fsSL "https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw/provision-reliable.sh" -o "$TMP/provision-reliable.sh"
  bash "$TMP/provision-reliable.sh" "$@"
fi

logmsg "Video-only provisioner finished (exit: $?)"
