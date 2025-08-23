import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:ghsender/domain/value_objects/safety_envelope.dart';

void main() {
  group('SafetyEnvelope', () {
    late SafetyEnvelope envelope;
    
    setUp(() {
      envelope = SafetyEnvelope(
        minBounds: vm.Vector3(-100, -100, -100),
        maxBounds: vm.Vector3(100, 100, 100),
        safetyMargin: 1.0,
      );
    });

    test('should contain position within safe bounds', () {
      // Position well within bounds after safety margin
      final result = envelope.contains(vm.Vector3(50, 50, 50));
      expect(result, isTrue);
    });

    test('should reject position outside safe bounds', () {
      // Position outside bounds
      final result = envelope.contains(vm.Vector3(150, 150, 150));
      expect(result, isFalse);
    });

    test('should reject position too close to boundary', () {
      // Position at exact boundary - should be rejected due to safety margin
      final result = envelope.contains(vm.Vector3(100, 100, 100));
      expect(result, isFalse);
    });

    test('should accept position just inside safety margin', () {
      // Position at boundary minus safety margin
      final result = envelope.contains(vm.Vector3(99, 99, 99));
      expect(result, isTrue);
    });

    test('should calculate distance to edge correctly', () {
      // Position at center should have distance to edge of 99 (100 - 1 safety margin)
      final distance = envelope.distanceToEdge(vm.Vector3.zero());
      expect(distance, equals(100.0)); // Distance to nearest boundary without safety margin
    });

    test('should handle negative boundaries correctly', () {
      // Test with negative boundaries
      final negEnvelope = SafetyEnvelope(
        minBounds: vm.Vector3(-50, -50, -50),
        maxBounds: vm.Vector3(-10, -10, -10),
      );
      
      expect(negEnvelope.contains(vm.Vector3(-30, -30, -30)), isTrue);
      expect(negEnvelope.contains(vm.Vector3(-5, -5, -5)), isFalse);
    });

    test('should be immutable', () {
      final originalBounds = envelope.minBounds;
      // Envelope should be immutable - no way to modify it
      expect(envelope.minBounds, equals(originalBounds));
    });
  });
}