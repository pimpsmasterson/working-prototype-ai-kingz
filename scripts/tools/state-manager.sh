#!/bin/bash
# AI KINGS - State Manager (tools/state-manager.sh)
# Tracks provisioning progress in /workspace/.provision_state.json

STATE_FILE="/workspace/.provision_state.json"

# Initialize state file if missing
if [[ ! -f "$STATE_FILE" ]]; then
    echo '{"completed_modules": [], "last_run": ""}' > "$STATE_FILE"
fi

check_module() {
    local module=$1
    if grep -q "\"$module\"" "$STATE_FILE"; then
        return 0 # Completed
    else
        return 1 # Not started
    fi
}

mark_module_complete() {
    local module=$1
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Simple JSON append (using python to be safe if jq isn't there)
    python3 -c "
import json, sys
data = json.load(open('$STATE_FILE'))
if '$module' not in data['completed_modules']:
    data['completed_modules'].append('$module')
data['last_run'] = '$timestamp'
with open('$STATE_FILE', 'w') as f:
    json.dump(data, f, indent=2)
"
}

get_log_path() {
    local module=$1
    echo "/workspace/logs/provision_${module}.log"
}
