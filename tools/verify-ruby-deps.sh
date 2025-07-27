#!/bin/bash

# Ruby build dependencies verification script
# Tests that all dependencies are properly installed and configured

set -euo pipefail

# Color output functions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Toolchain directories
TOOLCHAIN_ROOT="$PROJECT_ROOT/toolchain"
DEPS_ROOT="$TOOLCHAIN_ROOT/deps"
INSTALL_DIR="$DEPS_ROOT/install"

# Expected library versions
OPENSSL_VERSION="3.5.1"
READLINE_VERSION="8.2"
LIBYAML_VERSION="0.2.5"
GMP_VERSION="6.3.0"

info "Verifying Ruby build dependencies installation..."
info "Install directory: $INSTALL_DIR"

# Check if dependencies are installed
check_installation() {
    local errors=0
    
    info "Checking dependency installation..."
    
    if [[ ! -d "$INSTALL_DIR" ]]; then
        error "Dependencies not installed. Run ./tools/setup-ruby-deps.sh first"
        return 1
    fi
    
    # Check static libraries
    local libraries=(
        "libssl.a:OpenSSL SSL library"
        "libcrypto.a:OpenSSL crypto library"
        "libreadline.a:GNU Readline library"
        "libyaml.a:LibYAML library"
        "libgmp.a:GMP arithmetic library"
    )
    
    for lib_info in "${libraries[@]}"; do
        IFS=':' read -r lib_name lib_desc <<< "$lib_info"
        if [[ -f "$INSTALL_DIR/lib/$lib_name" ]]; then
            local size=$(stat -f%z "$INSTALL_DIR/lib/$lib_name" 2>/dev/null || echo "0")
            success "$lib_desc found (${lib_name}, ${size} bytes)"
        else
            error "$lib_desc missing ($lib_name)"
            ((errors++))
        fi
    done
    
    # Check header files
    local headers=(
        "openssl/ssl.h:OpenSSL headers"
        "openssl/crypto.h:OpenSSL crypto headers"
        "readline/readline.h:Readline headers"
        "yaml.h:LibYAML headers"
        "gmp.h:GMP headers"
    )
    
    for header_info in "${headers[@]}"; do
        IFS=':' read -r header_name header_desc <<< "$header_info"
        if [[ -f "$INSTALL_DIR/include/$header_name" ]]; then
            success "$header_desc found ($header_name)"
        else
            error "$header_desc missing ($header_name)"
            ((errors++))
        fi
    done
    
    return $errors
}

# Check activation script
check_activation_script() {
    info "Checking activation script..."
    
    local script_path="$DEPS_ROOT/activate-ruby-deps.sh"
    
    if [[ ! -f "$script_path" ]]; then
        error "Activation script not found: $script_path"
        return 1
    fi
    
    if [[ ! -x "$script_path" ]]; then
        error "Activation script not executable: $script_path"
        return 1
    fi
    
    success "Activation script found and executable"
    return 0
}

# Test environment activation
test_environment_activation() {
    info "Testing environment activation..."
    
    # Source the activation script in a subshell to test
    if ! (source "$DEPS_ROOT/activate-ruby-deps.sh" && [[ -n "$RUBY_CONFIGURE_OPTS" ]]); then
        error "Failed to activate environment or RUBY_CONFIGURE_OPTS not set"
        return 1
    fi
    
    success "Environment activation test passed"
    return 0
}

# Check pkg-config files
check_pkgconfig() {
    info "Checking pkg-config files..."
    
    local pc_dir="$INSTALL_DIR/lib/pkgconfig"
    local pc_files=("openssl.pc" "libssl.pc" "libcrypto.pc")
    local errors=0
    
    if [[ ! -d "$pc_dir" ]]; then
        warning "pkg-config directory not found: $pc_dir"
        return 1
    fi
    
    for pc_file in "${pc_files[@]}"; do
        if [[ -f "$pc_dir/$pc_file" ]]; then
            success "pkg-config file found: $pc_file"
        else
            warning "pkg-config file missing: $pc_file"
            ((errors++))
        fi
    done
    
    # Test pkg-config functionality if available
    if command -v pkg-config >/dev/null 2>&1; then
        export PKG_CONFIG_PATH="$pc_dir:${PKG_CONFIG_PATH:-}"
        
        if pkg-config --exists openssl 2>/dev/null; then
            success "pkg-config can find OpenSSL"
        else
            warning "pkg-config cannot find OpenSSL"
            ((errors++))
        fi
    else
        info "pkg-config not available, skipping pkg-config tests"
    fi
    
    return $errors
}

