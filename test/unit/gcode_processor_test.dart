import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghsender/gcode/gcode_processor.dart';
import 'package:ghsender/models/gcode_file.dart';

void main() {
  group('GCodeProcessor', () {
    late GCodeProcessor processor;
    
    setUp(() {
      processor = GCodeProcessor.instance;
      processor.clearCurrentFile();
    });

    tearDown(() {
      processor.clearCurrentFile();
    });

    test('should process valid G-code file successfully', () async {
      // Create a temporary valid G-code file
      final tempDir = Directory.systemTemp.createTempSync('gcode_test_');
      final tempFile = File('${tempDir.path}/simple_square.gcode');
      await tempFile.writeAsString('''
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

      final testFile = GCodeFile(
        name: 'simple_square.gcode',
        path: tempFile.path,
        sizeBytes: await tempFile.length(),
        uploadDate: DateTime.now(),
        status: 'ready',
      );

      try {
        // Act
        await processor.processFile(testFile);

        // Assert
        expect(processor.hasValidFile, isTrue);
        expect(processor.currentFile, equals(testFile));
        expect(processor.currentParsedData, isNotNull);
        expect(processor.currentParsedData!.totalOperations, greaterThan(0));
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('should reject non-existent files', () async {
      final testFile = GCodeFile(
        name: 'nonexistent.gcode',
        path: '/nonexistent/path/file.gcode',
        sizeBytes: 100,
        uploadDate: DateTime.now(),
        status: 'ready',
      );

      // Act & Assert
      expect(
        () => processor.processFile(testFile),
        throwsA(isA<GCodeProcessingException>()),
      );
      
      expect(processor.hasValidFile, isFalse);
      // Note: currentFile might still be set even after failure, but hasValidFile should be false
      expect(processor.currentParsedData, isNull);
    });

    test('should clear current file', () async {
      // Create a valid file and process it
      final tempDir = Directory.systemTemp.createTempSync('gcode_test_');
      final tempFile = File('${tempDir.path}/test.gcode');
      await tempFile.writeAsString('G90 G21\nG0 X0.0 Y0.0 Z1.0\n');

      final testFile = GCodeFile(
        name: 'test.gcode',
        path: tempFile.path,
        sizeBytes: await tempFile.length(),
        uploadDate: DateTime.now(),
        status: 'ready',
      );

      try {
        await processor.processFile(testFile);
        expect(processor.hasValidFile, isTrue);

        // Act - Clear the file
        processor.clearCurrentFile();

        // Assert
        expect(processor.currentFile, isNull);
        expect(processor.currentParsedData, isNull);
        expect(processor.hasValidFile, isFalse);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('should prevent processing when already processing', () async {
      final tempDir = Directory.systemTemp.createTempSync('gcode_test_');
      final tempFile = File('${tempDir.path}/slow.gcode');
      // Create a larger file to ensure processing takes some time
      final content = List.generate(100, (i) => 'G1 X$i Y$i F1000').join('\n');
      await tempFile.writeAsString('G90 G21\n$content\n');

      final testFile = GCodeFile(
        name: 'test.gcode',
        path: tempFile.path,
        sizeBytes: await tempFile.length(),
        uploadDate: DateTime.now(),
        status: 'ready',
      );

      try {
        // Start processing
        final future1 = processor.processFile(testFile);
        
        // Should not be able to start another process
        expect(processor.isProcessing, isTrue);
        
        // Second call should complete without doing anything
        await processor.processFile(testFile);
        
        // Wait for first to complete
        await future1;
        
        expect(processor.isProcessing, isFalse);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('should return estimated visualization time', () {
      // Without processed data, should return zero
      expect(processor.getEstimatedVisualizationTime(), Duration.zero);
    });
  });
}