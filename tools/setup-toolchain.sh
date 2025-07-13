#!/bin/bash
# Local Toolchain Setup - Container-style development for desktop GUI software
# Installs all project dependencies in local toolchain/ directory

set -e  # Exit on any error

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLCHAIN_DIR="$PROJECT_ROOT/toolchain"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Local Toolchain Setup ===${NC}"
echo "Project: G-Code Sender"
echo "Toolchain Directory: $TOOLCHAIN_DIR"
echo "Platform: $(uname -s) $(uname -m)"
echo

# Function to print colored status
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
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
    
    mkdir -p "$TOOLCHAIN_DIR"/{flutter,scripts,cache,config}
    
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
        print_error "Flutter directory not found after extraction"
        exit 1
    fi
    rm -rf "$temp_dir"
    
    # Verify installation
    if [[ -x "$flutter_dir/bin/flutter" ]]; then
        print_status "Flutter $FLUTTER_VERSION installed successfully"
    else
        print_error "Flutter installation failed - binary not found"
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

# Set Flutter/Dart cache directories to local toolchain
export PUB_CACHE="$TOOLCHAIN_DIR/cache/pub"
export FLUTTER_ROOT="$FLUTTER_HOME"

# Create cache directories if they don't exist
mkdir -p "$PUB_CACHE"

echo "✅ Activated local toolchain environment"
echo "   Flutter: $(which flutter)"
echo "   Dart: $(which dart)"
echo "   Pub Cache: $PUB_CACHE"
EOF
    
    chmod +x "$activation_script"
    print_status "Created activation script: $activation_script"
}

# Create convenience activation script in tools/
create_tools_activation_script() {
    print_step "Creating tools/activate-env.sh convenience script..."
    
    local tools_script="$PROJECT_ROOT/tools/activate-env.sh"
    
    cat > "$tools_script" << 'EOF'
#!/bin/bash
# Convenience script to activate local toolchain
# Usage: source ./tools/activate-env.sh

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PROJECT_ROOT/toolchain/scripts/activate-env.sh"
EOF
    
    chmod +x "$tools_script"
    print_status "Created convenience script: $tools_script"
}

# Update build scripts to use local toolchain
update_build_scripts() {
    print_step "Updating build scripts to use local toolchain..."
    
    # Update build.sh to activate environment first
    local build_script="$PROJECT_ROOT/tools/build.sh"
    
    # Add environment activation to existing build script
    if [[ -f "$build_script" ]]; then
        # Create backup
        cp "$build_script" "$build_script.backup"
        
        # Add environment activation at the top (after set -e)
        sed -i.tmp '6i\
# Activate local toolchain environment\
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"\
if [[ -f "$PROJECT_ROOT/toolchain/scripts/activate-env.sh" ]]; then\
    source "$PROJECT_ROOT/toolchain/scripts/activate-env.sh"\
fi\
' "$build_script"
        
        rm "$build_script.tmp"
        print_status "Updated build.sh to use local toolchain"
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
CMAKE_MIN_VERSION="3.18.0"
EOF
        print_status "Created versions.env file"
    else
        print_status "versions.env file already exists"
    fi
}

# Run Flutter doctor to check system dependencies
check_system_dependencies() {
    print_step "Checking system dependencies with Flutter doctor..."
    
    # Activate environment temporarily for this check
    export PATH="$TOOLCHAIN_DIR/flutter/bin:$PATH"
    
    echo
    echo "=== Flutter Doctor Output ==="
    "$TOOLCHAIN_DIR/flutter/bin/flutter" doctor
    echo "=== End Flutter Doctor ==="
    echo
    
    print_warning "Review Flutter doctor output above for any missing system dependencies"
    print_status "Note: Some warnings are expected since we're using a local toolchain"
}

# Create VS Code configuration
create_vscode_config() {
    print_step "Creating VS Code configuration for local toolchain..."
    
    local vscode_dir="$PROJECT_ROOT/.vscode"
    mkdir -p "$vscode_dir"
    
    # Settings for local toolchain
    local settings_file="$vscode_dir/settings.json"
    
    if [[ ! -f "$settings_file" ]]; then
        cat > "$settings_file" << EOF
{
  "dart.flutterSdkPath": "./toolchain/flutter",
  "dart.sdkPath": "./toolchain/flutter/bin/cache/dart-sdk",
  "dart.debugExternalPackageLibraries": false,
  "dart.debugSdkLibraries": false,
  "flutter.hotReloadOnSave": true,
  "flutter.hotRestartOnSave": false,
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll": true
  },
  "files.associations": {
    "*.arb": "json"
  },
  "terminal.integrated.env.osx": {
    "PATH": "\${workspaceFolder}/toolchain/flutter/bin:\${env:PATH}",
    "PUB_CACHE": "\${workspaceFolder}/toolchain/cache/pub",
    "FLUTTER_ROOT": "\${workspaceFolder}/toolchain/flutter"
  },
  "terminal.integrated.env.linux": {
    "PATH": "\${workspaceFolder}/toolchain/flutter/bin:\${env:PATH}",
    "PUB_CACHE": "\${workspaceFolder}/toolchain/cache/pub",
    "FLUTTER_ROOT": "\${workspaceFolder}/toolchain/flutter"
  }
}
EOF
        print_status "Created VS Code settings.json"
    else
        print_status "VS Code settings.json already exists"
    fi
}

# Main execution
main() {
    print_status "Starting local toolchain setup..."
    print_status "This will install all development tools in: $TOOLCHAIN_DIR"
    echo
    
    create_versions_file
    setup_directories
    install_flutter
    create_activation_script
    create_tools_activation_script
    update_build_scripts
    create_vscode_config
    
    echo
    print_status "✅ Local toolchain setup complete!"
    echo
    echo "Next steps:"
    echo "1. Activate the environment:"
    echo "   source ./tools/activate-env.sh"
    echo
    echo "2. Verify installation:"
    echo "   flutter --version"
    echo "   flutter doctor"
    echo
    echo "3. Start development:"
    echo "   flutter create test_app"
    echo "   cd test_app && flutter run"
    echo
    
    # Run system dependency check
    check_system_dependencies
}

# Run main function
main "$@"