# Test compilation with dependencies
test_compilation() {
    info "Testing compilation with dependencies..."
    
    # Create a temporary test program
    local test_dir="$DEPS_ROOT/test_compilation"
    mkdir -p "$test_dir"
    
    # Create test C program that uses all dependencies
    cat > "$test_dir/test_deps.c" << 'EOF'
#include <stdio.h>
#include <openssl/ssl.h>
#include <openssl/crypto.h>
#include <readline/readline.h>
#include <yaml.h>
#include <gmp.h>

int main() {
    printf("Testing Ruby build dependencies...\n");
    
    // Test OpenSSL
    SSL_library_init();
    printf("OpenSSL: %s\n", OpenSSL_version(OPENSSL_VERSION));
    
    // Test Readline
    printf("Readline: GNU Readline library available\n");
    
    // Test LibYAML
    printf("LibYAML: Version %s\n", yaml_get_version_string());
    
    // Test GMP
    printf("GMP: Version %d.%d.%d\n", __GNU_MP_VERSION, __GNU_MP_VERSION_MINOR, __GNU_MP_VERSION_PATCHLEVEL);
    
    printf("All dependencies accessible!\n");
    return 0;
}
EOF
    
    # Compile the test program
    local compile_cmd="clang -I$INSTALL_DIR/include -L$INSTALL_DIR/lib -o $test_dir/test_deps $test_dir/test_deps.c -lssl -lcrypto -lreadline -lyaml -lgmp -lcurses"
    
    if $compile_cmd 2>"$test_dir/compile.log"; then
        success "Test program compiled successfully"
        
        # Run the test program
        if "$test_dir/test_deps" >"$test_dir/output.log" 2>&1; then
            success "Test program executed successfully"
            info "Test program output:"
            cat "$test_dir/output.log" | sed 's/^/  /'
        else
            error "Test program execution failed"
            cat "$test_dir/output.log" | sed 's/^/  /'
            return 1
        fi
    else
        error "Test program compilation failed"
        cat "$test_dir/compile.log" | sed 's/^/  /'
        return 1
    fi
    
    # Clean up
    rm -rf "$test_dir"
    return 0
}

# Check library compatibility
check_library_compatibility() {
    info "Checking library compatibility..."
    
    local arch=$(uname -m)
    local errors=0
    
    for lib in libssl.a libcrypto.a libreadline.a libyaml.a libgmp.a; do
        if [[ -f "$INSTALL_DIR/lib/$lib" ]]; then
            # Check if library is for correct architecture
            if lipo -info "$INSTALL_DIR/lib/$lib" 2>/dev/null | grep -q "$arch"; then
                success "$lib compiled for correct architecture ($arch)"
            else
                error "$lib not compiled for architecture $arch"
                ((errors++))
            fi
        fi
    done
    
    return $errors
}

# Generate usage instructions
show_usage_instructions() {
    info "Usage Instructions:"
    echo ""
    echo "To use these dependencies for Ruby compilation:"
    echo ""
    echo "1. Activate the environment:"
    echo "   source $DEPS_ROOT/activate-ruby-deps.sh"
    echo ""
    echo "2. Install Ruby with your preferred method:"
    echo "   # Using ruby-build:"
    echo "   ruby-build 3.2.2 $TOOLCHAIN_ROOT/ruby/3.2.2"
    echo ""
    echo "   # Or compile from source:"
    echo "   ./configure --prefix=$TOOLCHAIN_ROOT/ruby/3.2.2 \$RUBY_CONFIGURE_OPTS"
    echo "   make && make install"
    echo ""
    echo "Environment variables set by activation script:"
    (source "$DEPS_ROOT/activate-ruby-deps.sh" 2>/dev/null && echo "   RUBY_CONFIGURE_OPTS: $RUBY_CONFIGURE_OPTS")
    echo ""
}

# Main verification function
main() {
    local total_errors=0
    
    info "Starting Ruby build dependencies verification..."
    info "Platform: $(uname -s) $(uname -m)"
    echo ""
    
    # Run all checks
    check_installation || ((total_errors++))
    echo ""
    
    check_activation_script || ((total_errors++))
    echo ""
    
    test_environment_activation || ((total_errors++))
    echo ""
    
    check_pkgconfig || ((total_errors++))
    echo ""
    
    check_library_compatibility || ((total_errors++))
    echo ""
    
    test_compilation || ((total_errors++))
    echo ""
    
    # Summary
    if [[ $total_errors -eq 0 ]]; then
        success "All verification tests passed!"
        echo ""
        show_usage_instructions
        return 0
    else
        error "Verification failed with $total_errors test failures"
        echo ""
        info "To fix issues, try:"
        info "1. Re-run the setup script: ./tools/setup-ruby-deps.sh"
        info "2. Check build logs in: $DEPS_ROOT/build/"
        info "3. Verify Xcode Command Line Tools: xcode-select --install"
        return 1
    fi
}

# Run main function
main "$@"