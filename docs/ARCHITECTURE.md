# Application Architecture

**🚧 Status: Vision Document - Most Features Not Yet Implemented**

This document outlines the **planned** high-level software architecture for ghSender. The architecture is designed to meet the core tenets of reliability, low latency, and maintainability, leveraging the strengths of the Flutter/Dart ecosystem.

**⚠️ Implementation Reality**: Currently implemented is a high-performance 3D G-code visualizer with ultra-responsive grblHAL communication (125Hz status updates, 120fps rendering). Core architecture is operational, but advanced features like safety systems, workflows, and adaptive learning are planned but not yet built.

## Current Implementation Summary

**✅ Operational Components:**
- **Flutter/Dart Architecture** - Cross-platform framework with proven 120fps 3D performance
- **BLoC State Management** - Handles 125Hz real-time updates without performance degradation  
- **WebSocket Communication** - Industry-leading 8ms response times with grblHAL controllers
- **3D Visualization Pipeline** - Flutter Scene rendering with custom shaders and anti-aliased lines
- **G-code Processing** - Parser supporting G0/G1/G2/G3 commands with arc interpolation

**📋 Planned Components:**
- Safety systems, manual workflows, adaptive learning, touch interface, plugin architecture

## 1. Layered Architecture

A layered architecture will be employed to ensure a strong separation of concerns, which is critical for building a robust and scalable application. This separation allows different parts of the application to be developed, tested, and maintained independently.

```
+------------------------------------+
|         UI / Presentation          |
|        (Flutter Widgets)           |
+------------------------------------+
|   State Management / BLoC          |
| (Cubits, Event/State, Streams)     |
+------------------------------------+
|             Services               |
| (CNC, G-Code Sim, Workflow, etc.)  |
+------------------------------------+
|         Data / Model               |
|      (Dart Classes & Freezed)      |
+------------------------------------+
```

### 1.1. UI / Presentation Layer

*   **Responsibility:** To render the user interface and handle raw user input (clicks, touches, gestures, etc.).
*   **Technology:** Flutter widgets with Dart.
*   **Implementation Status:** ✅ **Implemented** - Core 3D visualization and UI framework operational.
*   **Details:** This layer is composed of reactive Flutter widgets that receive their state from BLoCs and emit events for user interactions. It features:
    - **High-Performance 3D Visualization:** 120fps rendering using Flutter Scene with custom shaders
    - **Cross-Platform UI:** Native performance on desktop platforms with planned tablet optimization
    - **Reactive Architecture:** Widgets rebuild automatically based on BLoC state changes
    - **Material Design 3:** Modern UI components with dark theme support
    - **No Business Logic:** Pure presentation layer that delegates all logic to BLoCs

### 1.2. State Management / BLoC Layer

*   **Responsibility:** To act as the intermediary between the UI and the services. It manages the application's state and contains all the business logic, respecting the single source of truth principle.
*   **Technology:** BLoC (Business Logic Component) pattern with flutter_bloc package.
*   **Implementation Status:** ✅ **Implemented** - Core BLoCs operational with high-frequency state management.
*   **Details:** This layer is responsible for managing both machine and application state through well-defined BLoCs:
    *   **`CncCommunicationBloc`:** ✅ **Implemented** - Manages real-time WebSocket communication with grblHAL controllers at 125Hz. Handles connection state, message passing, and error recovery.
    *   **`MachineControllerBloc`:** ✅ **Implemented** - Processes machine state updates from communication layer. Maintains authoritative machine state reflecting controller status.
    *   **`FileManagerBloc`:** ✅ **Implemented** - Manages G-code file loading, parsing, and processing pipeline.
    *   **`GraphicsBloc`:** ✅ **Implemented** - Manages 3D visualization state and rendering parameters.
    *   **`PerformanceBloc`:** ✅ **Implemented** - Tracks application performance metrics and optimization.
    *   **`ProfileBloc`:** ✅ **Implemented** - Manages user profiles and application settings.
    *   **`ProblemsBloc`:** ✅ **Implemented** - Handles error detection and user notification.
    *   **Planned BLoCs:** `WorkflowBloc`, `LearningBloc`, `SafetyBloc` for advanced features.
*   This clear separation within BLoCs ensures that machine state and application state are managed independently, with proven capability to handle 125Hz update rates without performance degradation.

### 1.3. Service Layer

