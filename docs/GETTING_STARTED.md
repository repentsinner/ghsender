# Getting Started with ghSender Development

**Last Updated**: January 18, 2025  
**Status**: Active development - Phase 1

## Quick Start

### Prerequisites
- **macOS** or **Windows 11** (primary development platforms)
- **Git** for version control
- **Flutter SDK** (latest stable)
- **Dart SDK** (included with Flutter)

### 1. Clone and Setup

```bash
# Clone the repository
git clone https://github.com/your-org/ghsender.git
cd ghsender

# macOS setup
./tools/setup-toolchain.sh && ./tools/setup-agent-tools.sh
source ./tools/activate-env.sh

# Windows 11 setup
wsl --install  # Restart after installation
.\tools\setup-toolchain.ps1 && .\tools\setup-agent-tools.ps1
. .\tools\activate-env.ps1
```

### 2. Verify Installation

```bash
# Check Flutter installation
flutter doctor

# Run the application
flutter run -d macos  # or -d windows
```

### 3. First Run

1. **Launch the application** - You'll see a 3D G-code visualizer
2. **Load a G-code file** - Use the file browser to load a test file
3. **View 3D visualization** - Pan, zoom, and rotate the toolpath display
4. **Check performance** - Should achieve 120fps on high-refresh displays

## Development Environment

### Recommended IDE Setup

**VS Code Extensions:**
- Flutter
- Dart
- GitLens
- Error Lens
- Bracket Pair Colorizer

**IntelliJ/Android Studio:**
- Flutter plugin
- Dart plugin
- Git integration

### Project Structure

```
ghsender/
├── lib/                        # Main application code
│   ├── bloc/                   # State management (BLoC pattern)
│   ├── models/                 # Data models
│   ├── renderers/              # 3D rendering engine
│   ├── scene/                  # 3D scene management
│   ├── gcode/                  # G-code processing
│   └── ui/                     # User interface
├── test/                       # Unit and widget tests
├── docs/                       # Documentation
└── tools/                      # Development scripts
```

### Key Commands

```bash
# Development
flutter run --debug              # Run in debug mode
flutter run --profile           # Run with performance profiling
flutter run --release           # Run optimized build

# Testing
flutter test                     # Run unit tests
flutter test --coverage         # Run with coverage report

# Code Quality
flutter analyze                  # Static analysis
dart format lib/                 # Format code
```

## Multi-Agent Development

This project uses AI agents for development assistance:

### Claude Code Integration
- **Purpose**: Architecture design and complex refactoring
- **Setup**: Integrated with VS Code
- **Usage**: Available for code review and implementation guidance

### Gemini CLI Integration  
- **Purpose**: Code generation and testing
- **Setup**: Command-line interface
- **Usage**: Automated code generation and validation

### Agent Coordination
- Agents work collaboratively on different aspects
- Human oversight for all architectural decisions
- Automated testing validates agent contributions

## Current Development Focus

### What's Working (January 2025)
- ✅ **3D G-code Visualization** - 120fps rendering with Flutter Scene
- ✅ **WebSocket Communication** - 125Hz status updates from grblHAL
- ✅ **G-code Processing** - Parser for G0/G1/G2/G3 commands
- ✅ **Cross-Platform** - macOS and Windows 11 development

### Active Development
- 🚧 **Domain-Driven Architecture** - Refactoring BLoC structure
- 🚧 **Safety Systems** - Work envelope protection
- 🚧 **Hardware Validation** - Testing with physical CNC controllers

### Not Yet Started
- ❌ **Manual Workflows** - Tool changes, touchoff procedures
- ❌ **Adaptive Learning** - Skill-based UI progression
- ❌ **Touch Interface** - Tablet optimization

## Development Workflow

### 1. Feature Development
1. **Check current status** - Review `CURRENT_STATUS.md`
2. **Create feature branch** - `git checkout -b feature/your-feature`
3. **Follow architecture** - Use domain-driven design patterns
4. **Write tests** - Unit tests for domain logic
5. **Submit PR** - Include tests and documentation

### 2. Testing Strategy
- **Unit Tests** - Domain logic and business rules
- **Widget Tests** - UI components and interactions
- **Integration Tests** - End-to-end workflows
- **Performance Tests** - Maintain 125Hz/120fps benchmarks

### 3. Code Quality
- **Static Analysis** - `flutter analyze` must pass
- **Formatting** - `dart format` enforced
- **Documentation** - Public APIs must be documented
- **Performance** - No regressions in benchmarks

## Troubleshooting

### Common Issues

**Flutter Doctor Issues:**
```bash
# Android toolchain not needed for desktop development
flutter config --no-enable-android

# iOS toolchain only needed on macOS
flutter config --enable-macos-desktop
flutter config --enable-windows-desktop  # Windows only
```

**Build Failures:**
```bash
# Clean build artifacts
flutter clean
flutter pub get

# Reset Flutter cache
flutter pub cache repair
```

**Performance Issues:**
```bash
# Run with performance profiling
flutter run --profile --trace-startup
```

### Getting Help

1. **Check Documentation** - Review `CURRENT_STATUS.md` and `TECHNICAL_REFERENCE.md`
2. **Search Issues** - GitHub issues for known problems
3. **Ask Questions** - GitHub discussions for development questions
4. **Performance Issues** - Include profiling data with reports

## Next Steps

1. **Explore the Code** - Start with `lib/main.dart` and `lib/ui/screens/grblhal_visualizer.dart`
2. **Run Tests** - `flutter test` to understand current test coverage
3. **Review Architecture** - Read `TECHNICAL_REFERENCE.md` for system design
4. **Check Roadmap** - See `PLANNED_FEATURES.md` for future development

## Contributing

1. **Read the Code** - Understand current implementation
2. **Start Small** - Bug fixes and small improvements
3. **Follow Patterns** - Use established BLoC and domain patterns
4. **Test Everything** - Maintain test coverage
5. **Document Changes** - Update relevant documentation

Welcome to ghSender development! The project is in active development with a focus on building a solid foundation for advanced CNC control features.