import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ghsender/main.dart' as app;
import 'package:ghsender/gcode/gcode_processor.dart';
import 'package:ghsender/scene/scene_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('File Selection Flow Integration Tests', () {
    testWidgets('Complete file selection and scene update flow', (
      WidgetTester tester,
    ) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Verify app loads correctly
      expect(find.text('Graphics Performance Spike'), findsOneWidget);

      // Navigate to Files & Jobs sidebar (it should be the second activity item)
      final filesAndJobsButton = find.byTooltip('Files & Jobs').first;
      await tester.tap(filesAndJobsButton);
      await tester.pumpAndSettle();

      // Verify Files & Jobs section is visible
      expect(find.text('Upload G-Code Files'), findsOneWidget);
      expect(find.text('G-Code Files'), findsOneWidget);

      // Verify sample files are displayed
      expect(find.text('enclosure-cut.gcode'), findsOneWidget);
      expect(find.text('door-frame.nc'), findsOneWidget);
      expect(find.text('bracket-holes.gcode'), findsOneWidget);

      // Initially no file should be selected
      expect(find.text('SELECTED'), findsNothing);
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);

      // Tap on the first G-code file to select it
      await tester.tap(find.text('enclosure-cut.gcode'));
      await tester.pumpAndSettle();

      // Verify file is selected
      expect(find.text('SELECTED'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);

      // Wait for G-code processing to complete
      await tester.pumpAndSettle(Duration(seconds: 2));

      // Verify that the scene has been updated
      // This would require accessing the scene manager instance
      final sceneManager = SceneManager.instance;
      expect(sceneManager.initialized, isTrue);
      expect(sceneManager.sceneData, isNotNull);

      // Verify G-code processor has the file
      final processor = GCodeProcessor.instance;
      expect(processor.currentFile, isNotNull);
      expect(processor.currentFile!.name, equals('enclosure-cut.gcode'));
    });

    testWidgets('File selection changes update visualization', (
      WidgetTester tester,
    ) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to Files & Jobs
      final filesAndJobsButton = find.byTooltip('Files & Jobs').first;
      await tester.tap(filesAndJobsButton);
      await tester.pumpAndSettle();

      // Select first file
      await tester.tap(find.text('enclosure-cut.gcode'));
      await tester.pumpAndSettle(Duration(seconds: 1));

      // Get initial scene state
      final sceneManager = SceneManager.instance;

      // Select different file
      await tester.tap(find.text('door-frame.nc'));
      await tester.pumpAndSettle(Duration(seconds: 1));

      // Verify selection changed
      expect(find.text('SELECTED'), findsOneWidget);

      // Verify scene updated (object count might change)
      final newSceneObjects = sceneManager.sceneData?.objects.length ?? 0;
      // Scene should have been rebuilt (though object count might be similar)
      expect(
        newSceneObjects,
        greaterThan(3),
      ); // Should have more than just world axes
    });

    testWidgets('File deletion removes from list', (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to Files & Jobs
      final filesAndJobsButton = find.byTooltip('Files & Jobs').first;
      await tester.tap(filesAndJobsButton);
      await tester.pumpAndSettle();

      // Count initial files
      final initialDeleteButtons = find.byIcon(Icons.delete_outline);
      final initialFileCount = tester.widgetList(initialDeleteButtons).length;
      expect(initialFileCount, equals(3)); // Should have 3 sample files

      // Select a file first
      await tester.tap(find.text('bracket-holes.gcode'));
      await tester.pumpAndSettle();
      expect(find.text('SELECTED'), findsOneWidget);

      // Delete the selected file
      final deleteButtons = find.byIcon(Icons.delete_outline);
      await tester.tap(
        deleteButtons.last,
      ); // Delete the last file (bracket-holes.gcode)
      await tester.pumpAndSettle();

      // Verify file is removed
      expect(find.text('bracket-holes.gcode'), findsNothing);
      expect(
        find.text('SELECTED'),
        findsNothing,
      ); // Selection should be cleared

      // Verify fewer delete buttons
      final remainingDeleteButtons = find.byIcon(Icons.delete_outline);
      final remainingFileCount = tester
          .widgetList(remainingDeleteButtons)
          .length;
      expect(remainingFileCount, equals(initialFileCount - 1));

      // Verify processor state is cleared
      final processor = GCodeProcessor.instance;
      expect(processor.currentFile, isNull);
    });

    testWidgets('Activity bar navigation works correctly', (
      WidgetTester tester,
    ) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Should start with Session Initialization (first activity)
      expect(find.text('Session Initialization'), findsOneWidget);

      // Navigate to Files & Jobs
      final filesAndJobsButton = find.byTooltip('Files & Jobs').first;
      await tester.tap(filesAndJobsButton);
      await tester.pumpAndSettle();

      // Should show Files & Jobs section
      expect(find.text('Upload G-Code Files'), findsOneWidget);
      expect(find.text('Session Initialization'), findsNothing);

      // Navigate to Graphics section
      final graphicsButton = find.byTooltip('Graphics').first;
      await tester.tap(graphicsButton);
      await tester.pumpAndSettle();

      // Should show graphics content and hide Files & Jobs
      expect(find.text('Upload G-Code Files'), findsNothing);
    });

    testWidgets('Scene visualization responds to file selection', (
      WidgetTester tester,
    ) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Get initial scene state (empty scene with world axes)
      final sceneManager = SceneManager.instance;
      await tester.pumpAndSettle(
        Duration(seconds: 1),
      ); // Wait for initialization

      final initialObjectCount = sceneManager.sceneData?.objects.length ?? 0;
      expect(initialObjectCount, equals(3)); // Should have 3 world axes

      // Navigate to Files & Jobs and select a file
      final filesAndJobsButton = find.byTooltip('Files & Jobs').first;
      await tester.tap(filesAndJobsButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('enclosure-cut.gcode'));
      await tester.pumpAndSettle(Duration(seconds: 2));

      // Verify scene has been updated with G-code data
      final newObjectCount = sceneManager.sceneData?.objects.length ?? 0;
      expect(
        newObjectCount,
        greaterThan(initialObjectCount),
      ); // Should have G-code objects + world axes

      // Verify camera has been repositioned based on G-code bounds
      final camera = sceneManager.sceneData?.camera;
      expect(camera, isNotNull);
      expect(
        camera!.target.length,
        greaterThan(0),
      ); // Should be positioned at G-code center, not origin
    });

    testWidgets('Error handling for invalid file operations', (
      WidgetTester tester,
    ) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to Files & Jobs
      final filesAndJobsButton = find.byTooltip('Files & Jobs').first;
      await tester.tap(filesAndJobsButton);
      await tester.pumpAndSettle();

      // Try to use upload functionality
      final uploadButton = find.text('Browse Files');
      await tester.tap(uploadButton);
      await tester.pumpAndSettle();

      // Note: File picker would open here in real scenario
      // In test environment, this just verifies the button is responsive
      // Actual file upload testing would require platform-specific test setup
    });
  });

  group('Performance Tests', () {
    testWidgets('App startup performance', (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();

      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      stopwatch.stop();

      // Verify app starts within reasonable time
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(5000),
      ); // Less than 5 seconds

      // Verify key components are loaded
      expect(find.text('Graphics Performance Spike'), findsOneWidget);
    });

    testWidgets('File selection response time', (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to Files & Jobs
      final filesAndJobsButton = find.byTooltip('Files & Jobs').first;
      await tester.tap(filesAndJobsButton);
      await tester.pumpAndSettle();

      // Measure file selection response time
      final stopwatch = Stopwatch()..start();

      await tester.tap(find.text('enclosure-cut.gcode'));
      await tester.pumpAndSettle();

      stopwatch.stop();

      // Should respond quickly to selection
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(1000),
      ); // Less than 1 second for UI response

      // Visual selection should be immediate
      expect(find.text('SELECTED'), findsOneWidget);
    });
  });
}