*   **Responsibility:** To handle interactions with external dependencies, data sources, and complex business logic that doesn't fit into a single BLoC.
*   **Technology:** Dart services integrated with BLoC pattern.
*   **Implementation Status:** ⚠️ **Partially Implemented** - Basic communication framework exists, most services planned but not built.
*   **Details:** This layer abstracts the core functionalities of the application into distinct, testable services. Each service has a clearly defined boundary:
    *   **`CncCommunicationBloc`:** ✅ **Implemented** - Manages WebSocket communication with grblHAL controllers. Handles connection management and message passing.
    *   **`GCodeProcessor`:** ✅ **Implemented** - Parses `.gcode` files into structured format supporting G0/G1/G2/G3 commands with arc interpolation.
    *   **`SceneManager`:** ✅ **Implemented** - Manages 3D scene data and visualization of G-code toolpaths.
    *   **`ValidationService`:** ❌ **Not Implemented** - Planned service for proactive error prevention including:
        - **Boundary Checking:** Verifying toolpath stays within machine work envelope
        - **Tool Change Validation:** Verifying tool compatibility and constraints
        - **Coordinate System Validation:** Ensuring valid workpiece touchoff operations
    *   **`WorkflowService`:** ❌ **Not Implemented** - Planned service for managing state transitions between program execution and manual intervention modes:
        - **State Machine Management:** Program/Manual/Tool Change/Touchoff mode transitions
        - **Step-by-Step Workflow Guidance:** Structured workflows with safety checkpoints
        - **Context Preservation:** Maintaining program state during manual interventions
    *   **`LearningService`:** ❌ **Not Implemented** - Planned service for adaptive learning and competency tracking:
        - **Competency Assessment:** Tracking successful operations and skill levels
        - **Workflow Adaptation:** Adjusting UI complexity based on demonstrated competency
        - **Progress Tracking:** Learning milestones and skill development feedback
    *   **`PersistenceService`:** 🚧 **Partially Implemented** - Basic profile management exists, full settings persistence planned
    *   **`AnalyticsService`:** ❌ **Not Implemented** - Planned for anonymized usage data and error reporting

### 1.4. Data / Model Layer

*   **Responsibility:** To define the data structures and objects used throughout the application.
*   **Technology:** Dart classes using the `freezed` package to ensure immutability.
*   **Details:** This layer will contain immutable data classes (e.g., `MachineState`, `GCodeCommand`, `ToolDefinition`). The use of `freezed` ensures compile-time safety and predictable state objects.

### 1.5. Programming Paradigm

To ensure the highest levels of reliability and predictability, this project will adhere to a **Functional Programming (FP)** paradigm wherever possible, especially in the State Management and Service layers. This decision is formally documented in **ADR-010**.

**Key Principles:**

*   **Immutability:** All data models (in the `Data / Model Layer`) and state objects (managed by BLoC) will be immutable. The `freezed` package will be used to enforce this.
*   **Pure Functions:** Services and BLoC logic will be composed of pure functions that avoid side effects, making them highly predictable and testable.
*   **State Management:** The BLoC pattern, which is based on functional reactive principles, will be used to manage all application state. UI widgets will be "dumb" and will only react to state changes emitted by the BLoCs.

This approach directly supports the core tenet of "Uncompromising Reliability and State Management" by minimizing unpredictable state changes and making the application's behavior easier to reason about and verify.

## 2. Current Directory Structure

The actual implemented directory structure follows a layered architecture pattern:

```
lib/
├── main.dart                    # ✅ Application entry point
│
├── bloc/                        # ✅ BLoC state management layer
│   ├── communication/           # ✅ CNC communication BLoC
│   ├── file_manager/           # ✅ G-code file management BLoC
│   ├── graphics/               # ✅ 3D visualization BLoC
│   ├── machine_controller/     # ✅ Machine state BLoC
│   ├── performance/            # ✅ Performance monitoring BLoC
│   ├── problems/               # ✅ Error handling BLoC
│   ├── profile/                # ✅ User profile BLoC
│   └── bloc_exports.dart       # ✅ Centralized BLoC exports
│
├── models/                      # ✅ Data models and structures
│   ├── machine_controller.dart # ✅ Machine state definitions
│   ├── machine_configuration.dart # ✅ Controller configuration
│   ├── gcode_file.dart         # ✅ G-code file models
│   └── problem.dart            # ✅ Error/problem models
│
├── gcode/                       # ✅ G-code processing layer
│   ├── gcode_parser.dart       # ✅ G0/G1/G2/G3 command parser
│   ├── gcode_processor.dart    # ✅ File processing pipeline
│   └── gcode_scene.dart        # ✅ Scene generation from G-code
│
├── renderers/                   # ✅ 3D rendering layer
│   ├── flutter_scene_batch_renderer.dart # ✅ Main renderer
│   ├── line_mesh_factory.dart  # ✅ High-performance line rendering
│   ├── filled_square_renderer.dart # ✅ Filled geometry rendering
│   ├── billboard_text_renderer.dart # ✅ 3D text rendering
│   └── renderer_interface.dart # ✅ Renderer abstraction
│
├── scene/                       # ✅ 3D scene management
│   ├── scene_manager.dart      # ✅ Scene state management
│   ├── axes_factory.dart       # ✅ Coordinate axes generation
│   └── filled_square_factory.dart # ✅ Geometry factories
│
├── ui/                          # ✅ User interface layer
│   ├── app/                    # ✅ Application integration
│   ├── screens/                # ✅ Main application screens
│   ├── layouts/                # ✅ Layout components
│   ├── themes/                 # ✅ Visual themes and styling
│   └── widgets/                # ✅ Reusable UI components
│
├── utils/                       # ✅ Utility functions
│   └── logger.dart             # ✅ Application logging
│
└── camera_director.dart         # ✅ 3D camera control

# Planned future structure:
├── workflows/                   # 📋 Planned - Manual operation workflows
├── safety/                     # 📋 Planned - Safety systems
├── learning/                   # 📋 Planned - Adaptive learning
└── plugins/                    # 📋 Planned - Extension system
```

## 3. Current Component Architecture

The implemented application follows a reactive architecture with high-performance 3D visualization:

