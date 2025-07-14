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
echo "Project: ghSender"
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



# Install libyaml locally
install_libyaml() {
    print_step "Installing libyaml locally..."
    local libyaml_dir="$TOOLCHAIN_DIR/libyaml"
    local libyaml_version="0.2.5"
    local libyaml_url="http://pyyaml.org/download/libyaml/yaml-${libyaml_version}.tar.gz"
    local temp_dir=$(mktemp -d)
    local filename=$(basename "$libyaml_url")
    local extracted_dir="$temp_dir/yaml-${libyaml_version}"

    mkdir -p "$libyaml_dir"

    print_status "Downloading libyaml ${libyaml_version}..."
    if ! curl -L -o "$temp_dir/$filename" "$libyaml_url"; then
        print_error "Failed to download libyaml"
        rm -rf "$temp_dir"
        exit 1
    fi

    print_status "Extracting libyaml..."
    if ! tar -xzf "$temp_dir/$filename" -C "$temp_dir"; then
        print_error "Failed to extract libyaml"
        rm -rf "$temp_dir"
        exit 1
    fi

    print_status "Compiling and installing libyaml..."
    (cd "$extracted_dir" && \
        ./configure --prefix="$libyaml_dir" && \
        make && \
        make install)

    if [[ $? -ne 0 ]]; then
        print_error "Failed to compile or install libyaml"
        rm -rf "$temp_dir"
        exit 1
    fi

    rm -rf "$temp_dir"
    print_status "libyaml ${libyaml_version} installed successfully to $libyaml_dir."
}

# Install rbenv and ruby-build

install_rbenv() {
    print_step "Installing rbenv and ruby-build..."
    local rbenv_dir="$TOOLCHAIN_DIR/gems/rbenv"
    local ruby_build_dir="$rbenv_dir/plugins/ruby-build"

    mkdir -p "$rbenv_dir"
    git clone https://github.com/rbenv/rbenv.git "$rbenv_dir"

    mkdir -p "$ruby_build_dir"
    git clone https://github.com/rbenv/ruby-build.git "$ruby_build_dir"

    print_status "rbenv and ruby-build installed."
}

# Install Ruby using rbenv
install_ruby() {
    print_step "Installing Ruby $RUBY_VERSION using rbenv..."
    
    # Install Ruby
    if ! rbenv install -s "$RUBY_VERSION" --with-yaml-dir="$TOOLCHAIN_DIR/libyaml"; then
        print_error "Failed to install Ruby $RUBY_VERSION"
        exit 1
    fi

    # Set global Ruby version
    if ! rbenv global "$RUBY_VERSION"; then
        print_error "Failed to set global Ruby version to $RUBY_VERSION"
        exit 1
    fi

    print_status "Ruby $RUBY_VERSION installed and set as global."
}

# Download and install Flutter SDK locally
install_flutter() {
    print_step "Installing Flutter SDK locally..."
    
    local flutter_dir="$TOOLCHAIN_DIR/flutter"

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
    print_status "Extracting Flutter to $TOOLCHAIN_DIR..."
    
    case "$filename" in
        *.zip)
            if ! unzip -q "$temp_dir/$filename" -d "$TOOLCHAIN_DIR"; then
                print_error "Failed to extract Flutter zip"
                exit 1
            fi
            ;;
        *.tar.xz)
            if ! tar -xJf "$temp_dir/$filename" -C "$TOOLCHAIN_DIR"; then
                print_error "Failed to extract Flutter tar.xz"
                exit 1
            fi
            ;;
    esac
    
    print_status "Contents of $flutter_dir after extraction:"
    ls -laR "$flutter_dir"

    rm -rf "$temp_dir"
    
    # Verify installation
    if [[ -x "$flutter_dir/bin/flutter" ]]; then
        print_status "Flutter $FLUTTER_VERSION installed successfully"
    else
        print_error "Flutter installation failed - binary not found"
        exit 1
    fi
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
    "PATH": "\${workspaceFolder}/toolchain/flutter/bin:\${workspaceFolder}/toolchain/gems/rbenv/bin:\${env:PATH}",
    "PUB_CACHE": "\${workspaceFolder}/toolchain/cache/pub",
    "FLUTTER_ROOT": "\${workspaceFolder}/toolchain/flutter"
  },
  "terminal.integrated.env.linux": {
    "PATH": "\${workspaceFolder}/toolchain/flutter/bin:\${workspaceFolder}/toolchain/gems/rbenv/bin:\${env:PATH}",
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
    
    print_step "Cleaning up existing toolchain directory..."
    rm -rf "$TOOLCHAIN_DIR"
    print_status "Removed existing toolchain directory."

    install_libyaml
    install_rbenv

    # Initialize rbenv for the current script execution
    export RBENV_ROOT="$TOOLCHAIN_DIR/gems/rbenv"
    export PATH="$RBENV_ROOT/bin:$PATH"
    eval "$(rbenv init -)"

    install_ruby
    install_flutter
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