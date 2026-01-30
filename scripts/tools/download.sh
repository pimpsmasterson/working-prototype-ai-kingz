#!/bin/bash
# AI KINGS - Production-Grade Robust Download Tool (tools/download.sh)
# Features: Retry logic, memory monitoring, extended timeouts, better error detection
# Usage: ./download.sh <URL> <TARGET_DIR> <FILENAME> [EXPECTED_SHA256]

set -euo pipefail

URL=$1
DIR=$2
FILENAME=$3
SHA256=${4:-}
FILEPATH="${DIR}/${FILENAME}"

# Configuration
MAX_RETRIES=5
BASE_TIMEOUT=1800  # 30 minutes for large files
RETRY_DELAY=60    # 1 minute between retries
MAX_MEMORY_USAGE=80  # Max % memory usage before throttling
MIN_DISK_SPACE=1073741824  # 1GB minimum free space

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DOWNLOAD] $*" >&2
}

# Memory monitoring function
check_memory_usage() {
    local mem_usage
    mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    echo "$mem_usage"
}

# Disk space check
check_disk_space() {
    local available
    available=$(df "$DIR" | tail -1 | awk '{print $4}')
    echo "$available"
}

# Throttle downloads if memory usage is high
throttle_if_needed() {
    local mem_usage
    mem_usage=$(check_memory_usage)
    if [ "$mem_usage" -gt "$MAX_MEMORY_USAGE" ]; then
        log "⚠️ High memory usage (${mem_usage}%), throttling download..."
        sleep 10
    fi
}

# Enhanced error detection for HTML pages
is_error_page() {
    local file=$1
    local size
    size=$(stat -c%s "$file" 2>/dev/null || echo "0")

    # Check if file is suspiciously small
    if [ "$size" -lt 1000 ]; then
        return 0
    fi

    # Check for common error indicators
    if head -n 10 "$file" 2>/dev/null | grep -qiE "(error|404|403|500|unauthorized|forbidden|not found)"; then
        return 0
    fi

    # Check MIME type
    local mime
    mime=$(file -b --mime-type "$file" 2>/dev/null || echo "unknown")
    if [[ "$mime" == "text/html" ]]; then
        return 0
    fi

    return 1
}

# Validate download completion
validate_download() {
    local file=$1

    if [ ! -f "$file" ]; then
        log "❌ File does not exist: $file"
        return 1
    fi

    if is_error_page "$file"; then
        log "❌ Downloaded file appears to be an error page"
        return 1
    fi

    local size
    size=$(stat -c%s "$file")
    if [ "$size" -lt 100000 ]; then  # Less than 100KB is suspicious
        log "❌ Downloaded file is too small (${size} bytes)"
        return 1
    fi

    if [ -n "$SHA256" ]; then
        local actual_sha
        actual_sha=$(sha256sum "$file" | awk '{print $1}')
        if [ "$actual_sha" != "$SHA256" ]; then
            log "❌ Checksum verification failed"
            log "  Expected: $SHA256"
            log "  Actual:   $actual_sha"
            return 1
        fi
    fi

    return 0
}

# Main download function with retry logic
download_with_retry() {
    local attempt=1
    local timeout=$BASE_TIMEOUT

    mkdir -p "$DIR"

    # Pre-flight checks
    local disk_space
    disk_space=$(check_disk_space)
    if [ "$disk_space" -lt "$MIN_DISK_SPACE" ]; then
        log "❌ Insufficient disk space: $(($disk_space/1024/1024))MB free, need 1GB+"
        return 1
    fi

    while [ $attempt -le $MAX_RETRIES ]; do
        log "⬇️ Download attempt $attempt/$MAX_RETRIES for $FILENAME (timeout: ${timeout}s)"

        throttle_if_needed

        # Clean up any partial downloads
        rm -f "$FILEPATH"

        local success=0

        if command -v aria2c >/dev/null 2>&1; then
            # Use aria2c with memory-conscious settings
            if aria2c -x4 -s4 --max-connection-per-server=2 \
                     --timeout="$timeout" --retry-wait=30 --max-tries=1 \
                     --lowest-speed-limit=1K --max-overall-download-limit=50M \
                     --file-allocation=none \
                     "${HEADERS[@]}" -d "$DIR" -o "$FILENAME" "$URL" 2>/dev/null; then
                success=1
            fi
        else
            # Fallback to wget with conservative settings
            if wget --timeout="$timeout" --tries=1 --retry-connrefused \
                    --limit-rate=10m \
                    "${HEADERS[@]}" -O "$FILEPATH" "$URL" 2>/dev/null; then
                success=1
            fi
        fi

        if [ $success -eq 1 ] && validate_download "$FILEPATH"; then
            local final_size
            final_size=$(stat -c%s "$FILEPATH")
            log "✅ Successfully downloaded $FILENAME ($(numfmt --to=iec-i --suffix=B "$final_size"))"
            return 0
        fi

        attempt=$((attempt + 1))
        if [ $attempt -le $MAX_RETRIES ]; then
            log "❌ Download attempt $((attempt-1)) failed, retrying in ${RETRY_DELAY}s..."
            sleep "$RETRY_DELAY"
            # Increase timeout for next attempt
            timeout=$((timeout + 300))
        fi
    done

    log "❌ All $MAX_RETRIES download attempts failed for $FILENAME"
    return 1
}

# Main execution
main() {
    # Header Management
    declare -a HEADERS
    if [[ "$URL" =~ huggingface\.co ]] && [[ -n "${HUGGINGFACE_HUB_TOKEN:-}" ]]; then
        HEADERS+=(--header="Authorization: Bearer $HUGGINGFACE_HUB_TOKEN")
    fi

    # Token injection for Civitai
    if [[ "$URL" =~ civitai\.com ]] && [[ -n "${CIVITAI_TOKEN:-}" ]]; then
        if [[ "$URL" == *"?"* ]]; then
            URL="${URL}&token=${CIVITAI_TOKEN}"
        else
            URL="${URL}?token=${CIVITAI_TOKEN}"
        fi
    fi

    # Check if file already exists and is valid
    if [[ -f "$FILEPATH" ]]; then
        if validate_download "$FILEPATH"; then
            log "✅ $FILENAME already exists and is valid"
            exit 0
        else
            log "⚠️ Existing $FILENAME is invalid, re-downloading..."
            rm -f "$FILEPATH"
        fi
    fi

    # Attempt download with retry
    if download_with_retry; then
        exit 0
    else
        log "❌ Failed to download $FILENAME after all retries"
        exit 1
    fi
}

main "$@"
