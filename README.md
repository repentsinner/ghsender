# ghSender

**A modern, safety-first CNC controller for grblHAL with adaptive learning**

*An homage to gSender, optimized for grblHAL*

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev)
[![Cross-Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Windows%20%7C%20iPad-blue)](docs/development/CROSS_PLATFORM_SETUP.md)
[![Multi-Agent](https://img.shields.io/badge/AI-Claude%20%7C%20Gemini-green)](docs/development/AGENT_TOOLS.md)

## What is ghSender?

ghSender is a **next-generation CNC controller** designed to make CNC machining **safer, smarter, and more accessible**. Whether you're a complete beginner or an experienced machinist, our adaptive learning system grows with your skills.

Built specifically for **grblHAL**, ghSender takes advantage of advanced features like tool changers, probes, and networked communication while maintaining the reliability and precision that CNC users demand.

### 🎯 **For Beginners**
- **Step-by-step guidance** through every operation
- **Built-in safety checks** prevent costly mistakes
- **Interactive learning** that adapts to your progress
- **Clear visual feedback** shows exactly what's happening

### ⚡ **For Experts** 
- **Streamlined workflows** for maximum efficiency
- **Advanced features** unlock automatically as you demonstrate competency
- **Customizable interface** tailored to your preferences
- **Professional-grade reliability** for production work

## Key Features

### 🛡️ **Safety First**
- **Pre-flight validation** catches errors before they reach your machine
- **Work envelope protection** prevents crashes and tool breaks
- **Emergency stop** integration with visual and audio alerts
- **Tool change workflows** with built-in safety checkpoints

### 🧠 **Adaptive Learning**
- **Skill assessment** automatically adjusts interface complexity
- **Progressive disclosure** reveals advanced features as you're ready
- **Learning milestones** track your CNC mastery journey
- **Contextual help** provides guidance exactly when you need it

### 🔗 **grblHAL Integration**
- **Native TCP/IP** communication for reliable, high-speed control
- **Real-time status** with <100ms latency
- **Advanced features** support for tool changers, probes, and sensors
- **Future-proof** compatibility with grblHAL evolution

### 📱 **Modern Interface**
- **Touch-first design** optimized for tablets and touchscreens
- **Responsive layout** works on desktop, tablet, and mobile
- **Dark/light themes** for any lighting condition
- **Customizable workspace** arrange panels to fit your workflow

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

## Development Status

🚧 **Currently in Phase 0 - Technology Validation**

- ✅ **Project Architecture** - Complete development framework established
- ✅ **Cross-Platform Toolchain** - macOS and Windows 11 development ready
- ✅ **Multi-Agent Development** - Claude Code and Gemini CLI integration
- 🚧 **Flutter Technology Spikes** - Validating real-time communication and graphics performance
- ⏳ **Core grblHAL Integration** - TCP/IP communication layer
- ⏳ **Adaptive Learning Engine** - User skill assessment and progression

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
- **Communication**: TCP/IP for reliable grblHAL integration
- **State Management**: BLoC pattern for predictable, testable code
- **AI Integration**: Claude Code and Gemini CLI for development assistance
- **Platforms**: macOS, Windows 11, iPad (with Android planned)

[🔧 **Technical Details**](docs/ARCHITECTURE.md)

## Safety Notice

⚠️ **This software is in active development. Do not use with production machines without proper safety precautions.**

- Always test with a simulator first
- Keep emergency stop within reach
- Verify all tool paths before running
- Start with slow feed rates and low spindle speeds

## License

This project is licensed under the [MIT License](LICENSE).

## Community

- **Issues**: [GitHub Issues](https://github.com/your-org/ghsender/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/ghsender/discussions)
- **Discord**: [CNC Community](https://discord.gg/your-invite)

---

**Built with ❤️ for the CNC community**