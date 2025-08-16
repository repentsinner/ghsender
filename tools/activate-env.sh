#!/bin/bash
# Activate local toolchain environment
# Usage: source ./tools/activate-env.sh

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script must be sourced, not executed directly"
    echo "Usage: source ./tools/activate-env.sh"
    exit 1
fi

# Get project root - assume we're being sourced from project root
# This is more reliable than trying to detect script location when sourced
PROJECT_ROOT="$(pwd)"
TOOLCHAIN_DIR="$PROJECT_ROOT/toolchain"

# Source version configuration
if [[ -f "$PROJECT_ROOT/tools/versions.sh" ]]; then
    source "$PROJECT_ROOT/tools/versions.sh"
fi

# Add local toolchain bin directory to PATH (for direct tool links)
export PATH="$TOOLCHAIN_DIR/bin:$PATH"

# Add Flutter to PATH
export FLUTTER_HOME="$TOOLCHAIN_DIR/flutter"
export PATH="$FLUTTER_HOME/bin:$PATH"

# Add ASDF managed tools to PATH (includes cmake, ruby, etc.)
export ASDF_DIR="$TOOLCHAIN_DIR/asdf"
export ASDF_DATA_DIR="$TOOLCHAIN_DIR/asdf-data"
export PATH="$ASDF_DATA_DIR/shims:$PATH"

# Add CMake to PATH (fallback for direct installation)
export CMAKE_HOME="$TOOLCHAIN_DIR/cmake"
if [[ -d "$CMAKE_HOME/CMake.app/Contents/bin" ]]; then
    # macOS CMake app bundle
    export PATH="$CMAKE_HOME/CMake.app/Contents/bin:$PATH"
elif [[ -d "$CMAKE_HOME/bin" ]]; then
    # Linux CMake binary
    export PATH="$CMAKE_HOME/bin:$PATH"
fi

# Add glslangValidator to PATH
export GLSLANG_HOME="$TOOLCHAIN_DIR/glslang"
if [[ -d "$GLSLANG_HOME/bin" ]]; then
    export PATH="$GLSLANG_HOME/bin:$PATH"
    # glslang added to PATH
else
    echo "   WARNING: glslang directory not found at $GLSLANG_HOME/bin"
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
echo "   glslangValidator: $(which glslangValidator 2>/dev/null || echo 'glslangValidator not found')"
echo "   Pub Cache: $PUB_CACHE"