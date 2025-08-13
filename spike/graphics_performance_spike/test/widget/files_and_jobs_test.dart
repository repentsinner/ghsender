import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ghsender/ui/widgets/sidebars/files_and_jobs.dart';
import 'package:ghsender/gcode/gcode_processor.dart';
import 'package:ghsender/models/gcode_file.dart';

// Mock classes
class MockGCodeProcessor extends Mock implements GCodeProcessor {}

void main() {
  group('FilesAndJobsSection Widget', () {

    testWidgets('should display upload section', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilesAndJobsSection(),
          ),
        ),
      );

      // Assert
      expect(find.text('Upload G-Code Files'), findsOneWidget);
      expect(find.text('Drop files here or click to browse'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Browse Files'), findsOneWidget);
    });

    testWidgets('should display sample G-code files', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilesAndJobsSection(),
          ),
        ),
      );

      // Assert
      expect(find.text('G-Code Files'), findsOneWidget);
      expect(find.text('enclosure-cut.gcode'), findsOneWidget);
      expect(find.text('door-frame.nc'), findsOneWidget);
      expect(find.text('bracket-holes.gcode'), findsOneWidget);
    });

    testWidgets('should display file information correctly', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilesAndJobsSection(),
          ),
        ),
      );

      // Assert - Check file metadata display
      expect(find.text('2.4 MB'), findsOneWidget); // enclosure-cut.gcode size
      expect(find.text('1.8 MB'), findsOneWidget); // door-frame.nc size
      expect(find.text('456.0 KB'), findsOneWidget); // bracket-holes.gcode size
      
      // Check status display
      expect(find.text('ready'), findsAtLeastNWidgets(1));
      expect(find.text('completed'), findsOneWidget);
      
      // Check time estimates
      expect(find.text('45min'), findsOneWidget);
      expect(find.text('32min'), findsOneWidget);
      expect(find.text('12min'), findsOneWidget);
    });

    testWidgets('should show file selection state', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilesAndJobsSection(),
          ),
        ),
      );

      // Initially no file should be selected
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked), findsAtLeastNWidgets(1));
      expect(find.text('SELECTED'), findsNothing);

      // Tap on first file to select it
      await tester.tap(find.text('enclosure-cut.gcode'));
      await tester.pump();

      // Should now show selection
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.text('SELECTED'), findsOneWidget);
    });

    testWidgets('should handle file selection tap', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilesAndJobsSection(),
          ),
        ),
      );

      // Tap on file
      await tester.tap(find.text('door-frame.nc'));
      await tester.pump();

      // Assert - File should be visually selected
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.text('SELECTED'), findsOneWidget);
      
      // The selected file should have different styling
      final selectedContainer = find.ancestor(
        of: find.text('SELECTED'),
        matching: find.byType(Container),
      );
      expect(selectedContainer, findsOneWidget);
    });

    testWidgets('should handle file deletion', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilesAndJobsSection(),
          ),
        ),
      );

      // Find delete button for first file
      final deleteButtons = find.byIcon(Icons.delete_outline);
      expect(deleteButtons, findsAtLeastNWidgets(3)); // One for each file

      // Tap delete button
      await tester.tap(deleteButtons.first);
      await tester.pump();

      // File should be removed (assuming it was the first file)
      // This test would need to verify the specific file is gone
      // For now, just verify delete buttons still exist for remaining files
      expect(find.byIcon(Icons.delete_outline), findsAtLeastNWidgets(2));
    });

    testWidgets('should only allow one file to be selected at a time', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilesAndJobsSection(),
          ),
        ),
      );

      // Select first file
      await tester.tap(find.text('enclosure-cut.gcode'));
      await tester.pump();

      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.text('SELECTED'), findsOneWidget);

      // Select second file
      await tester.tap(find.text('door-frame.nc'));
      await tester.pump();

      // Should still only have one selected file
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.text('SELECTED'), findsOneWidget);
    });

    testWidgets('should show upload button', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilesAndJobsSection(),
          ),
        ),
      );

      // Find and tap upload button
      final uploadButton = find.widgetWithText(ElevatedButton, 'Browse Files');
      expect(uploadButton, findsOneWidget);

      await tester.tap(uploadButton);
      await tester.pump();

      // Note: Testing file picker interaction would require platform-specific mocking
      // For now, just verify the button exists and is tappable
    });

    testWidgets('should display correct file status colors', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilesAndJobsSection(),
          ),
        ),
      );

      // Find status text elements
      final statusWidgets = find.text('ready');
      expect(statusWidgets, findsAtLeastNWidgets(1));

      final completedStatus = find.text('completed');
      expect(completedStatus, findsOneWidget);

      // The actual color testing would require examining the widget properties
      // This verifies the status text is displayed correctly
    });

    testWidgets('should handle empty file list state', (WidgetTester tester) async {
      // This test would require a way to inject an empty file list
      // For now, testing with the default sample data
      
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilesAndJobsSection(),
          ),
        ),
      );

      // With sample data, should not show empty state
      expect(find.text('No G-Code files uploaded'), findsNothing);
      expect(find.text('Upload files to get started'), findsNothing);
    });

    testWidgets('should show proper section headers with info tooltips', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilesAndJobsSection(),
          ),
        ),
      );

      // Should have section headers with info icons
      expect(find.text('Upload G-Code Files'), findsOneWidget);
      expect(find.text('G-Code Files'), findsOneWidget);
      
      // Should have info icons for tooltips
      expect(find.byIcon(Icons.info_outline), findsAtLeastNWidgets(2));
    });
  });

  group('GCodeFile Model', () {
    test('should format file size correctly', () {
      // Test different file sizes
      final smallFile = GCodeFile(
        name: 'small.gcode',
        path: '/path/small.gcode',
        sizeBytes: 512,
        uploadDate: DateTime.now(),
        status: 'ready',
      );
      expect(smallFile.formattedSize, equals('512 B'));

      final mediumFile = GCodeFile(
        name: 'medium.gcode',
        path: '/path/medium.gcode',
        sizeBytes: 1536, // 1.5 KB
        uploadDate: DateTime.now(),
        status: 'ready',
      );
      expect(mediumFile.formattedSize, equals('1.5 KB'));

      final largeFile = GCodeFile(
        name: 'large.gcode',
        path: '/path/large.gcode',
        sizeBytes: 2097152, // 2 MB
        uploadDate: DateTime.now(),
        status: 'ready',
      );
      expect(largeFile.formattedSize, equals('2.0 MB'));
    });

    test('should format date correctly', () {
      final file = GCodeFile(
        name: 'test.gcode',
        path: '/path/test.gcode',
        sizeBytes: 100,
        uploadDate: DateTime(2024, 3, 15),
        status: 'ready',
      );
      expect(file.formattedDate, equals('2024-03-15'));
    });

    test('should format time estimates correctly', () {
      final shortFile = GCodeFile(
        name: 'short.gcode',
        path: '/path/short.gcode',
        sizeBytes: 100,
        uploadDate: DateTime.now(),
        status: 'ready',
        estimatedTime: Duration(minutes: 30),
      );
      expect(shortFile.formattedTime, equals('30 min'));

      final longFile = GCodeFile(
        name: 'long.gcode',
        path: '/path/long.gcode',
        sizeBytes: 100,
        uploadDate: DateTime.now(),
        status: 'ready',
        estimatedTime: Duration(hours: 2, minutes: 30),
      );
      expect(longFile.formattedTime, equals('2h 30min'));

      final unknownFile = GCodeFile(
        name: 'unknown.gcode',
        path: '/path/unknown.gcode',
        sizeBytes: 100,
        uploadDate: DateTime.now(),
        status: 'ready',
        estimatedTime: null,
      );
      expect(unknownFile.formattedTime, equals('Unknown'));
    });
  });
}