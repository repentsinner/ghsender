# Development Plan

**Last Updated**: 2025-07-13  
**Status Tracking**: Evidence-based scheduling with confidence intervals  
**Progress**: 2 of 15 major milestones completed (13%)  
**Current Status**: Planning and documentation phase  
**Estimated MVP Completion**: 3-6 months (assumes Flutter validation successful)

This document outlines the development phases and milestones for ghSender. The primary goal of the initial phases is to deliver a functional MVP that allows an expert user to connect to a grblHAL controller, load a G-Code file, set up a workpiece, and execute the program.

## Progress Legend
- ✅ **Complete** - Delivered and verified
- 🚧 **In Progress** - Currently being worked on  
- 📋 **Ready** - Meets Definition of Ready, can start immediately
- 🔍 **Analysis** - Needs requirements analysis or technical research
- ⏸️ **Blocked** - Cannot proceed due to dependencies
- ❌ **Not Started** - Not yet analyzed or planned

## Effort Estimation Method
**Evidence-Based Scheduling** with confidence intervals:
- **Best Case** (10% probability) - Everything goes perfectly
- **Most Likely** (50% probability) - Normal development with typical issues
- **Worst Case** (90% probability) - Includes debugging, rework, and complications

**Effort Scale**: 
- XS: 1-2 days
- S: 3-5 days  
- M: 1-2 weeks
- L: 2-4 weeks
- XL: 1-2 months

## Guiding Principles for MVP

*   **Focus on the Core Workflow:** The highest priority is the end-to-end workflow of executing a G-Code program on a physical machine.
*   **Expert User First:** The initial implementation will assume an expert user (the "Mark" persona) who is comfortable with CNC concepts and requires less guidance. The adaptive learning features will be scaffolded but not fully implemented.
*   **Scaffold, Don't Build Out:** Features like the Visualizer and the Learning Service are important for the long-term vision but are considered "nice-to-haves" for the initial MVP. They will be scaffolded in place to ensure the architecture is sound, but their functionality will be minimal.

## Definition of Ready (DoR)

Before any development task or user story can be pulled into an active sprint or development phase, it must meet the following criteria. This ensures clarity, reduces rework, and maintains development velocity.

1.  **Clear Acceptance Criteria**: The task has well-defined, testable acceptance criteria that specify what "done" looks like.
2.  **Dependencies Identified**: All external and internal dependencies (e.g., API endpoints, UI designs, other tasks) are identified and addressed.
3.  **Technical Approach Outlined**: A high-level technical approach or solution sketch is documented, including any significant architectural considerations.
4.  **Effort Estimated**: The task has a reasonable effort estimate, agreed upon by the development team.
5.  **UX/UI Mockups Approved (if applicable)**: For user-facing features, relevant UX/UI designs or wireframes are finalized and approved.
6.  **Security Considerations Reviewed**: Potential security implications are briefly reviewed and noted.
7.  **Observability Requirements Defined**: Logging, metrics, or error reporting needs for debugging are specified.
8.  **No Ambiguities**: Any ambiguities or open questions are resolved.

---

## Phase 0: Technology Spike & De-risking (Deliverable 0)

**Status**: 🚧 In Progress (1 of 3 spikes complete)  
**Overall Effort**: M (1-2 weeks) | Best: S (3-5 days) | Likely: M (1-2 weeks) | Worst: L (3-4 weeks)  
**Dependencies**: Flutter dev environment setup (macOS or Windows 11)  
**Risk Level**: High - fundamental technology validation  
**Development Target**: Desktop development (macOS/Windows 11) for de-risking  
**Cross-Platform**: Supports development on both macOS and Windows 11
**Progress**: Communication spike complete (2025-07-13), awaiting hardware for final validation

**Goal:** To validate the core technical assumptions of the Flutter/Dart framework before committing to feature development. This phase prioritizes toolchain viability over user-facing features to mitigate project risk.

**Phase 0 Development Strategy:**
- **Target Platforms**: macOS and Windows 11 desktop development environments
- **Cross-Platform Validation**: Prove Flutter works consistently on both development platforms
- **Rationale**: Reduces complexity during critical technology validation while ensuring cross-platform compatibility
- **Future Validation**: iPad and mobile deployment characteristics validated in Phase 1
- **Benefits**: Faster iteration, simpler debugging, no mobile platform constraints, team OS flexibility

