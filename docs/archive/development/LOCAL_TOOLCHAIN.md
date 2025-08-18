# Local Toolchain Strategy

**Author**: DevOps Engineer  
**Date**: 2025-07-13  
**Purpose**: Container-style development for desktop GUI software with isolated project dependencies

## Philosophy: Container-Style Development Without Containers

Desktop GUI software development doesn't lend itself well to containerization due to:
- Graphics acceleration requirements
- Native platform integration needs  
- IDE integration complexity
- Real-time hardware communication (CNC controllers)

However, we can achieve similar **dependency isolation** and **reproducible environments** using a local toolchain approach.

## Local Toolchain Directory Structure

```
ghsender/
├── toolchain/                 # Git-ignored, contains all project-specific tools
│   ├── flutter/              # Flutter SDK installation
│   ├── dart-sdk/             # Dart SDK (if separate from Flutter)
│   ├── scripts/              # Environment setup and activation scripts
│   ├── cache/                # Package caches and build artifacts
│   └── config/               # Tool-specific configuration files
├── tools/                    # Checked-in scripts that use toolchain/
│   ├── setup-toolchain.sh    # Initial toolchain installation
│   ├── activate-env.sh       # Activate project environment
│   ├── build.sh              # Build using local toolchain
│   └── build.ps1             # Windows equivalent
└── .envrc                    # Optional: direnv integration
```

## Benefits of Local Toolchain Approach

### ✅ **Container-Style Isolation**
- **Dependency Isolation**: No impact on system-wide tool versions
- **Version Pinning**: Exact tool versions specified per project
- **Clean Environment**: Easy to reset by deleting `toolchain/` directory
- **Reproducible Builds**: Same tool versions across all development machines

### ✅ **Desktop GUI Compatibility**
- **Native Performance**: Full graphics acceleration and platform integration
- **IDE Integration**: VS Code works naturally with local tools
- **Hardware Access**: Direct CNC controller communication
- **Platform Tools**: Xcode/Visual Studio integration preserved

### ✅ **Team Collaboration**
- **Consistent Environments**: All developers use identical tool versions
- **Easy Onboarding**: Single script setup for new team members
- **No System Pollution**: Developers' personal tool chains unaffected
- **CI/CD Ready**: Same toolchain approach works in automated environments

## Implementation Strategy

### Phase 1: Flutter SDK Local Installation

```bash
# Download and install Flutter in project toolchain
./tools/setup-toolchain.sh

# Activate project environment (adds toolchain/flutter/bin to PATH)
source ./tools/activate-env.sh

# Verify local installation
flutter --version  # Uses toolchain/flutter/bin/flutter
```

### Phase 2: VS Code Integration

```json
// .vscode/settings.json - Project-specific tool paths
{
  "dart.flutterSdkPath": "./toolchain/flutter",
  "dart.sdkPath": "./toolchain/flutter/bin/cache/dart-sdk",
  "terminal.integrated.env.osx": {
    "PATH": "${workspaceFolder}/toolchain/flutter/bin:${env:PATH}"
  },
  "terminal.integrated.env.windows": {
    "PATH": "${workspaceFolder}/toolchain/flutter/bin;${env:PATH}"
  }
}
```

### Phase 3: Environment Activation Scripts

**Automatic Activation Options:**
1. **Manual Source**: `source ./tools/activate-env.sh` before work session
2. **direnv Integration**: Automatic activation when entering directory
3. **VS Code Tasks**: Integrated terminal automatically uses local toolchain
4. **Shell Functions**: Wrapper functions for common development commands

## OS-Dependent Platform Tools

### ✅ **Can Be Localized**
- **Flutter SDK**: Complete self-contained installation
- **Dart SDK**: Included with Flutter or standalone
- **Node.js/npm**: For web builds and tooling (if needed)
- **Build Tools**: Flutter-specific build chains
- **Package Caches**: Pub cache, CocoaPods, etc.

### ⚠️ **System Dependencies (Unavoidable)**
- **Xcode Command Line Tools**: Required for iOS builds on macOS
- **Visual Studio Build Tools**: Required for Windows builds
- **Android SDK**: Can be localized but often system-wide
- **Git**: Core version control (though could be localized)
- **System Compilers**: clang, MSVC, etc.

