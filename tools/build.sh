#!/bin/bash
# Cross-Platform Build Script for ghSender Monorepo
# Handles all platform-specific build tasks for multiple Flutter projects

set -e  # Exit on any error

# Activate local toolchain environment
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$PROJECT_ROOT/tools/activate-env.sh" ]]; then
    source "$PROJECT_ROOT/tools/activate-env.sh"
fi
cd "$PROJECT_ROOT"

# Define Flutter project (single root-level app)
FLUTTER_PROJECTS=(
    "."
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

# Check for native assets requirements
check_native_assets() {
    local project_dir="$1"
    if [[ -f "$project_dir/hook/build.dart" ]]; then
        print_status "Project uses native assets (flutter_gpu_shaders)"
        return 0
    fi
    return 1
}

# Prepare native assets build environment
prepare_native_assets() {
    local project_dir="$1"
    print_status "Preparing native assets build environment..."
    
    # Ensure native assets build hooks are available
    if ! flutter pub deps | grep -q -E "(native_assets_cli|hooks)"; then
        print_error "Native assets build system not found in dependencies"
        return 1
    fi
    
    # Clean any previous build artifacts that might interfere
    if [[ -d "$project_dir/.dart_tool/hooks_runner" ]]; then
        print_status "Cleaning previous native assets build cache..."
        rm -rf "$project_dir/.dart_tool/hooks_runner"
    fi
    
    # Ensure build directory exists for shader compilation
    mkdir -p "$project_dir/build/shaderbundles"
    
    return 0
}

# Validate shader files for common GLSL issues
validate_shaders() {
    local project_dir="$1"
    local shader_dir="$project_dir/shaders"
    
    if [[ ! -d "$shader_dir" ]]; then
        return 0  # No shaders to validate
    fi
    
    print_status "Validating shader files for modern GLSL compatibility..."
    
    local has_issues=false
    
    # Check for deprecated GLSL syntax
    for shader_file in "$shader_dir"/*.vert "$shader_dir"/*.frag; do
        if [[ -f "$shader_file" ]]; then
            local filename=$(basename "$shader_file")
            
            # Check for deprecated 'attribute' keyword
            if grep -q "attribute " "$shader_file"; then
                print_warning "$filename: Uses deprecated 'attribute' keyword (should be 'in' for modern GLSL)"
                has_issues=true
            fi
            
            # Check for non-blocked uniforms (Vulkan compatibility issue)
            if grep -E "^uniform [^{]*;.*$" "$shader_file" | grep -v "uniform.*{" > /dev/null; then
                print_warning "$filename: Uses non-blocked uniforms (not compatible with Vulkan)"
                has_issues=true
            fi
        fi
    done
    
    if [[ "$has_issues" == true ]]; then
        print_warning "Shader validation found compatibility issues"
        print_warning "Consider updating shaders for modern GLSL/Vulkan compatibility"
        print_warning "Build will attempt to continue but may fail during shader compilation"
    else
        print_status "Shader validation passed"
    fi
}

# Fix shader syntax for modern GLSL/Vulkan compatibility
fix_shader_syntax() {
    local project_dir="$1"
    local shader_dir="$project_dir/shaders"
    
    if [[ ! -d "$shader_dir" ]]; then
        print_warning "No shader directory found"
        return 1
    fi
    
    print_status "Fixing shader syntax for modern GLSL compatibility..."
    
    # Create backups
    local backup_dir="$shader_dir/.backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    for shader_file in "$shader_dir"/*.vert "$shader_dir"/*.frag; do
        if [[ -f "$shader_file" ]]; then
            local filename=$(basename "$shader_file")
            cp "$shader_file" "$backup_dir/$filename"
            
            # Fix deprecated 'attribute' to 'in'
            if grep -q "attribute " "$shader_file"; then
                print_status "Fixing 'attribute' keyword in $filename"
                sed -i '' 's/attribute /in /g' "$shader_file"
            fi
            
            # Fix non-blocked uniforms by wrapping them in a uniform block
            if grep -E "^uniform [^{]*;.*$" "$shader_file" | grep -v "uniform.*{" > /dev/null; then
                print_status "Converting non-blocked uniforms in $filename"
                # This is a complex transformation that would need careful handling
                print_warning "Non-blocked uniform conversion requires manual intervention"
                print_warning "Please wrap standalone uniforms in uniform blocks for Vulkan compatibility"
            fi
        fi
    done
    
    print_status "Shader syntax fixes completed. Backups stored in $backup_dir"
    print_warning "Please review the changes and test thoroughly"
}

# Build for specific platform
build_platform() {
    local platform=$1
    local current_dir=$(pwd)
    print_status "Building for $platform..."
    
    # Check if this project requires native assets
    if check_native_assets "$current_dir"; then
        validate_shaders "$current_dir"
        if ! prepare_native_assets "$current_dir"; then
            print_error "Failed to prepare native assets build environment"
            return 1
        fi
    fi
    
    case $platform in
        "macos")
            # For native assets projects, use verbose output to better diagnose issues
            if check_native_assets "$current_dir"; then
                print_status "Building macOS with native assets support..."
                if ! flutter build macos --release --verbose; then
                    print_error "macOS build with native assets failed"
                    print_error "Check shader files for GLSL compatibility issues"
                    return 1
                fi
            else
                flutter build macos --release
            fi
            print_status "macOS build completed: build/macos/Build/Products/Release/"
            ;;
        "ios")
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # iOS build only available on macOS
                if check_native_assets "$current_dir"; then
                    print_status "Building iOS with native assets support..."
                    if ! flutter build ios --release --verbose; then
                        print_error "iOS build with native assets failed"
                        print_error "Check shader files for GLSL compatibility issues"
                        return 1
                    fi
                else
                    flutter build ios --release
                fi
                print_status "iOS build completed: build/ios/Release-iphoneos/"
            else
                print_warning "iOS builds only available on macOS"
            fi
            ;;
        "android")
            if check_native_assets "$current_dir"; then
                print_status "Building Android with native assets support..."
                if ! flutter build apk --release --verbose; then
                    print_error "Android build with native assets failed"
                    print_error "Check shader files for GLSL compatibility issues"
                    return 1
                fi
            else
                flutter build apk --release
            fi
            print_status "Android APK completed: build/app/outputs/flutter-apk/"
            ;;
        "linux")
            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                if check_native_assets "$current_dir"; then
                    print_status "Building Linux with native assets support..."
                    if ! flutter build linux --release --verbose; then
                        print_error "Linux build with native assets failed"
                        print_error "Check shader files for GLSL compatibility issues"
                        return 1
                    fi
                else
                    flutter build linux --release
                fi
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
                print_error "Please specify project name (use '.' for root project)"
                exit 1
            fi
            check_flutter
            if [[ "$project" == "." ]]; then
                flutter pub get && flutter analyze && flutter test --timeout=60s
            elif [[ -d "spike/$project" ]]; then
                (cd "spike/$project" && flutter pub get && flutter analyze && flutter test --timeout=60s)
            else
                print_error "Project $project not found"
                exit 1
            fi
            ;;
        "test-unit")
            local project=${2:-""}
            if [[ -z "$project" ]]; then
                print_error "Please specify project name (use '.' for root project)"
                exit 1
            fi
            check_flutter
            if [[ "$project" == "." ]]; then
                print_status "Running unit tests for root project..."
                flutter test test/unit/ --timeout=60s
            elif [[ -d "spike/$project" ]]; then
                print_status "Running unit tests for $project..."
                (cd "spike/$project" && flutter test test/unit/ --timeout=60s)
            else
                print_error "Project $project not found"
                exit 1
            fi
            ;;
        "test-widget")
            local project=${2:-""}
            if [[ -z "$project" ]]; then
                print_error "Please specify project name (use '.' for root project)"
                exit 1
            fi
            check_flutter
            if [[ "$project" == "." ]]; then
                print_status "Running widget tests for root project..."
                flutter test test/widget/ --timeout=60s
            elif [[ -d "spike/$project" ]]; then
                print_status "Running widget tests for $project..."
                (cd "spike/$project" && flutter test test/widget/ --timeout=60s)
            else
                print_error "Project $project not found"
                exit 1
            fi
            ;;
        "test-integration")
            local project=${2:-""}
            if [[ -z "$project" ]]; then
                print_error "Please specify project name (use '.' for root project)"
                exit 1
            fi
            check_flutter
            if [[ "$project" == "." ]]; then
                print_status "Running integration tests for root project..."
                flutter test integration_test/ --timeout=120s
            elif [[ -d "spike/$project" ]]; then
                print_status "Running integration tests for $project..."
                (cd "spike/$project" && flutter test integration_test/ --timeout=120s)
            else
                print_error "Project $project not found"
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
                print_error "Project: . (root-level Flutter app)"
                print_error "Platforms: macos, ios, android, linux"
                exit 1
            fi
            check_flutter
            if [[ "$project" == "." ]]; then
                flutter pub get && build_platform "$platform"
            elif [[ -d "spike/$project" ]]; then
                (cd "spike/$project" && flutter pub get && build_platform "$platform")
            else
                print_error "Project $project not found"
                exit 1
            fi
            ;;
        "diagnose-shaders")
            print_status "Diagnosing shader compatibility for root project..."
            validate_shaders "$(pwd)"
            if [[ -f "shaders/ghsender.shaderbundle.json" ]]; then
                print_status "Shader bundle configuration:"
                cat "shaders/ghsender.shaderbundle.json"
            fi
            ;;
        "fix-shaders")
            print_status "Attempting to fix shader compatibility issues for root project..."
            print_warning "This will modify shader files to use modern GLSL syntax"
            read -p "Continue? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                fix_shader_syntax "$(pwd)"
            else
                print_status "Shader fix cancelled"
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
            echo "  test-single <project>              - Test specific project (all tests)"
            echo "  test-unit <project>                - Run unit tests only for specific project"
            echo "  test-widget <project>              - Run widget tests only for specific project"  
            echo "  test-integration <project>         - Run integration tests only for specific project"
            echo "  build-single <project> <platform>  - Build specific project for platform"
            echo
            echo "🔧 Shader/Native Assets Diagnostics:"
            echo "  diagnose-shaders                    - Check shader compatibility for root project"
            echo "  fix-shaders                         - Attempt to fix common shader issues for root project"
            echo
            echo "📁 Project Structure:"
            echo "  • Root-level Flutter app with graphics rendering and CNC communication"
            echo "  • Uses native assets for shader compilation and GPU rendering"
            echo "  • Integrated BLoC state management with real-time machine control"
            echo
            echo "🖥️  Available Platforms:"
            echo "  • macos    - macOS desktop application"
            echo "  • ios      - iOS mobile application (macOS only)"
            echo "  • android  - Android mobile application"
            echo "  • linux    - Linux desktop application (Linux only)"
            echo
            echo "Examples:"
            echo "  $0 setup                                    # Setup project dependencies"
            echo "  $0 test                                     # Test project"
            echo "  $0 test-single .                           # Test root project"
            echo "  $0 build macos                             # Build project for macOS"
            echo "  $0 build-single . macos                       # Build root project for macOS"
            echo "  $0 diagnose-shaders                        # Check shader compatibility issues"
            echo "  $0 fix-shaders                             # Fix common shader syntax issues"
            echo "  $0 all                                      # Build project for all platforms"
            echo "  $0 clean                                    # Clean project artifacts"
            ;;
    esac
}

# Run main function with all arguments
main "$@"