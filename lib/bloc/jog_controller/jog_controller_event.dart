import 'package:equatable/equatable.dart';
import 'jog_controller_state.dart';
import '../../services/jog_input_driver.dart';

/// Events for the Jog Controller BLoC
abstract class JogControllerEvent extends Equatable {
  const JogControllerEvent();
  
  @override
  List<Object?> get props => [];
}

/// Initialize the jog controller
class JogControllerInitialized extends JogControllerEvent {
  const JogControllerInitialized();
}

/// Update jog settings (distance, feed rate, mode)
class JogSettingsUpdated extends JogControllerEvent {
  final double? selectedDistance;
  final int? selectedFeedRate;
  final JogMode? mode;

  const JogSettingsUpdated({
    this.selectedDistance,
    this.selectedFeedRate,
    this.mode,
  });

  @override
  List<Object?> get props => [selectedDistance, selectedFeedRate, mode];
}

/// Proportional jog input received from any input driver
class ProportionalJogInputReceived extends JogControllerEvent {
  final JogInputEvent inputEvent;

  const ProportionalJogInputReceived({
    required this.inputEvent,
  });

  @override
  List<Object?> get props => [inputEvent];
}

/// Legacy joystick input event (for backward compatibility during transition)
class JoystickInputReceived extends JogControllerEvent {
  final double x;
  final double y;
  final double? z; // Optional Z-axis for 3D joystick support

  const JoystickInputReceived({
    required this.x,
    required this.y,
    this.z,
  });

  @override
  List<Object?> get props => [x, y, z];
}

/// Discrete jog requested (button press)
class DiscreteJogRequested extends JogControllerEvent {
  final String axis; // 'X', 'Y', 'Z'
  final double distance;

  const DiscreteJogRequested({
    required this.axis,
    required this.distance,
  });

  @override
  List<Object?> get props => [axis, distance];
}

/// Stop any ongoing jog movement
class JogStopRequested extends JogControllerEvent {
  const JogStopRequested();
}

/// Set work zero coordinates
class WorkZeroRequested extends JogControllerEvent {
  final String axes; // 'X', 'Y', 'Z', or 'XYZ'

  const WorkZeroRequested({
    required this.axes,
  });

  @override
  List<Object?> get props => [axes];
}

/// Probe work surface
class ProbeRequested extends JogControllerEvent {
  const ProbeRequested();
}

/// Update probe settings
class ProbeSettingsUpdated extends JogControllerEvent {
  final double? distance;
  final double feedRate;

  const ProbeSettingsUpdated({
    this.distance,
    required this.feedRate,
  });

  @override
  List<Object?> get props => [distance, feedRate];
}

/// Home machine request
class HomingRequested extends JogControllerEvent {
  const HomingRequested();
}