### 📋 **Hybrid Approach**
- **Core Platform Tools**: Document system requirements clearly
- **Development Tools**: Install locally in `toolchain/`
- **Version Verification**: Scripts verify system tools meet minimum versions
- **Graceful Degradation**: Clear error messages when system dependencies missing

## Tool Version Management

### Pinned Versions Strategy
```bash
# tools/versions.sh - Single source of truth for tool versions
FLUTTER_VERSION="3.24.5"
DART_VERSION="3.5.4"  
ANDROID_SDK_VERSION="34.0.0"
XCODE_MIN_VERSION="15.0"
```

### Version Verification
```bash
# Verify all required tools are available and correct versions
./tools/verify-environment.sh

# Output example:
# ✅ Flutter 3.24.5 (local)
# ✅ Dart 3.5.4 (local) 
# ✅ Xcode 15.1 (system)
# ⚠️  Android SDK not found - run ./tools/setup-android.sh
```

## Development Workflow

### Daily Development Session
```bash
# 1. Activate project environment
cd /path/to/ghsender
source ./tools/activate-env.sh

# 2. Verify environment is ready
./tools/verify-environment.sh

# 3. Normal development workflow
flutter pub get
flutter run
flutter test

# 4. Build for specific platform
./tools/build.sh build macos
```

### New Team Member Onboarding
```bash
# 1. Clone repository
git clone <repo-url>
cd ghsender

# 2. Run complete toolchain setup
./tools/setup-toolchain.sh

# 3. Verify everything works
./tools/verify-environment.sh
flutter doctor

# 4. Start development
source ./tools/activate-env.sh
flutter run
```

### Environment Reset/Cleanup
```bash
# Complete reset - removes all local tools
rm -rf toolchain/

# Reinstall fresh environment
./tools/setup-toolchain.sh
```

## CI/CD Integration

### GitHub Actions Strategy
```yaml
# Same toolchain approach works in CI
- name: Setup Local Toolchain
  run: ./tools/setup-toolchain.sh

- name: Activate Environment
  run: source ./tools/activate-env.sh

- name: Build and Test
  run: |
    flutter test
    flutter build macos
```

## VS Code Integration

### Project-Specific Tool Configuration
```json
// .vscode/settings.json
{
  "dart.flutterSdkPath": "./toolchain/flutter",
  "terminal.integrated.defaultProfile.osx": "bash",
  "terminal.integrated.profiles.osx": {
    "ghsender-dev": {
      "path": "/bin/bash",
      "args": ["-c", "source ./tools/activate-env.sh && exec bash"]
    }
  }
}
```

### Build Tasks Using Local Toolchain
```json
// .vscode/tasks.json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Flutter: Hot Reload",
      "type": "shell", 
      "command": "./tools/flutter-dev.sh",
      "args": ["run", "-d", "macos"],
      "group": "build"
    }
  ]
}
```

## Advanced: direnv Integration (Optional)

### Automatic Environment Activation
```bash
# .envrc - Automatically sources environment when entering directory
source_env ./tools/activate-env.sh

# When you cd into the project:
# direnv: loading ~/dev/ghsender/.envrc
# direnv: export +FLUTTER_HOME +PATH
```

## Benefits Summary

### ✅ **Achieves Container-Style Benefits**
- Isolated dependencies per project
- Reproducible development environments  
- Easy environment reset and cleanup
- Version pinning and consistency

### ✅ **Maintains Desktop GUI Advantages**
- Native performance and platform integration
- IDE integration and debugging capabilities
- Direct hardware access for CNC communication
- Platform-specific tooling (Xcode, Visual Studio) preserved

### ✅ **Team and CI/CD Ready**
- Consistent environments across team members
- Single-script setup for new developers
- Same approach works in automated build systems
- Clear documentation of all dependencies

This approach gives us the **dependency isolation of containers** while maintaining the **native performance and integration** required for desktop GUI development with CNC hardware.