```
+------------------+     events      +-----------------+
|   Flutter UI     |<--------------->|      BLoCs      |
|   (Widgets)      |     states      | (State Mgmt)    |
+------------------+                 +-----------------+
        |                                   |
        | renders                           | manages
        |                                   |
        v                                   v
+------------------+     data        +-----------------+
|  Flutter Scene   |<----------------|  Scene Manager  |
|  (3D Renderer)   |                 | (G-code Data)   |
+------------------+                 +-----------------+
        |                                   |
        | displays                          | processes
        |                                   |
        v                                   v
+------------------+     streams     +-----------------+
|   120fps 3D      |<----------------|   WebSocket     |
|  Visualization   |                 | Communication   |
+------------------+                 +-----------------+
```

### ✅ Implemented Component Responsibilities

1. **Flutter UI Layer** - ✅ **Operational**
   - Material Design 3 interface with dark theme
   - Reactive widgets that rebuild on BLoC state changes
   - Cross-platform desktop support (macOS, Windows 11)
   - High-performance custom paint widgets for 3D integration

2. **BLoC State Management** - ✅ **Operational**
   - Handles 125Hz real-time updates without performance degradation
   - Manages machine state, communication, file processing, and graphics
   - Event-driven architecture with clear separation of concerns
   - Proven scalability with high-frequency data streams

3. **Flutter Scene 3D Renderer** - ✅ **Operational**
   - 120fps rendering with custom GLSL shaders
   - Anti-aliased line rendering for smooth toolpath visualization
   - Efficient geometry batching and GPU utilization
   - Real-time camera controls with smooth interaction

4. **Scene Manager** - ✅ **Operational**
   - Converts G-code data into 3D scene objects
   - Manages coordinate system transformations (CNC to display)
   - Handles dynamic scene updates and object lifecycle
   - Optimized for large G-code files with complex toolpaths

5. **WebSocket Communication** - ✅ **Operational**
   - 125Hz (8ms) status streaming from grblHAL controllers
   - Non-buffered command execution for maximum responsiveness
   - Automatic reconnection and error recovery
   - Industry-leading performance benchmarks

6. **G-code Processing Pipeline** - ✅ **Operational**
   - Parser supporting G0/G1/G2/G3 commands with arc interpolation
   - Bounds calculation and toolpath analysis
   - Efficient file loading and processing for large programs
   - Real-time scene generation from parsed data
### ✅ Current Key Interactions (Implemented)

1. **Flutter UI ↔ BLoCs**
   - Widgets listen to BLoC state streams and rebuild reactively
   - User interactions emit events to appropriate BLoCs
   - 125Hz state updates handled without UI performance impact

2. **BLoCs ↔ Services**
   - CncCommunicationBloc manages WebSocket connections and message streams
   - FileManagerBloc coordinates with GCodeProcessor for file operations
   - MachineControllerBloc processes real-time status updates

3. **Scene Manager ↔ 3D Renderer**
   - Scene Manager converts G-code data into renderable 3D objects
   - Flutter Scene Renderer displays scene data at 120fps
   - Real-time scene updates propagate efficiently through the pipeline

4. **WebSocket Communication ↔ Machine State**
   - 125Hz status streaming from grblHAL controllers
   - Non-buffered command execution for maximum responsiveness
   - Automatic state synchronization between controller and application

### 📋 Planned Interactions (Future Implementation)

1. **Safety Systems ↔ All Components**
   - Work envelope validation before command execution
   - Emergency stop integration across all operational modes
   - Collision detection with real-time feedback

2. **Workflow Management ↔ User Interface**
   - Step-by-step guidance for manual operations
   - Context-aware UI adaptation based on current workflow state
   - Progress tracking and milestone celebration

3. **Learning System ↔ User Experience**
   - Competency assessment based on successful operations
   - Progressive UI complexity adaptation
   - Personalized workflow optimization

## 4. Product Management Integration

To avoid the pitfalls observed in existing G-Code sender projects, this architecture incorporates mandatory product management checkpoints and decision governance.

### 3.1. Architectural Decision Log

All significant technical decisions must be documented in `DECISIONS.md` with the following format:
- **Decision**: What was decided
- **Context**: Why this decision was necessary
- **Alternatives**: What other options were considered
- **Consequences**: Expected impact on user experience and system design
- **Review Date**: When this decision should be re-evaluated

### 3.2. Product Management Checkpoints

**MANDATORY**: Before implementing any new feature or significant refactor, the development team must:

1. **Persona Validation**: Confirm the change serves either Brenda (beginner) or Mark (experienced) personas defined in `PRODUCT_BRIEF.md`
2. **Success Metric Alignment**: Verify the change supports at least one of the defined KPIs (adoption rate, job success rate, user satisfaction, crash rate)
3. **Requirements Review**: Ensure the change aligns with the core tenets in `REQUIREMENTS.md`
4. **Performance Impact**: Assess impact on defined performance requirements
5. **Safety Impact**: Evaluate any safety implications through the `ValidationService`

**Process**: Create a brief (1-page) impact assessment document before beginning implementation. This prevents feature creep and ensures architectural coherence.

### 4.3. Technology Choice Governance

✅ **Validated Decisions** - The following technology choices have been proven in implementation:

