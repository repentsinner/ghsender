import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'isolate_communication_bloc.dart';
import 'logger.dart';

class AutomatedTestScreen extends StatefulWidget {
  @override
  _AutomatedTestScreenState createState() => _AutomatedTestScreenState();
}

class _AutomatedTestScreenState extends State<AutomatedTestScreen> {
  static final _logger = AppLogger.ui;
  
  Timer? _testSequenceTimer;
  Timer? _uiMetricsTimer;
  Map<String, dynamic> _uiMetrics = {};
  
  // Test configuration
  static const String DEFAULT_HOST = '192.168.77.177';
  static const int DEFAULT_PORT = 8081;
  static const int TEST_DURATION_SECONDS = 5;
  static const int TEST_INTERVAL_MS = 20;
  
  // Test state tracking
  TestPhase _currentPhase = TestPhase.initializing;
  DateTime? _testStartTime;
  List<String> _testResults = [];
  Map<String, dynamic> _finalMetrics = {};
  
  @override
  void initState() {
    super.initState();
    _logger.info('AutomatedTestScreen initialized - Starting automated validation');
    
    // Start UI performance monitoring
    _startUIMetricsMonitoring();
    
    // Start automated test sequence after a brief delay
    Timer(Duration(seconds: 2), _startAutomatedTestSequence);
  }
  
  @override
  void dispose() {
    _testSequenceTimer?.cancel();
    _uiMetricsTimer?.cancel();
    super.dispose();
  }
  
  void _startUIMetricsMonitoring() {
    _uiMetricsTimer = Timer.periodic(Duration(milliseconds: 100), (_) {
      final bloc = context.read<IsolateCommunicationBloc>();
      setState(() {
        _uiMetrics = bloc.getUIPerformanceMetrics();
      });
    });
  }
  
  void _startAutomatedTestSequence() {
    _logger.info('=== STARTING AUTOMATED FRAMEWORK VALIDATION ===');
    _logger.info('Target: $DEFAULT_HOST:$DEFAULT_PORT');
    _logger.info('High-frequency test: ${TEST_DURATION_SECONDS}s @ ${TEST_INTERVAL_MS}ms interval');
    
    _updateTestPhase(TestPhase.connecting);
    
    // Step 1: Connect to simulator
    context.read<IsolateCommunicationBloc>().add(
      IsolateConnectEvent(DEFAULT_HOST, DEFAULT_PORT)
    );
    
    // Set up test sequence timer to monitor progress
    _testSequenceTimer = Timer.periodic(Duration(seconds: 1), _checkTestProgress);
  }
  
