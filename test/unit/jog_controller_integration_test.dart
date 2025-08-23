import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:ghsender/utils/soft_limit_checker.dart';
import 'package:ghsender/models/machine_controller.dart';
import 'package:ghsender/services/jog_service.dart';

void main() {
  group('Jog Controller Soft Limits Integration', () {
    late WorkEnvelope workEnvelope;
    late vm.Vector3 centerMachinePosition;
    late vm.Vector3 nearBoundaryMachinePosition;

    setUp(() {
      // Standard grblHAL work envelope: hard limits minus pulloff
      // Machine travels from -100 to 0 in all axes (home at 0,0,0)
      workEnvelope = WorkEnvelope.fromBounds(
        minBounds: vm.Vector3(-100.0, -100.0, -100.0),
        maxBounds: vm.Vector3(0.0, 0.0, 0.0),
        units: 'mm',
        lastUpdated: DateTime.now(),
      );
      
      // Machine position in center of travel envelope
      centerMachinePosition = vm.Vector3(-50.0, -50.0, -50.0);
      
      // Machine position near boundary (5mm from X max, Y min)
      nearBoundaryMachinePosition = vm.Vector3(-5.0, -95.0, -50.0);
    });

    group('Machine Position vs Work Envelope Filtering', () {
      test('allows safe diagonal movement from center', () {
        // Joystick input: diagonal right+down
        final filteredInput = SoftLimitChecker.filterJoystickInput(
          rawX: 0.5,  // Right
          rawY: 0.5,  // Down (in joystick coordinates)
          currentPosition: centerMachinePosition,
          workEnvelope: workEnvelope,
          baseDistance: 10.0,
        );

        // Should preserve full diagonal movement when safe
        expect(filteredInput.x, equals(0.5));
        expect(filteredInput.y, equals(0.5));
      });

      test('filters diagonal movement near boundary', () {
        // Test realistic scenario with JoystickProcessor's baseDistance calculation
        // For 1000 mm/min feedrate: baseDistance = (1000/60) * (25/1000) = 0.4167
        const testFeedRate = 1000;
        const targetExecutionTimeMs = 25.0;
        final expectedBaseDistance = (testFeedRate / 60.0) * (targetExecutionTimeMs / 1000.0);
        
        final filteredInput = SoftLimitChecker.filterJoystickInput(
          rawX: 1.0,   // Full right (towards X max)
          rawY: -1.0,  // Full up in joystick coords = towards Y min in CNC
          currentPosition: nearBoundaryMachinePosition,
          workEnvelope: workEnvelope,
          baseDistance: expectedBaseDistance,
        );

        // X: 5mm available - 1mm buffer = 4mm, 4/0.4167 ≈ 9.6 (but clamped to 1.0)
        // Y: 5mm available - 1mm buffer = 4mm, 4/0.4167 ≈ 9.6 (but clamped to -1.0)
        // Since movement is very small relative to available space, no filtering needed
        expect(filteredInput.x, closeTo(1.0, 0.01));
        expect(filteredInput.y, closeTo(-1.0, 0.01));
      });

      test('processes diagonal movement with proper feed rate scaling', () {
        // Test the complete joystick processing pipeline
        final processed = JoystickProcessor.processWithSoftLimits(
          rawX: 0.7,
          rawY: 0.7,
          selectedFeedRate: 1000,
          currentPosition: centerMachinePosition,
          workEnvelope: workEnvelope,
        );

        // Should maintain diagonal scaling after filtering
        expect(processed.isActive, isTrue);
        expect(processed.x, closeTo(0.7, 0.01));
        expect(processed.y, closeTo(0.7, 0.01));
        
        // Feed rate should be scaled based on magnitude
        final expectedMagnitude = vm.Vector2(0.7, 0.7).length;
        final expectedFeedRate = 1000.0 * expectedMagnitude;
        expect(processed.scaledFeedRate, closeTo(expectedFeedRate, 1.0));
      });

      test('handles machine position at boundary correctly', () {
        final atBoundary = vm.Vector3(0.0, -100.0, -50.0); // At X max, Y min
        
        // Use large baseDistance to force filtering
        final filteredInput = SoftLimitChecker.filterJoystickInput(
          rawX: 0.5,   // Try to move beyond X boundary
          rawY: -0.5,  // Try to move beyond Y boundary  
          currentPosition: atBoundary,
          workEnvelope: workEnvelope,
          baseDistance: 10.0, // Large movement that would exceed boundaries
        );

        // X movement should be limited to safety buffer allowance
        // safeMaxX = 0.0 - 1.0 = -1.0, so allowed movement = -1.0 - 0.0 = -1.0mm
        // Joystick value = -1.0 / 10.0 = -0.1
        expect(filteredInput.x, closeTo(-0.1, 0.001));
        
        // Y movement toward center should be allowed (moving away from Y min boundary)
        expect(filteredInput.y, equals(-0.5));
      });

      test('allows movement away from boundaries', () {
        final atCorner = vm.Vector3(-1.0, -99.0, -50.0); // Near X max and Y min but not at exact boundary
        
        final filteredInput = SoftLimitChecker.filterJoystickInput(
          rawX: -0.5,  // Move away from X boundary (toward negative X = away from 0)
          rawY: -0.5,  // Move away from Y boundary (toward positive Y in CNC coords = away from -100)
          currentPosition: atCorner,
          workEnvelope: workEnvelope,
          baseDistance: 10.0,
        );

        // Both movements should be allowed since they move away from boundaries
        expect(filteredInput.x, equals(-0.5));
        expect(filteredInput.y, equals(-0.5));
      });
    });

    group('Coordinate System Transformations', () {
      test('handles Y-axis inversion correctly in filtering', () {
        final nearYBoundary = vm.Vector3(-50.0, -5.0, -50.0); // Near Y max (0)
        
        // Joystick Y- (up) should move towards CNC Y+ (away from operator)
        final filteredInput = SoftLimitChecker.filterJoystickInput(
          rawX: 0.0,
          rawY: -1.0,  // Joystick up
          currentPosition: nearYBoundary,
          workEnvelope: workEnvelope,
          baseDistance: 10.0,
        );

        // Should be filtered due to proximity to Y max boundary
        // Available space: 5mm - 1mm buffer = 4mm, 4/10 = 0.4
        expect(filteredInput.x, equals(0.0));
        expect(filteredInput.y, closeTo(-0.4, 0.01));
      });

      test('processes joystick coordinates through complete pipeline', () {
        // Test that joystick input -> CNC movement -> filtering -> back to joystick works
        final rawX = 0.6;
        final rawY = -0.8; // Joystick up
        
        final processed = JoystickProcessor.processWithSoftLimits(
          rawX: rawX,
          rawY: rawY,
          selectedFeedRate: 800,
          currentPosition: centerMachinePosition,
          workEnvelope: workEnvelope,
        );

        // At center position, movement should not be filtered
        expect(processed.x, closeTo(rawX, 0.01));
        expect(processed.y, closeTo(rawY, 0.01));
        
        // Magnitude should be preserved
        final expectedMagnitude = vm.Vector2(rawX, rawY).length;
        expect(processed.magnitude, closeTo(expectedMagnitude, 0.01));
      });
    });

    group('Safety Buffer Behavior', () {
      test('applies 1mm safety buffer correctly', () {
        final nearBoundaryWithBuffer = vm.Vector3(-1.5, -50.0, -50.0); // 1.5mm from X max
        
        final filteredInput = SoftLimitChecker.filterJoystickInput(
          rawX: 1.0,  // Full movement towards boundary
          rawY: 0.0,
          currentPosition: nearBoundaryWithBuffer,
          workEnvelope: workEnvelope,
          baseDistance: 10.0,
        );

        // Available space: 1.5mm - 1mm buffer = 0.5mm, 0.5/10 = 0.05
        expect(filteredInput.x, closeTo(0.05, 0.01));
        expect(filteredInput.y, equals(0.0));
      });

      test('prevents movement when within safety buffer', () {
        final withinBuffer = vm.Vector3(-0.5, -50.0, -50.0); // 0.5mm from boundary (within 1mm buffer)
        
        final filteredInput = SoftLimitChecker.filterJoystickInput(
          rawX: 1.0,  // Try to move towards boundary
          rawY: 0.0,
          currentPosition: withinBuffer,
          workEnvelope: workEnvelope,
          baseDistance: 10.0,
        );

        // safeMaxX = 0.0 - 1.0 = -1.0, allowed movement = -1.0 - (-0.5) = -0.5mm  
        // Joystick value = -0.5 / 10.0 = -0.05
        expect(filteredInput.x, closeTo(-0.05, 0.001));
        expect(filteredInput.y, equals(0.0));
      });
    });
  });
}