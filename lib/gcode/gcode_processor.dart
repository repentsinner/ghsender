import 'dart:async';
import 'dart:io';
import '../utils/logger.dart';
import '../domain/value_objects/gcode_path.dart';
import 'gcode_parser.dart' as parser; // Need GCodeParser and old GCodePath
import '../domain/value_objects/gcode_file.dart';

/// Central G-code processing engine that manages the pipeline between
/// file selection and various consumers (scene manager, CNC connection, etc.)
class GCodeProcessor {
  static GCodeProcessor? _instance;
  static GCodeProcessor get instance => _instance ??= GCodeProcessor._();

  GCodeProcessor._();

  // Current processing state
  GCodeFile? _currentFile;
  GCodePath? _currentParsedData;
  bool _isProcessing = false;

  // Stream controllers for notifying consumers
  final StreamController<GCodeProcessingEvent> _eventController =
      StreamController<GCodeProcessingEvent>.broadcast();

  // Getters for current state
  GCodeFile? get currentFile => _currentFile;
  GCodePath? get currentParsedData => _currentParsedData;
  bool get isProcessing => _isProcessing;
  Stream<GCodeProcessingEvent> get events => _eventController.stream;

  /// Process a selected G-code file
  Future<void> processFile(GCodeFile file) async {
    if (_isProcessing) {
      AppLogger.gcodeWarning('G-code processor is already processing a file');
      return;
    }

    _isProcessing = true;
    _currentFile = file;
    
    _eventController.add(GCodeProcessingEvent.started(file));
    AppLogger.gcodeInfo('Starting G-code processing for: ${file.name}');

    try {
      // Validate file exists and is readable
      final fileHandle = File(file.path);
      if (!await fileHandle.exists()) {
        throw GCodeProcessingException('File not found: ${file.path}');
      }

      // Parse the G-code file
      _eventController.add(GCodeProcessingEvent.parsing(file));
      AppLogger.gcodeInfo('Parsing G-code file: ${file.path}');

      final gcodeParser = parser.GCodeParser();
      _currentParsedData = await gcodeParser.parseFile(file.path);

      AppLogger.gcodeInfo('G-code parsing completed:');
      AppLogger.gcodeInfo('- Total operations: ${_currentParsedData!.totalOperations}');
      AppLogger.gcodeInfo('- Bounds: ${_currentParsedData!.minBounds} to ${_currentParsedData!.maxBounds}');

      // Validate parsed data
      if (_currentParsedData!.totalOperations == 0) {
        throw GCodeProcessingException('No valid G-code operations found in file');
      }

      // Notify consumers that processing is complete
      _eventController.add(GCodeProcessingEvent.completed(file, _currentParsedData!));
      AppLogger.gcodeInfo('G-code processing completed successfully');

    } catch (e) {
      AppLogger.gcodeError('G-code processing failed', e);
      _currentParsedData = null;
      _eventController.add(GCodeProcessingEvent.failed(file, e.toString()));
      rethrow;
    } finally {
      _isProcessing = false;
    }
  }

  /// Clear the current file and parsed data
  void clearCurrentFile() {
    if (_isProcessing) {
      AppLogger.gcodeWarning('Cannot clear file while processing');
      return;
    }

    final previousFile = _currentFile;
    _currentFile = null;
    _currentParsedData = null;

    if (previousFile != null) {
      _eventController.add(GCodeProcessingEvent.cleared(previousFile));
      AppLogger.gcodeInfo('Cleared current G-code file: ${previousFile.name}');
    }
  }

  /// Get estimated processing time for visualization
  Duration getEstimatedVisualizationTime() {
    if (_currentParsedData == null) return Duration.zero;
    
    // Rough estimate: 1ms per operation for visualization generation
    final operations = _currentParsedData!.totalOperations;
    return Duration(milliseconds: operations);
  }

  /// Check if the processor has a valid file ready for consumption
  bool get hasValidFile => _currentFile != null && _currentParsedData != null && !_isProcessing;

  /// Dispose of resources
  void dispose() {
    _eventController.close();
  }
}

/// Events emitted by the G-code processor
abstract class GCodeProcessingEvent {
  final GCodeFile file;
  final DateTime timestamp;

  const GCodeProcessingEvent(this.file, this.timestamp);

  factory GCodeProcessingEvent.started(GCodeFile file) = GCodeProcessingStarted;
  factory GCodeProcessingEvent.parsing(GCodeFile file) = GCodeProcessingParsing;
  factory GCodeProcessingEvent.completed(GCodeFile file, GCodePath parsedData) = GCodeProcessingCompleted;
  factory GCodeProcessingEvent.failed(GCodeFile file, String error) = GCodeProcessingFailed;
  factory GCodeProcessingEvent.cleared(GCodeFile file) = GCodeProcessingCleared;
}

class GCodeProcessingStarted extends GCodeProcessingEvent {
  GCodeProcessingStarted(GCodeFile file) : super(file, DateTime.now());
}

class GCodeProcessingParsing extends GCodeProcessingEvent {
  GCodeProcessingParsing(GCodeFile file) : super(file, DateTime.now());
}

class GCodeProcessingCompleted extends GCodeProcessingEvent {
  final GCodePath parsedData;

  GCodeProcessingCompleted(GCodeFile file, this.parsedData) : super(file, DateTime.now());
}

class GCodeProcessingFailed extends GCodeProcessingEvent {
  final String error;

  GCodeProcessingFailed(GCodeFile file, this.error) : super(file, DateTime.now());
}

class GCodeProcessingCleared extends GCodeProcessingEvent {
  GCodeProcessingCleared(GCodeFile file) : super(file, DateTime.now());
}

/// Exception thrown during G-code processing
class GCodeProcessingException implements Exception {
  final String message;
  
  const GCodeProcessingException(this.message);
  
  @override
  String toString() => 'GCodeProcessingException: $message';
}