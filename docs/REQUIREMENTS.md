# Project Requirements: A Modern G-Code Sender

This document outlines the requirements for a new G-Code sender application designed for high reliability, low latency, and cross-platform compatibility, specifically targeting modern CNC controllers.

## 1. Core Tenets

### 1.8. Requirements Quality and Lifecycle

All requirements are subject to a "Definition of Ready" (DoR) before development commences. This ensures clarity, completeness, and testability, minimizing ambiguity and rework. The DoR criteria are detailed in the [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md) document.


### 1.1. Uncompromising Reliability and State Management

The absolute highest priority is the safety and correctness of the system. The application must maintain a perfectly synchronized and accurate representation of the machine controller's state at all times. Discrepancies between the UI and the physical state of the machine can lead to catastrophic hardware damage and are unacceptable. The system architecture must be designed from the ground up to guarantee state integrity.

To enforce this, a clear separation of state ownership must be maintained:
- **Machine State (Single Source of Truth: Controller):** The grblHAL controller is the definitive source for all physical machine parameters and real-time status. This includes, but is not limited to, machine volume, maximum speeds per axis, current position, and operational mode. The application will always fetch this information from the controller upon connection and subscribe to real-time updates. It will *never* store its own authoritative version of the machine's physical state.
- **Application State (Single Source of Truth: Application):** The application is responsible for managing its own state, which includes user preferences and UI configurations. This includes settings like display units (metric/imperial), color themes (light/dark mode), visualizer preferences, and user-defined macros. This state will be managed locally and persisted on the device.

### 1.2. Low-Latency Interaction

Manual machine operations, particularly jogging to set workpiece coordinate systems, are high-risk activities. The application must ensure minimal latency between user input and machine response. Delays in command execution can cause tool collisions, resulting in irreparable damage to the machine and workpiece. The communication and command processing pipeline must be optimized for real-time performance.

### 1.3. Comprehensive Machine Monitoring

The application must provide clear, real-time feedback and visualization of the machine's status. This includes:
- **Real-time State Updates:** The UI must instantly reflect any changes in the machine's state, such as position, speed, and operational mode.
- **Clear Feedback:** Users must be provided with unambiguous feedback on the status of their commands and the overall state of the machine.
- **Effective Visualization:** A high-quality, real-time visualization of the toolpath and machine position is essential for understanding the machine's operation and for identifying potential issues before they occur.

### 1.4. Proactive Error Prevention

The application must be designed to anticipate and prevent common user errors, reducing the risk of machine damage and wasted materials. This is especially important for hobbyist users who may not have extensive experience.
- **In-Context Documentation:** All settings and controls within the UI should have clear, concise explanations available directly alongside them. This eliminates ambiguity and helps users make informed decisions.
- **Pre-run Simulation and Validation:** Before a job is started, the application must perform a comprehensive simulation. This includes:
    - **Boundary Checking:** The visualizer must display the machine's physical work envelope and verify that the entire G-Code toolpath is contained within these boundaries. The user must be alerted to any potential out-of-bounds movements *before* cutting begins.
    - **G-Code Validation:** The application should parse and validate the G-Code for common errors or unsupported commands.

### 1.5. Manual Intervention Workflow Safety

The application must provide exceptional safety and clarity during manual operations that occur outside of G-Code program execution. These are the highest-risk moments in CNC operation, where operator confusion or unclear machine state can lead to collisions and damage.

#### 1.5.1. State Transition Management
- **Clear Mode Indication:** The UI must unambiguously display whether the machine is in "Program Execution" mode or "Manual Intervention" mode at all times
- **Controlled Transitions:** Entry and exit from program execution must be explicit user actions with confirmation dialogs explaining the implications
- **State Preservation:** When pausing program execution for manual intervention, the application must preserve and clearly display the program state (current line, position, etc.) and provide clear pathways to resume
- **Mode-Specific Controls:** UI controls must be contextually appropriate - manual controls disabled during program execution, program controls disabled during manual intervention

