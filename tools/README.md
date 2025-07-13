# Tools Directory

This directory contains various utility scripts to assist with development, setup, and project analysis.

## Scripts Overview

- `activate-env.sh`: Script to activate the development environment (details to be added).
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
