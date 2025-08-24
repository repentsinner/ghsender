import 'package:equatable/equatable.dart';
import '../domain/value_objects/machine_coordinates.dart';
import '../domain/enums/machine_status.dart';
import '../domain/value_objects/spindle_state.dart';
import '../domain/value_objects/feed_state.dart';
import '../domain/value_objects/active_codes.dart';

// MachineCoordinates has been moved to lib/domain/value_objects/machine_coordinates.dart
// MachineStatus has been moved to lib/domain/enums/machine_status.dart
// SpindleState has been moved to lib/domain/value_objects/spindle_state.dart
// FeedState has been moved to lib/domain/value_objects/feed_state.dart
// ActiveCodes has been moved to lib/domain/value_objects/active_codes.dart

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
  /// (Delegates to MachineStatusExtension.parseStatus)
  static MachineStatus parseStatus(String statusString) {
    return MachineStatusExtension.parseStatus(statusString);
  }
}

