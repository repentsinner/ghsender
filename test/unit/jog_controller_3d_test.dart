import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:ghsender/services/jog_service.dart';
import 'package:ghsender/models/machine_controller.dart';

void main() {
  group('JoystickProcessor 3D Support', () {
    late WorkEnvelope workEnvelope;
    late vm.Vector3 centerPosition;
    const int testFeedRate = 1000;

    setUp(() {
      workEnvelope = WorkEnvelope.fromBounds(
        minBounds: vm.Vector3(-100.0, -100.0, -100.0),
        maxBounds: vm.Vector3(0.0, 0.0, 0.0),
        units: 'mm',
        lastUpdated: DateTime.now(),
      );
      
      centerPosition = vm.Vector3(-50.0, -50.0, -50.0);
    });

    group('processWithSoftLimits3D', () {
      test('processes safe 3D movement correctly', () {
        final result = JoystickProcessor.processWithSoftLimits3D(
          rawX: 0.6,
          rawY: 0.8,
          rawZ: 0.3,
          selectedFeedRate: testFeedRate,
          currentPosition: centerPosition,
          workEnvelope: workEnvelope,
        );

        expect(result.isActive, isTrue);
        expect(result.x, closeTo(0.6, 0.001));
        expect(result.y, closeTo(0.8, 0.001));
        expect(result.z, closeTo(0.3, 0.001));
        expect(result.scaledFeedRate, greaterThan(0));
        
        // 3D magnitude calculation: sqrt(0.6^2 + 0.8^2 + 0.3^2) = sqrt(0.36 + 0.64 + 0.09) = sqrt(1.09) ≈ 1.044
        // Should be clamped to 1.0
        expect(result.magnitude, closeTo(1.0, 0.001));
      });

      test('handles 3D filtering with realistic scenario', () {
        // Position close to boundaries but not within safety buffer
        final nearBoundary = vm.Vector3(-2.0, -98.0, -2.0);
        
        final result = JoystickProcessor.processWithSoftLimits3D(
          rawX: 0.8,
          rawY: -0.8, 
          rawZ: 0.8,
          selectedFeedRate: testFeedRate,
          currentPosition: nearBoundary,
          workEnvelope: workEnvelope,
        );

        expect(result.isActive, isTrue);
        
        // At this distance from boundaries (2mm), with 1mm safety buffer,
        // and small baseDistance (≈0.4167mm), movements should mostly be preserved
        // since the movements are small relative to available space
        expect(result.x, closeTo(0.8, 0.1));
        expect(result.y, closeTo(-0.8, 0.1));
        expect(result.z, closeTo(0.8, 0.1));
      });

      test('falls back to unfiltered processing when no work envelope', () {
        final result = JoystickProcessor.processWithSoftLimits3D(
          rawX: 0.6,
          rawY: 0.8,
          rawZ: 0.3,
          selectedFeedRate: testFeedRate,
          currentPosition: centerPosition,
          workEnvelope: null,
        );

        // Should process without filtering
        expect(result.isActive, isTrue);
        expect(result.x, equals(0.6));
        expect(result.y, equals(0.8));
        expect(result.z, equals(0.3));
        expect(result.magnitude, closeTo(1.0, 0.001)); // Clamped to 1.0
      });

      test('returns inactive for input below dead zone', () {
        final result = JoystickProcessor.processWithSoftLimits3D(
          rawX: 0.02, // Below dead zone
          rawY: 0.02,
          rawZ: 0.02,
          selectedFeedRate: testFeedRate,
          currentPosition: centerPosition,
          workEnvelope: workEnvelope,
        );

        expect(result.isActive, isFalse);
        expect(result.x, equals(0.0));
        expect(result.y, equals(0.0));
        expect(result.z, equals(0.0));
        expect(result.magnitude, equals(0.0));
      });

      test('handles Z-axis coordinate system correctly', () {
        // Positive Z should remain positive (away from workpiece)
        final result = JoystickProcessor.processWithSoftLimits3D(
          rawX: 0.0,
          rawY: 0.0,
          rawZ: 0.5, // Positive Z
          selectedFeedRate: testFeedRate,
          currentPosition: centerPosition,
          workEnvelope: workEnvelope,
        );

        expect(result.isActive, isTrue);
        expect(result.z, equals(0.5)); // Z should remain positive
      });
    });

    group('3D magnitude calculations', () {
      test('calculates 3D magnitude correctly', () {
        // Test Pythagorean theorem in 3D: sqrt(3^2 + 4^2 + 5^2) = sqrt(9 + 16 + 25) = sqrt(50) ≈ 7.07
        // But should be clamped to 1.0
        final result = JoystickProcessor.processWithSoftLimits3D(
          rawX: 0.6,  // 3/5
          rawY: 0.8,  // 4/5  
          rawZ: 1.0,  // 5/5
          selectedFeedRate: testFeedRate,
          currentPosition: centerPosition,
          workEnvelope: workEnvelope,
        );

        expect(result.magnitude, closeTo(1.0, 0.001)); // Should be clamped
      });

      test('preserves small 3D magnitudes correctly', () {
        final result = JoystickProcessor.processWithSoftLimits3D(
          rawX: 0.1,
          rawY: 0.1,
          rawZ: 0.1,
          selectedFeedRate: testFeedRate,
          currentPosition: centerPosition,
          workEnvelope: workEnvelope,
        );

        // sqrt(0.1^2 + 0.1^2 + 0.1^2) = sqrt(0.03) ≈ 0.173
        expect(result.magnitude, closeTo(0.173, 0.01));
      });
    });
  });
}