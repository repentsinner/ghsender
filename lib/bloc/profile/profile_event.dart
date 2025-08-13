import 'package:equatable/equatable.dart';

/// Events for the Profile BLoC
abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

/// Load profile data from storage/defaults
class ProfileLoadRequested extends ProfileEvent {
  const ProfileLoadRequested();
}

/// Update profile name
class ProfileNameChanged extends ProfileEvent {
  final String name;

  const ProfileNameChanged(this.name);

  @override
  List<Object> get props => [name];
}

/// Update controller/WebSocket address
class ProfileControllerAddressChanged extends ProfileEvent {
  final String address;

  const ProfileControllerAddressChanged(this.address);

  @override
  List<Object> get props => [address];
}


/// Switch to a different profile
class ProfileSwitched extends ProfileEvent {
  final String profileId;

  const ProfileSwitched(this.profileId);

  @override
  List<Object> get props => [profileId];
}

/// Create a new profile
class ProfileCreated extends ProfileEvent {
  final String name;
  final String controllerAddress;

  const ProfileCreated(this.name, this.controllerAddress);

  @override
  List<Object> get props => [name, controllerAddress];
}

/// Copy current profile with new name
class ProfileCopied extends ProfileEvent {
  final String newName;

  const ProfileCopied(this.newName);

  @override
  List<Object> get props => [newName];
}

/// Delete a profile
class ProfileDeleted extends ProfileEvent {
  final String profileId;

  const ProfileDeleted(this.profileId);

  @override
  List<Object> get props => [profileId];
}

/// Export profile to file
class ProfileExportRequested extends ProfileEvent {
  final String profileName;

  const ProfileExportRequested(this.profileName);

  @override
  List<Object> get props => [profileName];
}

/// Import profile from file
class ProfileImportRequested extends ProfileEvent {
  final String filePath;

  const ProfileImportRequested(this.filePath);

  @override
  List<Object> get props => [filePath];
}