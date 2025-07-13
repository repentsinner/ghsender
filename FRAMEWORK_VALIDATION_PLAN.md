# Framework Validation Plan (Phase 0)

**Purpose:** To validate that the selected Flutter/Dart/BLoC stack can meet the project's most critical technical and performance requirements before committing to full feature development. This phase directly addresses the highest-risk assumptions in our technology choice.

**Success Criteria:** Successful completion of the following technology spikes within the defined performance envelopes. Failure in two or more spikes will trigger the re-evaluation process defined in ADR-011.

---

### Spike 1: Real-time Communication Pipeline

*   **Question:** Can Dart's TCP sockets, running in a background `Isolate`, handle a high-frequency stream of status updates from the `grblhalsimulator` without blocking the main UI thread or dropping data?
*   **"Toy Program" Description:**
    1.  Create a minimal Flutter application with a simple UI (e.g., a single text field to show a counter).
    2.  Implement a `CncService` that connects to the `grblhalsimulator` over TCP/IP.
    3.  The TCP communication **must** run in a separate Dart `Isolate` to simulate the final architecture and prevent UI thread blocking.
    4.  The service will subscribe to the real-time status stream from the simulator.
    5.  On receiving a status message, the service will simply increment a counter and display the raw message on the console.
*   **Acceptance Criteria:**
    *   The application successfully connects to the simulator.
    *   The UI remains responsive (maintains 60fps) while the status stream is active.
    *   No status messages are dropped.
    *   The latency from the simulator sending a message to it being processed in the app is consistently below 20ms.

---

### Spike 2: High-Performance Graphics Rendering

*   **Question:** Can Flutter's `CustomPainter` API efficiently render a large, static toolpath and handle real-time position updates at 60fps?
*   **"Toy Program" Description:**
    1.  Create a minimal Flutter application with a `CustomPaint` widget filling the screen.
    2.  Hard-code a list of 100,000 2D line segments.
    3.  Implement a `VisualizerPainter` that draws all 100,000 segments in its `paint` method.
    4.  Add a button to the UI that, when pressed, simulates a machine position update by re-drawing a single, small circle at a random location on the canvas.
*   **Acceptance Criteria:**
    *   The initial render of the 100,000 segments completes within a reasonable time (< 500ms).
    *   The application maintains a consistent 60fps, verified using Flutter DevTools.
    *   Pressing the position update button results in an immediate redraw with no visible stutter or frame drops.
    *   Memory usage remains stable and within acceptable limits (< 150MB).

---

### Spike 3: State Management Stress Test

*   **Question:** Can the BLoC pattern efficiently process a high-frequency stream of events without becoming a performance bottleneck?
*   **"Toy Program" Description:**
    1.  Create a minimal Flutter application with a single text widget.
    2.  Implement a `MachineBloc` that manages a simple state object containing only a position counter.
    3.  Create a mock service that simulates a high-frequency data stream by emitting an event to the `MachineBloc` every 10 milliseconds for 10 seconds (a total of 1000 events).
    4.  The UI will listen to the `MachineBloc`'s state stream and update the text widget with the latest counter value.
*   **Acceptance Criteria:**
    *   The BLoC successfully processes all 1000 events without errors.
    *   The UI updates smoothly and reflects the final counter value correctly.
    *   Flutter DevTools show no significant performance issues or memory leaks related to the BLoC during the event storm.
