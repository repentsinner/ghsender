# Architectural Decision Records (ADRs)

## Current Proposed Decisions Requiring Resolution

1. **Framework Selection (ADR-001)**
   - Status: Proposed
   - Options: Flutter/Dart vs Electron/TypeScript/React
   - Blocking: Widget framework implementation, visualizer architecture
   - Dependencies: Affects all UI components and runtime architecture
   - Priority: HIGH - Critical path for development

2. **State Management Pattern (ADR-002)**
   - Status: Proposed (Dependent on ADR-001)
   - Options: BLoC vs Redux vs Alternatives
   - Blocking: Real-time data flow architecture
   - Priority: HIGH - Required for simulator/visualizer integration

3. **Plugin Architecture (ADR-007)**
   - Status: Proposed
   - Options: VS Code-style vs Custom approach
   - Blocking: Extension points for community contributions
   - Priority: MEDIUM - Can be evolved post-MVP

4. **Settings Management (ADR-008)**
   - Status: Proposed
   - Options: VS Code-style JSON vs Traditional GUI
   - Blocking: Machine configuration storage
   - Priority: MEDIUM - Required for MVP but implementation can be basic initially

## Previously Accepted Decisions

- **TCP/IP Communication (ADR-003)**: Exclusive network-based communication
- **grblHAL Support (ADR-004)**: Exclusive support for grblHAL controllers
- **Workflow Management (ADR-005)**: Dedicated WorkflowService for operations
- **Learning System (ADR-006)**: Adaptive learning based on user competency

## Decision Log Format

Each decision entry follows this structure:
- **Decision ID**: Unique identifier (ADR-XXX)
- **Date**: When the decision was made
- **Status**: Proposed, Accepted, Deprecated, or Superseded
- **Decision**: What was decided
- **Context**: Why this decision was necessary
- **Alternatives**: What other options were considered
- **Consequences**: Expected impact on user experience and system design
- **Review Date**: When this decision should be re-evaluated

---

## ADR-001: Framework Selection - Updated Analysis

**Date**: 2025-07-13 (Updated)  
**Status**: Proposed  
**Previous Analysis**: Flutter/Dart framework  
**Current Analysis**: Evaluating Flutter/Dart vs Electron/TypeScript/React

**Context Update**: 
Comprehensive analysis revealed key constraints: developer expertise (Flutter/Dart comfortable, React/Redux learning curve), target hardware (2024 iPad Pro M4), and user experience priority (60fps visualizer, native performance). Analysis in `FRAMEWORK_ANALYSIS.md` and `VISUALIZER_ANALYSIS.md` confirms Flutter as optimal choice.

**Key Constraint Clarifications**:
- **Developer Expertise**: Flutter/Dart comfortable, React/Redux would be learning curve
- **Target Hardware**: 2024 iPad Pro M4 - extremely powerful, power consumption not critical
- **User Experience Priority**: 60fps visualizer performance and native feel prioritized
- **Long-term Focus**: User experience guarantees win over development convenience

**Final Analysis Summary**:

**Flutter + Dart + BLoC (CONFIRMED RECOMMENDATION)**:
- **Development Velocity**: ⭐⭐⭐⭐⭐ (Developer expertise advantage)
- **User Experience**: ⭐⭐⭐⭐⭐ (Native performance, 60fps guaranteed)
- **Target Hardware**: ⭐⭐⭐⭐⭐ (Optimized for iPad Pro M4)
- **Performance**: ⭐⭐⭐⭐⭐ (Superior technical performance + hardware match)
- **State Management**: BLoC pattern familiar, excellent for real-time applications

**Electron + TypeScript + React + Redux Toolkit (ALTERNATIVE)**:
- **Development Velocity**: ⭐⭐⭐ (Learning curve for React/Redux)
- **User Experience**: ⭐⭐⭐⭐ (Good but not native)
- **Target Hardware**: ⭐⭐⭐ (Less optimized for tablet experience)
- **Performance**: ⭐⭐⭐⭐ (Adequate with optimization potential)
- **State Management**: Redux learning curve but good debugging tools

