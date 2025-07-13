# Development Plan

This document outlines the development phases and milestones for the G-Code Sender application. The primary goal of the initial phases is to deliver a functional MVP that allows an expert user to connect to a grblHAL controller, load a G-Code file, set up a workpiece, and execute the program.

## Guiding Principles for MVP

*   **Focus on the Core Workflow:** The highest priority is the end-to-end workflow of executing a G-Code program on a physical machine.
*   **Expert User First:** The initial implementation will assume an expert user (the "Mark" persona) who is comfortable with CNC concepts and requires less guidance. The adaptive learning features will be scaffolded but not fully implemented.
*   **Scaffold, Don't Build Out:** Features like the Visualizer and the Learning Service are important for the long-term vision but are considered "nice-to-haves" for the initial MVP. They will be scaffolded in place to ensure the architecture is sound, but their functionality will be minimal.

---

## Phase 0: Technology Spike & De-risking (Deliverable 0)

**Goal:** To validate the core technical assumptions of the Flutter/Dart framework before committing to feature development. This phase prioritizes toolchain viability over user-facing features to mitigate project risk.

**Reference:** See [FRAMEWORK_VALIDATION_PLAN.md](FRAMEWORK_VALIDATION_PLAN.md) for detailed descriptions of the technology spikes.

**Key Milestones:**

1.  **Real-time Communication Spike:**
    *   **Task:** Prove that Dart Isolates can handle high-frequency TCP communication without blocking the UI thread.
    *   **Outcome:** A "toy program" that successfully communicates with the `grblhalsimulator` and meets the performance criteria defined in the validation plan.

2.  **Graphics Performance Spike:**
    *   **Task:** Prove that Flutter's rendering engine can handle the demands of the visualizer.
    *   **Outcome:** A "toy program" that renders a large number of static line segments while maintaining 60fps during real-time updates.

3.  **State Management Stress Test:**
    *   **Task:** Prove that the BLoC pattern can handle high-frequency state updates without performance degradation.
    *   **Outcome:** A "toy program" that processes a high-volume event storm through a BLoC with a responsive UI.

**Decision Point:** The results of this phase will be evaluated against the triggers in **ADR-011**. A decision will be made to either proceed with Flutter or pivot to the Electron/TypeScript/React stack.

---

## Phase 1: Core Connection and Real-time Communication (Deliverable 1)

**Goal:** Establish a stable connection to the grblHAL controller and verify that we can send commands and receive real-time status updates. This phase is critical for validating the foundational communication layer.

**Implementation Details:**

*   **`CncService` Interface Definition:**
    *   Define the abstract class `CncService` with methods like `connect(host, port)`, `disconnect()`, `sendCommand(command)`, and streams for `statusStream` and `responseStream`.
    *   The `statusStream` will emit `MachineState` objects.
    *   The initial `MachineState` data model (using `freezed`) will be defined with fields for `workPosition`, `machinePosition`, and `status` (e.g., 'Idle', 'Run').

*   **grblHAL Protocol Research:**
    *   The development team will need to read the grblHAL documentation to understand the exact TCP/IP command and status report format. This is a prerequisite for the `CncService` implementation.

**Key Milestones:**

1.  **`CncService` Implementation:**
    *   **Task:** Implement the `CncService` to establish a TCP/IP connection to a grblHAL controller.
    *   **Acceptance Criteria:**
        *   The application can successfully connect to a grblHAL controller at a specified IP address and port.
        *   The connection status (Connected/Disconnected/Error) is clearly displayed in the UI.
        *   The application can handle connection errors gracefully and provide meaningful feedback to the user.

2.  **Real-time Status Streaming:**
    *   **Task:** Implement the functionality to receive and parse real-time status updates from the controller.
    *   **Acceptance Criteria:**
        *   The application subscribes to the grblHAL status stream upon connection.
        *   A basic Digital Readout (DRO) widget is implemented to display the machine's real-time position (MPos and WPos) and status (e.g., `Idle`, `Run`, `Alarm`).
        *   The DRO updates in real-time (< 100ms latency from controller update to UI update).

3.  **Manual Command Interface:**
    *   **Task:** Implement a simple "console" or input field to send G-Code commands directly to the controller.
    *   **Acceptance Criteria:**
        *   The user can type a G-Code command (e.g., `G0 X10`) and send it to the controller.
        *   The controller's response (`ok` or `error`) is displayed in the UI.
        *   The DRO updates to reflect the new machine position after a move command.

4.  **Simulator Integration:**
    *   **Task:** Ensure that the `CncService` can connect to the `grblhalsimulator` for development and testing.
    *   **Acceptance Criteria:**
        *   The application can connect to the simulator as if it were a real controller.
        *   All communication functionality works as expected with the simulator.

---

## Phase 2: G-Code Execution and Manual Control (Deliverable 2)

**Goal:** Enable a user to load a G-Code file, perform a basic workpiece setup, and execute the program. This phase focuses on the core state management of the application's workflows.

**Implementation Details:**

*   **Service Interface Definitions:**
    *   Define the interfaces for `GCodeParserService`, `WorkflowService`, and `LearningService`.
*   **Initial Machine Configurations:**
    *   Define the default machine configurations for at least two common machine types (e.g., Shapeoko, X-Carve). This will involve creating the initial JSON configuration files.
*   **MVP "Definition of Done":**
    *   A user can successfully complete a job from start to finish. This includes connecting to the machine, loading a file, setting the origin, and running the program.

**Key Milestones:**

1.  **File Loading and Parsing:**
    *   **Task:** Implement the ability to load a `.nc` file from the local filesystem.
    *   **Acceptance Criteria:**
        *   The user can select a `.nc` file using a native file picker.
        *   The `GCodeParserService` is implemented to parse the file into a list of commands.
        *   Basic program information (e.g., number of lines, estimated runtime) is displayed.

2.  **Execution State Management (BLoC):**
    *   **Task:** Implement the BLoC for managing the execution state (`Idle`, `Running`, `Paused`).
    *   **Acceptance Criteria:**
        *   The application can transition between states correctly.
        *   The UI updates to reflect the current execution state.
        *   The appropriate controls (`Start`, `Pause`, `Stop`) are enabled/disabled based on the state.

3.  **Manual Jogging Controls:**
    *   **Task:** Implement the `Jog Controls` widget for manual machine movement.
    *   **Acceptance Criteria:**
        *   The user can jog the machine in all axes (X, Y, Z).
        *   The user can select different step sizes for jogging (e.g., 0.1mm, 1mm, 10mm).
        *   The jog controls are disabled during program execution.

4.  **Workpiece Origin Setup (G54):**
    *   **Task:** Implement the workflow for setting the workpiece origin (XY and Z zero).
    *   **Acceptance Criteria:**
        *   The user can jog the machine to the desired origin point.
        *   The user can set the current position as the work coordinate system origin (e.g., by sending `G10 L20 P1 X0 Y0 Z0`).
        *   The DRO updates to show the new work coordinates.

5.  **Basic Visualizer Scaffold:**
    *   **Task:** Create a placeholder for the visualizer component.
    *   **Acceptance Criteria:**
        *   A simple, non-interactive 2D view is implemented that displays the full toolpath from the loaded G-Code file.
        *   The visualizer does **not** need to update in real-time for the MVP. It should be an empty black box if rendering the toolpath is too complex for the MVP.

6.  **Learning Service Scaffold:**
    *   **Task:** Create a placeholder for the `LearningService`.
    *   **Acceptance Criteria:**
        *   The `LearningService` is created with placeholder methods that return default "expert" level settings.
        *   The application does **not** need to implement any adaptive learning features for the MVP.
