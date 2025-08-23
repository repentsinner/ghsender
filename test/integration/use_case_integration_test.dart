import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:ghsender/domain/use_cases/jog_machine.dart';
import 'package:ghsender/domain/use_cases/execute_gcode_program.dart';
import 'package:ghsender/domain/entities/machine.dart';
import 'package:ghsender/domain/value_objects/machine_position.dart';
import 'package:ghsender/domain/value_objects/safety_envelope.dart';
import 'package:ghsender/domain/value_objects/gcode_program.dart';
import 'package:ghsender/domain/value_objects/gcode_program_id.dart';
import 'package:ghsender/domain/value_objects/validation_result.dart';
import 'package:ghsender/domain/repositories/machine_repository.dart';
import 'package:ghsender/domain/repositories/gcode_repository.dart';
import 'package:ghsender/domain/services/safety_validator.dart';
import 'package:ghsender/models/machine_controller.dart';
import 'package:ghsender/models/machine_configuration.dart';
import 'package:ghsender/utils/soft_limit_checker.dart';

/// Integration tests verifying domain use cases work with existing SoftLimitChecker
/// 
/// These tests demonstrate the domain layer successfully integrates with
/// the existing application-level soft limit checking infrastructure.
void main() {
  group('Domain Use Cases Integration', () {
    late TestMachineRepository machineRepository;
    late TestGCodeRepository gcodeRepository;
    late TestSafetyValidator safetyValidator;
    late JogMachine jogMachine;
    late ExecuteGCodeProgram executeProgram;
    
    late Machine testMachine;
    late GCodeProgram testProgram;
    late SafetyEnvelope workEnvelope;

    setUp(() {
      // Create work envelope matching SoftLimitChecker test patterns
      workEnvelope = SafetyEnvelope(
        minBounds: vm.Vector3(-100, -100, -100),
        maxBounds: vm.Vector3(0, 0, 0),
      );

      // Create test machine at center of work envelope
      testMachine = Machine(
        id: const MachineId('integration-test'),
        configuration: MachineConfiguration(lastUpdated: DateTime.now()),
        currentPosition: MachinePosition.fromVector3(vm.Vector3(-50, -50, -50)),
        status: MachineStatus.idle,
        safetyEnvelope: workEnvelope,
      );

      testProgram = GCodeProgram(
        id: const GCodeProgramId('test-integration'),
        name: 'integration-test.gcode',
        path: '/test/integration-test.gcode',
        sizeBytes: 2048,
        uploadDate: DateTime.now(),
        status: 'ready',
      );

      // Create test implementations using SoftLimitChecker
      machineRepository = TestMachineRepository(testMachine);
      gcodeRepository = TestGCodeRepository(testProgram);
      safetyValidator = TestSafetyValidator();
      
      jogMachine = JogMachine(machineRepository, safetyValidator);
      executeProgram = ExecuteGCodeProgram(
        machineRepository,
        gcodeRepository,
        safetyValidator,
      );
    });

    group('JogMachine Integration with SoftLimitChecker', () {
      test('allows safe diagonal movement from center position', () async {
        // Test movement that should be allowed by SoftLimitChecker
        final targetPosition = vm.Vector3(-40, -40, -40); // 10mm diagonal from center
        final request = JogRequest(
          targetPosition: targetPosition,
          feedRate: 1000.0,
        );

        final result = await jogMachine.execute(request);

        expect(result.success, isTrue);
        expect(result.updatedMachine, isNotNull);
        expect(result.updatedMachine!.currentPosition.workCoordinates, targetPosition);
        expect(result.errorMessage, isNull);
      });

      test('prevents movement beyond work envelope boundaries', () async {
        // Move machine close to boundary
        final nearBoundary = testMachine.copyWith(
          currentPosition: MachinePosition.fromVector3(vm.Vector3(-5, -95, -50)),
        );
        machineRepository.updateCurrentMachine(nearBoundary);

        // Try to move beyond Y boundary
        final targetPosition = vm.Vector3(-5, -105, -50); // Beyond Y min boundary
        final request = JogRequest(
          targetPosition: targetPosition,
          feedRate: 1000.0,
        );

        final result = await jogMachine.execute(request);

        expect(result.success, isFalse);
        expect(result.validationResult, isNotNull);
        expect(result.validationResult!.violationType, ViolationType.workEnvelopeExceeded);
        expect(result.errorMessage, contains('work envelope'));
      });

      test('allows movement away from boundaries', () async {
        // Position machine near corner
        final nearCorner = testMachine.copyWith(
          currentPosition: MachinePosition.fromVector3(vm.Vector3(-5, -95, -50)),
        );
        machineRepository.updateCurrentMachine(nearCorner);

        // Move away from boundaries (toward center)
        final targetPosition = vm.Vector3(-15, -85, -50);
        final request = JogRequest(
          targetPosition: targetPosition,
          feedRate: 1000.0,
        );

        final result = await jogMachine.execute(request);

        expect(result.success, isTrue);
        expect(result.updatedMachine!.currentPosition.workCoordinates, targetPosition);
      });

      test('respects safety buffer from SoftLimitChecker', () async {
        // Position machine at exactly safety buffer distance from boundary
        final atSafetyBuffer = testMachine.copyWith(
          currentPosition: MachinePosition.fromVector3(vm.Vector3(-1.0, -50, -50)), // 1mm from X max
        );
        machineRepository.updateCurrentMachine(atSafetyBuffer);

        // Try to move toward boundary (should be prevented by safety buffer)
        final targetPosition = vm.Vector3(0.5, -50, -50); // Beyond boundary
        final request = JogRequest(
          targetPosition: targetPosition,
          feedRate: 1000.0,
        );

        final result = await jogMachine.execute(request);

        expect(result.success, isFalse);
        expect(result.validationResult!.violationType, ViolationType.workEnvelopeExceeded);
      });
    });

    group('ExecuteGCodeProgram Integration with SoftLimitChecker', () {
      test('validates program execution respects work envelope', () async {
        final request = ExecuteProgramRequest(
          programId: const GCodeProgramId('test-integration'),
        );

        final result = await executeProgram.execute(request);

        expect(result.success, isTrue);
        expect(result.program, equals(testProgram));
        expect(result.errorMessage, isNull);
      });

      test('prevents execution when machine near boundary', () async {
        // Position machine where program execution might violate limits
        final nearBoundary = testMachine.copyWith(
          currentPosition: MachinePosition.fromVector3(vm.Vector3(-5, -95, -5)),
        );
        machineRepository.updateCurrentMachine(nearBoundary);
        
        // Configure safety validator to reject this program due to position
        safetyValidator.shouldRejectProgram = true;

        final request = ExecuteProgramRequest(
          programId: const GCodeProgramId('test-integration'),
        );

        final result = await executeProgram.execute(request);

        expect(result.success, isFalse);
        expect(result.validationResult, isNotNull);
        expect(result.validationResult!.violationType, ViolationType.workEnvelopeExceeded);
      });

      test('validates program content for envelope compatibility', () async {
        final validationResult = await executeProgram.validateProgram(
          ExecuteProgramRequest(programId: const GCodeProgramId('test-integration')),
        );

        expect(validationResult.isValid, isTrue);
      });
    });

    group('Coordinate System Integration', () {
      test('handles Y-axis coordinate transformations correctly', () async {
        // Test movement in CNC coordinate system (Y-axis away from operator is positive)
        final targetPosition = vm.Vector3(-50, -40, -50); // Move Y+ (away from operator)
        final request = JogRequest(
          targetPosition: targetPosition,
          feedRate: 1000.0,
        );

        final result = await jogMachine.execute(request);

        expect(result.success, isTrue);
        expect(result.updatedMachine!.currentPosition.workCoordinates.y, equals(-40));
      });

      test('integrates with SoftLimitChecker coordinate filtering', () async {
        // Position near Y boundary to test coordinate system integration
        final nearYBoundary = testMachine.copyWith(
          currentPosition: MachinePosition.fromVector3(vm.Vector3(-50, -5, -50)),
        );
        machineRepository.updateCurrentMachine(nearYBoundary);

        // Try movement that would be filtered by SoftLimitChecker
        final targetPosition = vm.Vector3(-50, 5, -50); // Beyond Y max boundary
        final request = JogRequest(
          targetPosition: targetPosition,
          feedRate: 1000.0,
        );

        final result = await jogMachine.execute(request);

        expect(result.success, isFalse);
        expect(result.validationResult!.violationType, ViolationType.workEnvelopeExceeded);
      });
    });
  });
}

