import 'package:equatable/equatable.dart';
import '../domain/value_objects/machine_coordinates.dart';

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
}

// MachineCoordinates has been moved to lib/domain/value_objects/machine_coordinates.dart

/// Spindle information
class SpindleState extends Equatable {
  final bool isRunning;
  final double speed; // RPM
  final double targetSpeed; // RPM
  final bool isClockwise;
  final DateTime lastUpdated;

  const SpindleState({
    required this.isRunning,
    required this.speed,
    required this.targetSpeed,
    this.isClockwise = true,
    required this.lastUpdated,
  });

  @override
  List<Object?> get props => [isRunning, speed, targetSpeed, isClockwise, lastUpdated];

  SpindleState copyWith({
    bool? isRunning,
    double? speed,
    double? targetSpeed,
    bool? isClockwise,
    DateTime? lastUpdated,
  }) {
    return SpindleState(
      isRunning: isRunning ?? this.isRunning,
      speed: speed ?? this.speed,
      targetSpeed: targetSpeed ?? this.targetSpeed,
      isClockwise: isClockwise ?? this.isClockwise,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Feed rate information
class FeedState extends Equatable {
  final double rate; // units per minute
  final double targetRate; // units per minute
  final String units; // "mm/min" or "inch/min"
  final DateTime lastUpdated;

  const FeedState({
    required this.rate,
    required this.targetRate,
    this.units = 'mm/min',
    required this.lastUpdated,
  });

  @override
  List<Object?> get props => [rate, targetRate, units, lastUpdated];

  FeedState copyWith({
    double? rate,
    double? targetRate,
    String? units,
    DateTime? lastUpdated,
  }) {
    return FeedState(
      rate: rate ?? this.rate,
      targetRate: targetRate ?? this.targetRate,
      units: units ?? this.units,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Active G/M codes on the machine
class ActiveCodes extends Equatable {
  final List<String> gCodes; // Active G codes (e.g., "G90", "G54")
  final List<String> mCodes; // Active M codes (e.g., "M3", "M8")
  final DateTime lastUpdated;

  const ActiveCodes({
    this.gCodes = const [],
    this.mCodes = const [],
    required this.lastUpdated,
  });

  @override
  List<Object?> get props => [gCodes, mCodes, lastUpdated];

  ActiveCodes copyWith({
    List<String>? gCodes,
    List<String>? mCodes,
    DateTime? lastUpdated,
  }) {
    return ActiveCodes(
      gCodes: gCodes ?? this.gCodes,
      mCodes: mCodes ?? this.mCodes,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Machine controller information and state
class MachineController extends Equatable {
  final String controllerId;
  final String? firmwareVersion;
  final String? hardwareVersion;
  final MachineStatus status;
  final MachineCoordinates? workPosition;
  final MachineCoordinates? machinePosition;
  final SpindleState? spindleState;
  final FeedState? feedState;
  final ActiveCodes? activeCodes;
  final List<String> alarms;
  final List<String> errors;
  final DateTime lastCommunication;
  final bool isOnline;

  const MachineController({
    required this.controllerId,
    this.firmwareVersion,
    this.hardwareVersion,
    this.status = MachineStatus.unknown,
    this.workPosition,
    this.machinePosition,
    this.spindleState,
    this.feedState,
    this.activeCodes,
    this.alarms = const [],
    this.errors = const [],
    required this.lastCommunication,
    this.isOnline = false,
  });

  @override
  List<Object?> get props => [
    controllerId,
    firmwareVersion,
    hardwareVersion,
    status,
    workPosition,
    machinePosition,
    spindleState,
    feedState,
    activeCodes,
    alarms,
    errors,
    lastCommunication,
    isOnline,
  ];

  MachineController copyWith({
    String? controllerId,
    String? firmwareVersion,
    String? hardwareVersion,
    MachineStatus? status,
    MachineCoordinates? workPosition,
    MachineCoordinates? machinePosition,
    SpindleState? spindleState,
    FeedState? feedState,
    ActiveCodes? activeCodes,
    List<String>? alarms,
    List<String>? errors,
    DateTime? lastCommunication,
    bool? isOnline,
  }) {
    return MachineController(
      controllerId: controllerId ?? this.controllerId,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      hardwareVersion: hardwareVersion ?? this.hardwareVersion,
      status: status ?? this.status,
      workPosition: workPosition ?? this.workPosition,
      machinePosition: machinePosition ?? this.machinePosition,
      spindleState: spindleState ?? this.spindleState,
      feedState: feedState ?? this.feedState,
      activeCodes: activeCodes ?? this.activeCodes,
      alarms: alarms ?? this.alarms,
      errors: errors ?? this.errors,
      lastCommunication: lastCommunication ?? this.lastCommunication,
      isOnline: isOnline ?? this.isOnline,
    );
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

