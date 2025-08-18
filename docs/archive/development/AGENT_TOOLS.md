# Agent Tools Setup and Integration

**Author**: DevOps Engineer  
**Date**: 2025-07-13  
**Purpose**: Multi-agent development environment with Claude Code and Gemini CLI integration

## Overview

This project supports **multi-agent development coordination** using AI-powered development tools:

- **Claude Code CLI**: Primary development agent for code generation, analysis, and coordination
- **Gemini CLI**: Secondary agent for code review, alternative perspectives, and specialized tasks
- **Cross-Platform Support**: Native installation on both macOS and Windows 11

## Agent Tools Architecture

### Multi-Agent Development Benefits
- **Code Review**: Claude and Gemini provide different perspectives on code quality
- **Problem Solving**: Multiple AI approaches to complex technical challenges  
- **Specialized Tasks**: Each agent has different strengths and capabilities
- **Development Velocity**: AI assistance reduces time for routine development tasks
- **Learning Integration**: Agents help implement adaptive learning features for CNC users

### Agent Coordination Strategy
- **Primary Agent**: Claude Code CLI for main development workflows
- **Secondary Agent**: Gemini CLI for code review and alternative solutions
- **Shared Context**: Both agents work with same codebase and documentation
- **Role Switching**: Explicit commands to switch between agent perspectives
- **Documentation Integration**: Agents update shared documentation and decision logs

## Platform-Specific Setup

### macOS Setup

**Automated Installation:**
```bash
# Install all agent tools to user scope
./tools/setup-agent-tools.sh

# Verify installation
nvm --version
node --version
claude --version
gemini --version
```

**What Gets Installed:**
- **NVM**: Node Version Manager for user-scoped Node.js
- **Node.js LTS**: Latest stable Node.js via NVM
- **Claude Code CLI**: `npm install -g @anthropics/claude-code`
- **Gemini CLI**: Platform-appropriate installation method
- **Shell Configuration**: Automatic PATH updates for bash/zsh

### Windows 11 Setup

**⚠️ WSL Requirement**: Claude Code CLI requires WSL on Windows 11

**Automated Installation:**
```powershell
# 1. Install WSL first (one-time setup)
wsl --install
# Restart computer

# 2. Install agent tools
.\tools\setup-agent-tools.ps1

# 3. Verify installation
nvm version
node --version  
claude --version  # Via WSL wrapper
gemini --version
```

**What Gets Installed:**
- **Chocolatey**: Package manager for Windows
- **NVM for Windows**: Node Version Manager for Windows
- **Node.js LTS**: Latest stable Node.js via NVM
- **Claude Code CLI**: Installed in WSL, accessible via Windows wrapper
- **Gemini CLI**: Native Windows installation
- **WSL Wrapper**: `claude.bat` to seamlessly use Claude Code from PowerShell

### WSL Integration Details

**Why WSL is Required:**
- **Claude Code CLI**: Currently requires Linux/Unix environment
- **npm Dependencies**: Some Node.js packages require Unix-like environment
- **Shell Integration**: Better compatibility with development workflows

**WSL Setup Process:**
```powershell
# Install WSL with default Ubuntu distribution
wsl --install

# After restart, set up Ubuntu user account
# WSL will prompt for username and password

# Verify WSL is working
wsl --status
wsl --list --verbose
```

**Windows-WSL Integration:**
- **Transparent Access**: `claude` command works from PowerShell via wrapper
- **File System Access**: WSL can access Windows files via `/mnt/c/`
- **Environment Sync**: PATH and environment variables synchronized
- **Performance**: Minimal overhead for development workflows

## Agent Configuration

### Claude Code CLI Configuration

**Initial Setup:**
```bash
# Authenticate with Claude
claude auth

# Verify authentication
claude --version
claude status
```

**Project Integration:**
```bash
# Initialize Claude in project directory
cd /path/to/ghsender
claude init

# Start interactive session
claude chat

# File-based operations
claude analyze src/
claude review --file src/main.dart
```

### Gemini CLI Configuration

**Initial Setup:**
```bash
# Authenticate with Google AI
gemini auth

# Verify authentication  
gemini --version
gemini status
```

**Project Integration:**
```bash
# Code analysis
gemini analyze src/

# Code review
gemini review --file src/main.dart

# Alternative solutions
gemini suggest --problem "real-time CNC communication"
```

## Development Workflows

### Multi-Agent Code Review

**Primary Review (Claude):**
```bash
# Activate environment
source ./tools/activate-env.sh  # macOS
# or
. .\tools\activate-env.ps1      # Windows

# Review current changes
claude review --staged

# Get implementation suggestions
claude suggest --feature "tool change workflow"
```

