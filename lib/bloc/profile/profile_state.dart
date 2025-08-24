import 'package:equatable/equatable.dart';
import '../../domain/entities/machine_profile.dart';

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