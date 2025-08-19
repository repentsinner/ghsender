import 'package:equatable/equatable.dart';

/// Severity levels for machine conditions (alarms and errors)
enum ConditionSeverity {
  info,
  warning, 
  error,
  critical,
  fatal;

  /// Display name for UI
  String get displayName {
    switch (this) {
      case ConditionSeverity.info:
        return 'Info';
      case ConditionSeverity.warning:
        return 'Warning';
      case ConditionSeverity.error:
        return 'Error';
      case ConditionSeverity.critical:
        return 'Critical';
      case ConditionSeverity.fatal:
        return 'Fatal';
    }
  }

  /// Icon for UI display
  String get icon {
    switch (this) {
      case ConditionSeverity.info:
        return 'ℹ️';
      case ConditionSeverity.warning:
        return '⚠️';
      case ConditionSeverity.error:
        return '❌';
      case ConditionSeverity.critical:
        return '🚨';
      case ConditionSeverity.fatal:
        return '💀';
    }
  }
}

/// Recovery actions for alarm and error conditions
enum RecoveryAction {
  none,
  unlock,
  home,
  reset,
  manual;

  /// Display name for UI
  String get displayName {
    switch (this) {
      case RecoveryAction.none:
        return 'No Action Required';
      case RecoveryAction.unlock:
        return 'Unlock Machine';
      case RecoveryAction.home:
        return 'Home Machine';
      case RecoveryAction.reset:
        return 'Soft Reset';
      case RecoveryAction.manual:
        return 'Manual Intervention';
    }
  }

  /// Command to send for this recovery action
  String? get command {
    switch (this) {
      case RecoveryAction.unlock:
        return '\$X';
      case RecoveryAction.home:
        return '\$H';
      case RecoveryAction.reset:
        return null; // Soft reset is raw bytes [0x18]
      case RecoveryAction.none:
      case RecoveryAction.manual:
        return null;
    }
  }

  /// Whether this action sends raw bytes instead of string command
  bool get isRawBytes {
    return this == RecoveryAction.reset;
  }

  /// Raw bytes for this action (only for reset)
  List<int>? get rawBytes {
    switch (this) {
      case RecoveryAction.reset:
        return [0x18]; // Soft reset
      default:
        return null;
    }
  }
}

/// Metadata for alarm codes from $EA/$EAG commands
class AlarmMetadata extends Equatable {
  final int code;
  final String name;
  final String description;
  final int? groupId;
  final ConditionSeverity severity;
  final RecoveryAction recommendedAction;
  final DateTime receivedAt;

  const AlarmMetadata({
    required this.code,
    required this.name,
    required this.description,
    this.groupId,
    required this.severity,
    required this.recommendedAction,
    required this.receivedAt,
  });

  @override
  List<Object?> get props => [
        code,
        name,
        description,
        groupId,
        severity,
        recommendedAction,
        receivedAt,
      ];

