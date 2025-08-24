import 'package:equatable/equatable.dart';

class MachineCoordinates extends Equatable {
  final double x;
  final double y;
  final double z;
  final String units; // "mm" or "inch"
  final DateTime lastUpdated;
  
  const MachineCoordinates({
    required this.x,
    required this.y,
    required this.z,
    this.units = 'mm',
    required this.lastUpdated,
  });
  
  @override
  List<Object?> get props => [x, y, z, units, lastUpdated];
  
  @override
  String toString() => '($x, $y, $z) $units';
  
  MachineCoordinates copyWith({
    double? x,
    double? y,
    double? z,
    String? units,
    DateTime? lastUpdated,
  }) {
    return MachineCoordinates(
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      units: units ?? this.units,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}