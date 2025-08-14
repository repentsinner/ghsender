import 'dart:async';
import 'dart:developer' as developer;
import 'package:logging/logging.dart';

/// Log message for UI display
class LogMessage {
  final DateTime time;
  final String level;
  final String name;
  final String message;

  LogMessage({
    required this.time,
    required this.level,
    required this.name,
    required this.message,
  });

  String get formattedTime => time.toString().substring(11, 23);
}

/// Central logger configuration for the ghSender CNC controller application.
/// Provides structured logging with appropriate levels for development and production.
///
/// This unified logging system supports both graphics rendering and CNC communication
/// components with clean, readable output.
class AppLogger {
  static bool _initialized = false;

  // Global log history storage - always collecting logs
  static final List<LogMessage> _logHistory = [];
  static const int _maxLogMessages = 1000; // Prevent memory issues

  // Stream controller for UI log messages
  static final StreamController<LogMessage> _logStreamController =
      StreamController<LogMessage>.broadcast();

  /// Stream of log messages for UI consumption
  static Stream<LogMessage> get logStream => _logStreamController.stream;

  /// Global log history - always available regardless of UI state
  static List<LogMessage> get logHistory => List.unmodifiable(_logHistory);

  /// Clear the global log history
  static void clearLogHistory() {
    _logHistory.clear();
  }

  // Category-specific loggers for different subsystems
  static final Logger _logger = Logger('general');
  static final Logger _communicationLogger = Logger('comms  ');
  static final Logger _gcodeLogger = Logger('gcode  ');
  static final Logger _machineControllerLogger = Logger('machine');
  static final Logger _visualizerLogger = Logger('viz    ');

  /// Initialize logging system (call once at app startup)
  static void initialize() {
    if (_initialized) return;

    // Configure logging to output to console with clean format
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      final message = record.message;

      // Create the formatted log message (same for both UI and developer.log)
      var formattedMessage = message;

      // Add error information if present
      if (record.error != null) {
        formattedMessage += '\n  Error: ${record.error}';
      }
      if (record.stackTrace != null) {
        formattedMessage += '\n  Stack trace:\n${record.stackTrace}';
      }

      // Create log message for UI with the same formatted content
      final uiLogMessage = LogMessage(
        time: record.time,
        name: record.loggerName,
        level: record.level.name,
        message: formattedMessage, // Use the same formatted message
      );

      // Store in global log history (always collecting)
      _logHistory.add(uiLogMessage);

      // Limit the number of stored messages for memory management
      if (_logHistory.length > _maxLogMessages) {
        _logHistory.removeRange(0, _logHistory.length - _maxLogMessages);
      }

      // Send to UI stream for real-time updates
      _logStreamController.add(uiLogMessage);

      // Use developer.log for clean output and IDE integration
      developer.log(
        formattedMessage,
        time: record.time,
        level: record.level.value,
        name: record.loggerName,
      );
    });

    _initialized = true;
  }

  /// Info level logging for general information
  static void info(String message) => _logger.info(message);

  /// Debug level logging for development information
  static void debug(String message) => _logger.fine(message);

  /// Warning level logging for non-critical issues
  static void warning(String message) => _logger.warning(message);

  /// Error level logging for error conditions
  static void error(String message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.severe(message, error, stackTrace);

  // Category-specific logging methods for communication subsystem
  /// Communication-specific info logging (WebSocket, GRBL protocol)
  static void commInfo(String message) => _communicationLogger.info(message);

  /// Communication-specific debug logging
  static void commDebug(String message) => _communicationLogger.fine(message);

  /// Communication-specific warning logging
  static void commWarning(String message) =>
      _communicationLogger.warning(message);

  /// Communication-specific error logging
  static void commError(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) => _communicationLogger.severe(message, error, stackTrace);

  // Category-specific logging methods for G-code processing
  /// G-code processing info logging (parsing, streaming, job control)
  static void gcodeInfo(String message) => _gcodeLogger.info(message);

  /// G-code processing debug logging
  static void gcodeDebug(String message) => _gcodeLogger.fine(message);

  /// G-code processing warning logging
  static void gcodeWarning(String message) => _gcodeLogger.warning(message);

  /// G-code processing error logging
  static void gcodeError(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) => _gcodeLogger.severe(message, error, stackTrace);

  // Category-specific logging methods for machine controller subsystem
  /// Machine controller info logging (state management, BLoC events)
  static void machineInfo(String message) =>
      _machineControllerLogger.info(message);

  /// Machine controller debug logging
  static void machineDebug(String message) =>
      _machineControllerLogger.fine(message);

  /// Machine controller warning logging
  static void machineWarning(String message) =>
      _machineControllerLogger.warning(message);

  /// Machine controller error logging
  static void machineError(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) => _machineControllerLogger.severe(message, error, stackTrace);

  // Category-specific logging methods for visualizer subsystem
  /// Visualizer info logging (rendering, scene management, graphics)
  static void vizInfo(String message) => _visualizerLogger.info(message);

  /// Visualizer debug logging
  static void vizDebug(String message) => _visualizerLogger.fine(message);

  /// Visualizer warning logging
  static void vizWarning(String message) => _visualizerLogger.warning(message);

  /// Visualizer error logging
  static void vizError(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) => _visualizerLogger.severe(message, error, stackTrace);
}
