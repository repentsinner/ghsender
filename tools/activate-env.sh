#!/bin/bash
# Activate local toolchain environment
# This script sets up PATH and environment variables for the local toolchain

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLCHAIN_DIR="$PROJECT_ROOT/toolchain"

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we have a valid project structure
if [[ ! -f "$PROJECT_ROOT/tools/setup-toolchain.sh" ]]; then
    print_error "Could not find setup-toolchain.sh - are you in the right directory?"
    print_error "Project root detected as: $PROJECT_ROOT"
    return 1 2>/dev/null || exit 1
fi

# Add Flutter to PATH
if [[ -d "$TOOLCHAIN_DIR/flutter/bin" ]]; then
    export PATH="$TOOLCHAIN_DIR/flutter/bin:$PATH"
    export FLUTTER_ROOT="$TOOLCHAIN_DIR/flutter"
    print_status "Flutter added to PATH"
else
    print_warning "Flutter not found in toolchain directory"
    print_warning "Run ./tools/setup-toolchain.sh first"
fi

# Set up pub cache
export PUB_CACHE="$TOOLCHAIN_DIR/cache/pub"
mkdir -p "$PUB_CACHE"

# Activate asdf Ruby environment if available
ASDF_DIR="$TOOLCHAIN_DIR/asdf"
ASDF_DATA_DIR="$TOOLCHAIN_DIR/asdf-data"

if [[ -d "$ASDF_DIR" && -f "$ASDF_DIR/asdf.sh" ]]; then
    # Set up asdf environment
    export ASDF_DIR="$ASDF_DIR"
    export ASDF_DATA_DIR="$ASDF_DATA_DIR"
    
    # Source asdf
    source "$ASDF_DIR/asdf.sh"
    
    # Add asdf completions to bash if available (suppress errors)
    if [[ -f "$ASDF_DIR/completions/asdf.bash" ]]; then
        source "$ASDF_DIR/completions/asdf.bash" 2>/dev/null || true
    fi
    
    print_status "Ruby/CocoaPods environment activated via asdf"
else
    print_warning "Ruby/CocoaPods not available"
    print_warning "Run ./tools/setup-toolchain.sh to install"
fi

print_status "Local toolchain environment activated"
print_status "Project root: $PROJECT_ROOT"
print_status "Toolchain directory: $TOOLCHAIN_DIR"

# Show available tools
echo
echo "Available tools:"
if command -v flutter >/dev/null 2>&1; then
    echo "  ✅ Flutter: $(flutter --version | head -n1)"
else
    echo "  ❌ Flutter: not available"
fi

if command -v dart >/dev/null 2>&1; then
    echo "  ✅ Dart: $(dart --version | head -n1)"
else
    echo "  ❌ Dart: not available"
fi

if command -v ruby >/dev/null 2>&1; then
    echo "  ✅ Ruby: $(ruby --version | cut -d' ' -f1-2)"
else
    echo "  ❌ Ruby: not available"
fi

if command -v pod >/dev/null 2>&1; then
    echo "  ✅ CocoaPods: $(pod --version 2>/dev/null || echo 'version check failed')"
else
    echo "  ❌ CocoaPods: not available"
fi

