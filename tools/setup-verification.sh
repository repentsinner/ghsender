#!/bin/bash
# Development Environment Verification for Phase 0
# Run this script after installing Flutter tooling

echo "=== ghSender Development Environment Check ==="
echo "Date: $(date)"
echo

# Check Flutter installation
echo "🔍 Checking Flutter installation..."
if command -v flutter &> /dev/null; then
    flutter --version
    echo "✅ Flutter installed"
else
    echo "❌ Flutter not found - please install Flutter SDK"
    echo "   Download from: https://docs.flutter.dev/get-started/install/macos"
fi
echo

# Check Dart installation (comes with Flutter)
echo "🔍 Checking Dart installation..."
if command -v dart &> /dev/null; then
    dart --version
    echo "✅ Dart installed"
else
    echo "❌ Dart not found - usually comes with Flutter"
fi
echo

# Check development tools
echo "🔍 Checking development tools..."
tools=("git" "code" "telnet")
for tool in "${tools[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo "✅ $tool installed"
    else
        echo "❌ $tool not found"
    fi
done
echo

# Run Flutter doctor
echo "🔍 Running Flutter doctor..."
if command -v flutter &> /dev/null; then
    flutter doctor
else
    echo "❌ Cannot run flutter doctor - Flutter not installed"
fi
echo

# Check project structure
echo "🔍 Checking project structure..."
required_dirs=("docs" "team" "tools")
for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo "✅ $dir directory exists"
    else
        echo "❌ $dir directory missing"
    fi
done
echo

# Phase 0 readiness check
echo "🎯 Phase 0 Readiness Assessment (macOS Desktop Development):"
echo "Required for Phase 0 Technology Spikes:"
echo "  [ ] Flutter SDK installed and working"
echo "  [ ] VS Code with Flutter extension"
echo "  [ ] git working"
echo "  [ ] Network tools (telnet/netcat) for TCP testing"
echo "  [ ] grblHAL simulator or test TCP server"
echo
echo "📱 Platform Strategy for Phase 0:"
echo "  • Target: macOS desktop development (reduces complexity)"
echo "  • iPad deployment validation: Phase 1"
echo "  • Benefits: Faster iteration, better debugging, no mobile constraints"
echo
echo "Once all items are checked, you can begin:"
echo "  1. Real-time Communication Spike (desktop Flutter app)"
echo "  2. Graphics Performance Spike (desktop rendering)"
echo "  3. State Management Stress Test (desktop performance)"
echo
echo "=== End Verification ==="