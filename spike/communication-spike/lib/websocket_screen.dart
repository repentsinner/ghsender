import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'websocket_bloc.dart';

class WebSocketScreen extends StatefulWidget {
  @override
  _WebSocketScreenState createState() => _WebSocketScreenState();
}

class _WebSocketScreenState extends State<WebSocketScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default to grblHAL simulator
    _urlController.text = 'ws://192.168.77.177:8081';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WebSocket Communication Spike'),
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
                    SizedBox(height: 8),
                    TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        labelText: 'WebSocket URL',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 8),
                    BlocBuilder<WebSocketBloc, WebSocketState>(
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
            
            // Message sending section
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Send Message',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              labelText: 'Message',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        BlocBuilder<WebSocketBloc, WebSocketState>(
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
                        'Messages',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    Expanded(
                      child: BlocBuilder<WebSocketBloc, WebSocketState>(
                        builder: (context, state) {
                          if (state is WebSocketMessageReceived) {
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

  VoidCallback? _getConnectionButtonAction(WebSocketState state) {
    if (state is WebSocketConnecting) return null;
    if (_isConnected(state)) return _disconnect;
    return _connect;
  }

  String _getConnectionButtonText(WebSocketState state) {
    if (state is WebSocketConnecting) return 'Connecting...';
    if (_isConnected(state)) return 'Disconnect';
    return 'Connect';
  }

  Widget _getConnectionStatus(WebSocketState state) {
    Color color;
    String text;
    
    if (state is WebSocketConnecting) {
      color = Colors.orange;
      text = 'Connecting';
    } else if (_isConnected(state)) {
      color = Colors.green;
      text = 'Connected';
    } else if (state is WebSocketError) {
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
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  bool _isConnected(WebSocketState state) {
    return state is WebSocketConnected || 
           (state is WebSocketMessageReceived && state.isConnected);
  }

  void _connect() {
    context.read<WebSocketBloc>().add(ConnectEvent(_urlController.text));
  }

  void _disconnect() {
    context.read<WebSocketBloc>().add(DisconnectEvent());
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      context.read<WebSocketBloc>().add(SendMessageEvent(_messageController.text));
      _messageController.clear();
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}