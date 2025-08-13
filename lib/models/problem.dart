import 'package:equatable/equatable.dart';

/// Severity levels for problems in the system
enum ProblemSeverity { 
  error,   // Critical issues that prevent functionality
  warning, // Issues that may impact performance or user experience
  info     // Informational notices
}

/// Extension to provide severity-specific properties
extension ProblemSeverityExtension on ProblemSeverity {
  /// Display name for the severity level
  String get displayName {
    switch (this) {
      case ProblemSeverity.error:
        return 'Error';
      case ProblemSeverity.warning:
        return 'Warning';
      case ProblemSeverity.info:
        return 'Info';
    }
  }
  
  /// Icon representation for the severity level
  String get icon {
    switch (this) {
      case ProblemSeverity.error:
        return '❌';
      case ProblemSeverity.warning:
        return '⚠️';
      case ProblemSeverity.info:
        return 'ℹ️';
    }
  }
  
  /// Priority for sorting (higher numbers = higher priority)
  int get priority {
    switch (this) {
      case ProblemSeverity.error:
        return 3;
      case ProblemSeverity.warning:
        return 2;
      case ProblemSeverity.info:
        return 1;
    }
  }
}

/// Represents a problem or issue detected in any subsystem
class Problem extends Equatable {
  /// Unique identifier for this problem
  final String id;
  
  /// Severity level of the problem
  final ProblemSeverity severity;
  
  /// Source subsystem that reported the problem
  final String source;
  
  /// Brief title describing the problem
  final String title;
  
  /// Detailed description of the problem and potential resolution
  final String description;
  
  /// When this problem was first detected
  final DateTime timestamp;
  
  /// Additional metadata for context (e.g., latency values, error codes)
  final Map<String, dynamic>? metadata;
  
  const Problem({
    required this.id,
    required this.severity,
    required this.source,
    required this.title,
    required this.description,
    required this.timestamp,
    this.metadata,
  });
  