**Secondary Review (Gemini):**
```bash
# Alternative perspective on same code
gemini review --file src/tool_change.dart

# Compare approaches
gemini compare --approach1 "BLoC pattern" --approach2 "Provider pattern"
```

### Agent Coordination Commands

**Role Switching:**
```bash
# Switch to Claude for implementation
claude mode --role implementation

# Switch to Gemini for review
gemini mode --role review

# Get both perspectives
claude analyze src/cnc_service.dart
gemini analyze src/cnc_service.dart
```

### Shared Documentation Updates

**Decision Logging:**
```bash
# Document architectural decisions with AI assistance
claude document --decision "chose BLoC for state management"
gemini review --document DECISIONS.md
```

**Code Generation:**
```bash
# Generate scaffolding with Claude
claude generate --component "tool change workflow"

# Review and improve with Gemini
gemini improve --file src/tool_change_workflow.dart
```

## Integration with Project Workflow

### Git Integration

**Pre-commit Review:**
```bash
# Automated review before commits
git add .
claude review --staged
gemini review --staged

# Generate commit messages
claude commit --suggest
```

**Pull Request Assistance:**
```bash
# Generate PR descriptions
claude pr --describe

# Review PR before submission
gemini pr --review
```

### VS Code Integration

**Extensions and Settings:**
```json
// .vscode/settings.json additions for agent tools
{
  "claude.enabled": true,
  "claude.autoReview": false,
  "gemini.enabled": true,
  "gemini.autoSuggest": false,
  "terminal.integrated.env.osx": {
    "CLAUDE_CONFIG": "${workspaceFolder}/.claude",
    "GEMINI_CONFIG": "${workspaceFolder}/.gemini"
  },
  "terminal.integrated.env.windows": {
    "CLAUDE_CONFIG": "${workspaceFolder}\\.claude",
    "GEMINI_CONFIG": "${workspaceFolder}\\.gemini"
  }
}
```

### Build Integration

**Automated Analysis:**
```bash
# macOS build with AI analysis
./tools/build.sh analyze  # Runs claude/gemini analysis

# Windows build with AI analysis  
.\tools\build.ps1 analyze  # Runs claude/gemini analysis
```

## Troubleshooting

### Common Issues

**Claude Code CLI Not Found (Windows):**
```powershell
# Check WSL status
wsl --status

# Verify WSL installation
wsl bash -c "which claude"

# Recreate wrapper if needed
.\tools\setup-agent-tools.ps1 -Force
```

**Node.js Version Conflicts:**
```bash
# Check current Node.js version
node --version

# Switch to LTS version
nvm use --lts

# Set default
nvm alias default "lts/*"
```

**Authentication Issues:**
```bash
# Re-authenticate Claude
claude auth --refresh

# Re-authenticate Gemini
gemini auth --refresh

# Check authentication status
claude status
gemini status
```

### Corporate Environment Considerations

**WSL Restrictions:**
- Some enterprise environments may restrict WSL installation
- Alternative: Use Claude Code via web interface
- Gemini CLI can work without WSL on Windows

**Network Restrictions:**
- AI services may require specific firewall configurations
- Proxy settings may need configuration for npm and CLI tools
- Consider offline-capable alternatives for restricted environments

## Performance Considerations

### Resource Usage
- **Claude Code CLI**: Lightweight, minimal system impact
- **Gemini CLI**: Similar resource footprint to Claude
- **WSL Overhead**: Minimal for CLI tools, ~50-100MB RAM
- **Node.js**: Standard development dependency

### Optimization Tips
- **Cache Management**: Regular cleanup of npm cache and AI response cache
- **Selective Usage**: Use AI tools for complex tasks, not routine operations
- **Batch Operations**: Group AI requests to minimize API calls

## Security Considerations

### API Key Management
- **Environment Variables**: Store API keys securely
- **Project Isolation**: Each project can have separate AI configurations
- **Key Rotation**: Regular API key updates
- **Access Logs**: Monitor AI tool usage for security compliance

### Code Privacy
- **Local Processing**: Some operations can be done locally
- **Sensitive Code**: Option to exclude certain files from AI analysis
- **Audit Trail**: Log all AI interactions for compliance
- **Data Retention**: Configure AI service data retention policies

## Future Enhancements

### Planned Features
- **Automated Code Review**: Pre-commit hooks with AI analysis
- **Intelligent Testing**: AI-generated test cases and scenarios
- **Documentation Generation**: Automated documentation updates
- **Performance Analysis**: AI-powered performance optimization suggestions

### Integration Roadmap
- **Phase 0**: Basic AI tool setup and manual usage
- **Phase 1**: Automated workflows and git integration
- **Phase 2**: Advanced coordination and learning features
- **Phase 3**: Custom AI workflows for CNC development