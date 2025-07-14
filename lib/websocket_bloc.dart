import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

// Events
abstract class WebSocketEvent {}

class ConnectEvent extends WebSocketEvent {
  final String url;
  ConnectEvent(this.url);
}

class DisconnectEvent extends WebSocketEvent {}

class SendMessageEvent extends WebSocketEvent {
  final String message;
  SendMessageEvent(this.message);
}

class MessageReceivedEvent extends WebSocketEvent {
  final String message;
  MessageReceivedEvent(this.message);
}

// States
abstract class WebSocketState {}

class WebSocketInitial extends WebSocketState {}

class WebSocketConnecting extends WebSocketState {}

class WebSocketConnected extends WebSocketState {
  final String url;
  WebSocketConnected(this.url);
}

class WebSocketDisconnected extends WebSocketState {}

class WebSocketError extends WebSocketState {
  final String error;
  WebSocketError(this.error);
}

class WebSocketMessageReceived extends WebSocketState {
  final List<String> messages;
  final bool isConnected;
  WebSocketMessageReceived(this.messages, this.isConnected);
}

// BLoC
class WebSocketBloc extends Bloc<WebSocketEvent, WebSocketState> {
  WebSocketChannel? _channel;
  final List<String> _messages = [];
  bool _isConnected = false;

  WebSocketBloc() : super(WebSocketInitial()) {
    on<ConnectEvent>(_onConnect);
    on<DisconnectEvent>(_onDisconnect);
    on<SendMessageEvent>(_onSendMessage);
    on<MessageReceivedEvent>(_onMessageReceived);
  }

  void _onConnect(ConnectEvent event, Emitter<WebSocketState> emit) async {
    try {
      emit(WebSocketConnecting());
      
      _channel = WebSocketChannel.connect(Uri.parse(event.url));
      
      // Listen for messages
      _channel!.stream.listen(
        (data) {
          add(MessageReceivedEvent(data.toString()));
        },
        onError: (error) {
          add(DisconnectEvent());
        },
        onDone: () {
          add(DisconnectEvent());
        },
      );
      
      _isConnected = true;
      emit(WebSocketConnected(event.url));
      emit(WebSocketMessageReceived(List.from(_messages), _isConnected));
    } catch (e) {
      emit(WebSocketError('Failed to connect: $e'));
    }
  }

  void _onDisconnect(DisconnectEvent event, Emitter<WebSocketState> emit) {
    if (_channel != null) {
      _channel!.sink.close(status.goingAway);
      _channel = null;
    }
    _isConnected = false;
    emit(WebSocketDisconnected());
    emit(WebSocketMessageReceived(List.from(_messages), _isConnected));
  }

  void _onSendMessage(SendMessageEvent event, Emitter<WebSocketState> emit) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(event.message);
      _messages.add('Sent: ${event.message}');
      emit(WebSocketMessageReceived(List.from(_messages), _isConnected));
    }
  }

  void _onMessageReceived(MessageReceivedEvent event, Emitter<WebSocketState> emit) {
    _messages.add('Received: ${event.message}');
    emit(WebSocketMessageReceived(List.from(_messages), _isConnected));
  }

  @override
  Future<void> close() {
    if (_channel != null) {
      _channel!.sink.close();
    }
    return super.close();
  }
}