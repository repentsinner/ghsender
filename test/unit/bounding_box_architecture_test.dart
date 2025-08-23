import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:ghsender/models/bounding_box.dart';
import 'package:ghsender/models/job_envelope.dart';
import 'package:ghsender/models/machine_controller.dart';
import 'package:ghsender/utils/soft_limit_checker.dart';

void main() {
  group('Bounding Box Architecture', () {
    group('WorkEnvelope vs JobEnvelope Distinction', () {
      late WorkEnvelope machineWorkEnvelope;
      late JobEnvelope gcodeJobEnvelope;
      
      setUp(() {
        // Machine work envelope - represents physical machine travel limits
        // Typical grblHAL setup with negative coordinates for machine limits
        machineWorkEnvelope = WorkEnvelope(
          bounds: BoundingBox(
            minBounds: vm.Vector3(-200.0, -300.0, -100.0), // Machine soft limits
            maxBounds: vm.Vector3(0.0, 0.0, 0.0),
          ),
          lastUpdated: DateTime.now(),
        );
        
        // G-code job envelope - represents actual job geometry bounds
        // A small part within the machine's travel area
        gcodeJobEnvelope = JobEnvelope(
          bounds: BoundingBox(
            minBounds: vm.Vector3(-50.0, -80.0, -5.0),  // G-code geometry
            maxBounds: vm.Vector3(-10.0, -20.0, 0.0),
          ),
          lastUpdated: DateTime.now(),
          jobName: 'Sample Part',
          totalOperations: 250,
        );
      });

      test('should demonstrate semantic distinction between envelopes', () {
        // WorkEnvelope is about machine capabilities
        expect(machineWorkEnvelope.minBounds.x, equals(-200.0));
        expect(machineWorkEnvelope.dimensions.x, equals(200.0)); // Machine X travel
        
        // JobEnvelope is about G-code content
        expect(gcodeJobEnvelope.minBounds.x, equals(-50.0));
        expect(gcodeJobEnvelope.width, equals(40.0)); // Actual part width
        expect(gcodeJobEnvelope.jobName, equals('Sample Part'));
      });

      test('should verify G-code job fits within machine limits', () {
        // The G-code job should fit within the machine's work envelope
        expect(gcodeJobEnvelope.fitsWithin(machineWorkEnvelope), isTrue);
        
        // Machine envelope should contain the job bounds
        expect(
          machineWorkEnvelope.bounds.containsBox(gcodeJobEnvelope.bounds), 
          isTrue,
        );
      });

      test('should demonstrate correct usage in soft limit checking', () {
        // Soft limit checking uses WorkEnvelope (machine limits)
        final machinePosition = vm.Vector3(-100.0, -150.0, -50.0);
        
        // Should enforce limits based on machine capabilities
        expect(
          SoftLimitChecker.shouldEnforceLimits(workEnvelope: machineWorkEnvelope),
          isTrue,
        );
        
        // Position should be within machine limits
        expect(
          SoftLimitChecker.isPositionWithinLimits(
            machinePosition, 
            machineWorkEnvelope,
          ),
          isTrue,
        );
        
        // NOTE: Soft limits don't care about G-code bounds - only machine limits
      });

      test('should show different purposes for camera and visualization', () {
        // Camera should focus on G-code geometry (JobEnvelope)
        final cameraTarget = gcodeJobEnvelope.center; // Center of actual work
        expect(cameraTarget, equals(vm.Vector3(-30.0, -50.0, -2.5)));
        
        // Machine limits (WorkEnvelope) are for safety, not visualization
        final machineLimitsCenter = machineWorkEnvelope.center;
        expect(machineLimitsCenter, equals(vm.Vector3(-100.0, -150.0, -50.0)));
        
        // Camera should focus on the job, not the machine limits
        expect(cameraTarget, isNot(equals(machineLimitsCenter)));
      });
    });

    group('BoundingBox Integration', () {
      test('should demonstrate unified BoundingBox usage', () {
        final bounds = BoundingBox(
          minBounds: vm.Vector3(10.0, 20.0, 30.0),
          maxBounds: vm.Vector3(40.0, 60.0, 80.0),
        );
        
        // Same BoundingBox can be used for both envelope types
        final workEnvelope = WorkEnvelope(
          bounds: bounds,
          lastUpdated: DateTime.now(),
        );
        
        final jobEnvelope = JobEnvelope(
          bounds: bounds,
          lastUpdated: DateTime.now(),
        );
        
        // Both should have identical geometric properties
        expect(workEnvelope.center, equals(jobEnvelope.center));
        expect(workEnvelope.dimensions, equals(jobEnvelope.size));
        expect(workEnvelope.minBounds, equals(jobEnvelope.minBounds));
        expect(workEnvelope.maxBounds, equals(jobEnvelope.maxBounds));
        
        // But different semantic purposes
        expect(workEnvelope.units, equals('mm')); // Machine units
        expect(jobEnvelope.jobName, isNull); // No job metadata on work envelope
      });
    });

    group('Real-world Scenario', () {
      test('should handle typical CNC scenario correctly', () {
        // Machine: 400x300mm travel, home position at max extents
        final machine = WorkEnvelope(
          bounds: BoundingBox(
            minBounds: vm.Vector3(-400.0, -300.0, -100.0),
            maxBounds: vm.Vector3(0.0, 0.0, 0.0),
          ),
          lastUpdated: DateTime.now(),
        );
        
        // Job: Small bracket in corner of workspace
        final bracket = JobEnvelope(
          bounds: BoundingBox(
            minBounds: vm.Vector3(-350.0, -250.0, -20.0),
            maxBounds: vm.Vector3(-320.0, -200.0, 0.0),
          ),
          lastUpdated: DateTime.now(),
          jobName: 'Corner Bracket',
          totalOperations: 450,
        );
        
        // Verify proper relationships
        expect(bracket.fitsWithin(machine), isTrue);
        expect(bracket.width, equals(30.0)); // 30mm wide bracket
        expect(machine.dimensions.x, equals(400.0)); // 400mm machine travel
        
        // Machine position for this job (center of bracket)
        final jobCenter = bracket.center;
        expect(
          SoftLimitChecker.isPositionWithinLimits(jobCenter, machine),
          isTrue,
        );
        
        // Camera should focus on bracket, not machine limits
        expect(jobCenter.x, closeTo(-335.0, 0.1));
        expect(machine.center.x, equals(-200.0)); // Different focus points
      });
    });
  });
}