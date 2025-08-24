import 'package:equatable/equatable.dart';
import '../../domain/enums/machine_status.dart';
import '../../domain/entities/machine_configuration.dart';
import '../communication/cnc_communication_state.dart';
import '../communication/cnc_communication_event.dart';
import '../../domain/value_objects/machine_coordinates.dart';
import '../../domain/value_objects/spindle_state.dart';
import '../../domain/value_objects/feed_state.dart';
import '../../domain/value_objects/active_codes.dart';

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

/// Add alarm condition with code for enhanced metadata lookup
class MachineControllerAlarmConditionAdded extends MachineControllerEvent {
  final int alarmCode;
  final String rawMessage;
  final DateTime timestamp;
  
  const MachineControllerAlarmConditionAdded({
    required this.alarmCode,
    required this.rawMessage,
    required this.timestamp,
  });
  
  @override
  List<Object?> get props => [alarmCode, rawMessage, timestamp];
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

/// Add error condition with code for enhanced metadata lookup
class MachineControllerErrorConditionAdded extends MachineControllerEvent {
  final int errorCode;
  final String rawMessage;
  final DateTime timestamp;
  
  const MachineControllerErrorConditionAdded({
    required this.errorCode,
    required this.rawMessage,
    required this.timestamp,
  });
  
  @override
  List<Object?> get props => [errorCode, rawMessage, timestamp];
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

/// Set alarm/error bloc reference for metadata lookup
class MachineControllerSetAlarmErrorBloc extends MachineControllerEvent {
  final dynamic alarmErrorBloc;
  
  const MachineControllerSetAlarmErrorBloc(this.alarmErrorBloc);
  
  @override
  List<Object?> get props => [alarmErrorBloc];
}

/// Set problems bloc reference for creating problem entries
class MachineControllerSetProblemsBloc extends MachineControllerEvent {
  final dynamic problemsBloc;
  
  const MachineControllerSetProblemsBloc(this.problemsBloc);
  
  @override
  List<Object?> get props => [problemsBloc];
}

/// Firmware welcome message received
class MachineControllerFirmwareWelcomeReceived extends MachineControllerEvent {
  final DateTime timestamp;
  
  const MachineControllerFirmwareWelcomeReceived({
    required this.timestamp,
  });
  
  @override
  List<Object?> get props => [timestamp];
}



// Jog Control Events

/// Request to jog the machine in a specific direction
class MachineControllerJogRequested extends MachineControllerEvent {
  final String axis; // 'X', 'Y', 'Z'
  final double distance; // Distance to jog (positive or negative)
  final int feedRate; // Feed rate in mm/min or in/min
  
  const MachineControllerJogRequested({
    required this.axis,
    required this.distance,
    required this.feedRate,
  });
  
  @override
  List<Object?> get props => [axis, distance, feedRate];
}

/// Request to stop any ongoing jog movement
class MachineControllerJogStopRequested extends MachineControllerEvent {
  const MachineControllerJogStopRequested();
}

/// Continuous jog start (hold down)
class MachineControllerContinuousJogStarted extends MachineControllerEvent {
  final String axis; // 'X', 'Y', 'Z'
  final bool positive; // true for positive direction, false for negative
  final int feedRate; // Feed rate in mm/min or in/min
  
  const MachineControllerContinuousJogStarted({
    required this.axis,
    required this.positive,
    required this.feedRate,
  });
  
  @override
  List<Object?> get props => [axis, positive, feedRate];
}

/// Continuous jog stop (release button)
class MachineControllerContinuousJogStopped extends MachineControllerEvent {
  const MachineControllerContinuousJogStopped();
}

/// Multi-axis jog request for smooth diagonal movement
class MachineControllerMultiAxisJogRequested extends MachineControllerEvent {
  final double xDistance; // X axis distance in mm (can be 0)
  final double yDistance; // Y axis distance in mm (can be 0)
  final double? zDistance; // Optional Z axis distance in mm (can be 0)
  final int feedRate; // Feed rate for the combined movement in mm/min
  
  const MachineControllerMultiAxisJogRequested({
    required this.xDistance,
    required this.yDistance,
    this.zDistance,
    required this.feedRate,
  });
  
  @override
  List<Object?> get props => [xDistance, yDistance, zDistance, feedRate];
}

/// Machine configuration received and parsed from $ command response
class MachineControllerConfigurationReceived extends MachineControllerEvent {
  final MachineConfiguration configuration;
  final DateTime timestamp;
  
  const MachineControllerConfigurationReceived({
    required this.configuration,
    required this.timestamp,
  });
  
  @override
  List<Object?> get props => [configuration, timestamp];
}

/// Individual message received from CNC communication for event-based processing
class MachineControllerMessageReceived extends MachineControllerEvent {
  final String message;
  final DateTime timestamp;
  final CncMessageType messageType;
  
  const MachineControllerMessageReceived({
    required this.message,
    required this.timestamp, 
    required this.messageType,
  });
  
  @override
  List<Object?> get props => [message, timestamp, messageType];
}

/// Buffer status updated from status report
class MachineControllerBufferStatusUpdated extends MachineControllerEvent {
  final int plannerBlocksAvailable;
  final int rxBytesAvailable;
  final DateTime timestamp;
  
  const MachineControllerBufferStatusUpdated({
    required this.plannerBlocksAvailable,
    required this.rxBytesAvailable,
    required this.timestamp,
  });
  
  @override
  List<Object?> get props => [plannerBlocksAvailable, rxBytesAvailable, timestamp];
}

/// Plugins detected from $I command response
class MachineControllerPluginsDetected extends MachineControllerEvent {
  final List<String> plugins;
  final DateTime timestamp;
  
  const MachineControllerPluginsDetected({
    required this.plugins,
    required this.timestamp,
  });
  
  @override
  List<Object?> get props => [plugins, timestamp];
}