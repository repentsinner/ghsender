import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'logger.dart';

// Events for grblHAL communication
abstract class GrblCommunicationEvent {}


class GrblConnectEvent extends GrblCommunicationEvent {
  final String url;
  GrblConnectEvent(this.url);
}

class GrblDisconnectEvent extends GrblCommunicationEvent {}

class GrblSendCommandEvent extends GrblCommunicationEvent {
  final String command;
  GrblSendCommandEvent(this.command);
}


class GrblStartJogTestEvent extends GrblCommunicationEvent {
  final int durationSeconds;
  final double jogDistance;
  final int feedRate;
  GrblStartJogTestEvent(this.durationSeconds, this.jogDistance, this.feedRate);
}

class GrblStopJogTestEvent extends GrblCommunicationEvent {}

class _GrblJogTestCountdownEvent extends GrblCommunicationEvent {}

// Internal event for handling isolate responses

// States for grblHAL communication
abstract class GrblCommunicationState {}

class GrblCommunicationInitial extends GrblCommunicationState {}

class GrblCommunicationConnecting extends GrblCommunicationState {}

class GrblCommunicationConnected extends GrblCommunicationState {
  final String url;
  GrblCommunicationConnected(this.url);
}

class GrblCommunicationDisconnected extends GrblCommunicationState {}

class GrblCommunicationError extends GrblCommunicationState {
  final String error;
  GrblCommunicationError(this.error);
}

class GrblCommunicationWithData extends GrblCommunicationState {
  final List<String> messages;
  final bool isConnected;
  final PerformanceData? performanceData;
  final bool jogTestRunning;
  final int? jogTestRemainingSeconds;
  
  GrblCommunicationWithData(
    this.messages, 
    this.isConnected, 
    [this.performanceData,
     this.jogTestRunning = false,
     this.jogTestRemainingSeconds]
  );
  
  GrblCommunicationWithData copyWith({
    List<String>? messages,
    bool? isConnected,
    PerformanceData? performanceData,
    bool? jogTestRunning,
    int? jogTestRemainingSeconds,
  }) {
    return GrblCommunicationWithData(
      messages ?? this.messages,
      isConnected ?? this.isConnected,
      performanceData ?? this.performanceData,
      jogTestRunning ?? this.jogTestRunning,
      jogTestRemainingSeconds ?? this.jogTestRemainingSeconds,
    );
  }
}

class PerformanceData {
  final int messagesPerSecond;
  final double averageLatencyMs;
  final double maxLatencyMs;
  final int totalMessages;
  final int droppedMessages;
  final List<LatencyMeasurement> recentLatencies;
  
  PerformanceData(
    this.messagesPerSecond,
    this.averageLatencyMs,
    this.maxLatencyMs,
    this.totalMessages,
    this.droppedMessages,
    this.recentLatencies,
  );
  
  bool get meetsLatencyRequirement => averageLatencyMs < 20.0;
  String get latencyStatus => meetsLatencyRequirement ? "✅ PASS" : "❌ FAIL";
}

class LatencyMeasurement {
  final DateTime timestamp;
  final double latencyMs;
  final int commandId;
  
  LatencyMeasurement(this.timestamp, this.latencyMs, this.commandId);
}

// grblHAL communication BLoC
class GrblCommunicationBloc extends Bloc<GrblCommunicationEvent, GrblCommunicationState> {
  static final Logger _logger = AppLogger.communication;
  
  // WebSocket communication
  WebSocketChannel? _webSocketChannel;
  StreamSubscription? _webSocketSubscription;
  
  final List<String> _messages = [];
  PerformanceData? _currentPerformanceData;
  bool _isConnected = false;
  bool _jogTestRunning = false;
  int _commandIdCounter = 0;
  
  // Jog test timing
  DateTime? _jogTestStartTime;
  int _jogTestDurationSeconds = 0;
  Timer? _jogTestCountdownTimer;
  
  // Communication tracking
  Timer? _heartbeatTimer;
  final Map<int, DateTime> _pendingCommands = {};
  final Map<int, String> _pendingCommandTypes = {};
  final List<double> _latencies = [];
  String _lastMachineState = '';
  
  // Jog test variables
  Timer? _jogPollTimer;
  int _jogCount = 0;
  double _jogDistance = 0.0;
  int _jogFeedRate = 0;
  DateTime? _jogStartTime;
  List<String> _stateTransitions = [];
  
