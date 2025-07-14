import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'communication_bloc.dart';
import 'communication_screen.dart';
import 'logger.dart';

void main() {
  // Initialize logging first
  final appLogger = AppLogger.getLogger('MAIN');
  appLogger.info('=== ghSender Communication Test Starting ===');
  appLogger.info('Flutter version: ${const String.fromEnvironment('FLUTTER_VERSION', defaultValue: 'unknown')}');
  appLogger.info('Build mode: ${const String.fromEnvironment('FLUTTER_BUILD_MODE', defaultValue: 'unknown')}');
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'grblHAL Communication Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: BlocProvider(
        create: (context) => CommunicationBloc(),
        child: CommunicationScreen(),
      ),
    );
  }
}