  /// Parse alarm metadata from $EA command response
  /// Format: [ALARMCODE:1|Hard limit|Hard limit has been triggered...]
  static AlarmMetadata? parseFromExtendedLine(String line, DateTime timestamp) {
    // Remove brackets and split by pipe
    final content = line.trim();
    if (!content.startsWith('[ALARMCODE:') || !content.endsWith(']')) {
      return null;
    }

    try {
      final inner = content.substring(11, content.length - 1); // Remove [ALARMCODE: and ]
      final parts = inner.split('|');
      
      if (parts.length < 3) return null;

      final code = int.parse(parts[0]);
      final name = parts[1];
      final description = parts[2];

      // Determine severity and recovery action based on alarm code
      final severity = _determineSeverity(code);
      final recoveryAction = _determineRecoveryAction(code);

      return AlarmMetadata(
        code: code,
        name: name,
        description: description,
        severity: severity,
        recommendedAction: recoveryAction,
        receivedAt: timestamp,
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse alarm metadata from $EAG command response (grbl CSV format)
  static AlarmMetadata? parseFromCsvLine(String line, DateTime timestamp) {
    // TODO: Implement CSV parsing when we understand the exact format
    // For now, fall back to extended format parsing
    return parseFromExtendedLine(line, timestamp);
  }

  /// Determine severity based on alarm code
  static ConditionSeverity _determineSeverity(int code) {
    switch (code) {
      case 1: // Hard limit
      case 2: // Soft limit
      case 10: // E-stop
        return ConditionSeverity.critical;
      case 11: // Homing required
        return ConditionSeverity.warning;
      default:
        return ConditionSeverity.error;
    }
  }

  /// Determine recommended recovery action based on alarm code
  static RecoveryAction _determineRecoveryAction(int code) {
    switch (code) {
      case 1: // Hard limit
      case 2: // Soft limit
      case 10: // E-stop
        return RecoveryAction.unlock;
      case 11: // Homing required
        return RecoveryAction.home;
      default:
        return RecoveryAction.reset;
    }
  }
}

/// Metadata for error codes from $EE/$EEG commands  
class ErrorMetadata extends Equatable {
  final int code;
  final String name;
  final String description;
  final int? groupId;
  final ConditionSeverity severity;
  final DateTime receivedAt;

  const ErrorMetadata({
    required this.code,
    required this.name,
    required this.description,
    this.groupId,
    required this.severity,
    required this.receivedAt,
  });

  @override
  List<Object?> get props => [
        code,
        name,
        description,
        groupId,
        severity,
        receivedAt,
      ];

  /// Parse error metadata from $EE command response
  /// Format: [ERRORCODE:1|Expected command letter|G-code words consist of a letter and a value...]
  static ErrorMetadata? parseFromExtendedLine(String line, DateTime timestamp) {
    // Remove brackets and split by pipe
    final content = line.trim();
    if (!content.startsWith('[ERRORCODE:') || !content.endsWith(']')) {
      return null;
    }

    try {
      final inner = content.substring(11, content.length - 1); // Remove [ERRORCODE: and ]
      final parts = inner.split('|');
      
      if (parts.length < 3) return null;

      final code = int.parse(parts[0]);
      final name = parts[1];
      final description = parts[2];

      // Determine severity based on error code
      final severity = _determineSeverity(code);

      return ErrorMetadata(
        code: code,
        name: name,
        description: description,
        severity: severity,
        receivedAt: timestamp,
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse error metadata from $EEG command response (grbl CSV format)
  static ErrorMetadata? parseFromCsvLine(String line, DateTime timestamp) {
    // TODO: Implement CSV parsing when we understand the exact format
    // For now, fall back to extended format parsing
    return parseFromExtendedLine(line, timestamp);
  }

  /// Determine severity based on error code
  static ConditionSeverity _determineSeverity(int code) {
    switch (code) {
      case 1: // Expected command letter
      case 2: // Bad number format
      case 3: // Invalid statement
        return ConditionSeverity.error;
      case 20: // Unsupported command
      case 21: // Modal group violation
        return ConditionSeverity.warning;
      default:
        return ConditionSeverity.error;
    }
  }
}

/// Group information for alarms and errors
class ConditionGroup extends Equatable {
  final int id;
  final int? parentId;
  final String name;
  final DateTime receivedAt;

  const ConditionGroup({
    required this.id,
    this.parentId,
    required this.name,
    required this.receivedAt,
  });

  @override
  List<Object?> get props => [id, parentId, name, receivedAt];

  /// Parse group from response line if it exists
  static ConditionGroup? parseFromLine(String line, DateTime timestamp) {
    // TODO: Implement group parsing if grblHAL supports alarm/error groups
    // This is a placeholder for future implementation
    return null;
  }
}

/// Active condition combining current state with metadata
class ActiveCondition extends Equatable {
  final int code;
  final bool isAlarm; // true for alarm, false for error
  final AlarmMetadata? alarmMetadata;
  final ErrorMetadata? errorMetadata;
  final DateTime detectedAt;

  const ActiveCondition({
    required this.code,
    required this.isAlarm,
    this.alarmMetadata,
    this.errorMetadata,
    required this.detectedAt,
  });

  @override
  List<Object?> get props => [
        code,
        isAlarm,
        alarmMetadata,
        errorMetadata,
        detectedAt,
      ];

  /// Get display name with fallback
  String get name {
    if (isAlarm && alarmMetadata != null) {
      return alarmMetadata!.name;
    } else if (!isAlarm && errorMetadata != null) {
      return errorMetadata!.name;
    }
    return isAlarm ? 'Alarm $code' : 'Error $code';
  }

  /// Get description with fallback
  String get description {
    if (isAlarm && alarmMetadata != null) {
      return alarmMetadata!.description;
    } else if (!isAlarm && errorMetadata != null) {
      return errorMetadata!.description;
    }
    return isAlarm ? 'Alarm code $code occurred' : 'Error code $code occurred';
  }

  /// Get severity with fallback
  ConditionSeverity get severity {
    if (isAlarm && alarmMetadata != null) {
      return alarmMetadata!.severity;
    } else if (!isAlarm && errorMetadata != null) {
      return errorMetadata!.severity;
    }
    return isAlarm ? ConditionSeverity.critical : ConditionSeverity.error;
  }

  /// Get recommended recovery action (only for alarms)
  RecoveryAction get recommendedAction {
    if (isAlarm && alarmMetadata != null) {
      return alarmMetadata!.recommendedAction;
    }
    return RecoveryAction.none;
  }

  /// Get formatted display text
  String get formattedText {
    final prefix = isAlarm ? 'Alarm' : 'Error';
    return '$prefix $code: $name';
  }
}