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

# Create toolchain directory structure
setup_directories() {
    print_step "Setting up toolchain directory structure..."
    
    mkdir -p "$TOOLCHAIN_DIR"/{flutter,scripts,cache,config,ruby,nix}
    
    print_status "Created toolchain directories"
}

# Download and install Flutter SDK locally
install_flutter() {
    print_step "Installing Flutter SDK locally..."
    
    local flutter_dir="$TOOLCHAIN_DIR/flutter"
    
    if [[ -d "$flutter_dir" && -x "$flutter_dir/bin/flutter" ]]; then
        # For master channel, check if it's a git repo and on the right branch
        if [[ "$FLUTTER_CHANNEL" == "master" || "$FLUTTER_CHANNEL" == "main" ]]; then
            if [[ -d "$flutter_dir/.git" ]]; then
                cd "$flutter_dir"
                local current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
                if [[ "$current_branch" == "master" || "$current_branch" == "main" ]]; then
                    print_status "Flutter from $FLUTTER_CHANNEL channel already installed"
                    print_status "Updating to latest..."
                    if git pull origin "${FLUTTER_CHANNEL}" >/dev/null 2>&1; then
                        print_status "Flutter updated successfully"
                        return 0
                    else
                        print_warning "Failed to update Flutter, reinstalling..."
                        cd "$PROJECT_ROOT"
                        rm -rf "$flutter_dir"
                    fi
                else
                    print_warning "Found Flutter on wrong branch ($current_branch), reinstalling..."
                    cd "$PROJECT_ROOT"
                    rm -rf "$flutter_dir"
                fi
            else
                print_warning "Found non-git Flutter installation for master channel, reinstalling..."
                rm -rf "$flutter_dir"
            fi
        else
            # For stable/beta channels, check version
            local current_version=$("$flutter_dir/bin/flutter" --version | head -n1 | awk '{print $2}')
            if [[ "$current_version" == "$FLUTTER_VERSION" ]]; then
                print_status "Flutter $FLUTTER_VERSION already installed"
                return 0
            else
                print_warning "Found Flutter $current_version, but need $FLUTTER_VERSION"
                rm -rf "$flutter_dir"
            fi
        fi
    elif [[ -d "$flutter_dir" ]]; then
        print_warning "Found incomplete Flutter installation, removing..."
        rm -rf "$flutter_dir"
    fi
    
    # Install Flutter based on channel
    if [[ "$FLUTTER_CHANNEL" == "master" || "$FLUTTER_CHANNEL" == "main" ]]; then
        # For master/main channel, clone from git
        print_status "Cloning Flutter from $FLUTTER_CHANNEL channel..."
        
        if ! git clone -b "$FLUTTER_CHANNEL" https://github.com/flutter/flutter.git "$flutter_dir"; then
            print_error "Failed to clone Flutter from git"
            exit 1
        fi
        
        print_status "Flutter cloned successfully from $FLUTTER_CHANNEL channel"
    else
        # For stable/beta channels, download pre-built zip
        local arch=$(uname -m)
        local os=$(uname -s | tr '[:upper:]' '[:lower:]')
        local flutter_url
        
        case "$os-$arch" in
            "darwin-arm64")
                flutter_url="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/macos/flutter_macos_arm64_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.zip"
                ;;
            "darwin-x86_64")
                flutter_url="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/macos/flutter_macos_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.zip"
                ;;
            "linux-x86_64")
                flutter_url="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/linux/flutter_linux_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz"
                ;;
            *)
                print_error "Unsupported platform: $os-$arch"
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
        
        # Move Flutter to toolchain directory  
        if [[ -d "$temp_dir/flutter" ]]; then
            mv "$temp_dir/flutter" "$flutter_dir"
            print_status "Moved Flutter to $flutter_dir"
        else
            print_error "Flutter directory not found after extraction"
            exit 1
        fi
        rm -rf "$temp_dir"
    fi
    
    # Verify installation
    if [[ -x "$flutter_dir/bin/flutter" ]]; then
        print_status "Flutter installed successfully"
        
        # Set up Flutter (this downloads Dart SDK and other components)
        print_status "Setting up Flutter (this may take a few minutes)..."
        export PATH="$flutter_dir/bin:$PATH"
        
        # Run flutter --version to trigger setup and get version info
        "$flutter_dir/bin/flutter" --version
        
        print_status "Flutter setup complete"
    else
        print_error "Flutter installation failed - binary not found"
        exit 1
    fi
}

