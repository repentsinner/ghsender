# Cross-Platform Development Setup

**Author**: DevOps Engineer  
**Date**: 2025-07-13  
**Purpose**: Enable development on both macOS and Windows 11 with consistent tooling and workflows

## Cross-Platform Development Strategy

### Development Environment Architecture
- **Primary IDE**: VS Code for all development activities (macOS and Windows 11)
- **Platform Tools**: Xcode and Visual Studio used via command-line only
- **Build Automation**: Scripts handle platform-specific build tasks
- **GUI Avoidance**: Minimize exposure to platform-specific IDE interfaces
- **Consistency Goal**: Identical development experience regardless of platform

### Agent Tools Integration
- **Claude Code CLI**: Multi-agent development coordination
- **Gemini CLI**: AI-assisted development and code review
- **Cross-Platform Compatibility**: Native installation on both platforms
- **WSL Requirement**: Windows 11 requires WSL for Claude Code CLI

### Flutter Advantage for Cross-Platform Development
- **Single Codebase**: Same Dart/Flutter code runs on both development platforms
- **Consistent Experience**: UI, debugging, and testing work identically
- **Team Flexibility**: Developers can use macOS or Windows 11 without affecting others
- **Shared Workflows**: Git, documentation, and deployment processes are identical
- **CLI-Driven Builds**: Flutter's command-line tools eliminate GUI IDE dependencies

### Complexity Assessment: **LOW**
✅ **Minimal Additional Complexity**:
- Flutter handles platform differences automatically
- Same IDE (VS Code) available on both platforms
- Identical project structure and build commands
- Git workflow completely platform-agnostic

❌ **Minor Platform Differences**:
- Different native build tools (Xcode vs Visual Studio)
- Platform-specific mobile emulators
- Different installation procedures

## Platform-Specific Setup Instructions

### macOS Development Setup

**🚀 Automated Setup (Recommended):**
```bash
# 1. Setup local toolchain (Flutter, VS Code config)
./tools/setup-toolchain.sh

# 2. Setup agent tools (nvm, Claude Code, Gemini CLI)
./tools/setup-agent-tools.sh

# 3. Activate environment
source ./tools/activate-env.sh

# 4. Verify installation
flutter --version
claude --version
gemini --version
```

**📋 Manual Setup (if needed):**
```bash
# 1. Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Install system tools
brew install --cask visual-studio-code
brew install git telnet

# 3. Install VS Code extensions
code --install-extension Dart-Code.flutter
code --install-extension Dart-Code.dart-code
```

**iOS Development Tools (CLI-Only, Required for Phase 1):**
```bash
# Install Xcode Command Line Tools (minimal installation)
xcode-select --install

# Install Xcode from App Store (for iOS simulator and build tools)
# Note: Xcode GUI will NOT be used - only command-line tools and simulator
# All iOS builds managed via Flutter CLI and build scripts

# Verify command-line tools
xcrun --show-sdk-path
xcodebuild -version
```

**Verification:**
```bash
flutter doctor
./tools/setup-verification.sh
```

### Windows 11 Development Setup

**⚠️ WSL Required for Claude Code CLI**

**🚀 Automated Setup (Recommended):**
```powershell
# 1. Install WSL first (required for Claude Code CLI)
wsl --install
# Restart computer after WSL installation

# 2. Setup local toolchain (Flutter, VS Code config) - Native PowerShell
.\tools\setup-toolchain.ps1

# 3. Setup agent tools (nvm, Claude Code via WSL, Gemini CLI)  
.\tools\setup-agent-tools.ps1

# 4. Activate environment
. .\tools\activate-env.ps1

# 5. Verify installation
flutter --version
claude --version  # Uses WSL wrapper
gemini --version
```

**Manual Setup (if needed):**
```powershell
# 1. Install Git for Windows (if not already installed)
# Download: https://git-scm.com/download/win

# 2. Install VS Code (if not already installed)  
# Download: https://code.visualstudio.com/

# 3. Install VS Code extensions
code --install-extension Dart-Code.flutter
code --install-extension Dart-Code.dart-code
```