**Critical Insights**:
1. **Developer Expertise**: Flutter/Dart familiarity eliminates learning curve, maximizes development velocity
2. **Hardware Target**: 2024 iPad Pro M4 provides exceptional performance for Flutter applications
3. **User Experience**: Native performance guarantees and 60fps visualizer achievable with Flutter
4. **Long-term Value**: User experience quality prioritized over short-term development convenience

**State Management Comparison**:
```dart
// BLoC - Familiar pattern, excellent for real-time applications
class MachineBloc extends Bloc<MachineEvent, MachineState> {
  final CncService _cncService;
  
  MachineBloc(this._cncService) : super(MachineState.disconnected()) {
    // Real-time position updates - familiar stream handling
    _cncService.positionStream.listen((position) {
      add(PositionUpdated(position));
    });
    
    on<UpdatePosition>((event, emit) {
      emit(state.copyWith(position: event.position));
    });
  }
}
```

```typescript
// Redux Toolkit - Would require learning new patterns
const machineSlice = createSlice({
  name: 'machine',
  initialState: { status: 'idle', position: { x: 0, y: 0, z: 0 } },
  reducers: {
    updatePosition: (state, action) => {
      state.position = action.payload; // New learning required
    }
  }
});
```

**Final Decision**: Continue with Flutter + Dart + BLoC

**Implementation Strategy**:
1. **Architecture Confirmed**: All documented architectural patterns apply directly to Flutter
2. **Service Layer**: Dart services with isolates for background processing
3. **State Management**: BLoC pattern for all state management as originally planned
4. **UI Components**: Flutter widgets optimized for iPad Pro M4
5. **Real-time Communication**: Dart isolates for TCP/IP communication with grblHAL

**Consequences**:
- **Positive**: 
  - Maximum development velocity using familiar Flutter/Dart stack
  - Superior user experience with native performance guarantees
  - Optimized for target hardware (iPad Pro M4)
  - 60fps visualizer performance achievable
  - Lower memory usage and better power efficiency
  - Excellent tablet touch experience built-in
- **Negative**: 
  - Community contribution barrier due to Dart knowledge requirement
  - Smaller ecosystem compared to JavaScript/TypeScript
  - Less VS Code pattern alignment for extension system
- **Risks Accepted**: 
  - Community growth may be slower initially
  - Plugin development requires Dart knowledge
  - AI agent assistance somewhat limited compared to web technologies

**Review Date**: 2025-10-01 (after initial implementation experience)

**Reference**: See `FRAMEWORK_ANALYSIS.md` and `VISUALIZER_ANALYSIS.md` for comprehensive technical analysis and performance comparisons.

---

## ADR-002: BLoC State Management Pattern

**Date**: 2025-07-13  
**Status**: Accepted  
**Decision**: Use flutter_bloc for state management across the application

**Context**:
Need predictable, testable state management that clearly separates machine state (from CNC controller) and application state (local settings). Must support real-time updates and error handling.

**Alternatives**:
1. **Provider + ChangeNotifier**: Simpler, Flutter-recommended approach
   - Pros: Official recommendation, easier learning curve
   - Cons: Less structured for complex state, potential performance issues with rapid updates

2. **Riverpod**: Modern state management with better compile-time safety
   - Pros: Better developer experience, compile-time safety, excellent testing
   - Cons: Newer, smaller ecosystem, different mental model

3. **GetX**: All-in-one solution with state management, routing, and dependency injection
   - Pros: Comprehensive solution, simple API
   - Cons: Opinionated architecture, potential for overuse, less predictable

**Consequences**:
- **Positive**: Clear event-driven architecture, excellent testability, separation of concerns, predictable state flows
- **Negative**: Steeper learning curve, more boilerplate than simpler solutions
- **Safety Impact**: Event-driven pattern ensures all state changes are trackable and testable

**Review Date**: 2025-12-01 (after core services implementation)

---

## ADR-003: TCP/IP Communication Protocol

