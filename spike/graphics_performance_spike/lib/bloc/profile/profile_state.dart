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

/// States for the Profile BLoC
abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

/// Initial state - no profile loaded
class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

/// Profile loading from storage
class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

/// No profiles exist - user needs to create at least one
class ProfileEmpty extends ProfileState {
  const ProfileEmpty();
}

/// Profile loaded and ready
class ProfileLoaded extends ProfileState {
  final MachineProfile currentProfile;
  final List<MachineProfile> availableProfiles;

  const ProfileLoaded({
    required this.currentProfile,
    required this.availableProfiles,
  });

  @override
  List<Object> get props => [currentProfile, availableProfiles];
}

/// Profile operation in progress (save/load/create/delete)
class ProfileOperationInProgress extends ProfileState {
  final String operation;
  final MachineProfile currentProfile;
  final List<MachineProfile> availableProfiles;

  const ProfileOperationInProgress({
    required this.operation,
    required this.currentProfile,
    required this.availableProfiles,
  });

  @override
  List<Object> get props => [operation, currentProfile, availableProfiles];
}

/// Profile operation completed successfully
class ProfileOperationSuccess extends ProfileState {
  final String message;
  final MachineProfile currentProfile;
  final List<MachineProfile> availableProfiles;

  const ProfileOperationSuccess({
    required this.message,
    required this.currentProfile,
    required this.availableProfiles,
  });

  @override
  List<Object> get props => [message, currentProfile, availableProfiles];
}

/// Profile error state
class ProfileError extends ProfileState {
  final String errorMessage;
  final MachineProfile? currentProfile;
  final List<MachineProfile>? availableProfiles;

  const ProfileError({
    required this.errorMessage,
    this.currentProfile,
    this.availableProfiles,
  });

  @override
  List<Object?> get props => [errorMessage, currentProfile, availableProfiles];
}