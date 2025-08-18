# ghSender Documentation

**Last Updated**: January 18, 2025  
**Status**: Consolidated and current

## Quick Navigation

### 🚀 **Start Here**
- [**GETTING_STARTED.md**](GETTING_STARTED.md) - Setup, first run, and development workflow
- [**CURRENT_STATUS.md**](CURRENT_STATUS.md) - What actually works now vs. what's planned

### 📋 **Project Information**
- [**PLANNED_FEATURES.md**](PLANNED_FEATURES.md) - Product vision, roadmap, and future features
- [**TECHNICAL_REFERENCE.md**](TECHNICAL_REFERENCE.md) - Architecture, patterns, and implementation

### 🔧 **Active Development**
- [**REFACTORING_PLAN.md**](REFACTORING_PLAN.md) - Current architecture improvements (Domain-Driven Design)

## What is ghSender?

ghSender is a **high-performance 3D G-code visualizer** with **ultra-responsive grblHAL communication** currently in active development. It achieves industry-leading performance with **125Hz status updates** and **120fps 3D rendering**.

**Current Reality**: Advanced 3D visualizer with proven communication performance  
**Future Vision**: Complete safety-first CNC controller with adaptive learning

## Documentation Structure

This documentation has been **consolidated from 30+ scattered files** into **4 main documents** for easier navigation:

### **GETTING_STARTED.md**
*Everything you need to start developing*
- Development environment setup (macOS, Windows 11)
- Project structure and key commands
- Multi-agent development tools
- Troubleshooting and getting help

### **CURRENT_STATUS.md**
*Honest assessment of what actually works*
- Performance achievements (125Hz, 120fps)
- Implementation status by component
- Known issues and limitations
- Development priorities

### **PLANNED_FEATURES.md**
*Product vision and future roadmap*
- Target users and value proposition
- Detailed feature specifications
- Implementation timeline
- Success metrics and validation

### **TECHNICAL_REFERENCE.md**
*Architecture and implementation details*
- Current and planned architecture
- Performance specifications
- Development patterns and guidelines
- Testing strategies

## For Different Audiences

### **New Contributors**
1. Read [GETTING_STARTED.md](GETTING_STARTED.md) for setup
2. Check [CURRENT_STATUS.md](CURRENT_STATUS.md) to understand what's implemented
3. Review [TECHNICAL_REFERENCE.md](TECHNICAL_REFERENCE.md) for architecture

### **Users/Testers**
1. See [CURRENT_STATUS.md](CURRENT_STATUS.md) for current capabilities
2. Check [PLANNED_FEATURES.md](PLANNED_FEATURES.md) for future features
3. Review safety warnings - **not ready for production CNC use**

### **Project Stakeholders**
1. Review [PLANNED_FEATURES.md](PLANNED_FEATURES.md) for product vision
2. Check [CURRENT_STATUS.md](CURRENT_STATUS.md) for progress
3. See [TECHNICAL_REFERENCE.md](TECHNICAL_REFERENCE.md) for technical details

## Key Project Status

### ✅ **What's Working (January 2025)**
- **Industry-leading performance**: 125Hz communication, 120fps rendering
- **3D G-code visualization**: Flutter Scene with custom shaders
- **Cross-platform development**: macOS and Windows 11 environments
- **Advanced G-code processing**: Parser with arc interpolation

### 🚧 **In Active Development**
- **Domain-driven architecture**: Refactoring for maintainability and safety
- **Hardware validation**: Testing with physical grblHAL controllers
- **Safety foundation**: Basic validation and error handling

### 📋 **Planned (Not Started)**
- **Safety systems**: Work envelope protection, collision detection
- **Manual workflows**: Tool changes, workpiece setup procedures
- **Adaptive learning**: Skill-based UI progression
- **Touch interface**: Tablet optimization

## Archive

Historical documentation has been preserved in the `archive/` directory:
- `archive/analysis/` - Technical analysis documents (decisions made)
- `archive/workflows/` - Workflow specifications (features not implemented)
- `archive/widgets/` - Widget specifications (components not built)
- `archive/development/` - Detailed setup guides (consolidated into GETTING_STARTED.md)

## Contributing to Documentation

1. **Update main documents** - Keep the 4 core documents current
2. **Avoid creating new files** - Add to existing documents unless absolutely necessary
3. **Maintain honesty** - Clear distinction between implemented vs. planned
4. **Cross-reference** - Link between related sections in different documents

---

**Quick Start**: New to the project? Start with [GETTING_STARTED.md](GETTING_STARTED.md)  
**Current Status**: Want to know what works? See [CURRENT_STATUS.md](CURRENT_STATUS.md)  
**Future Plans**: Interested in the vision? Read [PLANNED_FEATURES.md](PLANNED_FEATURES.md)