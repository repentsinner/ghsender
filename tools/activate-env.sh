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

# Try to activate Nix Ruby environment if available
if [[ -f "$TOOLCHAIN_DIR/ruby/activate-simple.sh" ]]; then
    source "$TOOLCHAIN_DIR/ruby/activate-simple.sh"
elif [[ -f "$TOOLCHAIN_DIR/ruby/activate-ruby.sh" ]]; then
    print_status "Ruby environment available (interactive mode)"
    print_status "Run: source $TOOLCHAIN_DIR/ruby/activate-ruby.sh"
else
    print_warning "Ruby/CocoaPods not available"
    print_warning "Run ./tools/setup-toolchain.sh to install"
fi

# Source local Nix if available
if [[ -f "$TOOLCHAIN_DIR/nix/activate-nix.sh" ]]; then
    source "$TOOLCHAIN_DIR/nix/activate-nix.sh"
    if command -v nix >/dev/null 2>&1; then
        print_status "Local Nix package manager available"
    else
        print_warning "Local Nix found but not working properly"
    fi
elif command -v nix >/dev/null 2>&1; then
    print_status "System Nix package manager available (consider switching to local)"
elif [[ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
    source "$HOME/.nix-profile/etc/profile.d/nix.sh"
    print_status "System Nix environment loaded (consider switching to local)"
elif [[ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]]; then
    source "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
    print_status "System Nix daemon environment loaded (consider switching to local)"
else
    print_warning "Nix not available - Ruby/CocoaPods may not work"
    print_warning "Run ./tools/setup-toolchain.sh to install local Nix"
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

if command -v nix >/dev/null 2>&1; then
    echo "  ✅ Nix: $(nix --version 2>/dev/null | head -n1 || echo 'version check failed')"
else
    echo "  ❌ Nix: not available"
fi