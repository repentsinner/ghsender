import 'package:equatable/equatable.dart';

/// Jog mode enumeration
enum JogMode {
  discrete,    // Fixed distance jogging
  continuous,  // Hold-down jogging
  joystick,    // Free movement with joystick
}

/// Jog settings configuration
class JogSettings extends Equatable {
  final double selectedDistance;
  final int selectedFeedRate;
  final JogMode mode;
  
  const JogSettings({
    required this.selectedDistance,
    required this.selectedFeedRate,
    required this.mode,
  });

  @override
  List<Object?> get props => [selectedDistance, selectedFeedRate, mode];

  JogSettings copyWith({
    double? selectedDistance,
    int? selectedFeedRate,
    JogMode? mode,
  }) {
    return JogSettings(
      selectedDistance: selectedDistance ?? this.selectedDistance,
      selectedFeedRate: selectedFeedRate ?? this.selectedFeedRate,
      mode: mode ?? this.mode,
    );
  }
}

/// Current joystick input state
class JoystickState extends Equatable {
  final double x;
  final double y;
  final double magnitude;
  final bool isActive;
  final DateTime? lastInputTime;
  final DateTime? lastCommandTime;

  const JoystickState({
    required this.x,
    required this.y,
    required this.magnitude,
    required this.isActive,
    this.lastInputTime,
    this.lastCommandTime,
  });

  @override
  List<Object?> get props => [x, y, magnitude, isActive, lastInputTime, lastCommandTime];

  JoystickState copyWith({
    double? x,
    double? y,
    double? magnitude,
    bool? isActive,
    DateTime? lastInputTime,
    DateTime? lastCommandTime,
  }) {
    return JoystickState(
      x: x ?? this.x,
      y: y ?? this.y,
      magnitude: magnitude ?? this.magnitude,
      isActive: isActive ?? this.isActive,
      lastInputTime: lastInputTime ?? this.lastInputTime,
      lastCommandTime: lastCommandTime ?? this.lastCommandTime,
    );
  }

  /// Create inactive joystick state
  static const JoystickState inactive = JoystickState(
    x: 0.0,
    y: 0.0,
    magnitude: 0.0,
    isActive: false,
  );
}

/// Probe configuration
class ProbeSettings extends Equatable {
  final double distance;
  final double feedRate;

  const ProbeSettings({
    required this.distance,
    required this.feedRate,
  });

  @override
  List<Object?> get props => [distance, feedRate];

  ProbeSettings copyWith({
    double? distance,
    double? feedRate,
  }) {
    return ProbeSettings(
      distance: distance ?? this.distance,
      feedRate: feedRate ?? this.feedRate,
    );
  }
}

/// Complete jog controller state
class JogControllerState extends Equatable {
  final JogSettings settings;
  final JoystickState joystickState;
  final ProbeSettings probeSettings;
  final bool isInitialized;

  const JogControllerState({
    required this.settings,
    required this.joystickState,
    required this.probeSettings,
    required this.isInitialized,
  });

  @override
  List<Object?> get props => [settings, joystickState, probeSettings, isInitialized];

  JogControllerState copyWith({
    JogSettings? settings,
    JoystickState? joystickState,
    ProbeSettings? probeSettings,
    bool? isInitialized,
  }) {
    return JogControllerState(
      settings: settings ?? this.settings,
      joystickState: joystickState ?? this.joystickState,
      probeSettings: probeSettings ?? this.probeSettings,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  /// Initial state with defaults
  static const JogControllerState initial = JogControllerState(
    settings: JogSettings(
      selectedDistance: 1.0,
      selectedFeedRate: 500,
      mode: JogMode.discrete,
    ),
    joystickState: JoystickState.inactive,
    probeSettings: ProbeSettings(
      distance: 10.0,
      feedRate: 100.0,
    ),
    isInitialized: false,
  );
}