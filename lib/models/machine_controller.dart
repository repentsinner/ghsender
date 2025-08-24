import 'package:equatable/equatable.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'machine_configuration.dart';
import 'bounding_box.dart';
import '../utils/logger.dart';
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

/// Work envelope representing machine soft limits and travel boundaries
/// 
/// Based on grblHAL's limits_set_work_envelope() logic:
/// - Represents the safe operating boundaries within the machine's physical limits
/// - Calculated as: hard limits minus homing pulloff distance  
/// - This is the boundary that MACHINE POSITION (MPos) should stay within
/// - Different from work position (WPos) which is workpiece coordinates
/// 
/// Usage in soft limits checking:
/// - Check: Machine Position + Jog Vector vs Work Envelope
/// - NOT: Work Position vs Work Envelope (that's for different use cases)
///
/// Example: If machine can travel X=-285 to X=0, the work envelope might be
/// X=-284 to X=-1 after applying pulloff distance safety buffer.
class WorkEnvelope extends Equatable {
  /// The geometric bounding box representing machine soft limits
  final BoundingBox bounds;
  
  /// When this envelope was last updated (for state change detection)
  final DateTime lastUpdated;
  
  // Note: Removed 'units' field as per BOUNDING_BOX.md - always mm internally

  const WorkEnvelope({
    required this.bounds,
    required this.lastUpdated,
  });
  
  /// Legacy constructor for backward compatibility during migration
  /// Creates WorkEnvelope from individual minBounds/maxBounds
  factory WorkEnvelope.fromBounds({
    required vm.Vector3 minBounds,
    required vm.Vector3 maxBounds,
    String? units, // Ignored - always mm internally
    required DateTime lastUpdated,
  }) {
    return WorkEnvelope(
      bounds: BoundingBox(
        minBounds: minBounds,
        maxBounds: maxBounds,
      ),
      lastUpdated: lastUpdated,
    );
  }

  /// Legacy getters for backward compatibility
  vm.Vector3 get minBounds => bounds.minBounds;
  vm.Vector3 get maxBounds => bounds.maxBounds;
  String get units => 'mm'; // Always mm internally

  @override
  List<Object?> get props => [bounds, lastUpdated];

  /// Calculate work envelope from grblHAL machine configuration
  /// Based on grblHAL's limits_set_work_envelope() logic
  /// 
  /// Creates the soft limits boundary by taking machine travel limits and applying
  /// safety margins. This boundary should be checked against MACHINE POSITION (MPos),
  /// not work position (WPos).
  static WorkEnvelope? fromConfiguration(MachineConfiguration config) {
    // Require all three axis travel limits to be available
    final xTravel = config.xMaxTravel;
    final yTravel = config.yMaxTravel;
    final zTravel = config.zMaxTravel;
    
    if (xTravel == null || yTravel == null || zTravel == null) {
      final missing = <String>[];
      if (xTravel == null) missing.add('xMaxTravel');
      if (yTravel == null) missing.add('yMaxTravel');
      if (zTravel == null) missing.add('zMaxTravel');
      AppLogger.jogInfo('WorkEnvelope creation FAILED: missing ${missing.join(', ')} from machine configuration');
      return null;
    }

    // grblHAL stores max_travel as negative values internally
    // The actual travel distance is the absolute value
    final xMax = xTravel.abs();
    final yMax = yTravel.abs();
    final zMax = zTravel.abs();

    // For grblHAL with default settings (force_set_origin typically true):
    // - Home position becomes origin (0,0,0)
    // - Work envelope extends in negative direction from home
    // This follows the standard CNC convention where home is at max positive position
    final minBounds = vm.Vector3(-xMax, -yMax, -zMax);
    final maxBounds = vm.Vector3(0.0, 0.0, 0.0);

    // Only log WorkEnvelope creation once when it first succeeds, not on every call

    return WorkEnvelope.fromBounds(
      minBounds: minBounds,
      maxBounds: maxBounds,
      units: config.reportInches == true ? 'inch' : 'mm',
      lastUpdated: config.lastUpdated,
    );
  }

  /// Get work envelope dimensions  
  vm.Vector3 get dimensions => bounds.size;

  /// Get work envelope center point
  vm.Vector3 get center => bounds.center;

  WorkEnvelope copyWith({
    BoundingBox? bounds,
    vm.Vector3? minBounds,
    vm.Vector3? maxBounds,
    String? units, // Ignored - always mm internally
    DateTime? lastUpdated,
  }) {
    // If new bounds provided directly, use them
    if (bounds != null) {
      return WorkEnvelope(
        bounds: bounds,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
    }
    
    // Legacy support: if minBounds/maxBounds provided, create BoundingBox
    if (minBounds != null || maxBounds != null) {
      return WorkEnvelope.fromBounds(
        minBounds: minBounds ?? this.minBounds,
        maxBounds: maxBounds ?? this.maxBounds,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
    }
    
    // No bounds changes, just update lastUpdated if provided
    return WorkEnvelope(
      bounds: this.bounds,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() => 'WorkEnvelope($minBounds to $maxBounds $units)';
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

