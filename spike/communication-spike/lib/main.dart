import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'grbl_communication_bloc.dart';
import 'framework_validation_screen.dart';
import 'logger.dart';

void main() {
  // Initialize logging first
  final appLogger = AppLogger.getLogger('MAIN');
  appLogger.info('=== ghSender Framework Validation Spike ===');
  appLogger.info('Flutter version: ${const String.fromEnvironment('FLUTTER_VERSION', defaultValue: 'unknown')}');
  appLogger.info('Build mode: ${const String.fromEnvironment('FLUTTER_BUILD_MODE', defaultValue: 'unknown')}');
  appLogger.info('Running automated framework validation test');
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Framework Validation Spike',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: true,
      ),
      home: BlocProvider(
        create: (context) => GrblCommunicationBloc(),
        child: FrameworkValidationScreen(),
      ),
    );
  }
}

