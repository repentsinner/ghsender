#!/bin/bash
# Cross-Platform Build Script for macOS/Linux
# Handles all platform-specific build tasks via CLI tools

set -e  # Exit on any error
# Activate local toolchain environment
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$PROJECT_ROOT/toolchain/scripts/activate-env.sh" ]]; then
    source "$PROJECT_ROOT/toolchain/scripts/activate-env.sh"
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== G-Code Sender Build Script ===${NC}"
echo "Platform: $(uname -s)"
echo "Architecture: $(uname -m)"
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

# Check Flutter installation
check_flutter() {
    print_status "Checking Flutter installation..."
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter not found. Please install Flutter first."
        exit 1
    fi
    
    flutter --version
    echo
}

# Get dependencies
get_dependencies() {
    print_status "Getting Flutter dependencies..."
    flutter pub get
    echo
}

# Run tests
run_tests() {
    print_status "Running tests..."
    flutter analyze
    flutter test
    echo
}

# Build for specific platform
build_platform() {
    local platform=$1
    print_status "Building for $platform..."
    
    case $platform in
        "macos")
            flutter build macos --release
            print_status "macOS build completed: build/macos/Build/Products/Release/"
            ;;
        "ios")
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # iOS build only available on macOS
                flutter build ios --release
                print_status "iOS build completed: build/ios/Release-iphoneos/"
            else
                print_warning "iOS builds only available on macOS"
            fi
            ;;
        "android")
            flutter build apk --release
            print_status "Android APK completed: build/app/outputs/flutter-apk/"
            ;;
        "linux")
            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                flutter build linux --release
                print_status "Linux build completed: build/linux/x64/release/bundle/"
            else
                print_warning "Linux builds only available on Linux"
            fi
            ;;
        *)
            print_error "Unknown platform: $platform"
            echo "Available platforms: macos, ios, android, linux"
            exit 1
            ;;
    esac
}

# Main execution
main() {
    local command=${1:-"help"}
    
    case $command in
        "setup")
            print_status "Setting up development environment..."
            check_flutter
            get_dependencies
            ;;
        "test")
            check_flutter
            get_dependencies
            run_tests
            ;;
        "build")
            local platform=${2:-""}
            if [[ -z "$platform" ]]; then
                print_error "Please specify platform: macos, ios, android, linux"
                exit 1
            fi
            check_flutter
            get_dependencies
            run_tests
            build_platform "$platform"
            ;;
        "all")
            check_flutter
            get_dependencies
            run_tests
            
            # Build all platforms available on current OS
            if [[ "$OSTYPE" == "darwin"* ]]; then
                build_platform "macos"
                build_platform "ios"
            fi
            build_platform "android"
            ;;
        "clean")
            print_status "Cleaning build artifacts..."
            flutter clean
            rm -rf build/
            ;;
        "help"|*)
            echo "Usage: $0 <command> [options]"
            echo
            echo "Commands:"
            echo "  setup          - Setup development environment"
            echo "  test           - Run tests and analysis"
            echo "  build <platform> - Build for specific platform (macos, ios, android, linux)"
            echo "  all            - Build for all available platforms"
            echo "  clean          - Clean build artifacts"
            echo "  help           - Show this help message"
            echo
            echo "Examples:"
            echo "  $0 setup"
            echo "  $0 test"
            echo "  $0 build macos"
            echo "  $0 build ios"
            echo "  $0 all"
            ;;
    esac
}

# Run main function with all arguments
main "$@"