#!/bin/bash
# sync-dropbox.sh - Video Sync Helper for AI KINGS
# This script manages rclone sync between ComfyUI output and Dropbox.

# Configuration
SOURCE_DIR="/workspace/ComfyUI/output"
REMOTE_NAME="dropbox_remote"
REMOTE_DIR="video-gen-output"
LOG_FILE="/workspace/dropbox_sync.log"

# Check if rclone is configured
if ! rclone listremotes | grep -q "$REMOTE_NAME"; then
    echo "$(date): ERROR - rclone remote '$REMOTE_NAME' not found. Provisioning likely failed to set it up." >> "$LOG_FILE"
    exit 1
fi

# Ensure source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "$(date): WARNING - Source directory $SOURCE_DIR does not exist. No sync performed." >> "$LOG_FILE"
    exit 0
fi

echo "$(date): Starting sync: $SOURCE_DIR -> $REMOTE_NAME:$REMOTE_DIR" >> "$LOG_FILE"

# Run rclone sync
# --links: copy symlinks as the file they point to
# --transfers: number of file transfers to run in parallel
# --checkers: number of checkers to run in parallel
# --progress: show progress in logs
rclone sync "$SOURCE_DIR" "$REMOTE_NAME:$REMOTE_DIR" \
    --links \
    --transfers 4 \
    --checkers 8 \
    --log-file "$LOG_FILE" \
    --log-level INFO

if [ $? -eq 0 ]; then
    echo "$(date): Sync completed successfully." >> "$LOG_FILE"
else
    echo "$(date): Sync failed. Check $LOG_FILE for details." >> "$LOG_FILE"
fi