**Date**: 2025-07-13  
**Status**: Accepted  
**Decision**: Exclusively support TCP/IP network communication with grblHAL controllers

**Context**:
Traditional G-Code senders use USB/serial connections, but this limits tablet support and adds driver complexity. Modern grblHAL controllers support Ethernet/WiFi connectivity.

**Alternatives**:
1. **USB/Serial Only**: Traditional approach used by existing senders
   - Pros: Universal compatibility, direct connection, no network setup
   - Cons: Requires drivers, no tablet support, single-device limitation

2. **Dual Support**: Both TCP/IP and USB/serial
   - Pros: Maximum compatibility, gradual migration path
   - Cons: Complex abstraction layer, doubled testing burden, architectural complexity

3. **Bluetooth**: Wireless serial alternative
   - Pros: Wireless, good mobile support
   - Cons: Reliability issues, pairing complexity, limited bandwidth

**Consequences**:
- **Positive**: Enables tablet support, no driver dependencies, network-based architecture allows multiple client connections
- **Negative**: Requires network-capable CNC controllers, users must configure network settings
- **Risks**: Network reliability concerns, potential latency issues over WiFi

**Review Date**: 2025-10-01 (after initial user testing)

---

## ADR-004: grblHAL Exclusive Support

**Date**: 2025-07-13  
**Status**: Accepted  
**Decision**: Support only grblHAL controllers, not legacy Grbl or other firmwares

**Context**:
Existing G-Code senders try to support multiple controller types, leading to complex abstraction layers and lowest-common-denominator feature sets. grblHAL represents the modern evolution of Grbl.

**Alternatives**:
1. **Multi-Controller Support**: Support Grbl, grblHAL, TinyG, Smoothieware, etc.
   - Pros: Broader market appeal, compatibility with existing setups
   - Cons: Complex abstraction layer, feature limitations, testing complexity

2. **Grbl + grblHAL**: Support both Grbl variants
   - Pros: Covers most hobbyist market, simpler than full multi-controller
   - Cons: Still requires abstraction, limits access to grblHAL-specific features

**Consequences**:
- **Positive**: Can leverage grblHAL-specific features, simpler architecture, focused development effort
- **Negative**: Smaller initial addressable market, requires users to upgrade firmware
- **Safety Impact**: Access to grblHAL's enhanced safety features and real-time reporting

**Review Date**: 2026-06-01 (reassess market adoption of grblHAL)

---

## Template for Future Decisions

```markdown
## ADR-XXX: [Decision Title]

**Date**: YYYY-MM-DD  
**Status**: [Proposed/Accepted/Deprecated/Superseded]  
**Decision**: [What was decided]

**Context**: 
[Why this decision was necessary]

**Alternatives**:
1. **Option 1**: [Description]
   - Pros: [Benefits]
   - Cons: [Drawbacks]

2. **Option 2**: [Description]
   - Pros: [Benefits]
   - Cons: [Drawbacks]

**Consequences**:
- **Positive**: [Expected benefits]
- **Negative**: [Expected costs/limitations]
- **Risks**: [Potential issues]

**Review Date**: YYYY-MM-DD [When to reassess]
```

---

---

## ADR-005: WorkflowService for Manual Operations

**Date**: 2025-07-13  
**Status**: Accepted  
**Decision**: Create a dedicated `WorkflowService` to manage state transitions between G-Code execution and manual intervention modes

**Context**: 
Manual operations like tool changes and workpiece touchoff are the highest-risk moments in CNC operation. Unlike professional controllers that handle these operations internally, hobbyist G-Code senders must manage complex state transitions between automated and manual modes. Existing senders handle this poorly, leading to confusion and accidents.

**Alternatives**:
1. **Integrate into CncService**: Handle manual workflows within the existing CNC communication service
   - Pros: Simpler architecture, fewer services
   - Cons: Violates single responsibility principle, makes CncService overly complex

2. **BLoC-Level Management**: Handle workflow state entirely within individual BLoCs
   - Pros: Distributed state management, simpler service layer
   - Cons: Complex cross-BLoC coordination, difficult to ensure state consistency