1. **Flutter/Dart Ecosystem** - ✅ **Validated** - Delivers exceptional performance with 120fps 3D rendering and 125Hz real-time communication
2. **Performance First** - ✅ **Achieved** - 8ms response times exceed <50ms requirements by 6x
3. **Cross-Platform Consistency** - ✅ **Proven** - Single codebase works seamlessly on macOS and Windows 11
4. **BLoC State Management** - ✅ **Validated** - Handles high-frequency updates without performance degradation
5. **Flutter Scene 3D** - ✅ **Proven** - Custom shaders deliver industry-leading visualization performance

📋 **Future Evaluation Criteria**:
- Maintain proven performance benchmarks when adding new features
- Prioritize Flutter ecosystem solutions for consistency
- Ensure new dependencies don't impact real-time performance requirements

### 3.4. Third-Party Package and Dependency Strategy

*   **Principle**: To accelerate development and leverage community expertise, we will prioritize the use of high-quality, well-maintained packages from `pub.dev` over building custom implementations from scratch. "Reinventing the wheel" will be actively discouraged.

*   **Rationale**: This approach allows the development team to focus on the unique challenges and business logic of the G-Code sender, rather than solving problems that have already been solved effectively by the open-source community. It reduces development time, lowers the maintenance burden, and benefits from the continuous improvements of the package maintainers.

*   **Criteria for High-Quality Packages**: A package is considered "high-quality" if it meets the majority of the following criteria:
    *   **High Scores**: Strong "Likes," "Pub Points," and "Popularity" on `pub.dev`.
    *   **Null Safety**: Full support for modern, null-safe Dart.
    *   **Active Maintenance**: A responsive issue tracker and recent commit history.
    *   **Excellent Documentation**: A clear `README`, comprehensive API documentation, and a functional `example/` implementation.
    *   **Thorough Testing**: A comprehensive test suite included with the package.
    *   **Minimal Dependencies**: The package should not introduce an excessive number of transitive dependencies.

*   **Exceptions**: A custom implementation will be considered only when:
    *   No high-quality package exists that meets the specific functional or performance requirements.
    *   The required functionality is trivial and a custom implementation is less complex than adding a new dependency.
    *   A package introduces a security risk or a significant performance bottleneck that cannot be mitigated.

## 4. Development Quality Gates

### 4.1. Performance Gates

✅ **Achieved Performance Benchmarks:**
- **Communication Response Time**: ✅ **8ms** - Exceeds <50ms target by 6x with 125Hz status streaming
- **UI Responsiveness**: ✅ **120fps** - Exceeds 60fps target by 2x during 3D visualization and real-time updates
- **3D Rendering Performance**: ✅ **120fps** - Smooth visualization with anti-aliased lines and complex toolpaths
- **High-Frequency State Management**: ✅ **125Hz** - BLoC architecture handles real-time updates without performance degradation

📋 **Planned Performance Targets:**
- **Memory Usage**: <200MB total application memory footprint (needs validation)
- **Startup Time**: <3 seconds on target devices (iPad, mid-range Android tablet)
- **File Loading**: Large G-code files (>10MB) processed without UI blocking

### 4.2. Development Platform Strategy

**Cross-Platform Development Environment**
- **Supported Development Platforms**: macOS and Windows 11
- **Flutter Advantage**: Single codebase works across both development environments
- **Team Flexibility**: Developers can use their preferred OS without project impact
- **CI/CD Strategy**: Build and test on both platforms automatically

**Phase 0-1: Desktop Development Focus**
- **Primary Platforms**: macOS and Windows 11 desktop development
- **Rationale**: Reduces complexity during technology validation and core development
- **Benefits**: Faster iteration cycles, comprehensive debugging tools, no mobile platform constraints
- **Validation Target**: Prove core technology assumptions before mobile deployment
- **Cross-Platform Validation**: Ensure Flutter app works on both desktop platforms early

**Phase 1+: Mobile and Production Validation**
- **iPad Deployment**: Early validation of touch interface and performance characteristics
- **Mobile Constraints**: Validate memory usage, touch responsiveness, and platform-specific limitations
- **Production Target**: iPad-first experience with desktop compatibility
- **Windows Testing**: Validate desktop experience for potential Windows tablet deployment

**Platform-Specific Considerations:**
- **macOS Development**: Native Xcode integration, iOS simulator access, Metal rendering
- **Windows Development**: Visual Studio integration, Android emulator preferred, DirectX rendering
- **Cross-Platform Shared**: Dart language, Flutter framework, git workflow, documentation
- **Platform Differences**: Build tools, debugging environments, deployment pipelines

### 4.3. Safety Gates (Planned - Not Yet Implemented)

📋 **Future Safety Requirements:**
- **Validation Coverage**: 100% of G-Code operations must pass through `ValidationService`
- **State Consistency**: Machine state and UI state synchronization verified in integration tests
- **Error Recovery**: All error conditions must have defined recovery paths
- **Boundary Checking**: Work envelope validation must be mathematically verified, not heuristic
- **Manual Operation Safety**: All tool change and touchoff workflows must include confirmation steps and collision prevention
- **State Transition Integrity**: Entry/exit between program and manual modes must be validated and logged

⚠️ **Current Status**: Safety systems are not yet implemented. Current software is for visualization and development only.

### 4.4. User Experience Gates (Planned)

