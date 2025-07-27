#!/usr/bin/env fish
# Activate local toolchain environment for Fish shell
# This script sets up PATH and environment variables for the local toolchain

# Get project root directory
set SCRIPT_DIR (dirname (status --current-filename))
set PROJECT_ROOT (cd $SCRIPT_DIR/.. && pwd)
set TOOLCHAIN_DIR $PROJECT_ROOT/toolchain

# Color output functions
function print_status
    echo -e "\033[0;32m[INFO]\033[0m $argv"
end

function print_warning
    echo -e "\033[1;33m[WARN]\033[0m $argv"
end

function print_error
    echo -e "\033[0;31m[ERROR]\033[0m $argv"
end

# Check if we have a valid project structure
if not test -f $PROJECT_ROOT/tools/setup-toolchain.sh
    print_error "Could not find setup-toolchain.sh - are you in the right directory?"
    print_error "Project root detected as: $PROJECT_ROOT"
    exit 1
end

# Add Flutter to PATH
if test -d $TOOLCHAIN_DIR/flutter/bin
    set -gx PATH $TOOLCHAIN_DIR/flutter/bin $PATH
    set -gx FLUTTER_ROOT $TOOLCHAIN_DIR/flutter
    print_status "Flutter added to PATH"
else
    print_warning "Flutter not found in toolchain directory"
    print_warning "Run ./tools/setup-toolchain.sh first"
end

# Set up pub cache
set -gx PUB_CACHE $TOOLCHAIN_DIR/cache/pub
mkdir -p $PUB_CACHE

# Activate asdf Ruby environment if available
set ASDF_DIR $TOOLCHAIN_DIR/asdf
set ASDF_DATA_DIR $TOOLCHAIN_DIR/asdf-data

if test -d $ASDF_DIR; and test -f $ASDF_DIR/asdf.fish
    # Set up asdf environment
    set -gx ASDF_DIR $ASDF_DIR
    set -gx ASDF_DATA_DIR $ASDF_DATA_DIR
    
    # Source asdf for Fish
    source $ASDF_DIR/asdf.fish
    
    print_status "Ruby/CocoaPods environment activated via asdf"
else
    print_warning "Ruby/CocoaPods not available"
    print_warning "Run ./tools/setup-toolchain.sh to install"
end

print_status "Local toolchain environment activated"
print_status "Project root: $PROJECT_ROOT"
print_status "Toolchain directory: $TOOLCHAIN_DIR"

# Show available tools
echo ""
echo "Available tools:"

if command -v flutter >/dev/null 2>&1
    echo "  ✅ Flutter: "(flutter --version | head -n1)
else
    echo "  ❌ Flutter: not available"
end

if command -v dart >/dev/null 2>&1
    echo "  ✅ Dart: "(dart --version | head -n1)
else
    echo "  ❌ Dart: not available"
end

if command -v ruby >/dev/null 2>&1
    echo "  ✅ Ruby: "(ruby --version | cut -d' ' -f1-2)
else
    echo "  ❌ Ruby: not available"
end

if command -v pod >/dev/null 2>&1
    echo "  ✅ CocoaPods: "(pod --version 2>/dev/null; or echo 'version check failed')
else
    echo "  ❌ CocoaPods: not available"
end