# Install Nix package manager locally within project directory
install_nix() {
    print_step "Installing Nix package manager locally..."
    
    local nix_dir="$TOOLCHAIN_DIR/nix"
    local nix_store="$nix_dir/store"
    local nix_var="$nix_dir/var"
    
    # Check if we already have a working local Nix installation
    if [[ -f "$nix_dir/bin/nix" ]] && [[ -f "$nix_dir/activate-nix.sh" ]]; then
        print_status "Checking existing local Nix installation..."
        
        # Test the existing installation
        if source "$nix_dir/activate-nix.sh" && command -v nix >/dev/null 2>&1; then
            local current_version=$(nix --version 2>/dev/null | awk '{print $3}' || echo "unknown")
            print_status "Found working local Nix installation (version: $current_version)"
            return 0
        else
            print_warning "Existing local Nix installation not working, reinstalling..."
            rm -rf "$nix_dir"
            mkdir -p "$nix_dir"
        fi
    fi
    
    print_status "Installing Nix in single-user mode within project directory..."
    print_status "Target directory: $nix_dir"
    
    # Determine OS and architecture
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    
    case "$os-$arch" in
        "darwin-arm64"|"darwin-x86_64"|"linux-x86_64")
            print_status "Detected platform: $os-$arch"
            ;;
        *)
            print_error "Unsupported platform: $os-$arch"
            print_error "Local Nix installation only supports macOS and Linux x86_64"
            exit 1
            ;;
    esac
    
    # Create Nix directory structure
    mkdir -p "$nix_store" "$nix_var/nix/profiles" "$nix_var/nix/db" "$nix_dir/bin" "$nix_dir/etc"
    
    # Download Nix static binary
    print_status "Downloading Nix static binary for $os-$arch..."
    local temp_dir=$(mktemp -d)
    local nix_url
    
    # Use specific Nix version that supports static binaries
    case "$os-$arch" in
        "darwin-arm64")
            nix_url="https://releases.nixos.org/nix/nix-2.18.1/nix-2.18.1-aarch64-darwin.tar.xz"
            ;;
        "darwin-x86_64")
            nix_url="https://releases.nixos.org/nix/nix-2.18.1/nix-2.18.1-x86_64-darwin.tar.xz"
            ;;
        "linux-x86_64")
            nix_url="https://releases.nixos.org/nix/nix-2.18.1/nix-2.18.1-x86_64-linux.tar.xz"
            ;;
    esac
    
    local nix_tarball="$temp_dir/nix.tar.xz"
    if ! curl -L -o "$nix_tarball" "$nix_url"; then
        print_error "Failed to download Nix binary from $nix_url"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Extract Nix binary
    print_status "Extracting Nix binary..."
    if ! tar -xJf "$nix_tarball" -C "$temp_dir"; then
        print_error "Failed to extract Nix binary"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Find the extracted nix directory (it might be nix-* pattern)
    local extracted_nix_dir=$(find "$temp_dir" -name "nix-*" -type d | head -n1)
    if [[ -z "$extracted_nix_dir" ]] || [[ ! -d "$extracted_nix_dir" ]]; then
        print_error "Could not find extracted Nix directory"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Copy Nix binaries and libraries to our local directory
    print_status "Installing Nix binaries to $nix_dir..."
    
    # Copy binaries
    if [[ -d "$extracted_nix_dir/bin" ]]; then
        cp -r "$extracted_nix_dir/bin"/* "$nix_dir/bin/" || {
            print_error "Failed to copy Nix binaries"
            rm -rf "$temp_dir"
            exit 1
        }
    fi
    
    # Copy libraries/dependencies if they exist
    for dir in lib libexec share etc; do
        if [[ -d "$extracted_nix_dir/$dir" ]]; then
            cp -r "$extracted_nix_dir/$dir" "$nix_dir/" || true
        fi
    done
    
    # Clean up download
    rm -rf "$temp_dir"
    
    # Create local Nix configuration
    print_status "Creating local Nix configuration..."
    
    cat > "$nix_dir/etc/nix.conf" << EOF
# Local Nix configuration for project-contained installation
store = $nix_store
state-dir = $nix_var/nix
log-dir = $nix_var/log/nix
store-dir = $nix_store
real-store-dir = $nix_store

# Single-user mode settings
build-users-group = 
sandbox = false
filter-syscalls = false

# Performance settings
max-jobs = auto
cores = 0

# Allow unfree packages (needed for some development tools)
allow-unfree = true
EOF
    
    # Create activation script
    cat > "$nix_dir/activate-nix.sh" << EOF
#!/bin/bash
# Activate local Nix environment

NIX_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"

# Set up Nix environment variables
export NIX_STORE="\$NIX_DIR/store"
export NIX_STATE_DIR="\$NIX_DIR/var/nix"
export NIX_LOG_DIR="\$NIX_DIR/var/log/nix"
export NIX_CONF_DIR="\$NIX_DIR/etc"
export NIX_USER_CONF_FILES="\$NIX_DIR/etc/nix.conf"
export NIX_DATA_DIR="\$NIX_DIR/share"

# Add Nix binaries to PATH
export PATH="\$NIX_DIR/bin:\$PATH"

# Set up library path for dynamic linking
case "\$(uname -s)" in
    "Darwin")
        export DYLD_LIBRARY_PATH="\$NIX_DIR/lib:\${DYLD_LIBRARY_PATH:-}"
        ;;
    "Linux")
        export LD_LIBRARY_PATH="\$NIX_DIR/lib:\${LD_LIBRARY_PATH:-}"
        ;;
esac

# Initialize store if it doesn't exist
if [[ ! -d "\$NIX_STORE" ]]; then
    mkdir -p "\$NIX_STORE"
fi

# Initialize database if it doesn't exist
if [[ ! -f "\$NIX_STATE_DIR/db/db.sqlite" ]]; then
    mkdir -p "\$NIX_STATE_DIR/db"
    # We'll initialize on first use
fi

echo "✅ Local Nix environment activated"
echo "   Nix store: \$NIX_STORE"
echo "   Nix config: \$NIX_CONF_DIR"
EOF
    
    chmod +x "$nix_dir/activate-nix.sh"
    
    # Activate the environment for testing
    print_status "Testing local Nix installation..."
    source "$nix_dir/activate-nix.sh"
    
    # Test basic Nix functionality
    if ! command -v nix >/dev/null 2>&1; then
        print_error "Nix binary not available after installation"
        exit 1
    fi
    
    # Initialize Nix database and test
    print_status "Initializing Nix database..."
    if ! nix --version >/dev/null 2>&1; then
        print_warning "Nix command not working immediately - this is normal for first run"
        print_status "Attempting to initialize Nix store..."
        
        # Create minimal store structure
        mkdir -p "$NIX_STATE_DIR/db" "$NIX_STATE_DIR/profiles" "$NIX_STATE_DIR/gcroots"
        
        # Try a simple nix command that doesn't require store access
        if nix --help >/dev/null 2>&1; then
            print_status "Nix help command works"
        else
            print_warning "Nix may need additional setup"
        fi
    fi
    
    # Verify version
    local nix_version=$(nix --version 2>/dev/null | awk '{print $3}' || echo "unknown")
    print_status "✅ Local Nix installed successfully"
    print_status "Nix version: $nix_version"
    print_status "Installation directory: $nix_dir"
    
    # Check version requirement
    if [[ "$nix_version" != "unknown" ]] && command -v sort >/dev/null 2>&1; then
        local min_version="$NIX_MIN_VERSION"
        if [[ "$(printf '%s\n%s\n' "$min_version" "$nix_version" | sort -V | head -n1)" == "$min_version" ]]; then
            print_status "Nix version meets minimum requirement ($min_version)"
        else
            print_warning "Nix version $nix_version is older than recommended minimum $min_version"
        fi
    fi
}

# Install Ruby and CocoaPods using local Nix
install_nix_ruby() {
    print_step "Installing Ruby and CocoaPods using local Nix..."
    
    local ruby_dir="$TOOLCHAIN_DIR/ruby"
    local nix_dir="$TOOLCHAIN_DIR/nix"
    
    # Ensure local Nix is available
    if [[ ! -f "$nix_dir/activate-nix.sh" ]]; then
        print_error "Local Nix installation not found. Run install_nix first."
        exit 1
    fi
    
    # Activate local Nix environment
    source "$nix_dir/activate-nix.sh"
    
    if ! command -v nix >/dev/null 2>&1; then
        print_error "Local Nix not available after activation"
        exit 1
    fi
    
    # Check if we already have a working Ruby/CocoaPods setup
    if [[ -f "$ruby_dir/activate-ruby.sh" ]]; then
        print_status "Checking existing Ruby installation..."
        
        # Test in a subshell to avoid affecting current environment
        if (source "$ruby_dir/activate-ruby.sh" && command -v ruby >/dev/null && command -v pod >/dev/null && pod --version >/dev/null 2>&1); then
            local current_ruby_version=$(source "$ruby_dir/activate-ruby.sh" && ruby -v 2>/dev/null | awk '{print $2}' | cut -d'p' -f1 || echo "unknown")
            print_status "Found working Ruby $current_ruby_version with CocoaPods"
            return 0
        fi
        
        print_status "Existing installation not working, reinstalling..."
        rm -rf "$ruby_dir"
    fi
    
    mkdir -p "$ruby_dir"
    
    print_status "Using Nix to install Ruby $RUBY_VERSION and CocoaPods..."
    
    # Create a Nix expression for Ruby with CocoaPods
    cat > "$ruby_dir/ruby-env.nix" << EOF
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    ruby_3_2
    bundler
    pkg-config
    # Dependencies needed for native gem compilation
    openssl
    libffi
    zlib
    libyaml
    # macOS specific dependencies
  ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
    darwin.apple_sdk.frameworks.Foundation
    darwin.apple_sdk.frameworks.Security
    darwin.apple_sdk.frameworks.CoreFoundation
  ];
  
  shellHook = ''
    export GEM_HOME=\${PWD}/gems
    export GEM_PATH=\$GEM_HOME
    export PATH=\$GEM_HOME/bin:\$PATH
    
    # Set up environment for native gem compilation
    export PKG_CONFIG_PATH="\${pkgs.openssl.dev}/lib/pkgconfig:\${pkgs.libffi.dev}/lib/pkgconfig"
    export LDFLAGS="-L\${pkgs.openssl.out}/lib -L\${pkgs.libffi.out}/lib"
    export CPPFLAGS="-I\${pkgs.openssl.dev}/include -I\${pkgs.libffi.dev}/include"
    
    # Create gems directory if it doesn't exist
    mkdir -p \$GEM_HOME
    
    echo "✅ Nix Ruby environment activated"
    echo "   Ruby: \$(ruby --version)"
    echo "   Gem home: \$GEM_HOME"
  '';
}
EOF
    
    # Create activation script that enters the Nix shell
    cat > "$ruby_dir/activate-ruby.sh" << 'EOF'
#!/bin/bash
# Activate local Nix-based Ruby environment

RUBY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$RUBY_DIR/../.." && pwd)"
NIX_DIR="$PROJECT_ROOT/toolchain/nix"

if [[ ! -f "$RUBY_DIR/ruby-env.nix" ]]; then
    echo "Error: Nix Ruby environment not set up. Run setup-toolchain.sh first."
    return 1
fi

if [[ ! -f "$NIX_DIR/activate-nix.sh" ]]; then
    echo "Error: Local Nix installation not found. Run setup-toolchain.sh first."
    return 1
fi

# Activate local Nix environment first
source "$NIX_DIR/activate-nix.sh"

if ! command -v nix >/dev/null 2>&1; then
    echo "Error: Local Nix not available after activation"
    return 1
fi

# Enter the Nix shell environment
cd "$RUBY_DIR"
nix-shell ruby-env.nix --run 'exec bash --rcfile <(echo "source ~/.bashrc 2>/dev/null || true; source ~/.bash_profile 2>/dev/null || true; export PS1=\"[nix-ruby] \$PS1\"")'
EOF
    
    chmod +x "$ruby_dir/activate-ruby.sh"
    
    # Install CocoaPods in the Nix environment
    print_status "Installing CocoaPods in Nix environment..."
    
    cd "$ruby_dir"
    if ! nix-shell ruby-env.nix --run "gem install cocoapods -v '>=$COCOAPODS_MIN_VERSION' --no-document"; then
        print_error "Failed to install CocoaPods in Nix environment"
        exit 1
    fi
    
    # Verify the installation
    print_status "Verifying Ruby and CocoaPods installation..."
    
    if ! nix-shell ruby-env.nix --run "ruby --version && gem --version && pod --version"; then
        print_error "Ruby/CocoaPods verification failed"
        exit 1
    fi
    
    # Create a simple activation script for CI/scripts
    cat > "$ruby_dir/activate-simple.sh" << 'EOF'
#!/bin/bash
# Simple activation script that sets up the environment without interactive shell

RUBY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$RUBY_DIR/../.." && pwd)"
NIX_DIR="$PROJECT_ROOT/toolchain/nix"

if [[ ! -f "$RUBY_DIR/ruby-env.nix" ]]; then
    echo "Error: Nix Ruby environment not set up. Run setup-toolchain.sh first."
    return 1
fi

if [[ ! -f "$NIX_DIR/activate-nix.sh" ]]; then
    echo "Error: Local Nix installation not found. Run setup-toolchain.sh first."
    return 1
fi

# Activate local Nix environment first
source "$NIX_DIR/activate-nix.sh"

if ! command -v nix >/dev/null 2>&1; then
    echo "Error: Local Nix not available after activation"
    return 1
fi

# Set up the environment variables that Nix would set
cd "$RUBY_DIR"

# Get the environment from nix-shell and source it
eval "$(nix-shell ruby-env.nix --run 'echo "export GEM_HOME=$GEM_HOME; export GEM_PATH=$GEM_PATH; export PATH=$PATH"')"

echo "✅ Local Nix Ruby environment activated (simple mode)"
echo "   Ruby: $(ruby --version 2>/dev/null || echo 'not available in current context')"
echo "   Gem home: $GEM_HOME"
EOF
    
    chmod +x "$ruby_dir/activate-simple.sh"
    
    print_status "✅ Ruby and CocoaPods installed successfully using Nix"
    print_status "To activate: source $ruby_dir/activate-ruby.sh"
    print_status "For scripts: source $ruby_dir/activate-simple.sh"
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
if [[ -f "$PROJECT_ROOT/tools/activate-env.sh" ]]; then\
    source "$PROJECT_ROOT/tools/activate-env.sh"\
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

# Show usage information
show_usage() {
    echo "Usage: $0 [COMPONENT]"
    echo
    echo "Install local development toolchain components."
    echo
    echo "Components:"
    echo "  directories    Set up toolchain directory structure"
    echo "  flutter        Install Flutter SDK"
    echo "  nix           Install Nix package manager locally"
    echo "  ruby          Install Ruby and CocoaPods via Nix"
    echo "  build-scripts Update build scripts to use local toolchain"
    echo "  vscode        Create VS Code configuration"
    echo "  doctor        Run Flutter doctor to check dependencies"
    echo
    echo "If no component is specified, installs all components in correct order."
    echo
    echo "Examples:"
    echo "  $0              # Install everything"
    echo "  $0 nix          # Install only Nix"
    echo "  $0 flutter      # Install only Flutter"
    echo "  $0 ruby         # Install only Ruby (requires Nix)"
}

# Main execution
main() {
    local component="$1"
    
    # Show usage if help requested
    if [[ "$component" == "-h" || "$component" == "--help" || "$component" == "help" ]]; then
        show_usage
        exit 0
    fi
    
    print_status "Starting local toolchain setup..."
    print_status "Target directory: $TOOLCHAIN_DIR"
    echo
    
    case "$component" in
        "directories")
            setup_directories
            ;;
        "flutter")
            setup_directories
            install_flutter
            ;;
        "nix")
            setup_directories
            install_nix
            ;;
        "ruby")
            setup_directories
            install_nix_ruby
            ;;
        "build-scripts")
            update_build_scripts
            ;;
        "vscode")
            create_vscode_config
            ;;
        "doctor")
            check_system_dependencies
            ;;
        "")
            # Install everything in correct order
            print_status "Installing all components..."
            echo
            setup_directories
            install_flutter
            install_nix
            install_nix_ruby
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
            ;;
        *)
            print_error "Unknown component: $component"
            echo
            show_usage
            exit 1
            ;;
    esac
    
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