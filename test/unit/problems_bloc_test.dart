import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:ghsender/bloc/problems/problems_bloc.dart';
import 'package:ghsender/domain/enums/machine_status.dart';
import 'package:ghsender/bloc/problems/problems_event.dart';
import 'package:ghsender/bloc/problems/problems_state.dart';
import 'package:ghsender/bloc/machine_controller/machine_controller_state.dart';
import 'package:ghsender/domain/entities/problem.dart';
import 'package:ghsender/models/machine_controller.dart';

void main() {
  group('ProblemsBloc Door Open Detection', () {
    late ProblemsBloc problemsBloc;

    setUp(() {
      problemsBloc = ProblemsBloc();
    });

    tearDown(() {
      problemsBloc.close();
    });

    blocTest<ProblemsBloc, ProblemsState>(
      'adds door open problem when machine status is door',
      build: () => problemsBloc,
      act: (bloc) {
        // Create a MachineController with door status
        final controller = MachineController(
          controllerId: 'test-controller',
          status: MachineStatus.door,
          isOnline: true,
          lastCommunication: DateTime.now(),
        );
        final machineState = MachineControllerState(controller: controller);
        bloc.add(MachineControllerStateAnalyzed(machineState));
      },
      expect: () => [
        isA<ProblemsState>(), // Initial state from initialization
        isA<ProblemsState>().having(
          (state) => state.problems.any((p) => p.id == ProblemIds.cncDoorOpen),
          'has door open problem',
          true,
        ),
      ],
    );

    blocTest<ProblemsBloc, ProblemsState>(
      'removes door open problem when machine status is not door',
      build: () => problemsBloc,
      seed: () => ProblemsState(
        problems: [ProblemFactory.cncDoorOpen()],
        isInitialized: true,
      ),
      act: (bloc) {
        // Create a MachineController with idle status
        final controller = MachineController(
          controllerId: 'test-controller',
          status: MachineStatus.idle,
          isOnline: true,
          lastCommunication: DateTime.now(),
        );
        final machineState = MachineControllerState(controller: controller);
        bloc.add(MachineControllerStateAnalyzed(machineState));
      },
      expect: () => [
        isA<ProblemsState>().having(
          (state) => state.problems.any((p) => p.id == ProblemIds.cncDoorOpen),
          'has no door open problem',
          false,
        ),
      ],
    );

    blocTest<ProblemsBloc, ProblemsState>(
      'does not add door open problem when no controller present',
      build: () => problemsBloc,
      act: (bloc) {
        // Create state with no controller
        final machineState = MachineControllerState(controller: null);
        bloc.add(MachineControllerStateAnalyzed(machineState));
      },
      expect: () => [
        // Only initialization state is emitted when no controller is present
        isA<ProblemsState>().having(
          (state) => state.problems.any((p) => p.id == ProblemIds.cncDoorOpen),
          'has no door open problem',
          false,
        ),
      ],
    );

    test('door open problem has correct properties', () {
      final doorProblem = ProblemFactory.cncDoorOpen();
      
      expect(doorProblem.id, equals(ProblemIds.cncDoorOpen));
      expect(doorProblem.severity, equals(ProblemSeverity.warning));
      expect(doorProblem.source, equals('Machine State'));
      expect(doorProblem.title, equals('Safety Door Open'));
      expect(doorProblem.description, contains('machine safety door is open'));
    });
  });
}