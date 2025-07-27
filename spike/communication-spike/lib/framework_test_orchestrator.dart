import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'grbl_communication_bloc.dart';
import 'logger.dart';

enum TestPhase {
  initializing,
  connecting,
  baseline,
  jogTest,
  analyzing,
  completed,
  failed,
}

class FrameworkTestOrchestrator {
  static final Logger _logger = AppLogger.ui;
  
  final GrblCommunicationBloc _communicationBloc;
  final StreamController<TestPhase> _phaseController = StreamController<TestPhase>.broadcast();
  final StreamController<Map<String, dynamic>> _metricsController = StreamController<Map<String, dynamic>>.broadcast();
  
  TestPhase _currentPhase = TestPhase.initializing;
  DateTime? _testStartTime;
  Timer? _testSequenceTimer;
  Map<String, dynamic> _finalMetrics = {};
  
  // Test configuration
  static const String defaultHost = '192.168.77.87';
  static const int defaultPort = 80;
  static const int jogTestDurationSeconds = 10;
  static const double jogDistanceMm = 2.0;
  static const int jogFeedRateMmMin = 500;

  FrameworkTestOrchestrator(this._communicationBloc);

  Stream<TestPhase> get phaseStream => _phaseController.stream;
  Stream<Map<String, dynamic>> get metricsStream => _metricsController.stream;
  TestPhase get currentPhase => _currentPhase;
  Map<String, dynamic> get finalMetrics => _finalMetrics;

  void startAutomatedValidation() {
    _logger.info('=== STARTING AUTOMATED FRAMEWORK VALIDATION ===');
    _logger.info('Target: ws://$defaultHost:$defaultPort');
    _logger.info('Jog responsiveness test: ${jogTestDurationSeconds}s duration, ${jogDistanceMm}mm jogs @ ${jogFeedRateMmMin}mm/min');
    
    _updatePhase(TestPhase.connecting);
    
    // Connect to grblHAL simulator
    final wsUrl = 'ws://$defaultHost:$defaultPort';
    _communicationBloc.add(GrblConnectEvent(wsUrl));
    
    // Monitor test progress
    _testSequenceTimer = Timer.periodic(Duration(seconds: 1), _checkTestProgress);
  }

  void _checkTestProgress(Timer timer) {
    final state = _communicationBloc.state;
    
    switch (_currentPhase) {
      case TestPhase.connecting:
        if (state is GrblCommunicationConnected || 
            (state is GrblCommunicationWithData && state.isConnected)) {
          _logger.info('✅ Connection established - starting baseline test');
          _updatePhase(TestPhase.baseline);
          _scheduleBaselineTest();
        } else if (state is GrblCommunicationError) {
          _logger.severe('❌ Connection failed: ${state.error}');
          _updatePhase(TestPhase.failed);
          timer.cancel();
        }
        break;
        
      case TestPhase.baseline:
        // Baseline test runs for 5 seconds, will auto-transition
        break;
        
      case TestPhase.jogTest:
        if (state is GrblCommunicationWithData && !state.jogTestRunning) {
          _logger.info('✅ Jog responsiveness test completed - analyzing results');
          _updatePhase(TestPhase.analyzing);
          _analyzeResults(state);
          timer.cancel();
        }
        break;
        
      case TestPhase.analyzing:
      case TestPhase.completed:
      case TestPhase.failed:
        timer.cancel();
        break;
        
      case TestPhase.initializing:
        // Still waiting for initialization
        break;
    }
  }

  void _scheduleBaselineTest() {
    // Send baseline commands to establish communication pattern
    Timer(Duration(seconds: 1), () {
      _logger.info('Sending baseline commands...');
      _communicationBloc.add(GrblSendCommandEvent('\$\$'));
    });
    
    Timer(Duration(seconds: 2), () {
      _communicationBloc.add(GrblSendCommandEvent('?'));
    });
    
    Timer(Duration(seconds: 3), () {
      _communicationBloc.add(GrblSendCommandEvent('\$I'));
    });
    
    // Start jog test after baseline
    Timer(Duration(seconds: 5), () {
      _logger.info('✅ Baseline complete - starting jog responsiveness test');
      _updatePhase(TestPhase.jogTest);
      _testStartTime = DateTime.now();
      
      _communicationBloc.add(GrblStartJogTestEvent(
        jogTestDurationSeconds, 
        jogDistanceMm, 
        jogFeedRateMmMin
      ));
    });
  }

