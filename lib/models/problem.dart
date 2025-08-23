import 'package:equatable/equatable.dart';

/// Action that can be performed to address a problem
class ProblemAction extends Equatable {
  /// Unique identifier for the action type
  final String id;
  
  /// Display label for the action button
  final String label;
  
  /// Type of action to perform
  final ProblemActionType type;
  
  /// Optional command or parameter for the action
  final String? command;
  
  /// Icon to display on the button
  final String? icon;

  const ProblemAction({
    required this.id,
    required this.label,
    required this.type,
    this.command,
    this.icon,
  });

  @override
  List<Object?> get props => [id, label, type, command, icon];
}

/// Types of actions that can be performed to resolve problems
enum ProblemActionType {
  /// Send a machine command (like homing, reset, etc.)
  machineCommand,
  /// Send a raw command/bytes to the controller
  rawCommand,
  /// Navigate to a specific UI panel
  navigate,
  /// Dismiss the problem
  dismiss,
}

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
  
  /// Available actions to resolve this problem
  final List<ProblemAction> actions;
  
  const Problem({
    required this.id,
    required this.severity,
    required this.source,
    required this.title,
    required this.description,
    required this.timestamp,
    this.metadata,
    this.actions = const [],
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
    List<ProblemAction>? actions,
  }) {
    return Problem(
      id: id ?? this.id,
      severity: severity ?? this.severity,
      source: source ?? this.source,
      title: title ?? this.title,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
      actions: actions ?? this.actions,
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
      'actions': actions.map((a) => a.id).toList(),
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
    actions,
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
  static const String cncInitializationTimeout = 'cnc_initialization_timeout';
  static const String cncNotGrblHalSystem = 'cnc_not_grblhal_system';
  static const String cncDoorOpen = 'cnc_door_open';
  static const String cncFirmwareUnresponsive = 'cnc_firmware_unresponsive';
  
  static const String fileManagerError = 'file_manager_error';
  static const String fileManagerNoFiles = 'file_manager_no_files';
  static const String fileManagerNoSelection = 'file_manager_no_selection';
  static const String fileManagerInvalidGcode = 'file_manager_invalid_gcode';
  
  static const String profileNoProfiles = 'profile_no_profiles';
  static const String profileLoadError = 'profile_load_error';
  static const String profileMissingAddress = 'profile_missing_address';
}

/// Common problem actions
class ProblemActions {
  /// Home the machine (for hard limit alarms)
  static const ProblemAction homeMachine = ProblemAction(
    id: 'home_machine',
    label: 'Home Machine',
    type: ProblemActionType.machineCommand,
    command: '\$H',
    icon: '🏠',
  );

  /// Reset alarms/errors
  static const ProblemAction resetAlarms = ProblemAction(
    id: 'reset_alarms',
    label: 'Reset Alarms',
    type: ProblemActionType.rawCommand,
    command: '0x18', // Soft reset
    icon: '🔄',
  );

  /// Unlock machine (after alarm reset)
  static const ProblemAction unlockMachine = ProblemAction(
    id: 'unlock_machine',
    label: 'Unlock Machine',
    type: ProblemActionType.machineCommand,
    command: '\$X',
    icon: '🔓',
  );

  /// Kill alarm (for non-critical alarms)
  static const ProblemAction killAlarm = ProblemAction(
    id: 'kill_alarm',
    label: 'Kill Alarm',
    type: ProblemActionType.machineCommand,
    command: '\$X',
    icon: '❌',
  );
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

  /// Create an initialization timeout problem
  static Problem cncInitializationTimeout({int? configMessagesReceived}) {
    final messagePart = configMessagesReceived != null && configMessagesReceived > 0
        ? ' Only received $configMessagesReceived configuration messages.'
        : ' No configuration responses received.';
    
    return Problem(
      id: ProblemIds.cncInitializationTimeout,
      severity: ProblemSeverity.error,
      source: 'CNC Communication',
      title: 'grblHAL Unresponsive',
      description: 'Controller responded to the initial connection but failed to respond '
          'to configuration and status requests within 15 seconds.$messagePart '
          'This indicates the controller firmware may be hung or unresponsive.',
      timestamp: DateTime.now(),
      metadata: {
        'configMessagesReceived': configMessagesReceived ?? 0,
        'timeoutSeconds': 15,
      },
      actions: [
        ProblemAction(
          id: 'reboot_controller',
          label: 'Reboot Controller',
          type: ProblemActionType.rawCommand,
          command: '0x18', // grblHAL soft reset
          icon: '🔄',
        ),
      ],
    );
  }

  /// Create a problem for non-grblHAL systems
  static Problem cncNotGrblHalSystem() {
    return Problem(
      id: ProblemIds.cncNotGrblHalSystem,
      severity: ProblemSeverity.error,
      source: 'CNC Communication',
      title: 'Not a grblHAL System',
      description: 'WebSocket connection established but no grblHAL welcome message received '
          'within the timeout period. The controller may not be running grblHAL firmware '
          'or may not support the expected communication protocol.',
      timestamp: DateTime.now(),
      metadata: {
        'expectedWelcome': 'grblHAL',
        'timeoutSeconds': 10,
      },
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

  /// Create a firmware unresponsive problem
  static Problem cncFirmwareUnresponsive() {
    return Problem(
      id: ProblemIds.cncFirmwareUnresponsive,
      severity: ProblemSeverity.error,
      source: 'Machine State',
      title: 'Firmware Unresponsive',
      description: 'The firmware sent a welcome message but is not responding to status requests. '
          'This typically indicates the firmware is hung or unresponsive.',
      timestamp: DateTime.now(),
      metadata: {
        'suggestedAction': 'reboot',
        'rebootCommand': '0x18',
      },
      actions: [
        ProblemAction(
          id: 'reboot_firmware',
          label: 'Reboot Firmware',
          type: ProblemActionType.rawCommand,
          command: '0x18', // grblHAL soft reset command
          icon: '🔄',
        ),
      ],
    );
  }
}