**References:** 
- See [FRAMEWORK_VALIDATION_PLAN.md](FRAMEWORK_VALIDATION_PLAN.md) for detailed descriptions of the technology spikes
- See [docs/development/CROSS_PLATFORM_SETUP.md](docs/development/CROSS_PLATFORM_SETUP.md) for macOS and Windows 11 development environment setup

**Key Milestones:**

1.  **Real-time Communication Spike:** ✅ Complete (2025-07-13)
    *   **Effort**: S (3-5 days) | Best: XS (2 days) | Likely: S (4 days) | Worst: M (8 days)
    *   **Actual Effort**: 1 day
    *   **Task:** Prove that Dart Isolates can handle high-frequency TCP communication without blocking the UI thread.
    *   **Outcome:** A "toy program" that successfully communicates with the `grblhalsimulator` and meets the performance criteria defined in the validation plan.
    *   **Developer Notes**: TCP socket implementation is straightforward in Dart, but isolate communication patterns need validation. Main risk is message passing overhead between isolates.
    *   **Results**:
        - ✅ **TCP in Dart Isolate**: Successfully implemented and tested
        - ❌ **<20ms Latency**: Failed (measured 200-230ms, but appears to be simulator limitation)
        - ❌ **60fps UI**: Failed (consistent UI jank detected during high-frequency communication)
        - ✅ **No Message Drops**: Passed
        - ✅ **High-Frequency Communication**: Successfully sustained 20ms interval messaging
    *   **Key Findings**: 
        - Dart Isolates successfully separate TCP communication from UI thread
        - High latency (200-230ms) appears to be grblHAL simulator limitation, not Flutter/Dart
        - UI jank persists despite isolate architecture - requires optimization in state management
        - Package updates (flutter_bloc 9.1.1, web_socket_channel 3.0.3) had no impact on performance
    *   **Recommendation**: Proceed with hardware testing to validate latency. UI performance needs optimization but is not a blocker.

2.  **Graphics Performance Spike:** 🔍 Analysis  
    *   **Effort**: S (3-5 days) | Best: XS (2 days) | Likely: S (5 days) | Worst: M (10 days)
    *   **Task:** Prove that Flutter's rendering engine can handle the demands of the visualizer.
    *   **Outcome:** A "toy program" that renders a large number of static line segments while maintaining 60fps during real-time updates.
    *   **Developer Notes**: Flutter Canvas performance for line rendering is well-documented. Main challenge is optimizing draw calls and managing large datasets. CustomPainter approach should work well.

3.  **State Management Stress Test:** 🔍 Analysis
    *   **Effort**: XS (1-2 days) | Best: XS (1 day) | Likely: XS (2 days) | Worst: S (4 days)  
    *   **Task:** Prove that the BLoC pattern can handle high-frequency state updates without performance degradation.
    *   **Outcome:** A "toy program" that processes a high-volume event storm through a BLoC with a responsive UI.
    *   **Developer Notes**: BLoC pattern with streams is well-suited for this. Main consideration is ensuring UI doesn't rebuild excessively. Should be quick to validate.

**Decision Point:** The results of this phase will be evaluated against the triggers in **ADR-011**. A decision will be made to either proceed with Flutter or pivot to the Electron/TypeScript/React stack.

**Phase 0 Completion Criteria:**
- [x] Communication spike complete (partial pass - hardware validation needed)
- [ ] Graphics performance spike demonstrates acceptable rendering
- [ ] State management spike handles high-frequency updates
- [ ] Performance benchmarks meet requirements in validation plan  
- [ ] Technical risks documented and mitigation strategies defined
- [ ] Go/no-go decision documented as ADR

---

## Phase 1: Core Connection and Real-time Communication (Deliverable 1)

**Status**: ⏸️ Blocked (waiting for Phase 0 completion)  
**Overall Effort**: L (2-4 weeks) | Best: M (10 days) | Likely: L (3 weeks) | Worst: XL (6 weeks)  
**Dependencies**: Phase 0 technology validation, grblHAL protocol documentation  
**Risk Level**: Medium-High - core communication foundation  
**Development Target**: macOS desktop + initial iPad deployment validation

