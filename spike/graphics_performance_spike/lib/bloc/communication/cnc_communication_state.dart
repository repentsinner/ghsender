import 'package:equatable/equatable.dart';

/// States for CNC communication system
/// 
/// Represents all possible states of communication with CNC controllers,
/// including connection status, machine state, and performance metrics.
abstract class CncCommunicationState extends Equatable {
  const CncCommunicationState();
  
  @override
  List<Object?> get props => [];
}

/// Initial state - no connection attempted
class CncCommunicationInitial extends CncCommunicationState {
  const CncCommunicationInitial();
}

/// Controller address has been configured
class CncCommunicationAddressConfigured extends CncCommunicationState {
  final String controllerAddress;
  final DateTime configuredAt;
  
  const CncCommunicationAddressConfigured({
    required this.controllerAddress,
    required this.configuredAt,
  });
  
  @override
  List<Object?> get props => [controllerAddress, configuredAt];
}

/// Attempting to connect to CNC controller
class CncCommunicationConnecting extends CncCommunicationState {
  const CncCommunicationConnecting();
}

/// Successfully connected to CNC controller
class CncCommunicationConnected extends CncCommunicationState {
  final String url;
  final String statusMessage;
  final String? deviceInfo;
  final DateTime connectedAt;
  
  const CncCommunicationConnected({
    required this.url,
    required this.statusMessage,
    this.deviceInfo,
    required this.connectedAt,
  });
  
  @override
  List<Object?> get props => [url, statusMessage, deviceInfo, connectedAt];
}

/// Disconnected from CNC controller
class CncCommunicationDisconnected extends CncCommunicationState {
  final String statusMessage;
  final String? reason;
  final DateTime? disconnectedAt;
  
  const CncCommunicationDisconnected({
    required this.statusMessage,
    this.reason,
    this.disconnectedAt,
  });
  
  @override
  List<Object?> get props => [statusMessage, reason, disconnectedAt];
}

/// Communication error occurred
class CncCommunicationError extends CncCommunicationState {
  final String errorMessage;
  final String statusMessage;
  final dynamic error;
  final StackTrace? stackTrace;
  
  const CncCommunicationError({
    required this.errorMessage,
    required this.statusMessage,
    this.error,
    this.stackTrace,
  });
  
  @override
  List<Object?> get props => [errorMessage, statusMessage, error, stackTrace];
}

/// Connected state with communication data and metrics
class CncCommunicationWithData extends CncCommunicationState {
  final String url;
  final List<String> messages;
  final bool isConnected;
  final PerformanceData? performanceData;
  final MachineState? machineState;
  final bool jogTestRunning;
  final DateTime connectedAt;
  
  const CncCommunicationWithData({
    required this.url,
    required this.messages,
    required this.isConnected,
    this.performanceData,
    this.machineState,
    this.jogTestRunning = false,
    required this.connectedAt,
  });
  
  @override
  List<Object?> get props => [
    url,
    messages,
    isConnected,
    performanceData,
    machineState,
    jogTestRunning,
    connectedAt,
  ];
  
  CncCommunicationWithData copyWith({
    String? url,
    List<String>? messages,
    bool? isConnected,
    PerformanceData? performanceData,
    MachineState? machineState,
    bool? jogTestRunning,
    DateTime? connectedAt,
  }) {
    return CncCommunicationWithData(
      url: url ?? this.url,
      messages: messages ?? this.messages,
      isConnected: isConnected ?? this.isConnected,
      performanceData: performanceData ?? this.performanceData,
      machineState: machineState ?? this.machineState,
      jogTestRunning: jogTestRunning ?? this.jogTestRunning,
      connectedAt: connectedAt ?? this.connectedAt,
    );
  }
}

/// Performance metrics for communication monitoring
class PerformanceData extends Equatable {
  final int messagesPerSecond;
  final double averageLatencyMs;
  final double maxLatencyMs;
  final int totalMessages;
  final int droppedMessages;
  final List<LatencyMeasurement> recentLatencies;
  
  const PerformanceData({
    required this.messagesPerSecond,
    required this.averageLatencyMs,
    required this.maxLatencyMs,
    required this.totalMessages,
    required this.droppedMessages,
    required this.recentLatencies,
  });
  
  /// Check if latency meets performance requirements (< 20ms average)
  bool get meetsLatencyRequirement => averageLatencyMs < 20.0;
  
  /// Status indicator for latency performance
  String get latencyStatus => meetsLatencyRequirement ? "✅ PASS" : "❌ FAIL";
  
  @override
  List<Object?> get props => [
    messagesPerSecond,
    averageLatencyMs,
    maxLatencyMs,
    totalMessages,
    droppedMessages,
    recentLatencies,
  ];
}

/// Individual latency measurement for performance tracking
class LatencyMeasurement extends Equatable {
  final DateTime timestamp;
  final double latencyMs;
  final int commandId;
  
  const LatencyMeasurement({
    required this.timestamp,
    required this.latencyMs,
    required this.commandId,
  });
  
  @override
  List<Object?> get props => [timestamp, latencyMs, commandId];
}

/// Current machine state information
class MachineState extends Equatable {
  final String state; // e.g., "Idle", "Run", "Jog", "Alarm"
  final Position? workPosition;
  final Position? machinePosition;
  final double? feedRate;
  final double? spindleSpeed;
  final List<String> activeModalCodes;
  final DateTime lastUpdated;
  
  const MachineState({
    required this.state,
    this.workPosition,
    this.machinePosition,
    this.feedRate,
    this.spindleSpeed,
    this.activeModalCodes = const [],
    required this.lastUpdated,
  });
  
  @override
  List<Object?> get props => [
    state,
    workPosition,
    machinePosition,
    feedRate,
    spindleSpeed,
    activeModalCodes,
    lastUpdated,
  ];
}

/// 3D position information
class Position extends Equatable {
  final double x;
  final double y;
  final double z;
  
  const Position({
    required this.x,
    required this.y,
    required this.z,
  });
  
  @override
  List<Object?> get props => [x, y, z];
  
  @override
  String toString() => '($x, $y, $z)';
}

