import 'package:equatable/equatable.dart';

/// Events for the SettingsBloc that manages UI metadata from grblHAL
abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize the settings bloc
class SettingsInitialized extends SettingsEvent {
  const SettingsInitialized();
}

/// Set reference to communication bloc for sending commands
class SettingsSetCommunicationBloc extends SettingsEvent {
  final dynamic communicationBloc;

  const SettingsSetCommunicationBloc(this.communicationBloc);

  @override
  List<Object?> get props => [communicationBloc];
}

/// Request extended settings metadata from grblHAL ($ES command)
class SettingsRequestMetadata extends SettingsEvent {
  const SettingsRequestMetadata();
}

/// Request setting groups from grblHAL ($EG command)
class SettingsRequestGroups extends SettingsEvent {
  const SettingsRequestGroups();
}

/// Extended settings metadata received from $ES command
class SettingsMetadataReceived extends SettingsEvent {
  final List<String> messages;
  final DateTime timestamp;

  const SettingsMetadataReceived({
    required this.messages,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [messages, timestamp];
}

/// Setting groups received from $EG command
class SettingsGroupsReceived extends SettingsEvent {
  final List<String> messages;
  final DateTime timestamp;

  const SettingsGroupsReceived({
    required this.messages,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [messages, timestamp];
}

/// Clear all settings metadata (on disconnect)
class SettingsClearMetadata extends SettingsEvent {
  const SettingsClearMetadata();
}

/// Reset settings bloc to initial state
class SettingsReset extends SettingsEvent {
  const SettingsReset();
}