📋 **Future UX Requirements:**
- **Persona Coverage**: Each major feature must demonstrate value for either Brenda or Mark
- **Accessibility**: All controls must support touch, keyboard, and accessibility features
- **Progressive Disclosure**: Complex features must have beginner-friendly entry points
- **Contextual Help**: Safety-critical operations must include inline guidance

✅ **Current UX Achievements:**
- **High-Performance Visualization**: 120fps 3D rendering provides smooth, responsive user experience
- **Cross-Platform Consistency**: Single Flutter codebase ensures consistent experience across platforms
- **Material Design 3**: Modern, accessible UI components with dark theme support

## 5. Extensibility and Scalability Architecture

### 5.1. Plugin Architecture for Community Growth

To support the rapid feature development needed for commercial success in the maker community, the architecture must support safe, isolated extensions:

**Plugin Interface Design:**
```dart
abstract class WorkflowPlugin {
  String get name;
  String get version;
  List<WorkflowStep> get customSteps;
  bool validateSafety(WorkflowContext context);
  Widget buildConfigurationUI();
}
```

**Extension Points:**
- **Custom Workflow Steps**: Allow community to contribute specialized operations
- **Hardware Drivers**: Support for custom sensors, probes, and peripherals  
- **CAM Integration**: Direct integration with popular CAM software
- **Macro Systems**: Advanced automation for power users
- **Learning Modules**: Custom competency tracking for specialized techniques

### 5.2. Service Extensibility Patterns

**Event-Driven Service Communication:**
Services communicate through well-defined events rather than direct coupling:
```dart
// Instead of: workflowService.startToolChange()
// Use: eventBus.publish(ToolChangeRequested(toolNumber: 1))
```

**Decorator Pattern for Service Enhancement:**
```dart
class EnhancedValidationService implements ValidationService {
  final ValidationService base;
  final List<ValidationPlugin> plugins;
  
  @override
  ValidationResult validate(GCode code) {
    var result = base.validate(code);
    for (var plugin in plugins) {
      result = plugin.enhance(result);
    }
    return result;
  }
}
```

### 5.3. Learning System Extensibility

**Custom Competency Metrics:**
```dart
abstract class CompetencyMetric {
  String get operationType;
  double calculateScore(List<OperationResult> history);
  bool shouldPromoteSkillLevel(double currentScore);
}
```

**Community Learning Paths:**
- Machine-specific learning sequences (Shapeoko, X-Carve, etc.)
- Technique-specific progressions (woodworking, metalworking, etc.)
- Integration with online learning platforms

### 5.4. UI Extensibility for Feature Growth

**Progressive Disclosure Framework:**
```dart
class AdaptiveUI {
  Widget buildForSkillLevel(SkillLevel level, List<Feature> features) {
    return switch (level) {
      SkillLevel.beginner => BasicInterface(essentialFeatures),
      SkillLevel.intermediate => StandardInterface(coreFeatures),
      SkillLevel.expert => AdvancedInterface(allFeatures),
    };
  }
}
```

**Feature Flag System:**
- **Gradual Rollout**: New features can be enabled for specific user segments
- **A/B Testing**: Compare feature variants for optimal UX
- **Community Beta**: Power users can access experimental features

### 5.5. Data Model Evolution

**Versioned Data Models:**
```dart
@freezed
class MachineState with _$MachineState {
  const factory MachineState({
    @Default(1) int version,
    required Position currentPosition,
    required OperationalMode mode,
    // New fields added with version increments
    @JsonKey(includeIfNull: false) ToolInfo? currentTool,
  }) = _MachineState;
}
```

**Migration Strategy:**
- **Backward Compatibility**: Older data formats automatically upgraded
- **Feature Detection**: UI adapts based on available controller capabilities
- **Graceful Degradation**: Advanced features disable cleanly on older hardware

### 5.6. Performance Scaling Considerations

**Resource Management:**
- **Lazy Loading**: Complex features only loaded when needed
- **Memory Pooling**: Efficient handling of large G-Code files and visualization data
- **Background Processing**: Heavy operations run in isolates

**Caching Strategy:**
- **Competency Data**: Learning progression cached locally
- **Workflow Templates**: Community workflows cached for offline use
- **Validation Results**: Expensive validation calculations cached

### 5.7. Community Integration Architecture

**Workflow Marketplace:**
```dart
class WorkflowMarketplace {
  Future<List<WorkflowTemplate>> searchWorkflows(String query);
  Future<void> installWorkflow(WorkflowTemplate template);
  Future<void> shareWorkflow(CustomWorkflow workflow);
  Future<List<Review>> getWorkflowReviews(String workflowId);
}
```

**Telemetry for Feature Development:**
- **Usage Analytics**: Which features are most/least used
- **Performance Metrics**: Feature-specific performance impact
- **Error Tracking**: Feature-specific error rates and patterns
- **Learning Analytics**: Community learning progression patterns

## 6. VS Code Design Pattern Integration

### 6.1. Proven Platform Patterns

Following VS Code's successful platform strategy, we will adopt key design patterns that enabled their dominance in the developer tools market:

### 6.2. Configuration Architecture

