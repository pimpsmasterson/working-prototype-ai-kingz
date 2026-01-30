#!/bin/bash
# AI KINGS - Production-Grade Master Provisioning Orchestrator
# Features: Comprehensive error handling, timeouts, resource monitoring, circuit breaker

set -uo pipefail  # Exit on error, undefined vars, pipe failures

# --- CONFIGURATION ---
WORKSPACE="/workspace"
GIT_ROOT="/workspace/aikings-scripts"
SCRIPTS_ROOT="/workspace/scripts"
LOG_FILE="/workspace/scripts/master-provision.log"
TIMEOUT_MINUTES=45  # Increased timeout for heavy operations
MAX_CONSECUTIVE_FAILURES=3
CIRCUIT_BREAKER_FILE="/workspace/.circuit_breaker"

# Resource thresholds
MIN_DISK_SPACE_GB=50
MIN_MEMORY_MB=4096
MAX_CPU_USAGE=90
MAX_MEMORY_USAGE=90

# Initialize logging
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

# Global state
declare -i CONSECUTIVE_FAILURES=0
declare -a FAILED_MODULES=()

# Enhanced logging with levels
log() {
    local level=${2:-INFO}
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $1"
}

error_log() {
    log "$1" "ERROR"
}

warn_log() {
    log "$1" "WARN"
}

# Circuit breaker pattern
check_circuit_breaker() {
    if [[ -f "$CIRCUIT_BREAKER_FILE" ]]; then
        local last_failure
        last_failure=$(stat -c %Y "$CIRCUIT_BREAKER_FILE" 2>/dev/null || echo "0")
        local now
        now=$(date +%s)
        local cooldown_period=300  # 5 minutes

        if (( now - last_failure < cooldown_period )); then
            error_log "Circuit breaker active. Too many recent failures. Waiting..."
            return 1
        else
            rm -f "$CIRCUIT_BREAKER_FILE"
        fi
    fi
    return 0
}

activate_circuit_breaker() {
    touch "$CIRCUIT_BREAKER_FILE"
    error_log "Circuit breaker activated due to excessive failures"
}

# Resource monitoring functions
check_system_resources() {
    log "🔍 Performing system resource checks..."

    # Check disk space
    local free_space_gb
    free_space_gb=$(df -BG "$WORKSPACE" | tail -1 | awk '{print int($4)}')
    if (( free_space_gb < MIN_DISK_SPACE_GB )); then
        error_log "Insufficient disk space: ${free_space_gb}GB free, need ${MIN_DISK_SPACE_GB}GB+"
        return 1
    fi
    log "✅ Disk space: ${free_space_gb}GB free"

    # Check memory
    local total_mem_mb
    total_mem_mb=$(free -m | grep '^Mem:' | awk '{print $2}')
    if (( total_mem_mb < MIN_MEMORY_MB )); then
        warn_log "Low total memory: ${total_mem_mb}MB (minimum ${MIN_MEMORY_MB}MB recommended)"
    fi

    local avail_mem_mb
    avail_mem_mb=$(free -m | grep '^Mem:' | awk '{print $7}')
    local mem_usage_percent
    mem_usage_percent=$(( 100 - (avail_mem_mb * 100 / total_mem_mb) ))
    log "✅ Memory: ${avail_mem_mb}MB available (${mem_usage_percent}% used)"

    if (( mem_usage_percent > MAX_MEMORY_USAGE )); then
        warn_log "High memory usage detected: ${mem_usage_percent}%"
    fi

    # Check CPU usage
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' | xargs printf "%.0f")
    log "✅ CPU usage: ${cpu_usage}%"

    if (( cpu_usage > MAX_CPU_USAGE )); then
        warn_log "High CPU usage detected: ${cpu_usage}%"
    fi

    return 0
}

# Background resource monitor
start_resource_monitor() {
    local monitor_pid
    (
        while true; do
            local mem_usage
            mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
            local cpu_usage
            cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' | xargs printf "%.0f")

            if (( mem_usage > 95 || cpu_usage > 95 )); then
                warn_log "CRITICAL: Memory ${mem_usage}%, CPU ${cpu_usage}% - System under extreme load"
            fi

            sleep 30
        done
    ) &
    monitor_pid=$!
    log "Started resource monitor (PID: $monitor_pid)"
    echo "$monitor_pid" > "/tmp/resource_monitor.pid"
}

stop_resource_monitor() {
    if [[ -f "/tmp/resource_monitor.pid" ]]; then
        local pid
        pid=$(cat "/tmp/resource_monitor.pid")
        kill "$pid" 2>/dev/null || true
        rm -f "/tmp/resource_monitor.pid"
        log "Stopped resource monitor"
    fi
}

# Enhanced module runner with timeout and error handling
run_module_with_protection() {
    local module_path=$1
    local module_name
    module_name=$(basename "$module_path" .sh)

    log "▶️ Starting module: $module_name"

    # Pre-module resource check
    if ! check_system_resources; then
        error_log "System resource check failed before $module_name"
        return 1
    fi

    # Run with timeout and comprehensive error handling
    local start_time
    start_time=$(date +%s)
    local exit_code=0

    # Use timeout with cleanup
    timeout "${TIMEOUT_MINUTES}m" bash "$module_path" || exit_code=$?

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if (( exit_code == 124 )); then
        error_log "Module $module_name timed out after ${TIMEOUT_MINUTES} minutes"
        CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
        FAILED_MODULES+=("$module_name (timeout)")
        return 1
    elif (( exit_code != 0 )); then
        error_log "Module $module_name failed with exit code $exit_code (duration: ${duration}s)"
        CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
        FAILED_MODULES+=("$module_name (exit code $exit_code)")
        return 1
    else
        log "✅ Module $module_name completed successfully in ${duration}s"
        CONSECUTIVE_FAILURES=0  # Reset on success
        return 0
    fi
}

