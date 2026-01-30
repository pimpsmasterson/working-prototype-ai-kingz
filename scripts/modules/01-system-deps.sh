#!/bin/bash
# AI KINGS - Module 01: System Dependencies (Production-Grade)
# Features: Package validation, network checks, configurable packages, error recovery

set -uo pipefail
source /workspace/scripts/tools/state-manager.sh

MODULE_NAME="system-deps"

if check_module "$MODULE_NAME"; then
    echo "✅ Module $MODULE_NAME already completed. Skipping."
    exit 0
fi

# Configuration
APT_UPDATE_TIMEOUT=300  # 5 minutes
PACKAGE_INSTALL_TIMEOUT=600  # 10 minutes
MAX_NETWORK_RETRIES=3
NETWORK_TIMEOUT=30

# Logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SYSTEM-DEPS] $*" >&2
}

error_log() {
    log "$1" "ERROR"
}

warn_log() {
    log "$1" "WARN"
}

# Network connectivity check
check_network() {
    log "🔍 Checking network connectivity..."

    local test_urls=("http://archive.ubuntu.com" "http://security.ubuntu.com" "https://pypi.org")
    local connected=false

    for url in "${test_urls[@]}"; do
        if curl -f --max-time "$NETWORK_TIMEOUT" --silent "$url" >/dev/null 2>&1; then
            log "✅ Network connectivity confirmed via $url"
            connected=true
            break
        fi
    done

    if [[ "$connected" != true ]]; then
        error_log "No network connectivity detected"
        return 1
    fi

    return 0
}

# Safe APT update with retry
apt_update_safe() {
    log "📦 Updating APT package lists..."

    local attempt=1
    while (( attempt <= MAX_NETWORK_RETRIES )); do
        log "APT update attempt $attempt/$MAX_NETWORK_RETRIES"

        if timeout "$APT_UPDATE_TIMEOUT" apt-get update 2>&1; then
            log "✅ APT update successful"
            return 0
        else
            local exit_code=$?
            warn_log "APT update attempt $attempt failed (exit code: $exit_code)"

            if (( attempt < MAX_NETWORK_RETRIES )); then
                local wait_time=$((attempt * 10))
                log "Waiting ${wait_time}s before retry..."
                sleep "$wait_time"
            fi
        fi

        attempt=$((attempt + 1))
    done

    error_log "APT update failed after $MAX_NETWORK_RETRIES attempts"
    return 1
}

# Safe package installation with validation
install_packages_safe() {
    local packages=("$@")

    if (( ${#packages[@]} == 0 )); then
        log "No packages to install"
        return 0
    fi

    log "📦 Installing packages: ${packages[*]}"

    # Check if packages are already installed
    local packages_to_install=()
    for pkg in "${packages[@]}"; do
        if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            packages_to_install+=("$pkg")
        else
            log "✅ $pkg already installed"
        fi
    done

    if (( ${#packages_to_install[@]} == 0 )); then
        log "All packages already installed"
        return 0
    fi

    log "Installing ${#packages_to_install[@]} packages: ${packages_to_install[*]}"

    # Install with timeout and error handling
    if timeout "$PACKAGE_INSTALL_TIMEOUT" apt-get install -y "${packages_to_install[@]}" 2>&1; then
        log "✅ Package installation successful"

        # Validate installation
        local failed_validation=()
        for pkg in "${packages_to_install[@]}"; do
            if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
                failed_validation+=("$pkg")
            fi
        done

        if (( ${#failed_validation[@]} > 0 )); then
            error_log "Package validation failed for: ${failed_validation[*]}"
            return 1
        fi

        return 0
    else
        local exit_code=$?
        error_log "Package installation failed (exit code: $exit_code)"
        return 1
    fi
}

# Git LFS setup with validation
setup_git_lfs() {
    log "🔧 Setting up Git LFS..."

    if command -v git-lfs >/dev/null 2>&1; then
        if git lfs install 2>&1; then
            log "✅ Git LFS setup successful"
            return 0
        else
            error_log "Git LFS setup failed"
            return 1
        fi
    else
        warn_log "Git LFS not available - skipping setup"
        return 0
    fi
}

# Create directories with proper permissions
create_directories() {
    log "📁 Creating necessary directories..."

    local directories=(
        "/workspace/logs"
        "/workspace/ComfyUI/models/checkpoints"
        "/workspace/ComfyUI/models/loras"
        "/workspace/ComfyUI/user/default/workflows"
        "/workspace/.pip_cache"
    )

    local failed_dirs=()

    for dir in "${directories[@]}"; do
        if mkdir -p "$dir" 2>/dev/null; then
            # Set proper permissions
            chmod 755 "$dir" 2>/dev/null || true
            log "✅ Created $dir"
        else
            failed_dirs+=("$dir")
        fi
    done

    if (( ${#failed_dirs[@]} > 0 )); then
        error_log "Failed to create directories: ${failed_dirs[*]}"
        return 1
    fi

    return 0
}

# Validate system requirements
validate_system() {
    log "🔍 Validating system requirements..."

    # Check Ubuntu version (should be compatible)
    if [[ -f /etc/os-release ]]; then
        local os_name
        os_name=$(grep '^NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
        local os_version
        os_version=$(grep '^VERSION=' /etc/os-release | cut -d'=' -f2 | tr -d '"' || echo "unknown")

        log "System: $os_name $os_version"

        if [[ "$os_name" != *"Ubuntu"* ]]; then
            warn_log "System is not Ubuntu - some packages may not be available"
        fi
    fi

    # Check available commands
    local required_commands=("apt-get" "curl" "python3" "pip3" "git")
    local missing_commands=()

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done

    if (( ${#missing_commands[@]} > 0 )); then
        error_log "Missing required commands: ${missing_commands[*]}"
        return 1
    fi

    log "✅ System validation passed"
    return 0
}

echo "🚀 Starting $MODULE_NAME (Production Mode)..."

# Pre-flight checks
if ! validate_system; then
    error_log "System validation failed"
    exit 1
fi

if ! check_network; then
    error_log "Network check failed"
    exit 1
fi

# APT package installation
APT_PACKAGES=(
    "unrar"
    "p7zip-full"
    "unzip"
    "ffmpeg"
    "libgl1-mesa-glx"
    "libglib2.0-0"
    "git-lfs"
    "file"
    "aria2"
    "curl"
    "python3-pip"
    "python3-dev"
    "build-essential"
    "libssl-dev"
    "libffi-dev"
)

# Update APT first
if ! apt_update_safe; then
    error_log "Cannot proceed without APT update"
    exit 1
fi

# Install packages
if ! install_packages_safe "${APT_PACKAGES[@]}"; then
    error_log "Package installation failed"
    exit 1
fi

# Setup Git LFS
if ! setup_git_lfs; then
    warn_log "Git LFS setup failed - continuing..."
fi

# Create directories
if ! create_directories; then
    error_log "Directory creation failed"
    exit 1
fi

# Final validation
log "🔍 Performing final validation..."

# Check critical commands are available
if ! command -v python3 >/dev/null 2>&1; then
    error_log "Python3 not available after installation"
    exit 1
fi

if ! command -v pip3 >/dev/null 2>&1; then
    error_log "pip3 not available after installation"
    exit 1
fi

# Test pip functionality
if ! python3 -c "import pip" 2>/dev/null; then
    error_log "pip import failed"
    exit 1
fi

log "✅ All validations passed"

mark_module_complete "$MODULE_NAME"
log "✅ Finished $MODULE_NAME (Production Mode)"
