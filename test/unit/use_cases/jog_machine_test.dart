import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:ghsender/domain/use_cases/jog_machine.dart';
import 'package:ghsender/domain/enums/machine_status.dart';
import 'package:ghsender/domain/repositories/machine_repository.dart';
import 'package:ghsender/domain/entities/machine.dart';
import 'package:ghsender/domain/value_objects/machine_position.dart';
import 'package:ghsender/domain/value_objects/safety_envelope.dart';
import 'package:ghsender/domain/value_objects/validation_result.dart';
import 'package:ghsender/domain/entities/machine_configuration.dart';

// Mock classes
class MockMachineRepository extends Mock implements MachineRepository {}

void main() {
  group('JogMachine Use Case', () {
    late JogMachine jogMachine;
    late MockMachineRepository mockMachineRepository;
    late Machine testMachine;

    setUp(() {
      mockMachineRepository = MockMachineRepository();
      jogMachine = JogMachine(mockMachineRepository);

      // Create test machine
      testMachine = Machine(
        id: const MachineId('test-machine'),
        configuration: MachineConfiguration(lastUpdated: DateTime.now()),
        currentPosition: MachinePosition.fromVector3(vm.Vector3.zero()),
        status: MachineStatus.idle,
        safetyEnvelope: SafetyEnvelope(
          minBounds: vm.Vector3(-100, -100, -100),
          maxBounds: vm.Vector3(100, 100, 100),
        ),
      );

      // Register fallback values for mocktail
      registerFallbackValue(testMachine);
      registerFallbackValue(vm.Vector3.zero());
    });

    group('execute', () {
      test('should successfully execute valid jog move', () async {
        // Arrange
        final targetPosition = vm.Vector3(50, 50, 50);
        final feedRate = 1000.0;
        final request = JogRequest(
          targetPosition: targetPosition,
          feedRate: feedRate,
        );

        when(() => mockMachineRepository.getCurrent())
            .thenAnswer((_) async => testMachine);
        

        when(() => mockMachineRepository.updatePosition(any()))
            .thenAnswer((_) async {});

        // Act
        final result = await jogMachine.execute(request);

        // Assert
        expect(result.success, isTrue);
        expect(result.updatedMachine, isNotNull);
        expect(result.updatedMachine!.currentPosition.workCoordinates, targetPosition);
        expect(result.errorMessage, isNull);

        // Verify interactions
        verify(() => mockMachineRepository.getCurrent()).called(1);
        verify(() => mockMachineRepository.updatePosition(any())).called(1);
      });

      test('should return failure when validation fails', () async {
        // Arrange
        final targetPosition = vm.Vector3(150, 150, 150); // Outside bounds
        final feedRate = 1000.0;
        final request = JogRequest(
          targetPosition: targetPosition,
          feedRate: feedRate,
        );

        final validationFailure = ValidationResult.failure(
          'Target position exceeds work envelope',
          ViolationType.workEnvelopeExceeded,
        );

        when(() => mockMachineRepository.getCurrent())
            .thenAnswer((_) async => testMachine);
        

        // Act
        final result = await jogMachine.execute(request);

        // Assert
        expect(result.success, isFalse);
        expect(result.updatedMachine, isNull);
        expect(result.validationResult, equals(validationFailure));
        expect(result.errorMessage, contains('work envelope'));

        // Verify interactions
        verify(() => mockMachineRepository.getCurrent()).called(1);
        verifyNever(() => mockMachineRepository.updatePosition(any()));
      });

      test('should handle repository errors gracefully', () async {
        // Arrange
        final targetPosition = vm.Vector3(50, 50, 50);
        final feedRate = 1000.0;
        final request = JogRequest(
          targetPosition: targetPosition,
          feedRate: feedRate,
        );

        when(() => mockMachineRepository.getCurrent())
            .thenThrow(Exception('Repository connection failed'));

        // Act
        final result = await jogMachine.execute(request);

        // Assert
        expect(result.success, isFalse);
        expect(result.updatedMachine, isNull);
        expect(result.errorMessage, contains('Repository connection failed'));
        
        // Verify interactions
        verify(() => mockMachineRepository.getCurrent()).called(1);
        verifyNever(() => mockMachineRepository.updatePosition(any()));
      });
    });

    group('validateMove', () {
      test('should return validation result without executing', () async {
        // Arrange
        final targetPosition = vm.Vector3(50, 50, 50);
        final feedRate = 1000.0;
        final request = JogRequest(
          targetPosition: targetPosition,
          feedRate: feedRate,
        );

        final validationResult = ValidationResult.success();

        when(() => mockMachineRepository.getCurrent())
            .thenAnswer((_) async => testMachine);
        

        // Act
        final result = await jogMachine.validateMove(request);

        // Assert
        expect(result, equals(validationResult));
        
        // Verify interactions
        verify(() => mockMachineRepository.getCurrent()).called(1);
        verifyNever(() => mockMachineRepository.updatePosition(any()));
      });

      test('should handle validation errors', () async {
        // Arrange
        final targetPosition = vm.Vector3(50, 50, 50);
        final feedRate = 1000.0;
        final request = JogRequest(
          targetPosition: targetPosition,
          feedRate: feedRate,
        );

        when(() => mockMachineRepository.getCurrent())
            .thenThrow(Exception('Validation failed'));

        // Act
        final result = await jogMachine.validateMove(request);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.violationType, ViolationType.systemError);
        expect(result.error, contains('Validation failed'));
      });
    });

    group('canJog', () {
      test('should return true when machine is ready', () async {
        // Arrange
        when(() => mockMachineRepository.getCurrent())
            .thenAnswer((_) async => testMachine);
        when(() => mockMachineRepository.isConnected).thenReturn(true);

        // Act
        final canJog = await jogMachine.canJog();

        // Assert
        expect(canJog, isTrue);
      });

      test('should return false when repository not connected', () async {
        // Arrange
        when(() => mockMachineRepository.getCurrent())
            .thenAnswer((_) async => testMachine);
        when(() => mockMachineRepository.isConnected).thenReturn(false);

        // Act
        final canJog = await jogMachine.canJog();

        // Assert
        expect(canJog, isFalse);
      });

      test('should return false when machine has error', () async {
        // Arrange
        final alarmedMachine = testMachine.copyWith(status: MachineStatus.alarm);
        
        when(() => mockMachineRepository.getCurrent())
            .thenAnswer((_) async => alarmedMachine);
        when(() => mockMachineRepository.isConnected).thenReturn(true);

        // Act
        final canJog = await jogMachine.canJog();

        // Assert
        expect(canJog, isFalse);
      });

      test('should return false when machine is running', () async {
        // Arrange
        final runningMachine = testMachine.copyWith(status: MachineStatus.running);
        
        when(() => mockMachineRepository.getCurrent())
            .thenAnswer((_) async => runningMachine);
        when(() => mockMachineRepository.isConnected).thenReturn(true);

        // Act
        final canJog = await jogMachine.canJog();

        // Assert
        expect(canJog, isFalse);
      });

      test('should return true when machine is already jogging', () async {
        // Arrange
        final joggingMachine = testMachine.copyWith(status: MachineStatus.jogging);
        
        when(() => mockMachineRepository.getCurrent())
            .thenAnswer((_) async => joggingMachine);
        when(() => mockMachineRepository.isConnected).thenReturn(true);

        // Act
        final canJog = await jogMachine.canJog();

        // Assert
        expect(canJog, isTrue);
      });

      test('should handle repository errors gracefully', () async {
        // Arrange
        when(() => mockMachineRepository.getCurrent())
            .thenThrow(Exception('Connection failed'));

        // Act
        final canJog = await jogMachine.canJog();

        // Assert
        expect(canJog, isFalse);
      });
    });
  });
}