3. **Manual Mode Toggle**: Simple binary mode switching without structured workflows
   - Pros: Simplest implementation, familiar pattern
   - Cons: No safety guidance, high accident risk, poor user experience for beginners

**Consequences**:
- **Positive**: Clear separation of concerns, structured safety workflows, consistent state management across manual operations, testable workflow logic
- **Negative**: Additional service complexity, more sophisticated state machine requirements
- **Safety Impact**: Significantly reduces risk during manual operations by providing structured, guided workflows with safety checkpoints

**Review Date**: 2025-11-01 (after tool change and touchoff implementation)

---

## ADR-006: Adaptive Learning System Architecture

**Date**: 2025-07-13  
**Status**: Accepted  
**Decision**: Implement a dedicated `LearningService` with adaptive workflow progression based on demonstrated user competency

**Context**: 
User research and persona analysis revealed that both beginners and experienced users need different approaches to learning new workflows. Brenda needs gradual confidence building with progressive skill development, while Mark needs rapid onboarding that respects his existing expertise. No existing G-Code sender provides adaptive learning capabilities.

**Alternatives**:
1. **Static Skill Level Selection**: Let users manually choose "Beginner," "Intermediate," or "Expert" modes
   - Pros: Simple implementation, clear user control
   - Cons: Users often misjudge their skill level, no progression motivation, binary experience

2. **Profile-Based Learning**: Create user profiles with saved preferences
   - Pros: Personalized experience, profile sharing
   - Cons: Static approach, no adaptation based on actual performance, complex profile management

3. **No Learning System**: Provide single workflow interface for all users
   - Pros: Simplest implementation, consistent experience
   - Cons: Frustrates experts with hand-holding, overwhelms beginners with complexity

4. **Tutorial Mode Only**: Separate tutorial system disconnected from actual workflows
   - Pros: Clear learning separation, familiar pattern
   - Cons: No transfer to real operations, users skip tutorials, safety gaps between tutorial and real use

**Consequences**:
- **Positive**: 
  - Dynamic adaptation improves user confidence and efficiency
  - Measurable learning progression provides engagement and motivation
  - Expert onboarding reduces migration friction from other senders
  - Safety validation maintained regardless of skill level
- **Negative**: 
  - Additional complexity in workflow state management
  - Competency assessment algorithms require tuning and validation
  - More sophisticated testing requirements for adaptive behaviors
- **Safety Impact**: 
  - Learning progression never compromises safety validation
  - Builds user confidence through successful operation completion
  - Reduces accidents through appropriate pacing of complexity introduction

**Review Date**: 2026-02-01 (after user testing with adaptive learning features)

---

## ADR-007: Extensibility Architecture for Market Adoption Success

**Date**: 2025-07-13  
**Status**: Accepted  
**Decision**: Implement plugin architecture and extensibility framework from MVP foundation to support rapid post-MVP feature development

**Context**: 
Analysis of open-source maker software adoption patterns shows that platforms achieve market dominance through rapid feature development, strong community engagement, and hardware ecosystem support. The goal is to become the #1 G-Code sender that drives grblHAL hardware adoption. The maker community values software that grows with their skills and enables community contributions. Our research shows existing G-Code senders fail partly due to architectural limitations that prevent clean feature addition and community scaling.

**Alternatives**:
1. **Monolithic Growth**: Add features directly to core codebase without extensibility framework
   - Pros: Faster initial feature development, simpler architecture
   - Cons: Technical debt accumulation, feature conflicts, difficult community contributions

2. **Microservice Architecture**: Break functionality into separate services
   - Pros: Complete isolation, independent deployment
   - Cons: Over-engineering for desktop app, communication complexity, performance overhead

3. **Fork-Friendly Architecture**: Design for community forks rather than extensions
   - Pros: Maximum flexibility for community
   - Cons: Fragmentation, incompatible extensions, maintenance burden

4. **Defer Extensibility**: Build extensibility later when needed
   - Pros: Focus on MVP delivery
   - Cons: Architectural refactoring costs, missed community engagement opportunity

