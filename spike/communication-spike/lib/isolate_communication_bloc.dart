import 'dart:async';
import 'dart:isolate';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'isolate_communication.dart';
import 'logger.dart';

// Events for the new isolate-based communication bloc
abstract class IsolateCommunicationEvent {}

class IsolateConnectEvent extends IsolateCommunicationEvent {
  final String host;
  final int port;
  IsolateConnectEvent(this.host, this.port);
}

class IsolateDisconnectEvent extends IsolateCommunicationEvent {}

class IsolateSendCommandEvent extends IsolateCommunicationEvent {
  final String command;
  IsolateSendCommandEvent(this.command);
}

class IsolateStartHighFrequencyTestEvent extends IsolateCommunicationEvent {
  final int durationSeconds;
  final int intervalMs;
  IsolateStartHighFrequencyTestEvent(this.durationSeconds, this.intervalMs);
}

class IsolateStopHighFrequencyTestEvent extends IsolateCommunicationEvent {}

// Internal event for handling isolate responses
class _IsolateResponseEvent extends IsolateCommunicationEvent {
  final IsolateResponse response;
  _IsolateResponseEvent(this.response);
}

// States for the isolate communication bloc
abstract class IsolateCommunicationState {}

class IsolateCommunicationInitial extends IsolateCommunicationState {}

class IsolateCommunicationConnecting extends IsolateCommunicationState {}

class IsolateCommunicationConnected extends IsolateCommunicationState {
  final String host;
  final int port;
  IsolateCommunicationConnected(this.host, this.port);
}

class IsolateCommunicationDisconnected extends IsolateCommunicationState {}

class IsolateCommunicationError extends IsolateCommunicationState {
  final String error;
  IsolateCommunicationError(this.error);
}

class IsolateCommunicationWithData extends IsolateCommunicationState {
  final List<String> messages;
  final bool isConnected;
  final PerformanceData? performanceData;
  final bool highFrequencyTestRunning;
  
  IsolateCommunicationWithData(
    this.messages, 
    this.isConnected, 
    [this.performanceData,
     this.highFrequencyTestRunning = false]
  );
  