**JSON Settings with GUI Overlay:**
```dart
// settings.dart - Type-safe settings with JSON serialization
@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    @Default("192.168.1.100") String machineHostname,
    required WorkEnvelope workEnvelope,
    @Default(10.0) double toolChangeSafeHeight,
    @Default(true) bool learningAdaptiveSpeed,
    @Default("dark") String uiTheme,
  }) = _AppSettings;
  
  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);
}
```

**Settings UI Strategy:**
- **Beginner Mode**: Guided settings UI with clear explanations
- **Expert Mode**: Direct JSON editing with IntelliSense and validation
- **Import/Export**: JSON settings files for sharing and version control
- **Schema Validation**: Real-time validation with helpful error messages

### 6.3. Command Palette Architecture

**Command System:**
```dart
abstract class Command {
  String get id;
  String get title;
  String get category;
  List<String> get keywords;
  Future<void> execute(CommandContext context);
  bool canExecute(AppState state);
}

class ToolChangeCommand extends Command {
  String get id => "workflow.toolChange.start";
  String get title => "Start Tool Change";
  String get category => "Workflow";
  List<String> get keywords => ["tool", "change", "M6"];
}
```

**Integration Points:**
- **Keyboard Shortcuts**: `Ctrl+Shift+P` for command palette
- **Context-Aware Commands**: Available commands based on current machine state
- **Learning Integration**: Commands adapt based on user competency level
- **Plugin Commands**: Extensions can register custom commands

### 6.4. Extension/Plugin Marketplace Model

**Extension Manifest:**
```json
{
  "name": "shapeoko-pro-workflows",
  "version": "1.0.0",
  "displayName": "Shapeoko Pro Workflows",
  "description": "Official workflow templates for Shapeoko Pro CNC",
  "publisher": "carbide3d",
  "categories": ["Workflows", "Hardware"],
  "contributes": {
    "commands": [
      {
        "command": "shapeoko.setupWorkflow",
        "title": "Setup Shapeoko Pro Workflow"
      }
    ],
    "settings": [
      {
        "key": "shapeoko.bitSetter.enabled",
        "type": "boolean",
        "default": true,
        "description": "Enable BitSetter integration"
      }
    ],
    "workflows": [
      {
        "name": "Shapeoko Pro Tool Change",
        "file": "./workflows/toolchange.json"
      }
    ]
  }
}
```

### 6.5. Workspace/Project Concept

**Project-Based Configuration:**
```dart
class WorkspaceConfig {
  final String projectName;
  final MachineSettings machineConfig;
  final List<WorkflowTemplate> customWorkflows;
  final Map<String, dynamic> pluginSettings;
  
  // Project settings override global settings
  AppSettings getEffectiveSettings(AppSettings globalSettings) {
    return globalSettings.copyWith(
      // Project-specific overrides
    );
  }
}
```

**Benefits for CNC Users:**
- **Machine-Specific Projects**: Different settings for different machines
- **Shared Workflows**: Team collaboration on workflow templates
- **Version Control**: Git integration for project settings and workflows
- **Template Projects**: Quick setup for common machine/material combinations

### 6.6. Implementation Strategy

**Phase 1 (MVP Foundation):**
- Basic settings system with JSON export/import
- Simple command registration infrastructure
- Plugin loading framework
- Workspace concept foundation

**Phase 2 (Enhanced UX):**
- Full command palette implementation
- JSON settings editor with validation
- Basic extension marketplace
- Workspace switching UI

**Phase 3 (Community Platform):**
- Advanced extension marketplace with ratings/reviews
- IntelliSense for settings JSON
- Collaborative workspace features
- Advanced command system with parameters

**Phase 4 (Ecosystem Maturity):**
- VS Code-style extension development tools
- Integrated documentation system
- Advanced workflow sharing and collaboration
- Enterprise workspace management

---

## 7. Architecture Assessment & Improvement Recommendations

**Assessment Date**: January 18, 2025  
**Current Architecture Status**: Core technology validated, structural improvements needed

### 7.1. Architecture Quality Assessment

#### ✅ **Validated Strengths**
- **Performance Excellence**: 125Hz communication and 120fps rendering prove Flutter/Dart architecture
- **Reactive State Management**: BLoC pattern successfully handles high-frequency real-time updates
- **Cross-Platform Consistency**: Single codebase delivers native performance on multiple platforms
- **3D Rendering Pipeline**: Custom Flutter Scene implementation with GLSL shaders exceeds requirements

#### ❌ **Critical Architecture Gaps**
- **Safety-First Architecture Missing**: No safety validation layer despite being core product requirement
- **Monolithic BLoC Design**: Large BLoCs handling multiple concerns, reducing maintainability
- **No Domain-Driven Structure**: Business logic scattered across presentation layer
- **Missing Error Handling Strategy**: No consistent error recovery or user feedback patterns

### 7.2. Priority 1: Domain-Driven Design Refactoring

**Current Issue**: Business logic is mixed with presentation logic in BLoCs, making the system difficult to test, maintain, and extend.

#### **Recommended Domain Structure**

