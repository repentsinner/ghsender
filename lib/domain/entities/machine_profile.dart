import 'package:equatable/equatable.dart';

/// Machine profile configuration data - UUID-based with name and controller address
class MachineProfile extends Equatable {
  final String id;  // UUID for stable identity
  final String name;
  final String controllerAddress;

  const MachineProfile({
    required this.id,
    required this.name,
    required this.controllerAddress,
  });


  /// Copy profile with modifications
  MachineProfile copyWith({
    String? id,
    String? name,
    String? controllerAddress,
  }) {
    return MachineProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      controllerAddress: controllerAddress ?? this.controllerAddress,
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'controllerAddress': controllerAddress,
    };
  }

  /// Create from JSON for persistence
  factory MachineProfile.fromJson(Map<String, dynamic> json) {
    return MachineProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      controllerAddress: json['controllerAddress'] as String,
    );
  }

  @override
  List<Object> get props => [id, name, controllerAddress];
}