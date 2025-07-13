# Testing Strategy

This document outlines the testing strategy for the G-Code sender application. A comprehensive testing approach is essential to ensure the application meets its core tenets of reliability, safety, and correctness. We will follow the principles of the testing pyramid, focusing on a strong foundation of unit tests, supplemented by widget and integration tests.

```
      /\      
     /  \     End-to-End / Integration Tests
    /----\    
   /      \   Widget Tests
  /--------\  
 /          \ Unit Tests
+------------+
```

## 1. Unit Tests

*   **Goal:** To verify the correctness of individual functions, methods, and classes in isolation. This is the fastest and most reliable type of test and will form the bulk of our testing efforts.
*   **Location:** `test/` directory, with filenames mirroring the source file (e.g., `cnc_service_test.dart`).
*   **Tools:** `package:test`, `package:mocktail` (for creating mock dependencies).

### Testing by Layer:

*   **Data / Model Layer:**
    *   **What:** Test constructors and any helper methods on the data models (e.g., `copyWith`, `toJson`).
    *   **Example:** Verify that a `MachineState` object can be correctly instantiated and that its properties are immutable.

*   **Service Layer:**
    *   **What:** Test the business logic within each service. Dependencies between services will be mocked.
    *   **Example 1 (`ValidationService`):** Create a test that provides a mock `GCode` toolpath and mock machine dimensions. Verify that the service correctly identifies whether the path is inside or outside the machine's work envelope.
    *   **Example 2 (`G-CodeParserService`):** Provide a string containing a G-Code file and assert that the service correctly parses it into a list of `G-CodeCommand` objects.

*   **State Management / BLoC Layer:**
    *   **What:** Test that BLoCs emit the correct sequence of states in response to a given sequence of events. Services that the BLoC depends on will be mocked.
    *   **Tool:** `package:bloc_test`.
    *   **Example:** For a `ConnectionBloc`, dispatch a `ConnectEvent` and mock the `CncService` to return a successful connection stream. Assert that the BLoC emits `[ConnectionState.loading(), ConnectionState.success()]`.

## 2. Widget Tests

*   **Goal:** To verify that individual Flutter widgets render correctly and respond to user interactions as expected, without needing to run the full application.
*   **Location:** `test/` directory, typically in a `features/.../view/` subdirectory.
*   **Tools:** `package:flutter_test`.

### Testing Approach:

*   **What:** Test that widgets appear, disappear, and change in response to state changes from their BLoC. The BLoCs themselves will be mocked to provide a controlled state.
*   **Example 1 (Rendering):** Provide a mock `ConnectionBloc` that is in the `ConnectionState.loading()` state. Verify that a `CircularProgressIndicator` is rendered on the connection screen.
*   **Example 2 (Interaction):** Find a `JogButton` widget, simulate a tap, and verify that the appropriate event (e.g., `JogEvent.start()`) was dispatched to its mock BLoC.

## 3. Integration & End-to-End (E2E) Tests

*   **Goal:** To verify that complete features or user flows work correctly from the UI down through the service layer. These tests are slower and more brittle but are essential for ensuring all the pieces work together.
*   **Location:** `integration_test/` directory.
*   **Tools:** `package:integration_test`, `package:flutter_test`.

### Testing Approach:

*   **What:** These tests will run on a real device or simulator. They will drive the application through the UI, simulating user actions.
*   **Mocking Strategy:** The key to successful integration testing for this application is to **mock the `CncService` at the dependency injection level**. We will create a `MockCncService` that simulates a real grblHAL controller. This mock will allow us to:
    *   Simulate successful and failed connections.
    *   Emit fake real-time status reports in response to commands.
    *   Simulate error conditions from the controller (e.g., alarms).
*   **Example Flow:**
    1.  The test starts the app.
    2.  It finds the text field for the IP address and enters a fake address.
    3.  It finds the "Connect" button and taps it.
    4.  The `MockCncService` receives the connect call and emits a stream of "connecting..." then "connected" states.
    5.  The test verifies that the UI updates accordingly, hiding the progress indicator and showing the main machine control interface.

## 4. Performance Testing

Based on the performance requirements defined in `REQUIREMENTS.md`, automated performance testing is mandatory to prevent the latency and reliability issues observed in existing G-Code senders.

### 4.1. Latency Testing

*   **Jog Response Time Testing:**
    *   **Tool:** Custom performance test harness with high-resolution timers
    *   **Method:** Measure time from user input event to TCP packet transmission
    *   **Target:** <50ms for all jogging operations
    *   **Frequency:** Every CI/CD pipeline run

*   **UI Responsiveness Testing:**
    *   **Tool:** Flutter's performance profiling tools
    *   **Method:** Monitor frame rendering times during stress conditions
    *   **Target:** Maintain 60fps during all operations
    *   **Scenarios:** Large G-Code file loading, real-time DRO updates, 3D visualization

### 4.2. Resource Usage Testing

