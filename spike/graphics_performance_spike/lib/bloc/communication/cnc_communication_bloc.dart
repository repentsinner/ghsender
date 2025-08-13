import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../../utils/logger.dart';
import 'cnc_communication_event.dart';
import 'cnc_communication_state.dart';

/// Enhanced CNC communication BLoC with full WebSocket support
///
/// This BLoC replaces the basic simulated connection with real WebSocket
/// communication to GRBL/grblHAL controllers. It provides:
/// - Real-time bidirectional communication
/// - Performance monitoring and latency tracking
/// - Machine state monitoring
/// - Automated jog testing capabilities
/// - UI responsiveness monitoring
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

  // Performance monitoring
  PerformanceData? _currentPerformanceData;
  final Map<int, DateTime> _pendingCommands = {};
  final Map<int, String> _pendingCommandTypes = {};
  final List<double> _latencies = [];
  int _commandIdCounter = 0;

  // Machine state tracking
  MachineState? _currentMachineState;
  String _lastRawMachineState = '';

  // Jog testing
  bool _jogTestRunning = false;
  DateTime? _jogTestStartTime;
  int _jogTestDurationSeconds = 0;
  int _jogCount = 0;
  double _jogDistance = 0.0;
  int _jogFeedRate = 0;
  DateTime? _jogStartTime;
  final List<String> _stateTransitions = [];

  // Timers for periodic operations
  Timer? _heartbeatTimer;
  Timer? _jogPollTimer;
  Timer? _uiPerformanceTimer;

  // UI performance monitoring
  final List<double> _uiFrameTimes = [];
  final Stopwatch _uiStopwatch = Stopwatch();

  // Track when data has been updated from message processing
  bool _hasDataUpdate = false;

  CncCommunicationBloc() : super(const CncCommunicationInitial()) {
    AppLogger.commInfo('CNC Communication BLoC initialized');

    on<CncCommunicationConnectRequested>(_onConnectRequested);
    on<CncCommunicationDisconnectRequested>(_onDisconnectRequested);
    on<CncCommunicationSendCommand>(_onSendCommand);
    on<CncCommunicationStartJogTest>(_onStartJogTest);
    on<CncCommunicationStopJogTest>(_onStopJogTest);
    on<CncCommunicationStatusChanged>(_onStatusChanged);
    on<CncCommunicationSetControllerAddress>(_onSetControllerAddress);

    _startUIPerformanceMonitoring();
  }

  /// Start monitoring UI thread responsiveness
  void _startUIPerformanceMonitoring() {
    _uiPerformanceTimer = Timer.periodic(const Duration(milliseconds: 16), (
      timer,
    ) {
      // Measure UI thread responsiveness by timing this callback
      if (_uiStopwatch.isRunning) {
        final frameTime = _uiStopwatch.elapsedMicroseconds / 1000.0;
        _uiFrameTimes.add(frameTime);

        // Keep only last 60 frames (1 second at 60fps)
        if (_uiFrameTimes.length > 60) {
          _uiFrameTimes.removeAt(0);
        }

        // Log UI jank if frame time exceeds 20ms (50fps threshold)
        if (frameTime > 20.0) {
          AppLogger.commWarning(
            'UI JANK detected: ${frameTime.toStringAsFixed(2)}ms frame time',
          );
        }
      }
      _uiStopwatch.reset();
      _uiStopwatch.start();
    });
  }

  /// Handle connection request
  Future<void> _onConnectRequested(
    CncCommunicationConnectRequested event,
    Emitter<CncCommunicationState> emit,
  ) async {
    AppLogger.commInfo('WebSocket connection requested to ${event.url}');
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

      // Stop any existing heartbeat to avoid interference with validation
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;

      // Set up connection validation with proper state management
      bool connectionValidated = false;
      bool connectionFailed = false;

      AppLogger.commInfo('Starting connection validation - heartbeat stopped');

      // Set up a timeout for the entire connection validation process
      final validationTimeout = Timer(const Duration(milliseconds: 2000), () {
        if (!connectionValidated && !connectionFailed) {
          AppLogger.commError(
            'WebSocket connection validation timeout - likely handshake failed',
          );
          connectionFailed = true;
          if (!emit.isDone) {
            emit(
              const CncCommunicationError(
                errorMessage:
                    'WebSocket connection timeout - controller may not support WebSocket protocol',
                statusMessage: 'Connection Timeout',
              ),
            );
          }
        }
      });

      // Set up temporary message handler to detect first successful communication
      _webSocketSubscription = _webSocketChannel!.stream.listen(
        (data) {
          AppLogger.commDebug(
            'Validation check: connectionValidated=$connectionValidated, connectionFailed=$connectionFailed',
          );

          if (!connectionValidated && !connectionFailed) {
            // First successful message received - connection is truly established
            connectionValidated = true;
            _isConnected = true;
            validationTimeout.cancel();

            AppLogger.commInfo(
              'WebSocket connection successfully established and validated',
            );
            _messages.add('Connected to WebSocket: ${event.url}');

            AppLogger.commDebug(
              'About to emit CncCommunicationConnected state',
            );
            if (!emit.isDone) {
              emit(
                CncCommunicationConnected(
                  url: event.url,
                  statusMessage: 'Connected to CNC Controller',
                  deviceInfo: 'GRBL/grblHAL via WebSocket',
                  connectedAt: _connectedAt!,
                ),
              );
              AppLogger.commDebug(
                'CncCommunicationConnected state emitted successfully',
              );
            } else {
              AppLogger.commError('Failed to emit state - emitter is done');
            }

            // Start heartbeat now that we're truly connected
            _startHeartbeat();
            AppLogger.commDebug('Heartbeat started after validation');

            // Remove the immediate _emitDataState call to avoid overriding the Connected state
            // _emitDataState(emit);
          }

          // Continue with normal message processing
          AppLogger.commDebug(
            'WebSocket received raw data: ${data.toString()}',
          );
          _onMessage(data.toString(), DateTime.now());

          // Note: Cannot emit states from async stream listener after event handler completes
          // State emissions must happen within the original event handler context
        },
        onError: (error) {
          AppLogger.commError(
            'WebSocket stream error: $error (type: ${error.runtimeType})',
            error,
          );
          _isConnected = false;

          if (!connectionValidated && !connectionFailed) {
            connectionFailed = true;
            validationTimeout.cancel();

            AppLogger.commError(
              'WebSocket connection failed during validation: $error',
              error,
            );
            if (!emit.isDone) {
              emit(
                CncCommunicationError(
                  errorMessage:
                      'Failed to establish WebSocket connection: $error',
                  statusMessage: 'Connection Failed',
                  error: error,
                ),
              );
            }
          } else if (!emit.isDone) {
            // Connection was established but then failed
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

          if (!connectionValidated && !connectionFailed) {
            connectionFailed = true;
            validationTimeout.cancel();

            AppLogger.commInfo('WebSocket connection closed during validation');
            if (!emit.isDone) {
              emit(
                const CncCommunicationDisconnected(
                  statusMessage: 'Connection Closed',
                  reason: 'WebSocket closed during handshake',
                ),
              );
            }
          } else if (!emit.isDone) {
            emit(
              const CncCommunicationDisconnected(
                statusMessage: 'Disconnected',
                reason: 'WebSocket stream closed',
              ),
            );
          }
        },
      );

      try {
        // Send a test command to trigger the validation
        _sendCommand('?', -999);
      } catch (e) {
        connectionFailed = true;
        validationTimeout.cancel();

        AppLogger.commError('Failed to send test command', e);
        if (!emit.isDone) {
          emit(
            CncCommunicationError(
              errorMessage: 'Connection test failed: $e',
              statusMessage: 'Connection Test Failed',
              error: e,
            ),
          );
        }
        return;
      }
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
      // Close WebSocket connection
      if (_webSocketChannel != null) {
        await _webSocketChannel!.sink.close(status.goingAway);
        _webSocketChannel = null;
      }

      // Clean up timers and state
      _cleanup();
      _isConnected = false;

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
    AppLogger.commInfo('Sending command $commandId: "${event.command}"');

    _sendCommand(event.command, commandId);
    _messages.add('Sent: ${event.command}');
    _emitDataState(emit);
  }

  /// Handle jog test start
  void _onStartJogTest(
    CncCommunicationStartJogTest event,
    Emitter<CncCommunicationState> emit,
  ) {
    if (!_isConnected) {
      AppLogger.commWarning('Cannot start jog test - not connected');
      return;
    }

    AppLogger.commInfo(
      'Starting jog test: ${event.durationSeconds}s, ${event.jogDistance}mm, ${event.feedRate}mm/min',
    );

    _jogTestRunning = true;
    _jogTestStartTime = DateTime.now();
    _jogTestDurationSeconds = event.durationSeconds;
    _messages.add('=== JOG TEST STARTED ===');
    _messages.add(
      'Duration: ${event.durationSeconds}s, Distance: ${event.jogDistance}mm, Feed: ${event.feedRate}mm/min',
    );

    _startJogTest(event.durationSeconds, event.jogDistance, event.feedRate);
    _emitDataState(emit);
  }

  /// Handle jog test stop
  void _onStopJogTest(
    CncCommunicationStopJogTest event,
    Emitter<CncCommunicationState> emit,
  ) {
    AppLogger.commInfo('Stopping jog test');
    _stopJogTest();
    _messages.add('=== JOG TEST STOPPED ===');
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

    AppLogger.commDebug('Received: $message');
    _messages.add('Received: $message');

    // Keep message history manageable
    if (_messages.length > 1000) {
      _messages.removeRange(0, 100);
    }

    // Track state changes for jog test
    _trackStateChange(message, timestamp);

    // Parse machine state from status messages
    _parseMachineState(message, timestamp);

    // Check if this is a response to a pending command
    _processCommandResponse(message, timestamp);

    // Update performance metrics
    _updatePerformanceMetrics();

    // Mark that data has been updated
    _hasDataUpdate = true;
  }

  /// Track state transitions for jog testing
  void _trackStateChange(String message, DateTime timestamp) {
    if (!message.startsWith('<')) return;

    final stateMatch = RegExp(r'<([^|]+)').firstMatch(message);
    if (stateMatch == null) return;

    final currentState = stateMatch.group(1)!;

    if (_lastRawMachineState.isNotEmpty &&
        _lastRawMachineState != currentState) {
      final transitionTime = _jogStartTime != null
          ? timestamp.difference(_jogStartTime!).inMicroseconds / 1000.0
          : 0.0;

      final transition =
          '$_lastRawMachineState → $currentState (${transitionTime.toStringAsFixed(1)}ms)';
      _stateTransitions.add(transition);

      _messages.add('State: $transition');
      AppLogger.commDebug('State transition: $transition');

      // If we transitioned from Jog to Idle during jog test, start next jog
      if (_jogTestRunning &&
          _lastRawMachineState == 'Jog' &&
          currentState == 'Idle') {
        AppLogger.commDebug('Jog completed, starting next jog');
        Timer(const Duration(milliseconds: 100), () {
          if (_jogTestRunning) {
            _executeNextJog();
          }
        });
      }
    }

    _lastRawMachineState = currentState;
  }

  /// Parse machine state information from GRBL status messages
  void _parseMachineState(String message, DateTime timestamp) {
    if (!message.startsWith('<')) return;

    // Parse GRBL status: <Idle|MPos:0.000,0.000,0.000|FS:0,0>
    final stateMatch = RegExp(r'<([^|]+)').firstMatch(message);
    if (stateMatch == null) return;

    final state = stateMatch.group(1)!;

    // Parse positions
    Position? workPos;
    Position? machinePos;

    final workPosMatch = RegExp(
      r'WPos:([+-]?\d*\.?\d+),([+-]?\d*\.?\d+),([+-]?\d*\.?\d+)',
    ).firstMatch(message);
    if (workPosMatch != null) {
      workPos = Position(
        x: double.parse(workPosMatch.group(1)!),
        y: double.parse(workPosMatch.group(2)!),
        z: double.parse(workPosMatch.group(3)!),
      );
    }

    final machinePosMatch = RegExp(
      r'MPos:([+-]?\d*\.?\d+),([+-]?\d*\.?\d+),([+-]?\d*\.?\d+)',
    ).firstMatch(message);
    if (machinePosMatch != null) {
      machinePos = Position(
        x: double.parse(machinePosMatch.group(1)!),
        y: double.parse(machinePosMatch.group(2)!),
        z: double.parse(machinePosMatch.group(3)!),
      );
    }

    // Parse feed and spindle
    double? feedRate;
    double? spindleSpeed;

    final fsMatch = RegExp(r'FS:(\d+),(\d+)').firstMatch(message);
    if (fsMatch != null) {
      feedRate = double.parse(fsMatch.group(1)!);
      spindleSpeed = double.parse(fsMatch.group(2)!);
    }

    _currentMachineState = MachineState(
      state: state,
      workPosition: workPos,
      machinePosition: machinePos,
      feedRate: feedRate,
      spindleSpeed: spindleSpeed,
      lastUpdated: timestamp,
    );
  }

  /// Process command responses and calculate latency
  void _processCommandResponse(String message, DateTime timestamp) {
    if (message != 'ok' &&
        !message.startsWith('error:') &&
        !message.startsWith('<')) {
      return;
    }

    int? commandId;

    if (message.startsWith('<')) {
      // Status data - find most recent status query
      commandId = _findMostRecentStatusQuery();
    } else if (message == 'ok' || message.startsWith('error:')) {
      // Ok/error response - match to oldest non-status command
      commandId = _findOldestNonStatusCommand();
    }

    if (commandId != null && _pendingCommands.containsKey(commandId)) {
      final sentTime = _pendingCommands.remove(commandId)!;
      _pendingCommandTypes.remove(commandId);
      final latency = timestamp.difference(sentTime).inMicroseconds / 1000.0;

      _latencies.add(latency);
      if (_latencies.length > 1000) {
        _latencies.removeAt(0);
      }

      _messages.add('Response [$commandId]: $message (${latency.round()}ms)');
      AppLogger.commDebug(
        'Command $commandId latency: ${latency.toStringAsFixed(3)}ms',
      );
    }
  }

  /// Find the most recent status query command ID
  int? _findMostRecentStatusQuery() {
    int? latestStatusCommandId;
    DateTime? latestStatusTime;

    for (final entry in _pendingCommands.entries) {
      final commandId = entry.key;
      final timestamp = entry.value;
      final commandType = _pendingCommandTypes[commandId];

      if (commandType == '?' &&
          (latestStatusTime == null || timestamp.isAfter(latestStatusTime))) {
        latestStatusCommandId = commandId;
        latestStatusTime = timestamp;
      }
    }

    return latestStatusCommandId;
  }

  /// Find the oldest non-status command ID
  int? _findOldestNonStatusCommand() {
    int? oldestNonStatusCommandId;
    DateTime? oldestNonStatusTime;

    for (final entry in _pendingCommands.entries) {
      final commandId = entry.key;
      final timestamp = entry.value;
      final commandType = _pendingCommandTypes[commandId];

      if (commandType != '?' &&
          commandId > 0 &&
          (oldestNonStatusTime == null ||
              timestamp.isBefore(oldestNonStatusTime))) {
        oldestNonStatusCommandId = commandId;
        oldestNonStatusTime = timestamp;
      }
    }

    return oldestNonStatusCommandId;
  }

  /// Update performance metrics based on current latency data
  void _updatePerformanceMetrics() {
    if (_latencies.isEmpty) return;

    final avgLatency = _latencies.reduce((a, b) => a + b) / _latencies.length;
    final maxLatency = _latencies.reduce((a, b) => a > b ? a : b);

    _currentPerformanceData = PerformanceData(
      messagesPerSecond: _latencies.length,
      averageLatencyMs: avgLatency,
      maxLatencyMs: maxLatency,
      totalMessages: _latencies.length,
      droppedMessages: 0,
      recentLatencies: [],
    );
  }

  /// Send command to WebSocket with tracking
  void _sendCommand(String command, int commandId) {
    if (_webSocketChannel == null) {
      AppLogger.commWarning('Cannot send WebSocket command - not connected');
      return;
    }

    try {
      final commandWithNewline = '$command\r\n';

      // Check WebSocket state before sending
      final sink = _webSocketChannel!.sink;
      AppLogger.commDebug('WebSocket sink ready: ${sink.hashCode}');

      sink.add(commandWithNewline);

      final timestamp = DateTime.now();
      _pendingCommands[commandId] = timestamp;
      _pendingCommandTypes[commandId] = command;

      AppLogger.commDebug(
        'WebSocket sent command $commandId: "$command" successfully',
      );
    } catch (e, stackTrace) {
      AppLogger.commError(
        'Error sending WebSocket command "$command"',
        e,
        stackTrace,
      );
      _pendingCommands.remove(commandId);
      _pendingCommandTypes.remove(commandId);

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

  /// Start heartbeat timer for status monitoring
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 200), (
      timer,
    ) {
      if (_webSocketChannel != null && !_jogTestRunning) {
        _sendCommand('?', -timer.tick);

        // If we have data updates, trigger a status event to refresh the UI state
        if (_hasDataUpdate && _isConnected) {
          _hasDataUpdate = false; // Reset the flag
          add(
            CncCommunicationStatusChanged(
              isConnected: true,
              statusMessage: 'Data Updated',
              deviceInfo: 'GRBL/grblHAL via WebSocket',
            ),
          );
        }
      }
    });
    AppLogger.commInfo('Heartbeat started (200ms interval)');
  }

  /// Start jog test sequence
  void _startJogTest(int durationSeconds, double jogDistance, int feedRate) {
    _jogTestRunning = true;
    _jogCount = 0;
    _jogDistance = jogDistance;
    _jogFeedRate = feedRate;
    _jogTestDurationSeconds = durationSeconds;
    _lastRawMachineState = '';
    _stateTransitions.clear();

    AppLogger.commInfo(
      'Starting jog test: ${durationSeconds}s, ${jogDistance}mm, ${feedRate}mm/min',
    );

    // Stop regular heartbeat during test
    _heartbeatTimer?.cancel();

    // Start 20Hz status polling during jog operations
    _startJogPolling();

    // Start the jog sequence
    _executeNextJog();
  }

  /// Start high-frequency status polling during jog test
  void _startJogPolling() {
    _jogPollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_jogTestRunning) {
        timer.cancel();
        return;
      }

      // Safety check: ensure test doesn't run longer than intended duration
      if (_jogTestStartTime != null &&
          DateTime.now().difference(_jogTestStartTime!).inSeconds >=
              _jogTestDurationSeconds) {
        AppLogger.commInfo('Jog test duration exceeded - stopping test');
        _stopJogTest();
        timer.cancel();
        return;
      }

      // Send status query
      _sendCommand('?', -1000 - _jogCount);
    });
  }

  /// Execute the next jog movement in sequence
  void _executeNextJog() {
    if (!_jogTestRunning) return;

    if (_jogTestStartTime != null &&
        DateTime.now().difference(_jogTestStartTime!).inSeconds >=
            _jogTestDurationSeconds) {
      _stopJogTest();
      return;
    }

    _jogCount++;
    _jogStartTime = DateTime.now();

    // Send jog command: alternate between +X and -X
    final direction = (_jogCount % 2 == 1) ? '' : '-';
    final jogCommand = '\$J=G91 X$direction$_jogDistance F$_jogFeedRate';

    AppLogger.commDebug('Executing jog $_jogCount: $jogCommand');
    _sendCommand(jogCommand, 20000 + _jogCount);
  }

  /// Stop jog test and report metrics
  void _stopJogTest() {
    if (!_jogTestRunning) return;

    AppLogger.commInfo('Stopping jog test');
    _jogTestRunning = false;
    _jogPollTimer?.cancel();
    _jogPollTimer = null;

    // Resume regular heartbeat
    _startHeartbeat();

    _reportJogTestMetrics();
  }

  /// Report jog test performance metrics
  void _reportJogTestMetrics() {
    final testDuration = _jogTestStartTime != null
        ? DateTime.now().difference(_jogTestStartTime!).inMilliseconds / 1000.0
        : 0.0;

    AppLogger.commInfo('=== JOG TEST RESULTS ===');
    AppLogger.commInfo('Test duration: ${testDuration.toStringAsFixed(1)}s');
    AppLogger.commInfo('Total jogs: $_jogCount');
    AppLogger.commInfo('State transitions: ${_stateTransitions.length}');

    for (final transition in _stateTransitions) {
      AppLogger.commInfo('  $transition');
    }

    // Calculate average jog time
    final jogTimes = <double>[];
    for (final transition in _stateTransitions) {
      if (transition.contains('Jog → Idle')) {
        final timeMatch = RegExp(r'\\(([0-9.]+)ms\\)').firstMatch(transition);
        if (timeMatch != null) {
          jogTimes.add(double.parse(timeMatch.group(1)!));
        }
      }
    }

    final avgJogTime = jogTimes.isEmpty
        ? 0.0
        : jogTimes.reduce((a, b) => a + b) / jogTimes.length;
    final maxJogTime = jogTimes.isEmpty
        ? 0.0
        : jogTimes.reduce((a, b) => a > b ? a : b);

    AppLogger.commInfo(
      'Average jog completion time: ${avgJogTime.toStringAsFixed(2)}ms',
    );
    AppLogger.commInfo(
      'Max jog completion time: ${maxJogTime.toStringAsFixed(2)}ms',
    );

    // Add results to message history
    _messages.add('=== JOG TEST COMPLETED ===');
    _messages.add('Total jogs: $_jogCount');
    _messages.add('Average jog time: ${avgJogTime.toStringAsFixed(2)}ms');
    _messages.add('Max jog time: ${maxJogTime.toStringAsFixed(2)}ms');
    _messages.add('Test duration: ${testDuration.toStringAsFixed(1)}s');
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
          performanceData: _currentPerformanceData,
          machineState: _currentMachineState,
          jogTestRunning: _jogTestRunning,
          connectedAt: _connectedAt!,
        ),
      );
    }
  }

  /// Clean up timers and subscriptions
  void _cleanup() {
    _webSocketSubscription?.cancel();
    _heartbeatTimer?.cancel();
    _jogPollTimer?.cancel();

    _webSocketSubscription = null;
    _heartbeatTimer = null;
    _jogPollTimer = null;
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

  /// Get current UI performance metrics
  Map<String, dynamic> getUIPerformanceMetrics() {
    if (_uiFrameTimes.isEmpty) {
      return {
        'avgFrameTime': 0.0,
        'maxFrameTime': 0.0,
        'jankFrames': 0,
        'framerate': 0.0,
        'uiThreadBlocked': false,
      };
    }

    final avgFrameTime =
        _uiFrameTimes.reduce((a, b) => a + b) / _uiFrameTimes.length;
    final maxFrameTime = _uiFrameTimes.reduce((a, b) => a > b ? a : b);
    final jankFrames = _uiFrameTimes.where((time) => time > 20.0).length;
    final framerate = 1000.0 / avgFrameTime;
    final uiThreadBlocked = avgFrameTime > 20.0;

    return {
      'avgFrameTime': avgFrameTime,
      'maxFrameTime': maxFrameTime,
      'jankFrames': jankFrames,
      'framerate': framerate,
      'uiThreadBlocked': uiThreadBlocked,
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
    _uiPerformanceTimer?.cancel();
    _cleanup();
    return super.close();
  }
}