#### 1.5.2. Tool Change Workflow Safety
- **Step-by-Step Guidance:** Provide a wizard-style interface that guides users through each step of manual tool changes
- **Position Awareness:** Automatically move to safe tool change position before allowing tool removal
- **Tool Validation:** After tool change, require operator confirmation of tool type/size and validate against program requirements
- **Collision Prevention:** Warn users of potential collisions when moving with new tool dimensions
- **Recovery Procedures:** Clear instructions for recovering from tool change errors or misaligned tools

#### 1.5.3. Workpiece Touchoff Workflow Safety
- **Progressive Approach:** Provide multi-speed jogging (rapid → medium → fine) for safe approach to workpiece surfaces
- **Contact Detection:** Integrate with probe inputs or provide clear manual confirmation workflows for surface contact
- **Undo Capability:** Allow operators to easily undo/retry touchoff operations if they make mistakes
- **Visual Confirmation:** Display coordinate system changes in real-time with clear before/after indicators
- **Boundary Validation:** After touchoff, re-validate that the G-Code program will stay within machine limits with the new coordinate system

#### 1.5.4. Real-Time Feedback During Manual Operations
- **Immediate Response:** All manual commands must provide immediate visual feedback of machine response
- **Clear Intention:** Before executing any manual command, display what will happen, how fast it will occur, and what the operator should expect
- **Stop Authority:** Provide immediate, always-accessible emergency stop that works regardless of current operation mode
- **Progress Indication:** For multi-step manual operations, show clear progress and next-step expectations
- **Adaptive Learning Feedback:** System must track successful operation completions and progressively reduce confirmation requirements while maintaining safety validation
- **Competency Recognition:** Workflows must adapt speed and detail level based on demonstrated user competency, with clear indicators of current skill level recognition

### 1.6. Adaptive Learning and Skill Development

The application must support progressive skill development for all users, from complete beginners to experienced operators learning new workflow paradigms.

#### 1.6.1. Learning Progression System
- **Competency Tracking:** System must track successful completion of manual operations and workflow steps to assess user skill development
- **Progressive Complexity:** Workflows must start with detailed, step-by-step confirmations and gradually group related operations as competency is demonstrated
- **Skill Level Recognition:** Application must provide clear indicators of current recognized skill level for each type of operation (e.g., "Beginner," "Intermediate," "Expert" for tool changes)
- **Milestone Celebration:** System must acknowledge and celebrate user progress to build confidence and encourage skill development

#### 1.6.2. Expert Learning Mode
- **Rapid Onboarding:** For experienced CNC operators, provide option to experience complete workflow once for understanding, then immediately adapt to streamlined interface
- **Workflow Pattern Learning:** System must recognize and suggest optimizations based on user workflow patterns
- **Customizable Acceleration:** Allow experts to manually adjust learning progression speed for different operation types

#### 1.6.3. Adaptive Workflow Speeds
- **Dynamic Pacing:** Workflow execution speed must adapt based on demonstrated competency while maintaining safety validation
- **Context-Aware Adaptation:** Different operation types (tool change, touchoff, jogging) must have independent competency tracking
- **Safety Override:** Regardless of skill level, critical safety validations must never be bypassed, only streamlined in presentation

### 1.7. Proactive Issue Discovery and Reporting

To continuously improve the software and address problems before they are widely reported, the application will incorporate a mechanism for telemetry and error reporting.
- **User Opt-In:** Data collection will be strictly opt-in. Users will be prompted on first use and can change their preference at any time in the settings. User privacy is paramount.
- **Anonymous Analytics:** The application will collect anonymized data on feature usage and performance to help guide development priorities.
- **Automated Error Reporting:** The application will automatically capture and report anonymized crash reports and non-fatal errors. This will allow the development team to identify and fix bugs proactively.
- **Learning Analytics:** With user consent, collect anonymized data on learning progression patterns to improve adaptive algorithms

## 2. Target Controller and Communication

### 2.1. Exclusive grblHAL Support

To ensure a modern and consistent feature set, the application will exclusively support CNC controllers running **grblHAL**. This focus eliminates the complexity of supporting a wide variety of legacy controllers and firmware versions.

### 2.2. Network-Based Communication

