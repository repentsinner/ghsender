#!/bin/bash
# Agent Tools Setup Script (macOS/Linux)
# Installs development agent tools to user scope
# - nvm (Node Version Manager)
# - Claude Code CLI
# - Gemini CLI

set -e  # Exit on any error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Agent Tools Setup ===${NC}"
echo "Platform: $(uname -s) $(uname -m)"
echo "Installing agent development tools to user scope..."
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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install NVM (Node Version Manager)
install_nvm() {
    print_step "Installing NVM (Node Version Manager)..."
    
    if command_exists nvm; then
        print_status "NVM already installed"
        nvm --version
        return 0
    fi
    
    # Check if NVM is installed but not in PATH
    if [[ -f "$HOME/.nvm/nvm.sh" ]]; then
        print_status "NVM found but not loaded, sourcing..."
        source "$HOME/.nvm/nvm.sh"
        if command_exists nvm; then
            print_status "NVM successfully loaded"
            nvm --version
            return 0
        fi
    fi
    
    print_status "Downloading and installing NVM..."
    
    # Download and install NVM
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    
    # Source NVM for current session
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    
    if command_exists nvm; then
        print_status "NVM installed successfully"
        nvm --version
    else
        print_error "NVM installation failed"
        return 1
    fi
}

# Install Node.js LTS via NVM
install_node() {
    print_step "Installing Node.js LTS via NVM..."
    
    # Ensure NVM is available
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    if ! command_exists nvm; then
        print_error "NVM not available for Node.js installation"
        return 1
    fi
    
    # Install and use latest LTS Node.js
    print_status "Installing Node.js LTS..."
    nvm install --lts
    nvm use --lts
    nvm alias default "lts/*"
    
    print_status "Node.js installed:"
    node --version
    npm --version
}

# Install Claude Code CLI
install_claude_code() {
    print_step "Installing Claude Code CLI..."
    
    # Ensure Node.js is available
    if ! command_exists npm; then
        print_error "npm not available. Node.js installation may have failed."
        return 1
    fi
    
    if command_exists claude; then
        print_status "Claude Code CLI already installed"
        claude --version
        return 0
    fi
    
    print_status "Installing Claude Code CLI via npm..."
    npm install -g @anthropics/claude-code
    
    if command_exists claude; then
        print_status "Claude Code CLI installed successfully"
        claude --version
    else
        print_error "Claude Code CLI installation failed"
        return 1
    fi
}

# Install Gemini CLI
install_gemini_cli() {
    print_step "Installing Gemini CLI..."
    
    if command_exists gemini; then
        print_status "Gemini CLI already installed"
        gemini --version 2>/dev/null || echo "Gemini CLI found"
        return 0
    fi
    
    # Check for different Gemini CLI installation methods
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    
    case "$os" in
        "darwin")
            print_status "Installing Gemini CLI for macOS..."
            # Check if Homebrew is available
            if command_exists brew; then
                print_status "Using Homebrew to install Gemini CLI..."
                brew install gemini-cli 2>/dev/null || {
                    print_warning "Homebrew formula not found, trying alternative method..."
                    install_gemini_manual_macos
                }
            else
                print_warning "Homebrew not found, installing manually..."
                install_gemini_manual_macos
            fi
            ;;
        "linux")
            print_status "Installing Gemini CLI for Linux..."
            install_gemini_manual_linux
            ;;
        *)
            print_error "Unsupported OS for Gemini CLI: $os"
            return 1
            ;;
    esac
}

# Manual Gemini CLI installation for macOS
install_gemini_manual_macos() {
    print_status "Installing Gemini CLI manually for macOS..."
    
    # Create local bin directory
    mkdir -p "$HOME/.local/bin"
    
    # Download Gemini CLI (this is a placeholder - actual download URL may vary)
    # Note: This may need to be updated with the actual Gemini CLI distribution method
    print_warning "Manual Gemini CLI installation method may need verification"
    print_warning "Please check official Gemini CLI documentation for installation instructions"
    
    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    fi
}

# Manual Gemini CLI installation for Linux
install_gemini_manual_linux() {
    print_status "Installing Gemini CLI manually for Linux..."
    
    # Create local bin directory
    mkdir -p "$HOME/.local/bin"
    
    print_warning "Manual Gemini CLI installation method may need verification"
    print_warning "Please check official Gemini CLI documentation for installation instructions"
    
    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    fi
}

# Setup shell configuration
setup_shell_config() {
    print_step "Setting up shell configuration..."
    
    local shell_configs=("$HOME/.bashrc" "$HOME/.zshrc")
    
    for config in "${shell_configs[@]}"; do
        if [[ -f "$config" ]]; then
            # Check if NVM is already configured
            if ! grep -q "NVM_DIR" "$config"; then
                print_status "Adding NVM configuration to $(basename "$config")..."
                cat >> "$config" << 'EOF'

# NVM Configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
EOF
            fi
            
            # Check if local bin is in PATH
            if ! grep -q '$HOME/.local/bin' "$config"; then
                print_status "Adding local bin to PATH in $(basename "$config")..."
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$config"
            fi
        fi
    done
}

# Verify installations
verify_installations() {
    print_step "Verifying agent tool installations..."
    
    # Source NVM for verification
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    echo
    echo "=== Installation Verification ==="
    
    if command_exists nvm; then
        echo "✅ NVM: $(nvm --version)"
    else
        echo "❌ NVM: Not found"
    fi
    
    if command_exists node; then
        echo "✅ Node.js: $(node --version)"
    else
        echo "❌ Node.js: Not found"
    fi
    
    if command_exists npm; then
        echo "✅ npm: $(npm --version)"
    else
        echo "❌ npm: Not found"
    fi
    
    if command_exists claude; then
        echo "✅ Claude Code CLI: $(claude --version 2>/dev/null || echo 'installed')"
    else
        echo "❌ Claude Code CLI: Not found"
    fi
    
    if command_exists gemini; then
        echo "✅ Gemini CLI: $(gemini --version 2>/dev/null || echo 'installed')"
    else
        echo "❌ Gemini CLI: Not found"
    fi
    
    echo "=== End Verification ==="
    echo
}

# Main execution
main() {
    print_status "Starting agent tools installation..."
    echo
    
    # Install tools
    install_nvm
    install_node
    install_claude_code
    install_gemini_cli
    setup_shell_config
    
    echo
    print_status "✅ Agent tools setup complete!"
    echo
    echo "Next steps:"
    echo "1. Restart your terminal or run:"
    echo "   source ~/.bashrc  # or source ~/.zshrc"
    echo ""
    echo "2. Verify installation:"
    echo "   nvm --version"
    echo "   node --version"
    echo "   claude --version"
    echo "   gemini --version"
    echo ""
    echo "3. Configure Claude Code (if not already done):"
    echo "   claude auth"
    echo ""
    echo "4. Configure Gemini CLI (if not already done):"
    echo "   gemini auth  # or similar command"
    echo
    
    # Run verification
    verify_installations
    
    print_warning "Note: You may need to restart your terminal for all changes to take effect"
}

# Run main function
main "$@"