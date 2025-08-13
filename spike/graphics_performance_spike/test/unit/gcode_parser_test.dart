import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:ghsender/gcode/gcode_parser.dart';

void main() {
  group('GCodeParser', () {
    late GCodeParser parser;

    setUp(() {
      parser = GCodeParser();
    });

    group('String Parsing', () {
      test('should parse simple linear moves', () {
        // Arrange
        final gcode = '''
G90 G21
G0 X0.0 Y0.0 Z1.0
G1 X10.0 Y0.0 F1000
G1 X10.0 Y10.0
G1 X0.0 Y10.0
G1 X0.0 Y0.0
        ''';

        // Act
        final result = parser.parseString(gcode);

        // Assert
        expect(result.commands, isNotEmpty);
        expect(result.totalOperations, equals(result.commands.length));
        
        // Check first move command (skip setup commands)
        final firstMove = result.commands.firstWhere(
          (cmd) => cmd.type == GCodeCommandType.rapidMove
        );
        expect(firstMove.position, vm.Vector3(0.0, 0.0, 1.0));
        
        // Check bounds calculation
        expect(result.minBounds.x, equals(0.0));
        expect(result.minBounds.y, equals(0.0));
        expect(result.maxBounds.x, equals(10.0));
        expect(result.maxBounds.y, equals(10.0));
      });

      test('should parse arc movements with I,J parameters', () {
        // Arrange
        final gcode = '''
G90 G21
G0 X0.0 Y0.0
G2 X10.0 Y5.0 I0.0 J5.0
G3 X5.0 Y10.0 I-5.0 J0.0
        ''';

        // Act
        final result = parser.parseString(gcode);

        // Assert
        final clockwiseArc = result.commands.firstWhere(
          (cmd) => cmd.type == GCodeCommandType.clockwiseArc
        );
        expect(clockwiseArc.position, vm.Vector3(10.0, 5.0, 0.0));
        expect(clockwiseArc.center, vm.Vector3(0.0, 5.0, 0.0));

        final counterClockwiseArc = result.commands.firstWhere(
          (cmd) => cmd.type == GCodeCommandType.counterClockwiseArc
        );
        expect(counterClockwiseArc.position, vm.Vector3(5.0, 10.0, 0.0));
        expect(counterClockwiseArc.center, vm.Vector3(-5.0, 0.0, 0.0));
      });

      test('should handle feed rates correctly', () {
        // Arrange
        final gcode = '''
G1 X10.0 Y0.0 F1000
G1 X20.0 Y0.0 F500
G1 X30.0 Y0.0
        ''';

        // Act
        final result = parser.parseString(gcode);

        // Assert
        expect(result.commands[0].feedRate, equals(1000.0));
        expect(result.commands[1].feedRate, equals(500.0));
        expect(result.commands[2].feedRate, equals(500.0)); // Should maintain previous feed rate
      });

      test('should skip comments and empty lines', () {
        // Arrange
        final gcode = '''
; This is a comment
G90 G21
(Another comment style)

G0 X0.0 Y0.0
; End comment
        ''';

        // Act
        final result = parser.parseString(gcode);

        // Assert
        // Should only have actual movement commands, no comments
        expect(result.commands, isNotEmpty);
        for (final command in result.commands) {
          expect(command.type, isIn([
            GCodeCommandType.rapidMove,
            GCodeCommandType.linearMove,
            GCodeCommandType.clockwiseArc,
            GCodeCommandType.counterClockwiseArc,
          ]));
        }
      });

      test('should handle incremental positioning', () {
        // Test different G-code formats
        final gcode = '''
G0 X5.0 Y5.0
G01 X10.0 Y10.0
G02 X15.0 Y15.0 I2.5 J0.0
G03 X20.0 Y20.0 I0.0 J2.5
        ''';

        // Act
        final result = parser.parseString(gcode);

        // Assert
        expect(result.commands.length, equals(4));
        expect(result.commands[0].type, GCodeCommandType.rapidMove);
        expect(result.commands[1].type, GCodeCommandType.linearMove);
        expect(result.commands[2].type, GCodeCommandType.clockwiseArc);
        expect(result.commands[3].type, GCodeCommandType.counterClockwiseArc);
      });
    });

    group('File Parsing', () {
      test('should parse file from disk', () async {
        // Arrange
        final testFile = File('test/fixtures/test_gcode_temp.nc');
        await testFile.create(recursive: true);
        await testFile.writeAsString('''
; Test G-code file
G90 G21
G0 X0.0 Y0.0 Z1.0
G1 X10.0 Y0.0 F1000
G1 X10.0 Y10.0
        ''');

        try {
          // Act
          final result = await parser.parseFile(testFile.path);

          // Assert
          expect(result.commands, isNotEmpty);
          expect(result.totalOperations, greaterThan(0));
          expect(result.minBounds, isNotNull);
          expect(result.maxBounds, isNotNull);
        } finally {
          // Clean up
          if (await testFile.exists()) {
            await testFile.delete();
          }
        }
      });

      test('should throw exception for non-existent file', () async {
        // Act & Assert
        expect(
          () => parser.parseFile('/nonexistent/file.gcode'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Edge Cases', () {
      test('should handle empty G-code', () {
        // Arrange
        final gcode = '''
; Empty G-code file
; Just comments
        ''';

        // Act
        final result = parser.parseString(gcode);

        // Assert
        expect(result.commands, isEmpty);
        expect(result.totalOperations, equals(0));
      });

      test('should handle malformed G-code gracefully', () {
        // Arrange
        final gcode = '''
G90 G21
INVALID_COMMAND X10.0
G1 X10.0 Y10.0
BROKEN LINE
G1 X0.0 Y0.0
        ''';

        // Act
        final result = parser.parseString(gcode);

        // Assert
        // Should parse valid commands and skip invalid ones
        expect(result.commands, isNotEmpty);
        expect(result.commands.length, equals(2)); // Only the valid G1 commands
      });

      test('should handle missing coordinates', () {
        // Arrange
        final gcode = '''
G90 G21
G0 X10.0 Y10.0 Z1.0
G1 F1000
G1 X20.0
G1 Y20.0
        ''';

        // Act
        final result = parser.parseString(gcode);

        // Assert
        expect(result.commands, isNotEmpty);
        // Commands with missing coordinates should use current position
        final lastCommand = result.commands.last;
        expect(lastCommand.position.x, equals(20.0)); // Should maintain X from previous
        expect(lastCommand.position.y, equals(20.0));
      });

      test('should calculate bounds correctly for negative coordinates', () {
        // Arrange
        final gcode = '''
G90 G21
G0 X-10.0 Y-5.0 Z1.0
G1 X5.0 Y10.0
G1 X-5.0 Y-10.0
        ''';

        // Act
        final result = parser.parseString(gcode);

        // Assert
        expect(result.minBounds.x, equals(-10.0));
        expect(result.minBounds.y, equals(-10.0));
        expect(result.maxBounds.x, equals(5.0));
        expect(result.maxBounds.y, equals(10.0));
      });
    });

    group('Complex Movements', () {
      test('should parse R-format arc commands', () {
        // Arrange
        final gcode = '''
G90 G21
G0 X0.0 Y0.0
G2 X10.0 Y0.0 R5.0
        ''';

        // Act
        final result = parser.parseString(gcode);

        // Assert
        final arcCommand = result.commands.firstWhere(
          (cmd) => cmd.type == GCodeCommandType.clockwiseArc
        );
        expect(arcCommand.radius, equals(5.0));
        expect(arcCommand.position, vm.Vector3(10.0, 0.0, 0.0));
      });
    });
  });
}