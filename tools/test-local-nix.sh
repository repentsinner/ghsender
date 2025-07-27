#!/bin/bash
# Test script for local Nix installation
# This script tests the project-local Nix setup

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLCHAIN_DIR="$PROJECT_ROOT/toolchain"
NIX_DIR="$TOOLCHAIN_DIR/nix"

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_test() {
    echo -e "${GREEN}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

test_count=0
pass_count=0
fail_count=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((test_count++))
    print_test "Testing: $test_name"
    
    if eval "$test_command"; then
        print_pass "$test_name"
        ((pass_count++))
        return 0
    else
        print_fail "$test_name"
        ((fail_count++))
        return 1
    fi
}

echo "=== Local Nix Installation Test ==="
echo "Project root: $PROJECT_ROOT"
echo "Toolchain dir: $TOOLCHAIN_DIR"
echo "Nix dir: $NIX_DIR"
echo

# Test 1: Check if local Nix directory exists
run_test "Local Nix directory exists" "[[ -d '$NIX_DIR' ]]"

# Test 2: Check if activation script exists
run_test "Nix activation script exists" "[[ -f '$NIX_DIR/activate-nix.sh' ]]"

# Test 3: Check if Nix binary exists
run_test "Nix binary exists" "[[ -f '$NIX_DIR/bin/nix' ]]"

# Test 4: Check if Nix config exists
run_test "Nix config exists" "[[ -f '$NIX_DIR/etc/nix.conf' ]]"

# Test 5: Activate Nix and test basic functionality
if [[ -f "$NIX_DIR/activate-nix.sh" ]]; then
    print_test "Activating local Nix environment..."
    
    # Source in a subshell to test
    if (source "$NIX_DIR/activate-nix.sh" && command -v nix >/dev/null 2>&1); then
        print_pass "Nix environment activation"
        ((pass_count++))
        
        # Test Nix version command
        if (source "$NIX_DIR/activate-nix.sh" && nix --version >/dev/null 2>&1); then
            local nix_version=$(source "$NIX_DIR/activate-nix.sh" && nix --version 2>/dev/null | awk '{print $3}' || echo "unknown")
            print_pass "Nix version command works (version: $nix_version)"
            ((pass_count++))
        else
            print_fail "Nix version command"
            ((fail_count++))
        fi
        
        # Test if environment variables are set correctly
        if (source "$NIX_DIR/activate-nix.sh" && [[ -n "$NIX_STORE" ]] && [[ -n "$NIX_STATE_DIR" ]]); then
            print_pass "Nix environment variables set correctly"
            ((pass_count++))
        else
            print_fail "Nix environment variables"
            ((fail_count++))
        fi
        
    else
        print_fail "Nix environment activation"
        ((fail_count++))
    fi
    
    ((test_count += 3))
else
    print_warn "Skipping activation tests - no activation script found"
fi

# Test 6: Check if store directory exists and is properly initialized
if [[ -d "$NIX_DIR/store" ]]; then
    print_pass "Nix store directory exists"
    ((pass_count++))
else
    print_fail "Nix store directory missing"
    ((fail_count++))
fi
((test_count++))

# Test 7: Check if state directory exists
if [[ -d "$NIX_DIR/var/nix" ]]; then
    print_pass "Nix state directory exists"
    ((pass_count++))
else
    print_fail "Nix state directory missing"
    ((fail_count++))
fi
((test_count++))

# Test 8: Verify no system contamination
system_contaminated=false
if [[ -d "/nix" ]] && [[ ! -L "/nix" ]]; then
    print_warn "System /nix directory found - may indicate system-wide installation"
    system_contaminated=true
fi

if pgrep -f "nix-daemon" >/dev/null 2>&1; then
    print_warn "Nix daemon process found - may indicate system-wide installation"
    system_contaminated=true
fi

if [[ "$system_contaminated" == "false" ]]; then
    print_pass "No system contamination detected"
    ((pass_count++))
else
    print_warn "Potential system contamination (system Nix installation may exist)"
    # Don't count this as a fail since system Nix might have been there before
fi
((test_count++))

# Summary
echo
echo "=== Test Summary ==="
echo "Total tests: $test_count"
echo "Passed: $pass_count"
echo "Failed: $fail_count"

if [[ $fail_count -eq 0 ]]; then
    echo -e "${GREEN}✅ All tests passed! Local Nix installation is working correctly.${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed. Local Nix installation needs attention.${NC}"
    exit 1
fi