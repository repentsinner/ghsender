# grblHAL Connection Management and State Synchronization

**Author**: Gemini
**Date**: 2025-07-13
**Purpose**: This document outlines a strategy for managing the connection state of the embedded grbl protocol over the network link, ensuring the application always has an accurate and real-time understanding of the grblHAL machine controller's operational status. It also explores the synchronous/asynchronous nature of the grbl protocol and advises on structuring the communication layer.

## 1. The Challenge: Embedded Link State

While the TCP/IP (or WebSocket) connection provides network-level connectivity, grblHAL communicates using a serial-like protocol embedded within this network stream. The network link can be active, but the underlying grblHAL controller might be in an unresponsive state (e.g., in `ALARM` mode, soft-reset, or otherwise not processing commands). Therefore, it's crucial to monitor the *embedded protocol link* in addition to the network link.

## 2. Mechanism for Tracking Embedded Link State

We will implement a **heartbeat mechanism** combined with **expected response monitoring** to ascertain the health and responsiveness of the grblHAL controller.

### 2.1. Heartbeat Command: `?` (Status Report Query)

The `?` command is the most suitable heartbeat for grblHAL. It is a real-time command that requests a status report from the controller. It does not interfere with ongoing G-code streaming and provides immediate feedback on the controller's state.

-   **Frequency**: A `?` command should be sent periodically (e.g., every 200-500ms) when the application is connected and expecting status updates.
-   **Expected Response**: A valid status report string (e.g., `<Idle|WPos:0.000,0.000,0.000>`).

### 2.2. No-Op Command: `G4 P0.001` (Dwell)

While `?` is ideal for heartbeats, a `G4 P0.001` (dwell for 1 millisecond) can serve as a no-op command to test command processing. It's a valid G-code command that has minimal impact on machine operation. This can be used for more intrusive health checks if the `?` heartbeat is insufficient.

### 2.3. Connection State Machine

The `CncService` will maintain an internal state machine for the grblHAL connection, beyond just the network socket status:

-   **`Disconnected`**: No network connection.
-   **`Connecting`**: Attempting to establish network connection.
-   **`NetworkConnected`**: TCP/IP/WebSocket connection established, but grblHAL protocol not yet confirmed responsive.
-   **`GrblReady`**: Network connected, and grblHAL controller is responsive to heartbeats and processing commands (e.g., sending `ok` or status reports).
-   **`GrblAlarm`**: Controller is in an `ALARM` state, requiring user intervention (e.g., `$X` to unlock).
-   **`GrblError`**: Controller is reporting persistent errors or unexpected behavior.

**Transition Logic:**
-   Transition from `NetworkConnected` to `GrblReady` upon receiving the first valid status report or `ok` response after connection.
-   Transition to `GrblAlarm` if a status report indicates `ALARM` state.
-   Transition to `GrblError` if heartbeats consistently fail or unexpected errors occur.
-   Transition back to `Disconnected` if the network connection drops or grblHAL becomes unresponsive for a prolonged period (e.g., 3-5 missed heartbeats).

## 3. Synchronous vs. Asynchronous Nature of grbl Protocol

The grbl protocol is fundamentally **asynchronous** in its operation, but with **synchronous elements** for command processing:

-   **Asynchronous Aspects**: Status reports are streamed asynchronously. The controller can send status updates at any time, independent of commands being sent. Error messages can also appear asynchronously.
-   **Synchronous Aspects**: Most G-code and `$` commands are processed synchronously. The sender must wait for an `ok` or `error` response from grblHAL before sending the next command. This is crucial for flow control and preventing buffer overflows.

This hybrid nature means the communication layer must be designed to handle both concurrent incoming data (status reports) and sequential command-response cycles.

## 4. Structuring the Communications Layer (`CncService`)

To always have the current machine controller state available, the `CncService` should be structured as follows:

### 4.1. Dedicated Communication Thread/Isolate

-   **Purpose**: To handle all raw network I/O (reading and writing bytes/strings) and initial parsing of incoming data.
-   **Implementation**: In Dart/Flutter, this should be a dedicated `Isolate` to prevent blocking the UI thread. This isolate will manage the TCP/IP or WebSocket connection.

### 4.2. Incoming Data Stream Processing

-   **Raw Data Stream**: The communication isolate will expose a stream of raw incoming lines from grblHAL.
-   **Line Parser**: A component within the isolate (or a dedicated parser) will categorize incoming lines into:
    -   **Status Reports**: Lines starting with `<` and ending with `>`. These are parsed into `MachineState` objects.
    -   **Command Responses**: Lines like `ok` or `error:X`.
    -   **Other Messages**: Welcome messages, feedback messages, etc.

### 4.3. State Management Integration (BLoC)

-   **`MachineState` BLoC**: The `CncService` will feed parsed `MachineState` objects directly into a dedicated `MachineStateBloc` (or similar BLoC). This BLoC will be the single source of truth for the application's understanding of the machine's current state.
-   **Command Response Handling**: The `CncService` will also manage a queue for outgoing commands. For each command sent, it will expect a corresponding `ok` or `error` response. This can be handled using `Completer`s or `Future`s in Dart, where a `Future` completes when the expected response is received.

### 4.4. Outgoing Command Queue

-   **Purpose**: To ensure commands are sent to grblHAL in the correct sequence and only when the controller is ready.
-   **Mechanism**: The `CncService` will maintain an internal queue of commands to be sent. Commands are dequeued and sent only after an `ok` response is received for the previous command, or if the command is a real-time command (like `?`) that doesn't require an `ok`.

### 4.5. Heartbeat Management

-   **Timer-based**: A periodic timer within the `CncService` (or its isolate) will send `?` commands at the defined heartbeat frequency.
-   **Responsiveness Check**: The `CncService` will monitor the receipt of status reports. If a certain number of heartbeats are missed, it will trigger a state transition to `GrblError` or `Disconnected`.

## 5. Example `CncService` Structure (Conceptual)

```dart
class CncService {
  // Network connection (Socket or WebSocket)
  // StreamController for incoming raw lines
  // StreamController for parsed MachineState updates
  // Command queue (e.g., Queue<Completer<String>>)
  // Heartbeat timer

  // Current internal connection state (Disconnected, NetworkConnected, GrblReady, etc.)

  Future<void> connect(String host, int port) { /* ... */ }
  Future<void> disconnect() { /* ... */ }

  // Method to send a command and await its 'ok'/'error' response
  Future<String> sendCommand(String command) { /* ... */ }

  // Stream of real-time machine state updates
  Stream<MachineState> get machineStateStream => _machineStateController.stream;

  // Internal method to process incoming lines from the network
  void _processIncomingLine(String line) { /* ... */ }

  // Internal method to manage heartbeat and connection health
  void _manageHeartbeat() { /* ... */ }
}
```

This structured approach ensures that the application maintains a robust and accurate understanding of the grblHAL controller's state, crucial for safety and reliable operation.