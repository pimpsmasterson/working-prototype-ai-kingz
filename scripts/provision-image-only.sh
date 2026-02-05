#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║   👑 AI KINGS COMFYUI - IMAGE PROVISIONER v3.1 (IMAGE-ONLY)                   ║
# ║                                                                               ║
# ║   Purpose: Thin, fast provisioner for image-only generation workloads.
# ║   - Sets conservative disk & resource requirements for image workloads
# ║   - Uses the same robust provisioning machinery as `provision-reliable.sh`
# ║   - Intended to be small & fast for image-focused instances
# ╚═══════════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

# Export overrides tailored for image workloads
export PROVISION_SCRIPT_TYPE="image"
export PROVISION_EXPECTED_SIGNATURE="AI KINGS COMFYUI - IMAGE PROVISIONER v3.1"
# Allow lower disk for image-only workloads (default overridable by env)
export MIN_DISK_GB="${MIN_DISK_GB:-300}"
# Allow GPUs with >= 12GB VRAM to be considered for image workloads
export VASTAI_MIN_GPU_RAM_MB="${VASTAI_MIN_GPU_RAM_MB:-12288}"
# Keep strict pricing by default but allow some flexibility for better offers
export WARM_POOL_MAX_DPH="${WARM_POOL_MAX_DPH:-5.00}"
# Mark for the main provisioner (if it supports targeted selections)
export IMAGE_ONLY=1

logmsg() { echo "$(date '+%H:%M:%S') $*"; }

logmsg "Starting Image-only provisioner (delegates to provision-reliable.sh)"

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

logmsg "Image-only provisioner finished (exit: $?)"
