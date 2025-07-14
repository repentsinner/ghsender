import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'isolate_communication_bloc.dart';
import 'logger.dart';

class IsolateTestScreen extends StatefulWidget {
  @override
  _IsolateTestScreenState createState() => _IsolateTestScreenState();
}

class _IsolateTestScreenState extends State<IsolateTestScreen> {
  static final _logger = AppLogger.ui;
  
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _testDurationController = TextEditingController();
  final TextEditingController _testIntervalController = TextEditingController();
  
  Timer? _uiMetricsTimer;
  Map<String, dynamic> _uiMetrics = {};
  
  @override
  void initState() {
    super.initState();
    _logger.info('IsolateTestScreen initialized');
    
    // Default values
    _hostController.text = '192.168.77.177';
    _portController.text = '8081';
    _testDurationController.text = '10';
    _testIntervalController.text = '5';
    
    // Start UI metrics monitoring
    _uiMetricsTimer = Timer.periodic(Duration(milliseconds: 100), (_) {
      final bloc = context.read<IsolateCommunicationBloc>();
      setState(() {
        _uiMetrics = bloc.getUIPerformanceMetrics();
      });
    });
  }
  
  @override
  void dispose() {
    _uiMetricsTimer?.cancel();
    _hostController.dispose();
    _portController.dispose();
    _messageController.dispose();
    _testDurationController.dispose();
    _testIntervalController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Isolate Communication Test'),
        backgroundColor: Colors.purple[100],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Connection Section
            _buildConnectionSection(),
            SizedBox(height: 16),
            
            // Performance Metrics Section
            _buildPerformanceSection(),
            SizedBox(height: 16),
            
            // High Frequency Test Section
            _buildHighFrequencyTestSection(),
            SizedBox(height: 16),
            
            // Manual Commands Section
            _buildManualCommandsSection(),
            SizedBox(height: 16),
            
            // Messages Section
            Expanded(child: _buildMessagesSection()),
          ],
        ),
      ),
    );
  }
  
  Widget _buildConnectionSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Isolate Communication', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _hostController,
                    decoration: InputDecoration(
                      labelText: 'Host/IP',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _portController,
                    decoration: InputDecoration(
                      labelText: 'Port',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            BlocBuilder<IsolateCommunicationBloc, IsolateCommunicationState>(
              builder: (context, state) {
                return Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _getConnectionButtonAction(state),
                        child: Text(_getConnectionButtonText(state)),
                      ),
                    ),
                    SizedBox(width: 8),
                    _getConnectionStatus(state),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPerformanceSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Performance Metrics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            BlocBuilder<IsolateCommunicationBloc, IsolateCommunicationState>(
              builder: (context, state) {
                if (state is IsolateCommunicationWithData && state.performanceData != null) {
                  final perf = state.performanceData!;
                  return Column(
                    children: [
                      _buildMetricRow('Messages/sec', '${perf.messagesPerSecond}', Colors.blue),
                      _buildMetricRow('Avg Latency', '${perf.averageLatencyMs.toStringAsFixed(2)}ms', 
                        perf.meetsLatencyRequirement ? Colors.green : Colors.red),
                      _buildMetricRow('Max Latency', '${perf.maxLatencyMs.toStringAsFixed(2)}ms', Colors.orange),
                      _buildMetricRow('Total Messages', '${perf.totalMessages}', Colors.blue),
                      _buildMetricRow('Dropped Messages', '${perf.droppedMessages}', Colors.red),
                      _buildMetricRow('Latency Requirement', perf.latencyStatus, 
                        perf.meetsLatencyRequirement ? Colors.green : Colors.red),
                    ],
                  );
                }
                return Text('No performance data available');
              },
            ),
            SizedBox(height: 8),
            Text('UI Thread Performance', style: TextStyle(fontWeight: FontWeight.bold)),
            _buildMetricRow('Avg Frame Time', '${(_uiMetrics['avgFrameTime'] ?? 0.0).toStringAsFixed(2)}ms', 
              (_uiMetrics['uiThreadBlocked'] ?? false) ? Colors.red : Colors.green),
            _buildMetricRow('Max Frame Time', '${(_uiMetrics['maxFrameTime'] ?? 0.0).toStringAsFixed(2)}ms', Colors.orange),
            _buildMetricRow('Framerate', '${(_uiMetrics['framerate'] ?? 0.0).toStringAsFixed(1)} fps', 
              (_uiMetrics['framerate'] ?? 0.0) >= 55.0 ? Colors.green : Colors.red),
            _buildMetricRow('Jank Frames', '${_uiMetrics['jankFrames'] ?? 0}', 
              (_uiMetrics['jankFrames'] ?? 0) == 0 ? Colors.green : Colors.red),
            _buildMetricRow('UI Thread Status', 
              (_uiMetrics['uiThreadBlocked'] ?? false) ? '❌ BLOCKED' : '✅ RESPONSIVE',
              (_uiMetrics['uiThreadBlocked'] ?? false) ? Colors.red : Colors.green),
          ],
        ),
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
  
  Widget _buildHighFrequencyTestSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('High Frequency Communication Test', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _testDurationController,
                    decoration: InputDecoration(
                      labelText: 'Duration (seconds)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _testIntervalController,
                    decoration: InputDecoration(
                      labelText: 'Interval (ms)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            BlocBuilder<IsolateCommunicationBloc, IsolateCommunicationState>(
              builder: (context, state) {
                final isConnected = _isConnected(state);
                final testRunning = state is IsolateCommunicationWithData && state.highFrequencyTestRunning;
                
                return Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isConnected && !testRunning ? _startHighFrequencyTest : null,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: Text('Start Test'),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: testRunning ? _stopHighFrequencyTest : null,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: Text('Stop Test'),
                      ),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: 8),
            Text(
              'This test validates:\n'
              '• <20ms latency requirement\n'
              '• UI thread remains responsive (60fps)\n'
              '• No message drops during high-frequency communication\n'
              '• Dart Isolates handle TCP communication without blocking UI',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildManualCommandsSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Manual Commands', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _sendQuickCommand('\$\$'),
                  child: Text('\$\$ (Settings)', style: TextStyle(fontSize: 10)),
                ),
                ElevatedButton(
                  onPressed: () => _sendQuickCommand('?'),
                  child: Text('? (Status)', style: TextStyle(fontSize: 10)),
                ),
                ElevatedButton(
                  onPressed: () => _sendQuickCommand('\$I'),
                  child: Text('\$I (Build Info)', style: TextStyle(fontSize: 10)),
                ),
                ElevatedButton(
                  onPressed: () => _sendQuickCommand('\$G'),
                  child: Text('\$G (Parser State)', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      labelText: 'Custom command',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                BlocBuilder<IsolateCommunicationBloc, IsolateCommunicationState>(
                  builder: (context, state) {
                    return ElevatedButton(
                      onPressed: _isConnected(state) ? _sendCustomCommand : null,
                      child: Text('Send'),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMessagesSection() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Communication Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: BlocBuilder<IsolateCommunicationBloc, IsolateCommunicationState>(
              builder: (context, state) {
                if (state is IsolateCommunicationWithData) {
                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      final isReceived = message.startsWith('Received:');
                      final isResponse = message.contains('Response [');
                      final isTest = message.contains('===');
                      
                      Color textColor = Colors.black;
                      if (isReceived) textColor = Colors.blue;
                      else if (isResponse) textColor = Colors.green;
                      else if (isTest) textColor = Colors.purple;
                      
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 1.0),
                        child: Text(
                          message,
                          style: TextStyle(
                            color: textColor,
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  );
                }
                return Center(child: Text('No messages yet'));
              },
            ),
          ),
        ],
      ),
    );
  }
  
  VoidCallback? _getConnectionButtonAction(IsolateCommunicationState state) {
    if (state is IsolateCommunicationConnecting) return null;
    if (_isConnected(state)) return _disconnect;
    return _connect;
  }
  
  String _getConnectionButtonText(IsolateCommunicationState state) {
    if (state is IsolateCommunicationConnecting) return 'Connecting...';
    if (_isConnected(state)) return 'Disconnect';
    return 'Connect';
  }
  
  Widget _getConnectionStatus(IsolateCommunicationState state) {
    Color color;
    String text;
    
    if (state is IsolateCommunicationConnecting) {
      color = Colors.orange;
      text = 'Connecting';
    } else if (_isConnected(state)) {
      color = Colors.green;
      text = 'Connected (Isolate)';
    } else if (state is IsolateCommunicationError) {
      color = Colors.red;
      text = 'Error';
    } else {
      color = Colors.grey;
      text = 'Disconnected';
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
  
  bool _isConnected(IsolateCommunicationState state) {
    return state is IsolateCommunicationConnected || 
           (state is IsolateCommunicationWithData && state.isConnected);
  }
  
  void _connect() {
    final host = _hostController.text;
    final port = int.tryParse(_portController.text) ?? 8081;
    _logger.info('UI: User initiated isolate connection to $host:$port');
    context.read<IsolateCommunicationBloc>().add(IsolateConnectEvent(host, port));
  }
  
  void _disconnect() {
    _logger.info('UI: User initiated isolate disconnect');
    context.read<IsolateCommunicationBloc>().add(IsolateDisconnectEvent());
  }
  
  void _sendCustomCommand() {
    if (_messageController.text.isNotEmpty) {
      final command = _messageController.text;
      _logger.info('UI: User sending custom command: "$command"');
      context.read<IsolateCommunicationBloc>().add(IsolateSendCommandEvent(command));
      _messageController.clear();
    }
  }
  
  void _sendQuickCommand(String command) {
    final bloc = context.read<IsolateCommunicationBloc>();
    if (_isConnected(bloc.state)) {
      _logger.info('UI: User sending quick command: "$command"');
      bloc.add(IsolateSendCommandEvent(command));
    }
  }
  
  void _startHighFrequencyTest() {
    final duration = int.tryParse(_testDurationController.text) ?? 10;
    final interval = int.tryParse(_testIntervalController.text) ?? 5;
    
    _logger.info('UI: Starting high frequency test: ${duration}s duration, ${interval}ms interval');
    context.read<IsolateCommunicationBloc>().add(
      IsolateStartHighFrequencyTestEvent(duration, interval)
    );
  }
  
  void _stopHighFrequencyTest() {
    _logger.info('UI: Stopping high frequency test');
    context.read<IsolateCommunicationBloc>().add(IsolateStopHighFrequencyTestEvent());
  }
}