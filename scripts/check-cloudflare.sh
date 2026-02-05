#!/usr/bin/env bash
# scripts/check-cloudflare.sh - lightweight helper to validate cloudflared and tunnel setup
# Exit codes:
# 0 - OK
# 2..8 - various checks failed

set -euo pipefail

# Prefer explicit WORKSPACE if provided; otherwise, use current working dir (portable across Windows/Linux)
WORKSPACE="${WORKSPACE:-${PWD:-/workspace}}"
# Detect cloudflared binary: prefer /usr/local/bin, then PATH, then scripts/bin (Windows-friendly)
CLOUDFLARED_BIN="/usr/local/bin/cloudflared"
if [[ ! -x "$CLOUDFLARED_BIN" ]]; then
  CLOUDFLARED_BIN="$(command -v cloudflared 2>/dev/null || true)"
fi
# Fallback to repo-local copy for Windows users
if [[ -z "$CLOUDFLARED_BIN" || ! -x "$CLOUDFLARED_BIN" ]]; then
  if [[ -x "${PWD}/scripts/bin/cloudflared" ]]; then
    CLOUDFLARED_BIN="${PWD}/scripts/bin/cloudflared"
  elif [[ -x "${PWD}/scripts/bin/cloudflared.exe" ]]; then
    CLOUDFLARED_BIN="${PWD}/scripts/bin/cloudflared.exe"
  fi
fi

# Provide a list of candidate log paths to support different environments (WORKSPACE may be /workspace on Linux or repo root on Windows)
TUNNEL_LOG_CANDIDATES=("${WORKSPACE}/cloudflared.log" "${PWD}/cloudflared.log" "./cloudflared.log")
# Resolve the first existing candidate into TUNNEL_LOG; leave empty if none exist
TUNNEL_LOG=""
for candidate in "${TUNNEL_LOG_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    TUNNEL_LOG="$candidate"
    break
  fi
done

# If TUNNEL_LOG not found yet, we'll still check candidates later and provide a helpful message


# Simple health check helper
# 1) cloudflared binary presence and version
# 2) DISABLE_CLOUDFLARED detection
# 3) Named tunnel credential and tunnel list check
# 4) Quick Tunnel log inspection for trycloudflare URL and reachability


echo "🔍 Cloudflare Tunnel health check"

# 1) Binary
if [[ ! -x "$CLOUDFLARED_BIN" ]]; then
  echo "❌ cloudflared not found at $CLOUDFLARED_BIN"
  echo "   Install with the provisioner or from: https://github.com/cloudflare/cloudflared/releases"
  exit 2
fi

# Safely capture version (quotes handle paths with spaces, e.g., Windows paths via WSL)
cf_version=$("$CLOUDFLARED_BIN" --version 2>/dev/null | head -n1 || true)
if [[ -n "$cf_version" ]]; then
  echo "✅ cloudflared: $cf_version"
else
  echo "✅ cloudflared present (version unknown)"
fi

# 2) Disabled flag
if [[ "${DISABLE_CLOUDFLARED:-0}" == "1" ]]; then
  echo "⚠️ DISABLE_CLOUDFLARED=1 - tunneling is disabled"
  exit 3
fi

# 3) Named tunnel checks
if [[ -n "${CLOUDFLARED_TUNNEL_NAME:-}" ]]; then
  echo "ℹ️ Named tunnel requested: $CLOUDFLARED_TUNNEL_NAME"
  if [[ -z "${CLOUDFLARED_CRED_FILE:-}" || ! -f "$CLOUDFLARED_CRED_FILE" ]]; then
    echo "❌ CLOUDFLARED_CRED_FILE missing or unreadable: ${CLOUDFLARED_CRED_FILE:-<not set>}"
    exit 4
  fi

  # Best-effort check using cloudflared tunnel list
  if "$CLOUDFLARED_BIN" tunnel list 2>/dev/null | grep -q "$CLOUDFLARED_TUNNEL_NAME"; then
    echo "✅ Named tunnel exists in 'cloudflared tunnel list'"
    exit 0
  else
    echo "⚠️ Named tunnel not found in 'cloudflared tunnel list'"
    echo "   Ensure you created the tunnel and provided the correct credentials file"
    exit 5
  fi
fi

# 4) Quick Tunnel inspection
# If TUNNEL_LOG was already resolved at top, use it; otherwise find the first existing candidate
if [[ -z "$TUNNEL_LOG" ]]; then
  for candidate in "${TUNNEL_LOG_CANDIDATES[@]}"; do
    if [[ -f "$candidate" ]]; then
      TUNNEL_LOG="$candidate"
      break
    fi
  done
fi

if [[ -n "$TUNNEL_LOG" && -f "$TUNNEL_LOG" ]]; then
  echo "ℹ️ Using tunnel log: $TUNNEL_LOG"
  # Normalize line endings and join lines to handle wrapped URLs in the output, then search for trycloudflare URL
  TUNNEL_URL=$(tr -d '\r' < "$TUNNEL_LOG" | tr '\n' ' ' | grep -oE 'https://[a-z0-9-]+\\.trycloudflare\\.com' 2>/dev/null | head -1 || true)
  if [[ -n "$TUNNEL_URL" ]]; then
    echo "✅ Found tunnel URL in log: $TUNNEL_URL"
    echo "ℹ️ Testing reachability..."
    if curl -s --connect-timeout 5 "${TUNNEL_URL}/system_stats" >/dev/null 2>&1; then
      echo "✅ Tunnel reachable: ${TUNNEL_URL}"
      exit 0
    else
      echo "⚠️ Tunnel URL not reachable yet: ${TUNNEL_URL}"
      exit 6
    fi
  else
    echo "⚠️ No trycloudflare URL found in $TUNNEL_LOG"
    # Also check for rate limit or errors
    if tr -d '\r' < "$TUNNEL_LOG" | grep -qE '429|Too Many Requests|error code: 1015' 2>/dev/null; then
      echo "⚠️ Cloudflared logs indicate rate limiting (429) - Quick Tunnel may be rate-limited"
      exit 7
    fi
    echo "   Start the tunnel and re-run this script to capture the URL"
    exit 8
  fi
else
  echo "⚠️ No tunnel log found in any of: ${TUNNEL_LOG_CANDIDATES[*]}"
  echo "   Start provisioning or run start_cloudflare_tunnel() then re-run this helper"
  exit 8
fi

