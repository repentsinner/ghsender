# Framework Stack Analysis and Final Decision

**Author**: Product Management & System Architecture Team  
**Date**: 2025-07-13 (Updated)  
**Purpose**: To document the evaluation of framework choices and record the final decision, ensuring alignment across the project.

## 1. Executive Summary

This document records the analysis of two primary technology stacks for the G-Code Sender application: **Flutter/Dart/BLoC** and **Electron/TypeScript/React**.

After a comprehensive evaluation against the project's core tenets, a final decision has been made to proceed with **Flutter/Dart/BLoC**.

The primary driver for this decision is the "uncompromising reliability and state management" tenet. Flutter's native performance, direct rendering pipeline, and strong, type-safe state management patterns (BLoC) are best suited to meet the stringent requirements for low-latency, safety-critical machine control. While the Electron stack offers potential advantages in developer velocity and AI agent synergy, the project prioritizes the end-user experience, performance, and long-term reliability over initial development speed.

To mitigate the risks associated with this choice (such as a potentially slower development pace or a higher barrier for community contribution), a formal re-evaluation plan has been codified in **ADR-011: Framework Re-evaluation Triggers**. This ensures that we will "fail fast" and pivot to the Electron stack if key development or performance milestones are not met during the initial development phase.

## 2. Framework Analysis Summary

### 2.1. Flutter + Dart + BLoC (Selected Stack)

*   **Architecture**: Native application with direct rendering via the Impeller graphics engine. State is managed reactively using the BLoC pattern.
*   **Strengths**:
    *   **Performance**: Compiles to native code, providing the highest possible performance for UI rendering and real-time updates. This is critical for the 60fps visualizer and <50ms jog response time requirements.
    *   **Reliability**: Dart's strong type system, combined with the BLoC pattern for state management, provides a highly predictable and testable foundation, which is essential for a safety-critical application.
    *   **Cross-Platform Consistency**: A single codebase delivers a consistent, high-quality experience across desktop and tablet platforms, which is a core project goal.
    *   **Touch-First UI**: Flutter excels at creating high-quality, responsive touch interfaces, aligning with the tablet-first design requirement.
*   **Acknowledged Risks & Mitigation**:
    *   **Development Velocity**: May be slower than web technologies. **Mitigation**: The team's existing familiarity with Flutter and the detailed architectural planning are expected to offset this. ADR-011 provides a clear checkpoint to validate this assumption.
    *   **Community Contribution**: The Dart ecosystem is smaller than JavaScript's. **Mitigation**: The plugin architecture will be well-documented, and the core application's quality is expected to attract dedicated contributors.

### 2.2. Electron + TypeScript + React + Redux Toolkit (Alternative Stack)

*   **Architecture**: A web application running in a Node.js-managed Chromium shell. State is managed using Redux Toolkit.
*   **Strengths**:
    *   **Developer Velocity & Ecosystem**: The vast JavaScript/TypeScript ecosystem and the team's familiarity could lead to faster initial development.
    *   **AI Agent Synergy**: AI development tools currently have more extensive training data for web technologies.
    *   **Extensibility**: The VS Code extension model, built on this stack, is a proven success.
*   **Reasons for Not Selecting**:
    *   **Performance Risk**: While capable, achieving consistent, low-latency performance requires significant optimization and is subject to the overhead of the browser rendering engine and IPC communication. This was deemed an unacceptable risk for a safety-critical control application.
    *   **State Management Debugging**: While Redux DevTools are excellent, the potential for subtle, hard-to-debug state synchronization issues in a less-constrained environment was a significant concern.
    *   **Native Feel**: Electron applications, while powerful, often fall short of a true native look, feel, and performance, particularly on touch-based tablet interfaces.

## 3. Final Decision and Path Forward

The project will proceed with the **Flutter/Dart/BLoC** stack. All development will be based on the architecture and patterns described in `ARCHITECTURE.md`, `DECISIONS.md`, and the various workflow documents. The development progress will be closely monitored against the triggers defined in **ADR-011**.