```
lib/
├── domain/                           # 📋 NEW - Pure business logic
│   ├── entities/                     # Core business objects with behavior
│   │   ├── machine.dart             # Machine entity with state and operations
│   │   ├── toolpath.dart            # Toolpath domain logic and validation
│   │   ├── workflow.dart            # Workflow state machines and transitions
│   │   └── safety_envelope.dart     # Work envelope and collision detection
│   │
│   ├── value_objects/               # Immutable value types
│   │   ├── coordinates.dart         # Machine coordinates with validation
│   │   ├── feed_rate.dart          # Feed rate with safety limits
│   │   └── tool_definition.dart     # Tool specifications and constraints
│   │
│   ├── repositories/                # Data access abstractions
│   │   ├── machine_repository.dart  # Machine state persistence interface
│   │   ├── gcode_repository.dart    # G-code file management interface
│   │   └── profile_repository.dart  # User profile and settings interface
│   │
│   ├── services/                    # Domain services for complex operations
│   │   ├── safety_validator.dart    # Safety validation business rules
│   │   ├── toolpath_analyzer.dart   # Toolpath analysis and optimization
│   │   └── workflow_orchestrator.dart # Multi-step workflow coordination
│   │
│   └── use_cases/                   # Application-specific business rules
│       ├── execute_gcode_program.dart
│       ├── perform_tool_change.dart
│       ├── validate_work_envelope.dart
│       └── handle_emergency_stop.dart
│
├── infrastructure/                   # 🔄 REFACTOR - External concerns only
│   ├── communication/               # grblHAL protocol implementation
│   │   ├── grblhal_client.dart     # WebSocket communication details
│   │   └── message_parser.dart     # Protocol message parsing
│   ├── persistence/                 # Data storage implementations
│   │   ├── file_gcode_repository.dart
│   │   └── shared_prefs_profile_repository.dart
│   └── rendering/                   # 3D visualization engine
│       ├── flutter_scene_renderer.dart
│       └── shader_manager.dart
│
└── application/                     # 🔄 REFACTOR - Thin application layer
    ├── blocs/                       # UI state management only
    │   ├── machine_status_cubit.dart    # Simple state display
    │   ├── file_browser_bloc.dart       # UI navigation state
    │   └── visualization_bloc.dart      # 3D view state
    │
    └── use_case_handlers/           # Bridge between UI and domain
        ├── machine_control_handler.dart
        ├── file_management_handler.dart
        └── safety_monitoring_handler.dart
```

#### **Domain Entity Example**

```dart
// domain/entities/machine.dart
class Machine {
  final MachineId id;
  final MachineConfiguration configuration;
  final MachinePosition currentPosition;
  final MachineStatus status;
  final SafetyEnvelope safetyEnvelope;

  const Machine({
    required this.id,
    required this.configuration,
    required this.currentPosition,
    required this.status,
    required this.safetyEnvelope,
  });

  // Business logic methods
  ValidationResult validateMove(Vector3 targetPosition) {
    if (!safetyEnvelope.contains(targetPosition)) {
      return ValidationResult.failure('Move exceeds work envelope');
    }
    
    if (status.isAlarmed) {
      return ValidationResult.failure('Cannot move while machine is alarmed');
    }
    
    return ValidationResult.success();
  }

  Machine executeMove(Vector3 targetPosition) {
    final validation = validateMove(targetPosition);
    if (!validation.isValid) {
      throw MachineOperationException(validation.error);
    }
    
    return copyWith(
      currentPosition: MachinePosition(targetPosition),
      status: MachineStatus.moving,
    );
  }
}
```

#### **Use Case Example**

```dart
// domain/use_cases/execute_gcode_program.dart
class ExecuteGCodeProgram {
  final MachineRepository _machineRepository;
  final SafetyValidator _safetyValidator;
  final GCodeRepository _gcodeRepository;

  ExecuteGCodeProgram(
    this._machineRepository,
    this._safetyValidator,
    this._gcodeRepository,
  );

  Future<ExecutionResult> execute(GCodeProgramId programId) async {
    // 1. Load program and validate
    final program = await _gcodeRepository.load(programId);
    final machine = await _machineRepository.getCurrent();
    
    final safetyCheck = _safetyValidator.validateProgram(program, machine);
    if (!safetyCheck.isValid) {
      return ExecutionResult.failure(safetyCheck.violations);
    }

    // 2. Execute with domain logic
    try {
      final updatedMachine = machine.startProgram(program);
      await _machineRepository.save(updatedMachine);
      
      return ExecutionResult.success();
    } catch (e) {
      return ExecutionResult.failure([e.toString()]);
    }
  }
}
```

### 7.3. Priority 2: BLoC Architecture Refactoring

**Current Issue**: Monolithic BLoCs like `MachineControllerBloc` handle multiple concerns, making them difficult to test and maintain.

#### **Recommended BLoC Decomposition**

