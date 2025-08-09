#!/bin/bash
# Local Toolchain Setup - Container-style development for desktop GUI software
# Orchestrates individual setup scripts for each component

set -e  # Exit on any error

# Load shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-utils.sh"

# Load configuration
load_versions

# Set up project paths
PROJECT_ROOT="$(get_project_root)"
TOOLCHAIN_DIR="$PROJECT_ROOT/toolchain"

# Show header
show_header() {
    echo -e "${GREEN}=== Local Toolchain Setup ===${NC}"
    echo "Project: ghSender"
    echo "Toolchain Directory: $TOOLCHAIN_DIR"
    echo "Platform: $(uname -s) $(uname -m)"
    echo
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Load version configuration
source "$PROJECT_ROOT/tools/versions.env"

# Create toolchain directory structure
setup_directories() {
    print_step "Setting up toolchain directory structure..."
    
    mkdir -p "$TOOLCHAIN_DIR"/{flutter,cmake,scripts,cache,config}
    
    print_status "Created toolchain directories"
}

# Download and install Flutter SDK locally
install_flutter() {
    print_step "Installing Flutter SDK locally..."
    
    local flutter_dir="$TOOLCHAIN_DIR/flutter"
    
    if [[ -d "$flutter_dir" && -x "$flutter_dir/bin/flutter" ]]; then
        local current_version=$("$flutter_dir/bin/flutter" --version | head -n1 | awk '{print $2}')
        if [[ "$current_version" == "$FLUTTER_VERSION" ]]; then
            print_status "Flutter $FLUTTER_VERSION already installed"
            return 0
        else
            print_warning "Found Flutter $current_version, but need $FLUTTER_VERSION"
            rm -rf "$flutter_dir"
        fi
    elif [[ -d "$flutter_dir" ]]; then
        print_warning "Found incomplete Flutter installation, removing..."
        rm -rf "$flutter_dir"
    fi
    
    # Determine architecture and download URL
    local arch=$(uname -m)
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local flutter_url
    
    case "$os-$arch" in
        "darwin-arm64")
            flutter_url="https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_${FLUTTER_VERSION}-stable.zip"
            ;;
        "darwin-x86_64")
            flutter_url="https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_${FLUTTER_VERSION}-stable.zip"
            ;;
        "linux-x86_64")
            flutter_url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
            ;;
        *)
            print_error "Unsupported platform: $os-$arch"
            exit 1
            ;;
    esac
    
    print_status "Downloading Flutter $FLUTTER_VERSION for $os-$arch..."
    
    # Download Flutter
    local temp_dir=$(mktemp -d)
    local filename=$(basename "$flutter_url")
    
    if ! curl -L -o "$temp_dir/$filename" "$flutter_url"; then
        print_error "Failed to download Flutter"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Extract Flutter
    print_status "Extracting Flutter to $flutter_dir..."
    
    case "$filename" in
        *.zip)
            if ! unzip -q "$temp_dir/$filename" -d "$temp_dir"; then
                print_error "Failed to extract Flutter zip"
                exit 1
            fi
            ;;
        *.tar.xz)
            if ! tar -xJf "$temp_dir/$filename" -C "$temp_dir"; then
                print_error "Failed to extract Flutter tar.xz"
                exit 1
            fi
            ;;
    esac
    
    # Debug: Check what was extracted
    print_status "Contents of temp directory after extraction:"
    ls -la "$temp_dir"
    
    # Move Flutter to toolchain directory  
    if [[ -d "$temp_dir/flutter" ]]; then
        mv "$temp_dir/flutter" "$flutter_dir"
        print_status "Moved Flutter to $flutter_dir"
    else
        print_warning "Ruby dependencies script not found, skipping..."
    fi
}