# Graceful error recovery
handle_module_failure() {
    local module_name=$1

    if (( CONSECUTIVE_FAILURES >= MAX_CONSECUTIVE_FAILURES )); then
        error_log "Too many consecutive failures ($CONSECUTIVE_FAILURES). Activating circuit breaker."
        activate_circuit_breaker
        return 1
    fi

    warn_log "Module $module_name failed. Continuing with remaining modules..."
    return 0
}

# Enhanced ComfyUI startup with health checks
start_comfyui_production() {
    log "🚀 Starting ComfyUI with production safeguards..."

    if [[ ! -d "$WORKSPACE/ComfyUI" ]]; then
        error_log "ComfyUI directory not found at $WORKSPACE/ComfyUI"
        return 1
    fi

    cd "$WORKSPACE/ComfyUI" || {
        error_log "Cannot change to ComfyUI directory"
        return 1
    }

    if [[ ! -f "main.py" ]]; then
        error_log "main.py not found in ComfyUI directory"
        return 1
    fi

    # Activate appropriate virtual environment
    if [[ -f "/venv/main/bin/activate" ]]; then
        source "/venv/main/bin/activate"
        log "Activated conda/uv virtual environment"
    elif [[ -f "/workspace/venv/bin/activate" ]]; then
        source "/workspace/venv/bin/activate"
        log "Activated local virtual environment"
    else
        warn_log "No virtual environment found - using system Python"
    fi

    # Pre-start resource check
    if ! check_system_resources; then
        error_log "System resource check failed - aborting ComfyUI start"
        return 1
    fi

    # Start ComfyUI with proper monitoring
    log "Starting ComfyUI process..."
    nohup python main.py --listen 0.0.0.0 --disable-auto-launch --port 8188 --enable-cors-header \
        > "$WORKSPACE/comfyui.log" 2>&1 &
    local comfyui_pid=$!

    log "ComfyUI started (PID: $comfyui_pid) — logs: $WORKSPACE/comfyui.log"

    # Health check with timeout
    local health_check_attempts=0
    local max_health_checks=30  # 5 minutes

    while (( health_check_attempts < max_health_checks )); do
        sleep 10
        health_check_attempts=$((health_check_attempts + 1))

        # Check if process is still running
        if ! kill -0 "$comfyui_pid" 2>/dev/null; then
            error_log "ComfyUI process died during startup"
            return 1
        fi

        # Try health check endpoint
        if curl -f -m 5 http://127.0.0.1:8188/system_stats >/dev/null 2>&1; then
            log "✅ ComfyUI health check passed - service is ready"
            return 0
        fi

        log "Waiting for ComfyUI to become ready... (${health_check_attempts}/${max_health_checks})"
    done

    error_log "ComfyUI failed to become ready within timeout"
    return 1
}

# Cleanup function
cleanup() {
    local exit_code=$?
    stop_resource_monitor

    if (( exit_code != 0 )); then
        error_log "Provisioning completed with errors (exit code: $exit_code)"
        if (( ${#FAILED_MODULES[@]} > 0 )); then
            error_log "Failed modules: ${FAILED_MODULES[*]}"
        fi
    else
        log "🎉 Provisioning completed successfully!"
    fi

    log "--- Provisioning ended at $(date) ---"
}

# Main execution
main() {
    trap cleanup EXIT

    log "--- Provisioning started at $(date) ---"

    # Circuit breaker check
    if ! check_circuit_breaker; then
        exit 1
    fi

    # Initial system checks
    if ! check_system_resources; then
        error_log "Initial system resource check failed"
        exit 1
    fi

    # Start background monitoring
    start_resource_monitor

    # Source state manager
    source "${SCRIPTS_ROOT}/tools/state-manager.sh"

    # Module execution pipeline
    local modules=(
        "${SCRIPTS_ROOT}/modules/01-system-deps.sh"
        "${SCRIPTS_ROOT}/modules/02-custom-nodes.sh"
        "${SCRIPTS_ROOT}/modules/03-models-core.sh"
        "${SCRIPTS_ROOT}/modules/04-models-wan.sh"
        "${SCRIPTS_ROOT}/modules/05-workflows.sh"
    )

    for module in "${modules[@]}"; do
        if run_module_with_protection "$module"; then
            log "Module pipeline continuing..."
        else
            if ! handle_module_failure "$(basename "$module" .sh)"; then
                break
            fi
        fi
    done

    # Final ComfyUI startup
    if (( ${#FAILED_MODULES[@]} == 0 )); then
        start_comfyui_production
    else
        warn_log "Skipping ComfyUI startup due to module failures: ${FAILED_MODULES[*]}"
    fi

    # Final status report
    if (( ${#FAILED_MODULES[@]} > 0 )); then
        warn_log "Provisioning completed with ${#FAILED_MODULES[@]} failed modules"
        exit 1
    else
        log "All systems operational"
        exit 0
    fi
}

main "$@"
