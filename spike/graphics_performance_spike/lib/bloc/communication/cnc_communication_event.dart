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