# Download and install CMake locally
install_cmake() {
    print_step "Installing CMake locally..."
    
    local cmake_dir="$TOOLCHAIN_DIR/cmake"
    
    if [[ -d "$cmake_dir" && -x "$cmake_dir/CMake.app/Contents/bin/cmake" ]]; then
        local current_version=$("$cmake_dir/CMake.app/Contents/bin/cmake" --version | head -n1 | awk '{print $3}')
        if [[ "$current_version" == "$CMAKE_VERSION" ]]; then
            print_status "CMake $CMAKE_VERSION already installed"
            return 0
        else
            print_warning "Found CMake $current_version, but need $CMAKE_VERSION"
            rm -rf "$cmake_dir"
        fi
    elif [[ -d "$cmake_dir" ]]; then
        print_warning "Found incomplete CMake installation, removing..."
        rm -rf "$cmake_dir"
    fi
    
    # Determine architecture and download URL
    local arch=$(uname -m)
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local cmake_url
    
    case "$os-$arch" in
        "darwin-"*) # Both x86_64 and arm64 use universal binary
            cmake_url="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-macos-universal.tar.gz"
            ;;
        "linux-x86_64")
            cmake_url="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz"
            ;;
        *)
            print_error "Unsupported platform for CMake: $os-$arch"
            exit 1
            ;;
    esac
    
    print_status "Downloading CMake $CMAKE_VERSION for $os-$arch..."
    
    # Download CMake
    local temp_dir=$(mktemp -d)
    local filename=$(basename "$cmake_url")
    
    if ! curl -L -o "$temp_dir/$filename" "$cmake_url"; then
        print_error "Failed to download CMake"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Extract CMake
    print_status "Extracting CMake to $cmake_dir..."
    
    if ! tar -xzf "$temp_dir/$filename" -C "$temp_dir"; then
        print_error "Failed to extract CMake"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Move CMake to toolchain directory
    local extracted_dir="$temp_dir/cmake-${CMAKE_VERSION}-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)"
    if [[ "$os" == "darwin" ]]; then
        extracted_dir="$temp_dir/cmake-${CMAKE_VERSION}-macos-universal"
    fi
    
    if [[ -d "$extracted_dir" ]]; then
        mv "$extracted_dir" "$cmake_dir"
        print_status "Moved CMake to $cmake_dir"
    else
        print_error "CMake directory not found after extraction"
        print_status "Available directories:"
        ls -la "$temp_dir"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    rm -rf "$temp_dir"
    
    # Verify installation
    if [[ -x "$cmake_dir/CMake.app/Contents/bin/cmake" ]] || [[ -x "$cmake_dir/bin/cmake" ]]; then
        print_status "CMake $CMAKE_VERSION installed successfully"
    else
        print_error "CMake installation failed - binary not found"
        exit 1
    fi
}

# Create environment activation script
create_activation_script() {
    print_step "Creating environment activation script..."
    
    local activation_script="$TOOLCHAIN_DIR/scripts/activate-env.sh"
    
    cat > "$activation_script" << 'EOF'
#!/bin/bash
# Activate local toolchain environment
# Usage: source ./toolchain/scripts/activate-env.sh

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script must be sourced, not executed directly"
    echo "Usage: source ./toolchain/scripts/activate-env.sh"
    exit 1
fi

# Get project root (toolchain parent directory)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOOLCHAIN_DIR="$PROJECT_ROOT/toolchain"

# Add Flutter to PATH
export FLUTTER_HOME="$TOOLCHAIN_DIR/flutter"
export PATH="$FLUTTER_HOME/bin:$PATH"

# Add CMake to PATH
export CMAKE_HOME="$TOOLCHAIN_DIR/cmake"
if [[ -d "$CMAKE_HOME/CMake.app/Contents/bin" ]]; then
    # macOS CMake app bundle
    export PATH="$CMAKE_HOME/CMake.app/Contents/bin:$PATH"
elif [[ -d "$CMAKE_HOME/bin" ]]; then
    # Linux CMake binary
    export PATH="$CMAKE_HOME/bin:$PATH"
fi

# Set Flutter/Dart cache directories to local toolchain
export PUB_CACHE="$TOOLCHAIN_DIR/cache/pub"
export FLUTTER_ROOT="$FLUTTER_HOME"

# Create cache directories if they don't exist
mkdir -p "$PUB_CACHE"

echo "✅ Activated local toolchain environment"
echo "   Flutter: $(which flutter)"
echo "   Dart: $(which dart)"
echo "   CMake: $(which cmake)"
echo "   Pub Cache: $PUB_CACHE"
EOF
    
    chmod +x "$activation_script"
    print_status "Created activation script: $activation_script"
}

# Run Flutter setup
setup_flutter() {
    print_step "Setting up Flutter..."
    "$SCRIPT_DIR/setup-flutter.sh"
}

