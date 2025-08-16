#!/bin/bash
# GLSL Shader Validation Tool Setup
# Installs glslangValidator locally for shader linting in VS Code

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
    echo -e "${GREEN}=== GLSL Shader Validation Tool Setup ===${NC}"
    echo "Installing glslangValidator for VS Code GLSL Lint extension"
    echo "Toolchain Directory: $TOOLCHAIN_DIR"
    echo "Platform: $(uname -s) $(uname -m)"
    echo
}

# Download and install glslangValidator locally
install_glslang() {
    print_step "Installing glslangValidator locally..."
    
    local glslang_dir="$TOOLCHAIN_DIR/glslang"
    
    # Check if already installed and working
    if [[ -d "$glslang_dir" && -x "$glslang_dir/bin/glslangValidator" ]]; then
        print_status "Testing existing glslangValidator installation..."
        if "$glslang_dir/bin/glslangValidator" --version >/dev/null 2>&1; then
            local current_info=$("$glslang_dir/bin/glslangValidator" --version 2>&1 | head -n1 || echo "unknown")
            print_status "glslangValidator already installed and working: $current_info"
            return 0
        else
            print_warning "Found glslangValidator but it's not working, removing..."
            rm -rf "$glslang_dir"
        fi
    elif [[ -d "$glslang_dir" ]]; then
        print_warning "Found incomplete glslangValidator installation, removing..."
        rm -rf "$glslang_dir"
    fi
    
    # Determine platform for download
    local arch=$(uname -m)
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local platform_name
    local build_type="Release"  # Use Release builds for better performance
    
    case "$os-$arch" in
        "darwin-arm64"|"darwin-x86_64")
            platform_name="osx"
            ;;
        "linux-x86_64")
            platform_name="linux"
            ;;
        *)
            print_error "Unsupported platform for glslangValidator: $os-$arch"
            print_error "Supported platforms: macOS (Intel/Apple Silicon), Linux x86_64"
            exit 1
            ;;
    esac
    
    # Use main-tot release which has precompiled binaries
    local glslang_url="https://github.com/KhronosGroup/glslang/releases/download/main-tot/glslang-main-${platform_name}-${build_type}.zip"
    
    print_status "Downloading glslangValidator from main-tot release for $platform_name..."
    print_status "URL: $glslang_url"
    
    # Download glslang
    local temp_dir=$(mktemp -d)
    local filename=$(basename "$glslang_url")
    
    if ! curl -L -f -o "$temp_dir/$filename" "$glslang_url"; then
        print_error "Failed to download glslangValidator from $glslang_url"
        print_error "Check if the URL is accessible and the platform is supported"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Verify we got a proper zip file
    local file_size=$(stat -c%s "$temp_dir/$filename" 2>/dev/null || stat -f%z "$temp_dir/$filename" 2>/dev/null || echo "0")
    if [[ "$file_size" -lt 1000 ]]; then
        print_error "Downloaded file is too small ($file_size bytes), likely a 404 or error page"
        print_error "Contents of downloaded file:"
        cat "$temp_dir/$filename" || true
        rm -rf "$temp_dir"
        exit 1
    fi
    
    print_status "Downloaded $file_size bytes, extracting..."
    
    # Extract glslang
    print_status "Extracting glslangValidator to $glslang_dir..."
    
    if ! unzip -q "$temp_dir/$filename" -d "$temp_dir"; then
        print_error "Failed to extract glslangValidator"
        print_error "File may be corrupted or not a valid zip file"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Create glslang directory and move files
    mkdir -p "$glslang_dir/bin"
    
    # Look for binaries in various possible locations within the extracted files
    local glslang_binary=""
    if [[ -f "$temp_dir/bin/glslangValidator" ]]; then
        glslang_binary="$temp_dir/bin/glslangValidator"
    elif [[ -f "$temp_dir/glslangValidator" ]]; then
        glslang_binary="$temp_dir/glslangValidator"
    else
        # Search recursively for the binary
        glslang_binary=$(find "$temp_dir" -name "glslangValidator" -type f -executable | head -n1)
    fi
    
    if [[ -n "$glslang_binary" && -f "$glslang_binary" ]]; then
        # Copy the binary and make sure it's executable
        cp "$glslang_binary" "$glslang_dir/bin/glslangValidator"
        chmod +x "$glslang_dir/bin/glslangValidator"
        
        # Also copy any other tools that might be useful
        local bin_dir=$(dirname "$glslang_binary")
        for tool in spirv-remap spirv-dis spirv-val spirv-opt spirv-link spirv-reduce; do
            if [[ -f "$bin_dir/$tool" ]]; then
                cp "$bin_dir/$tool" "$glslang_dir/bin/"
                chmod +x "$glslang_dir/bin/$tool"
                print_status "Also installed: $tool"
            fi
        done
        
        print_status "Installed glslangValidator to $glslang_dir/bin/"
    else
        print_error "glslangValidator binary not found after extraction"
        print_status "Available files in extracted archive:"
        find "$temp_dir" -type f | head -20
        rm -rf "$temp_dir"
        exit 1
    fi
    
    rm -rf "$temp_dir"
    
    # Verify installation
    if [[ -x "$glslang_dir/bin/glslangValidator" ]]; then
        print_status "Testing glslangValidator installation..."
        local version_info=$("$glslang_dir/bin/glslangValidator" --version 2>&1 | head -n1 || echo "Version check failed")
        print_status "✅ glslangValidator installed successfully: $version_info"
    else
        print_error "glslangValidator installation failed - binary not found or not executable"
        exit 1
    fi
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Install glslangValidator locally for GLSL shader validation."
    echo
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo
    echo "This script downloads the latest glslangValidator from the main-tot release"
    echo "and installs it to the local toolchain for use with VS Code GLSL Lint extension."
    echo
    echo "Configuration is loaded from tools/versions.sh"
}

# Main execution
main() {
    local option="${1:-}"
    
    # Show usage if help requested
    if [[ "$option" == "-h" || "$option" == "--help" || "$option" == "help" ]]; then
        show_usage
        exit 0
    fi
    
    show_header
    print_status "Starting glslangValidator installation..."
    echo
    
    # Create toolchain directory if it doesn't exist
    mkdir -p "$TOOLCHAIN_DIR"
    
    install_glslang
    
    echo
    print_status "✅ glslangValidator setup complete!"
    echo
    echo "To use glslangValidator:"
    echo "  1. Source the environment: source tools/activate-env.sh"
    echo "  2. Run: glslangValidator --version"
    echo "  3. VS Code GLSL Lint extension should now work automatically"
    echo
}

# Run main function
main "$@"