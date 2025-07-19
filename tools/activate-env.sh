#!/bin/bash
# Activate local toolchain environment
# Usage: source ./tools/activate-env.sh

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script must be sourced, not executed directly"
    echo "Usage: source ./tools/activate-env.sh"
    exit 1
fi

# Get project root using script location
PROJECT_ROOT="/Users/ritchie/development/ghsender"
TOOLCHAIN_DIR="$PROJECT_ROOT/toolchain"

# Add Flutter to PATH
export FLUTTER_HOME="$TOOLCHAIN_DIR/flutter"
export PATH="$FLUTTER_HOME/bin:$PATH"

# Add CMake to PATH
export CMAKE_HOME="$TOOLCHAIN_DIR/cmake"
if [[ -d "$CMAKE_HOME/CMake.app/Contents/bin" ]]; then
    # macOS CMake app bundle
    export PATH="$CMAKE_HOME/CMake.app/Contents/bin:$PATH"
elif [[ -d "$CMAKE_HOME/bin" ]]; then
    # Linux CMake binary
    export PATH="$CMAKE_HOME/bin:$PATH"
fi

# Set Flutter/Dart cache directories to local toolchain
export PUB_CACHE="$TOOLCHAIN_DIR/cache/pub"
export FLUTTER_ROOT="$FLUTTER_HOME"

# Create cache directories if they don't exist
mkdir -p "$PUB_CACHE"

echo "✅ Activated local toolchain environment"
echo "   Flutter: $(which flutter 2>/dev/null || echo 'flutter not found')"
echo "   Dart: $(which dart 2>/dev/null || echo 'dart not found')"
echo "   CMake: $(which cmake 2>/dev/null || echo 'cmake not found')"
echo "   Pub Cache: $PUB_CACHE"