#!/bin/bash
# AI KINGS - Robust Download Tool (tools/download.sh)
# Usage: ./download.sh <URL> <TARGET_DIR> <FILENAME> [EXPECTED_SHA256]

URL=$1
DIR=$2
FILENAME=$3
SHA256=$4
FILEPATH="${DIR}/${FILENAME}"

mkdir -p "$DIR"

# Header Management
HEADERS=()
if [[ "$URL" =~ huggingface\.co ]] && [[ -n "$HUGGINGFACE_HUB_TOKEN" ]]; then
    HEADERS+=(--header="Authorization: Bearer $HUGGINGFACE_HUB_TOKEN")
fi

# Token injection for Civitai
if [[ "$URL" =~ civitai\.com ]] && [[ -n "$CIVITAI_TOKEN" ]]; then
    if [[ "$URL" == *"?"* ]]; then
        URL="${URL}&token=${CIVITAI_TOKEN}"
    else
        URL="${URL}?token=${CIVITAI_TOKEN}"
    fi
fi

# Check existing file
if [[ -f "$FILEPATH" ]]; then
    SIZE=$(stat -c%s "$FILEPATH")
    MIME=$(file -b --mime-type "$FILEPATH")
    
    # If file is valid size and not an HTML error page, verify checksum or skip
    if [[ $SIZE -gt 100000 && "$MIME" != "text/html" ]]; then
        if [[ -n "$SHA256" ]]; then
            ACTUAL_SHA=$(sha256sum "$FILEPATH" | awk '{print $1}')
            if [[ "$ACTUAL_SHA" == "$SHA256" ]]; then
                echo "✅ $FILENAME already exists and matches checksum."
                exit 0
            else
                echo "⚠️ Checksum mismatch for $FILENAME. Redownloading..."
                rm -f "$FILEPATH"
            fi
        else
            echo "✅ $FILENAME exists (skipped checksum verification)."
            exit 0
        fi
    else
        echo "⚠️ $FILENAME is corrupt or HTML error page. Removing..."
        rm -f "$FILEPATH"
    fi
fi

# Download logic
echo "⬇️ Downloading $FILENAME..."

if command -v aria2c >/dev/null 2>&1; then
    # Use aria2c for multi-segment download
    aria2c -x16 -s16 --max-connection-per-server=8 \
           --timeout=300 --retry-wait=10 --continue=true \
           "${HEADERS[@]}" -d "$DIR" -o "$FILENAME" "$URL"
else
    # Fallback to wget
    wget -c --show-progress --progress=bar:force:noscroll \
         --timeout=300 --tries=5 --retry-connrefused \
         "${HEADERS[@]}" -O "$FILEPATH" "$URL"
fi

# Post-download Validation
if [[ -f "$FILEPATH" ]]; then
    FINAL_SIZE=$(stat -c%s "$FILEPATH")
    MIME_TYPE=$(file -b --mime-type "$FILEPATH")
    
    if [[ $FINAL_SIZE -lt 100000 || "$MIME_TYPE" == "text/html" ]]; then
        echo "❌ Download failed: $FILENAME is too small or an HTML error page."
        rm -f "$FILEPATH"
        exit 1
    fi
    
    if [[ -n "$SHA256" ]]; then
        FINAL_SHA=$(sha256sum "$FILEPATH" | awk '{print $1}')
        if [[ "$FINAL_SHA" != "$SHA256" ]]; then
            echo "❌ Checksum verification failed for $FILENAME!"
            rm -f "$FILEPATH"
            exit 1
        fi
    fi
    
    echo "✅ Successfully downloaded $FILENAME ($(($FINAL_SIZE/1024/1024)) MB)"
else
    echo "❌ Execution failed: $FILENAME was not created."
    exit 1
fi
