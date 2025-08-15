# ghSender

**A modern, safety-first CNC controller for grblHAL with adaptive learning**

*An homage to gSender, optimized for grblHAL*

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev)
[![Cross-Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Windows%20%7C%20iPad-blue)](docs/development/CROSS_PLATFORM_SETUP.md)
[![Multi-Agent](https://img.shields.io/badge/AI-Claude%20%7C%20Gemini-green)](docs/development/AGENT_TOOLS.md)

## What is ghSender?

ghSender is a **modern CNC controller** built with Flutter for **grblHAL** firmware. It combines real-time machine control with advanced 3D visualization, providing a responsive touch-first interface for CNC machining.

**Current Capabilities:**
- **Real-time grblHAL Communication** - WebSocket connection with <100ms status updates
- **Advanced 3D Visualization** - High-performance line rendering with 35,000+ segments at 60fps
- **Manual Machine Control** - Complete jogging system with configurable feed rates and distances
- **G-code Processing** - Full pipeline from file loading to 3D toolpath visualization
- **Cross-Platform** - Native performance on macOS, Windows, and iPad

**Planned Features:**
- **Adaptive Learning System** - Interface complexity that grows with your skills
- **Advanced Safety Features** - Work envelope protection and pre-flight validation
- **Tool Change Workflows** - Automated sequences with safety checkpoints

### 🎯 **Current Features**
- **Real-time Machine Control** - Direct grblHAL communication with live status updates
- **3D Toolpath Visualization** - High-performance rendering of G-code programs
- **Manual Jogging** - Precise machine positioning with configurable step sizes
- **G-code File Management** - Load, parse, and visualize CNC programs

### ⚡ **In Development** 
- **Adaptive Learning System** - Interface that grows with your experience level
- **Safety-First Design** - Pre-flight validation and work envelope protection
- **Touch-Optimized Interface** - Designed for tablets with desktop compatibility
- **Advanced Workflows** - Tool changes, probing, and workpiece setup

## Key Features

### 🔗 **grblHAL Integration** - ✅ Implemented
- **WebSocket Communication** - Reliable, high-speed control with real-time status
- **Machine State Management** - Complete tracking of position, status, and configuration
- **Manual Control** - Jogging, homing, and direct G-code command execution
- **grblHAL Detection** - Automatic firmware identification and configuration

### 🎨 **Advanced Graphics** - ✅ Implemented  
- **High-Performance Rendering** - 35,000+ line segments at 60fps using Flutter Scene
- **3D Toolpath Visualization** - Real-time G-code program display
- **Custom Shaders** - Anti-aliased line rendering with configurable thickness
- **Interactive Camera** - Pan, zoom, and rotate with touch or mouse controls

### 📁 **G-code Processing** - ✅ Implemented
- **File Management** - Load and manage G-code files with native file picker
- **Advanced Parser** - Support for G0/G1/G2/G3 commands with arc interpolation
- **Bounds Calculation** - Automatic work envelope detection and validation
- **Real-time Updates** - Live scene updates as files are processed

### 🛡️ **Safety Systems** - 🚧 In Progress
- **Basic Alarm Handling** - Machine alarm detection and user notification
- **State Validation** - Proper state transitions and error recovery
- **Emergency Stop** - Real-time command integration (hardware dependent)
- **Work Envelope Protection** - Planned for Phase 2

### 🧠 **Adaptive Learning** - 📋 Planned
- **Skill Assessment** - Interface complexity based on demonstrated competency
- **Progressive Disclosure** - Advanced features unlock as skills develop
- **Learning Milestones** - Track CNC mastery progression
- **Contextual Guidance** - Step-by-step workflows for complex operations

## Quick Start

### Installation

**macOS:**
```bash
git clone https://github.com/your-org/ghsender.git
cd ghsender
./tools/setup-toolchain.sh && ./tools/setup-agent-tools.sh
source ./tools/activate-env.sh
```

**Windows 11:**
```powershell
git clone https://github.com/your-org/ghsender.git
cd ghsender
wsl --install  # Restart after installation
.\tools\setup-toolchain.ps1 && .\tools\setup-agent-tools.ps1
. .\tools\activate-env.ps1
```

### First Run

1. **Connect to your grblHAL controller** via TCP/IP
2. **Load a G-Code file** using the built-in file browser
3. **Set your workpiece origin** with guided touch-off workflows
4. **Run your first job** with real-time monitoring and safety checks

[📖 **Full Setup Guide**](docs/development/CROSS_PLATFORM_SETUP.md)

## Current Implementation Status

**What Works Now:**
- ✅ Connect to grblHAL controllers via WebSocket
- ✅ Real-time machine status monitoring (position, state, alarms)
- ✅ Manual machine control (jogging, homing, direct G-code commands)
- ✅ G-code file loading and parsing (G0/G1/G2/G3 support)
- ✅ 3D toolpath visualization with high-performance rendering
- ✅ Cross-platform development (macOS, Windows 11)

**In Active Development:**
- 🚧 Hardware validation with physical machines
- 🚧 Enhanced safety systems and error handling
- 🚧 Tool change and probing workflows
- 🚧 Work envelope protection and collision detection

**Planned Features:**
- 📋 Adaptive learning system for progressive skill development
- 📋 Advanced workflow templates and automation
- 📋 Community plugin marketplace
- 📋 CAM software integration

## Development Status

🚀 **Phase 0 Complete - Moving to Phase 1**

### ✅ **Phase 0: Technology Validation** - Complete
- ✅ **Real-time Communication Spike** - WebSocket communication with grblHAL validated
- ✅ **Graphics Performance Spike** - Flutter Scene rendering with 35K+ line segments at 60fps
- ✅ **State Management Stress Test** - BLoC pattern handling 100 events/second
- ✅ **Cross-Platform Toolchain** - macOS and Windows 11 development ready
- ✅ **Multi-Agent Development** - Claude Code and Gemini CLI integration

### 🚧 **Phase 1: Core Communication** - In Progress
- ✅ **grblHAL Communication** - WebSocket connection and real-time status streaming
- ✅ **Machine State Management** - Complete BLoC architecture for machine control
- ✅ **Manual Jogging Controls** - Full axis control with configurable feed rates
- ✅ **G-code Processing Pipeline** - File loading, parsing, and 3D visualization
- 🚧 **Safety Systems** - Basic alarm handling and state validation
- 📋 **Hardware Integration Testing** - Ready for physical machine validation

### 📋 **Phase 2: Advanced Features** - Ready to Start
- 📋 **Adaptive Learning Engine** - User skill assessment and progression (scaffolded)
- 📋 **Advanced Safety Features** - Work envelope protection and pre-flight validation
- 📋 **Tool Change Workflows** - Automated tool change sequences
- 📋 **Probe Integration** - Touch-off and measurement workflows

[📋 **Development Plan**](docs/DEVELOPMENT_PLAN.md) | [🏗️ **Architecture**](docs/ARCHITECTURE.md)

## Contributing

We welcome contributions from the CNC community! Whether you're a developer, machinist, or educator, there are many ways to help:

- **Code contributions** - Flutter/Dart development
- **Testing** - Try the software with your CNC setup
- **Documentation** - Improve guides and tutorials  
- **Feedback** - Share your experience and suggestions
- **Translations** - Help make it accessible worldwide

[🤝 **Contributing Guide**](docs/DEVELOPMENT_PLAN.md#team-coordination)

## Technology Stack

- **Framework**: Flutter/Dart for cross-platform native performance
- **Graphics**: Flutter Scene with custom GLSL shaders for high-performance 3D rendering
- **Communication**: WebSocket for reliable grblHAL integration
- **State Management**: BLoC pattern for predictable, real-time state handling
- **Architecture**: Layered service architecture with functional programming principles
- **Development**: Multi-agent AI assistance (Claude Code and Gemini CLI)
- **Platforms**: macOS, Windows 11, iPad (Android support planned)

[🔧 **Technical Details**](docs/ARCHITECTURE.md)

## Safety Notice

⚠️ **This software is in active development (Phase 1). Use with appropriate caution.**

**Current Safety Status:**
- ✅ **Basic Communication** - Stable grblHAL connection and status monitoring
- ✅ **Manual Control** - Jogging and positioning controls functional
- ✅ **Alarm Detection** - Machine alarms properly detected and displayed
- 🚧 **Work Envelope Protection** - In development for Phase 2
- 🚧 **Pre-flight Validation** - G-code safety checks planned for Phase 2

**Recommended Precautions:**
- Always test with grblHAL simulator first
- Keep emergency stop within reach during operation
- Verify all tool paths and work coordinates before running programs
- Start with conservative feed rates and spindle speeds
- Ensure proper machine setup and calibration

## License

This project is licensed under the [MIT License](LICENSE).

## Community

- **Issues**: [GitHub Issues](https://github.com/your-org/ghsender/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/ghsender/discussions)
- **Discord**: [CNC Community](https://discord.gg/your-invite)

---

**Built with ❤️ for the CNC community**