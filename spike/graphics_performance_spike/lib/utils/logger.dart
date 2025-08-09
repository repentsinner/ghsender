import 'package:logger/logger.dart';

/// Central logger configuration for the graphics performance spike project.
/// Provides structured logging with appropriate levels for development and production.
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

  /// Info level logging for general information
  static void info(String message) => _logger.i(message);
  
  /// Debug level logging for development information
  static void debug(String message) => _logger.d(message);
  
  /// Warning level logging for non-critical issues
  static void warning(String message) => _logger.w(message);
  
  /// Error level logging for error conditions
  static void error(String message, [dynamic error, StackTrace? stackTrace]) => 
      _logger.e(message, error: error, stackTrace: stackTrace);
}