  /// Create a copy with updated fields
  Problem copyWith({
    String? id,
    ProblemSeverity? severity,
    String? source,
    String? title,
    String? description,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return Problem(
      id: id ?? this.id,
      severity: severity ?? this.severity,
      source: source ?? this.source,
      title: title ?? this.title,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }
  
  /// Convert to JSON for debugging/logging
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'severity': severity.name,
      'source': source,
      'title': title,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }
  
  /// Create from JSON for debugging/logging
  factory Problem.fromJson(Map<String, dynamic> json) {
    return Problem(
      id: json['id'] as String,
      severity: ProblemSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => ProblemSeverity.error,
      ),
      source: json['source'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
  
  @override
  List<Object?> get props => [
    id,
    severity,
    source,
    title,
    description,
    timestamp,
    metadata,
  ];
  
  @override
  String toString() {
    return 'Problem{id: $id, severity: $severity, source: $source, title: $title}';
  }
}

/// Predefined problem IDs for common issues
class ProblemIds {
  static const String cncNotConnected = 'cnc_not_connected';
  static const String cncDisconnected = 'cnc_disconnected';
  static const String cncHighLatency = 'cnc_high_latency';
  static const String cncConnectionUnstable = 'cnc_connection_unstable';
  static const String cncMachineAlarm = 'cnc_machine_alarm';
  static const String cncConnectionTimeout = 'cnc_connection_timeout';
  static const String cncDoorOpen = 'cnc_door_open';
  
  static const String fileManagerError = 'file_manager_error';
  static const String fileManagerNoFiles = 'file_manager_no_files';
  static const String fileManagerNoSelection = 'file_manager_no_selection';
  static const String fileManagerInvalidGcode = 'file_manager_invalid_gcode';
  
  static const String profileNoProfiles = 'profile_no_profiles';
  static const String profileLoadError = 'profile_load_error';
  static const String profileMissingAddress = 'profile_missing_address';
}

/// Factory methods for creating common problems
class ProblemFactory {
  /// Create a CNC not connected problem
  static Problem cncNotConnected() {
    return Problem(
      id: ProblemIds.cncNotConnected,
      severity: ProblemSeverity.error,
      source: 'CNC Communication',
      title: 'Not Connected',
      description: 'Controller address configured but no active connection. '
          'Check that the CNC controller is powered on and accessible at the configured address.',
      timestamp: DateTime.now(),
    );
  }
  
  /// Create a high latency problem
  static Problem cncHighLatency(double latencyMs) {
    return Problem(
      id: ProblemIds.cncHighLatency,
      severity: ProblemSeverity.warning,
      source: 'Performance',
      title: 'High Latency Detected',
      description: 'Average response time: ${latencyMs.toStringAsFixed(1)}ms (threshold: 20ms). '
          'This may indicate network congestion or controller processing delays.',
      timestamp: DateTime.now(),
      metadata: {'latencyMs': latencyMs},
    );
  }
  
  /// Create a machine alarm problem
  static Problem cncMachineAlarm(String alarmDetails) {
    return Problem(
      id: ProblemIds.cncMachineAlarm,
      severity: ProblemSeverity.warning,
      source: 'Machine State',
      title: 'Alarm Condition',
      description: 'Machine is in alarm state: $alarmDetails. '
          'Check safety systems and clear alarms before continuing.',
      timestamp: DateTime.now(),
      metadata: {'alarmDetails': alarmDetails},
    );
  }
  
  /// Create a connection timeout problem
  static Problem cncConnectionTimeout() {
    return Problem(
      id: ProblemIds.cncConnectionTimeout,
      severity: ProblemSeverity.error,
      source: 'CNC Communication',
      title: 'Connection Timeout',
      description: 'WebSocket connection validation timed out. '
          'The controller may not support WebSocket protocol or may be unreachable.',
      timestamp: DateTime.now(),
    );
  }
  
  /// Create a disconnected problem (for when connection was lost)
  static Problem cncDisconnected({String? reason, DateTime? disconnectedAt}) {
    return Problem(
      id: ProblemIds.cncDisconnected,
      severity: ProblemSeverity.error,
      source: 'CNC Communication',
      title: 'Connection Lost',
      description: reason != null 
          ? 'Connection to CNC controller was lost: $reason. Check network connectivity and controller status.'
          : 'Connection to CNC controller was lost. Check network connectivity and controller status.',
      timestamp: DateTime.now(),
      metadata: {
        'reason': reason,
        'disconnectedAt': disconnectedAt?.toIso8601String(),
      },
    );
  }
  
  /// Create a no profiles problem
  static Problem profileNoProfiles() {
    return Problem(
      id: ProblemIds.profileNoProfiles,
      severity: ProblemSeverity.error,
      source: 'Profile Manager',
      title: 'No Machine Profiles',
      description: 'At least one machine profile is required to connect to a CNC controller. '
          'Create a profile in the Settings panel with your controller\'s WebSocket address.',
      timestamp: DateTime.now(),
    );
  }
  
  /// Create a profile load error problem
  static Problem profileLoadError(String errorMessage) {
    return Problem(
      id: ProblemIds.profileLoadError,
      severity: ProblemSeverity.error,
      source: 'Profile Manager',
      title: 'Profile Load Failed',
      description: 'Failed to load machine profiles: $errorMessage. '
          'Check that profile data is not corrupted and try creating a new profile.',
      timestamp: DateTime.now(),
      metadata: {'errorMessage': errorMessage},
    );
  }
  
  /// Create a file manager error problem
  static Problem fileManagerError(String errorMessage) {
    return Problem(
      id: ProblemIds.fileManagerError,
      severity: ProblemSeverity.error,
      source: 'File Manager',
      title: 'File Operation Failed',
      description: 'File operation failed: $errorMessage. '
          'Check file permissions and ensure the file is a valid G-code file.',
      timestamp: DateTime.now(),
      metadata: {'errorMessage': errorMessage},
    );
  }
  
  /// Create a no files loaded problem
  static Problem fileManagerNoFiles() {
    return Problem(
      id: ProblemIds.fileManagerNoFiles,
      severity: ProblemSeverity.info,
      source: 'File Manager',
      title: 'No G-code Files',
      description: 'No G-code files are currently loaded. '
          'Upload G-code files through the File Manager to begin processing.',
      timestamp: DateTime.now(),
    );
  }
  
  /// Create a no file selected problem
  static Problem fileManagerNoSelection() {
    return Problem(
      id: ProblemIds.fileManagerNoSelection,
      severity: ProblemSeverity.info,
      source: 'File Manager',
      title: 'No G-code File Selected',
      description: 'G-code files are loaded but none is selected for processing. '
          'Select a file from the File Manager to prepare for machining.',
      timestamp: DateTime.now(),
    );
  }
  
  /// Create a door open problem
  static Problem cncDoorOpen() {
    return Problem(
      id: ProblemIds.cncDoorOpen,
      severity: ProblemSeverity.warning,
      source: 'Machine State',
      title: 'Safety Door Open',
      description: 'The machine safety door is open. The machine will not run while the door is open. '
          'Close the safety door to resume normal operation.',
      timestamp: DateTime.now(),
    );
  }
}