**Phase 1 Platform Strategy:**
- **Primary Development**: Continue on macOS desktop for rapid iteration
- **iPad Validation**: Deploy to iPad for performance and UX baseline testing
- **Cross-Platform Testing**: Validate touch interface assumptions early

**Goal:** Establish a stable connection to the grblHAL controller and verify that we can send commands and receive real-time status updates. This phase is critical for validating the foundational communication layer.

**Implementation Details:**

*   **`CncService` Interface Definition:**
    *   Define the abstract class `CncService` with methods like `connect(host, port)`, `disconnect()`, `sendCommand(command)`, and streams for `statusStream` and `responseStream`.
    *   The `statusStream` will emit `MachineState` objects.
    *   The initial `MachineState` data model (using `freezed`) will be defined with fields for `workPosition`, `machinePosition`, and `status` (e.g., 'Idle', 'Run').

*   **grblHAL Protocol Research:**
    *   The development team will need to understand the grblHAL communication protocol, including TCP/IP command and status report formats. Refer to [GRBLHAL_COMMUNICATION.md](GRBLHAL_COMMUNICATION.md) for details. This is a prerequisite for the `CncService` implementation.

**Key Milestones:**

1.  **`CncService` Implementation:** ⏸️ Blocked
    *   **Effort**: M (1-2 weeks) | Best: S (5 days) | Likely: M (10 days) | Worst: L (3 weeks)
    *   **Task:** Implement the `CncService` to establish a TCP/IP connection to a grblHAL controller.
    *   **Acceptance Criteria:**
        *   The application can successfully connect to a grblHAL controller at a specified IP address and port.
        *   The connection status (Connected/Disconnected/Error) is clearly displayed in the UI.
        *   The application can handle connection errors gracefully and provide meaningful feedback to the user.
    *   **Developer Notes**: TCP connection is straightforward, but grblHAL protocol parsing and error handling will require careful implementation. Need to research protocol documentation thoroughly.

2.  **Real-time Status Streaming:** ⏸️ Blocked  
    *   **Effort**: M (1-2 weeks) | Best: S (5 days) | Likely: M (8 days) | Worst: L (3 weeks)
    *   **Task:** Implement the functionality to receive and parse real-time status updates from the controller.
    *   **Acceptance Criteria:**
        *   The application subscribes to the grblHAL status stream upon connection.
        *   A basic Digital Readout (DRO) widget is implemented to display the machine's real-time position (MPos and WPos) and status (e.g., `Idle`, `Run`, `Alarm`).
        *   The DRO updates in real-time (< 100ms latency from controller update to UI update).
    *   **Developer Notes**: Status parsing logic will be complex - need to handle various grblHAL status formats. UI updates need to be efficient to meet latency requirements.

3.  **Manual Command Interface:** ⏸️ Blocked
    *   **Effort**: S (3-5 days) | Best: XS (2 days) | Likely: S (4 days) | Worst: M (8 days)
    *   **Task:** Implement a simple "console" or input field to send G-Code commands directly to the controller.
    *   **Acceptance Criteria:**
        *   The user can type a G-Code command (e.g., `G0 X10`) and send it to the controller.
        *   The controller's response (`ok` or `error`) is displayed in the UI.
        *   The DRO updates to reflect the new machine position after a move command.
    *   **Developer Notes**: Relatively straightforward UI component. Main complexity is command queuing and response correlation.

4.  **Simulator Integration:** ⏸️ Blocked
    *   **Effort**: XS (1-2 days) | Best: XS (1 day) | Likely: XS (2 days) | Worst: S (3 days)
    *   **Task:** Ensure that the `CncService` can connect to the `grblhalsimulator` for development and testing.
    *   **Acceptance Criteria:**
        *   The application can connect to the simulator as if it were a real controller.
        *   All communication functionality works as expected with the simulator.
    *   **Developer Notes**: Should be minimal effort if CncService is properly abstracted. Main risk is simulator behavior differences from real hardware.

