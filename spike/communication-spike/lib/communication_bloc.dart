import 'dart:io';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:logging/logging.dart';
import 'logger.dart';

// Connection Types
enum ConnectionType { websocket, tcp }

// Events
abstract class CommunicationEvent {}

class ConnectEvent extends CommunicationEvent {
  final String host;
  final int port;
  final ConnectionType type;
  ConnectEvent(this.host, this.port, this.type);
}

class DisconnectEvent extends CommunicationEvent {}

class SendMessageEvent extends CommunicationEvent {
  final String message;
  SendMessageEvent(this.message);
}

class MessageReceivedEvent extends CommunicationEvent {
  final String message;
  MessageReceivedEvent(this.message);
}

// States
abstract class CommunicationState {}

class CommunicationInitial extends CommunicationState {}

class CommunicationConnecting extends CommunicationState {}

class CommunicationConnected extends CommunicationState {
  final String host;
  final int port;
  final ConnectionType type;
  CommunicationConnected(this.host, this.port, this.type);
}

class CommunicationDisconnected extends CommunicationState {}

class CommunicationError extends CommunicationState {
  final String error;
  CommunicationError(this.error);
}

class CommunicationMessageReceived extends CommunicationState {
  final List<String> messages;
  final bool isConnected;
  final ConnectionType? connectionType;
  CommunicationMessageReceived(this.messages, this.isConnected, [this.connectionType]);
}

// BLoC
class CommunicationBloc extends Bloc<CommunicationEvent, CommunicationState> {
  static final Logger _logger = AppLogger.communication;
  
  WebSocketChannel? _webSocketChannel;
  Socket? _tcpSocket;
  final List<String> _messages = [];
  bool _isConnected = false;
  ConnectionType? _currentConnectionType;

  CommunicationBloc() : super(CommunicationInitial()) {
    _logger.info('CommunicationBloc initialized');
    on<ConnectEvent>(_onConnect);
    on<DisconnectEvent>(_onDisconnect);
    on<SendMessageEvent>(_onSendMessage);
    on<MessageReceivedEvent>(_onMessageReceived);
  }

  void _onConnect(ConnectEvent event, Emitter<CommunicationState> emit) async {
    _logger.info('Attempting to connect: ${event.type.name} to ${event.host}:${event.port}');
    try {
      emit(CommunicationConnecting());
      
      if (event.type == ConnectionType.websocket) {
        await _connectWebSocket(event.host, event.port);
      } else {
        await _connectTcp(event.host, event.port);
      }
      
      _isConnected = true;
      _currentConnectionType = event.type;
      _logger.info('Successfully connected via ${event.type.name} to ${event.host}:${event.port}');
      emit(CommunicationConnected(event.host, event.port, event.type));
      emit(CommunicationMessageReceived(List.from(_messages), _isConnected, _currentConnectionType));
    } catch (e, stackTrace) {
      _logger.severe('Connection failed: $e', e, stackTrace);
      emit(CommunicationError('Failed to connect: $e'));
    }
  }

  Future<void> _connectWebSocket(String host, int port) async {
    final uri = Uri.parse('ws://$host:$port');
    final wsLogger = AppLogger.websocket;
    
    wsLogger.info('Connecting to WebSocket: $uri');
    _webSocketChannel = WebSocketChannel.connect(uri);
    
    _webSocketChannel!.stream.listen(
      (data) {
        wsLogger.fine('WebSocket received: $data');
        add(MessageReceivedEvent(data.toString()));
      },
      onError: (error) {
        wsLogger.severe('WebSocket error: $error');
        add(DisconnectEvent());
      },
      onDone: () {
        wsLogger.info('WebSocket connection closed');
        add(DisconnectEvent());
      },
    );
    wsLogger.info('WebSocket connection established');
  }

  Future<void> _connectTcp(String host, int port) async {
    final tcpLogger = AppLogger.tcp;
    
    tcpLogger.info('Connecting to TCP: $host:$port');
    _tcpSocket = await Socket.connect(host, port);
    tcpLogger.info('TCP connection established to $host:$port');
    
    _tcpSocket!.listen(
      (data) {
        final message = utf8.decode(data).trim();
        tcpLogger.fine('TCP received (${data.length} bytes): $message');
        if (message.isNotEmpty) {
          add(MessageReceivedEvent(message));
        }
      },
      onError: (error) {
        tcpLogger.severe('TCP error: $error');
        add(DisconnectEvent());
      },
      onDone: () {
        tcpLogger.info('TCP connection closed');
        add(DisconnectEvent());
      },
    );
  }

  void _onDisconnect(DisconnectEvent event, Emitter<CommunicationState> emit) {
    _logger.info('Disconnecting from ${_currentConnectionType?.name ?? "unknown"} connection');
    
    if (_webSocketChannel != null) {
      AppLogger.websocket.info('Closing WebSocket connection');
      _webSocketChannel!.sink.close(status.goingAway);
      _webSocketChannel = null;
    }
    if (_tcpSocket != null) {
      AppLogger.tcp.info('Destroying TCP socket');
      _tcpSocket!.destroy();
      _tcpSocket = null;
    }
    
    _isConnected = false;
    _currentConnectionType = null;
    _logger.info('Disconnected successfully');
    emit(CommunicationDisconnected());
    emit(CommunicationMessageReceived(List.from(_messages), _isConnected));
  }

  void _onSendMessage(SendMessageEvent event, Emitter<CommunicationState> emit) {
    final grblLogger = AppLogger.grblhal;
    
    if (_isConnected) {
      grblLogger.info('Sending command: "${event.message}"');
      
      if (_webSocketChannel != null) {
        AppLogger.websocket.fine('Sending via WebSocket: ${event.message}');
        _webSocketChannel!.sink.add(event.message);
      } else if (_tcpSocket != null) {
        final messageToSend = event.message + '\r\n'; // Add CRLF for grblHAL
        AppLogger.tcp.fine('Sending via TCP: "$messageToSend" (${messageToSend.length} bytes)');
        _tcpSocket!.write(messageToSend);
      }
      
      _messages.add('Sent: ${event.message}');
      emit(CommunicationMessageReceived(List.from(_messages), _isConnected, _currentConnectionType));
    } else {
      _logger.warning('Attempted to send message while disconnected: ${event.message}');
    }
  }

  void _onMessageReceived(MessageReceivedEvent event, Emitter<CommunicationState> emit) {
    AppLogger.grblhal.info('Received response: "${event.message}"');
    _messages.add('Received: ${event.message}');
    emit(CommunicationMessageReceived(List.from(_messages), _isConnected, _currentConnectionType));
  }

  @override
  Future<void> close() {
    if (_webSocketChannel != null) {
      _webSocketChannel!.sink.close();
    }
    if (_tcpSocket != null) {
      _tcpSocket!.destroy();
    }
    return super.close();
  }
}