  void _checkTestProgress(Timer timer) {
    final bloc = context.read<IsolateCommunicationBloc>();
    final state = bloc.state;
    
    switch (_currentPhase) {
      case TestPhase.connecting:
        if (state is IsolateCommunicationConnected) {
          _logger.info('✅ Connection established - starting baseline test');
          _updateTestPhase(TestPhase.baseline);
          _scheduleBaslineTest();
        } else if (state is IsolateCommunicationError) {
          _logger.severe('❌ Connection failed: ${state.error}');
          _updateTestPhase(TestPhase.failed);
          timer.cancel();
        }
        break;
        
      case TestPhase.baseline:
        // Baseline test runs for 5 seconds, will auto-transition
        break;
        
      case TestPhase.highFrequency:
        // High frequency test runs for configured duration
        if (state is IsolateCommunicationWithData && !state.highFrequencyTestRunning) {
          _logger.info('✅ High-frequency test completed - analyzing results');
          _updateTestPhase(TestPhase.analyzing);
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
  
  void _scheduleBaslineTest() {
    // Send a few manual commands to establish baseline
    Timer(Duration(seconds: 1), () {
      _logger.info('Sending baseline commands...');
      final bloc = context.read<IsolateCommunicationBloc>();
      bloc.add(IsolateSendCommandEvent('\$\$'));
    });
    
    Timer(Duration(seconds: 2), () {
      final bloc = context.read<IsolateCommunicationBloc>();
      bloc.add(IsolateSendCommandEvent('?'));
    });
    
    Timer(Duration(seconds: 3), () {
      final bloc = context.read<IsolateCommunicationBloc>();
      bloc.add(IsolateSendCommandEvent('\$I'));
    });
    
    // Start high-frequency test after baseline
    Timer(Duration(seconds: 5), () {
      _logger.info('✅ Baseline complete - starting high-frequency stress test');
      _updateTestPhase(TestPhase.highFrequency);
      _testStartTime = DateTime.now();
      
      context.read<IsolateCommunicationBloc>().add(
        IsolateStartHighFrequencyTestEvent(TEST_DURATION_SECONDS, TEST_INTERVAL_MS)
      );
    });
  }
  
  void _analyzeResults(IsolateCommunicationWithData state) {
    final testDuration = _testStartTime != null 
      ? DateTime.now().difference(_testStartTime!).inMilliseconds / 1000.0
      : 0.0;
    
    final perf = state.performanceData;
    final uiMetrics = _uiMetrics;
    
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
    
    _logger.info('=== SPIKE 1 VALIDATION RESULTS ===');
    _logger.info('1. TCP in Dart Isolate: ✅ PASS (isolate communication working)');
    _logger.info('2. <20ms Latency: ${latencyPass ? "✅ PASS" : "❌ FAIL"}');
    _logger.info('3. UI Thread Responsive: ${uiResponsive ? "✅ PASS" : "❌ FAIL"}');
    _logger.info('4. 60fps Performance: ${frameratePass ? "✅ PASS" : "❌ FAIL"}');
    _logger.info('5. No Message Drops: ${noDrops ? "✅ PASS" : "❌ FAIL"}');
    
    final overallPass = latencyPass && uiResponsive && frameratePass && noDrops;
    _logger.info('=== OVERALL RESULT ===');
    _logger.info('Framework Validation: ${overallPass ? "✅ PASS" : "❌ FAIL"}');
    
    if (!overallPass) {
      _logger.warning('RECOMMENDATION: Consider triggering ADR-011 framework re-evaluation');
    } else {
      _logger.info('RECOMMENDATION: Flutter/Dart/Isolate architecture validated for production');
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
    };
    
    _updateTestPhase(TestPhase.completed);
  }
  
  void _updateTestPhase(TestPhase phase) {
    setState(() {
      _currentPhase = phase;
    });
    _logger.info('Test Phase: ${phase.name.toUpperCase()}');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Automated Framework Validation'),
        backgroundColor: Colors.purple[100],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Test Status
            _buildTestStatusCard(),
            SizedBox(height: 16),
            
            // Real-time Metrics
            _buildMetricsCard(),
            SizedBox(height: 16),
            
            // Live Logs
            Expanded(child: _buildLogsCard()),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTestStatusCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Test Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Row(
              children: [
                _getPhaseIcon(_currentPhase),
                SizedBox(width: 8),
                Text(_getPhaseDescription(_currentPhase)),
              ],
            ),
            if (_currentPhase == TestPhase.completed) ...[
              SizedBox(height: 8),
              Text(
                'Overall Result: ${_finalMetrics['overallPass'] == true ? "✅ PASS" : "❌ FAIL"}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _finalMetrics['overallPass'] == true ? Colors.green : Colors.red,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetricsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Real-time Metrics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            BlocBuilder<IsolateCommunicationBloc, IsolateCommunicationState>(
              builder: (context, state) {
                if (state is IsolateCommunicationWithData && state.performanceData != null) {
                  final perf = state.performanceData!;
                  return Column(
                    children: [
                      _buildMetricRow('Avg Latency', '${perf.averageLatencyMs.toStringAsFixed(2)}ms', 
                        perf.meetsLatencyRequirement ? Colors.green : Colors.red),
                      _buildMetricRow('Messages/sec', '${perf.messagesPerSecond}', Colors.blue),
                      _buildMetricRow('UI Framerate', '${(_uiMetrics['framerate'] ?? 0.0).toStringAsFixed(1)} fps', 
                        (_uiMetrics['framerate'] ?? 0.0) >= 55.0 ? Colors.green : Colors.red),
                      _buildMetricRow('UI Status', 
                        (_uiMetrics['uiThreadBlocked'] ?? false) ? '❌ BLOCKED' : '✅ RESPONSIVE',
                        (_uiMetrics['uiThreadBlocked'] ?? false) ? Colors.red : Colors.green),
                    ],
                  );
                }
                return Text('Waiting for data...');
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLogsCard() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Live Test Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: BlocBuilder<IsolateCommunicationBloc, IsolateCommunicationState>(
              builder: (context, state) {
                if (state is IsolateCommunicationWithData) {
                  // Show only recent messages (last 20)
                  final recentMessages = state.messages.length > 20 
                    ? state.messages.sublist(state.messages.length - 20)
                    : state.messages;
                    
                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: recentMessages.length,
                    itemBuilder: (context, index) {
                      final message = recentMessages[index];
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 1.0),
                        child: Text(
                          message,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: _getMessageColor(message),
                          ),
                        ),
                      );
                    },
                  );
                }
                return Center(child: Text('Initializing test...'));
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetricRow(String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12)),
          Text(value, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  Icon _getPhaseIcon(TestPhase phase) {
    switch (phase) {
      case TestPhase.initializing:
        return Icon(Icons.hourglass_empty, color: Colors.grey);
      case TestPhase.connecting:
        return Icon(Icons.wifi_find, color: Colors.orange);
      case TestPhase.baseline:
        return Icon(Icons.speed, color: Colors.blue);
      case TestPhase.highFrequency:
        return Icon(Icons.flash_on, color: Colors.purple);
      case TestPhase.analyzing:
        return Icon(Icons.analytics, color: Colors.indigo);
      case TestPhase.completed:
        return Icon(Icons.check_circle, color: Colors.green);
      case TestPhase.failed:
        return Icon(Icons.error, color: Colors.red);
    }
  }
  
  String _getPhaseDescription(TestPhase phase) {
    switch (phase) {
      case TestPhase.initializing:
        return 'Initializing test environment...';
      case TestPhase.connecting:
        return 'Connecting to grblHAL simulator...';
      case TestPhase.baseline:
        return 'Running baseline communication test...';
      case TestPhase.highFrequency:
        return 'Running high-frequency stress test...';
      case TestPhase.analyzing:
        return 'Analyzing test results...';
      case TestPhase.completed:
        return 'Test completed - see logs for results';
      case TestPhase.failed:
        return 'Test failed - connection error';
    }
  }
  
  Color _getMessageColor(String message) {
    if (message.contains('✅') || message.contains('PASS')) return Colors.green;
    if (message.contains('❌') || message.contains('FAIL')) return Colors.red;
    if (message.contains('===')) return Colors.purple;
    if (message.startsWith('Received:')) return Colors.blue;
    if (message.contains('Response [')) return Colors.green;
    return Colors.black87;
  }
}

enum TestPhase {
  initializing,
  connecting,
  baseline,
  highFrequency,
  analyzing,
  completed,
  failed,
}