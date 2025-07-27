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
- `setup-verification.sh`: Script to verify the development setup.
- `versions.env`: Environment variables related to tool versions.

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
