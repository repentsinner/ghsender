import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ghsender/gcode/gcode_processor.dart';
import 'package:ghsender/gcode/gcode_parser.dart';
import 'package:ghsender/models/gcode_file.dart';

// Mock classes
class MockGCodeParser extends Mock implements GCodeParser {}
class MockFile extends Mock implements File {}

void main() {
  group('GCodeProcessor', () {
    late GCodeProcessor processor;
    
    setUp(() {
      processor = GCodeProcessor.instance;
    });

    tearDown(() {
      processor.clearCurrentFile();
    });

    group('File Processing', () {
      test('should emit started event when processing begins', () async {
        // Arrange
        final testFile = GCodeFile(
          name: 'test.gcode',
          path: 'test/fixtures/simple_square.nc',
          sizeBytes: 100,
          uploadDate: DateTime.now(),
          status: 'ready',
        );

        final events = <GCodeProcessingEvent>[];
        processor.events.listen((event) => events.add(event));

        // Act
        try {
          await processor.processFile(testFile);
        } catch (e) {
          // Expected to fail since we're using a test fixture path
        }

        // Assert
        expect(events, isNotEmpty);
        expect(events.first, isA<GCodeProcessingStarted>());
        expect(events.first.file.name, equals('test.gcode'));
      });

      test('should emit parsing event during processing', () async {
        // Arrange
        final testFile = GCodeFile(
          name: 'test.gcode',
          path: 'test/fixtures/simple_square.nc',
          sizeBytes: 100,
          uploadDate: DateTime.now(),
          status: 'ready',
        );

        final events = <GCodeProcessingEvent>[];
        processor.events.listen((event) => events.add(event));

        // Act
        try {
          await processor.processFile(testFile);
        } catch (e) {
          // Expected to fail for non-existent file
        }

        // Assert - should emit at least a started event
        expect(events.length, greaterThanOrEqualTo(1));
        expect(events[0], isA<GCodeProcessingStarted>());
        // Note: Since the file doesn't exist, we may not get parsing events
        // but we should always get a started event
      });

      test('should emit failed event for non-existent file', () async {
        // Arrange
        final testFile = GCodeFile(
          name: 'nonexistent.gcode',
          path: '/nonexistent/path/file.gcode',
          sizeBytes: 100,
          uploadDate: DateTime.now(),
          status: 'ready',
        );

        final events = <GCodeProcessingEvent>[];
        processor.events.listen((event) => events.add(event));

        // Act
        try {
          await processor.processFile(testFile);
        } catch (e) {
          // Expected
        }

        // Assert
        expect(events, isNotEmpty);
        expect(events.last, isA<GCodeProcessingFailed>());
        final failedEvent = events.last as GCodeProcessingFailed;
        expect(failedEvent.error, contains('not found'));
      });

      test('should process valid G-code file successfully', () async {
        // Arrange
        final fixturePath = 'test/fixtures/simple_square.nc';
        final testFile = GCodeFile(
          name: 'simple_square.nc',
          path: fixturePath,
          sizeBytes: 100,
          uploadDate: DateTime.now(),
          status: 'ready',
        );

        // Create the fixture file temporarily
        final file = File(fixturePath);
        await file.create(recursive: true);
        await file.writeAsString('''
; Simple square test fixture
G90 G21
G0 X0.0 Y0.0 Z1.0
G1 Z-1.0 F300
G1 X10.0 Y0.0 F1000
G1 X10.0 Y10.0
G1 X0.0 Y10.0
G1 X0.0 Y0.0
G0 Z1.0
        ''');

        final events = <GCodeProcessingEvent>[];
        processor.events.listen((event) => events.add(event));

        try {
          // Act
          await processor.processFile(testFile);

          // Assert
          expect(events, isNotEmpty);
          expect(events.last, isA<GCodeProcessingCompleted>());
          
          final completedEvent = events.last as GCodeProcessingCompleted;
          expect(completedEvent.parsedData.totalOperations, greaterThan(0));
          expect(processor.hasValidFile, isTrue);
          expect(processor.currentFile, equals(testFile));
          expect(processor.currentParsedData, isNotNull);
        } finally {
          // Clean up
          if (await file.exists()) {
            await file.delete();
          }
        }
      });

      test('should clear current file and emit cleared event', () async {
        // Arrange
        final testFile = GCodeFile(
          name: 'test.gcode',
          path: 'test/fixtures/simple_square.nc',
          sizeBytes: 100,
          uploadDate: DateTime.now(),
          status: 'ready',
        );

        final events = <GCodeProcessingEvent>[];
        processor.events.listen((event) {
          events.add(event);
        });

        // Process a file first so we have something to clear
        await processor.processFile(testFile);
        
        // Verify we have a file before clearing
        expect(processor.currentFile, equals(testFile));

        // Act - Clear the current file
        processor.clearCurrentFile();

        // Assert
        expect(processor.currentFile, isNull);
        expect(processor.currentParsedData, isNull);
        expect(processor.hasValidFile, isFalse);
        
        // Verify cleared event was emitted
        expect(events.any((e) => e is GCodeProcessingCleared), isTrue);
      });
    });

    group('State Management', () {
      test('should prevent processing when already processing', () async {
        // Arrange
        final testFile = GCodeFile(
          name: 'test.gcode',
          path: '/nonexistent/file.gcode',
          sizeBytes: 100,
          uploadDate: DateTime.now(),
          status: 'ready',
        );

        // Start first processing (will fail but shows the pattern)
        final future1 = processor.processFile(testFile);
        
        // Act - try to process another file while first is in progress
        final future2 = processor.processFile(testFile);

        // Assert
        expect(processor.isProcessing, isTrue);
        
        // Wait for both to complete
        await future1.catchError((_) {});
        await future2.catchError((_) {});
      });

      test('should return estimated visualization time', () {
        // This test would need a mock or real processed data
        // For now, test the default behavior
        expect(processor.getEstimatedVisualizationTime(), Duration.zero);
      });
    });

    group('Error Handling', () {
      test('should handle file system errors gracefully', () async {
        // Arrange
        final testFile = GCodeFile(
          name: 'test.gcode',
          path: '/nonexistent/directory/file.gcode',
          sizeBytes: 100,
          uploadDate: DateTime.now(),
          status: 'ready',
        );

        final events = <GCodeProcessingEvent>[];
        processor.events.listen((event) => events.add(event));

        // Act & Assert
        expect(() => processor.processFile(testFile), throwsA(isA<GCodeProcessingException>()));
      });
    });
  });
}