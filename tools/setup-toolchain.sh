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

# Run Ruby dependencies setup
setup_ruby_deps() {
    print_step "Setting up Ruby build dependencies..."
    if [[ -f "$SCRIPT_DIR/setup-ruby-deps.sh" ]]; then
        "$SCRIPT_DIR/setup-ruby-deps.sh"
    else
        print_warning "Ruby dependencies script not found, skipping..."
    fi
}

# Run Ruby setup
setup_ruby() {
    print_step "Setting up Ruby and CocoaPods..."
    "$SCRIPT_DIR/setup-ruby.sh"
}

# Run Flutter setup
setup_flutter() {
    print_step "Setting up Flutter..."
    "$SCRIPT_DIR/setup-flutter.sh"
}


# Run Flutter doctor to check system dependencies
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
    
    case "$component" in
        "directories")
            setup_directories
            ;;
        "ruby-deps")
            setup_directories
            setup_ruby_deps
            ;;
        "ruby")
            setup_directories
            setup_ruby
            ;;
        "flutter")
            setup_directories
            setup_flutter
            ;;
        "doctor")
            check_system_dependencies
            ;;
        "")
            # Install everything in correct dependency order
            print_status "Installing all components in dependency order..."
            echo
            setup_directories
            setup_ruby_deps
            setup_ruby
            setup_flutter
            
            echo
            print_status "✅ Local toolchain setup complete!"
            echo
            echo "Next steps:"
            echo "1. Activate the environment:"
            echo "   🐚 Bash/Zsh: source ./tools/activate-env.sh"
            echo "   🐠 Fish:     source ./tools/activate-env.fish"
            echo "   💡 Helper:   ./tools/activate (shows instructions)"
            echo
            echo "2. Verify installation:"
            echo "   ruby --version"
            echo "   pod --version"
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