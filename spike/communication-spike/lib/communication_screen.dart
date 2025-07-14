import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'communication_bloc.dart';
import 'logger.dart';

class CommunicationScreen extends StatefulWidget {
  @override
  _CommunicationScreenState createState() => _CommunicationScreenState();
}

class _CommunicationScreenState extends State<CommunicationScreen> {
  static final _logger = AppLogger.ui;
  
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  ConnectionType _selectedType = ConnectionType.tcp;

  @override
  void initState() {
    super.initState();
    _logger.info('Communication screen initialized');
    // Default to grblHAL simulator
    _hostController.text = '192.168.77.177';
    _portController.text = '8081';
    _logger.info('Default connection set to ${_hostController.text}:${_portController.text} via ${_selectedType.name}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('grblHAL Communication Test'),
        backgroundColor: Colors.blue[100],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Connection section
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Connection',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 16),
                    
                    // Connection type selector
                    Row(
                      children: [
                        Text('Protocol: '),
                        Radio<ConnectionType>(
                          value: ConnectionType.tcp,
                          groupValue: _selectedType,
                          onChanged: (ConnectionType? value) {
                            setState(() {
                              _selectedType = value!;
                              if (_selectedType == ConnectionType.tcp) {
                                _portController.text = '8081';
                              } else {
                                _portController.text = '8080';
                              }
                            });
                          },
                        ),
                        Text('TCP/Telnet'),
                        Radio<ConnectionType>(
                          value: ConnectionType.websocket,
                          groupValue: _selectedType,
                          onChanged: (ConnectionType? value) {
                            setState(() {
                              _selectedType = value!;
                              if (_selectedType == ConnectionType.tcp) {
                                _portController.text = '8081';
                              } else {
                                _portController.text = '8080';
                              }
                            });
                          },
                        ),
                        Text('WebSocket'),
                      ],
                    ),
                    
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
                    BlocBuilder<CommunicationBloc, CommunicationState>(
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
            ),
            SizedBox(height: 16),
            
            // Quick grblHAL commands
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Quick grblHAL Commands',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: () => _sendQuickCommand('\$\$'),
                          child: Text('\$\$ (Settings)'),
                        ),
                        ElevatedButton(
                          onPressed: () => _sendQuickCommand('?'),
                          child: Text('? (Status)'),
                        ),
                        ElevatedButton(
                          onPressed: () => _sendQuickCommand('\$I'),
                          child: Text('\$I (Build Info)'),
                        ),
                        ElevatedButton(
                          onPressed: () => _sendQuickCommand('\$#'),
                          child: Text('\$# (Parameters)'),
                        ),
                        ElevatedButton(
                          onPressed: () => _sendQuickCommand('\$G'),
                          child: Text('\$G (Parser State)'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // Message sending section
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Send Custom Command',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              labelText: 'G-code or grblHAL command',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        BlocBuilder<CommunicationBloc, CommunicationState>(
                          builder: (context, state) {
                            return ElevatedButton(
                              onPressed: _isConnected(state) ? _sendMessage : null,
                              child: Text('Send'),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // Messages section
            Expanded(
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Communication Log',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    Expanded(
                      child: BlocBuilder<CommunicationBloc, CommunicationState>(
                        builder: (context, state) {
                          if (state is CommunicationMessageReceived) {
                            return ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              itemCount: state.messages.length,
                              itemBuilder: (context, index) {
                                final message = state.messages[index];
                                final isReceived = message.startsWith('Received:');
                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 2.0),
                                  child: Text(
                                    message,
                                    style: TextStyle(
                                      color: isReceived ? Colors.blue : Colors.green,
                                      fontFamily: 'monospace',
                                      fontSize: 12,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  VoidCallback? _getConnectionButtonAction(CommunicationState state) {
    if (state is CommunicationConnecting) return null;
    if (_isConnected(state)) return _disconnect;
    return _connect;
  }

  String _getConnectionButtonText(CommunicationState state) {
    if (state is CommunicationConnecting) return 'Connecting...';
    if (_isConnected(state)) return 'Disconnect';
    return 'Connect';
  }

  Widget _getConnectionStatus(CommunicationState state) {
    Color color;
    String text;
    
    if (state is CommunicationConnecting) {
      color = Colors.orange;
      text = 'Connecting';
    } else if (_isConnected(state)) {
      color = Colors.green;
      text = 'Connected';
      if (state is CommunicationConnected) {
        text += ' (${state.type.name.toUpperCase()})';
      }
    } else if (state is CommunicationError) {
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

  bool _isConnected(CommunicationState state) {
    return state is CommunicationConnected || 
           (state is CommunicationMessageReceived && state.isConnected);
  }

  void _connect() {
    final host = _hostController.text;
    final port = int.tryParse(_portController.text) ?? 8081;
    _logger.info('UI: User initiated connection to $host:$port via ${_selectedType.name}');
    context.read<CommunicationBloc>().add(ConnectEvent(host, port, _selectedType));
  }

  void _disconnect() {
    _logger.info('UI: User initiated disconnect');
    context.read<CommunicationBloc>().add(DisconnectEvent());
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      final message = _messageController.text;
      _logger.info('UI: User sending custom message: "$message"');
      context.read<CommunicationBloc>().add(SendMessageEvent(message));
      _messageController.clear();
    }
  }

  void _sendQuickCommand(String command) {
    if (_isConnected(context.read<CommunicationBloc>().state)) {
      _logger.info('UI: User sending quick command: "$command"');
      context.read<CommunicationBloc>().add(SendMessageEvent(command));
    } else {
      _logger.warning('UI: User attempted to send quick command while disconnected: "$command"');
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}