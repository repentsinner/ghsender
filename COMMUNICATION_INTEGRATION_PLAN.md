# CNC Communications Integration Plan

## Executive Summary

This document outlines the comprehensive integration of WebSocket-based CNC communication capabilities from `spike/communication-spike` into the main `spike/graphics_performance_spike` application. The goal is to transform the app from a visualization-only tool into a full-featured CNC controller while preserving all existing 3D visualization and file management capabilities.

**Key Objectives:**
- Enable real CNC machine control via WebSocket communication
- Implement professional-grade G-code streaming with proper job control
- Add real-time machine commands (jogging, configuration, emergency controls)  
- Maintain unified logging system (no dual logging frameworks)
- Seamless integration with existing FileManager → Visualization workflow

## Current State Analysis

### Existing Components (graphics_performance_spike)
- ✅ **FileManagerBloc**: Persistent file selection and management
- ✅ **GCodeProcessor**: File parsing and scene integration
- ✅ **SceneManager**: 3D visualization of G-code
- ✅ **CncConnectionBloc**: Basic simulated connection state
- ✅ **Logger system**: Custom logger using `logger` package
- ✅ **VS Code-style UI**: Activity bar, sidebars, panels

### Available Components (communication-spike)
- 📦 **GrblCommunicationBloc**: Full WebSocket communication with GRBL
- 📦 **Performance monitoring**: Latency tracking, UI responsiveness
- 📦 **Jog testing**: Automated machine movement validation
- 📦 **WebSocket test server**: Development/testing infrastructure
- 📦 **Dual logging**: Uses `logging` package (conflicts with existing)

### Integration Requirements
- 🔄 **Replace** basic CncConnectionBloc with full communication system
- 🔄 **Add** G-code streaming engine for job execution
- 🔄 **Implement** real-time command system
- 🔄 **Unify** logging systems (remove dual logging)
- 🔄 **Extend** UI with communication controls

## Technical Architecture

### Communication Layer Structure
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  FileManager    │───▶│  GCodeRunner     │───▶│ CncCommunication│
│     Bloc        │    │      Bloc        │    │      Bloc       │
├─────────────────┤    ├──────────────────┤    ├─────────────────┤
│ - File selection│    │ - Job control    │    │ - WebSocket     │
│ - Upload/delete │    │ - Progress track │    │ - Real-time cmds│
│ - Persistence   │    │ - Stream G-code  │    │ - State polling │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Scene Manager                               │
│  - 3D Visualization  - Camera Control  - Renderer Updates      │
└─────────────────────────────────────────────────────────────────┘
```

### State Management Integration
- **FileManagerBloc**: Manages file list, selection, upload/delete
- **GCodeRunnerBloc**: Controls job execution, progress tracking, pause/resume
- **CncCommunicationBloc**: Handles WebSocket, real-time commands, machine state
- **Event Flow**: File selected → Parsed → Visualized → Executable → Streamed

### Communication Protocol Support
- **GRBL/grblHAL**: Primary CNC controller protocol
- **WebSocket**: Real-time bidirectional communication  
- **Command Types**:
  - G-code streaming (job execution)
  - Real-time commands (jogging, emergency stops)
  - Status queries (position, machine state)
  - Configuration commands (settings management)

## Implementation Phases

### Phase 0: Planning & Documentation ✅ CURRENT
- [x] Create comprehensive integration plan
- [x] Document technical architecture
- [x] Define implementation phases
- [x] Set up todo tracking

### Phase 1: Logging System Unification
**Objective**: Single logging system across entire application

**Tasks:**
1. **Refactor existing logger** (`lib/utils/logger.dart`)
   - Keep `logger` package as foundation
   - Maintain existing `AppLogger.info/debug/warning/error` API
   - Add communication-specific logger instances
2. **Update communication-spike code** during integration
   - Replace `logging` package calls with unified `AppLogger`
   - Remove `logging` dependency from integration
3. **Validate unified logging**
   - Test all log levels and categories
   - Ensure consistent formatting and output

### Phase 2: Core Communication Infrastructure
**Objective**: Replace simulated connection with real WebSocket communication

**Tasks:**
1. **Add WebSocket dependency**
   - Add `web_socket_channel: ^3.0.3` to pubspec.yaml
2. **Replace CncConnectionBloc**
   - Integrate `GrblCommunicationBloc` from communication-spike
   - Maintain existing event/state API where possible
   - Add WebSocket-specific states and events
3. **Copy test server infrastructure**
   - Copy `test_server/websocket_server.dart` for development
   - Update connection URLs and test scenarios
4. **Update connection UI**
   - Enhance session initialization sidebar
   - Add WebSocket URL configuration
   - Show connection status and performance metrics

### Phase 3: GCode Runner Engine  
**Objective**: Stream G-code files line-by-line to CNC machine

**Tasks:**
1. **Create GCodeRunnerBloc**
   - Job control events: Start, Pause, Resume, Stop, Reset
   - Progress tracking states: Ready, Running, Paused, Completed, Error
   - Integration with FileManagerBloc for file source
   - Integration with CncCommunicationBloc for command sending
2. **Implement streaming logic**
   - Parse G-code file into executable commands
   - Buffer management and flow control
   - Progress tracking and line-by-line execution
   - Error handling and recovery
3. **Job control UI components**
   - Start/pause/stop buttons
   - Progress indicators
   - Line-by-line execution display
   - Error reporting and recovery options

### Phase 4: Real-time Command System
**Objective**: Immediate machine control outside of G-code jobs

**Tasks:**
1. **Implement RealtimeCommandService**
   - Jogging commands (X/Y/Z movement)
   - Emergency controls (feed hold, cycle start, soft reset)
   - State queries (continuous position/status polling)
   - Machine configuration (settings management)
2. **Command prioritization system**
   - Real-time commands bypass G-code queue
   - Emergency commands take absolute priority  
   - Status queries run continuously during operations
3. **Machine state management**
   - Create MachineState model
   - Track position, mode, feeds/speeds
   - Handle state transitions and validation

### Phase 5: UI Integration
**Objective**: Comprehensive CNC control interface

**Tasks:**
1. **Enhanced connection panel**
   - WebSocket URL configuration
   - Connection status with performance metrics
   - Machine information display
2. **Jog control panel**
   - Manual X/Y/Z movement controls
   - Configurable jog distances and feed rates
   - Coordinate system display (work/machine)
   - Homing and zero-setting controls
3. **Job control interface** 
   - File-to-execution workflow
   - Job progress visualization
   - Real-time execution feedback
   - Error handling and recovery
4. **Communication monitoring**
   - Command/response history
   - Latency metrics and performance data
   - Debug logging and troubleshooting

### Phase 6: Testing & Validation
**Objective**: Comprehensive testing of integrated system

**Tasks:**
1. **Unit tests**
   - GCodeRunnerBloc functionality
   - RealtimeCommandService operations
   - Communication protocol handling
2. **Integration tests**
   - File → Parse → Visualize → Execute workflow
   - Real-time command prioritization
   - Error recovery scenarios
3. **UI tests**
   - Connection establishment and management
   - Job control operations
   - Jog control functionality
4. **Performance validation**
   - Communication latency measurements
   - UI responsiveness during operations
   - Memory usage and stability testing

## Dependencies & Requirements

### Package Additions
```yaml
dependencies:
  # NEW: WebSocket communication
  web_socket_channel: ^3.0.3
  
  # EXISTING: Keep all current dependencies
  logger: ^2.4.0        # Unified logging (no change)
  flutter_bloc: ^9.1.1  # State management (no change)
  # ... all other existing dependencies
