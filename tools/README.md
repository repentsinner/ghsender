# Tools Directory

This directory contains various utility scripts to assist with development, setup, and project analysis.

## Scripts Overview

- `activate-env.sh`: Script to activate the development environment for Bash/Zsh shells.
- `activate-env.fish`: Script to activate the development environment for Fish shell.
- `build.ps1`: PowerShell script for building the project (for Windows).
- `build.sh`: Bash script for building the project (for Linux/macOS).
- `generate_log_entry.sh`: A utility script to generate and append new log entries to `team/SHARED_WORKSPACE.md` with a system-generated timestamp. This ensures consistent timekeeping across agent communications.
  Usage: `./generate_log_entry.sh "<AGENT_NAME>" "<ACTION>" "<FILES_MODIFIED>" "<MESSAGE>"`
- `project-analysis.sh`: Script for performing project-wide analysis (details to be added).
- `setup-agent-tools.ps1`: PowerShell script for setting up agent-specific tools (for Windows).
- `setup-agent-tools.sh`: Bash script for setting up agent-specific tools (for Linux/macOS).
- `setup-toolchain.ps1`: PowerShell script for setting up the development toolchain (for Windows).
- `setup-toolchain.sh`: Bash script for setting up the development toolchain (for Linux/macOS).
- `setup-git-hooks.sh`: Script for installing git pre-commit hooks for code quality enforcement.
- `setup-verification.sh`: Script to verify the development setup.
- `versions.sh`: Shell script containing environment variables for tool versions.

## Environment Activation

To activate the ghSender development environment, use the appropriate command for your shell:

### 🐠 Fish shell
```fish
source ./tools/activate-env.fish
```

### 🐚 Bash/Zsh shell
```bash
source ./tools/activate-env.sh
```

### Auto-activation

For convenience, you can add auto-activation to your shell's config file:

#### Fish (~/.config/fish/config.fish)
```fish
if test (pwd) = "$HOME/development/ghsender"
  source ./tools/activate-env.fish
end
```

#### Bash/Zsh (~/.bashrc or ~/.zshrc)
```bash
if [[ "$PWD" == "$HOME/development/ghsender" ]]; then
  source ./tools/activate-env.sh
fi
```

> **Note**: Replace the hardcoded path with your actual project directory path.

## Git Hooks

Git hooks are automatically installed during toolchain setup to enforce code quality standards before commits.

### Hook Templates

Hook templates are stored in the `tools/hooks/` directory:

- `pre-commit`: Strict mode - blocks commits on any warnings or errors
- `pre-commit-errors-only`: Lenient mode - blocks commits only on errors, allows warnings

### Automatic Installation

Git hooks are automatically installed when you run:

```bash
./tools/setup-toolchain.sh
```

Or you can install/update hooks separately:

```bash
./tools/setup-git-hooks.sh
```

### Hook Functionality

The pre-commit hooks:

- **Use local toolchain**: Source `./tools/activate-env.sh` for consistent tool versions
- **Analyze Flutter projects**: Run `dart analyze` on all projects in `spike/` directory
- **Provide clear feedback**: Color-coded output with specific fix instructions
- **Block problematic commits**: Prevent commits that would break static analysis
- **Show bypass options**: Inform developers how to skip hooks when needed

### Hook Modes

**Strict Mode (default)**:
```bash
# Uses tools/hooks/pre-commit
# Blocks commits on ANY warnings or errors
dart analyze --fatal-warnings
```

**Lenient Mode**:
```bash
# Uses tools/hooks/pre-commit-errors-only  
# Blocks commits only on ERRORS, allows warnings
dart analyze  # (without --fatal-warnings)
```

### Switching Hook Modes

To switch to lenient mode (warnings allowed):
```bash
cp tools/hooks/pre-commit-errors-only .git/hooks/pre-commit
```

To switch back to strict mode (warnings block commits):
```bash
cp tools/hooks/pre-commit .git/hooks/pre-commit  
```

### Bypassing Hooks

To skip hook checks temporarily (not recommended):
```bash
git commit --no-verify
```

### Testing Hooks Manually

To test hooks without making a commit:
```bash
.git/hooks/pre-commit
```

### Hook Management Commands

```bash
# Install or update git hooks
./tools/setup-git-hooks.sh

# Validate existing hook installation
./tools/setup-git-hooks.sh --validate

# Show hook usage information
./tools/setup-git-hooks.sh --info
```

### Team Setup

All developers should run the setup script after cloning:
```bash
./tools/setup-toolchain.sh
```

This ensures consistent code quality enforcement across the entire development team.
