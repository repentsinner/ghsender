import 'dart:io';

void main() async {
  final server = await HttpServer.bind('localhost', 8080);
  // ignore: avoid_print
  print('WebSocket test server running on ws://localhost:8080');
  // ignore: avoid_print
  print('Simulating grblHAL communication patterns...');

  await for (HttpRequest request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      final websocket = await WebSocketTransformer.upgrade(request);
      // ignore: avoid_print
      print('Client connected: ${request.connectionInfo?.remoteAddress}');
      
      // Simulate grblHAL welcome message
      websocket.add('Grbl 1.1f [\'\$\' for help]');
      
      websocket.listen(
        (message) {
          // ignore: avoid_print
          print('Received: $message');
          
          // Simulate grblHAL responses
          if (message == '\$\$') {
            // Settings request
            websocket.add('\$\$');
            websocket.add('\$0=10');
            websocket.add('\$1=25');
            websocket.add('\$2=0');
            websocket.add('\$3=0');
            websocket.add('ok');
          } else if (message == '?') {
            // Status request
            websocket.add('<Idle|MPos:0.000,0.000,0.000|FS:0,0>');
          } else if (message.startsWith('G') || message.startsWith('M')) {
            // G-code command
            websocket.add('ok');
          } else if (message == '\$\$') {
            // Settings request
            websocket.add('ok');
          } else {
            // Echo other messages
            websocket.add('Echo: $message');
          }
        },
        onError: (error) {
          // ignore: avoid_print
          print('WebSocket error: $error');
        },
        onDone: () {
          // ignore: avoid_print
          print('Client disconnected');
        },
      );
    }
  }
}