```

### Package Removals/Conflicts
```yaml
# REMOVE from communication-spike integration:
logging: ^1.2.0  # Conflicts with existing logger package
```

## File Structure Changes

### New Directory Structure
```
lib/
├── communication/                     # NEW: Communication layer
│   ├── cnc_communication_bloc.dart   # Enhanced WebSocket communication
│   ├── cnc_communication_event.dart  # Connection + real-time events
│   ├── cnc_communication_state.dart  # Machine state integration
│   ├── gcode_runner_bloc.dart        # G-code streaming engine
│   ├── gcode_runner_event.dart       # Job control events
│   ├── gcode_runner_state.dart       # Execution progress states
│   └── realtime_command_service.dart # Jogging, emergency, config
├── models/
│   ├── gcode_file.dart               # EXISTING: File management
│   └── machine_state.dart            # NEW: CNC machine status
├── ui/widgets/sidebars/
│   ├── files_and_jobs.dart          # EXISTING: File management
│   ├── session_initialization.dart   # ENHANCED: Connection controls
│   ├── jog_control.dart              # NEW: Manual machine control
│   └── job_control.dart              # NEW: G-code execution
└── utils/
    └── logger.dart                   # ENHANCED: Unified logging
```

### Test Infrastructure
```
test_server/
└── websocket_server.dart            # COPIED: Development server

test/
├── unit/
│   ├── communication/               # NEW: Communication tests
│   └── gcode_runner/               # NEW: Job execution tests
├── widget/
│   ├── jog_control_test.dart       # NEW: UI component tests
│   └── job_control_test.dart       # NEW: Job control tests
└── integration/
    └── cnc_communication_test.dart  # NEW: End-to-end tests
```

## Risk Assessment & Mitigation

### Technical Risks
1. **WebSocket Connection Stability**
   - **Risk**: Network interruptions, connection drops
   - **Mitigation**: Auto-reconnection, connection monitoring, graceful degradation

2. **Real-time Command Conflicts**
   - **Risk**: G-code streaming vs real-time commands collision
   - **Mitigation**: Command prioritization system, proper queue management

3. **UI Responsiveness During Operations**
   - **Risk**: Communication blocking UI thread
   - **Mitigation**: Proper async handling, background processing, performance monitoring

### Integration Risks
1. **Logging System Conflicts**
   - **Risk**: Dual logging systems causing confusion/errors
   - **Mitigation**: Phase 1 complete unification before proceeding

2. **State Management Complexity** 
   - **Risk**: Multiple BLoCs creating circular dependencies
   - **Mitigation**: Clear event flow definition, proper separation of concerns

3. **Testing Coverage**
   - **Risk**: Complex integration making comprehensive testing difficult
   - **Mitigation**: Phased approach with validation at each step

## Success Criteria

### Functional Requirements
- ✅ Real CNC machine connection and control
- ✅ G-code file streaming with job control
- ✅ Real-time jogging and emergency controls  
- ✅ Machine status monitoring and display
- ✅ Preserved 3D visualization capabilities
- ✅ Single, unified logging system

### Performance Requirements
- ⚡ WebSocket communication latency < 20ms average
- ⚡ UI remains responsive during G-code streaming
- ⚡ File selection to execution workflow < 5 seconds
- ⚡ Emergency stop response < 100ms

### Quality Requirements
- 🧪 >90% test coverage for new communication components
- 🧪 Integration tests cover complete file-to-execution workflow
- 🧪 UI tests validate all new control interfaces
- 🧪 Performance benchmarks for communication and UI responsiveness

---

## Implementation Notes

This plan will be referenced throughout the implementation process and updated as we discover new requirements or encounter unexpected challenges. Each phase should be completed and validated before proceeding to the next phase to ensure system stability and maintainability.

**Next Step**: Begin Phase 1 - Logging System Unification