  IsolateCommunicationWithData copyWith({
    List<String>? messages,
    bool? isConnected,
    PerformanceData? performanceData,
    bool? highFrequencyTestRunning,
  }) {
    return IsolateCommunicationWithData(
      messages ?? this.messages,
      isConnected ?? this.isConnected,
      performanceData ?? this.performanceData,
      highFrequencyTestRunning ?? this.highFrequencyTestRunning,
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

// The new isolate-based communication BLoC
class IsolateCommunicationBloc extends Bloc<IsolateCommunicationEvent, IsolateCommunicationState> {
  static final Logger _logger = AppLogger.communication;
  
  Isolate? _communicationIsolate;
  SendPort? _isolateSendPort;
  ReceivePort? _receivePort;
  StreamSubscription? _isolateSubscription;
  
  final List<String> _messages = [];
  final List<LatencyMeasurement> _recentLatencies = [];
  PerformanceData? _currentPerformanceData;
  bool _isConnected = false;
  bool _highFrequencyTestRunning = false;
  int _commandIdCounter = 0;
  
  // Performance instrumentation
  final List<double> _uiFrameTimes = [];
  Timer? _uiPerformanceTimer;
  final Stopwatch _uiStopwatch = Stopwatch();
  
  IsolateCommunicationBloc() : super(IsolateCommunicationInitial()) {
    _logger.info('IsolateCommunicationBloc initialized');
    
    on<IsolateConnectEvent>(_onConnect);
    on<IsolateDisconnectEvent>(_onDisconnect);
    on<IsolateSendCommandEvent>(_onSendCommand);
    on<IsolateStartHighFrequencyTestEvent>(_onStartHighFrequencyTest);
    on<IsolateStopHighFrequencyTestEvent>(_onStopHighFrequencyTest);
    on<_IsolateResponseEvent>(_onIsolateResponse);
    
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
  
  Future<void> _onConnect(IsolateConnectEvent event, Emitter<IsolateCommunicationState> emit) async {
    _logger.info('Starting isolate connection to ${event.host}:${event.port}');
    
    try {
      emit(IsolateCommunicationConnecting());
      
      // Create receive port for isolate communication
      _receivePort = ReceivePort();
      
      // Spawn the communication isolate
      _communicationIsolate = await Isolate.spawn(
        CommunicationIsolate.entryPoint,
        _receivePort!.sendPort,
      );
      
      _logger.info('Communication isolate spawned successfully');
      
      // Set up communication with isolate
      final completer = Completer<SendPort>();
      
      // Listen for all messages from isolate
      _isolateSubscription = _receivePort!.listen((message) {
        if (message is SendPort) {
          // First message is the isolate's send port
          _isolateSendPort = message;
          completer.complete(message);
          _logger.info('Isolate communication established');
        } else if (message is IsolateResponse) {
          add(_IsolateResponseEvent(message));
        }
      });
      
      await completer.future;
      
      // Send connect command to isolate
      _isolateSendPort!.send(ConnectMessage(event.host, event.port, _receivePort!.sendPort));
      
    } catch (e, stackTrace) {
      _logger.severe('Failed to start isolate: $e', e, stackTrace);
      emit(IsolateCommunicationError('Failed to start communication isolate: $e'));
    }
  }
  
  void _onDisconnect(IsolateDisconnectEvent event, Emitter<IsolateCommunicationState> emit) {
    _logger.info('Disconnecting isolate communication');
    
    if (_isolateSendPort != null) {
      _isolateSendPort!.send(DisconnectMessage());
    }
    
    _cleanup();
    _isConnected = false;
    emit(IsolateCommunicationDisconnected());
  }
  
  void _onSendCommand(IsolateSendCommandEvent event, Emitter<IsolateCommunicationState> emit) {
    if (_isolateSendPort == null || !_isConnected) {
      _logger.warning('Cannot send command - not connected');
      return;
    }
    
    final commandId = ++_commandIdCounter;
    final timestamp = DateTime.now();
    
    _logger.info('Sending command $commandId: "${event.command}"');
    _isolateSendPort!.send(SendCommandMessage(event.command, timestamp, commandId));
    
    _messages.add('Sent: ${event.command}');
    _emitCurrentState(emit);
  }
  
  void _onStartHighFrequencyTest(IsolateStartHighFrequencyTestEvent event, Emitter<IsolateCommunicationState> emit) {
    if (_isolateSendPort == null || !_isConnected) {
      _logger.warning('Cannot start high frequency test - not connected');
      return;
    }
    
    _logger.info('Starting high frequency test: ${event.durationSeconds}s, ${event.intervalMs}ms interval');
    _highFrequencyTestRunning = true;
    _recentLatencies.clear();
    _messages.add('=== HIGH FREQUENCY TEST STARTED ===');
    _messages.add('Duration: ${event.durationSeconds}s, Interval: ${event.intervalMs}ms');
    
    _isolateSendPort!.send(StartHighFrequencyTestMessage(event.durationSeconds, event.intervalMs));
    _emitCurrentState(emit);
  }
  
  void _onStopHighFrequencyTest(IsolateStopHighFrequencyTestEvent event, Emitter<IsolateCommunicationState> emit) {
    if (_isolateSendPort == null) return;
    
    _logger.info('Stopping high frequency test');
    _highFrequencyTestRunning = false;
    _messages.add('=== HIGH FREQUENCY TEST STOPPED ===');
    
    _isolateSendPort!.send(StopHighFrequencyTestMessage());
    _emitCurrentState(emit);
  }
  
  void _onIsolateResponse(_IsolateResponseEvent event, Emitter<IsolateCommunicationState> emit) {
    final response = event.response;
    
    if (response is ConnectionStatusResponse) {
      if (response.connected) {
        _isConnected = true;
        _messages.add('Connected to isolate communication');
        emit(IsolateCommunicationConnected('isolate', 0));
      } else {
        _isConnected = false;
        if (response.error != null) {
          _messages.add('Connection error: ${response.error}');
          emit(IsolateCommunicationError(response.error!));
        } else {
          emit(IsolateCommunicationDisconnected());
        }
      }
    } else if (response is MessageReceivedResponse) {
      _messages.add('Received: ${response.message}');
      _emitCurrentState(emit);
    } else if (response is CommandResponseReceived) {
      final latency = LatencyMeasurement(
        response.timestamp,
        response.latencyMs.toDouble(),
        response.commandId,
      );
      
      _recentLatencies.add(latency);
      // Keep only last 100 latency measurements
      if (_recentLatencies.length > 100) {
        _recentLatencies.removeAt(0);
      }
      
      _messages.add('Response [${response.commandId}]: ${response.response} (${response.latencyMs}ms)');
      
      // Log latency performance
      if (response.latencyMs > 20) {
        _logger.warning('High latency detected: ${response.latencyMs}ms for command ${response.commandId}');
      }
      
      _emitCurrentState(emit);
    } else if (response is PerformanceMetrics) {
      _currentPerformanceData = PerformanceData(
        response.messagesPerSecond,
        response.averageLatencyMs,
        response.maxLatencyMs,
        response.totalMessages,
        response.droppedMessages,
        List.from(_recentLatencies),
      );
      
      // Log performance metrics
      _logger.info('Performance: ${response.messagesPerSecond} msg/s, '
                  'avg latency: ${response.averageLatencyMs.toStringAsFixed(2)}ms, '
                  'max latency: ${response.maxLatencyMs.toStringAsFixed(2)}ms');
      
      _emitCurrentState(emit);
    }
  }
  
  void _emitCurrentState(Emitter<IsolateCommunicationState> emit) {
    emit(IsolateCommunicationWithData(
      List.from(_messages),
      _isConnected,
      _currentPerformanceData,
      _highFrequencyTestRunning,
    ));
  }
  
  void _cleanup() {
    _isolateSubscription?.cancel();
    _receivePort?.close();
    _communicationIsolate?.kill();
    
    _isolateSubscription = null;
    _receivePort = null;
    _isolateSendPort = null;
    _communicationIsolate = null;
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