  // Performance instrumentation
  final List<double> _uiFrameTimes = [];
  Timer? _uiPerformanceTimer;
  final Stopwatch _uiStopwatch = Stopwatch();
  
  GrblCommunicationBloc() : super(GrblCommunicationInitial()) {
    _logger.info('GrblCommunicationBloc initialized');
    
    on<GrblConnectEvent>(_onConnect);
    on<GrblDisconnectEvent>(_onDisconnect);
    on<GrblSendCommandEvent>(_onSendCommand);
    on<GrblStartJogTestEvent>(_onStartJogTest);
    on<GrblStopJogTestEvent>(_onStopJogTest);
    on<_GrblJogTestCountdownEvent>(_onJogTestCountdown);
    
    _startUIPerformanceMonitoring();
  }
  
  void _startUIPerformanceMonitoring() {
    _uiPerformanceTimer = Timer.periodic(Duration(milliseconds: 16), (timer) {
      // Measure UI thread responsiveness by timing this callback
      if (_uiStopwatch.isRunning) {
        final frameTime = _uiStopwatch.elapsedMicroseconds / 1000.0;
        _uiFrameTimes.add(frameTime);
        
        // Keep only last 60 frames (1 second at 60fps)
        if (_uiFrameTimes.length > 60) {
          _uiFrameTimes.removeAt(0);
        }
        
        // Log UI jank if frame time exceeds 16.67ms (60fps threshold)
        if (frameTime > 16.67) {
          _logger.warning('UI JANK detected: ${frameTime.toStringAsFixed(2)}ms frame time');
        }
      }
      _uiStopwatch.reset();
      _uiStopwatch.start();
    });
  }
  
  Future<void> _onConnect(GrblConnectEvent event, Emitter<GrblCommunicationState> emit) async {
    _logger.info('Starting WebSocket connection to ${event.url}');
    
    try {
      emit(GrblCommunicationConnecting());
      
      // Connect to WebSocket
      _webSocketChannel = WebSocketChannel.connect(Uri.parse(event.url));
      
      // Listen for messages
      _webSocketSubscription = _webSocketChannel!.stream.listen(
        (data) {
          _onMessage(data.toString(), DateTime.now());
        },
        onError: (error) {
          _logger.severe('WebSocket error: $error');
          emit(GrblCommunicationError('WebSocket error: $error'));
        },
        onDone: () {
          _logger.info('WebSocket connection closed');
          _isConnected = false;
          emit(GrblCommunicationDisconnected());
        },
      );
      
      _isConnected = true;
      _messages.add('Connected to WebSocket');
      emit(GrblCommunicationConnected(event.url));
      _emitCurrentState(emit);
      
      _logger.info('WebSocket connected successfully');
      
      // Start heartbeat
      _startHeartbeat();
      
    } catch (e, stackTrace) {
      _logger.severe('Failed to connect WebSocket: $e', e, stackTrace);
      emit(GrblCommunicationError('Failed to connect WebSocket: $e'));
    }
  }
  
  void _onMessage(String message, DateTime timestamp) {
    if (message.isEmpty) return;
    
    _logger.fine('Received: $message');
    _messages.add('Received: $message');
    
    // Track state changes for jog test
    _trackStateChange(message, timestamp);
    
    // Check if this is a response to a pending command
    if (message == 'ok' || message.startsWith('error:') || message.startsWith('<')) {
      if (_pendingCommands.isNotEmpty) {
        bool shouldMeasureLatency = false;
        int? commandId;
        
        if (message.startsWith('<')) {
          // Status data - find most recent status query
          commandId = _findMostRecentStatusQuery();
          shouldMeasureLatency = commandId != null;
        } else if (message == 'ok' || message.startsWith('error:')) {
          // Ok/error response - match to oldest non-status command
          commandId = _findOldestNonStatusCommand();
          shouldMeasureLatency = commandId != null;
        }
        
        if (shouldMeasureLatency && commandId != null && _pendingCommands.containsKey(commandId)) {
          final sentTime = _pendingCommands.remove(commandId)!;
          _pendingCommandTypes.remove(commandId);
          final latency = timestamp.difference(sentTime).inMicroseconds / 1000.0;
          
          _latencies.add(latency);
          if (_latencies.length > 1000) {
            _latencies.removeAt(0);
          }
          
          _messages.add('Response [$commandId]: $message (${latency.round()}ms)');
          _logger.fine('Command $commandId latency: ${latency.toStringAsFixed(3)}ms');
        }
      }
    }
    
    // Update performance metrics
    _updatePerformanceMetrics();
  }
  
