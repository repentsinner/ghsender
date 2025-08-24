import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:ghsender/domain/entities/machine.dart';
import 'package:ghsender/domain/value_objects/machine_position.dart';
import 'package:ghsender/domain/value_objects/safety_envelope.dart';
import 'package:ghsender/domain/value_objects/validation_result.dart';
import 'package:ghsender/domain/entities/machine_configuration.dart';
import 'package:ghsender/domain/enums/machine_status.dart';

void main() {
  group('Machine Domain Entity', () {
    late Machine machine;
    late MachineConfiguration config;
    late SafetyEnvelope envelope;
    
    setUp(() {
      config = MachineConfiguration(
        lastUpdated: DateTime.now(),
      );
      envelope = SafetyEnvelope(
        minBounds: vm.Vector3(-100, -100, -100),
        maxBounds: vm.Vector3(100, 100, 100),
      );
      
      machine = Machine(
        id: const MachineId('test-machine'),
        configuration: config,
        currentPosition: MachinePosition.fromVector3(vm.Vector3.zero()),
        status: MachineStatus.idle,
        safetyEnvelope: envelope,
      );
    });

    test('should validate move within safety envelope', () {
      final result = machine.validateMove(vm.Vector3(50, 50, 50));
      
      expect(result.isValid, isTrue);
    });

    test('should reject move outside safety envelope', () {
      final result = machine.validateMove(vm.Vector3(150, 150, 150));
      
      expect(result.isValid, isFalse);
      expect(result.violationType, ViolationType.workEnvelopeExceeded);
      expect(result.error, contains('exceeds work envelope'));
    });

    test('should reject move when machine is alarmed', () {
      final alarmedMachine = machine.addAlarm(
        const Alarm(message: 'Test alarm', code: 1),
      );
      
      final result = alarmedMachine.validateMove(vm.Vector3(50, 50, 50));
      
      expect(result.isValid, isFalse);
      expect(result.violationType, ViolationType.machineAlarmed);
      expect(result.error, contains('alarm state'));
    });

    test('should reject move when machine is already moving', () {
      final movingMachine = machine.copyWith(status: MachineStatus.running);
      
      final result = movingMachine.validateMove(vm.Vector3(50, 50, 50));
      
      expect(result.isValid, isFalse);
      expect(result.violationType, ViolationType.machineMoving);
    });

    test('should allow jogging when already jogging', () {
      final joggingMachine = machine.copyWith(status: MachineStatus.jogging);
      
      final result = joggingMachine.validateMove(vm.Vector3(50, 50, 50));
      
      expect(result.isValid, isTrue);
    });

    test('should execute valid move', () {
      final targetPosition = vm.Vector3(50, 50, 50);
      
      final resultMachine = machine.executeMove(targetPosition);
      
      expect(resultMachine.currentPosition.workCoordinates, targetPosition);
      expect(resultMachine.status, MachineStatus.jogging);
    });

    test('should throw exception for invalid move', () {
      final invalidPosition = vm.Vector3(150, 150, 150);
      
      expect(
        () => machine.executeMove(invalidPosition),
        throwsA(isA<MachineOperationException>()),
      );
    });

    test('should clear alarms and set to idle', () {
      final alarmedMachine = machine.addAlarm(
        const Alarm(message: 'Test alarm', code: 1),
      );
      
      final clearedMachine = alarmedMachine.clearAlarms();
      
      expect(clearedMachine.activeAlarms, isEmpty);
      expect(clearedMachine.status, MachineStatus.idle);
    });
  });
}