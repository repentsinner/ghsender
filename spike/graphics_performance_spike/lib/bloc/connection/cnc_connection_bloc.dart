import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/logger.dart';
import 'cnc_connection_event.dart';
import 'cnc_connection_state.dart';

/// BLoC for managing CNC router connection state
class CncConnectionBloc extends Bloc<CncConnectionEvent, CncConnectionState> {
  CncConnectionBloc() : super(const CncConnectionInitial()) {
    on<CncConnectionConnectRequested>(_onConnectRequested);
    on<CncConnectionDisconnectRequested>(_onDisconnectRequested);
    on<CncConnectionStatusChanged>(_onStatusChanged);
  }

  /// Handle connection request from user
  Future<void> _onConnectRequested(
    CncConnectionConnectRequested event,
    Emitter<CncConnectionState> emit,
  ) async {
    AppLogger.info('Connection requested by user');
    emit(const CncConnectionConnecting());

    try {
      // Simulate connection process (replace with actual CNC communication)
      await Future.delayed(const Duration(milliseconds: 1500));

      // For now, simulate successful connection
      // In real implementation, this would attempt actual CNC communication
      const statusMessage = 'Connected to CNC Router';
      const deviceInfo = 'GRBL v1.1f (Simulated)';
      final connectedAt = DateTime.now();

      AppLogger.info('Successfully connected to CNC router');
      emit(
        CncConnectionConnected(
          statusMessage: statusMessage,
          deviceInfo: deviceInfo,
          connectedAt: connectedAt,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed to connect to CNC router', error, stackTrace);
      emit(
        CncConnectionError(
          errorMessage: 'Connection failed: ${error.toString()}',
          statusMessage: 'Connection Failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Handle disconnection request from user
  Future<void> _onDisconnectRequested(
    CncConnectionDisconnectRequested event,
    Emitter<CncConnectionState> emit,
  ) async {
    AppLogger.info('Disconnection requested by user');

    try {
      // Simulate disconnection process (replace with actual CNC communication cleanup)
      await Future.delayed(const Duration(milliseconds: 500));

      const statusMessage = 'Disconnected';
      const reason = 'User requested disconnection';
      final disconnectedAt = DateTime.now();

      AppLogger.info('Successfully disconnected from CNC router');
      emit(
        CncConnectionDisconnected(
          statusMessage: statusMessage,
          reason: reason,
          disconnectedAt: disconnectedAt,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error('Error during disconnection', error, stackTrace);
      emit(
        CncConnectionError(
          errorMessage: 'Disconnection error: ${error.toString()}',
          statusMessage: 'Disconnection Error',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Handle external status changes (e.g., from communication layer)
  Future<void> _onStatusChanged(
    CncConnectionStatusChanged event,
    Emitter<CncConnectionState> emit,
  ) async {
    AppLogger.info(
      'Connection status changed externally: ${event.statusMessage}',
    );

    if (event.isConnected) {
      emit(
        CncConnectionConnected(
          statusMessage: event.statusMessage,
          deviceInfo: event.deviceInfo,
          connectedAt: DateTime.now(),
        ),
      );
    } else {
      emit(
        CncConnectionDisconnected(
          statusMessage: event.statusMessage,
          reason: 'External status change',
          disconnectedAt: DateTime.now(),
        ),
      );
    }
  }

  /// Get current connection status as boolean
  bool get isConnected => state is CncConnectionConnected;

  /// Get current status message for display
  String get statusMessage {
    return switch (state) {
      CncConnectionInitial() => 'Not connected',
      CncConnectionConnecting() => 'Connecting...',
      CncConnectionConnected(statusMessage: final message) => message,
      CncConnectionDisconnected(statusMessage: final message) => message,
      CncConnectionError(statusMessage: final message) => message,
      _ => 'Unknown state',
    };
  }

  /// Get device information if connected
  String? get deviceInfo {
    return switch (state) {
      CncConnectionConnected(deviceInfo: final info) => info,
      _ => null,
    };
  }

  @override
  void onTransition(
    Transition<CncConnectionEvent, CncConnectionState> transition,
  ) {
    super.onTransition(transition);
    AppLogger.debug(
      'ConnectionBloc transition: ${transition.currentState} -> ${transition.nextState}',
    );
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    super.onError(error, stackTrace);
    AppLogger.error('ConnectionBloc error', error, stackTrace);
  }
}