The application will communicate with the grblHAL controller exclusively over a **network connection (TCP/IP)**. This approach offers several advantages:
- **Simplified Connectivity:** Eliminates the need for physical serial (USB) connections and the associated driver complexities.
- **Enhanced Platform Support:** Enables the application to run on devices that lack traditional serial ports, such as tablets.
- **Robustness:** Network protocols provide a more robust and standardized communication layer compared to serial connections.

## 3. Platform Support

### 3.1. True Cross-Platform Operation

The application must be truly cross-platform, capable of running on a wide range of devices. The primary goal is to move beyond the traditional desktop-only paradigm.

### 3.2. Tablet-First Interface

A key requirement is first-class support for tablet devices, particularly the **iPad**. The machine shop environment is often better suited to a ruggedized tablet than a desktop or laptop computer. The UI/UX must be designed with a touch-first approach.

### 3.3. Desktop Support

While being tablet-first, the application must also function seamlessly on traditional desktop operating systems, including:
- **Windows**
- **macOS**
- **Linux**

## 4. Recommended Technology

### 4.1. Flutter & Dart Ecosystem

The recommended technology stack is the **Flutter framework with the Dart programming language**. This choice is based on several key factors that directly address the project's core requirements:

- **High-Performance UI:** Flutter compiles to native code, providing the high-performance graphics rendering necessary for a smooth, responsive user interface and low-latency interactions.
- **Excellent Cross-Platform Support:** Flutter's single codebase can be deployed natively to iOS, Android, Windows, macOS, and Linux, perfectly aligning with the project's platform goals.
- **Strong Networking Capabilities:** Dart has robust, built-in libraries for handling network sockets and asynchronous communication, which is ideal for the required TCP/IP-based controller interface.
- **Focus on State Management:** The Flutter ecosystem has a strong emphasis on robust state management patterns (e.g., BLoC, Provider, Riverpod), which will be critical for ensuring the reliability and correctness of the application's state synchronization with the CNC controller.

## 5. Performance Requirements

Based on analysis of existing G-Code sender deficiencies, the following performance requirements are mandatory and measurable:

### 5.1. Real-Time Interaction Requirements

- **Jog Response Time**: Maximum 50ms from user input (touch/keyboard) to CNC command transmission
- **UI Frame Rate**: Maintain 60fps during all operations, including:
  - Real-time DRO updates
  - 3D toolpath visualization during job execution
  - Manual jogging operations
  - G-Code file loading and parsing
- **State Synchronization**: Machine state updates reflected in UI within 100ms of controller status change

### 5.2. Resource Usage Limits

- **Memory Footprint**: Total application memory usage <200MB on target devices
- **Startup Time**: Application ready for CNC connection within 3 seconds on:
  - iPad (A12 Bionic or newer)
  - Mid-range Android tablet (Snapdragon 660 equivalent or better)
  - Desktop systems (minimum 8GB RAM, dual-core processor)
- **Network Bandwidth**: Efficient TCP/IP usage <1KB/s during idle monitoring, <10KB/s during active job execution

### 5.3. Scalability Requirements

- **G-Code File Size**: Support files up to 10MB (approximately 500,000 lines) without performance degradation
- **Visualization Performance**: Render toolpaths with up to 100,000 line segments at 60fps
- **Command Queue**: Handle burst command queues of up to 1,000 commands without latency impact

### 5.4. Reliability Performance

- **Connection Recovery**: Automatic reconnection within 5 seconds of network interruption
- **Error Recovery Time**: Return to operational state within 2 seconds of recoverable errors
- **Data Integrity**: Zero tolerance for state desynchronization between UI and controller

### 5.5. Performance Monitoring

All performance requirements will be:
- **Measured**: Automated performance testing in CI/CD pipeline
- **Monitored**: Real-time performance metrics collected via `AnalyticsService` (with user opt-in)
- **Enforced**: Quality gates prevent deployment if performance requirements are not met

### 5.6. Performance Testing Strategy

- **Unit Tests**: Verify individual service response times
- **Widget Tests**: Measure UI rendering performance under load
- **Integration Tests**: End-to-end latency testing with mock CNC controller
- **Device Testing**: Regular performance validation on minimum-spec target devices
