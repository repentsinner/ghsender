import 'package:logger/logger.dart';

/// Central logger configuration for the graphics performance spike project.
/// Provides structured logging with appropriate levels for development and production.
/// 
/// This unified logging system will support both graphics rendering and CNC communication
/// components when integrated from communication-spike.
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  // Category-specific loggers for different subsystems
  static final Logger _communicationLogger = Logger(
    printer: PrettyPrinter(
      methodCount: 1,
      errorMethodCount: 5,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static final Logger _gcodeLogger = Logger(
    printer: PrettyPrinter(
      methodCount: 1,
      errorMethodCount: 3,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  /// Info level logging for general information
  static void info(String message) => _logger.i(message);
  
  /// Debug level logging for development information
  static void debug(String message) => _logger.d(message);
  
  /// Warning level logging for non-critical issues
  static void warning(String message) => _logger.w(message);
  
  /// Error level logging for error conditions
  static void error(String message, [dynamic error, StackTrace? stackTrace]) => 
      _logger.e(message, error: error, stackTrace: stackTrace);

  // Category-specific logging methods for communication subsystem
  /// Communication-specific info logging (WebSocket, GRBL protocol)
  static void commInfo(String message) => _communicationLogger.i('[COMM] $message');
  
  /// Communication-specific debug logging
  static void commDebug(String message) => _communicationLogger.d('[COMM] $message');
  
  /// Communication-specific warning logging
  static void commWarning(String message) => _communicationLogger.w('[COMM] $message');
  
  /// Communication-specific error logging
  static void commError(String message, [dynamic error, StackTrace? stackTrace]) => 
      _communicationLogger.e('[COMM] $message', error: error, stackTrace: stackTrace);

  // Category-specific logging methods for G-code processing
  /// G-code processing info logging (parsing, streaming, job control)
  static void gcodeInfo(String message) => _gcodeLogger.i('[GCODE] $message');
  
  /// G-code processing debug logging
  static void gcodeDebug(String message) => _gcodeLogger.d('[GCODE] $message');
  
  /// G-code processing warning logging
  static void gcodeWarning(String message) => _gcodeLogger.w('[GCODE] $message');
  
  /// G-code processing error logging
  static void gcodeError(String message, [dynamic error, StackTrace? stackTrace]) => 
      _gcodeLogger.e('[GCODE] $message', error: error, stackTrace: stackTrace);
}