**Android Development Tools (CLI-Only, Required for Phase 1):**
```powershell
# Install Android Studio (for SDK and tools only)
# Download: https://developer.android.com/studio
# Note: Android Studio GUI will NOT be used - only SDK tools and emulator
# All Android builds managed via Flutter CLI and build scripts

# Alternative: Android Command Line Tools only
# Download: https://developer.android.com/studio#command-tools
# Extract to: C:\src\android-sdk

# Verify command-line tools
flutter doctor  # Will check Android SDK installation
```

**Network Tools:**
```powershell
# Telnet (enable Windows feature)
Enable-WindowsOptionalFeature -Online -FeatureName TelnetClient

# PowerShell equivalent commands for testing
Test-NetConnection -ComputerName localhost -Port 23
```

**Verification:**
```powershell
# With local toolchain activated
flutter doctor

# Run environment verification  
.\tools\verify-environment.ps1  # (will be created)
```

## Cross-Platform Development Workflow

### Shared Project Structure
```
ghsender/                    # Identical on both platforms
├── lib/                     # Flutter/Dart source code
├── test/                    # Unit and integration tests  
├── docs/                    # Documentation (platform-agnostic)
├── team/                    # Agent coordination
├── tools/                   # Cross-platform scripts
└── pubspec.yaml            # Dependencies (same on both platforms)
```

## CLI-Driven Development Workflow

### Core Philosophy: Command-Line First
- **All builds via Flutter CLI** - No Xcode/Visual Studio GUI required
- **VS Code for all editing** - Consistent IDE experience across platforms
- **Automated scripts** - Platform-specific tasks handled by build automation
- **Minimal platform exposure** - Developers rarely interact with native tools directly

### Common Commands (Identical on Both Platforms)

**macOS/Linux (bash):**
```bash
# Activate environment
source ./tools/activate-env.sh

# Project setup
flutter create ghsender_app
flutter pub get

# Development workflow  
flutter run                    # Start development server
flutter run -d macos          # Run on macOS desktop
flutter run -d windows        # Run on Windows desktop (if cross-compiling)
flutter run -d ios            # Run on iOS simulator (macOS only)
flutter run -d android        # Run on Android emulator

# Build using project scripts
./tools/build.sh build macos
./tools/build.sh test
```

**Windows 11 (PowerShell):**
```powershell
# Activate environment  
. .\tools\activate-env.ps1

# Project setup (identical)
flutter create ghsender_app
flutter pub get

# Development workflow (identical)
flutter run                    # Start development server
flutter run -d windows        # Run on Windows desktop
flutter run -d android        # Run on Android emulator

# Build using project scripts
.\tools\build.ps1 build windows
.\tools\build.ps1 test
```

**Universal Commands (after environment activation):**
```bash
# Testing (identical)
flutter test                   # Unit tests
flutter test integration_test/ # Integration tests
flutter analyze               # Static analysis

# Building (CLI-only, no IDE required)
flutter build macos           # macOS desktop app (macOS only)
flutter build windows         # Windows desktop app  
flutter build ios             # iOS app (macOS only, uses Xcode CLI tools)
flutter build android         # Android app (uses Android SDK CLI)

# Git workflow (identical)
git checkout -b feature/new-feature
git commit -m "feat: add new feature"
git push origin feature/new-feature
```

### Platform-Specific CLI Commands

#### macOS iOS Builds (CLI-Only)
```bash
# All iOS operations via Flutter CLI - no Xcode GUI needed
flutter build ios --release
flutter build ipa              # App Store package

# iOS Simulator management via CLI
xcrun simctl list devices      # List available simulators
xcrun simctl boot "iPad Pro"   # Start specific simulator
flutter run -d ios            # Deploy to running simulator

# Code signing (when needed)
flutter build ios --export-options-plist=ios/ExportOptions.plist
```

#### Windows Android Builds (CLI-Only)
```bash
# All Android operations via Flutter CLI - no Android Studio GUI needed
flutter build android --release
flutter build appbundle        # Google Play package

# Android Emulator management via CLI
flutter emulators              # List available emulators
flutter emulators --launch Pixel_7 # Start specific emulator
flutter run -d android        # Deploy to running emulator

# APK signing (when needed)
flutter build apk --split-per-abi
```

### Platform-Specific Adaptations

### VS Code Configuration (Identical on Both Platforms)

