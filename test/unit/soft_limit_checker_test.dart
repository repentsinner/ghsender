import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:ghsender/utils/soft_limit_checker.dart';
import 'package:ghsender/models/machine_controller.dart';

void main() {
  group('SoftLimitChecker', () {
    late WorkEnvelope workEnvelope;
    late vm.Vector3 centerPosition;

    setUp(() {
      // Create a standard work envelope: -100 to 0 in all axes (typical grblHAL setup)
      workEnvelope = WorkEnvelope.fromBounds(
        minBounds: vm.Vector3(-100.0, -100.0, -100.0),
        maxBounds: vm.Vector3(0.0, 0.0, 0.0),
        units: 'mm',
        lastUpdated: DateTime.now(),
      );
      
      // Position in center of work envelope
      centerPosition = vm.Vector3(-50.0, -50.0, -50.0);
    });

    group('shouldEnforceLimits', () {
      test('returns true when work envelope available', () {
        expect(
          SoftLimitChecker.shouldEnforceLimits(
            workEnvelope: workEnvelope,
          ),
          isTrue,
        );
      });

      test('returns false when work envelope unavailable', () {
        expect(
          SoftLimitChecker.shouldEnforceLimits(
            workEnvelope: null,
          ),
          isFalse,
        );
      });
    });

    group('isPositionWithinLimits', () {
      test('returns true for position within bounds', () {
        expect(
          SoftLimitChecker.isPositionWithinLimits(centerPosition, workEnvelope),
          isTrue,
        );
      });

      test('returns false for position outside X bounds', () {
        final outsideX = vm.Vector3(10.0, -50.0, -50.0); // X > maxBounds.x
        expect(
          SoftLimitChecker.isPositionWithinLimits(outsideX, workEnvelope),
          isFalse,
        );
      });

      test('returns false for position outside Y bounds', () {
        final outsideY = vm.Vector3(-50.0, -150.0, -50.0); // Y < minBounds.y
        expect(
          SoftLimitChecker.isPositionWithinLimits(outsideY, workEnvelope),
          isFalse,
        );
      });

      test('returns true for position exactly on bounds', () {
        final onBounds = vm.Vector3(0.0, -100.0, 0.0); // On max X, min Y, max Z
        expect(
          SoftLimitChecker.isPositionWithinLimits(
            onBounds, 
            workEnvelope, 
            customSafetyBuffer: 0.0 // No buffer for this test
          ),
          isTrue,
        );
      });
    });

    group('filterMovement2D', () {
      test('allows movement that stays within bounds', () {
        final requestedMovement = vm.Vector2(10.0, 10.0);
        final filtered = SoftLimitChecker.filterMovement2D(
          requestedMovement: requestedMovement,
          currentPosition: centerPosition,
          workEnvelope: workEnvelope,
          customSafetyBuffer: 0.0, // No buffer for tests
        );

        expect(filtered.x, equals(10.0));
        expect(filtered.y, equals(10.0));
      });

      test('filters X component that would exceed positive bound', () {
        final nearXBound = vm.Vector3(-5.0, -50.0, -50.0); // 5mm from X max
        final requestedMovement = vm.Vector2(10.0, 0.0); // Would exceed by 5mm
        
        final filtered = SoftLimitChecker.filterMovement2D(
          requestedMovement: requestedMovement,
          currentPosition: nearXBound,
          workEnvelope: workEnvelope,
          customSafetyBuffer: 0.0,
        );

        expect(filtered.x, equals(5.0)); // Limited to available space
        expect(filtered.y, equals(0.0)); // Y unchanged
      });

      test('filters Y component that would exceed negative bound', () {
        final nearYBound = vm.Vector3(-50.0, -95.0, -50.0); // 5mm from Y min
        final requestedMovement = vm.Vector2(0.0, -10.0); // Would exceed by 5mm
        
        final filtered = SoftLimitChecker.filterMovement2D(
          requestedMovement: requestedMovement,
          currentPosition: nearYBound,
          workEnvelope: workEnvelope,
          customSafetyBuffer: 0.0,
        );

        expect(filtered.x, equals(0.0)); // X unchanged
        expect(filtered.y, equals(-5.0)); // Limited to available space
      });

      test('filters both components in diagonal movement near corner', () {
        final nearCorner = vm.Vector3(-5.0, -95.0, -50.0); // Near max X, min Y
        final requestedMovement = vm.Vector2(10.0, -10.0); // Diagonal towards corner
        
        final filtered = SoftLimitChecker.filterMovement2D(
          requestedMovement: requestedMovement,
          currentPosition: nearCorner,
          workEnvelope: workEnvelope,
          customSafetyBuffer: 0.0,
        );

        expect(filtered.x, equals(5.0)); // X limited
        expect(filtered.y, equals(-5.0)); // Y limited
      });

      test('returns zero movement when already at boundary', () {
        final atBoundary = vm.Vector3(0.0, -100.0, -50.0); // At max X, min Y
        final requestedMovement = vm.Vector2(1.0, -1.0); // Try to move beyond
        
        final filtered = SoftLimitChecker.filterMovement2D(
          requestedMovement: requestedMovement,
          currentPosition: atBoundary,
          workEnvelope: workEnvelope,
          customSafetyBuffer: 0.0,
        );

        expect(filtered.x, equals(0.0)); // No X movement allowed
        expect(filtered.y, equals(0.0)); // No Y movement allowed
      });

      test('allows movement away from boundary', () {
        final atBoundary = vm.Vector3(0.0, -100.0, -50.0); // At max X, min Y
        final requestedMovement = vm.Vector2(-10.0, 10.0); // Move away from boundaries
        
        final filtered = SoftLimitChecker.filterMovement2D(
          requestedMovement: requestedMovement,
          currentPosition: atBoundary,
          workEnvelope: workEnvelope,
          customSafetyBuffer: 0.0,
        );

        expect(filtered.x, equals(-10.0)); // Full X movement allowed
        expect(filtered.y, equals(10.0)); // Full Y movement allowed
      });
    });

    group('filterJoystickInput', () {
      test('preserves input when movement is safe', () {
        const baseDistance = 1.0;
        final filtered = SoftLimitChecker.filterJoystickInput(
          rawX: 0.5,
          rawY: 0.5,
          currentPosition: centerPosition,
          workEnvelope: workEnvelope,
          baseDistance: baseDistance,
        );

        expect(filtered.x, equals(0.5));
        expect(filtered.y, equals(0.5));
      });

      test('filters joystick input when movement would violate limits', () {
        final nearBoundary = vm.Vector3(-2.0, -50.0, -50.0); // 2mm from X max
        const baseDistance = 10.0; // Large base distance
        
        final filtered = SoftLimitChecker.filterJoystickInput(
          rawX: 1.0, // Full positive X (would move 10mm)
          rawY: 0.0,
          currentPosition: nearBoundary,
          workEnvelope: workEnvelope,
          baseDistance: baseDistance,
        );

        // Should be scaled down to only move the available space (2mm - 1mm buffer = 1mm)
        expect(filtered.x, closeTo(0.1, 0.001)); // 1mm / 10mm = 0.1
        expect(filtered.y, equals(0.0));
      });

      test('handles Y-axis correctly', () {
        final nearYMax = vm.Vector3(-50.0, -2.0, -50.0); // 2mm from Y max (0)
        const baseDistance = 10.0;
        
        final filtered = SoftLimitChecker.filterJoystickInput(
          rawX: 0.0,
          rawY: -1.0, // Negative Y joystick input (towards Y max in CNC coordinates)
          currentPosition: nearYMax,
          workEnvelope: workEnvelope,
          baseDistance: baseDistance,
        );

        expect(filtered.x, equals(0.0));
        expect(filtered.y, closeTo(-0.1, 0.001)); // Filtered to available space (2mm - 1mm buffer = 1mm, 1mm/10mm = 0.1, negative joystick Y)
      });

      test('returns zero when base distance is zero', () {
        final filtered = SoftLimitChecker.filterJoystickInput(
          rawX: 1.0,
          rawY: 1.0,
          currentPosition: centerPosition,
          workEnvelope: workEnvelope,
          baseDistance: 0.0,
        );

        expect(filtered.x, equals(0.0));
        expect(filtered.y, equals(0.0));
      });
    });

    group('getMaxSafeDistance', () {
      test('calculates max positive distance correctly', () {
        final distance = SoftLimitChecker.getMaxSafeDistance(
          currentPosition: -10.0,
          direction: 1.0, // Positive direction
          minBound: -100.0,
          maxBound: 0.0,
        );

        expect(distance, equals(10.0)); // Can move 10mm to reach maxBound
      });

      test('calculates max negative distance correctly', () {
        final distance = SoftLimitChecker.getMaxSafeDistance(
          currentPosition: -10.0,
          direction: -1.0, // Negative direction
          minBound: -100.0,
          maxBound: 0.0,
        );

        expect(distance, equals(90.0)); // Can move 90mm to reach minBound
      });

      test('returns zero for no movement', () {
        final distance = SoftLimitChecker.getMaxSafeDistance(
          currentPosition: -50.0,
          direction: 0.0, // No direction
          minBound: -100.0,
          maxBound: 0.0,
        );

        expect(distance, equals(0.0));
      });

      test('returns zero when already at boundary', () {
        final distance = SoftLimitChecker.getMaxSafeDistance(
          currentPosition: 0.0, // At maxBound
          direction: 1.0, // Trying to move positive
          minBound: -100.0,
          maxBound: 0.0,
        );

        expect(distance, equals(0.0));
      });
    });

    group('filterMovement3D', () {
      test('allows movement that stays within bounds', () {
        final requestedMovement = vm.Vector3(10.0, 10.0, 10.0);
        final filtered = SoftLimitChecker.filterMovement3D(
          requestedMovement: requestedMovement,
          currentPosition: centerPosition,
          workEnvelope: workEnvelope,
          customSafetyBuffer: 0.0,
        );

        expect(filtered.x, equals(10.0));
        expect(filtered.y, equals(10.0));
        expect(filtered.z, equals(10.0));
      });

      test('filters Z component that would exceed positive bound', () {
        final nearZBound = vm.Vector3(-50.0, -50.0, -5.0); // 5mm from Z max
        final requestedMovement = vm.Vector3(0.0, 0.0, 10.0); // Would exceed by 5mm
        
        final filtered = SoftLimitChecker.filterMovement3D(
          requestedMovement: requestedMovement,
          currentPosition: nearZBound,
          workEnvelope: workEnvelope,
          customSafetyBuffer: 0.0,
        );

        expect(filtered.x, equals(0.0)); // X unchanged
        expect(filtered.y, equals(0.0)); // Y unchanged
        expect(filtered.z, equals(5.0)); // Limited to available space
      });

      test('filters all three axes in diagonal movement near corner', () {
        final nearCorner = vm.Vector3(-5.0, -95.0, -5.0); // Near max X, min Y, max Z
        final requestedMovement = vm.Vector3(10.0, -10.0, 10.0); // Diagonal towards corner
        
        final filtered = SoftLimitChecker.filterMovement3D(
          requestedMovement: requestedMovement,
          currentPosition: nearCorner,
          workEnvelope: workEnvelope,
          customSafetyBuffer: 0.0,
        );

        expect(filtered.x, equals(5.0)); // X limited
        expect(filtered.y, equals(-5.0)); // Y limited  
        expect(filtered.z, equals(5.0)); // Z limited
      });

      test('allows movement away from all boundaries', () {
        final atCorner = vm.Vector3(0.0, -100.0, 0.0); // At X max, Y min, Z max
        final requestedMovement = vm.Vector3(-10.0, 10.0, -10.0); // Move away from all boundaries
        
        final filtered = SoftLimitChecker.filterMovement3D(
          requestedMovement: requestedMovement,
          currentPosition: atCorner,
          workEnvelope: workEnvelope,
          customSafetyBuffer: 0.0,
        );

        expect(filtered.x, equals(-10.0)); // Full X movement allowed
        expect(filtered.y, equals(10.0)); // Full Y movement allowed
        expect(filtered.z, equals(-10.0)); // Full Z movement allowed
      });
    });

    group('filterJoystickInput3D', () {
      test('preserves 3D input when movement is safe', () {
        const baseDistance = 1.0;
        final filtered = SoftLimitChecker.filterJoystickInput3D(
          rawX: 0.5,
          rawY: 0.5,
          rawZ: 0.5,
          currentPosition: centerPosition,
          workEnvelope: workEnvelope,
          baseDistance: baseDistance,
        );

        expect(filtered.x, equals(0.5));
        expect(filtered.y, equals(0.5));
        expect(filtered.z, equals(0.5));
      });

      test('filters Z-axis input when movement would violate limits', () {
        final nearZBoundary = vm.Vector3(-50.0, -50.0, -2.0); // 2mm from Z max
        const baseDistance = 10.0;
        
        final filtered = SoftLimitChecker.filterJoystickInput3D(
          rawX: 0.0,
          rawY: 0.0,
          rawZ: 1.0, // Full positive Z (would move 10mm)
          currentPosition: nearZBoundary,
          workEnvelope: workEnvelope,
          baseDistance: baseDistance,
        );

        expect(filtered.x, equals(0.0));
        expect(filtered.y, equals(0.0));
        // Should be scaled down: 2mm available - 1mm buffer = 1mm, 1mm/10mm = 0.1
        expect(filtered.z, closeTo(0.1, 0.001));
      });

      test('handles coordinate system correctly for all three axes', () {
        const baseDistance = 10.0;
        final filtered = SoftLimitChecker.filterJoystickInput3D(
          rawX: 0.6,
          rawY: -0.8, // Joystick up (negative Y)
          rawZ: 0.3,
          currentPosition: centerPosition,
          workEnvelope: workEnvelope,
          baseDistance: baseDistance,
        );

        // At center position, movement should not be filtered
        expect(filtered.x, closeTo(0.6, 0.01));
        expect(filtered.y, closeTo(-0.8, 0.01)); // Y-axis inversion preserved
        expect(filtered.z, closeTo(0.3, 0.01));
      });
    });

    group('hasMovementSpace', () {
      test('returns true when in center of envelope', () {
        expect(
          SoftLimitChecker.hasMovementSpace(
            currentPosition: centerPosition,
            workEnvelope: workEnvelope,
          ),
          isTrue,
        );
      });

      test('returns true when at one boundary but space in other directions', () {
        final atOneBoundary = vm.Vector3(0.0, -50.0, -50.0); // At X max
        expect(
          SoftLimitChecker.hasMovementSpace(
            currentPosition: atOneBoundary,
            workEnvelope: workEnvelope,
          ),
          isTrue, // Can still move in Y and other directions
        );
      });

      test('returns false when exactly at all boundaries (corner)', () {
        final atAllBoundaries = vm.Vector3(0.0, 0.0, 0.0); // At max corner
        expect(
          SoftLimitChecker.hasMovementSpace(
            currentPosition: atAllBoundaries,
            workEnvelope: workEnvelope,
          ),
          isTrue, // Can still move in negative directions
        );
      });
    });
  });
}