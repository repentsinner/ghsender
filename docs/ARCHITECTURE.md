# Application Architecture

This document outlines the proposed high-level software architecture for the modern G-Code sender. The architecture is designed to meet the core tenets of reliability, low latency, and maintainability, leveraging the strengths of the Flutter/Dart ecosystem.

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
*   **Technology:** React components with TypeScript.
*   **Details:** This layer will be composed of "dumb" components that receive their state from Redux and dispatch actions for user events. It will be built with a responsive, tablet-first design using CSS Grid/Flexbox, ensuring it adapts seamlessly from an iPad to a desktop environment. It will contain no business logic.

### 1.2. State Management / Redux Toolkit Layer

*   **Responsibility:** To act as the intermediary between the UI and the services. It manages the application's state and contains all the business logic, respecting the single source of truth principle.
*   **Technology:** Redux Toolkit with RTK Query for API state management.
*   **Details:** This layer is responsible for managing both machine and application state through well-defined slices.
    *   **Machine State Slice (e.g., `machineSlice`):** Manages real-time machine state updates from the `CncService`. Uses RTK Query for API calls and real-time subscriptions. Will *not* hold authoritative state; it reflects the controller's state.
    *   **Application State Slices (e.g., `settingsSlice`, `learningSlice`):** Manage UI-related state like themes, units, user competency levels, and preferences. Interact with the `PersistenceService` through async thunks.
    *   **Workflow State Slice (e.g., `workflowSlice`):** Orchestrates complex multi-step workflows like tool changes and touchoff operations.
*   This clear separation within Redux slices ensures that machine state and application state are managed independently, which is key to achieving the "Uncompromising Reliability and State Management" tenet.

### 1.3. Service Layer

*   **Responsibility:** To handle interactions with external dependencies, data sources, and complex business logic that doesn't fit into a single Redux slice.
*   **Technology:** Node.js services in the main process with TypeScript.
*   **Details:** This layer abstracts the core functionalities of the application into distinct, testable services. Each service has a clearly defined boundary:
    *   **`CncService`:** The *only* component that communicates with the grblHAL controller. It manages the low-level TCP/IP socket, sends commands, and exposes streams of real-time status reports and machine settings (like envelope dimensions). It is the gateway to the "Machine State" source of truth.
    *   **`GCodeParserService`:** Responsible for parsing `.gcode` files into a structured, command-by-command format. This service will also perform initial validation of the G-Code syntax against supported grblHAL commands.
    *   **`ValidationService`:** This service is central to the "Proactive Error Prevention" tenet. It will take the parsed G-Code from the `GCodeParserService` and the machine's physical dimensions from the `CncService` to perform pre-run checks, including:
        - **Boundary Checking:** Verifying that the toolpath does not exceed the machine's work envelope.
        - **Tool Change Validation:** Verifying tool changes are compatible with program requirements and machine constraints.
        - **Coordinate System Validation:** Ensuring workpiece touchoff operations result in valid coordinate systems for the loaded program.
    *   **`WorkflowService`:** Manages the complex state transitions between program execution and manual intervention modes. This service orchestrates tool changes, workpiece touchoff operations, and other manual workflows that occur outside of G-Code execution:
        - **State Machine Management:** Tracks and controls transitions between Program, Manual, Tool Change, and Touchoff modes.
        - **Step-by-Step Workflow Guidance:** Provides structured workflows for manual operations with safety checkpoints.
        - **Context Preservation:** Maintains program state during manual interventions and ensures safe resumption of G-Code execution.
    *   **`LearningService`:** Manages adaptive learning progression and user competency tracking to provide personalized workflow experiences:
        - **Competency Assessment:** Tracks successful operation completions and calculates skill levels for different operation types.
        - **Workflow Adaptation:** Adjusts workflow pacing, confirmation requirements, and detail levels based on demonstrated competency.
        - **Progress Tracking:** Maintains learning milestones and provides feedback on skill development.
        - **Expert Mode Management:** Handles rapid onboarding for experienced users and pattern recognition for workflow optimization.
    *   **`PersistenceService`:** The *only* component that interacts with the device's local storage. It manages saving and retrieving application settings (e.g., controller IP address, UI preferences, macros). It is the gateway to the "Application State" source of truth.
    *   **`AnalyticsService`:** Responsible for collecting and reporting anonymized usage data and error reports. This service will respect user opt-in preferences and interact with external analytics platforms (e.g., Firebase Analytics, Sentry for error reporting).

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

## 2. Proposed Directory Structure

A feature-based directory structure is proposed to keep the codebase organized and easy to navigate.