  void _trackStateChange(String message, DateTime timestamp) {
    if (!message.startsWith('<')) return;
    
    final stateMatch = RegExp(r'<([^|]+)').firstMatch(message);
    if (stateMatch == null) return;
    
    final currentState = stateMatch.group(1)!;
    
    if (_lastMachineState.isNotEmpty && _lastMachineState != currentState) {
      final transitionTime = _jogStartTime != null 
        ? timestamp.difference(_jogStartTime!).inMicroseconds / 1000.0
        : 0.0;
      
      final transition = '${_lastMachineState} → $currentState (${transitionTime.toStringAsFixed(1)}ms)';
      _stateTransitions.add(transition);
      
      _messages.add('State: $transition');
      _logger.fine('State transition: $transition');
      
      // If we transitioned from Jog to Idle during jog test, start next jog
      if (_jogTestRunning && _lastMachineState == 'Jog' && currentState == 'Idle') {
        _logger.fine('Jog completed, starting next jog');
        Timer(Duration(milliseconds: 100), () {
          if (_jogTestRunning) {
            _executeNextJog();
          }
        });
      }
    }
    
    _lastMachineState = currentState;
  }
  
  int? _findMostRecentStatusQuery() {
    int? latestStatusCommandId;
    DateTime? latestStatusTime;
    
    for (final entry in _pendingCommands.entries) {
      final commandId = entry.key;
      final timestamp = entry.value;
      final commandType = _pendingCommandTypes[commandId];
      
      if (commandType == '?' && (latestStatusTime == null || timestamp.isAfter(latestStatusTime))) {
        latestStatusCommandId = commandId;
        latestStatusTime = timestamp;
      }
    }
    
    return latestStatusCommandId;
  }
  
  int? _findOldestNonStatusCommand() {
    int? oldestNonStatusCommandId;
    DateTime? oldestNonStatusTime;
    
    for (final entry in _pendingCommands.entries) {
      final commandId = entry.key;
      final timestamp = entry.value;
      final commandType = _pendingCommandTypes[commandId];
      
      if (commandType != '?' && commandId > 0 && 
          (oldestNonStatusTime == null || timestamp.isBefore(oldestNonStatusTime))) {
        oldestNonStatusCommandId = commandId;
        oldestNonStatusTime = timestamp;
      }
    }
    
    return oldestNonStatusCommandId;
  }
  
