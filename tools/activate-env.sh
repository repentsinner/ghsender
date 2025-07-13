#!/bin/bash
# Convenience script to activate local toolchain
# Usage: source ./tools/activate-env.sh

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PROJECT_ROOT/toolchain/scripts/activate-env.sh"
