# grblHAL Communication Protocol

**Author**: Gemini
**Date**: 2025-07-13
**Purpose**: This document summarizes the communication protocol for grblHAL controllers, focusing on the TCP/IP implementation and the underlying grbl serial protocol. This information is critical for developing the `CncService` and the real-time communication spike.

## Overview

grblHAL extends the popular grbl CNC firmware to support a wider range of hardware and features, including network connectivity. For our application, communication with grblHAL will primarily occur over TCP/IP, encapsulating the standard grbl serial protocol.

This means the communication involves two main layers:
1.  **Network Transport Layer**: How data is sent and received over the network (e.g., Telnet).
2.  **grbl Serial Protocol**: The actual commands and responses that grblHAL understands.

## 1. Network Transport Layer (TCP/IP)

grblHAL supports standard TCP/IP protocols for network communication, including **Telnet** in "raw" mode and **WebSockets**. While Telnet (TCP port 23) is a common choice due to its simplicity, WebSockets are also fully supported and may be preferred for more modern implementations due to their persistent, full-duplex communication capabilities. Our application can utilize either, with a preference for WebSockets if implementation proves equally straightforward.

-   **Protocol**: TCP/IP (Telnet)
-   **Default Port**: 23
-   **Data Format**: The grbl serial protocol commands and responses are sent as plain text over the established TCP connection.

### Connection Flow:
1.  The application establishes a TCP connection to the grblHAL controller's IP address and port 23.
2.  Once connected, the application can send grbl commands as plain text strings, terminated by a newline character (CR/LF).
3.  grblHAL responds with plain text status messages and command acknowledgments.

## 2. grbl Serial Protocol (Encapsulated)

The core of the communication is the grbl serial protocol. This protocol defines the commands the controller understands and the format of its responses and status reports.

### 2.1. Commands

Commands are typically single-line ASCII strings terminated by a newline character (`\n` or `\r\n`).

**Common Command Types:**
-   **G-code Commands**: Standard G-code commands (e.g., `G0 X10 Y10`, `G28`, `G90`).
-   **`$` Commands**: grbl-specific settings and commands (e.g., `$X` for alarm unlock, `$G` for parser state, `$#` for G-code parameters).
-   **`?` (Status Report Query)**: Requests a real-time status report from the controller.
-   **`~` (Cycle Start/Resume)**: Resumes a paused program.
-   **`!` (Feed Hold/Pause)**: Pauses a running program.
-   **`ctrl-x` (Soft Reset)**: Resets the grbl controller (often sent as ASCII 24).

### 2.2. Responses

grblHAL responds to commands with single-line ASCII strings, typically `ok` for successful execution or `error:` followed by an error code for failures.

**Examples:**
-   `ok`
-   `error:2` (G-code command not supported)

### 2.3. Real-time Status Reports

grblHAL can be configured to stream real-time status reports. These reports provide critical information about the machine's current state.

**Format**: Status reports are typically enclosed in angle brackets (`<>`) and contain key-value pairs.

**Example Status Report:**
```
<Idle|WPos:0.000,0.000,0.000|FS:0,0|Ov:100,100,100>
```

**Common Fields in Status Reports:**
-   **Machine State**: `Idle`, `Run`, `Hold`, `Alarm`, `Check`, `Door`, `Home`, `Sleep`.
-   **Work Position (WPos)**: Current position in the active work coordinate system (X, Y, Z).
-   **Machine Position (MPos)**: Current position in the machine coordinate system (X, Y, Z).
-   **Feed/Speed (FS)**: Current feed rate and spindle speed.
-   **Overrides (Ov)**: Current override values for feed, rapid, and spindle.
-   **Buffer State (Bf)**: Planner and serial RX buffer levels.
-   **Line Number (Ln)**: Current G-code line number being executed.

### 2.4. Flow Control

grblHAL uses a simple flow control mechanism. It will send an `ok` response only when it is ready to receive the next command. For streaming G-code, the sender must wait for an `ok` before sending the next line.

## 3. Integration with `CncService`

The `CncService` will be responsible for:
-   Establishing and maintaining the TCP/IP connection to grblHAL.
-   Sending grbl commands and parsing `ok`/`error` responses.
-   Subscribing to and parsing real-time status reports to update the application's `MachineState`.
-   Handling connection errors and re-connection logic.

## References

-   **grblHAL Core README**: `context/grblhal/core/README.md` (Provides an overview of grblHAL features and compatibility.)
-   **grbl v1.1 Interface Documentation**: [https://github.com/gnea/grbl/wiki/Grbl-v1.1-Interface](https://github.com/gnea/grbl/wiki/Grbl-v1.1-Interface) (For detailed grbl serial protocol commands and responses, which grblHAL largely adheres to.)
-   **grblHAL GitHub Wiki**: [https://github.com/grblHAL/grblHAL/wiki](https://github.com/grblHAL/grblHAL/wiki) (For general grblHAL information and extensions.)

