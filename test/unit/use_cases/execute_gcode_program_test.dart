import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:ghsender/domain/use_cases/execute_gcode_program.dart';
import 'package:ghsender/domain/repositories/machine_repository.dart';
import 'package:ghsender/domain/repositories/gcode_repository.dart';
import 'package:ghsender/domain/services/safety_validator.dart';
import 'package:ghsender/domain/entities/machine.dart';
import 'package:ghsender/domain/value_objects/machine_position.dart';
import 'package:ghsender/domain/value_objects/safety_envelope.dart';
import 'package:ghsender/domain/value_objects/validation_result.dart';
import 'package:ghsender/domain/value_objects/gcode_program.dart';
import 'package:ghsender/domain/value_objects/gcode_program_id.dart';
import 'package:ghsender/models/machine_controller.dart';
import 'package:ghsender/models/machine_configuration.dart';

// Mock classes
class MockMachineRepository extends Mock implements MachineRepository {}
class MockGCodeRepository extends Mock implements GCodeRepository {}
class MockSafetyValidator extends Mock implements SafetyValidator {}

void main() {
  group('ExecuteGCodeProgram Use Case', () {
    late ExecuteGCodeProgram executeProgram;
    late MockMachineRepository mockMachineRepository;
    late MockGCodeRepository mockGCodeRepository;
    late MockSafetyValidator mockSafetyValidator;
    late Machine testMachine;
    late GCodeProgram testProgram;

    setUp(() {
      mockMachineRepository = MockMachineRepository();
      mockGCodeRepository = MockGCodeRepository();
      mockSafetyValidator = MockSafetyValidator();
      executeProgram = ExecuteGCodeProgram(
        mockMachineRepository,
        mockGCodeRepository,
        mockSafetyValidator,
      );

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

      // Create test program
      testProgram = GCodeProgram(
        id: const GCodeProgramId('test-program'),
        name: 'test.gcode',
        path: '/path/to/test.gcode',
        sizeBytes: 1024,
        uploadDate: DateTime.now(),
        status: 'ready',
      );

      // Register fallback values for mocktail
      registerFallbackValue(testMachine);
      registerFallbackValue(testProgram);
      registerFallbackValue(const GCodeProgramId('fallback'));
    });

    group('execute', () {
      test('should successfully execute valid program', () async {
        // Arrange
        final request = ExecuteProgramRequest(
          programId: const GCodeProgramId('test-program'),
        );

        when(() => mockMachineRepository.getCurrent())
            .thenAnswer((_) async => testMachine);
        when(() => mockMachineRepository.isConnected).thenReturn(true);
        when(() => mockGCodeRepository.load(any()))
            .thenAnswer((_) async => testProgram);
        when(() => mockSafetyValidator.validateProgram(any()))
            .thenAnswer((_) async => ValidationResult.success());

        // Act
        final result = await executeProgram.execute(request);

        // Assert
        expect(result.success, isTrue);
        expect(result.program, equals(testProgram));
        expect(result.errorMessage, isNull);

        // Verify interactions
        verify(() => mockMachineRepository.getCurrent()).called(1);
        verify(() => mockGCodeRepository.load(const GCodeProgramId('test-program')))
            .called(1);
        verify(() => mockSafetyValidator.validateProgram(testProgram)).called(1);
      });

      test('should return failure when machine not ready', () async {
        // Arrange
        final alarmedMachine = testMachine.copyWith(status: MachineStatus.alarm);
        final request = ExecuteProgramRequest(
          programId: const GCodeProgramId('test-program'),
        );

        when(() => mockMachineRepository.getCurrent())
            .thenAnswer((_) async => alarmedMachine);
        when(() => mockMachineRepository.isConnected).thenReturn(true);

        // Act
        final result = await executeProgram.execute(request);

        // Assert
        expect(result.success, isFalse);
        expect(result.program, isNull);
        expect(result.errorMessage, contains('not ready for program execution'));
        expect(result.errorMessage, contains('Alarm'));

        // Verify interactions
        verify(() => mockMachineRepository.getCurrent()).called(1);
        verifyNever(() => mockGCodeRepository.load(any()));
        verifyNever(() => mockSafetyValidator.validateProgram(any()));
      });

      test('should return failure when program validation fails', () async {
        // Arrange
        final request = ExecuteProgramRequest(
          programId: const GCodeProgramId('test-program'),
        );

        final validationFailure = ValidationResult.failure(
          'Program contains invalid G-code commands',
          ViolationType.programValidation,
        );

        when(() => mockMachineRepository.getCurrent())
            .thenAnswer((_) async => testMachine);
        when(() => mockMachineRepository.isConnected).thenReturn(true);
        when(() => mockGCodeRepository.load(any()))
            .thenAnswer((_) async => testProgram);
        when(() => mockSafetyValidator.validateProgram(any()))
            .thenAnswer((_) async => validationFailure);

        // Act
        final result = await executeProgram.execute(request);

        // Assert
        expect(result.success, isFalse);
        expect(result.program, isNull);
        expect(result.validationResult, equals(validationFailure));
        expect(result.errorMessage, contains('invalid G-code commands'));

        // Verify interactions
        verify(() => mockMachineRepository.getCurrent()).called(1);
        verify(() => mockGCodeRepository.load(const GCodeProgramId('test-program')))
            .called(1);
        verify(() => mockSafetyValidator.validateProgram(testProgram)).called(1);
      });

      test('should handle repository errors gracefully', () async {
        // Arrange
        final request = ExecuteProgramRequest(
          programId: const GCodeProgramId('test-program'),
        );

        when(() => mockMachineRepository.getCurrent())
            .thenThrow(Exception('Repository connection failed'));

        // Act
        final result = await executeProgram.execute(request);

        // Assert
        expect(result.success, isFalse);
        expect(result.program, isNull);
        expect(result.errorMessage, contains('Repository connection failed'));
        
        // Verify interactions
        verify(() => mockMachineRepository.getCurrent()).called(1);
        verifyNever(() => mockGCodeRepository.load(any()));
        verifyNever(() => mockSafetyValidator.validateProgram(any()));
      });
    });

    group('validateProgram', () {
      test('should return validation result without executing', () async {
        // Arrange
        final request = ExecuteProgramRequest(
          programId: const GCodeProgramId('test-program'),
        );

        final validationResult = ValidationResult.success();

        when(() => mockGCodeRepository.load(any()))
            .thenAnswer((_) async => testProgram);
        when(() => mockSafetyValidator.validateProgram(any()))
            .thenAnswer((_) async => validationResult);

        // Act
        final result = await executeProgram.validateProgram(request);

        // Assert
        expect(result, equals(validationResult));
        
        // Verify interactions
        verify(() => mockGCodeRepository.load(const GCodeProgramId('test-program')))
            .called(1);
        verify(() => mockSafetyValidator.validateProgram(testProgram)).called(1);
        verifyNever(() => mockMachineRepository.getCurrent());
      });

      test('should handle validation errors', () async {
        // Arrange
        final request = ExecuteProgramRequest(
          programId: const GCodeProgramId('test-program'),
        );

        when(() => mockGCodeRepository.load(any()))
            .thenThrow(Exception('Program not found'));

        // Act
        final result = await executeProgram.validateProgram(request);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.violationType, ViolationType.systemError);
        expect(result.error, contains('Program not found'));
      });
    });

    group('canExecuteProgram', () {
      test('should return true when machine ready and program exists', () async {
        // Arrange
        final programId = const GCodeProgramId('test-program');

        when(() => mockMachineRepository.getCurrent())
            .thenAnswer((_) async => testMachine);
        when(() => mockMachineRepository.isConnected).thenReturn(true);
        when(() => mockGCodeRepository.exists(any()))
            .thenAnswer((_) async => true);

        // Act
        final canExecute = await executeProgram.canExecuteProgram(programId);

        // Assert
        expect(canExecute, isTrue);

        // Verify interactions
        verify(() => mockMachineRepository.getCurrent()).called(1);
        verify(() => mockGCodeRepository.exists(programId)).called(1);
      });

      test('should return false when repository not connected', () async {
        // Arrange
        final programId = const GCodeProgramId('test-program');

        when(() => mockMachineRepository.getCurrent())
            .thenAnswer((_) async => testMachine);
        when(() => mockMachineRepository.isConnected).thenReturn(false);
        when(() => mockGCodeRepository.exists(any()))
            .thenAnswer((_) async => true);

        // Act
        final canExecute = await executeProgram.canExecuteProgram(programId);

        // Assert
        expect(canExecute, isFalse);
      });

      test('should return false when program does not exist', () async {
        // Arrange
        final programId = const GCodeProgramId('nonexistent-program');

        when(() => mockMachineRepository.getCurrent())
            .thenAnswer((_) async => testMachine);
        when(() => mockMachineRepository.isConnected).thenReturn(true);
        when(() => mockGCodeRepository.exists(any()))
            .thenAnswer((_) async => false);

        // Act
        final canExecute = await executeProgram.canExecuteProgram(programId);

        // Assert
        expect(canExecute, isFalse);

        // Verify interactions
        verify(() => mockGCodeRepository.exists(programId)).called(1);
      });

      test('should return false when machine has error', () async {
        // Arrange
        final programId = const GCodeProgramId('test-program');
        final alarmedMachine = testMachine.copyWith(status: MachineStatus.alarm);

        when(() => mockMachineRepository.getCurrent())
            .thenAnswer((_) async => alarmedMachine);
        when(() => mockMachineRepository.isConnected).thenReturn(true);
        when(() => mockGCodeRepository.exists(any()))
            .thenAnswer((_) async => true);

        // Act
        final canExecute = await executeProgram.canExecuteProgram(programId);

        // Assert
        expect(canExecute, isFalse);
      });

      test('should handle errors gracefully', () async {
        // Arrange
        final programId = const GCodeProgramId('test-program');

        when(() => mockMachineRepository.getCurrent())
            .thenThrow(Exception('Connection failed'));

        // Act
        final canExecute = await executeProgram.canExecuteProgram(programId);

        // Assert
        expect(canExecute, isFalse);
      });
    });
  });
}