**Consequences**:
- **Positive**: 
  - Clean extension points enable rapid feature development
  - Community can contribute specialized workflows and integrations
  - Plugin marketplace creates ecosystem value and user engagement
  - Event-driven architecture prevents feature conflicts
  - Learning system can be extended for specialized competencies
- **Negative**: 
  - Additional architectural complexity in MVP
  - Plugin safety and validation requirements
  - More sophisticated testing and quality assurance needs
- **Adoption Impact**: 
  - Enables rapid response to community feature requests
  - Creates network effects that drive user adoption and retention
  - Supports hardware vendor partnerships and ecosystem growth
  - Reduces core development burden through distributed community contributions
  - Establishes platform as the preferred choice for grblHAL hardware

**Review Date**: 2026-01-01 (after first community plugin contributions)

---

## ADR-008: VS Code Design Pattern Adoption

**Date**: 2025-07-13  
**Status**: Accepted  
**Decision**: Adopt proven VS Code design patterns where applicable to leverage their successful platform strategy in the orthogonal CNC market

**Context**: 
VS Code achieved dominance through excellent platform design that enabled community growth, rapid extensibility, and user adoption. Since we're targeting similar adoption goals in the CNC space, we should leverage their proven patterns rather than reinventing solutions. The VS Code settings system, in particular, provides a powerful model for advanced configuration while maintaining accessibility.

**Key VS Code Patterns to Adopt**:

1. **JSON-Based Configuration with IntelliSense:**
   ```json
   // settings.json - Machine Configuration
   {
     "machine.grblhal.hostname": "192.168.1.100",
     "machine.workEnvelope": {
       "x": { "min": 0, "max": 800 },
       "y": { "min": 0, "max": 800 }, 
       "z": { "min": -100, "max": 0 }
     },
     "workflows.toolChange.safeHeight": 10,
     "learning.adaptiveSpeed": true,
     "ui.theme": "dark"
   }
   ```

2. **Command Palette Pattern:**
   - `Ctrl+Shift+P`: "grblHAL: Connect to Controller"
   - `Ctrl+Shift+P`: "Workflow: Start Tool Change"
   - `Ctrl+Shift+P`: "Learning: Reset Progression for Tool Changes"

3. **Extension Marketplace Model:**
   - Community-contributed workflow templates
   - Hardware-specific extensions (e.g., "Shapeoko Pro Extension")
   - CAM software integrations (e.g., "Fusion 360 Workflow Bridge")

4. **Settings UI with JSON Fallback:**
   - Beginner-friendly settings UI for common configurations
   - Power users can edit raw JSON for advanced scenarios
   - IntelliSense and validation in JSON editor

5. **Workspace/Project Concept:**
   - Project-specific machine configurations
   - Shared workflow templates within projects
   - Version-controlled settings for team collaboration

**Alternatives**:
1. **Traditional Preferences Dialog**: Simple GUI-only settings
   - Pros: Familiar pattern, beginner-friendly
   - Cons: Limited extensibility, hard to script, no version control

2. **Configuration Files Only**: Pure config file approach
   - Pros: Power user friendly, scriptable
   - Cons: Intimidating for beginners, no guided discovery

3. **Database-Stored Settings**: Settings in local database
   - Pros: Structured data, easy queries
   - Cons: Not version controllable, not portable, harder to debug

**Consequences**:
- **Positive**: 
  - Proven pattern reduces design risk and development time
  - JSON settings enable advanced automation and scripting
  - Extension marketplace pattern accelerates community adoption
  - Command palette provides efficient expert workflows
  - Settings approach scales from beginner GUI to expert JSON
- **Negative**: 
  - JSON can be intimidating for some beginners
  - Additional complexity in settings validation and migration
  - Need to build IntelliSense and validation infrastructure
- **Adoption Impact**: 
  - Familiar patterns reduce friction for developers migrating from VS Code
  - Extensible configuration enables hardware vendor customizations
  - Command palette supports rapid expert workflows
  - JSON settings enable CI/CD and automation workflows