**Required Extensions:**
```bash
# Core Flutter development
code --install-extension Dart-Code.flutter
code --install-extension Dart-Code.dart-code

# Enhanced development experience
code --install-extension ms-vscode.vscode-json     # JSON support
code --install-extension eamodio.gitlens          # Git integration
code --install-extension esbenp.prettier-vscode   # Code formatting
code --install-extension bradlc.vscode-tailwindcss # Tailwind support (if used)
```

**VS Code Settings (Cross-Platform):**
```json
{
  "dart.flutterSdkPath": "/path/to/flutter",  // Auto-detected usually
  "dart.debugExternalPackageLibraries": false,
  "dart.debugSdkLibraries": false,
  "flutter.hotReloadOnSave": true,
  "flutter.hotRestartOnSave": false,
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll": true
  },
  "files.associations": {
    "*.arb": "json"
  }
}
```

**Build Tasks Configuration:**
```json
// .vscode/tasks.json (works on both platforms)
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Flutter: Build for Current Platform",
      "type": "shell",
      "command": "${workspaceFolder}/tools/build.sh",
      "args": ["build", "macos"],
      "windows": {
        "command": "powershell",
        "args": ["-File", "${workspaceFolder}/tools/build.ps1", "build", "windows"]
      },
      "group": "build",
      "presentation": {
        "echo": true,
        "reveal": "always",
        "focus": false,
        "panel": "shared"
      },
      "problemMatcher": "$dart-flutter"
    }
  ]
}
```

#### Platform Differences (Minimized)
| Aspect | macOS | Windows 11 | VS Code Impact |
|--------|--------|------------|----------------|
| **Primary IDE** | VS Code | VS Code | ✅ Identical |
| **Build Scripts** | build.sh | build.ps1 | ✅ Automated |
| **Flutter CLI** | flutter | flutter | ✅ Identical |
| **Git Workflow** | git | git | ✅ Identical |
| **Platform Tools** | Xcode CLI | Android SDK CLI | ✅ Scripted |
| **Package Manager** | Homebrew | Chocolatey/winget | ⚠️ Setup only |
| **Terminal** | Terminal/iTerm2 | PowerShell/Terminal | ⚠️ Minor diff |

#### Tooling Adaptations
```bash
# macOS/Linux shell scripts
./tools/setup-toolchain.sh       # Automated toolchain setup
./tools/activate-env.sh          # Environment activation
./tools/build.sh                 # Build automation
./tools/setup-verification.sh    # Environment verification

# Windows PowerShell equivalents (native - no WSL required)
.\tools\setup-toolchain.ps1      # Automated toolchain setup
.\tools\activate-env.ps1          # Environment activation  
.\tools\build.ps1                 # Build automation
.\tools\setup-verification.ps1    # Environment verification
```

### ⚠️ **WSL Required for Agent Tools**
- **Flutter Development**: Native PowerShell support (no WSL needed)
- **Claude Code CLI**: Requires WSL on Windows 11
- **Gemini CLI**: Native PowerShell support (no WSL needed)
- **Hybrid Approach**: Core development native, AI tools via WSL
- **WSL Setup**: One-time installation: `wsl --install`

### 🏗️ **Architecture Benefits**
- **Core Development**: Native PowerShell performance for Flutter
- **AI Integration**: WSL provides Linux compatibility for Claude Code
- **Best of Both**: Native performance + maximum tool compatibility
- **Corporate Considerations**: WSL may be restricted in some enterprise environments

### CI/CD Cross-Platform Strategy

**GitHub Actions Matrix Build:**
```yaml
strategy:
  matrix:
    os: [macos-latest, windows-latest]
    
runs-on: ${{ matrix.os }}
steps:
  - uses: actions/checkout@v3
  - uses: subosito/flutter-action@v2
  - run: flutter test
  - run: flutter build windows  # on Windows
  - run: flutter build macos    # on macOS
```

## Phase 0 Cross-Platform Validation

### Technology Spikes on Both Platforms
1. **Real-time Communication Spike**
   - ✅ TCP sockets work identically on both platforms
   - ✅ Dart isolates behavior is consistent
   - ✅ Network debugging tools available on both

