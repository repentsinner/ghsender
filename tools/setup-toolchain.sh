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

# Version configuration is already loaded via load_versions() from setup-utils.sh

# Create toolchain directory structure
setup_directories() {
    print_step "Setting up toolchain directory structure..."
    
    mkdir -p "$TOOLCHAIN_DIR"/{flutter,cmake,glslang,scripts,cache,config}
    
    print_status "Created toolchain directories"
}

# Install Flutter SDK from git repository
install_flutter() {
    print_step "Installing Flutter SDK from git repository..."
    
    local flutter_dir="$TOOLCHAIN_DIR/flutter"
    
    # Check if Flutter is already installed and on correct channel
    if [[ -d "$flutter_dir" && -x "$flutter_dir/bin/flutter" ]]; then
        local current_channel=$("$flutter_dir/bin/flutter" channel | grep "^*" | awk '{print $2}')
        local current_version=$("$flutter_dir/bin/flutter" --version | head -n1 | awk '{print $2}')
        
        if [[ "$current_channel" == "$FLUTTER_CHANNEL" ]]; then
            print_status "Flutter on $FLUTTER_CHANNEL channel already installed (version: $current_version)"
            
            # Update to latest on the channel
            print_status "Updating Flutter to latest on $FLUTTER_CHANNEL channel..."
            (cd "$flutter_dir" && git pull)
            "$flutter_dir/bin/flutter" --version
            return 0
        else
            print_warning "Found Flutter on $current_channel channel, but need $FLUTTER_CHANNEL channel"
            rm -rf "$flutter_dir"
        fi
    elif [[ -d "$flutter_dir" ]]; then
        print_warning "Found incomplete Flutter installation, removing..."
        rm -rf "$flutter_dir"
    fi
    
    print_status "Cloning Flutter from git repository..."
    
    # Clone Flutter repository
    if ! git clone https://github.com/flutter/flutter.git "$flutter_dir"; then
        print_error "Failed to clone Flutter repository"
        exit 1
    fi
    
    # Switch to the desired channel
    print_status "Switching to $FLUTTER_CHANNEL channel..."
    (
        cd "$flutter_dir"
        git checkout "$FLUTTER_CHANNEL"
        git pull origin "$FLUTTER_CHANNEL"
    )
    
    # Run flutter doctor to download dependencies
    print_status "Initializing Flutter (this may take a few minutes)..."
    "$flutter_dir/bin/flutter" doctor
    
    # Display version info
    local installed_version=$("$flutter_dir/bin/flutter" --version | head -n1 | awk '{print $2}')
    print_status "Flutter $installed_version installed successfully on $FLUTTER_CHANNEL channel"
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

# Install GLSL shader validation tools
setup_glslang() {
    print_step "Setting up GLSL shader validation tools..."
    "$SCRIPT_DIR/setup-glslang.sh"
}

# Note: Environment activation is handled by existing tools/activate-env.sh
# No need to create duplicate activation scripts

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

# Note: tools/versions.sh is manually maintained as the single source of truth
# Setup scripts should NOT generate configuration files

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
    
    setup_directories
    install_flutter
    install_cmake
    setup_glslang
    update_build_scripts
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