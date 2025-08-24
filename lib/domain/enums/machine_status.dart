/// Machine controller status enumeration
enum MachineStatus {
  unknown,
  idle,
  running,
  paused,
  alarm,
  error,
  jogging,
  homing,
  hold,
  door,
  check,
  sleep,
}

/// Extension for machine status display and behavior
extension MachineStatusExtension on MachineStatus {
  /// Human-readable display name
  String get displayName {
    switch (this) {
      case MachineStatus.unknown:
        return 'Unknown';
      case MachineStatus.idle:
        return 'Idle';
      case MachineStatus.running:
        return 'Running';
      case MachineStatus.paused:
        return 'Paused';
      case MachineStatus.alarm:
        return 'Alarm';
      case MachineStatus.error:
        return 'Error';
      case MachineStatus.jogging:
        return 'Jogging';
      case MachineStatus.homing:
        return 'Homing';
      case MachineStatus.hold:
        return 'Hold';
      case MachineStatus.door:
        return 'Door Open';
      case MachineStatus.check:
        return 'Check Mode';
      case MachineStatus.sleep:
        return 'Sleep';
    }
  }

  /// Status icon emoji
  String get icon {
    switch (this) {
      case MachineStatus.unknown:
        return '❓';
      case MachineStatus.idle:
        return '⚪';
      case MachineStatus.running:
        return '🟢';
      case MachineStatus.paused:
        return '⏸️';
      case MachineStatus.alarm:
        return '🚨';
      case MachineStatus.error:
        return '❌';
      case MachineStatus.jogging:
        return '🏃';
      case MachineStatus.homing:
        return '🏠';
      case MachineStatus.hold:
        return '✋';
      case MachineStatus.door:
        return '🚪';
      case MachineStatus.check:
        return '🔍';
      case MachineStatus.sleep:
        return '😴';
    }
  }

  /// Whether the machine is ready to accept new commands
  bool get isReady {
    switch (this) {
      case MachineStatus.idle:
      case MachineStatus.check:
        return true;
      default:
        return false;
    }
  }

  /// Whether the machine is actively processing
  bool get isActive {
    switch (this) {
      case MachineStatus.running:
      case MachineStatus.jogging:
      case MachineStatus.homing:
        return true;
      default:
        return false;
    }
  }

  /// Whether the machine has an error condition
  bool get hasError {
    switch (this) {
      case MachineStatus.alarm:
      case MachineStatus.error:
        return true;
      default:
        return false;
    }
  }

  /// Factory method to parse machine status from string
  static MachineStatus parseStatus(String statusString) {
    final status = statusString.toLowerCase().trim();
    
    if (status.contains('idle')) return MachineStatus.idle;
    if (status.contains('run')) return MachineStatus.running;
    if (status.contains('pause')) return MachineStatus.paused;
    if (status.contains('alarm')) return MachineStatus.alarm;
    if (status.contains('error')) return MachineStatus.error;
    if (status.contains('jog')) return MachineStatus.jogging;
    if (status.contains('home')) return MachineStatus.homing;
    if (status.contains('hold')) return MachineStatus.hold;
    if (status.contains('door')) return MachineStatus.door;
    if (status.contains('check')) return MachineStatus.check;
    if (status.contains('sleep')) return MachineStatus.sleep;
    
    return MachineStatus.unknown;
  }
}