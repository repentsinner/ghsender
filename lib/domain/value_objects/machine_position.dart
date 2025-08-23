import 'package:equatable/equatable.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Coordinate system types used in CNC operations
enum CoordinateSystem {
  g54,
  g55,
  g56,
  g57,
  g58,
  g59,
  machine, // Machine coordinate system (MPos)
}

/// Immutable position representation supporting multiple coordinate systems
/// 
/// This value object handles the distinction between machine coordinates (MPos)
/// and work coordinates (WPos) that is critical for proper CNC operation.
class MachinePosition extends Equatable {
  final vm.Vector3 workCoordinates;
  final vm.Vector3 machineCoordinates;
  final CoordinateSystem activeSystem;

  const MachinePosition(
    this.workCoordinates, {
    required this.machineCoordinates,
    this.activeSystem = CoordinateSystem.g54,
  });

  /// Create from a single Vector3 position (simplified constructor)
  /// 
  /// Used when work and machine coordinates are the same or when only
  /// one coordinate system is relevant for the operation.
  const MachinePosition.fromVector3(vm.Vector3 position) 
    : workCoordinates = position,
      machineCoordinates = position,
      activeSystem = CoordinateSystem.g54;

  /// Create from existing MachineCoordinates model
  /// 
  /// Bridges the gap between existing coordinate models and new domain entities
  /// during the migration process.
  factory MachinePosition.fromMachineCoordinates(dynamic machineCoords) {
    final position = vm.Vector3(
      machineCoords.x,
      machineCoords.y,
      machineCoords.z,
    );
    return MachinePosition.fromVector3(position);
  }

  /// Get the position vector for the specified coordinate system
  vm.Vector3 getPosition(CoordinateSystem system) {
    switch (system) {
      case CoordinateSystem.machine:
        return machineCoordinates;
      default:
        return workCoordinates;
    }
  }

  /// Create a new position with updated coordinates
  MachinePosition copyWith({
    vm.Vector3? workCoordinates,
    vm.Vector3? machineCoordinates,
    CoordinateSystem? activeSystem,
  }) {
    return MachinePosition(
      workCoordinates ?? this.workCoordinates,
      machineCoordinates: machineCoordinates ?? this.machineCoordinates,
      activeSystem: activeSystem ?? this.activeSystem,
    );
  }

  @override
  List<Object?> get props => [workCoordinates, machineCoordinates, activeSystem];

  @override
  String toString() => 'MachinePosition(work: $workCoordinates, machine: $machineCoordinates, system: $activeSystem)';
}