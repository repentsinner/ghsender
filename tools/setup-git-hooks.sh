#!/bin/bash
# Git Hooks Setup - Install pre-commit hooks for code quality enforcement
# This script installs git hooks templates to .git/hooks/ and makes them executable

set -e  # Exit on any error

# Load shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-utils.sh"

# Set up project paths
PROJECT_ROOT="$(get_project_root)"
HOOKS_TEMPLATE_DIR="$PROJECT_ROOT/tools/hooks"
GIT_HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

# Show header
show_header() {
    echo -e "${GREEN}=== Git Hooks Setup ===${NC}"
    echo "Project: ghSender"
    echo "Hooks Templates: $HOOKS_TEMPLATE_DIR"
    echo "Git Hooks Directory: $GIT_HOOKS_DIR"
    echo
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if we're in a git repository
check_git_repo() {
    print_step "Checking git repository..."
    
    if [ ! -d "$PROJECT_ROOT/.git" ]; then
        print_error "Not in a git repository. Git hooks setup requires a git repository."
        exit 1
    fi
    
    print_status "Git repository confirmed"
}

# Install git hooks from templates
install_hooks() {
    print_step "Installing git hooks from templates..."
    
    if [ ! -d "$HOOKS_TEMPLATE_DIR" ]; then
        print_error "Hooks template directory not found: $HOOKS_TEMPLATE_DIR"
        exit 1
    fi
    
    # Ensure git hooks directory exists
    mkdir -p "$GIT_HOOKS_DIR"
    
    # Copy hooks from templates and make them executable
    local hooks_installed=0
    for hook_template in "$HOOKS_TEMPLATE_DIR"/*; do
        if [ -f "$hook_template" ]; then
            local hook_name=$(basename "$hook_template")
            local hook_dest="$GIT_HOOKS_DIR/$hook_name"
            
            echo "  Installing $hook_name..."
            cp "$hook_template" "$hook_dest"
            chmod +x "$hook_dest"
            hooks_installed=$((hooks_installed + 1))
        fi
    done
    
    if [ $hooks_installed -eq 0 ]; then
        print_warning "No hook templates found in $HOOKS_TEMPLATE_DIR"
        return 0
    fi
    
    print_status "Installed $hooks_installed git hook(s)"
}

# Validate hook installation
validate_hooks() {
    print_step "Validating hook installation..."
    
    local validation_failed=false
    
    # Check that the main pre-commit hook exists and is executable
    local main_hook="$GIT_HOOKS_DIR/pre-commit"
    if [ -f "$main_hook" ] && [ -x "$main_hook" ]; then
        print_status "✅ pre-commit hook: installed and executable"
    else
        print_error "❌ pre-commit hook: missing or not executable"
        validation_failed=true
    fi
    
    # Check that the errors-only variant exists and is executable
    local errors_only_hook="$GIT_HOOKS_DIR/pre-commit-errors-only"
    if [ -f "$errors_only_hook" ] && [ -x "$errors_only_hook" ]; then
        print_status "✅ pre-commit-errors-only hook: installed and executable"
    else
        print_error "❌ pre-commit-errors-only hook: missing or not executable"
        validation_failed=true
    fi
    
    if [ "$validation_failed" = true ]; then
        print_error "Hook validation failed"
        exit 1
    fi
    
    print_status "All hooks validated successfully"
}

# Show hook usage information
show_usage_info() {
    print_step "Git hooks usage information..."
    
    echo
    echo -e "${YELLOW}📋 Git Hooks Usage:${NC}"
    echo
    echo "• The default pre-commit hook (strict mode) will:"
    echo "  - Run 'dart analyze --fatal-warnings' on all Flutter projects"
    echo "  - Block commits if ANY warnings or errors are found"
    echo "  - Use the local toolchain environment"
    echo
    echo "• The pre-commit-errors-only hook (lenient mode) will:"
    echo "  - Run 'dart analyze' on all Flutter projects"  
    echo "  - Block commits only if ERRORS are found"
    echo "  - Allow commits with warnings"
    echo
    echo -e "${YELLOW}🔄 To switch between hook modes:${NC}"
    echo
    echo "  # Use strict mode (warnings block commits):"
    echo "  cp .git/hooks/pre-commit-errors-only .git/hooks/pre-commit.backup"
    echo "  cp tools/hooks/pre-commit .git/hooks/pre-commit"
    echo
    echo "  # Use lenient mode (warnings allowed):"
    echo "  cp .git/hooks/pre-commit .git/hooks/pre-commit.backup"
    echo "  cp tools/hooks/pre-commit-errors-only .git/hooks/pre-commit"
    echo
    echo -e "${YELLOW}🚫 To bypass hooks temporarily:${NC}"
    echo "  git commit --no-verify"
    echo
    echo -e "${YELLOW}📊 To test hooks manually:${NC}"
    echo "  .git/hooks/pre-commit"
    echo
}

# Show usage
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Install git hooks for code quality enforcement."
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --validate     Only validate existing hooks (don't reinstall)"
    echo "  --info         Show hook usage information only"
    echo
    echo "The script installs pre-commit hooks that:"
    echo "• Run static analysis (dart analyze) on Flutter projects"
    echo "• Use the local toolchain environment"  
    echo "• Block commits if issues are found"
    echo "• Provide clear error messages and fix instructions"
    echo
    echo "Hook templates are stored in tools/hooks/ and copied to .git/hooks/"
}

# Main execution
main() {
    local validate_only=false
    local info_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help|help)
                show_help
                exit 0
                ;;
            --validate)
                validate_only=true
                shift
                ;;
            --info)
                info_only=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    show_header
    
    if [ "$info_only" = true ]; then
        show_usage_info
        exit 0
    fi
    
    check_git_repo
    
    if [ "$validate_only" = false ]; then
        install_hooks
    fi
    
    validate_hooks
    show_usage_info
    
    echo
    print_status "✅ Git hooks setup complete!"
    echo
    echo -e "${GREEN}Next steps:${NC}"
    echo "• Test the hooks: make a commit to see static analysis in action"
    echo "• Switch hook modes if needed (see usage info above)"
    echo "• All team members should run this script after cloning"
}

# Run main function
main "$@"