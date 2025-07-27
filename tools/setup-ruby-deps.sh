#!/bin/bash

# Self-contained Ruby build dependencies installer for macOS
# Downloads, compiles, and installs openssl, readline, libyaml, and gmp
# within the project's toolchain directory

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
SOURCES_DIR="$DEPS_ROOT/sources"
BUILD_DIR="$DEPS_ROOT/build"
INSTALL_DIR="$DEPS_ROOT/install"

# Library versions and URLs
OPENSSL_VERSION="3.5.1"
OPENSSL_URL="https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz"

READLINE_VERSION="8.2"
READLINE_URL="https://ftp.gnu.org/gnu/readline/readline-${READLINE_VERSION}.tar.gz"

LIBYAML_VERSION="0.2.5"
LIBYAML_URL="https://github.com/yaml/libyaml/releases/download/${LIBYAML_VERSION}/yaml-${LIBYAML_VERSION}.tar.gz"

GMP_VERSION="6.3.0"
GMP_URL="https://gmplib.org/download/gmp/gmp-${GMP_VERSION}.tar.xz"

# Platform detection
if [[ "$(uname -m)" == "arm64" ]]; then
    ARCH="arm64"
    TARGET_TRIPLE="arm64-apple-darwin"
else
    ARCH="x86_64"
    TARGET_TRIPLE="x86_64-apple-darwin"
fi

info "Setting up Ruby build dependencies for macOS $ARCH"
info "Project root: $PROJECT_ROOT"
info "Install directory: $INSTALL_DIR"

# Create directory structure
create_directories() {
    info "Creating directory structure..."
    mkdir -p "$SOURCES_DIR" "$BUILD_DIR" "$INSTALL_DIR"/{bin,lib,include,share}
    success "Directory structure created"
}

# Download source files
download_sources() {
    info "Downloading source files..."
    cd "$SOURCES_DIR"
    
    # OpenSSL
    if [[ ! -f "openssl-${OPENSSL_VERSION}.tar.gz" ]]; then
        info "Downloading OpenSSL ${OPENSSL_VERSION}..."
        curl -L -o "openssl-${OPENSSL_VERSION}.tar.gz" "$OPENSSL_URL"
    fi
    
    # Readline
    if [[ ! -f "readline-${READLINE_VERSION}.tar.gz" ]]; then
        info "Downloading Readline ${READLINE_VERSION}..."
        curl -L -o "readline-${READLINE_VERSION}.tar.gz" "$READLINE_URL"
    fi
    
    # LibYAML
    if [[ ! -f "yaml-${LIBYAML_VERSION}.tar.gz" ]]; then
        info "Downloading LibYAML ${LIBYAML_VERSION}..."
        curl -L -o "yaml-${LIBYAML_VERSION}.tar.gz" "$LIBYAML_URL"
    fi
    
    # GMP
    if [[ ! -f "gmp-${GMP_VERSION}.tar.xz" ]]; then
        info "Downloading GMP ${GMP_VERSION}..."
        curl -L -o "gmp-${GMP_VERSION}.tar.xz" "$GMP_URL"
    fi
    
    success "All sources downloaded"
}

# Extract sources
extract_sources() {
    info "Extracting source files..."
    cd "$SOURCES_DIR"
    
    [[ ! -d "openssl-${OPENSSL_VERSION}" ]] && tar -xzf "openssl-${OPENSSL_VERSION}.tar.gz"
    [[ ! -d "readline-${READLINE_VERSION}" ]] && tar -xzf "readline-${READLINE_VERSION}.tar.gz"
    [[ ! -d "yaml-${LIBYAML_VERSION}" ]] && tar -xzf "yaml-${LIBYAML_VERSION}.tar.gz"
    [[ ! -d "gmp-${GMP_VERSION}" ]] && tar -xJf "gmp-${GMP_VERSION}.tar.xz"
    
    success "All sources extracted"
}