**Phase 1 Completion Criteria:**
- [ ] Stable connection to grblHAL controller established
- [ ] Real-time status updates working with <100ms latency
- [ ] Manual command interface functional
- [ ] All functionality verified with simulator
- [ ] Error handling and recovery procedures implemented
- [ ] Unit tests for core communication components

---

## Phase 2: G-Code Execution and Manual Control (Deliverable 2)

**Status**: ⏸️ Blocked (waiting for Phase 1 completion)  
**Overall Effort**: XL (1-2 months) | Best: L (3 weeks) | Likely: XL (6 weeks) | Worst: 3+ months  
**Dependencies**: Phase 1 communication layer, file system access patterns  
**Risk Level**: High - complex state management and user workflows

**Goal:** Enable a user to load a G-Code file, perform a basic workpiece setup, and execute the program. This phase focuses on the core state management of the application's workflows.

**Implementation Details:**

*   **Service Interface Definitions:**
    *   Define the interfaces for `GCodeParserService`, `WorkflowService`, and `LearningService`.
*   **Initial Machine Configurations:**
    *   Define the default machine configurations for at least two common machine types (e.g., Shapeoko, X-Carve). This will involve creating the initial JSON configuration files.
*   **MVP "Definition of Done":**
    *   A user can successfully complete a job from start to finish. This includes connecting to the machine, loading a file, setting the origin, and running the program.

**Key Milestones:**

1.  **File Loading and Parsing:** ⏸️ Blocked
    *   **Effort**: M (1-2 weeks) | Best: S (5 days) | Likely: M (10 days) | Worst: L (3 weeks)
    *   **Task:** Implement the ability to load a `.nc` file from the local filesystem.
    *   **Acceptance Criteria:**
        *   The user can select a `.nc` file using a native file picker.
        *   The `GCodeParserService` is implemented to parse the file into a list of commands.
        *   Basic program information (e.g., number of lines, estimated runtime) is displayed.
    *   **Developer Notes**: File picker varies by platform - need Flutter file_picker package. G-Code parsing is regex-heavy but well-defined. Risk is handling malformed files gracefully.

2.  **Execution State Management (BLoC):** ⏸️ Blocked
    *   **Effort**: M (1-2 weeks) | Best: S (5 days) | Likely: M (12 days) | Worst: L (4 weeks)
    *   **Task:** Implement the BLoC for managing the execution state (`Idle`, `Running`, `Paused`).
    *   **Acceptance Criteria:**
        *   The application can transition between states correctly.
        *   The UI updates to reflect the current execution state.
        *   The appropriate controls (`Start`, `Pause`, `Stop`) are enabled/disabled based on the state.
    *   **Developer Notes**: State machine logic is complex - many edge cases around pause/resume, error states, and recovery. Need comprehensive state transition testing.

3.  **Manual Jogging Controls:** ⏸️ Blocked
    *   **Effort**: M (1-2 weeks) | Best: S (4 days) | Likely: M (8 days) | Worst: L (3 weeks)
    *   **Task:** Implement the `Jog Controls` widget for manual machine movement.
    *   **Acceptance Criteria:**
        *   The user can jog the machine in all axes (X, Y, Z).
        *   The user can select different step sizes for jogging (e.g., 0.1mm, 1mm, 10mm).
        *   The jog controls are disabled during program execution.
    *   **Developer Notes**: UI is straightforward but requires careful UX design for tablet use. Need touch-friendly controls with good visual feedback. Risk is poor responsiveness on mobile.

4.  **Workpiece Origin Setup (G54):** ⏸️ Blocked
    *   **Effort**: L (2-4 weeks) | Best: M (10 days) | Likely: L (3 weeks) | Worst: XL (6 weeks)
    *   **Task:** Implement the workflow for setting the workpiece origin (XY and Z zero).
    *   **Acceptance Criteria:**
        *   The user can jog the machine to the desired origin point.
        *   The user can set the current position as the work coordinate system origin (e.g., by sending `G10 L20 P1 X0 Y0 Z0`).
        *   The DRO updates to show the new work coordinates.
    *   **Developer Notes**: This is safety-critical workflow with complex UI requirements. Need to implement sheet goods spoilboard workflow from documentation. High risk of UX complexity.

