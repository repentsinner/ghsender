import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'grbl_communication_bloc.dart';
import 'framework_test_orchestrator.dart';
import 'logger.dart';

class FrameworkValidationScreen extends StatefulWidget {
  const FrameworkValidationScreen({super.key});
  
  @override
  State<FrameworkValidationScreen> createState() => _FrameworkValidationScreenState();
}

class _FrameworkValidationScreenState extends State<FrameworkValidationScreen> {
  static final _logger = AppLogger.ui;
  
  Timer? _uiMetricsTimer;
  Map<String, dynamic> _uiMetrics = {};
  FrameworkTestOrchestrator? _testOrchestrator;
  
  // Test state tracking
  TestPhase _currentPhase = TestPhase.initializing;
  Map<String, dynamic> _finalMetrics = {};
  
  @override
  void initState() {
    super.initState();
    _logger.info('FrameworkValidationScreen initialized - Starting automated validation');
    
    // Initialize test orchestrator
    _testOrchestrator = FrameworkTestOrchestrator(context.read<GrblCommunicationBloc>());
    
    // Listen to phase changes
    _testOrchestrator!.phaseStream.listen((phase) {
      setState(() {
        _currentPhase = phase;
      });
    });
    
    // Listen to metrics updates
    _testOrchestrator!.metricsStream.listen((metrics) {
      setState(() {
        _finalMetrics = metrics;
      });
    });
    
    // Start UI performance monitoring
    _startUIMetricsMonitoring();
    
    // Start automated test sequence after a brief delay
    Timer(Duration(seconds: 2), () {
      _testOrchestrator?.startAutomatedValidation();
    });
  }
  
  @override
  void dispose() {
    _testOrchestrator?.dispose();
    _uiMetricsTimer?.cancel();
    super.dispose();
  }
  
  void _startUIMetricsMonitoring() {
    _uiMetricsTimer = Timer.periodic(Duration(milliseconds: 100), (_) {
      final bloc = context.read<GrblCommunicationBloc>();
      setState(() {
        _uiMetrics = bloc.getUIPerformanceMetrics();
      });
    });
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
            BlocBuilder<GrblCommunicationBloc, GrblCommunicationState>(
              builder: (context, state) {
                if (state is GrblCommunicationWithData) {
                  List<Widget> metrics = [];
                  
                  // Add jog test status if running
                  if (state.jogTestRunning) {
                    metrics.add(_buildMetricRow('Jog Test Status', 
                      'Running...', 
                      Colors.blue));
                  }
                  
                  // Add performance metrics if available
                  if (state.performanceData != null) {
                    final perf = state.performanceData!;
                    metrics.addAll([
                      _buildMetricRow('Avg Latency', '${perf.averageLatencyMs.toStringAsFixed(2)}ms', 
                        perf.meetsLatencyRequirement ? Colors.green : Colors.red),
                      _buildMetricRow('Messages/sec', '${perf.messagesPerSecond}', Colors.blue),
                    ]);
                  }
                  
                  // Add UI metrics
                  metrics.addAll([
                    _buildMetricRow('UI Framerate', '${(_uiMetrics['framerate'] ?? 0.0).toStringAsFixed(1)} fps', 
                      (_uiMetrics['framerate'] ?? 0.0) >= 55.0 ? Colors.green : Colors.red),
                    _buildMetricRow('UI Status', 
                      (_uiMetrics['uiThreadBlocked'] ?? false) ? '❌ BLOCKED' : '✅ RESPONSIVE',
                      (_uiMetrics['uiThreadBlocked'] ?? false) ? Colors.red : Colors.green),
                  ]);
                  
                  return Column(children: metrics);
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
            child: BlocBuilder<GrblCommunicationBloc, GrblCommunicationState>(
              builder: (context, state) {
                if (state is GrblCommunicationWithData) {
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
      case TestPhase.jogTest:
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
    return phase.description;
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

