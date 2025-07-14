

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart'; // Required for SystemNavigator

// --- BLoC Definition ---

// Events
abstract class MachineEvent {}

class UpdatePosition extends MachineEvent {
  final int position;
  UpdatePosition(this.position);
}

// States
class MachineState {
  final int position;
  MachineState(this.position);
}

// BLoC
class MachineBloc extends Bloc<MachineEvent, MachineState> {
  MachineBloc() : super(MachineState(0)) {
    on<UpdatePosition>((event, emit) {
      emit(MachineState(event.position));
    });
  }
}

// --- Mock Service ---

class MockDataService {
  final MachineBloc _machineBloc;
  Timer? _timer;
  int _counter = 0;

  MockDataService(this._machineBloc);

  void startStreaming(int eventFrequencyMs) {
    _timer = Timer.periodic(Duration(milliseconds: eventFrequencyMs), (timer) {
      _counter++;
      _machineBloc.add(UpdatePosition(_counter));
    });
  }

  void stopStreaming() {
    _timer?.cancel();
  }
}

// --- Main Application ---

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'State Management Stress Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BlocProvider(
        create: (_) => MachineBloc(),
        child: const StateManagementScreen(),
      ),
    );
  }
}

class StateManagementScreen extends StatefulWidget {
  const StateManagementScreen({super.key});

  @override
  State<StateManagementScreen> createState() => _StateManagementScreenState();
}

class _StateManagementScreenState extends State<StateManagementScreen> {
  late MockDataService _mockDataService;
  static const int _eventFrequencyMs = 10; // Event every 10ms
  static const int _measurementDurationSeconds = 10; // Run for 10 seconds
  DateTime _startTime = DateTime.now();
  int _initialPosition = 0;
  int _finalPosition = 0;

  @override
  void initState() {
    super.initState();
    _mockDataService = MockDataService(BlocProvider.of<MachineBloc>(context));
    _startTime = DateTime.now();

    // Get initial position to calculate total events
    _initialPosition = BlocProvider.of<MachineBloc>(context).state.position;

    _mockDataService.startStreaming(_eventFrequencyMs);

    // Timer to stop streaming and report results
    Timer(const Duration(seconds: _measurementDurationSeconds), () async {
      _mockDataService.stopStreaming();
      // Add a small delay to allow pending events to be processed
      await Future.delayed(const Duration(milliseconds: 1000)); // Increased delay to 1 second
      _finalPosition = BlocProvider.of<MachineBloc>(context).state.position;
      _reportAndExit();
    });
  }

  void _reportAndExit() {
    final int totalEvents = _finalPosition - _initialPosition;
    final double expectedEvents = (_measurementDurationSeconds * 1000) / _eventFrequencyMs;
    final double eventLossPercentage = ((expectedEvents - totalEvents) / expectedEvents) * 100;

    print('--- State Management Stress Test Results ---');
    print('Event Frequency: $_eventFrequencyMs ms');
    print('Measurement Duration: $_measurementDurationSeconds seconds');
    print('Total Events Processed: $totalEvents');
    print('Expected Events: ${expectedEvents.toStringAsFixed(0)}');
    print('Event Loss Percentage: ${eventLossPercentage.toStringAsFixed(2)}%');
    print('----------------------------------------');
    SystemNavigator.pop(); // Exit the application
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('State Management Stress Test'),
      ),
      body: Center(
        child: BlocBuilder<MachineBloc, MachineState>(
          builder: (context, state) {
            return Text(
              'Position: ${state.position}',
              style: Theme.of(context).textTheme.headlineMedium,
            );
          },
        ),
      ),
    );
  }
}