```
lib/
├── main.dart
│
├── data/
│   ├── models/            # Immutable data models (e.g., machine_state.dart)
│   └── services/          # Service abstractions (e.g., cnc_service.dart)
│
├── features/
│   ├── connection/
│   │   ├── bloc/          # BLoC for connection logic
│   │   └── view/          # Connection screen widgets
│   │
│   ├── jogging/
│   │   ├── bloc/          # BLoC for jogging logic
│   │   └── view/          # Jogging control widgets
│   │
│   ├── visualizer/
│   │   ├── bloc/          # BLoC for visualizer state
│   │   └── view/          # 3D visualizer widgets
│   │
│   ├── tool_change/
│   │   ├── bloc/          # BLoC for tool change workflow
│   │   └── view/          # Tool change wizard widgets
│   │
│   ├── touchoff/
│   │   ├── bloc/          # BLoC for workpiece touchoff workflow
│   │   └── view/          # Touchoff workflow widgets
│   │
│   ├── learning/
│   │   ├── bloc/          # BLoC for learning progression and competency tracking
│   │   └── view/          # Learning progress widgets and milestone celebrations
│   │
│   └── ...                # Other features (e.g., console, job_control)
│
└── core/
    ├── app/               # Main application widget and routing
    ├── theme/             # App-wide theme definitions
    ├── widgets/           # Common, shared widgets
    └── extensions/        # Plugin and extension infrastructure

├── plugins/               # Community and third-party extensions
│   ├── workflows/         # Custom workflow templates
│   ├── hardware/          # Hardware-specific drivers and configurations
│   ├── integrations/      # CAM software and tool integrations
│   └── macros/           # Advanced macro systems
```

## 2. Core Component Relationships

The application is built around three key architectural components that work together:

```
+------------------+     renders     +-----------------+
|     Widget       |--------------->|    Visualizer    |
|   Framework      |                |    Component     |
+------------------+                +-----------------+
        |                                   |
        | provides context                  | displays
        |                                   |
        v                                   v
+------------------+     drives      +-----------------+
|     Runtime      |--------------->|    G-Code        |
|     Model        |                |    Simulator     |
+------------------+                +-----------------+
```

### Component Responsibilities

1. **Widget Framework**
   - Provides the application shell and UI components
   - Manages layout and user interaction
   - Handles window/viewport management
   - Current options under evaluation (ADR-001):
     - Flutter/Dart approach
     - Electron/TypeScript/React approach

2. **Runtime Model**
   - Maintains machine state and configuration
   - Manages communication with grblHAL
   - Handles workflow and operation sequencing
   - Coordinates between UI and simulator

3. **G-Code Simulator**
   - Interprets G-code programs
   - Maintains simplified physical model
   - Performs collision detection
   - Generates toolpath data

4. **Visualizer Component**
   - Renders simulator output
   - Manages viewport and camera
   - Handles user navigation/interaction
   - Provides real-time visual feedback

### Key Interactions

1. **Widget Framework ↔ Runtime Model**
   - UI components observe runtime state
   - User actions trigger runtime operations
   - Configuration changes flow through runtime

2. **Runtime Model ↔ G-Code Simulator**
   - Runtime feeds G-code to simulator
   - Simulator reports execution progress
   - Machine limits and context shared

3. **G-Code Simulator ↔ Visualizer**
   - Simulator provides toolpath data
   - Collision detection results displayed
   - Real-time position updates rendered

4. **Widget Framework ↔ Visualizer**
   - Viewport management and layout
   - User interaction with 3D view
   - Visual feedback integration

## 3. Product Management Integration

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

### 3.3. Technology Choice Governance

When evaluating new dependencies or architectural changes:

1. **Flutter Ecosystem First**: Prefer Flutter/Dart solutions over platform-specific or web-based alternatives
2. **Performance Over Features**: Prioritize solutions that maintain <50ms latency requirements
3. **Cross-Platform Consistency**: Avoid platform-specific implementations unless absolutely necessary
4. **Testing Compatibility**: Ensure new technologies integrate with the existing testing strategy
5. **Maintenance Burden**: Consider long-term maintenance implications and team expertise

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

- **Jog Response Time**: <50ms from user input to CNC command transmission
- **UI Responsiveness**: 60fps during all operations, including 3D visualization
- **Memory Usage**: <200MB total application memory footprint
- **Startup Time**: <3 seconds on target devices (iPad, mid-range Android tablet)

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

### 4.2. Safety Gates

- **Validation Coverage**: 100% of G-Code operations must pass through `ValidationService`
- **State Consistency**: Machine state and UI state synchronization verified in integration tests
- **Error Recovery**: All error conditions must have defined recovery paths
- **Boundary Checking**: Work envelope validation must be mathematically verified, not heuristic
- **Manual Operation Safety**: All tool change and touchoff workflows must include confirmation steps and collision prevention
- **State Transition Integrity**: Entry/exit between program and manual modes must be validated and logged

### 4.3. User Experience Gates

- **Persona Coverage**: Each major feature must demonstrate value for either Brenda or Mark
- **Accessibility**: All controls must support touch, keyboard, and accessibility features
- **Progressive Disclosure**: Complex features must have beginner-friendly entry points
- **Contextual Help**: Safety-critical operations must include inline guidance

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
