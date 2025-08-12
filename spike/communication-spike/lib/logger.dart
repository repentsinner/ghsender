import 'dart:developer' as developer;
import 'package:logging/logging.dart';

class AppLogger {
  static final Map<String, Logger> _loggers = {};
  static bool _initialized = false;

  static Logger getLogger(String name) {
    if (!_initialized) {
      _initializeLogging();
    }
    
    return _loggers.putIfAbsent(name, () => Logger(name));
  }

  static void _initializeLogging() {
    Logger.root.level = Level.ALL;
    
    Logger.root.onRecord.listen((record) {
      final timestamp = DateTime.now().toIso8601String();
      final level = record.level.name.padRight(7);
      final logger = record.loggerName.padRight(20);
      final message = record.message;
      
      final logLine = '[$timestamp] $level [$logger] $message';
      
      // Output to console
      // ignore: avoid_print
      print(logLine);
      
      // Also send to developer console for better web debugging
      developer.log(
        message,
        time: record.time,
        level: record.level.value,
        name: record.loggerName,
        error: record.error,
        stackTrace: record.stackTrace,
      );
      
      // For errors, also log stack trace
      if (record.error != null) {
        // ignore: avoid_print
        print('ERROR DETAILS: ${record.error}');
      }
      if (record.stackTrace != null) {
        // ignore: avoid_print
        print('STACK TRACE: ${record.stackTrace}');
      }
    });
    
    _initialized = true;
  }

  // Convenience methods for common loggers
  static Logger get communication => getLogger('COMMUNICATION');
  static Logger get websocket => getLogger('WEBSOCKET');
  static Logger get tcp => getLogger('TCP');
  static Logger get ui => getLogger('UI');
  static Logger get grblhal => getLogger('GRBLHAL');
}