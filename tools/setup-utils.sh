#!/bin/bash
# Shared utilities for toolchain setup scripts
# This script should be sourced by other setup scripts

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get project root directory
get_project_root() {
    if [[ -n "${BASH_SOURCE[1]}" ]]; then
        echo "$(cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd)"
    else
        echo "$(pwd)"
    fi
}

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

# Load version configuration
load_versions() {
    local project_root="$(get_project_root)"
    if [[ -f "$project_root/tools/versions.sh" ]]; then
        source "$project_root/tools/versions.sh"
    else
        print_error "versions.sh not found at $project_root/tools/versions.sh"
        exit 1
    fi
}

# Set up toolchain directory structure
setup_directories() {
    local project_root="$(get_project_root)"
    local toolchain_dir="$project_root/toolchain"
    
    print_step "Setting up toolchain directory structure..."
    mkdir -p "$toolchain_dir"/{flutter,scripts,cache,config,ruby,asdf,asdf-data}
    print_status "Created toolchain directories"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if we're on macOS
is_macos() {
    [[ "$(uname -s)" == "Darwin" ]]
}

# Check if we're on Linux
is_linux() {
    [[ "$(uname -s)" == "Linux" ]]
}

# Check if we're on Windows (Git Bash/MSYS/MinGW)
is_windows() {
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*) return 0 ;;
        *) return 1 ;;
    esac
}

# Get architecture
get_arch() {
    uname -m
}

# Get OS name in lowercase
get_os() {
    uname -s | tr '[:upper:]' '[:lower:]'
}

# Verify required tools are available
verify_requirements() {
    local missing_tools=()
    
    if ! command_exists git; then
        missing_tools+=("git")
    fi
    
    if ! command_exists curl; then
        missing_tools+=("curl")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_error "Please install these tools before continuing"
        exit 1
    fi
}