# Build and install GMP (required by other libraries)
build_gmp() {
    info "Building GMP ${GMP_VERSION}..."
    cd "$BUILD_DIR"
    
    if [[ -f "$INSTALL_DIR/lib/libgmp.a" ]]; then
        success "GMP already installed, skipping"
        return
    fi
    
    rm -rf "gmp-${GMP_VERSION}"
    cp -r "$SOURCES_DIR/gmp-${GMP_VERSION}" .
    cd "gmp-${GMP_VERSION}"
    
    # Configure for macOS with proper architecture
    ./configure \
        --prefix="$INSTALL_DIR" \
        --enable-static \
        --disable-shared \
        --with-pic \
        CC=clang \
        CXX=clang++ \
        CFLAGS="-arch $ARCH -mmacosx-version-min=10.15" \
        CXXFLAGS="-arch $ARCH -mmacosx-version-min=10.15"
    
    make -j$(sysctl -n hw.ncpu)
    make install
    
    success "GMP ${GMP_VERSION} installed"
}

# Build and install OpenSSL
build_openssl() {
    info "Building OpenSSL ${OPENSSL_VERSION}..."
    cd "$BUILD_DIR"
    
    if [[ -f "$INSTALL_DIR/lib/libssl.a" && -f "$INSTALL_DIR/lib/libcrypto.a" ]]; then
        success "OpenSSL already installed, skipping"
        return
    fi
    
    rm -rf "openssl-${OPENSSL_VERSION}"
    cp -r "$SOURCES_DIR/openssl-${OPENSSL_VERSION}" .
    cd "openssl-${OPENSSL_VERSION}"
    
    # Configure for macOS with proper architecture
    if [[ "$ARCH" == "arm64" ]]; then
        ./Configure darwin64-arm64-cc \
            --prefix="$INSTALL_DIR" \
            --openssldir="$INSTALL_DIR/etc/ssl" \
            no-shared \
            no-tests \
            -mmacosx-version-min=10.15
    else
        ./Configure darwin64-x86_64-cc \
            --prefix="$INSTALL_DIR" \
            --openssldir="$INSTALL_DIR/etc/ssl" \
            no-shared \
            no-tests \
            -mmacosx-version-min=10.15
    fi
    
    make -j$(sysctl -n hw.ncpu)
    make install_sw install_ssldirs
    
    success "OpenSSL ${OPENSSL_VERSION} installed"
}

# Build and install Readline
build_readline() {
    info "Building Readline ${READLINE_VERSION}..."
    cd "$BUILD_DIR"
    
    if [[ -f "$INSTALL_DIR/lib/libreadline.a" ]]; then
        success "Readline already installed, skipping"
        return
    fi
    
    rm -rf "readline-${READLINE_VERSION}"
    cp -r "$SOURCES_DIR/readline-${READLINE_VERSION}" .
    cd "readline-${READLINE_VERSION}"
    
    # Configure for macOS with proper architecture
    ./configure \
        --prefix="$INSTALL_DIR" \
        --enable-static \
        --disable-shared \
        --with-curses \
        CC=clang \
        CFLAGS="-arch $ARCH -mmacosx-version-min=10.15"
    
    make -j$(sysctl -n hw.ncpu)
    make install
    
    success "Readline ${READLINE_VERSION} installed"
}

# Build and install LibYAML
build_libyaml() {
    info "Building LibYAML ${LIBYAML_VERSION}..."
    cd "$BUILD_DIR"
    
    if [[ -f "$INSTALL_DIR/lib/libyaml.a" ]]; then
        success "LibYAML already installed, skipping"
        return
    fi
    
    rm -rf "yaml-${LIBYAML_VERSION}"
    cp -r "$SOURCES_DIR/yaml-${LIBYAML_VERSION}" .
    cd "yaml-${LIBYAML_VERSION}"
    
    # Generate configure script if needed
    if [[ ! -f configure ]]; then
        ./bootstrap
    fi
    
    # Configure for macOS with proper architecture
    ./configure \
        --prefix="$INSTALL_DIR" \
        --enable-static \
        --disable-shared \
        CC=clang \
        CFLAGS="-arch $ARCH -mmacosx-version-min=10.15"
    
    make -j$(sysctl -n hw.ncpu)
    make install
    
    success "LibYAML ${LIBYAML_VERSION} installed"
}

