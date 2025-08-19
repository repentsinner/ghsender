import 'package:equatable/equatable.dart';

/// Events for AlarmError BLoC
abstract class AlarmErrorEvent extends Equatable {
  const AlarmErrorEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize the alarm/error bloc
class AlarmErrorInitialized extends AlarmErrorEvent {
  const AlarmErrorInitialized();
}

/// Set communication bloc reference for sending commands
class AlarmErrorSetCommunicationBloc extends AlarmErrorEvent {
  final dynamic communicationBloc;

  const AlarmErrorSetCommunicationBloc(this.communicationBloc);

  @override
  List<Object?> get props => [communicationBloc];
}

/// Request alarm metadata from grblHAL ($EA command)
class AlarmErrorRequestAlarmMetadata extends AlarmErrorEvent {
  const AlarmErrorRequestAlarmMetadata();
}

/// Request alarm groups from grblHAL ($EAG command)
class AlarmErrorRequestAlarmGroups extends AlarmErrorEvent {
  const AlarmErrorRequestAlarmGroups();
}

/// Request error metadata from grblHAL ($EE command)
class AlarmErrorRequestErrorMetadata extends AlarmErrorEvent {
  const AlarmErrorRequestErrorMetadata();
}

/// Request error groups from grblHAL ($EEG command)
class AlarmErrorRequestErrorGroups extends AlarmErrorEvent {
  const AlarmErrorRequestErrorGroups();
}

/// Alarm metadata received from $EA command
class AlarmErrorAlarmMetadataReceived extends AlarmErrorEvent {
  final List<String> messages;
  final DateTime timestamp;

  const AlarmErrorAlarmMetadataReceived({
    required this.messages,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [messages, timestamp];
}

/// Error metadata received from $EE command
class AlarmErrorErrorMetadataReceived extends AlarmErrorEvent {
  final List<String> messages;
  final DateTime timestamp;

  const AlarmErrorErrorMetadataReceived({
    required this.messages,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [messages, timestamp];
}

/// Alarm groups received from $EAG command
class AlarmErrorAlarmGroupsReceived extends AlarmErrorEvent {
  final List<String> messages;
  final DateTime timestamp;

  const AlarmErrorAlarmGroupsReceived({
    required this.messages,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [messages, timestamp];
}

/// Error groups received from $EEG command
class AlarmErrorErrorGroupsReceived extends AlarmErrorEvent {
  final List<String> messages;
  final DateTime timestamp;

  const AlarmErrorErrorGroupsReceived({
    required this.messages,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [messages, timestamp];
}

/// Clear all metadata (on disconnect)
class AlarmErrorClearMetadata extends AlarmErrorEvent {
  const AlarmErrorClearMetadata();
}

/// Reset to initial state
class AlarmErrorReset extends AlarmErrorEvent {
  const AlarmErrorReset();
}