import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:logging/logging.dart';

// Messages sent from main thread to communication isolate
abstract class IsolateMessage {}

class ConnectMessage extends IsolateMessage {
  final String host;
  final int port;
  final SendPort responsePort;
  ConnectMessage(this.host, this.port, this.responsePort);
}

class DisconnectMessage extends IsolateMessage {}

class SendCommandMessage extends IsolateMessage {
  final String command;
  final DateTime timestamp;
  final int commandId;
  SendCommandMessage(this.command, this.timestamp, this.commandId);
}

class StartHighFrequencyTestMessage extends IsolateMessage {
  final int durationSeconds;
  final int intervalMs;
  StartHighFrequencyTestMessage(this.durationSeconds, this.intervalMs);
}

class StopHighFrequencyTestMessage extends IsolateMessage {}

// Messages sent from communication isolate to main thread
abstract class IsolateResponse {}

class ConnectionStatusResponse extends IsolateResponse {
  final bool connected;
  final String? error;
  ConnectionStatusResponse(this.connected, [this.error]);
}

class MessageReceivedResponse extends IsolateResponse {
  final String message;
  final DateTime timestamp;
  MessageReceivedResponse(this.message, this.timestamp);
}

class CommandResponseReceived extends IsolateResponse {
  final String response;
  final DateTime timestamp;
  final int commandId;
  final int latencyMs;
  CommandResponseReceived(this.response, this.timestamp, this.commandId, this.latencyMs);
}

class PerformanceMetrics extends IsolateResponse {
  final int messagesPerSecond;
  final double averageLatencyMs;
  final double maxLatencyMs;
  final int totalMessages;
  final int droppedMessages;
  PerformanceMetrics(this.messagesPerSecond, this.averageLatencyMs, 
                     this.maxLatencyMs, this.totalMessages, this.droppedMessages);
}

class HeartbeatMetrics extends IsolateResponse {
  final DateTime timestamp;
  final int heartbeatNumber;
  final double latencyMs;
  HeartbeatMetrics(this.timestamp, this.heartbeatNumber, this.latencyMs);
}

// Communication isolate implementation
class CommunicationIsolate {
  static void entryPoint(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);
    
    final isolate = _CommunicationIsolateImpl(mainSendPort);
    receivePort.listen((message) {
      isolate.handleMessage(message);
    });
  }
}

class _CommunicationIsolateImpl {
  final SendPort _mainSendPort;
  Socket? _socket;
  StreamSubscription? _socketSubscription;
  final Map<int, DateTime> _pendingCommands = {};
  final List<double> _latencies = [];
  Timer? _heartbeatTimer;
  Timer? _metricsTimer;
  Timer? _highFrequencyTimer;
  
  // Performance tracking
  int _messageCount = 0;
  int _droppedMessages = 0;
  int _heartbeatCount = 0;
  DateTime? _testStartTime;
  bool _highFrequencyTestRunning = false;
  
  final Logger _logger = Logger('CommunicationIsolate');
  