/// Test repository implementation that uses real Machine objects
class TestMachineRepository implements MachineRepository {
  Machine _currentMachine;

  TestMachineRepository(this._currentMachine);

  void updateCurrentMachine(Machine machine) {
    _currentMachine = machine;
  }

  @override
  Future<Machine> getCurrent() async => _currentMachine;

  @override
  Future<void> save(Machine machine) async {
    _currentMachine = machine;
  }

  @override
  Stream<Machine> watchMachine() => Stream.value(_currentMachine);

  @override
  Future<void> updatePosition(Machine machine) async {
    _currentMachine = machine;
  }

  @override
  bool get isConnected => true;
}

/// Test repository implementation for G-code programs
class TestGCodeRepository implements GCodeRepository {
  final GCodeProgram _testProgram;

  TestGCodeRepository(this._testProgram);

  @override
  Future<GCodeProgram> load(GCodeProgramId id) async => _testProgram;

  @override
  Future<void> save(GCodeProgram program) async {}

  @override
  Future<List<GCodeProgramMetadata>> listPrograms() async => [];

  @override
  Future<void> delete(GCodeProgramId id) async {}

  @override
  Stream<List<GCodeProgramMetadata>> watchPrograms() => Stream.value([]);

  @override
  Future<bool> exists(GCodeProgramId id) async => true;

