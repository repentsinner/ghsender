import 'package:equatable/equatable.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../enums/machine_status.dart';
import 'machine_configuration.dart';
import '../value_objects/machine_position.dart';
import '../value_objects/safety_envelope.dart';
import '../value_objects/validation_result.dart';

/// Unique identifier for a machine instance
class MachineId extends Equatable {
  final String value;

  const MachineId(this.value);

  @override
  List<Object?> get props => [value];

  @override
  String toString() => 'MachineId($value)';
}

/// Alarm information for the machine
class Alarm extends Equatable {
  final String message;
  final int code;

  const Alarm({
    required this.message,
    required this.code,
  });

  @override
  List<Object?> get props => [message, code];

  @override
  String toString() => 'Alarm($code: $message)';
}

/// Core domain entity representing a CNC machine
/// 
/// This entity encapsulates all business logic related to machine state validation
/// and operations. It maintains immutable state and provides methods for safe
/// state transitions and move validation.
class Machine extends Equatable {
  final MachineId id;
  final MachineConfiguration configuration;
  final MachinePosition currentPosition;
  final MachineStatus status;
  final SafetyEnvelope safetyEnvelope;
  final List<Alarm> activeAlarms;

  const Machine({
    required this.id,
    required this.configuration,
    required this.currentPosition,
    required this.status,
    required this.safetyEnvelope,
    this.activeAlarms = const [],
  });

  /// Validate if a move to the target position is safe and allowed
  /// 
  /// This is the core business logic method that encapsulates all move validation
  /// rules. It checks safety envelope, machine state, and alarm conditions.
  ValidationResult validateMove(vm.Vector3 targetPosition) {
    // Safety envelope check - primary boundary validation
    if (!safetyEnvelope.contains(targetPosition)) {
      return ValidationResult.failure(
        'Target position $targetPosition exceeds work envelope',
        ViolationType.workEnvelopeExceeded,
      );
    }
    
    // Machine state checks - cannot move in certain states
    if (status.hasError) {
      final alarmMessage = activeAlarms.isNotEmpty 
          ? activeAlarms.first.message 
          : 'Machine has error condition';
      return ValidationResult.failure(
        'Cannot move while machine is in alarm state: $alarmMessage',
        ViolationType.machineAlarmed,
      );
    }
    
    if (status.isActive && status != MachineStatus.jogging) {
      return ValidationResult.failure(
        'Cannot start new move while machine is already moving',
        ViolationType.machineMoving,
      );
    }
    
    return ValidationResult.success();
  }

  /// Execute a move to the target position
  /// 
  /// This method updates the machine state to reflect the new position and
  /// status. It validates the move first and throws an exception if invalid.
  Machine executeMove(vm.Vector3 targetPosition) {
    final validation = validateMove(targetPosition);
    if (!validation.isValid) {
      throw MachineOperationException(validation.error!, validation.violationType!);
    }
    
    return copyWith(
      currentPosition: MachinePosition.fromVector3(targetPosition),
      status: MachineStatus.jogging,
    );
  }

  /// Update the machine status
  Machine updateStatus(MachineStatus newStatus) {
    return copyWith(status: newStatus);
  }

  /// Add an alarm to the machine
  Machine addAlarm(Alarm alarm) {
    return copyWith(
      activeAlarms: [...activeAlarms, alarm],
      status: MachineStatus.alarm,
    );
  }

  /// Clear all active alarms
  Machine clearAlarms() {
    return copyWith(
      activeAlarms: [],
      status: MachineStatus.idle,
    );
  }

  /// Create a copy with updated fields
  Machine copyWith({
    MachineId? id,
    MachineConfiguration? configuration,
    MachinePosition? currentPosition,
    MachineStatus? status,
    SafetyEnvelope? safetyEnvelope,
    List<Alarm>? activeAlarms,
  }) {
    return Machine(
      id: id ?? this.id,
      configuration: configuration ?? this.configuration,
      currentPosition: currentPosition ?? this.currentPosition,
      status: status ?? this.status,
      safetyEnvelope: safetyEnvelope ?? this.safetyEnvelope,
      activeAlarms: activeAlarms ?? this.activeAlarms,
    );
  }

  @override
  List<Object?> get props => [
        id,
        configuration,
        currentPosition,
        status,
        safetyEnvelope,
        activeAlarms,
      ];

  @override
  String toString() => 'Machine(id: $id, status: $status, position: $currentPosition)';
}

/// Exception thrown when machine operations fail
class MachineOperationException implements Exception {
  final String message;
  final ViolationType violationType;

  const MachineOperationException(this.message, this.violationType);

  @override
  String toString() => 'MachineOperationException: $message ($violationType)';
}