  _CommunicationIsolateImpl(this._mainSendPort) {
    // Setup logging in isolate
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      print('[ISOLATE] ${record.level.name}: ${record.message}');
    });
    
    _logger.info('Communication isolate started');
    
    // Start metrics reporting timer
    _metricsTimer = Timer.periodic(Duration(seconds: 1), (_) => _reportMetrics());
  }
  
  void handleMessage(dynamic message) {
    if (message is ConnectMessage) {
      _connect(message.host, message.port);
    } else if (message is DisconnectMessage) {
      _disconnect();
    } else if (message is SendCommandMessage) {
      _sendCommand(message.command, message.timestamp, message.commandId);
    } else if (message is StartHighFrequencyTestMessage) {
      _startHighFrequencyTest(message.durationSeconds, message.intervalMs);
    } else if (message is StopHighFrequencyTestMessage) {
      _stopHighFrequencyTest();
    }
  }
  
  Future<void> _connect(String host, int port) async {
    try {
      _logger.info('Connecting to $host:$port from isolate');
      _socket = await Socket.connect(host, port);
      
      _socketSubscription = _socket!.listen(
        _onDataReceived,
        onError: _onError,
        onDone: _onDisconnected,
      );
      
      _mainSendPort.send(ConnectionStatusResponse(true));
      _logger.info('Connected successfully from isolate');
      
      // Start heartbeat
      _startHeartbeat();
      
    } catch (e) {
      _logger.severe('Connection failed: $e');
      _mainSendPort.send(ConnectionStatusResponse(false, e.toString()));
    }
  }
  
  void _disconnect() {
    _logger.info('Disconnecting from isolate');
    _stopHeartbeat();
    _stopHighFrequencyTest();
    _socketSubscription?.cancel();
    _socket?.destroy();
    _socket = null;
    _mainSendPort.send(ConnectionStatusResponse(false));
  }
  
  void _onDataReceived(List<int> data) {
    final now = DateTime.now();
    final message = utf8.decode(data).trim();
    
    if (message.isEmpty) return;
    
    _messageCount++;
    _logger.fine('Received: $message');
    
    // Check if this is an echoed comment with timestamp for latency measurement
    if (message.startsWith('(PING:')) {
      // Parse: (PING:commandId:timestamp)
      final match = RegExp(r'\(PING:(\d+):(\d+)\)').firstMatch(message);
      if (match != null) {
        final commandId = int.parse(match.group(1)!);
        final sentTimestamp = int.parse(match.group(2)!);
        final receivedTimestamp = now.millisecondsSinceEpoch;
        final latency = receivedTimestamp - sentTimestamp; // Precise millisecond measurement
        
        _latencies.add(latency.toDouble());
        // Keep only last 1000 latencies for averaging
        if (_latencies.length > 1000) {
          _latencies.removeAt(0);
        }
        
        // Remove from pending commands
        _pendingCommands.remove(commandId);
        
        _mainSendPort.send(CommandResponseReceived(
          message, now, commandId, latency
        ));
        
        _logger.fine('PING $commandId latency: ${latency}ms');
      }
    }
    // Check if this is a response to a pending command (for non-timestamp commands)
    else if (message == 'ok' || message.startsWith('error:')) {
      // Only match ok/error to pending commands if not during high-frequency test
      if (!_highFrequencyTestRunning && _pendingCommands.isNotEmpty) {
        final commandId = _pendingCommands.keys.first;
        final sentTime = _pendingCommands.remove(commandId)!;
        final latency = now.difference(sentTime).inMicroseconds / 1000.0; // ms with microsecond precision
        
        _latencies.add(latency);
        // Keep only last 1000 latencies for averaging
        if (_latencies.length > 1000) {
          _latencies.removeAt(0);
        }
        
        _mainSendPort.send(CommandResponseReceived(
          message, now, commandId, latency.round()
        ));
        
        _logger.fine('Command $commandId latency: ${latency.toStringAsFixed(3)}ms');
      }
    }
    
    // Send all received messages to main thread
    _mainSendPort.send(MessageReceivedResponse(message, now));
  }
  
  void _onError(error) {
    _logger.severe('Socket error: $error');
    _mainSendPort.send(ConnectionStatusResponse(false, error.toString()));
  }
  
  void _onDisconnected() {
    _logger.info('Socket disconnected');
    _disconnect();
  }
  
  void _sendCommand(String command, DateTime timestamp, int commandId) {
    if (_socket == null) {
      _logger.warning('Cannot send command - not connected');
      return;
    }
    
    try {
      final commandWithNewline = command + '\r\n';
      _socket!.write(commandWithNewline);
      
      // Track pending command for latency measurement
      _pendingCommands[commandId] = timestamp;
      
      _logger.fine('Sent command $commandId: "$command"');
    } catch (e) {
      _logger.severe('Error sending command: $e');
      _pendingCommands.remove(commandId);
    }
  }
  
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(Duration(milliseconds: 200), (timer) {
      if (_socket != null && !_highFrequencyTestRunning) {
        _heartbeatCount++;
        final timestamp = DateTime.now();
        _sendCommand('?', timestamp, -_heartbeatCount); // Negative IDs for heartbeats
      }
    });
    _logger.info('Heartbeat started (200ms interval)');
  }
  
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _logger.info('Heartbeat stopped');
  }
  
  void _startHighFrequencyTest(int durationSeconds, int intervalMs) {
    if (_socket == null) {
      _logger.warning('Cannot start high frequency test - not connected');
      return;
    }
    
    _logger.info('Starting high frequency test: ${durationSeconds}s duration, ${intervalMs}ms interval');
    _highFrequencyTestRunning = true;
    _testStartTime = DateTime.now();
    _messageCount = 0;
    _droppedMessages = 0;
    _latencies.clear();
    
    // Stop regular heartbeat during test
    _stopHeartbeat();
    
    var commandCounter = 10000; // Start high to avoid collision with regular commands
    
    _highFrequencyTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (DateTime.now().difference(_testStartTime!).inSeconds >= durationSeconds) {
        _stopHighFrequencyTest();
        return;
      }
      
      commandCounter++;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Use G-Code comment with timestamp for precise latency measurement
      final command = '(PING:$commandCounter:$timestamp)';
      _sendCommand(command, DateTime.now(), commandCounter);
    });
  }
  
  void _stopHighFrequencyTest() {
    if (!_highFrequencyTestRunning) return;
    
    _logger.info('Stopping high frequency test');
    _highFrequencyTestRunning = false;
    _highFrequencyTimer?.cancel();
    _highFrequencyTimer = null;
    
    // Resume regular heartbeat
    _startHeartbeat();
    
    _reportFinalTestMetrics();
  }
  
  void _reportMetrics() {
    final avgLatency = _latencies.isEmpty ? 0.0 : 
      _latencies.reduce((a, b) => a + b) / _latencies.length;
    final maxLatency = _latencies.isEmpty ? 0.0 : _latencies.reduce((a, b) => a > b ? a : b);
    
    _mainSendPort.send(PerformanceMetrics(
      _messageCount,
      avgLatency,
      maxLatency,
      _messageCount,
      _droppedMessages
    ));
    
    // Reset counter for next second
    _messageCount = 0;
  }
  
  void _reportFinalTestMetrics() {
    final testDuration = _testStartTime != null 
      ? DateTime.now().difference(_testStartTime!).inMilliseconds / 1000.0
      : 0.0;
    
    final avgLatency = _latencies.isEmpty ? 0.0 : 
      _latencies.reduce((a, b) => a + b) / _latencies.length;
    final maxLatency = _latencies.isEmpty ? 0.0 : _latencies.reduce((a, b) => a > b ? a : b);
    
    _logger.info('=== HIGH FREQUENCY TEST RESULTS ===');
    _logger.info('Test duration: ${testDuration.toStringAsFixed(1)}s');
    _logger.info('Total messages: ${_latencies.length}');
    _logger.info('Average latency: ${avgLatency.toStringAsFixed(3)}ms');
    _logger.info('Max latency: ${maxLatency.toStringAsFixed(3)}ms');
    _logger.info('Messages/sec: ${(_latencies.length / testDuration).toStringAsFixed(1)}');
    _logger.info('Dropped messages: $_droppedMessages');
    
    // Check if we meet the <20ms requirement
    final meetsCriteria = avgLatency < 20.0 && maxLatency < 50.0; // Allow some tolerance on max
    _logger.info('LATENCY REQUIREMENT (<20ms avg): ${meetsCriteria ? "✅ PASS" : "❌ FAIL"}');
  }
}