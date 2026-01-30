#!/bin/bash
# AI KINGS - Production-Grade State Manager (tools/state-manager.sh)
# Features: File locking, JSON validation, backup/restore, concurrent access safety

set -uo pipefail

STATE_FILE="/workspace/.provision_state.json"
BACKUP_FILE="/workspace/.provision_state.backup"
LOCK_FILE="/workspace/.provision_state.lock"
MAX_LOCK_WAIT=30  # seconds

# Logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [STATE-MGR] $*" >&2
}

# File locking mechanism
acquire_lock() {
    local wait_time=0
    while [[ -f "$LOCK_FILE" ]]; do
        if (( wait_time >= MAX_LOCK_WAIT )); then
            log "ERROR: Could not acquire lock after ${MAX_LOCK_WAIT}s"
            return 1
        fi
        sleep 1
        wait_time=$((wait_time + 1))
    done

    # Create lock file with PID
    echo "$$" > "$LOCK_FILE"
    log "Lock acquired (PID: $$)"
    return 0
}

release_lock() {
    if [[ -f "$LOCK_FILE" ]] && [[ "$(cat "$LOCK_FILE")" == "$$" ]]; then
        rm -f "$LOCK_FILE"
        log "Lock released"
    fi
}

# JSON validation and manipulation
validate_json() {
    local file=$1
    if [[ ! -f "$file" ]]; then
        return 1
    fi

    # Use python for robust JSON validation
    if python3 -c "import json, sys; json.load(open('$file')); sys.exit(0)" 2>/dev/null; then
        return 0
    else
        log "ERROR: Invalid JSON in $file"
        return 1
    fi
}

# Backup state file
backup_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cp "$STATE_FILE" "$BACKUP_FILE" 2>/dev/null || {
            log "WARNING: Could not create backup"
        }
    fi
}

# Restore from backup
restore_backup() {
    if [[ -f "$BACKUP_FILE" ]] && validate_json "$BACKUP_FILE"; then
        cp "$BACKUP_FILE" "$STATE_FILE" 2>/dev/null && {
            log "Restored state from backup"
            return 0
        }
    fi
    return 1
}

# Initialize state file safely
initialize_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        log "Initializing state file..."
        local initial_state='{
            "completed_modules": [],
            "failed_modules": [],
            "last_run": "",
            "version": "2.0",
            "metadata": {
                "created_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
                "hostname": "'$(hostname)'"
            }
        }'

        echo "$initial_state" > "$STATE_FILE"
        if validate_json "$STATE_FILE"; then
            log "State file initialized successfully"
        else
            log "ERROR: Failed to initialize state file"
            return 1
        fi
    fi
    return 0
}

# Safe JSON update with locking
update_state_safe() {
    local operation=$1
    local module=${2:-}

    if ! acquire_lock; then
        log "ERROR: Could not acquire lock for state update"
        return 1
    fi

    # Ensure cleanup on exit
    trap 'release_lock' EXIT

    backup_state

    case "$operation" in
        "check")
            check_module "$module"
            ;;
        "mark_complete")
            mark_module_complete "$module"
            ;;
        "mark_failed")
            mark_module_failed "$module"
            ;;
        "reset")
            reset_module "$module"
            ;;
        *)
            log "ERROR: Unknown operation: $operation"
            return 1
            ;;
    esac

    release_lock
    trap - EXIT
}

check_module() {
    local module=$1

    if ! validate_json "$STATE_FILE"; then
        log "ERROR: State file corrupted, attempting restore..."
        if ! restore_backup; then
            log "ERROR: Could not restore state file"
            return 1
        fi
    fi

    # Use jq if available, fallback to python
    if command -v jq >/dev/null 2>&1; then
        if jq -e ".completed_modules[]? | select(. == \"$module\")" "$STATE_FILE" >/dev/null 2>&1; then
            return 0  # Completed
        fi
    else
        # Python fallback
        if python3 -c "
import json, sys
try:
    data = json.load(open('$STATE_FILE'))
    if '$module' in data.get('completed_modules', []):
        sys.exit(0)
    else:
        sys.exit(1)
except:
    sys.exit(1)
" 2>/dev/null; then
            return 0  # Completed
        fi
    fi

    return 1  # Not completed
}

mark_module_complete() {
    local module=$1
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    log "Marking module $module as completed"

    # Use jq if available for atomic updates
    if command -v jq >/dev/null 2>&1; then
        if jq --arg module "$module" --arg timestamp "$timestamp" \
            '.completed_modules |= (. + [$module] | unique) | .last_run = $timestamp | del(.failed_modules[]? | select(. == $module))' \
            "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null; then
            mv "${STATE_FILE}.tmp" "$STATE_FILE"
            return 0
        fi
    fi

    # Python fallback
    python3 -c "
import json, sys
try:
    data = json.load(open('$STATE_FILE'))
    if '$module' not in data.get('completed_modules', []):
        data.setdefault('completed_modules', []).append('$module')
    data['last_run'] = '$timestamp'
    # Remove from failed if present
    if 'failed_modules' in data and '$module' in data['failed_modules']:
        data['failed_modules'].remove('$module')
    with open('$STATE_FILE', 'w') as f:
        json.dump(data, f, indent=2)
    print('Module $module marked complete')
except Exception as e:
    print(f'Error updating state: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null && return 0

    log "ERROR: Failed to mark module $module as complete"
    return 1
}

mark_module_failed() {
    local module=$1
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    log "Marking module $module as failed"

    if command -v jq >/dev/null 2>&1; then
        jq --arg module "$module" --arg timestamp "$timestamp" \
            '.failed_modules |= (. + [$module] | unique) | .last_run = $timestamp | del(.completed_modules[]? | select(. == $module))' \
            "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null && \
        mv "${STATE_FILE}.tmp" "$STATE_FILE" && return 0
    fi

    # Python fallback
    python3 -c "
import json, sys
try:
    data = json.load(open('$STATE_FILE'))
    if '$module' not in data.get('failed_modules', []):
        data.setdefault('failed_modules', []).append('$module')
    data['last_run'] = '$timestamp'
    # Remove from completed if present
    if 'completed_modules' in data and '$module' in data['completed_modules']:
        data['completed_modules'].remove('$module')
    with open('$STATE_FILE', 'w') as f:
        json.dump(data, f, indent=2)
    print('Module $module marked failed')
except Exception as e:
    print(f'Error updating state: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null && return 0

    log "ERROR: Failed to mark module $module as failed"
    return 1
}

reset_module() {
    local module=$1

    log "Resetting module $module"

    if command -v jq >/dev/null 2>&1; then
        jq --arg module "$module" \
            'del(.completed_modules[]? | select(. == $module)) | del(.failed_modules[]? | select(. == $module))' \
            "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null && \
        mv "${STATE_FILE}.tmp" "$STATE_FILE" && return 0
    fi

    # Python fallback
    python3 -c "
import json, sys
try:
    data = json.load(open('$STATE_FILE'))
    if 'completed_modules' in data and '$module' in data['completed_modules']:
        data['completed_modules'].remove('$module')
    if 'failed_modules' in data and '$module' in data['failed_modules']:
        data['failed_modules'].remove('$module')
    with open('$STATE_FILE', 'w') as f:
        json.dump(data, f, indent=2)
    print('Module $module reset')
except Exception as e:
    print(f'Error resetting module: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null && return 0

    log "ERROR: Failed to reset module $module"
    return 1
}

get_log_path() {
    local module=$1
    echo "/workspace/logs/provision_${module}.log"
}

# Initialize on first load
if ! initialize_state; then
    log "ERROR: Could not initialize state manager"
    exit 1
fi