**Implementation Strategy**:
1. **Phase 1 (MVP)**: Basic settings UI with JSON export/import
2. **Phase 2**: Full JSON editor with IntelliSense and validation
3. **Phase 3**: Command palette implementation
4. **Phase 4**: Workspace/project settings and extension marketplace

**Review Date**: 2025-12-01 (after settings system implementation)

---

## ADR-009: Human-Readable Interface Over Technical Implementation

**Date**: 2025-07-13  
**Status**: Accepted  
**Decision**: Prioritize human-readable descriptions and workflows over technical G-Code/M-Code implementation details in all user interfaces

**Context**: 
Traditional G-Code senders require users to learn historical implementation details like G-codes (G54-G59), M-codes (M3/M5), and grblHAL settings ($-parameters). This creates a significant learning barrier and forces users to understand machine language rather than focusing on their actual goals. Our user research shows that users want to "change coordinate systems" or "start spindle" rather than memorize that G54 means "Work Coordinate System 1" or M3 means "spindle clockwise."

**Key Principles**:
1. **Primary Interface**: Human-readable descriptions that clearly explain what will happen
2. **Secondary Information**: Technical codes visible for power users who know them
3. **Progressive Disclosure**: Beginner users see only what they need, experts can access full technical details
4. **Contextual Help**: Explain why and when to use features, not just what they do

**Implementation Examples**:

**Coordinate System Selection:**
```
┌─────────────────────────────────────────────────────────┐
│  Work Coordinate System: Project Workpiece (G54) ▼     │
│  ├─ Project Workpiece (G54) ● Active                   │
│  ├─ Secondary Setup (G55)                              │
│  ├─ Fixture A Position (G56)                           │
│  └─ [+ Create New Coordinate System...]                │
└─────────────────────────────────────────────────────────┘
```

