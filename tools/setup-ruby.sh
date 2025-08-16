#!/bin/bash
# Ruby and CocoaPods installation script using asdf for ghSender project
# Installs Ruby and CocoaPods locally in toolchain/ directory

set -e  # Exit on any error

# Load shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-utils.sh"

# Load configuration
load_versions

# Set up project paths
PROJECT_ROOT="$(get_project_root)"
TOOLCHAIN_DIR="$PROJECT_ROOT/toolchain"
ASDF_DIR="$TOOLCHAIN_DIR/asdf"
ASDF_DATA_DIR="$TOOLCHAIN_DIR/asdf-data"

# Verify requirements
verify_requirements

# Check for build dependencies on macOS
check_build_dependencies() {
    if is_macos; then
        local missing_deps=()
        
        # Check for Xcode command line tools
        if ! xcode-select -p >/dev/null 2>&1; then
            print_warning "Xcode command line tools not found"
            print_warning "Install with: xcode-select --install"
        fi
        
        # Check for Homebrew (recommended for build dependencies)
        if ! command_exists brew; then
            print_warning "Homebrew not found - you may need to install build dependencies manually"
            print_warning "Recommended: install Homebrew and run: brew install openssl readline libyaml gmp"
        else
            # Check for common build dependencies
            for dep in openssl readline libyaml gmp; do
                if ! brew list "$dep" >/dev/null 2>&1; then
                    missing_deps+=("$dep")
                fi
            done
            
            if [[ ${#missing_deps[@]} -gt 0 ]]; then
                print_warning "Missing build dependencies: ${missing_deps[*]}"
                print_warning "Install with: brew install ${missing_deps[*]}"
                print_warning "Ruby compilation may fail without these dependencies"
            fi
        fi
    fi
}

# Install asdf locally
install_asdf() {
    if [[ ! -d "$ASDF_DIR" ]] || [[ ! -f "$ASDF_DIR/asdf.sh" ]]; then
        print_status "Installing asdf locally..."
        rm -rf "$ASDF_DIR"  # Clean up any incomplete installation
        git clone https://github.com/asdf-vm/asdf.git "$ASDF_DIR" --branch v0.14.0
        print_status "asdf cloned successfully"
    else
        print_status "asdf already installed"
    fi
}

# Set up asdf environment
setup_asdf_environment() {
    export ASDF_DIR="$ASDF_DIR"
    export ASDF_DATA_DIR="$ASDF_DATA_DIR"
    
    # Source asdf
    source "$ASDF_DIR/asdf.sh"
    
    # Create asdf data directory
    mkdir -p "$ASDF_DATA_DIR"
    
    print_status "asdf environment activated"
}

# Install Ruby plugin for asdf
install_ruby_plugin() {
    if ! asdf plugin list | grep -q ruby; then
        print_status "Adding Ruby plugin to asdf..."
        asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git
        print_status "Ruby plugin added successfully"
    else
        print_status "Ruby plugin already installed"
    fi
}

# Install Ruby using asdf
install_ruby() {
    if asdf list ruby | grep -q "$RUBY_VERSION"; then
        print_status "Ruby $RUBY_VERSION already installed"
    else
        print_status "Installing Ruby $RUBY_VERSION..."
        
        # Set up environment for compiling Ruby on macOS
        if is_macos; then
            # Check if we have local build dependencies first
            local deps_activation_script="$PROJECT_ROOT/toolchain/deps/activate-ruby-deps.sh"
            if [[ -f "$deps_activation_script" ]]; then
                print_status "Using local build dependencies"
                source "$deps_activation_script"
            else
                # Fallback to Homebrew if available
                local openssl_path
                if command_exists brew; then
                    openssl_path=$(brew --prefix openssl@3 2>/dev/null || brew --prefix openssl 2>/dev/null || echo "/usr/local/opt/openssl")
                else
                    openssl_path="/usr/local/opt/openssl"
                fi
                export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$openssl_path"
            fi
        fi
        
        if ! asdf install ruby "$RUBY_VERSION"; then
            print_error "Failed to install Ruby $RUBY_VERSION"
            if is_macos; then
                print_error "You may need to install build dependencies:"
                print_error "  xcode-select --install"
                print_error "  brew install openssl readline libyaml gmp"
            else
                print_error "You may need to install build dependencies:"
                print_error "  sudo apt-get install build-essential libssl-dev libreadline-dev libyaml-dev libgmp-dev"
            fi
            exit 1
        fi
        print_status "Ruby $RUBY_VERSION installed successfully"
    fi
}

# Set local Ruby version
set_local_ruby_version() {
    cd "$PROJECT_ROOT"
    asdf local ruby "$RUBY_VERSION"
    print_status "Set local Ruby version to $RUBY_VERSION"
}

# Verify Ruby installation
verify_ruby_installation() {
    local installed_ruby_version=$(asdf current ruby 2>/dev/null | awk '{print $2}' || echo "unknown")
    if [[ "$installed_ruby_version" == "unknown" ]]; then
        print_error "Ruby installation verification failed"
        exit 1
    fi
    print_status "Ruby version verified: $installed_ruby_version"
}

# Install CocoaPods
install_cocoapods() {
    if gem list -i cocoapods >/dev/null 2>&1; then
        local current_pod_version=$(gem list cocoapods | grep cocoapods | awk '{print $2}' | tr -d '()')
        print_status "CocoaPods already installed: $current_pod_version"
    else
        print_status "Installing CocoaPods..."
        if ! gem install cocoapods -v ">=$COCOAPODS_MIN_VERSION" --no-document; then
            print_error "Failed to install CocoaPods"
            exit 1
        fi
        print_status "CocoaPods installed successfully"
    fi
}

# Verify CocoaPods installation
verify_cocoapods_installation() {
    if ! command -v pod >/dev/null 2>&1; then
        print_error "CocoaPods verification failed - 'pod' command not found"
        exit 1
    fi
    
    local pod_version=$(pod --version 2>/dev/null || echo "unknown")
    print_status "CocoaPods version verified: $pod_version"
}

# Main Ruby installation function
install_ruby_and_cocoapods() {
    print_step "Installing Ruby and CocoaPods using local asdf..."
    
    # Check build dependencies
    check_build_dependencies
    
    # Install and set up asdf
    install_asdf
    setup_asdf_environment
    
    # Install Ruby plugin and Ruby itself
    install_ruby_plugin
    install_ruby
    
    # Set up Ruby environment
    set_local_ruby_version
    verify_ruby_installation
    
    # Install and verify CocoaPods
    install_cocoapods
    verify_cocoapods_installation
    
    print_status "✅ Ruby and CocoaPods installed successfully using asdf"
    print_status "To activate: source ./tools/activate-env.sh (or activate-env.fish for Fish shell)"
}

# Show usage information
show_usage() {
    echo "Usage: $0"
    echo
    echo "Install Ruby and CocoaPods locally using asdf in the project's toolchain directory."
    echo
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo
    echo "Configuration is loaded from tools/versions.sh"
    echo
    echo "Requirements:"
    echo "  - git"
    echo "  - curl"
    echo "  - On macOS: Xcode command line tools (xcode-select --install)"
    echo "  - On macOS: Recommended: brew install openssl readline libyaml gmp"
}

# Main execution
main() {
    case "${1:-}" in
        -h|--help|help)
            show_usage
            exit 0
            ;;
        "")
            echo -e "${GREEN}=== Ruby Setup ===${NC}"
            echo "Project: ghSender"
            echo "Target: $ASDF_DIR"
            echo "Platform: $(uname -s) $(uname -m)"
            echo
            
            setup_directories
            install_ruby_and_cocoapods
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