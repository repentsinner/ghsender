#!/bin/bash
# Convenience script to activate local toolchain
# Usage: source ./tools/activate-env.sh

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script must be sourced, not executed directly"
    echo "Usage: source ./tools/activate-env.sh"
    exit 1
fi

# Get project root and source the main activation script
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTIVATION_SCRIPT="$PROJECT_ROOT/toolchain/scripts/activate-env.sh"

if [[ -f "$ACTIVATION_SCRIPT" ]]; then
    source "$ACTIVATION_SCRIPT"
else
    echo "Error: Activation script not found at $ACTIVATION_SCRIPT"
    echo "Run ./tools/setup-toolchain.sh first"
fi
