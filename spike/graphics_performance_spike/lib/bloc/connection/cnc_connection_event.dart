import 'package:equatable/equatable.dart';

/// Base class for all connection events
abstract class CncConnectionEvent extends Equatable {
  const CncConnectionEvent();

  @override
  List<Object?> get props => [];
}

/// Event triggered when user requests to connect to CNC router
class CncConnectionConnectRequested extends CncConnectionEvent {
  const CncConnectionConnectRequested();

  @override
  String toString() => 'ConnectionConnectRequested';
}

/// Event triggered when user requests to disconnect from CNC router
class CncConnectionDisconnectRequested extends CncConnectionEvent {
  const CncConnectionDisconnectRequested();

  @override
  String toString() => 'ConnectionDisconnectRequested';
}

/// Event triggered when connection status changes externally
class CncConnectionStatusChanged extends CncConnectionEvent {
  const CncConnectionStatusChanged({
    required this.isConnected,
    required this.statusMessage,
    this.deviceInfo,
  });

  final bool isConnected;
  final String statusMessage;
  final String? deviceInfo;

  @override
  List<Object?> get props => [isConnected, statusMessage, deviceInfo];

  @override
  String toString() =>
      'ConnectionStatusChanged { isConnected: $isConnected, statusMessage: $statusMessage, deviceInfo: $deviceInfo }';
}
