#!/bin/bash
# Cross-Platform Build Script for ghSender Monorepo
# Handles all platform-specific build tasks for multiple Flutter projects

set -e  # Exit on any error
# Activate local toolchain environment
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$PROJECT_ROOT/tools/activate-env.sh" ]]; then
    source "$PROJECT_ROOT/tools/activate-env.sh"
fi
# Activate local toolchain environment
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$PROJECT_ROOT/tools/activate-env.sh" ]]; then
    source "$PROJECT_ROOT/tools/activate-env.sh"
fi
# Activate local toolchain environment
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$PROJECT_ROOT/toolchain/scripts/activate-env.sh" ]]; then
    source "$PROJECT_ROOT/toolchain/scripts/activate-env.sh"
fi

# Activate local toolchain environment
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$PROJECT_ROOT/tools/activate-env.sh" ]]; then
    source "$PROJECT_ROOT/tools/activate-env.sh"
fi

cd "$PROJECT_ROOT"

# Define Flutter projects in the monorepo
FLUTTER_PROJECTS=(
    "spike/communication-spike"
    "spike/graphics_performance_spike" 
    "spike/state_management_spike"
)

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== ghSender Build Script ===${NC}"
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

# Monorepo functions for handling multiple Flutter projects
get_dependencies_all() {
    print_status "Getting dependencies for all Flutter projects..."
    for project in "${FLUTTER_PROJECTS[@]}"; do
        if [[ -d "$project" && -f "$project/pubspec.yaml" ]]; then
            print_status "Getting dependencies for $project..."
            (cd "$project" && flutter pub get)
        else
            print_warning "Skipping $project - not a Flutter project"
        fi
    done
    echo
}

run_tests_all() {
    print_status "Running tests for all Flutter projects..."
    local all_passed=true
    
    for project in "${FLUTTER_PROJECTS[@]}"; do
        if [[ -d "$project" && -f "$project/pubspec.yaml" ]]; then
            print_status "Testing $project..."
            if ! (cd "$project" && flutter analyze && flutter test --timeout=60s); then
                print_error "Tests failed for $project"
                all_passed=false
            else
                print_status "Tests passed for $project"
            fi
        else
            print_warning "Skipping $project - not a Flutter project"
        fi
    done
    
    if [[ "$all_passed" == true ]]; then
        print_status "All tests passed!"
    else
        print_error "Some tests failed"
        exit 1
    fi
    echo
}

build_platform_all() {
    local platform=$1
    print_status "Building all Flutter projects for $platform..."
    
    for project in "${FLUTTER_PROJECTS[@]}"; do
        if [[ -d "$project" && -f "$project/pubspec.yaml" ]]; then
            print_status "Building $project for $platform..."
            (cd "$project" && build_platform "$platform")
        else
            print_warning "Skipping $project - not a Flutter project"
        fi
    done
    echo
}

clean_all() {
    print_status "Cleaning all Flutter projects..."
    for project in "${FLUTTER_PROJECTS[@]}"; do
        if [[ -d "$project" && -f "$project/pubspec.yaml" ]]; then
            print_status "Cleaning $project..."
            (cd "$project" && flutter clean && rm -rf build/)
        else
            print_warning "Skipping $project - not a Flutter project"
        fi
    done
    echo
}

# Main execution
main() {
    local command=${1:-"help"}
    
    case $command in
        "setup")
            print_status "Setting up development environment for all projects..."
            check_flutter
            get_dependencies_all
            ;;
        "test")
            check_flutter
            get_dependencies_all
            run_tests_all
            ;;
        "test-single")
            local project=${2:-""}
            if [[ -z "$project" ]]; then
                print_error "Please specify project: communication-spike, graphics_performance_spike, state_management_spike"
                exit 1
            fi
            check_flutter
            if [[ -d "spike/$project" ]]; then
                (cd "spike/$project" && flutter pub get && flutter analyze && flutter test --timeout=60s)
            else
                print_error "Project spike/$project not found"
                exit 1
            fi
            ;;
        "build")
            local platform=${2:-""}
            if [[ -z "$platform" ]]; then
                print_error "Please specify platform: macos, ios, android, linux"
                exit 1
            fi
            check_flutter
            get_dependencies_all
            run_tests_all
            build_platform_all "$platform"
            ;;
        "build-single")
            local project=${2:-""}
            local platform=${3:-""}
            if [[ -z "$project" || -z "$platform" ]]; then
                print_error "Usage: $0 build-single <project> <platform>"
                print_error "Projects: communication-spike, graphics_performance_spike, state_management_spike"
                print_error "Platforms: macos, ios, android, linux"
                exit 1
            fi
            check_flutter
            if [[ -d "spike/$project" ]]; then
                (cd "spike/$project" && flutter pub get && build_platform "$platform")
            else
                print_error "Project spike/$project not found"
                exit 1
            fi
            ;;
        "all")
            check_flutter
            get_dependencies_all
            run_tests_all
            
            # Build all platforms available on current OS for all projects
            if [[ "$OSTYPE" == "darwin"* ]]; then
                build_platform_all "macos"
                build_platform_all "ios"
            fi
            build_platform_all "android"
            ;;
        "clean")
            print_status "Cleaning build artifacts for all projects..."
            clean_all
            ;;
        "help"|*)
            echo "Usage: $0 <command> [options]"
            echo
            echo "🏗️  Monorepo Commands (All Projects):"
            echo "  setup                    - Setup development environment for all projects"
            echo "  test                     - Run tests and analysis for all projects"
            echo "  build <platform>         - Build all projects for platform (macos, ios, android, linux)"
            echo "  all                      - Build all projects for all available platforms"
            echo "  clean                    - Clean build artifacts for all projects"
            echo
            echo "🎯 Single Project Commands:"
            echo "  test-single <project>              - Test specific project"
            echo "  build-single <project> <platform>  - Build specific project for platform"
            echo
            echo "📁 Available Projects:"
            echo "  • communication-spike      - WebSocket communication testing"
            echo "  • graphics_performance_spike - Graphics and rendering performance"
            echo "  • state_management_spike  - State management patterns"
            echo
            echo "🖥️  Available Platforms:"
            echo "  • macos    - macOS desktop application"
            echo "  • ios      - iOS mobile application (macOS only)"
            echo "  • android  - Android mobile application"
            echo "  • linux    - Linux desktop application (Linux only)"
            echo
            echo "Examples:"
            echo "  $0 setup                                    # Setup all projects"
            echo "  $0 test                                     # Test all projects"
            echo "  $0 test-single communication-spike         # Test communication spike only"
            echo "  $0 build macos                             # Build all projects for macOS"
            echo "  $0 build-single graphics_performance_spike macos  # Build graphics spike for macOS"
            echo "  $0 all                                      # Build all projects for all platforms"
            echo "  $0 clean                                    # Clean all projects"
            ;;
    esac
}

# Run main function with all arguments
main "$@"