**Machine Settings:**
```
┌─────────────────────────────────────────────────────────┐
│  Machine Configuration                                  │
│  ┌─────────────────────────────────────────────────────┐ │
│  │ Maximum Feed Rate (X-Axis)                         │ │
│  │ How fast the machine can move in X direction       │ │
│  │ [2000] mm/min                          ($110)      │ │
│  └─────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────┐ │
│  │ Homing Seek Rate                                    │ │
│  │ Speed when moving to find limit switches           │ │
│  │ [500] mm/min                           ($24)       │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**Tool Control:**
```
┌─────────────────────────────────────────────────────────┐
│  Spindle Control                                        │
│  [Start Clockwise] [Start Counter-Clockwise] [Stop]    │
│  Speed: [12000] RPM                                     │
│  Status: Stopped                          (M3/M4/M5)   │
└─────────────────────────────────────────────────────────┘
```

**Alternatives**:
1. **Technical-First Interface**: Show G-codes and M-codes prominently with descriptions secondary
   - Pros: Familiar to experienced users, direct machine correlation
   - Cons: High learning barrier, intimidating to beginners, perpetuates historical complexity

2. **Hide Technical Details Completely**: Never show codes or technical references
   - Pros: Simplest for beginners, clean interface
   - Cons: Frustrates power users, limits troubleshooting, reduces learning opportunities

3. **Mode-Based Interface**: Separate "Beginner" and "Expert" modes with different terminology
   - Pros: Targeted experience for each user type
   - Cons: Creates artificial barriers, mode switching complexity, duplicated interface maintenance

**Consequences**:
- **Positive**: 
  - Significantly lower learning curve for new CNC users
  - Reduced cognitive load allows focus on machining rather than code memorization
  - Progressive disclosure supports natural skill development
  - Power users maintain access to technical details when needed
  - Clearer error messages and troubleshooting guidance
- **Negative**: 
  - Additional complexity in UI design and information architecture
  - Need to maintain mapping between human descriptions and technical codes
  - Potential confusion when transitioning between this sender and traditional tools
  - More text to translate for internationalization
- **Safety Impact**: 
  - Clearer understanding of actions reduces user errors
  - Better error messages improve troubleshooting success
  - Reduced confusion about machine state and capabilities

**Implementation Guidelines**:
1. **Primary Text**: Clear, action-oriented descriptions ("Change to Secondary Setup" not "Switch to G55")
2. **Secondary Text**: Technical codes in parentheses or smaller text for reference
3. **Help Text**: Explain when and why to use features, not just technical specifications
4. **Error Messages**: Describe what went wrong and how to fix it, not just error codes
5. **Progressive Disclosure**: Show complexity only when user demonstrates readiness

**Specific Areas to Update**:
- DRO Widget coordinate system display
- Settings configuration descriptions  
- Tool change workflow instructions
- G-Code validation error messages
- Machine status indicators
- Workflow step descriptions

**Review Date**: 2026-01-01 (after user testing with new interface patterns)

---

## Decision Review Schedule

- **Quarterly Reviews**: Check all decisions with review dates in the current quarter
- **Major Version Reviews**: Reassess all architectural decisions before major releases
- **Technology Updates**: Review framework and dependency decisions when new major versions are released
- **Performance Reviews**: Reassess performance-related decisions after each performance testing cycle

---

## ADR-011: Framework Re-evaluation Triggers

*   **Date**: 2025-07-13
*   **Status**: Accepted
*   **Decision**: A formal review of the Flutter/Dart framework choice will be triggered if the project fails to meet the success criteria of the technology spikes defined in **Phase 0** of the [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md).

*   **Context**: The choice of Flutter/Dart was made based on its perceived performance benefits and native cross-platform capabilities. However, the success of this project also depends on rapid development, AI agent synergy, and the potential for community contributions. We must have a "fail fast" mechanism to switch to the alternative Electron/TypeScript/React stack if the initial assumptions about Flutter prove incorrect in practice.

*   **Triggers for Re-evaluation**: A formal review will be initiated if **two or more** of the technology spikes in the `FRAMEWORK_VALIDATION_PLAN.md` fail to meet their defined acceptance criteria.

*   **Review Process**:
    1.  If triggered, a one-day "Framework Review" will be held.
    2.  The review will involve a direct, practical comparison of implementing a single, complex feature (e.g., the Tool Change workflow) in both the current Flutter codebase and a prototype Electron/React codebase.
    3.  The decision to switch will be based on which stack demonstrates a clear advantage in meeting the project's core tenets of reliability, performance, and development velocity.

*   **Consequences**: This ADR provides a clear, data-driven escape hatch from the initial framework decision. It prioritizes long-term project success over sticking with an initial choice that proves to be suboptimal. It forces an early, honest assessment of the chosen technology against the project's primary goals.

---

## ADR-010: Functional Programming Paradigm with BLoC

**Date**: 2025-07-13
**Status**: Accepted
**Decision**: The application will be developed using a hybrid approach with a strong emphasis on functional programming (FP) principles, particularly for state management and business logic. The BLoC (Business Logic Component) pattern will be the primary mechanism for implementing this.

**Context**:
The application is a safety-critical system that requires a high degree of predictability, testability, and maintainability. The state of the application must be perfectly synchronized with the state of the CNC machine at all times. Imperative programming, with its reliance on mutable state, can lead to complex and unpredictable behavior, which is unacceptable for this application.

**Alternatives**:
1.  **Purely Imperative Programming**: This is the traditional approach and what many developers are familiar with. However, it makes state management complex and error-prone, which is a significant risk for this project.
2.  **Purely Functional Programming**: While this would provide the most predictability, it would also have a steeper learning curve and might not be the best fit for UI programming.

**Consequences**:
-   **Positive**:
    -   **Predictability**: Pure functions and immutable state make it easier to reason about the application's behavior.
    -   **Testability**: Pure functions are easy to test, which will lead to a more robust test suite.
    -   **State Management**: The BLoC pattern provides a clear and structured way to manage state, which is critical for this application.
-   **Negative**:
    -   **Learning Curve**: The team will need to be disciplined in applying FP principles.
    -   **Boilerplate**: The BLoC pattern can sometimes be verbose.

**Review Date**: 2025-12-01 (after core services implementation)