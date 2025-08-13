import 'package:equatable/equatable.dart';
import '../../models/machine_controller.dart';
import '../communication/cnc_communication_state.dart';

/// Events for the Machine Controller BLoC
abstract class MachineControllerEvent extends Equatable {
  const MachineControllerEvent();
  
  @override
  List<Object?> get props => [];
}

/// Initialize the machine controller
class MachineControllerInitialized extends MachineControllerEvent {
  const MachineControllerInitialized();
}

/// Process incoming CNC communication data
class MachineControllerCommunicationReceived extends MachineControllerEvent {
  final CncCommunicationState communicationState;
  
  const MachineControllerCommunicationReceived(this.communicationState);
  
  @override
  List<Object?> get props => [communicationState];
}

/// Update machine status from parsed response
class MachineControllerStatusUpdated extends MachineControllerEvent {
  final MachineStatus status;
  final DateTime timestamp;
  
  const MachineControllerStatusUpdated({
    required this.status,
    required this.timestamp,
  });
  
  @override
  List<Object?> get props => [status, timestamp];
}

/// Update machine coordinates
class MachineControllerCoordinatesUpdated extends MachineControllerEvent {
  final MachineCoordinates? workPosition;
  final MachineCoordinates? machinePosition;
  final DateTime timestamp;
  
  const MachineControllerCoordinatesUpdated({
    this.workPosition,
    this.machinePosition,
    required this.timestamp,
  });
  
  @override
  List<Object?> get props => [workPosition, machinePosition, timestamp];
}

/// Update spindle state
class MachineControllerSpindleUpdated extends MachineControllerEvent {
  final SpindleState spindleState;
  final DateTime timestamp;
  
  const MachineControllerSpindleUpdated({
    required this.spindleState,
    required this.timestamp,
  });
  
  @override
  List<Object?> get props => [spindleState, timestamp];
}

/// Update feed rate
class MachineControllerFeedUpdated extends MachineControllerEvent {
  final FeedState feedState;
  final DateTime timestamp;
  
  const MachineControllerFeedUpdated({
    required this.feedState,
    required this.timestamp,
  });
  
  @override
  List<Object?> get props => [feedState, timestamp];
}

/// Update active G/M codes
class MachineControllerCodesUpdated extends MachineControllerEvent {
  final ActiveCodes activeCodes;
  final DateTime timestamp;
  
  const MachineControllerCodesUpdated({
    required this.activeCodes,
    required this.timestamp,
  });
  
  @override
  List<Object?> get props => [activeCodes, timestamp];
}

/// Add alarm to machine controller
class MachineControllerAlarmAdded extends MachineControllerEvent {
  final String alarm;
  final DateTime timestamp;
  
  const MachineControllerAlarmAdded({
    required this.alarm,
    required this.timestamp,
  });
  
  @override
  List<Object?> get props => [alarm, timestamp];
}

/// Clear alarms from machine controller
class MachineControllerAlarmsCleared extends MachineControllerEvent {
  const MachineControllerAlarmsCleared();
}

/// Add error to machine controller
class MachineControllerErrorAdded extends MachineControllerEvent {
  final String error;
  final DateTime timestamp;
  
  const MachineControllerErrorAdded({
    required this.error,
    required this.timestamp,
  });
  
  @override
  List<Object?> get props => [error, timestamp];
}

/// Clear errors from machine controller
class MachineControllerErrorsCleared extends MachineControllerEvent {
  const MachineControllerErrorsCleared();
}

/// Update controller firmware/hardware info
class MachineControllerInfoUpdated extends MachineControllerEvent {
  final String? firmwareVersion;
  final String? hardwareVersion;
  
  const MachineControllerInfoUpdated({
    this.firmwareVersion,
    this.hardwareVersion,
  });
  
  @override
  List<Object?> get props => [firmwareVersion, hardwareVersion];
}

/// Set machine online/offline status
class MachineControllerConnectionChanged extends MachineControllerEvent {
  final bool isOnline;
  final DateTime timestamp;
  
  const MachineControllerConnectionChanged({
    required this.isOnline,
    required this.timestamp,
  });
  
  @override
  List<Object?> get props => [isOnline, timestamp];
}

/// Reset machine controller state
class MachineControllerReset extends MachineControllerEvent {
  const MachineControllerReset();
}

// Performance Tracking Events (moved from CommunicationBloc)

/// Command sent to machine for latency tracking
class MachineControllerCommandSent extends MachineControllerEvent {
  final String command;
  final int commandId;
  final DateTime sentTime;
  
  const MachineControllerCommandSent({
    required this.command,
    required this.commandId,
    required this.sentTime,
  });
  
  @override
  List<Object?> get props => [command, commandId, sentTime];
}

/// Response received from machine for latency calculation
class MachineControllerResponseReceived extends MachineControllerEvent {
  final String response;
  final int? commandId;
  final DateTime receivedTime;
  
  const MachineControllerResponseReceived({
    required this.response,
    this.commandId,
    required this.receivedTime,
  });
  
  @override
  List<Object?> get props => [response, commandId, receivedTime];
}

// Jog Testing Events (moved from CommunicationBloc)

/// Start automated jog testing for performance validation
class MachineControllerStartJogTest extends MachineControllerEvent {
  final int durationSeconds;
  final double jogDistance;
  final int feedRate;
  
  const MachineControllerStartJogTest({
    required this.durationSeconds,
    required this.jogDistance,
    required this.feedRate,
  });
  
  @override
  List<Object?> get props => [durationSeconds, jogDistance, feedRate];
}

/// Stop automated jog testing
class MachineControllerStopJogTest extends MachineControllerEvent {
  const MachineControllerStopJogTest();
}

/// Execute next jog movement in test sequence
class MachineControllerExecuteJog extends MachineControllerEvent {
  final String jogCommand;
  final int jogNumber;
  final DateTime executionTime;
  
  const MachineControllerExecuteJog({
    required this.jogCommand,
    required this.jogNumber,
    required this.executionTime,
  });
  
  @override
  List<Object?> get props => [jogCommand, jogNumber, executionTime];
}

// grblHAL Detection and Configuration Events

/// grblHAL welcome message detected, trigger configuration
class MachineControllerGrblHalDetected extends MachineControllerEvent {
  final String welcomeMessage;
  final String firmwareVersion;
  final DateTime timestamp;
  
  const MachineControllerGrblHalDetected({
    required this.welcomeMessage,
    required this.firmwareVersion,
    required this.timestamp,
  });
  
  @override
  List<Object?> get props => [welcomeMessage, firmwareVersion, timestamp];
}

/// Set communication bloc reference for command sending
class MachineControllerSetCommunicationBloc extends MachineControllerEvent {
  final dynamic communicationBloc;
  
  const MachineControllerSetCommunicationBloc(this.communicationBloc);
  
  @override
  List<Object?> get props => [communicationBloc];
}

/// Auto reporting configuration completed successfully
class MachineControllerAutoReportingConfigured extends MachineControllerEvent {
  final bool enabled;
  final DateTime timestamp;
  
  const MachineControllerAutoReportingConfigured({
    required this.enabled,
    required this.timestamp,
  });
  
  @override
  List<Object?> get props => [enabled, timestamp];
}