  void _analyzeResults(GrblCommunicationWithData state) {
    final testDuration = _testStartTime != null 
      ? DateTime.now().difference(_testStartTime!).inMilliseconds / 1000.0
      : 0.0;
    
    final perf = state.performanceData;
    final uiMetrics = _communicationBloc.getUIPerformanceMetrics();
    
    _logger.info('=== FRAMEWORK VALIDATION RESULTS ===');
    
    // Performance Analysis
    if (perf != null) {
      _logger.info('Communication Performance:');
      _logger.info('  Messages/sec: ${perf.messagesPerSecond}');
      _logger.info('  Avg Latency: ${perf.averageLatencyMs.toStringAsFixed(3)}ms');
      _logger.info('  Max Latency: ${perf.maxLatencyMs.toStringAsFixed(3)}ms');
      _logger.info('  Total Messages: ${perf.totalMessages}');
      _logger.info('  Dropped Messages: ${perf.droppedMessages}');
      _logger.info('  Latency Requirement (<20ms): ${perf.latencyStatus}');
    }
    
    // UI Performance Analysis
    _logger.info('UI Thread Performance:');
    _logger.info('  Avg Frame Time: ${(uiMetrics['avgFrameTime'] ?? 0.0).toStringAsFixed(3)}ms');
    _logger.info('  Max Frame Time: ${(uiMetrics['maxFrameTime'] ?? 0.0).toStringAsFixed(3)}ms');
    _logger.info('  Framerate: ${(uiMetrics['framerate'] ?? 0.0).toStringAsFixed(1)} fps');
    _logger.info('  Jank Frames: ${uiMetrics['jankFrames'] ?? 0}');
    _logger.info('  UI Thread Status: ${(uiMetrics['uiThreadBlocked'] ?? false) ? "❌ BLOCKED" : "✅ RESPONSIVE"}');
    
    // Framework Validation Results
    final latencyPass = perf?.meetsLatencyRequirement ?? false;
    final uiResponsive = !(uiMetrics['uiThreadBlocked'] ?? true);
    final framerate = uiMetrics['framerate'] ?? 0.0;
    final frameratePass = framerate >= 55.0;
    final noDrops = (perf?.droppedMessages ?? 1) == 0;
    
    _logger.info('=== FRAMEWORK VALIDATION SUMMARY ===');
    _logger.info('1. WebSocket Communication: ✅ PASS (WebSocket communication working)');
    _logger.info('2. <20ms Latency: ${latencyPass ? "✅ PASS" : "❌ FAIL"}');
    _logger.info('3. UI Thread Responsive: ${uiResponsive ? "✅ PASS" : "❌ FAIL"}');
    _logger.info('4. 60fps Performance: ${frameratePass ? "✅ PASS" : "❌ FAIL"}');
    _logger.info('5. No Message Drops: ${noDrops ? "✅ PASS" : "❌ FAIL"}');
    
    final overallPass = latencyPass && uiResponsive && frameratePass && noDrops;
    _logger.info('=== OVERALL RESULT ===');
    _logger.info('Framework Validation: ${overallPass ? "✅ PASS" : "❌ FAIL"}');
    
    if (!overallPass) {
      _logger.warning('RECOMMENDATION: Consider framework optimization or architecture changes');
    } else {
      _logger.info('RECOMMENDATION: Flutter/Dart/WebSocket architecture validated for production');
    }
    
    _finalMetrics = {
      'latencyPass': latencyPass,
      'uiResponsive': uiResponsive,
      'frameratePass': frameratePass,
      'noDrops': noDrops,
      'overallPass': overallPass,
      'avgLatency': perf?.averageLatencyMs ?? 0.0,
      'maxLatency': perf?.maxLatencyMs ?? 0.0,
      'framerate': framerate,
      'jankFrames': uiMetrics['jankFrames'] ?? 0,
      'testDuration': testDuration,
    };
    
    _metricsController.add(_finalMetrics);
    _updatePhase(TestPhase.completed);
  }

  void _updatePhase(TestPhase phase) {
    _currentPhase = phase;
    _phaseController.add(phase);
    _logger.info('Test Phase: ${phase.name.toUpperCase()}');
  }

  void stopTest() {
    _testSequenceTimer?.cancel();
    _communicationBloc.add(GrblStopJogTestEvent());
    _communicationBloc.add(GrblDisconnectEvent());
  }

  void dispose() {
    _testSequenceTimer?.cancel();
    _phaseController.close();
    _metricsController.close();
  }
}

// Helper extension for phase descriptions
extension TestPhaseDescription on TestPhase {
  String get description {
    switch (this) {
      case TestPhase.initializing:
        return 'Initializing test environment...';
      case TestPhase.connecting:
        return 'Connecting to grblHAL simulator...';
      case TestPhase.baseline:
        return 'Running baseline communication test...';
      case TestPhase.jogTest:
        return 'Running jog responsiveness test...';
      case TestPhase.analyzing:
        return 'Analyzing test results...';
      case TestPhase.completed:
        return 'Test completed - see logs for results';
      case TestPhase.failed:
        return 'Test failed - connection error';
    }
  }

  String get icon {
    switch (this) {
      case TestPhase.initializing:
        return '⏳';
      case TestPhase.connecting:
        return '🔌';
      case TestPhase.baseline:
        return '📊';
      case TestPhase.jogTest:
        return '⚡';
      case TestPhase.analyzing:
        return '🔍';
      case TestPhase.completed:
        return '✅';
      case TestPhase.failed:
        return '❌';
    }
  }
}