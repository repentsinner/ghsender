import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../../utils/logger.dart';
import 'cnc_communication_event.dart';
import 'cnc_communication_state.dart';

/// Lightweight CNC communication BLoC with WebSocket support
///
/// This BLoC provides basic WebSocket communication to GRBL/grblHAL controllers:
/// - Real-time bidirectional communication
/// - Connection management and validation
/// - Raw message passing to MachineControllerBloc
/// - Minimal state tracking focused on connection status
class CncCommunicationBloc
    extends Bloc<CncCommunicationEvent, CncCommunicationState> {
  // WebSocket communication
  WebSocketChannel? _webSocketChannel;
  StreamSubscription? _webSocketSubscription;

  // Connection state
  bool _isConnected = false;
  String _currentUrl = '';
  DateTime? _connectedAt;
  final List<String> _messages = [];

  // Simple command tracking for basic functionality
  int _commandIdCounter = 0;

  CncCommunicationBloc() : super(const CncCommunicationInitial()) {
    AppLogger.commInfo('CNC Communication BLoC initialized (lightweight version)');

    on<CncCommunicationConnectRequested>(_onConnectRequested);
    on<CncCommunicationDisconnectRequested>(_onDisconnectRequested);
    on<CncCommunicationSendCommand>(_onSendCommand);
    on<CncCommunicationSendRawBytes>(_onSendRawBytes);
    on<CncCommunicationStatusChanged>(_onStatusChanged);
    on<CncCommunicationSetControllerAddress>(_onSetControllerAddress);
  }


  /// Handle connection request
  Future<void> _onConnectRequested(
    CncCommunicationConnectRequested event,
    Emitter<CncCommunicationState> emit,
  ) async {
    AppLogger.commInfo('WebSocket connection requested to ${event.url}');
    
    // Ensure clean state before attempting connection
    if (_webSocketChannel != null || _isConnected) {
      AppLogger.commWarning('Previous connection detected, performing cleanup before reconnect');
      _cleanup();
    }
    
    emit(const CncCommunicationConnecting());

    try {
      // Parse and log the URI for debugging
      final uri = Uri.parse(event.url);
      AppLogger.commInfo(
        'Parsed URI: $uri (host: ${uri.host}, port: ${uri.port}, scheme: ${uri.scheme})',
      );

      // Connect to WebSocket
      AppLogger.commInfo('Creating WebSocket connection...');
      _webSocketChannel = WebSocketChannel.connect(uri);

      // Don't immediately mark as connected - wait for actual WebSocket upgrade success
      _currentUrl = event.url;
      _connectedAt = DateTime.now();
      _messages.clear();
      _messages.add('Attempting WebSocket connection to: ${event.url}');

      AppLogger.commInfo(
        'WebSocket connection initiated, waiting for handshake completion...',
      );

      // Emit connecting state initially
      emit(const CncCommunicationConnecting());

      // Test connection with a single status request after WebSocket is established
      AppLogger.commInfo('Testing WebSocket connection with status request');

      // Note: Heartbeat mechanism removed for simplicity

      // Set up WebSocket stream listener for message processing
      _webSocketSubscription = _webSocketChannel!.stream.listen(
        (data) {
          // Process incoming message (no debug logging to avoid 60Hz spam)
          _onMessage(data.toString(), DateTime.now());
        },
        onError: (error) {
          AppLogger.commError(
            'WebSocket stream error: $error (type: ${error.runtimeType})',
            error,
          );
          _isConnected = false;

          if (!emit.isDone) {
            emit(
              CncCommunicationError(
                errorMessage: 'WebSocket connection lost: $error',
                statusMessage: 'Connection Lost',
                error: error,
              ),
            );
          }
        },
        onDone: () {
          AppLogger.commInfo('WebSocket stream closed (onDone callback)');
          _isConnected = false;

          if (!emit.isDone) {
            emit(
              const CncCommunicationDisconnected(
                statusMessage: 'Disconnected',
                reason: 'WebSocket stream closed',
              ),
            );
          }
        },
      );

      // WebSocket connection established successfully
      _isConnected = true;
      _messages.add('Connected to WebSocket: ${event.url}');
      
      AppLogger.commInfo('WebSocket connection established successfully');
      emit(
        CncCommunicationConnected(
          url: event.url,
          statusMessage: 'Connected to CNC Controller',
          deviceInfo: 'GRBL/grblHAL via WebSocket',
          connectedAt: _connectedAt!,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.commError('Failed to connect WebSocket', error, stackTrace);
      emit(
        CncCommunicationError(
          errorMessage: 'Failed to connect: ${error.toString()}',
          statusMessage: 'Connection Failed',
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Handle disconnection request
  Future<void> _onDisconnectRequested(
    CncCommunicationDisconnectRequested event,
    Emitter<CncCommunicationState> emit,
  ) async {
    AppLogger.commInfo('Disconnection requested by user');

    try {
      // Force close WebSocket connection with proper cleanup
      if (_webSocketChannel != null) {
        AppLogger.commDebug('Closing WebSocket connection');
        
        // Cancel subscription first to prevent stream events during close
        _webSocketSubscription?.cancel();
        _webSocketSubscription = null;
        
        // Close the WebSocket with normal closure status code
        try {
          await _webSocketChannel!.sink.close(status.normalClosure);
        } catch (e) {
          AppLogger.commWarning('WebSocket close failed, forcing cleanup: $e');
        }
        
        _webSocketChannel = null;
        AppLogger.commDebug('WebSocket connection closed and nullified');
      }

      // Perform comprehensive cleanup
      _cleanup();

      AppLogger.commInfo('Successfully disconnected from CNC controller');
      emit(
        CncCommunicationDisconnected(
          statusMessage: 'Disconnected',
          reason: 'User requested disconnection',
          disconnectedAt: DateTime.now(),
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.commError('Error during disconnection', error, stackTrace);
      
      // Even if disconnection fails, force cleanup to allow reconnection
      _cleanup();
      
      emit(
        CncCommunicationError(
          errorMessage: 'Disconnection error: ${error.toString()}',
          statusMessage: 'Disconnection Error',
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Handle command sending
  void _onSendCommand(
    CncCommunicationSendCommand event,
    Emitter<CncCommunicationState> emit,
  ) {
    if (!_isConnected || _webSocketChannel == null) {
      AppLogger.commWarning('Cannot send command - not connected');
      return;
    }

    final commandId = ++_commandIdCounter;
    
    // Only log non-status queries to avoid flooding logs
    if (event.command != '?') {
      AppLogger.commInfo('Sending command $commandId: "${event.command}"');
    }

    _sendCommand(event.command, commandId);
    _messages.add('Sent: ${event.command}');
    _emitDataState(emit);
  }

  /// Handle raw bytes sending (for real-time commands like grblHAL auto-reporting)
  void _onSendRawBytes(
    CncCommunicationSendRawBytes event,
    Emitter<CncCommunicationState> emit,
  ) {
    if (!_isConnected || _webSocketChannel == null) {
      AppLogger.commWarning('Cannot send raw bytes - not connected');
      return;
    }

    final bytesHex = event.bytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ');
    AppLogger.commInfo('Sending raw bytes: $bytesHex');

    _sendRawBytes(event.bytes);
    _messages.add('Sent raw: $bytesHex');
    _emitDataState(emit);
  }


  /// Handle external status changes
  Future<void> _onStatusChanged(
    CncCommunicationStatusChanged event,
    Emitter<CncCommunicationState> emit,
  ) async {
    AppLogger.commInfo(
      'Connection status changed externally: ${event.statusMessage}',
    );

    if (event.isConnected) {
      // Check if we have data to emit as a WithData state
      if (_isConnected && _connectedAt != null && _messages.isNotEmpty) {
        _emitDataState(emit);
      } else {
        emit(
          CncCommunicationConnected(
            url: _currentUrl,
            statusMessage: event.statusMessage,
            deviceInfo: event.deviceInfo,
            connectedAt: _connectedAt ?? DateTime.now(),
          ),
        );
      }
    } else {
      emit(
        CncCommunicationDisconnected(
          statusMessage: event.statusMessage,
          reason: 'External status change',
          disconnectedAt: DateTime.now(),
        ),
      );
    }
  }

  /// Set controller address from machine profile
  Future<void> _onSetControllerAddress(
    CncCommunicationSetControllerAddress event,
    Emitter<CncCommunicationState> emit,
  ) async {
    AppLogger.info(
      'Setting CNC controller address: ${event.controllerAddress}',
    );

    emit(
      CncCommunicationAddressConfigured(
        controllerAddress: event.controllerAddress,
        configuredAt: DateTime.now(),
      ),
    );

    AppLogger.info('Controller address configured successfully');
  }

  /// Process incoming message from WebSocket
  void _onMessage(String message, DateTime timestamp) {
    if (message.isEmpty) return;

    // Only log non-status messages to avoid flooding with 60Hz updates
    if (!message.startsWith('<') && message.trim() != 'ok') {
      AppLogger.commDebug('Received: $message');
    }
    
    _messages.add('Received: $message');

    // Keep message history manageable (more aggressive with 60Hz updates)
    if (_messages.length > 500) {
      _messages.removeRange(0, 200);
    }

    // Extract basic machine state from status messages (simple parsing only)
    _extractBasicMachineState(message, timestamp);
  }


  /// Extract basic machine state from GRBL status messages (simple parsing only)
  /// Detailed parsing is handled by MachineControllerBloc
  void _extractBasicMachineState(String message, DateTime timestamp) {
    // Note: Machine state tracking moved to MachineControllerBloc
    // This method is kept minimal for potential future use
    if (!message.startsWith('<')) return;

    // Basic validation only - detailed parsing handled by MachineControllerBloc
    final stateMatch = RegExp(r'<([^|]+)').firstMatch(message);
    if (stateMatch == null) return;

    // No local state storage needed - MachineControllerBloc handles all parsing
  }

  /// Send command to WebSocket
  void _sendCommand(String command, int commandId) {
    if (_webSocketChannel == null) {
      AppLogger.commWarning('Cannot send WebSocket command - not connected');
      return;
    }

    try {
      final commandWithNewline = '$command\r\n';
      _webSocketChannel!.sink.add(commandWithNewline);

      // Only log non-status commands to reduce noise
      if (command != '?') {
        AppLogger.commDebug('WebSocket sent command: "$command"');
      }
    } catch (e, stackTrace) {
      AppLogger.commError(
        'Error sending WebSocket command "$command"',
        e,
        stackTrace,
      );

      // If command sending fails, this indicates the connection is broken
      if (_isConnected) {
        AppLogger.commError(
          'WebSocket connection appears broken, marking as disconnected',
        );
        _isConnected = false;
        // The stream listener should handle the disconnection
      }
    }
  }

  /// Send raw bytes to WebSocket (for real-time commands like grblHAL auto-reporting)
  void _sendRawBytes(List<int> bytes) {
    if (_webSocketChannel == null) {
      AppLogger.commWarning('Cannot send raw bytes to WebSocket - not connected');
      return;
    }

    try {
      // Send raw bytes directly without any line endings
      _webSocketChannel!.sink.add(bytes);

      final bytesHex = bytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ');
      AppLogger.commDebug('WebSocket sent raw bytes: $bytesHex');
    } catch (e, stackTrace) {
      final bytesHex = bytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ');
      AppLogger.commError(
        'Error sending WebSocket raw bytes [$bytesHex]',
        e,
        stackTrace,
      );

      // If raw byte sending fails, this indicates the connection is broken
      if (_isConnected) {
        AppLogger.commError(
          'WebSocket connection appears broken, marking as disconnected',
        );
        _isConnected = false;
        // The stream listener should handle the disconnection
      }
    }
  }



  /// Emit current data state
  /// Note: This method can only be called from within an active event handler context
  void _emitDataState(Emitter<CncCommunicationState> emit) {
    if (_isConnected && _connectedAt != null && !emit.isDone) {
      emit(
        CncCommunicationWithData(
          url: _currentUrl,
          messages: List.from(_messages),
          isConnected: _isConnected,
          connectedAt: _connectedAt!,
        ),
      );
    }
  }

  /// Clean up timers and subscriptions
  void _cleanup() {
    AppLogger.commDebug('Starting cleanup of communication resources');
    
    // Cancel and clear all timers and subscriptions
    _webSocketSubscription?.cancel();
    _webSocketSubscription = null;
    
    // Reset connection state variables
    _isConnected = false;
    _currentUrl = '';
    _connectedAt = null;
    
    // Clear message data
    _messages.clear();
    _commandIdCounter = 0;
    
    AppLogger.commDebug('Cleanup completed - all state reset for reconnection');
  }

  /// Get current connection status
  bool get isConnected => _isConnected;

  /// Get current status message for display
  String get statusMessage {
    return switch (state) {
      CncCommunicationInitial() => 'Not connected',
      CncCommunicationConnecting() => 'Connecting...',
      CncCommunicationConnected(:final statusMessage) => statusMessage,
      CncCommunicationDisconnected(:final statusMessage) => statusMessage,
      CncCommunicationError(:final statusMessage) => statusMessage,
      CncCommunicationWithData() => 'Connected to $_currentUrl',
      _ => 'Unknown state',
    };
  }

  /// Get device information if connected
  String? get deviceInfo {
    return switch (state) {
      CncCommunicationConnected(:final deviceInfo) => deviceInfo,
      CncCommunicationWithData() => 'GRBL/grblHAL via WebSocket',
      _ => null,
    };
  }


  @override
  void onTransition(
    Transition<CncCommunicationEvent, CncCommunicationState> transition,
  ) {
    super.onTransition(transition);
    AppLogger.commDebug(
      'CommunicationBloc transition: ${transition.currentState} -> ${transition.nextState}',
    );
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    super.onError(error, stackTrace);
    AppLogger.commError('CommunicationBloc error', error, stackTrace);
  }

  @override
  Future<void> close() {
    AppLogger.commDebug('CncCommunicationBloc closing, performing final cleanup');
    
    // Force close WebSocket if still connected
    if (_webSocketChannel != null) {
      try {
        _webSocketChannel!.sink.close(status.normalClosure);
      } catch (e) {
        AppLogger.commDebug('Error closing WebSocket during BLoC close: $e');
      }
      _webSocketChannel = null;
    }
    
    // Perform comprehensive cleanup
    _cleanup();
    
    AppLogger.commDebug('CncCommunicationBloc cleanup completed');
    return super.close();
  }
}
