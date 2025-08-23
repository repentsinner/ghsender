import 'dart:async';
import 'jog_input_driver.dart';

/// Jog input driver for Flutter's on-screen joystick widget
/// Converts 2D joystick UI events to standardized JogInputEvent format
class FlutterJoystickDriver extends BaseJogInputDriver {
  static const String _deviceType = 'flutter_joystick';
  static int _instanceCounter = 0;

  FlutterJoystickDriver({String? instanceId}) 
      : super(
          deviceId: '$_deviceType${instanceId ?? '_${++_instanceCounter}'}',
          displayName: 'On-Screen Joystick',
          capabilities: JogInputCapabilities.xy2D,
        );

  @override
  bool get isActive => true; // Always active for UI joystick

  @override
  Future<void> onInitialize() async {
    // UI joystick doesn't need hardware initialization
  }

  @override
  Future<void> onDispose() async {
    // UI joystick doesn't need hardware cleanup
  }

  /// Called by UI joystick widget when user input changes
  /// This is the bridge between the UI widget and the driver system
  void onJoystickInput(double x, double y) {
    if (isEnabled) {
      emitInput2D(x, y);
    }
  }

  /// Stop input (called when joystick is released or disabled)
  void stopInput() {
    emitInput2D(0.0, 0.0);
  }
}

/// Factory for creating Flutter joystick drivers
class FlutterJoystickDriverFactory {
  static FlutterJoystickDriver createDriver({String? instanceId}) {
    return FlutterJoystickDriver(instanceId: instanceId);
  }

  /// Create multiple drivers for different joystick widgets (e.g., multiple tabs)
  static List<FlutterJoystickDriver> createMultipleDrivers(int count) {
    return List.generate(
      count, 
      (index) => FlutterJoystickDriver(instanceId: '_multi_$index'),
    );
  }
}