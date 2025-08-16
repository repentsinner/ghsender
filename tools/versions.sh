#!/bin/bash
# Tool versions for local toolchain
# Single source of truth for all development dependencies
# This file can be sourced directly by shell scripts

# Flutter/Dart versions
# flutter_gpu requires us to be on the main channel
export FLUTTER_CHANNEL="main"
export FLUTTER_VERSION="3.33.0"  # Target version on main channel

# Platform tool minimum versions
export XCODE_MIN_VERSION="15.0"
export ANDROID_SDK_VERSION="34.0.0"
export COCOAPODS_MIN_VERSION="1.16.2"

# Node.js (if needed for web builds)
export NODE_VERSION="20.10.0"

# Ruby version for CocoaPods
export RUBY_VERSION="3.4.5"
export RUBY_GEMS_VERSION="3.7.1"

# Ruby build dependencies (compiled from source)
export OPENSSL_VERSION="3.5.1"
export READLINE_VERSION="8.2"
export LIBYAML_VERSION="0.2.5"
export GMP_VERSION="6.3.0"

# Build tool versions
export CMAKE_VERSION="3.28.1"
export CMAKE_MIN_VERSION="3.18.0"

# GLSL shader validation tool (using main-tot release)
export GLSLANG_SOURCE="main-tot"

# Function to print version info (optional helper)
print_versions() {
    echo "=== Toolchain Versions ==="
    echo "Flutter Channel: $FLUTTER_CHANNEL"
    echo "Flutter Version: $FLUTTER_VERSION"
    echo "CMake Version: $CMAKE_VERSION"
    echo "glslang Source: $GLSLANG_SOURCE"
    echo "Ruby Version: $RUBY_VERSION"
    echo "=========================="
}