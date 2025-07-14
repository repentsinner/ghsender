import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'communication_bloc.dart';
import 'communication_screen.dart';
import 'isolate_communication_bloc.dart';
import 'isolate_test_screen.dart';
import 'automated_test_screen.dart';
import 'logger.dart';

void main() {
  // Initialize logging first
  final appLogger = AppLogger.getLogger('MAIN');
  appLogger.info('=== ghSender Framework Validation Spike ===');
  appLogger.info('Flutter version: ${const String.fromEnvironment('FLUTTER_VERSION', defaultValue: 'unknown')}');
  appLogger.info('Build mode: ${const String.fromEnvironment('FLUTTER_BUILD_MODE', defaultValue: 'unknown')}');
  appLogger.info('Running automated framework validation test');
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Framework Validation Spike',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: true,
      ),
      home: BlocProvider(
        create: (context) => IsolateCommunicationBloc(),
        child: AutomatedTestScreen(),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('grblHAL Communication Spike'),
        backgroundColor: Colors.blue[100],
      ),
      body: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(Icons.science, size: 64, color: Colors.blue),
                    SizedBox(height: 16),
                    Text(
                      'Framework Validation Spike',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Validating Dart Isolates for high-frequency TCP communication',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 32),
            
            // Main Thread Communication (Original)
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Main Thread Communication', 
                             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('TCP communication on UI thread (violates architecture)',
                         style: TextStyle(color: Colors.grey[600])),
                    SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BlocProvider(
                              create: (context) => CommunicationBloc(),
                              child: CommunicationScreen(),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: Text('Test Main Thread Communication'),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Isolate Communication (Correct Architecture)
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Isolate Communication', 
                             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('TCP communication in separate Dart Isolate (correct architecture)',
                         style: TextStyle(color: Colors.grey[600])),
                    SizedBox(height: 8),
                    Text('• <20ms latency validation\n• UI thread responsiveness (60fps)\n• High-frequency stress testing\n• Performance instrumentation',
                         style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                    SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BlocProvider(
                              create: (context) => IsolateCommunicationBloc(),
                              child: IsolateTestScreen(),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: Text('Test Isolate Communication'),
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
}