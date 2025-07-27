import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:integration_test/integration_test.dart';

import '../lib/main.dart';
import '../lib/grbl_communication_bloc.dart';
import '../lib/framework_validation_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Framework Validation Tests', () {
    testWidgets('Complete automated framework validation', (WidgetTester tester) async {
      // Launch the app
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();

      // Verify initial screen loads
      expect(find.text('Automated Framework Validation'), findsOneWidget);
      expect(find.text('Initializing test environment...'), findsOneWidget);

      // Wait for connection phase
      await tester.pump(Duration(seconds: 3));
      expect(find.text('Connecting to grblHAL simulator...'), findsOneWidget);

      // Wait for baseline test phase
      await tester.pump(Duration(seconds: 5));
      expect(find.text('Running baseline communication test...'), findsOneWidget);

      // Wait for jog test phase
      await tester.pump(Duration(seconds: 3));
      expect(find.text('Running jog responsiveness test...'), findsOneWidget);

      // Wait for jog test completion (10 seconds + buffer)
      await tester.pump(Duration(seconds: 12));
      
      // Verify test completed successfully
      expect(find.text('Test completed - see logs for results'), findsOneWidget);
      
      // Check that performance metrics are displayed
      expect(find.textContaining('Avg Latency'), findsOneWidget);
      expect(find.textContaining('fps'), findsOneWidget);
      expect(find.textContaining('RESPONSIVE'), findsOneWidget);
    });

    testWidgets('grblHAL communication latency test', (WidgetTester tester) async {
      final bloc = GrblCommunicationBloc();
      
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: bloc,
            child: FrameworkValidationScreen(),
          ),
        ),
      );

      // Connect to WebSocket
      bloc.add(GrblConnectEvent('ws://192.168.77.87:80'));
      await tester.pump(Duration(seconds: 2));

      // Verify connection
      expect(bloc.state, isA<GrblCommunicationConnected>());

      // Send test commands and measure latency
      bloc.add(GrblSendCommandEvent('?'));
      await tester.pump(Duration(milliseconds: 100));

      // Verify command was processed
      final state = bloc.state as GrblCommunicationWithData;
      expect(state.isConnected, true);
      expect(state.messages.any((msg) => msg.contains('Sent: ?')), true);

      // Cleanup
      bloc.add(GrblDisconnectEvent());
      await bloc.close();
    });

    testWidgets('Jog test responsiveness validation', (WidgetTester tester) async {
      final bloc = GrblCommunicationBloc();
      
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: bloc,
            child: FrameworkValidationScreen(),
          ),
        ),
      );

      // Connect first
      bloc.add(GrblConnectEvent('ws://192.168.77.87:80'));
      await tester.pump(Duration(seconds: 2));

      // Start jog test
      bloc.add(GrblStartJogTestEvent(5, 2.0, 500)); // 5 second test
      await tester.pump(Duration(milliseconds: 100));

      // Verify jog test started
      var state = bloc.state as GrblCommunicationWithData;
      expect(state.jogTestRunning, true);

      // Wait for test progression
      await tester.pump(Duration(seconds: 2));
      state = bloc.state as GrblCommunicationWithData;
      expect(state.jogTestRunning, true);

      // Wait for completion
      await tester.pump(Duration(seconds: 4));
      state = bloc.state as GrblCommunicationWithData;
      expect(state.jogTestRunning, false);

      // Cleanup
      bloc.add(GrblDisconnectEvent());
      await bloc.close();
    });

    testWidgets('UI performance monitoring', (WidgetTester tester) async {
      final bloc = GrblCommunicationBloc();
      
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: bloc,
            child: FrameworkValidationScreen(),
          ),
        ),
      );

      // Let UI performance monitoring run
      await tester.pump(Duration(seconds: 1));

      // Check UI performance metrics
      final uiMetrics = bloc.getUIPerformanceMetrics();
      expect(uiMetrics['avgFrameTime'], isA<double>());
      expect(uiMetrics['framerate'], isA<double>());
      expect(uiMetrics['uiThreadBlocked'], isA<bool>());

      await bloc.close();
    });
  });

  group('grblHAL Communication Tests', () {
    late GrblCommunicationBloc bloc;

    setUp(() {
      bloc = GrblCommunicationBloc();
    });

    tearDown(() async {
      await bloc.close();
    });

    test('WebSocket connection establishes successfully', () async {
      bloc.add(GrblConnectEvent('ws://192.168.77.87:80'));
      
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<GrblCommunicationConnecting>(),
          isA<GrblCommunicationConnected>(),
        ]),
      );
    });

    test('Command sending and response handling', () async {
      bloc.add(GrblConnectEvent('ws://192.168.77.87:80'));
      
      // Wait for connection
      await bloc.stream.firstWhere((state) => state is GrblCommunicationConnected);
      
      bloc.add(GrblSendCommandEvent('\$\$'));
      
      // Verify command was processed
      final state = await bloc.stream
          .firstWhere((state) => state is GrblCommunicationWithData)
          .then((state) => state as GrblCommunicationWithData);
      
      expect(state.messages.any((msg) => msg.contains('Sent: \$\$')), true);
    });

    test('Performance metrics generation', () async {
      bloc.add(GrblConnectEvent('ws://192.168.77.87:80'));
      
      // Wait for connection and some data
      await bloc.stream.firstWhere((state) => state is GrblCommunicationConnected);
      
      // Send a few commands to generate metrics
      bloc.add(GrblSendCommandEvent('?'));
      bloc.add(GrblSendCommandEvent('\$\$'));
      
      await Future.delayed(Duration(seconds: 1));
      
      final state = await bloc.stream
          .firstWhere((state) => 
              state is GrblCommunicationWithData && 
              state.performanceData != null)
          .then((state) => state as GrblCommunicationWithData);
      
      expect(state.performanceData!.averageLatencyMs, greaterThan(0));
      expect(state.performanceData!.totalMessages, greaterThan(0));
    });
  });
}