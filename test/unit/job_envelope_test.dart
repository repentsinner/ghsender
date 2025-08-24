import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:ghsender/domain/value_objects/job_envelope.dart';
import 'package:ghsender/models/bounding_box.dart';
import 'package:ghsender/domain/value_objects/work_envelope.dart';

void main() {
  group('JobEnvelope', () {
    late BoundingBox testBounds;
    late JobEnvelope jobEnvelope;
    late DateTime testTime;
    
    setUp(() {
      testTime = DateTime.now();
      testBounds = BoundingBox(
        minBounds: vm.Vector3(-10.0, -20.0, 0.0),
        maxBounds: vm.Vector3(50.0, 30.0, 5.0),
      );
      jobEnvelope = JobEnvelope(
        bounds: testBounds,
        lastUpdated: testTime,
        jobName: 'Test Job',
        totalOperations: 150,
      );
    });

    group('Construction', () {
      test('should create JobEnvelope with all properties', () {
        expect(jobEnvelope.bounds, equals(testBounds));
        expect(jobEnvelope.lastUpdated, equals(testTime));
        expect(jobEnvelope.jobName, equals('Test Job'));
        expect(jobEnvelope.totalOperations, equals(150));
        expect(jobEnvelope.isEmpty, isFalse);
      });

      test('should create JobEnvelope from legacy bounds', () {
        final minBounds = vm.Vector3(-5.0, -10.0, 0.0);
        final maxBounds = vm.Vector3(25.0, 15.0, 3.0);
        
        final envelope = JobEnvelope.fromBounds(
          minBounds: minBounds,
          maxBounds: maxBounds,
          jobName: 'Legacy Job',
          totalOperations: 100,
        );

        expect(envelope.minBounds, equals(minBounds));
        expect(envelope.maxBounds, equals(maxBounds));
        expect(envelope.jobName, equals('Legacy Job'));
        expect(envelope.totalOperations, equals(100));
      });

      test('should create empty JobEnvelope', () {
        final empty = JobEnvelope.empty(jobName: 'Empty Job');
        
        expect(empty.isEmpty, isTrue);
        expect(empty.jobName, equals('Empty Job'));
        expect(empty.totalOperations, isNull);
      });
    });

    group('Geometric Properties', () {
      test('should calculate bounds properties correctly', () {
        expect(jobEnvelope.minBounds, equals(vm.Vector3(-10.0, -20.0, 0.0)));
        expect(jobEnvelope.maxBounds, equals(vm.Vector3(50.0, 30.0, 5.0)));
        expect(jobEnvelope.center, equals(vm.Vector3(20.0, 5.0, 2.5)));
        expect(jobEnvelope.size, equals(vm.Vector3(60.0, 50.0, 5.0)));
      });

      test('should calculate dimensions correctly', () {
        expect(jobEnvelope.width, equals(60.0));
        expect(jobEnvelope.height, equals(50.0));
        expect(jobEnvelope.depth, equals(5.0));
      });

      test('should identify 2D jobs correctly', () {
        // 3D job
        expect(jobEnvelope.is2D, isFalse);
        
        // 2D job (minimal Z depth)
        final bounds2D = BoundingBox(
          minBounds: vm.Vector3(0.0, 0.0, 0.0),
          maxBounds: vm.Vector3(10.0, 10.0, 0.0005), // 0.5 microns
        );
        final job2D = JobEnvelope(
          bounds: bounds2D,
          lastUpdated: DateTime.now(),
        );
        
        expect(job2D.is2D, isTrue);
      });
    });

    group('Work Envelope Compatibility', () {
      test('should check if job fits within work envelope', () {
        // Create work envelope larger than job
        final largeWorkEnvelope = WorkEnvelope(
          bounds: BoundingBox(
            minBounds: vm.Vector3(-50.0, -50.0, -10.0),
            maxBounds: vm.Vector3(100.0, 100.0, 20.0),
          ),
          lastUpdated: DateTime.now(),
        );
        
        expect(jobEnvelope.fitsWithin(largeWorkEnvelope), isTrue);
        
        // Create work envelope smaller than job
        final smallWorkEnvelope = WorkEnvelope(
          bounds: BoundingBox(
            minBounds: vm.Vector3(0.0, 0.0, 0.0),
            maxBounds: vm.Vector3(40.0, 20.0, 3.0),
          ),
          lastUpdated: DateTime.now(),
        );
        
        expect(jobEnvelope.fitsWithin(smallWorkEnvelope), isFalse);
      });

      test('should handle empty envelopes in fit checking', () {
        final emptyJob = JobEnvelope.empty();
        final emptyWork = WorkEnvelope(
          bounds: BoundingBox.empty(),
          lastUpdated: DateTime.now(),
        );
        
        expect(emptyJob.fitsWithin(emptyWork), isFalse);
      });
    });

    group('Display Properties', () {
      test('should generate correct summary for 3D job', () {
        final summary = jobEnvelope.summary;
        
        expect(summary, contains('Test Job'));
        expect(summary, contains('(150 ops)'));
        expect(summary, contains('60.0 × 50.0 × 5.0 mm'));
      });

      test('should generate correct dimensions string for 3D job', () {
        final dimensions = jobEnvelope.dimensionsString;
        expect(dimensions, equals('60.0 × 50.0 × 5.0 mm'));
      });

      test('should generate correct dimensions string for 2D job', () {
        final bounds2D = BoundingBox(
          minBounds: vm.Vector3(0.0, 0.0, 0.0),
          maxBounds: vm.Vector3(10.0, 5.0, 0.0),
        );
        final job2D = JobEnvelope(
          bounds: bounds2D,
          lastUpdated: DateTime.now(),
        );
        
        final dimensions = job2D.dimensionsString;
        expect(dimensions, equals('10.0 × 5.0 mm')); // No Z dimension for 2D
      });

      test('should handle empty job in display properties', () {
        final empty = JobEnvelope.empty();
        
        expect(empty.summary, equals('No job geometry'));
        expect(empty.dimensionsString, equals('No geometry'));
      });

      test('should generate summary without operation count when null', () {
        final jobWithoutOps = JobEnvelope(
          bounds: testBounds,
          lastUpdated: testTime,
          jobName: 'Simple Job',
        );
        
        final summary = jobWithoutOps.summary;
        expect(summary, contains('Simple Job'));
        expect(summary, isNot(contains('ops)')));
        expect(summary, contains('60.0 × 50.0 × 5.0 mm'));
      });
    });

    group('Equality and Copying', () {
      test('should implement equality correctly', () {
        final identical = JobEnvelope(
          bounds: testBounds,
          lastUpdated: testTime,
          jobName: 'Test Job',
          totalOperations: 150,
        );
        
        final different = JobEnvelope(
          bounds: testBounds,
          lastUpdated: testTime,
          jobName: 'Different Job',
          totalOperations: 150,
        );
        
        expect(jobEnvelope, equals(identical));
        expect(jobEnvelope, isNot(equals(different)));
      });

      test('should copy with modifications', () {
        final newTime = DateTime.now().add(Duration(minutes: 1));
        final copied = jobEnvelope.copyWith(
          jobName: 'Modified Job',
          lastUpdated: newTime,
        );
        
        expect(copied.bounds, equals(jobEnvelope.bounds));
        expect(copied.jobName, equals('Modified Job'));
        expect(copied.lastUpdated, equals(newTime));
        expect(copied.totalOperations, equals(jobEnvelope.totalOperations));
      });
    });

    group('String Representation', () {
      test('should provide meaningful toString for valid job', () {
        final string = jobEnvelope.toString();
        expect(string, contains('JobEnvelope'));
        expect(string, contains('Test Job (150 ops): 60.0 × 50.0 × 5.0 mm'));
      });

      test('should provide meaningful toString for empty job', () {
        final empty = JobEnvelope.empty();
        final string = empty.toString();
        expect(string, equals('JobEnvelope.empty()'));
      });
    });
  });
}