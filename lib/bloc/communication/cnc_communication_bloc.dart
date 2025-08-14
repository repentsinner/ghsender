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
  
  // Message stream for real-time communication
  StreamController<CncMessage>? _messageStreamController;

  // Connection state
  bool _isConnected = false;
  String _currentUrl = '';
  DateTime? _connectedAt;

  // Simple command tracking for basic functionality
  int _commandIdCounter = 0;

  CncCommunicationBloc() : super(const CncCommunicationInitial()) {
    AppLogger.commInfo('CNC Communication BLoC initialized (lightweight version)');
    
    // Initialize message stream for real-time communication
    _messageStreamController = StreamController<CncMessage>.broadcast();

    on<CncCommunicationConnectRequested>(_onConnectRequested);
    on<CncCommunicationDisconnectRequested>(_onDisconnectRequested);
    on<CncCommunicationSendCommand>(_onSendCommand);
    on<CncCommunicationSendRawBytes>(_onSendRawBytes);
    on<CncCommunicationStatusChanged>(_onStatusChanged);
    on<CncCommunicationSetControllerAddress>(_onSetControllerAddress);
  }

  /// Stream of messages received from CNC controller
  /// Use this for real-time message processing instead of events
  Stream<CncMessage> get messageStream => _messageStreamController?.stream ?? const Stream.empty();


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
    
    _sendCommand(event.command, commandId);
    
    // Emit sent command to message stream
    _messageStreamController?.add(CncMessage(
      content: 'Sent: ${event.command}',
      timestamp: DateTime.now(),
      type: CncMessageType.other,
    ));
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
    
    _sendRawBytes(event.bytes);
    
    // Emit sent raw bytes to message stream
    _messageStreamController?.add(CncMessage(
      content: 'Sent raw: $bytesHex',
      timestamp: DateTime.now(),
      type: CncMessageType.other,
    ));
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
      emit(
        CncCommunicationConnected(
          url: _currentUrl,
          statusMessage: event.statusMessage,
          deviceInfo: event.deviceInfo,
          connectedAt: _connectedAt ?? DateTime.now(),
        ),
      );
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

  // Removed pointless _onMessageReceived - using streams instead

  /// Process incoming message from WebSocket
  void _onMessage(String message, DateTime timestamp) {
    if (message.isEmpty) return;

    // Debug logging for all messages during connection handshake
    AppLogger.commDebug('Received: $message');
    
    // Determine message type for efficient processing
    final messageType = _determineMessageType(message);
    
    // Emit to message stream for real-time processing
    _messageStreamController?.add(CncMessage(
      content: message,
      timestamp: timestamp,
      type: messageType,
    ));
  }

  /// Determine the type of message for efficient processing
  CncMessageType _determineMessageType(String message) {
    final trimmed = message.trim();
    
    if (trimmed.startsWith('<') && trimmed.endsWith('>')) {
      return CncMessageType.status;
    } else if (trimmed.startsWith(r'$') && trimmed.contains('=')) {
      return CncMessageType.configuration;
    } else if (trimmed.toLowerCase().contains('grbl') || 
               trimmed.toLowerCase().contains('welcome') ||
               trimmed.contains('[') && trimmed.contains(']')) {
      return CncMessageType.welcome;
    } else if (trimmed == 'ok') {
      return CncMessageType.acknowledgment;
    } else if (trimmed.startsWith('error:')) {
      return CncMessageType.error;
    } else {
      return CncMessageType.other;
    }
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

      // Minimal command logging
      if (command != '?' && command != r'$') {
        AppLogger.commDebug('Sent: "$command"');
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

      // Minimal raw bytes logging
      if (bytes.isNotEmpty && bytes[0] != 0x84) { // Don't log auto-reporting setup
        final bytesHex = bytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ');
        AppLogger.commDebug('Sent raw: $bytesHex');
      }
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
    
    // Reset command counter
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
      _ => 'Unknown state',
    };
  }

  /// Get device information if connected
  String? get deviceInfo {
    return switch (state) {
      CncCommunicationConnected(:final deviceInfo) => deviceInfo,
      _ => null,
    };
  }


  @override
  void onTransition(
    Transition<CncCommunicationEvent, CncCommunicationState> transition,
  ) {
    super.onTransition(transition);
    // Reduced transition logging - only log important state changes
    final fromType = transition.currentState.runtimeType.toString();
    final toType = transition.nextState.runtimeType.toString();
    if (fromType != toType) {
      AppLogger.commDebug('Communication: $fromType -> $toType');
    }
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    super.onError(error, stackTrace);
    AppLogger.commError('CommunicationBloc error', error, stackTrace);
  }

  @override
  Future<void> close() {
    AppLogger.commDebug('CncCommunicationBloc closing, performing final cleanup');
    
    // Close message stream
    _messageStreamController?.close();
    _messageStreamController = null;
    
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