*   **Memory Profiling:**
    *   **Tool:** Dart Observatory, platform-specific memory profilers
    *   **Target:** <200MB total application footprint
    *   **Scenarios:** Large G-Code files (10MB), extended runtime (8+ hours), rapid connection/disconnection cycles

*   **Startup Performance:**
    *   **Target:** <3 seconds to connection-ready state
    *   **Measured:** Cold start on minimum-spec devices
    *   **Automated:** CI/CD pipeline on emulated devices

### 4.3. Network Performance Testing

*   **TCP/IP Latency Testing:**
    *   **Method:** Mock network conditions (latency, packet loss, jitter)
    *   **Scenarios:** WiFi networks, Ethernet, poor network conditions
    *   **Validation:** Command delivery reliability under adverse conditions

## 5. User Testing Strategy

To avoid the user experience failures evident in existing G-Code senders, comprehensive user testing with real CNC operators is mandatory.

### 5.1. Persona-Based Testing

**Brenda (Beginner) Testing:**
*   **Participants:** 5-8 users with <6 months CNC experience
*   **Tasks:** 
    *   First-time connection to grblHAL controller
    *   Loading and validating first G-Code file
    *   Setting work coordinate system
    *   Running first job with supervision
*   **Metrics:** Task completion rate, time to completion, error recovery success
*   **Focus:** Safety feature effectiveness, onboarding clarity, error message comprehension

**Mark (Experienced) Testing:**
*   **Participants:** 5-8 users with 2+ years CNC experience
*   **Tasks:**
    *   Migrating from existing G-Code sender
    *   Complex job setup with toolpath validation
    *   Keyboard shortcut efficiency testing
    *   Advanced feature exploration
*   **Metrics:** Feature discovery rate, workflow efficiency vs. current tools, advanced feature adoption
*   **Focus:** Feature completeness, workflow optimization, professional usage patterns

### 5.2. Safety Validation Testing

**Critical Safety Scenarios:**
*   **Out-of-bounds toolpath detection:** Present intentionally problematic G-Code files
*   **Connection loss recovery:** Simulate network interruptions during jobs
*   **Emergency stop effectiveness:** Test stop command reliability under load
*   **State synchronization:** Verify UI accurately reflects machine state under all conditions

**Metrics:**
*   **Safety Feature Activation Rate:** Percentage of dangerous operations caught by validation
*   **False Positive Rate:** Safety warnings that don't represent actual risks
*   **Recovery Success Rate:** Successful return to operational state after errors

### 5.3. Usability Testing Protocol

**Testing Environment:**
*   **Real CNC machines:** Test with actual grblHAL-equipped CNCs when possible
*   **Simulated environment:** MockCncService for controlled testing scenarios
*   **Mixed reality:** Combination of real hardware with simulated dangerous scenarios

**Testing Schedule:**
*   **Alpha Testing:** Internal team and 2-3 experienced CNC users
*   **Beta Testing:** 10-15 users from each persona group
*   **Pre-release Testing:** 50+ users with diverse hardware configurations
*   **Post-release:** Continuous feedback collection via in-app mechanisms

### 5.4. Accessibility Testing

**Requirements:**
*   **Touch Targets:** Minimum 44px touch targets for tablet use
*   **Screen Reader Support:** Full VoiceOver/TalkBack compatibility
*   **High Contrast:** Support for accessibility color themes
*   **Keyboard Navigation:** Complete functionality without touch input

**Testing Tools:**
*   **Automated:** Flutter's accessibility testing framework
*   **Manual:** Testing with users who have accessibility needs
*   **Compliance:** WCAG 2.1 AA level compliance verification

## 6. Continuous Quality Assurance

### 6.1. Automated Testing Pipeline

**CI/CD Integration:**
*   **Unit Tests:** Must pass 100% for merge approval
*   **Widget Tests:** Minimum 90% pass rate for features under development
*   **Performance Tests:** Must meet all latency and resource requirements
*   **Integration Tests:** Core user flows must pass on all target platforms

### 6.2. User Feedback Integration

**Feedback Collection:**
*   **In-app feedback:** One-tap feedback mechanism for critical workflows
*   **Crash reporting:** Automatic crash report collection (opt-in)
*   **Usage analytics:** Performance metrics and feature usage patterns (opt-in)
*   **Community forums:** Integration with GitHub issues and community feedback

**Feedback Processing:**
*   **Weekly review:** Product team review of all user feedback
*   **Monthly analysis:** Trend analysis and feature prioritization
*   **Quarterly reassessment:** Product requirements and persona validation updates

### 6.3. Quality Gates

Before any release:
*   **All performance requirements met:** Verified through automated testing
*   **Safety validation passed:** No known safety regressions
*   **User testing completed:** Minimum number of users from each persona tested
*   **Accessibility compliance:** Full accessibility audit completed
*   **Device compatibility:** Tested on minimum-spec devices for each platform