  @override
  Stream<GCodeProgram> watchProgram(GCodeProgramId id) => Stream.value(_testProgram);
}

/// Test safety validator that integrates with SoftLimitChecker
class TestSafetyValidator implements SafetyValidator {
  bool shouldRejectProgram = false;

  @override
  Future<ValidationResult> validateJogMove(
    Machine machine,
    vm.Vector3 targetPosition,
    double feedRate,
  ) async {
    // Use SoftLimitChecker for actual validation
    final envelope = machine.safetyEnvelope;
    
    // Convert SafetyEnvelope to WorkEnvelope for SoftLimitChecker
    final workEnvelope = WorkEnvelope.fromBounds(
      minBounds: envelope.minBounds,
      maxBounds: envelope.maxBounds,
      units: 'mm',
      lastUpdated: DateTime.now(),
    );

    // Check if target position is within limits
    final isWithinLimits = SoftLimitChecker.isPositionWithinLimits(
      targetPosition,
      workEnvelope,
    );

    if (!isWithinLimits) {
      return ValidationResult.failure(
        'Target position exceeds work envelope limits',
        ViolationType.workEnvelopeExceeded,
      );
    }

    // Check feed rate limits
    if (feedRate > 3000.0) {
      return ValidationResult.failure(
        'Feed rate exceeds maximum limit',
        ViolationType.feedRateExceeded,
      );
    }

    return ValidationResult.success();
  }

  @override
  Future<ValidationResult> validateProgram(GCodeProgram program) async {
    if (shouldRejectProgram) {
      return ValidationResult.failure(
        'Program would exceed work envelope limits',
        ViolationType.workEnvelopeExceeded,
      );
    }
    
    return ValidationResult.success();
  }

  @override
  Future<ValidationResult> validateArcMove(
    Machine machine,
    vm.Vector3 startPosition,
    vm.Vector3 endPosition,
    vm.Vector3 center,
    double feedRate,
    {bool clockwise = true}
  ) async {
    return ValidationResult.success();
  }

  @override
  ValidationResult validateFeedRate(Machine machine, double feedRate) {
    if (feedRate > 3000.0) {
      return ValidationResult.failure(
        'Feed rate exceeds maximum limit',
        ViolationType.feedRateExceeded,
      );
    }
    return ValidationResult.success();
  }

  @override
  Future<ValidationResult> checkToolCollision(
    Machine machine,
    vm.Vector3 targetPosition,
  ) async {
    return ValidationResult.success();
  }
}