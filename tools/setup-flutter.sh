#!/bin/bash
# Flutter SDK installation script for ghSender project
# Installs Flutter SDK locally in toolchain/ directory

set -e  # Exit on any error

# Load shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-utils.sh"

# Load configuration
load_versions

# Set up project paths
PROJECT_ROOT="$(get_project_root)"
TOOLCHAIN_DIR="$PROJECT_ROOT/toolchain"
FLUTTER_DIR="$TOOLCHAIN_DIR/flutter"

# Verify requirements
verify_requirements

# Main Flutter installation function
install_flutter() {
    print_step "Installing Flutter SDK locally..."
    
    # Check if Flutter is already installed and working
    if [[ -d "$FLUTTER_DIR" && -x "$FLUTTER_DIR/bin/flutter" ]]; then
        # For master channel, check if it's a git repo and on the right branch
        if [[ "$FLUTTER_CHANNEL" == "master" || "$FLUTTER_CHANNEL" == "main" ]]; then
            if [[ -d "$FLUTTER_DIR/.git" ]]; then
                cd "$FLUTTER_DIR"
                local current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
                if [[ "$current_branch" == "master" || "$current_branch" == "main" ]]; then
                    print_status "Flutter from $FLUTTER_CHANNEL channel already installed"
                    print_status "Updating to latest..."
                    if git pull origin "${FLUTTER_CHANNEL}" >/dev/null 2>&1; then
                        print_status "Flutter updated successfully"
                        cd "$PROJECT_ROOT"
                        return 0
                    else
                        print_warning "Failed to update Flutter, reinstalling..."
                        cd "$PROJECT_ROOT"
                        rm -rf "$FLUTTER_DIR"
                    fi
                else
                    print_warning "Found Flutter on wrong branch ($current_branch), reinstalling..."
                    rm -rf "$FLUTTER_DIR"
                fi
            else
                print_warning "Found non-git Flutter installation for master channel, reinstalling..."
                rm -rf "$FLUTTER_DIR"
            fi
        else
            # For stable/beta channels, check version
            local current_version=$("$FLUTTER_DIR/bin/flutter" --version | head -n1 | awk '{print $2}')
            if [[ "$current_version" == "$FLUTTER_VERSION" ]]; then
                print_status "Flutter $FLUTTER_VERSION already installed"
                return 0
            else
                print_warning "Found Flutter $current_version, but need $FLUTTER_VERSION"
                rm -rf "$FLUTTER_DIR"
            fi
        fi
    elif [[ -d "$FLUTTER_DIR" ]]; then
        print_warning "Found incomplete Flutter installation, removing..."
        rm -rf "$FLUTTER_DIR"
    fi
    
    # Install Flutter based on channel
    if [[ "$FLUTTER_CHANNEL" == "master" || "$FLUTTER_CHANNEL" == "main" ]]; then
        install_flutter_from_git
    else
        install_flutter_from_release
    fi
    
    # Verify and setup Flutter
    verify_flutter_installation
}

# Install Flutter from git (master/main channel)
install_flutter_from_git() {
    print_status "Cloning Flutter from $FLUTTER_CHANNEL channel..."
    
    if ! git clone -b "$FLUTTER_CHANNEL" https://github.com/flutter/flutter.git "$FLUTTER_DIR"; then
        print_error "Failed to clone Flutter from git"
        exit 1
    fi
    
    print_status "Flutter cloned successfully from $FLUTTER_CHANNEL channel"
}

# Install Flutter from pre-built release
install_flutter_from_release() {
    local arch=$(get_arch)
    local os=$(get_os)
    local flutter_url
    
    # Determine download URL based on platform
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*)
            # Windows - use the Windows Flutter SDK
            flutter_url="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/windows/flutter_windows_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.zip"
            ;;
        Darwin)
            case "$arch" in
                arm64)
                    flutter_url="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/macos/flutter_macos_arm64_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.zip"
                    ;;
                x86_64)
                    flutter_url="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/macos/flutter_macos_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.zip"
                    ;;
            esac
            ;;
        Linux)
            flutter_url="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/linux/flutter_linux_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz"
            ;;
        *)
            print_error "Unsupported platform: $(uname -s)-$arch"
            exit 1
            ;;
    esac
    
    print_status "Downloading Flutter $FLUTTER_VERSION from $FLUTTER_CHANNEL channel for $os-$arch..."
    
    # Download Flutter
    local temp_dir=$(mktemp -d)
    local filename=$(basename "$flutter_url")
    
    if ! curl -L -o "$temp_dir/$filename" "$flutter_url"; then
        print_error "Failed to download Flutter"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Extract Flutter
    print_status "Extracting Flutter to $FLUTTER_DIR..."
    
    case "$filename" in
        *.zip)
            if ! unzip -q "$temp_dir/$filename" -d "$temp_dir"; then
                print_error "Failed to extract Flutter zip"
                rm -rf "$temp_dir"
                exit 1
            fi
            ;;
        *.tar.xz)
            if ! tar -xJf "$temp_dir/$filename" -C "$temp_dir"; then
                print_error "Failed to extract Flutter tar.xz"
                rm -rf "$temp_dir"
                exit 1
            fi
            ;;
    esac
    
    # Move Flutter to toolchain directory  
    if [[ -d "$temp_dir/flutter" ]]; then
        mv "$temp_dir/flutter" "$FLUTTER_DIR"
        print_status "Moved Flutter to $FLUTTER_DIR"
    else
        print_error "Flutter directory not found after extraction"
        rm -rf "$temp_dir"
        exit 1
    fi
    rm -rf "$temp_dir"
}

# Verify Flutter installation and run initial setup
verify_flutter_installation() {
    if [[ -x "$FLUTTER_DIR/bin/flutter" ]]; then
        print_status "Flutter installed successfully"
        
        # Set up Flutter (this downloads Dart SDK and other components)
        print_status "Setting up Flutter (this may take a few minutes)..."
        export PATH="$FLUTTER_DIR/bin:$PATH"
        
        # Run flutter --version to trigger setup and get version info
        "$FLUTTER_DIR/bin/flutter" --version
        
        print_status "Flutter setup complete"
        print_status "✅ Flutter installation successful"
        print_status "Location: $FLUTTER_DIR"
    else
        print_error "Flutter installation failed - binary not found"
        exit 1
    fi
}

# Show usage information
show_usage() {
    echo "Usage: $0"
    echo
    echo "Install Flutter SDK locally in the project's toolchain directory."
    echo
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo
    echo "Configuration is loaded from tools/versions.sh"
}

# Main execution
main() {
    case "${1:-}" in
        -h|--help|help)
            show_usage
            exit 0
            ;;
        "")
            echo -e "${GREEN}=== Flutter Setup ===${NC}"
            echo "Project: ghSender"
            echo "Target: $FLUTTER_DIR"
            echo "Platform: $(uname -s) $(uname -m)"
            echo
            
            setup_directories
            install_flutter
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"