2. **Graphics Performance Spike**
   - ✅ Flutter Canvas rendering identical
   - ⚠️ Minor differences: Metal (macOS) vs DirectX (Windows)
   - ✅ Performance characteristics should be similar

3. **State Management Stress Test**
   - ✅ BLoC pattern identical on both platforms
   - ✅ Memory management consistent
   - ✅ Performance profiling available on both

### Cross-Platform Testing Strategy
```dart
// Platform detection for any differences
import 'dart:io' show Platform;

if (Platform.isMacOS) {
  // macOS-specific code (rare)
} else if (Platform.isWindows) {
  // Windows-specific code (rare)
}

// Most code should be platform-agnostic
```

## Development Team Coordination

### Mixed-Platform Team Benefits
- **Code Review Quality**: Different platform perspectives catch more issues
- **Testing Coverage**: Natural testing on both desktop platforms
- **Documentation Quality**: Platform-agnostic docs benefit everyone
- **Deployment Validation**: Early catch of platform-specific issues

### Coordination Protocols
- **Git Workflow**: Completely platform-agnostic
- **Documentation**: Platform-neutral with platform-specific notes where needed
- **Agent Coordination**: Shared workspace files work identically
- **Code Standards**: Dart/Flutter standards are platform-independent

## Complexity Impact Assessment

### ✅ **No Additional Complexity** Areas:
- Core Flutter/Dart development
- Git workflow and version control
- Documentation and team coordination
- Agent-based development approach
- Testing and quality assurance
- API and service development

### ⚠️ **Minor Platform Considerations** Areas:
- Initial tooling setup (different installation procedures)
- Build scripts and automation (shell vs PowerShell)
- Mobile emulator setup (iOS vs Android)
- Platform-specific debugging tools

### 📊 **Overall Impact**: **Very Low**
- 95% of development work is identical across platforms
- 5% requires platform-specific setup or tooling adaptations
- Team productivity not significantly impacted
- Code quality potentially improved through diverse platform testing

## CLI-First Development Benefits

### ✅ **Platform Independence Achieved**
- **VS Code Primary**: 95% of development in consistent VS Code environment
- **CLI Automation**: Platform tools (Xcode/Visual Studio) accessed only via scripts
- **No GUI Lock-in**: Developers never need to learn platform-specific IDEs
- **Consistent Experience**: Same keyboard shortcuts, extensions, debugging across platforms
- **Reduced Complexity**: No context switching between different development environments

### 🚫 **Avoided Platform Dependencies**
- **No Xcode GUI**: iOS builds via `flutter build ios` and Xcode command-line tools only
- **No Visual Studio GUI**: Windows builds via `flutter build windows` and SDK tools only
- **No Android Studio GUI**: Android builds via `flutter build android` and SDK CLI only
- **No Platform IDE Learning**: Team doesn't need to learn multiple development environments
- **No IDE Configuration Drift**: Single VS Code config works everywhere

### 📋 **Build Automation Strategy**
```bash
# Identical commands on both platforms
./tools/build.sh setup     # or .\tools\build.ps1 setup
./tools/build.sh test      # or .\tools\build.ps1 test  
./tools/build.sh build ios # or .\tools\build.ps1 build windows
```

## Recommendations

### ✅ **Proceed with VS Code-First Cross-Platform Support**
- Flutter's CLI-driven approach eliminates platform IDE dependencies
- VS Code provides identical development experience across platforms
- Build automation handles platform-specific tasks transparently
- Team flexibility benefits with no development environment complexity
- No impact on Phase 0 technology validation timeline

### 📝 **Implementation Strategy**
1. **VS Code as primary IDE** - All development activities in VS Code
2. **CLI-driven builds** - Platform tools accessed only via automated scripts
3. **Cross-platform scripts** - Handle platform differences transparently
4. **Test Phase 0 spikes on both platforms** for validation
5. **Establish automated CI/CD** with matrix builds
6. **Minimal platform detection** in code

### 🎯 **Phase 0 Impact: NONE**
- Desktop Flutter development identical on both platforms
- Technology spikes work the same way on macOS and Windows 11
- VS Code debugging and development experience consistent
- No platform-specific dependencies during validation phase

Cross-platform development support with VS Code-first approach adds significant value with **zero additional complexity** for core development work.