# Update build scripts to use local toolchain
update_build_scripts() {
    print_step "Updating build scripts to use local toolchain..."
    
    # Update build.sh to activate environment first
    local build_script="$PROJECT_ROOT/tools/build.sh"
    
    # Skip updating build.sh - it already has toolchain activation
    if [[ -f "$build_script" ]]; then
        print_status "build.sh already configured for local toolchain"
    fi
}

# Create version tracking file
create_versions_file() {
    print_step "Creating versions.env file..."
    
    local versions_file="$PROJECT_ROOT/tools/versions.env"
    
    if [[ ! -f "$versions_file" ]]; then
        cat > "$versions_file" << EOF
# Tool versions for local toolchain
# Single source of truth for all development dependencies

# Flutter/Dart versions
FLUTTER_VERSION="3.24.5"
DART_VERSION="3.5.4"

# Platform tool minimum versions
XCODE_MIN_VERSION="15.0"
ANDROID_SDK_VERSION="34.0.0"
COCOAPODS_MIN_VERSION="1.11.0"

# Node.js (if needed for web builds)
NODE_VERSION="20.10.0"

# Build tool versions
CMAKE_VERSION="3.28.1"
CMAKE_MIN_VERSION="3.18.0"
EOF
        print_status "Created versions.env file"
    else
        print_status "versions.env file already exists"
    fi
}

# Run Flutter doctor to check system dependencies
# Install git hooks for code quality
setup_git_hooks() {
    print_step "Setting up git hooks..."
    "$SCRIPT_DIR/setup-git-hooks.sh"
}

check_system_dependencies() {
    print_step "Checking system dependencies with Flutter doctor..."
    
    # Activate full environment temporarily for this check
    if [[ -f "$PROJECT_ROOT/tools/activate-env.sh" ]]; then
        # Source environment in a subshell to avoid affecting current session
        (
            source "$PROJECT_ROOT/tools/activate-env.sh" > /dev/null 2>&1
            echo
            echo "=== Flutter Doctor Output ==="
            flutter doctor
            echo "=== End Flutter Doctor ==="
        )
    else
        print_warning "Environment activation script not found, using basic PATH setup"
        export PATH="$TOOLCHAIN_DIR/flutter/bin:$PATH"
        
        echo
        echo "=== Flutter Doctor Output ==="
        "$TOOLCHAIN_DIR/flutter/bin/flutter" doctor
        echo "=== End Flutter Doctor ==="
    fi
    
    echo
    print_warning "Review Flutter doctor output above for any missing system dependencies"
    print_status "Note: Some warnings are expected since we're using a local toolchain"
}


# Show usage information
show_usage() {
    echo "Usage: $0 [COMPONENT]"
    echo
    echo "Install local development toolchain components."
    echo
    echo "Components:"
    echo "  directories    Set up toolchain directory structure"
    echo "  ruby-deps     Install Ruby build dependencies from source"
    echo "  ruby          Install Ruby and CocoaPods via asdf"
    echo "  flutter       Install Flutter SDK"
    echo "  doctor        Run Flutter doctor to check dependencies"
    echo
    echo "If no component is specified, installs all components in correct order."
    echo "Recommended dependency order: ruby-deps → ruby → flutter"
    echo
    echo "Examples:"
    echo "  $0              # Install everything"
    echo "  $0 ruby-deps    # Install only Ruby dependencies"
    echo "  $0 ruby         # Install only Ruby and CocoaPods"
    echo "  $0 flutter      # Install only Flutter"
}

# Main execution
main() {
    local component="$1"
    
    # Show usage if help requested
    if [[ "$component" == "-h" || "$component" == "--help" || "$component" == "help" ]]; then
        show_usage
        exit 0
    fi
    
    show_header
    print_status "Starting local toolchain setup..."
    print_status "Target directory: $TOOLCHAIN_DIR"
    echo
    
    create_versions_file
    setup_directories
    install_flutter
    install_cmake
    create_activation_script
    create_tools_activation_script
    update_build_scripts
    create_vscode_config
    setup_git_hooks
    
    if [[ -n "$component" && "$component" != "doctor" ]]; then
        echo
        print_status "✅ Component '$component' setup complete!"
        echo
        echo "To install all components: $0"
        echo "To see available components: $0 --help"
    fi
}

# Run main function
main "$@"