/// Events for CNC communication system
/// 
/// These events handle all communication with CNC controllers including
/// connection management, command sending, and specialized operations like
/// jogging and G-code streaming.
abstract class CncCommunicationEvent {}

/// Request connection to CNC controller via WebSocket
class CncCommunicationConnectRequested extends CncCommunicationEvent {
  final String url;
  
  CncCommunicationConnectRequested(this.url);
}

/// Request disconnection from CNC controller
class CncCommunicationDisconnectRequested extends CncCommunicationEvent {}

/// Send a single command to the CNC controller
class CncCommunicationSendCommand extends CncCommunicationEvent {
  final String command;
  
  CncCommunicationSendCommand(this.command);
}

/// Send raw bytes to the CNC controller (for real-time commands)
class CncCommunicationSendRawBytes extends CncCommunicationEvent {
  final List<int> bytes;
  
  CncCommunicationSendRawBytes(this.bytes);
}


/// Internal event for handling external status changes
class CncCommunicationStatusChanged extends CncCommunicationEvent {
  final String statusMessage;
  final bool isConnected;
  final String? deviceInfo;
  
  CncCommunicationStatusChanged({
    required this.statusMessage,
    required this.isConnected,
    this.deviceInfo,
  });
}

/// Set controller address from machine profile
class CncCommunicationSetControllerAddress extends CncCommunicationEvent {
  final String controllerAddress;
  
  CncCommunicationSetControllerAddress(this.controllerAddress);
}

/// Individual message received from CNC controller
/// Used for event-based message processing instead of accumulating message lists
class CncCommunicationMessageReceived extends CncCommunicationEvent {
  final String message;
  final DateTime timestamp;
  final CncMessageType messageType;
  
  CncCommunicationMessageReceived({
    required this.message,
    required this.timestamp,
    required this.messageType,
  });
}

/// Types of messages from CNC controller for efficient processing
enum CncMessageType {
  /// Status messages (e.g., "&lt;Idle|MPos:0,0,0|...&gt;")
  status,
  /// Configuration responses (e.g., "$0=10")
  configuration,
  /// Welcome/version messages (e.g., "Grbl 1.1f ['$' for help]")
  welcome,
  /// Acknowledgments (e.g., "ok")
  acknowledgment,
  /// Error messages (e.g., "error:1")
  error,
  /// Other messages
  other,
}

/// Message received from CNC controller with metadata
class CncMessage {
  final String content;
  final DateTime timestamp;
  final CncMessageType type;
  
  const CncMessage({
    required this.content,
    required this.timestamp,
    required this.type,
  });
  
  @override
  String toString() => 'CncMessage(${type.name}: $content)';
}