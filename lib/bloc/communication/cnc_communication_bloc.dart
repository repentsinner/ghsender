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

  // Message reassembly buffer for fragmented WebSocket responses
  String _messageBuffer = '';
  bool _expectingMultilineResponse = false;

  // Status polling state
  Timer? _statusPollingTimer;
  // 125Hz polling rate (8ms interval) is well within grblHAL and WebSocket
  // capability, and should be within most sender host capabilities
  final int _pollingIntervalMs = 8;
  List<int> _pollingCommand = [0x80]; // grblHAL preferred status request
  
  // Status rate tracking
  final List<DateTime> _statusMessageTimestamps = [];
  int _totalStatusMessages = 0;
  DateTime? _statusTrackingStartTime;
  PerformanceData? _currentPerformanceData;

  CncCommunicationBloc() : super(const CncCommunicationInitial()) {
    AppLogger.commInfo(
      'CNC Communication BLoC initialized (lightweight version)',
    );

    // Initialize message stream for real-time communication
    _messageStreamController = StreamController<CncMessage>.broadcast();

    on<CncCommunicationConnectRequested>(_onConnectRequested);
    on<CncCommunicationDisconnectRequested>(_onDisconnectRequested);
    on<CncCommunicationSendCommand>(_onSendCommand);
    on<CncCommunicationSendRawBytes>(_onSendRawBytes);
    on<CncCommunicationStatusChanged>(_onStatusChanged);
    on<CncCommunicationSetControllerAddress>(_onSetControllerAddress);
    on<CncCommunicationPollingControlRequested>(_onPollingControlRequested);
    on<CncCommunicationPerformanceDataUpdated>(_onPerformanceDataUpdated);
  }

  /// Stream of messages received from CNC controller
  /// Use this for real-time message processing instead of events
  Stream<CncMessage> get messageStream =>
      _messageStreamController?.stream ?? const Stream.empty();

  /// Handle connection request
  Future<void> _onConnectRequested(
    CncCommunicationConnectRequested event,
    Emitter<CncCommunicationState> emit,
  ) async {
    AppLogger.commInfo('WebSocket connection requested to ${event.url}');

    // Ensure clean state before attempting connection
    if (_webSocketChannel != null || _isConnected) {
      AppLogger.commWarning(
        'Previous connection detected, performing cleanup before reconnect',
      );
      _cleanup();
    }

    emit(const CncCommunicationConnecting());

    try {
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

      emit(const CncCommunicationConnecting());

      // Test connection with a single status request after WebSocket is established
      AppLogger.commInfo('Testing WebSocket connection with status request');

      // Note: Heartbeat mechanism removed for simplicity

      // Set up WebSocket stream listener for message processing
      _webSocketSubscription = _webSocketChannel!.stream.listen(
        (data) {
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
    AppLogger.commDebug('_onSendCommand called with: "${event.command}"');
    
    if (!_isConnected || _webSocketChannel == null) {
      AppLogger.commWarning('Cannot send command - not connected (isConnected: $_isConnected, channel: ${_webSocketChannel != null})');
      return;
    }

    final commandId = ++_commandIdCounter;
    AppLogger.commDebug('Calling _sendCommand with: "${event.command}", id: $commandId');

    _sendCommand(event.command, commandId);

    _messageStreamController?.add(
      CncMessage(
        content: 'Sent: ${event.command}',
        timestamp: DateTime.now(),
        type: CncMessageType.other,
      ),
    );
  }

  /// Handle raw bytes sending (for real-time commands like status polling)
  void _onSendRawBytes(
    CncCommunicationSendRawBytes event,
    Emitter<CncCommunicationState> emit,
  ) {
    if (!_isConnected || _webSocketChannel == null) {
      AppLogger.commWarning('Cannot send raw bytes - not connected');
      return;
    }

    final bytesHex = event.bytes
        .map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}')
        .join(' ');

    _sendRawBytes(event.bytes);

    _messageStreamController?.add(
      CncMessage(
        content: 'Sent raw: $bytesHex',
        timestamp: DateTime.now(),
        type: CncMessageType.other,
      ),
    );
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

  /// Handle polling control requests
  void _onPollingControlRequested(
    CncCommunicationPollingControlRequested event,
    Emitter<CncCommunicationState> emit,
  ) {
    if (event.enable) {
      _startPolling(
        rawCommand: event.rawCommand,
        stringCommand: event.stringCommand,
      );
    } else {
      _stopPolling();
    }
  }

  // Removed pointless _onMessageReceived - using streams instead

  /// Process incoming message from WebSocket with reassembly support
  void _onMessage(String rawMessage, DateTime timestamp) {
    if (rawMessage.isEmpty) return;


    // If we're not expecting a multiline response, process immediately
    // This handles individual setting queries like $130, $131, etc.
    if (!_expectingMultilineResponse) {
      _processCompleteMessage(rawMessage, timestamp);
      return;
    }

    // Handle message reassembly for fragmented bulk responses ($ command)
    _messageBuffer += rawMessage;
    
    // Check if this completes a multi-line response (ends with "ok\r\n" or "ok\n")
    final isComplete = _messageBuffer.contains(RegExp(r'ok\s*\r?\n?\s*$'));
    
    if (!isComplete) {
      // Still expecting more fragments, don't process yet
      return;
    }
    
    // Process the complete reassembled bulk response
    final messageToProcess = _messageBuffer;
    _messageBuffer = '';
    _expectingMultilineResponse = false;
    
    AppLogger.commInfo('🔍 PROCESSING COMPLETE REASSEMBLED BULK MESSAGE: "${messageToProcess.substring(0, 100)}${messageToProcess.length > 100 ? '...' : ''}"');

    // Process complete message - interpret newlines correctly for framing
    _processCompleteMessage(messageToProcess, timestamp);
  }
  
  /// Process a complete reassembled message
  void _processCompleteMessage(String completeMessage, DateTime timestamp) {
    // Split on newlines to handle multi-line responses from grblHAL
    // grblHAL WebSocket wraps the underlying newline-based serial protocol
    final lines = completeMessage.split(RegExp(r'\r?\n'));

    for (final line in lines) {
      // Trim whitespace but preserve the logical message content
      final cleanedMessage = line.trim();
      if (cleanedMessage.isEmpty) continue; // Skip empty lines

      // Determine message type for efficient processing
      final messageType = _determineMessageType(cleanedMessage);
      
      // Track status messages for rate analysis
      if (messageType == CncMessageType.status) {
        _trackStatusMessage(timestamp);
      }

      _messageStreamController?.add(
        CncMessage(
          content: cleanedMessage,
          timestamp: timestamp,
          type: messageType,
        ),
      );
    }
  }

  /// Determine the type of message for efficient processing
  CncMessageType _determineMessageType(String message) {
    // Message is already cleaned in _onMessage, no need to trim again

    if (message.startsWith('<') && message.endsWith('>')) {
      return CncMessageType.status;
    } else if (message.startsWith(r'$') && message.contains('=')) {
      return CncMessageType.configuration;
    } else if (message.toLowerCase().contains('grbl') ||
        message.toLowerCase().contains('welcome')) {
      return CncMessageType.welcome;
    } else if (message == 'ok') {
      return CncMessageType.acknowledgment;
    } else if (message.startsWith('error:')) {
      return CncMessageType.error;
    } else {
      // Messages with [PLUGIN:...], [BOARD:...] etc. should be classified as 'other'
      // for processing by _processBuildInfoMessage
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
      // Set expectation flag for multi-line responses before sending
      if (command == r'$$') {
        _expectingMultilineResponse = true;
        _messageBuffer = ''; // Clear any existing buffer
        AppLogger.commInfo('🔍 SENT BULK CONFIG QUERY: "$command" - expecting fragmented multi-line response');
      }
      
      final commandWithNewline = '$command\r\n';
      _webSocketChannel!.sink.add(commandWithNewline);

      // Minimal command logging for non-bulk queries
      if (command != r'$$' && command != '?' && !command.startsWith(r'$J=')) {
        AppLogger.commDebug('Sent: "$command"');
      }
    } catch (e, stackTrace) {
      // Reset expectation on send failure
      if (command == r'$$') {
        _expectingMultilineResponse = false;
        _messageBuffer = '';
      }
      
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

  /// Send raw bytes to WebSocket (for real-time commands like status polling)
  void _sendRawBytes(List<int> bytes) {
    if (_webSocketChannel == null) {
      AppLogger.commWarning(
        'Cannot send raw bytes to WebSocket - not connected',
      );
      return;
    }

    try {
      // Send raw bytes directly without any line endings
      _webSocketChannel!.sink.add(bytes);

      // Minimal raw bytes logging
      if (bytes.isNotEmpty && bytes[0] != 0x84) {
      }
    } catch (e, stackTrace) {
      final bytesHex = bytes
          .map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}')
          .join(' ');
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

  /// Start status polling
  void _startPolling({List<int>? rawCommand, String? stringCommand}) {
    // Stop any existing polling
    _stopPolling();

    // Update polling configuration
    if (rawCommand != null) {
      _pollingCommand = rawCommand;
    } else if (stringCommand != null) {
      // Convert string command to bytes (will be sent as string)
      _pollingCommand = [];
    } else {
      // Use default 0x80 status request
      _pollingCommand = [0x80];
    }

    AppLogger.commInfo(
      'Starting status polling: ${_pollingIntervalMs}ms interval, command: ${rawCommand != null ? rawCommand.map((b) => '0x${b.toRadixString(16)}').join(' ') : stringCommand ?? '0x80'}',
    );

    // Start periodic timer
    _statusPollingTimer = Timer.periodic(
      Duration(milliseconds: _pollingIntervalMs),
      (_) => _sendPollingCommand(stringCommand),
    );
  }

  /// Stop status polling
  void _stopPolling() {
    if (_statusPollingTimer != null) {
      AppLogger.commInfo('Stopping status polling');
      _statusPollingTimer?.cancel();
      _statusPollingTimer = null;
    }
  }

  /// Send polling command
  void _sendPollingCommand(String? stringCommand) {
    if (!_isConnected || _webSocketChannel == null) {
      return;
    }

    if (stringCommand != null) {
      // Send string command
      _sendCommand(stringCommand, 0);
    } else {
      // Send raw bytes command
      _sendRawBytes(_pollingCommand);
    }
  }

  /// Track received status message for rate analysis
  void _trackStatusMessage(DateTime timestamp) {
    _totalStatusMessages++;
    
    // Initialize tracking on first status message
    _statusTrackingStartTime ??= timestamp;
    
    // Add timestamp to recent list
    _statusMessageTimestamps.add(timestamp);
    
    // Keep only last 2 seconds of timestamps for rate calculation
    final cutoffTime = timestamp.subtract(const Duration(seconds: 2));
    _statusMessageTimestamps.removeWhere((t) => t.isBefore(cutoffTime));
    
    // Update performance data every 10 messages (avoid constant recalculation)
    if (_totalStatusMessages % 10 == 0) {
      _updatePerformanceData(timestamp);
      // Trigger a state update to refresh UI
      add(CncCommunicationPerformanceDataUpdated(timestamp));
    }
  }
  
  /// Calculate expected status messages based on polling rate and duration
  int _calculateExpectedMessages(DateTime currentTime) {
    if (_statusTrackingStartTime == null) return 0;
    
    final duration = currentTime.difference(_statusTrackingStartTime!);
    final expectedRate = 1000 / _pollingIntervalMs; // Messages per second
    return (duration.inMilliseconds * expectedRate / 1000).round();
  }
  
  /// Update performance data with current status rate metrics
  void _updatePerformanceData(DateTime currentTime) {
    if (_statusMessageTimestamps.isEmpty) return;
    
    // Calculate status messages per second (based on last 2 seconds)
    final recentMessages = _statusMessageTimestamps.length;
    final timeSpan = _statusMessageTimestamps.isNotEmpty
        ? currentTime.difference(_statusMessageTimestamps.first).inMilliseconds / 1000.0
        : 1.0;
    final statusRate = recentMessages / timeSpan;
    
    // Calculate expected messages and drop rate
    final expectedMessages = _calculateExpectedMessages(currentTime);
    final dropRate = expectedMessages > 0 
        ? ((expectedMessages - _totalStatusMessages) / expectedMessages * 100.0).clamp(0.0, 100.0)
        : 0.0;
    
    _currentPerformanceData = PerformanceData(
      messagesPerSecond: statusRate.round(),
      averageLatencyMs: 0.0, // Not tracking latency in this implementation
      maxLatencyMs: 0.0,
      totalMessages: _totalStatusMessages,
      droppedMessages: (expectedMessages - _totalStatusMessages).clamp(0, expectedMessages),
      recentLatencies: const [],
      statusMessagesPerSecond: statusRate,
      totalStatusMessages: _totalStatusMessages,
      expectedStatusMessages: expectedMessages,
      statusMessageDropRate: dropRate,
      recentStatusTimestamps: List.from(_statusMessageTimestamps),
    );
    
  }
  
  /// Get current performance data
  PerformanceData? get performanceData => _currentPerformanceData;

  /// Handle performance data update events
  void _onPerformanceDataUpdated(
    CncCommunicationPerformanceDataUpdated event,
    Emitter<CncCommunicationState> emit,
  ) {
    // Emit updated state to trigger UI rebuild
    if (_isConnected && state is CncCommunicationConnected) {
      final currentState = state as CncCommunicationConnected;
      emit(CncCommunicationConnectedWithPerformance(
        url: currentState.url,
        statusMessage: currentState.statusMessage,
        deviceInfo: currentState.deviceInfo,
        connectedAt: currentState.connectedAt,
        performanceData: _currentPerformanceData,
      ));
    }
  }

  /// Clean up timers and subscriptions
  void _cleanup() {
    AppLogger.commDebug('Starting cleanup of communication resources');

    // Stop polling
    _stopPolling();

    // Cancel and clear all timers and subscriptions
    _webSocketSubscription?.cancel();
    _webSocketSubscription = null;

    // Reset connection state variables
    _isConnected = false;
    _currentUrl = '';
    _connectedAt = null;

    // Reset command counter
    _commandIdCounter = 0;
    
    // Reset message reassembly state
    _messageBuffer = '';
    _expectingMultilineResponse = false;
    
    // Reset status tracking
    _statusMessageTimestamps.clear();
    _totalStatusMessages = 0;
    _statusTrackingStartTime = null;
    _currentPerformanceData = null;

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
    AppLogger.commDebug(
      'CncCommunicationBloc closing, performing final cleanup',
    );

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