  void _updatePerformanceMetrics() {
    if (_latencies.isEmpty) return;
    
    final avgLatency = _latencies.reduce((a, b) => a + b) / _latencies.length;
    final maxLatency = _latencies.reduce((a, b) => a > b ? a : b);
    
    _currentPerformanceData = PerformanceData(
      _latencies.length,
      avgLatency,
      maxLatency,
      _latencies.length,
      0, // No dropped messages concept for WebSocket
      [], // No recent latencies tracking for simplified WebSocket implementation
    );
  }
  
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(Duration(milliseconds: 200), (timer) {
      if (_webSocketChannel != null && !_jogTestRunning) {
        _sendCommand('?', -timer.tick);
      }
    });
    _logger.info('Heartbeat started (200ms interval)');
  }
  
  void _sendCommand(String command, int commandId) {
    if (_webSocketChannel == null) {
      _logger.warning('Cannot send WebSocket command - not connected');
      return;
    }
    
    try {
      final commandWithNewline = command + '\r\n';
      _webSocketChannel!.sink.add(commandWithNewline);
      
      final timestamp = DateTime.now();
      _pendingCommands[commandId] = timestamp;
      _pendingCommandTypes[commandId] = command;
      
      _logger.fine('WebSocket sent command $commandId: "$command"');
    } catch (e) {
      _logger.severe('Error sending WebSocket command: $e');
      _pendingCommands.remove(commandId);
      _pendingCommandTypes.remove(commandId);
    }
  }
  
  void _startJogTest(int durationSeconds, double jogDistance, int feedRate) {
    _jogTestRunning = true;
    _jogCount = 0;
    _jogDistance = jogDistance;
    _jogFeedRate = feedRate;
    _jogTestDurationSeconds = durationSeconds;
    _lastMachineState = '';
    
    _logger.info('Starting jog test: ${durationSeconds}s, ${jogDistance}mm, ${feedRate}mm/min');
    
    // Stop regular heartbeat during test
    _heartbeatTimer?.cancel();
    
    // Start 20Hz status polling during jog operations
    _startJogPolling();
    
    // Start the jog sequence
    _executeNextJog();
  }
  
  void _startJogPolling() {
    _jogPollTimer = Timer.periodic(Duration(milliseconds: 50), (timer) {
      if (!_jogTestRunning) {
        timer.cancel();
        return;
      }
      
      // Safety check: ensure test doesn't run longer than intended duration
      if (_jogTestStartTime != null && 
          DateTime.now().difference(_jogTestStartTime!).inSeconds >= _jogTestDurationSeconds) {
        _logger.info('WebSocket jog test duration exceeded - stopping test');
        _stopJogTest();
        timer.cancel();
        return;
      }
      
      // Send status query
      _sendCommand('?', -1000 - _jogCount);
    });
  }
  
  void _executeNextJog() {
    if (!_jogTestRunning) return;
    
    if (_jogTestStartTime != null && 
        DateTime.now().difference(_jogTestStartTime!).inSeconds >= _jogTestDurationSeconds) {
      _stopJogTest();
      return;
    }
    
    _jogCount++;
    _jogStartTime = DateTime.now();
    
    // Send jog command: alternate between +X and -X
    final direction = (_jogCount % 2 == 1) ? '' : '-';
    final jogCommand = '\$J=G91 X${direction}${_jogDistance} F$_jogFeedRate';
    
    _logger.fine('Executing jog $_jogCount: $jogCommand');
    _sendCommand(jogCommand, 20000 + _jogCount);
  }
  
  void _stopJogTest() {
    if (!_jogTestRunning) return;
    
    _logger.info('Stopping jog test');
    _jogTestRunning = false;
    _jogPollTimer?.cancel();
    _jogPollTimer = null;
    
    // Resume regular heartbeat
    _startHeartbeat();
    
    _reportJogTestMetrics();
  }
  
  void _reportJogTestMetrics() {
    final testDuration = _jogTestStartTime != null 
      ? DateTime.now().difference(_jogTestStartTime!).inMilliseconds / 1000.0
      : 0.0;
    
    _logger.info('=== WEBSOCKET JOG TEST RESULTS ===');
    _logger.info('Test duration: ${testDuration.toStringAsFixed(1)}s');
    _logger.info('Total jogs: $_jogCount');
    _logger.info('State transitions: ${_stateTransitions.length}');
    
    for (final transition in _stateTransitions) {
      _logger.info('  $transition');
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
    
    final avgJogTime = jogTimes.isEmpty ? 0.0 : jogTimes.reduce((a, b) => a + b) / jogTimes.length;
    final maxJogTime = jogTimes.isEmpty ? 0.0 : jogTimes.reduce((a, b) => a > b ? a : b);
    
    _logger.info('Average jog completion time: ${avgJogTime.toStringAsFixed(2)}ms');
    _logger.info('Max jog completion time: ${maxJogTime.toStringAsFixed(2)}ms');
    
    // Send completion notification
    _jogTestRunning = false;
    _messages.add('=== JOG TEST COMPLETED ===');
    _messages.add('Total jogs: $_jogCount');
    _messages.add('Average jog time: ${avgJogTime.toStringAsFixed(2)}ms');
    _messages.add('Max jog time: ${maxJogTime.toStringAsFixed(2)}ms');
    _messages.add('Test duration: ${testDuration.toStringAsFixed(1)}s');
  }
  
  void _onDisconnect(GrblDisconnectEvent event, Emitter<GrblCommunicationState> emit) {
    _logger.info('Disconnecting communication');
    
    if (_webSocketChannel != null) {
      _webSocketChannel!.sink.close(status.goingAway);
      _webSocketChannel = null;
    }
    
    _cleanup();
    _isConnected = false;
    emit(GrblCommunicationDisconnected());
  }
  
  void _onSendCommand(GrblSendCommandEvent event, Emitter<GrblCommunicationState> emit) {
    if (!_isConnected) {
      _logger.warning('Cannot send command - not connected');
      return;
    }
    
    final commandId = ++_commandIdCounter;
    final timestamp = DateTime.now();
    
    _logger.info('Sending command $commandId: "${event.command}"');
    
    if (_webSocketChannel != null) {
      _sendCommand(event.command, commandId);
    } else {
      _logger.warning('Not connected');
      return;
    }
    
    _messages.add('Sent: ${event.command}');
    _emitCurrentState(emit);
  }
  
  
  void _onStartJogTest(GrblStartJogTestEvent event, Emitter<GrblCommunicationState> emit) {
    if (!_isConnected) {
      _logger.warning('Cannot start jog test - not connected');
      return;
    }
    
    _logger.info('Starting jog test: ${event.durationSeconds}s, ${event.jogDistance}mm, ${event.feedRate}mm/min');
    _jogTestRunning = true;
    _jogTestStartTime = DateTime.now();
    _jogTestDurationSeconds = event.durationSeconds;
    _messages.add('=== JOG TEST STARTED ===');
    _messages.add('Duration: ${event.durationSeconds}s, Distance: ${event.jogDistance}mm, Feed: ${event.feedRate}mm/min');
    
    // Start countdown timer that updates UI every second
    _startJogTestCountdown();
    
    // Use WebSocket-based jog test
    _startJogTest(event.durationSeconds, event.jogDistance.toDouble(), event.feedRate);
    
    _emitCurrentState(emit);
  }
  
  void _onStopJogTest(GrblStopJogTestEvent event, Emitter<GrblCommunicationState> emit) {
    _logger.info('Stopping jog test');
    _jogTestRunning = false;
    _jogTestCountdownTimer?.cancel();
    _jogTestCountdownTimer = null;
    _messages.add('=== JOG TEST STOPPED ===');
    
    _stopJogTest();
    
    _emitCurrentState(emit);
  }
  
  
  void _startJogTestCountdown() {
    _jogTestCountdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!_jogTestRunning || _jogTestStartTime == null) {
        timer.cancel();
        return;
      }
      
      final elapsed = DateTime.now().difference(_jogTestStartTime!).inSeconds;
      final remaining = _jogTestDurationSeconds - elapsed;
      
      if (remaining <= 0) {
        timer.cancel();
        // Complete the jog test when countdown reaches 0
        _stopJogTest();
        return;
      }
      
      // Trigger countdown event to update UI
      add(_GrblJogTestCountdownEvent());
    });
  }
  
  void _onJogTestCountdown(_GrblJogTestCountdownEvent event, Emitter<GrblCommunicationState> emit) {
    // Simply emit current state with updated countdown
    _emitCurrentState(emit);
  }
  
  int? _getJogTestRemainingSeconds() {
    if (!_jogTestRunning || _jogTestStartTime == null) return null;
    
    final elapsed = DateTime.now().difference(_jogTestStartTime!).inSeconds;
    final remaining = _jogTestDurationSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }
  
  void _emitCurrentState(Emitter<GrblCommunicationState> emit) {
    emit(GrblCommunicationWithData(
      List.from(_messages),
      _isConnected,
      _currentPerformanceData,
      _jogTestRunning,
      _getJogTestRemainingSeconds(),
    ));
  }
  
  void _cleanup() {
    _jogTestCountdownTimer?.cancel();
    _webSocketSubscription?.cancel();
    _heartbeatTimer?.cancel();
    _jogPollTimer?.cancel();
    
    _jogTestCountdownTimer = null;
    _webSocketSubscription = null;
    _webSocketChannel = null;
    _heartbeatTimer = null;
    _jogPollTimer = null;
  }
  
  // Public method to get current UI performance metrics
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
    
    final avgFrameTime = _uiFrameTimes.reduce((a, b) => a + b) / _uiFrameTimes.length;
    final maxFrameTime = _uiFrameTimes.reduce((a, b) => a > b ? a : b);
    final jankFrames = _uiFrameTimes.where((time) => time > 16.67).length;
    final framerate = 1000.0 / avgFrameTime;
    final uiThreadBlocked = avgFrameTime > 16.67;
    
    return {
      'avgFrameTime': avgFrameTime,
      'maxFrameTime': maxFrameTime,
      'jankFrames': jankFrames,
      'framerate': framerate,
      'uiThreadBlocked': uiThreadBlocked,
    };
  }
  
  @override
  Future<void> close() {
    _uiPerformanceTimer?.cancel();
    _cleanup();
    return super.close();
  }
}