# Create environment activation script
create_activation_script() {
    info "Creating environment activation script..."
    
    cat > "$DEPS_ROOT/activate-ruby-deps.sh" << 'EOF'
#!/bin/bash
# Ruby build dependencies environment activation script
# Source this script to set up environment variables for Ruby compilation

# Get the absolute path to the dependencies directory
DEPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$DEPS_DIR/install"

# Export environment variables for Ruby compilation
export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$INSTALL_DIR --with-readline-dir=$INSTALL_DIR --with-libyaml-dir=$INSTALL_DIR --with-gmp-dir=$INSTALL_DIR"

# PKG_CONFIG_PATH for finding libraries
export PKG_CONFIG_PATH="$INSTALL_DIR/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

# CPPFLAGS and LDFLAGS for compilation
export CPPFLAGS="-I$INSTALL_DIR/include ${CPPFLAGS:-}"
export LDFLAGS="-L$INSTALL_DIR/lib ${LDFLAGS:-}"

# Additional library paths
export LIBRARY_PATH="$INSTALL_DIR/lib:${LIBRARY_PATH:-}"
export LD_LIBRARY_PATH="$INSTALL_DIR/lib:${LD_LIBRARY_PATH:-}"

echo "Ruby build dependencies environment activated"
echo "Install directory: $INSTALL_DIR"
echo "RUBY_CONFIGURE_OPTS: $RUBY_CONFIGURE_OPTS"
EOF
    
    chmod +x "$DEPS_ROOT/activate-ruby-deps.sh"
    success "Activation script created at $DEPS_ROOT/activate-ruby-deps.sh"
}

# Create pkg-config files for better library detection
create_pkgconfig_files() {
    info "Creating pkg-config files..."
    
    local pc_dir="$INSTALL_DIR/lib/pkgconfig"
    mkdir -p "$pc_dir"
    
    # OpenSSL pkg-config files (if not created by build)
    if [[ ! -f "$pc_dir/openssl.pc" ]]; then
        cat > "$pc_dir/openssl.pc" << EOF
prefix=$INSTALL_DIR
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: OpenSSL
Description: Secure Sockets Layer and cryptography libraries
Version: $OPENSSL_VERSION
Requires: libssl libcrypto
EOF
    fi
    
    if [[ ! -f "$pc_dir/libssl.pc" ]]; then
        cat > "$pc_dir/libssl.pc" << EOF
prefix=$INSTALL_DIR
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: OpenSSL-libssl
Description: Secure Sockets Layer library
Version: $OPENSSL_VERSION
Requires.private: libcrypto
Libs: -L\${libdir} -lssl
Libs.private: -lcrypto
Cflags: -I\${includedir}
EOF
    fi
    
    if [[ ! -f "$pc_dir/libcrypto.pc" ]]; then
        cat > "$pc_dir/libcrypto.pc" << EOF
prefix=$INSTALL_DIR
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: OpenSSL-libcrypto
Description: OpenSSL cryptography library
Version: $OPENSSL_VERSION
Libs: -L\${libdir} -lcrypto
Cflags: -I\${includedir}
EOF
    fi
    
    success "pkg-config files created"
}

# Verify installation
verify_installation() {
    info "Verifying installation..."
    
    local errors=0
    
    # Check for required libraries
    for lib in libssl.a libcrypto.a libreadline.a libyaml.a libgmp.a; do
        if [[ ! -f "$INSTALL_DIR/lib/$lib" ]]; then
            error "Missing library: $lib"
            ((errors++))
        fi
    done
    
    # Check for required headers
    for header in openssl/ssl.h readline/readline.h yaml.h gmp.h; do
        if [[ ! -f "$INSTALL_DIR/include/$header" ]]; then
            error "Missing header: $header"
            ((errors++))
        fi
    done
    
    if [[ $errors -eq 0 ]]; then
        success "Installation verification passed"
        info "All Ruby build dependencies are installed and ready"
        info ""
        info "To use these dependencies for Ruby compilation:"
        info "  source $DEPS_ROOT/activate-ruby-deps.sh"
        info ""
        info "Or manually set environment variables:"
        info "  export RUBY_CONFIGURE_OPTS=\"--with-openssl-dir=$INSTALL_DIR --with-readline-dir=$INSTALL_DIR --with-libyaml-dir=$INSTALL_DIR --with-gmp-dir=$INSTALL_DIR\""
        return 0
    else
        error "Installation verification failed with $errors errors"
        return 1
    fi
}

# Main execution
main() {
    info "Starting Ruby build dependencies installation..."
    
    create_directories
    download_sources
    extract_sources
    
    # Build dependencies in order (GMP first as others may depend on it)
    build_gmp
    build_openssl
    build_readline
    build_libyaml
    
    create_activation_script
    create_pkgconfig_files
    verify_installation
    
    success "Ruby build dependencies installation completed successfully!"
}

# Run main function
main "$@"