5.  **Basic Visualizer Scaffold:** ⏸️ Blocked
    *   **Effort**: L (2-4 weeks) | Best: M (8 days) | Likely: L (2.5 weeks) | Worst: XL (2 months)
    *   **Task:** Create a placeholder for the visualizer component.
    *   **Acceptance Criteria:**
        *   A simple, non-interactive 2D view is implemented that displays the full toolpath from the loaded G-Code file.
        *   The visualizer does **not** need to update in real-time for the MVP. It should be an empty black box if rendering the toolpath is too complex for the MVP.
    *   **Developer Notes**: Even "simple" 2D rendering can be complex with large G-Code files. Need efficient Canvas rendering. High risk if performance requirements aren't met.

6.  **Learning Service Scaffold:** ⏸️ Blocked
    *   **Effort**: XS (1-2 days) | Best: XS (1 day) | Likely: XS (2 days) | Worst: S (3 days)
    *   **Task:** Create a placeholder for the `LearningService`.
    *   **Acceptance Criteria:**
        *   The `LearningService` is created with placeholder methods that return default "expert" level settings.
        *   The application does **not** need to implement any adaptive learning features for the MVP.
    *   **Developer Notes**: Simple scaffolding work. Low risk since it's just interface definitions and default implementations.

**Phase 2 Completion Criteria:**
- [ ] Complete end-to-end job execution workflow functional
- [ ] File loading and G-Code parsing working reliably
- [ ] Manual jogging controls responsive and intuitive  
- [ ] Workpiece origin setup workflow implemented per safety requirements
- [ ] Basic visualizer displaying toolpaths
- [ ] All state transitions tested and stable
- [ ] Integration tests covering full workflow
- [ ] Performance requirements met (<50ms jog response, 60fps UI)

---

## Project Timeline Summary

### Overall Schedule (Evidence-Based Estimates)

| Phase | Status | Best Case | Most Likely | Worst Case | Risk Level |
|-------|--------|-----------|-------------|------------|------------|
| **Phase 0: Technology Validation** | 🔍 Analysis | 3-5 days | 1-2 weeks | 3-4 weeks | High |
| **Phase 1: Core Communication** | ⏸️ Blocked | 10 days | 3 weeks | 6 weeks | Medium-High |
| **Phase 2: G-Code Execution** | ⏸️ Blocked | 3 weeks | 6 weeks | 3+ months | High |
| **MVP Total** | **Planning** | **5-7 weeks** | **10-11 weeks** | **4-7 months** | **High** |

### Critical Path Dependencies
1. **Phase 0 → Phase 1**: Flutter validation must succeed for Phase 1 to proceed
2. **Phase 1 → Phase 2**: Core communication must be stable before complex workflows
3. **Framework Pivot Risk**: If Flutter fails validation, add 2-4 weeks for Electron migration

### Key Risk Factors
- **Technology Risk**: Flutter performance validation (Phase 0)
- **Complexity Risk**: State management and safety workflows (Phase 2) 
- **Integration Risk**: grblHAL protocol implementation (Phase 1)
- **UX Risk**: Touch-friendly tablet interface design (Phase 2)

### Milestone Gates
- **Phase 0 Complete**: Go/no-go decision on Flutter vs Electron
- **Phase 1 Complete**: Core communication validated, ready for workflow development
- **Phase 2 Complete**: MVP functional, ready for user testing

### Development Team Readiness
✅ **Complete**: Team coordination framework, documentation strategy, git workflow  
🚧 **In Progress**: Project planning and estimation  
📋 **Ready**: Technology validation can begin immediately  
⏸️ **Blocked**: Core development waiting for Phase 0 completion

### Evidence-Based Scheduling Notes
- **Best Case (10%)**: Assumes ideal conditions, no significant roadblocks
- **Most Likely (50%)**: Normal development pace with typical debugging and iteration
- **Worst Case (90%)**: Includes major technical challenges, rework, and scope creep
- **Confidence Level**: Medium - based on Flutter experience but CNC domain adds complexity

### Next Steps
1. **Immediate**: Begin Phase 0 technology validation
2. **Week 1-2**: Complete Phase 0, document results, make framework decision
3. **Week 3+**: Proceed with Phase 1 or pivot to Electron based on Phase 0 results
