import 'package:equatable/equatable.dart';

/// Base class for all connection states
abstract class CncConnectionState extends Equatable {
  const CncConnectionState();

  @override
  List<Object?> get props => [];
}

/// Initial state when app starts
class CncConnectionInitial extends CncConnectionState {
  const CncConnectionInitial();

  @override
  String toString() => 'ConnectionInitial';
}

/// State when attempting to connect to CNC router
class CncConnectionConnecting extends CncConnectionState {
  const CncConnectionConnecting();

  @override
  String toString() => 'ConnectionConnecting';
}

/// State when successfully connected to CNC router
class CncConnectionConnected extends CncConnectionState {
  const CncConnectionConnected({
    required this.statusMessage,
    this.deviceInfo,
    this.connectedAt,
  });

  final String statusMessage;
  final String? deviceInfo;
  final DateTime? connectedAt;

  @override
  List<Object?> get props => [statusMessage, deviceInfo, connectedAt];

  @override
  String toString() =>
      'ConnectionConnected { statusMessage: $statusMessage, deviceInfo: $deviceInfo, connectedAt: $connectedAt }';
}

/// State when disconnected from CNC router
class CncConnectionDisconnected extends CncConnectionState {
  const CncConnectionDisconnected({
    required this.statusMessage,
    this.reason,
    this.disconnectedAt,
  });

  final String statusMessage;
  final String? reason;
  final DateTime? disconnectedAt;

  @override
  List<Object?> get props => [statusMessage, reason, disconnectedAt];

  @override
  String toString() =>
      'ConnectionDisconnected { statusMessage: $statusMessage, reason: $reason, disconnectedAt: $disconnectedAt }';
}

/// State when connection failed or encountered an error
class CncConnectionError extends CncConnectionState {
  const CncConnectionError({
    required this.errorMessage,
    required this.statusMessage,
    this.errorCode,
    this.stackTrace,
  });

  final String errorMessage;
  final String statusMessage;
  final String? errorCode;
  final StackTrace? stackTrace;

  @override
  List<Object?> get props => [
    errorMessage,
    statusMessage,
    errorCode,
    stackTrace,
  ];

  @override
  String toString() =>
      'ConnectionError { errorMessage: $errorMessage, statusMessage: $statusMessage, errorCode: $errorCode }';
}