```dart
// Current monolithic approach (BEFORE)
class MachineControllerBloc extends Bloc<MachineControllerEvent, MachineControllerState> {
  // Handles: status, position, alarms, configuration, communication, etc.
  // 500+ lines of mixed concerns
}

// Refactored focused approach (AFTER)

// 1. Simple state display (Cubit for simple state)
class MachineStatusCubit extends Cubit<MachineStatus> {
  final MachineRepository _repository;
  
  MachineStatusCubit(this._repository) : super(MachineStatus.unknown);
  
  void updateStatus(MachineStatus newStatus) {
    emit(newStatus);
  }
}

// 2. Position tracking with validation
class MachinePositionBloc extends Bloc<PositionEvent, PositionState> {
  final MachineRepository _repository;
  final SafetyValidator _safetyValidator;
  
  MachinePositionBloc(this._repository, this._safetyValidator) 
    : super(PositionState.initial()) {
    on<PositionUpdateRequested>(_onPositionUpdateRequested);
    on<JogRequested>(_onJogRequested);
  }
  
  Future<void> _onJogRequested(JogRequested event, Emitter<PositionState> emit) async {
    final machine = await _repository.getCurrent();
    final validation = machine.validateMove(event.targetPosition);
    
    if (!validation.isValid) {
      emit(state.copyWith(
        error: validation.error,
        status: PositionStatus.validationFailed,
      ));
      return;
    }
    
    emit(state.copyWith(status: PositionStatus.moving));
    
    try {
      final updatedMachine = machine.executeMove(event.targetPosition);
      await _repository.save(updatedMachine);
      
      emit(state.copyWith(
        position: updatedMachine.currentPosition,
        status: PositionStatus.idle,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        error: e.toString(),
        status: PositionStatus.error,
      ));
    }
  }
}

// 3. Alarm management
class MachineAlarmsBloc extends Bloc<AlarmEvent, AlarmState> {
  final MachineRepository _repository;
  
  MachineAlarmsBloc(this._repository) : super(AlarmState.initial()) {
    on<AlarmDetected>(_onAlarmDetected);
    on<AlarmCleared>(_onAlarmCleared);
  }
  
  // Focused alarm handling logic
}

// 4. Coordinator BLoC (lightweight)
class MachineCoordinatorBloc extends Bloc<CoordinatorEvent, CoordinatorState> {
  final MachineStatusCubit _statusCubit;
  final MachinePositionBloc _positionBloc;
  final MachineAlarmsBloc _alarmsBloc;
  
  MachineCoordinatorBloc(
    this._statusCubit,
    this._positionBloc,
    this._alarmsBloc,
  ) : super(CoordinatorState.initial()) {
    // Coordinate between focused BLoCs when needed
    // Handle cross-cutting concerns like emergency stop
  }
}
```

#### **BLoC Integration with Domain Layer**

```dart
// application/use_case_handlers/machine_control_handler.dart
class MachineControlHandler {
  final ExecuteGCodeProgram _executeGCodeUseCase;
  final PerformToolChange _toolChangeUseCase;
  final ValidateWorkEnvelope _validateEnvelopeUseCase;

  MachineControlHandler(
    this._executeGCodeUseCase,
    this._toolChangeUseCase,
    this._validateEnvelopeUseCase,
  );

  Future<void> handleJogRequest(JogRequest request) async {
    // Delegate to domain use case
    final result = await _validateEnvelopeUseCase.validate(request.targetPosition);
    
    if (result.isValid) {
      // Execute through domain
      await _executeJogUseCase.execute(request);
    } else {
      // Handle validation failure
      throw ValidationException(result.violations);
    }
  }
}

// BLoC uses handler (thin layer)
class MachinePositionBloc extends Bloc<PositionEvent, PositionState> {
  final MachineControlHandler _handler;
  
  Future<void> _onJogRequested(JogRequested event, Emitter<PositionState> emit) async {
    try {
      emit(state.copyWith(status: PositionStatus.moving));
      await _handler.handleJogRequest(event.request);
      emit(state.copyWith(status: PositionStatus.idle));
    } catch (e) {
      emit(state.copyWith(
        status: PositionStatus.error,
        error: e.toString(),
      ));
    }
  }
}
```

### 7.4. Implementation Strategy

#### **Phase 1: Domain Layer Foundation** (2-3 weeks)
1. Create domain entities for Machine, Toolpath, and SafetyEnvelope
2. Implement core use cases: ExecuteGCodeProgram, ValidateWorkEnvelope
3. Add repository interfaces (keep current implementations)
4. Create safety validation service

#### **Phase 2: BLoC Refactoring** (2-3 weeks)
1. Split MachineControllerBloc into focused Cubits/BLoCs
2. Create use case handlers as bridge layer
3. Update UI to use new focused BLoCs
4. Maintain backward compatibility during transition

#### **Phase 3: Infrastructure Separation** (1-2 weeks)
1. Move communication details to infrastructure layer
2. Implement repository pattern for data access
3. Clean up dependencies and improve testability

#### **Benefits of This Refactoring**
- **Testability**: Domain logic can be unit tested without Flutter dependencies
- **Maintainability**: Clear separation of concerns and focused components
- **Safety**: Business rules enforced at domain level, not presentation layer
- **Extensibility**: Plugin architecture becomes possible with clear interfaces
- **Performance**: Focused BLoCs reduce unnecessary rebuilds

### 7.5. Migration Path

To minimize disruption to current development:

1. **Parallel Implementation**: Build new domain layer alongside existing BLoCs
2. **Gradual Migration**: Move one feature at a time (start with machine positioning)
3. **Interface Compatibility**: Maintain existing BLoC interfaces during transition
4. **Comprehensive Testing**: Ensure performance benchmarks are maintained throughout refactoring

This refactoring will provide a solid foundation for implementing the planned safety features, workflows, and adaptive learning systems while maintaining the exceptional performance already achieved.

**📋 Detailed Implementation Guide**: See [REFACTORING_PLAN.md](REFACTORING_PLAN.md) for week-by-week implementation guidance, code examples, and testing strategies.
