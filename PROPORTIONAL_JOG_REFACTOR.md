# Proportional Jog Controller Refactor

## Overview
The jog controller has been refactored to separate generic proportional control logic from specific input device implementations. This enables support for multiple input devices (joysticks, gamepads, spacemouse, etc.) feeding into a unified jog control system.

## Architecture Changes

### Before (Tightly Coupled)
```
UI Joystick → JoystickProcessor → JogControllerBloc → Machine Commands
```

### After (Modular & Extensible)
```
Input Devices → InputDrivers → ProportionalJogController → JogControllerBloc → Machine Commands
     ↓              ↓                    ↓                       ↓
- Flutter UI   - Standardized      - Generic          - Orchestrates
- Gamepad      - JogInputEvent     - 6DOF Support     - Soft Limits  
- Spacemouse   - Device Caps       - Dead Zones       - Command Timing
- Hardware     - Enable/Disable    - Feed Scaling     - State Management
```

## Core Components

### 1. ProportionalJogController
**Location**: `lib/services/proportional_jog_controller.dart`

Generic proportional movement controller supporting up to 6DOF (X,Y,Z,A,B,C).

```dart
// 2D Input
final result = ProportionalJogController.process2D(
  rawX: 0.5, rawY: 0.8,
  selectedFeedRate: 1000,
  currentPosition: machinePos,
  workEnvelope: softLimits,
);

// 3D Input
final result = ProportionalJogController.process3D(
  rawX: 0.5, rawY: 0.8, rawZ: 0.3,
  selectedFeedRate: 1000,
  currentPosition: machinePos,
  workEnvelope: softLimits,
);

// Full 6DOF Input
final result = ProportionalJogController.process(ProportionalJogInput(
  x: 0.5, y: 0.8, z: 0.3,
  a: 0.1, b: 0.0, c: 0.2,  // Rotational axes
  selectedFeedRate: 1000,
  currentPosition: machinePos,
  workEnvelope: softLimits,
));
```

**Features**:
- Dead zone filtering (5% threshold)
- Magnitude clamping to 1.0
- 3D soft limits integration  
- Feed rate scaling based on magnitude
- Separate linear and rotational axis handling

### 2. JogInputDriver System
**Location**: `lib/services/jog_input_driver.dart`

Abstract interface for input devices with standardized event format.

```dart
// Define capabilities
const capabilities = JogInputCapabilities.xyz3D; // or .xy2D, .spacemouse6DOF

// Implement driver
class MyCustomDriver extends BaseJogInputDriver {
  MyCustomDriver() : super(
    deviceId: 'my_device',
    displayName: 'My Custom Controller',
    capabilities: capabilities,
  );

  @override
  Future<void> onInitialize() async {
    // Setup hardware, listeners, etc.
  }

  void onHardwareInput(double x, double y, double z) {
    if (isEnabled) {
      emitInput3D(x, y, z);  // Sends standardized JogInputEvent
    }
  }
}
```

**Features**:
- Standardized `JogInputEvent` format
- Device capabilities declaration (2D, 3D, 6DOF)
- Enable/disable per device
- Automatic cleanup and disposal

### 3. FlutterJoystickDriver  
**Location**: `lib/services/flutter_joystick_driver.dart`

Concrete implementation for Flutter's on-screen joystick widget.

```dart
// Create driver
final joystickDriver = FlutterJoystickDriver();
await jogBloc.addInputDriver(joystickDriver);

// Connect to UI widget (in your joystick widget)
void _onJoystickChanged(double x, double y) {
  joystickDriver.onJoystickInput(x, y);
}

void _onJoystickReleased() {
  joystickDriver.stopInput();
}
```

### 4. Updated JogControllerBloc
**Location**: `lib/bloc/jog_controller/jog_controller_bloc.dart`

Now supports multiple input drivers and unified proportional processing.

```dart
// Add input drivers
final flutterJoystick = FlutterJoystickDriver(instanceId: 'main_ui');
final gamepadDriver = GamepadDriver(); // Future implementation
final spacemouseDriver = SpacemouseDriver(); // Future implementation

await jogBloc.addInputDriver(flutterJoystick);
await jogBloc.addInputDriver(gamepadDriver);
await jogBloc.addInputDriver(spacemouseDriver);

// Enable/disable specific drivers
jogBloc.setInputDriverEnabled('main_ui', false); // Disable UI joystick
jogBloc.setInputDriverEnabled('gamepad_0', true); // Enable gamepad

// List active drivers
final drivers = jogBloc.inputDrivers;
```

**New Features**:
- Multiple concurrent input drivers
- Per-device enable/disable
- Unified `ProportionalJogInputReceived` event handling
- Automatic driver lifecycle management
- Legacy `JoystickInputReceived` support during transition

## Usage Examples

### Basic Setup (Flutter UI Joystick)
```dart
// In your app initialization
final jogBloc = JogControllerBloc(
  machineControllerBloc: machineBloc,
  communicationBloc: commBloc,
);

// Add Flutter joystick driver
final joystickDriver = FlutterJoystickDriver();
await jogBloc.addInputDriver(joystickDriver);

// In your joystick widget
class JoystickWidget extends StatelessWidget {
  final FlutterJoystickDriver driver;
  
  Widget build(BuildContext context) {
    return Joystick(
      listener: (details) {
        driver.onJoystickInput(details.x, details.y);
      },
      onStickDragEnd: () {
        driver.stopInput();
      },
    );
  }
}
```

### Multi-Device Setup (Future)
```dart
// Multiple input devices
final uiJoystick = FlutterJoystickDriver(instanceId: 'ui_main');
final gamepad = XboxGamepadDriver(); 
final spacemouse = SpacemouseDriver();

await jogBloc.addInputDriver(uiJoystick);
await jogBloc.addInputDriver(gamepad);
await jogBloc.addInputDriver(spacemouse);

// User preference: disable UI when hardware is connected
if (gamepad.isActive) {
  jogBloc.setInputDriverEnabled('ui_main', false);
}
```

### Custom Hardware Driver
```dart
class SpacemouseDriver extends BaseJogInputDriver {
  SpacemouseDriver() : super(
    deviceId: 'spacemouse_001',
    displayName: '3Dconnexion SpaceMouse',
    capabilities: JogInputCapabilities.spacemouse6DOF,
  );

  @override
  Future<void> onInitialize() async {
    // Initialize 3Dconnexion SDK
    await SpacemouseSDK.initialize();
    SpacemouseSDK.onMotion = _handleMotionEvent;
  }

  void _handleMotionEvent(SpaceMotion motion) {
    emitInput(
      x: motion.x / 1000.0,      // Normalize to [-1, 1]
      y: motion.y / 1000.0,
      z: motion.z / 1000.0,
      a: motion.pitch / 1000.0,  // Rotational axes
      b: motion.roll / 1000.0,
      c: motion.yaw / 1000.0,
    );
  }
}
```

## Migration Guide

### For UI Code
1. **Replace direct `JoystickInputReceived` events**:
   ```dart
   // Old
   jogBloc.add(JoystickInputReceived(x: x, y: y));
   
   // New (via driver)
   joystickDriver.onJoystickInput(x, y);
   ```

2. **Setup driver during initialization**:
   ```dart
   final joystickDriver = FlutterJoystickDriver();
   await jogBloc.addInputDriver(joystickDriver);
   ```

### For Testing
1. **Mock drivers for testing**:
   ```dart
   class MockJoystickDriver extends BaseJogInputDriver {
     MockJoystickDriver() : super(
       deviceId: 'test_driver',
       displayName: 'Test Driver', 
       capabilities: JogInputCapabilities.xy2D,
     );
     
     void simulateInput(double x, double y) {
       emitInput2D(x, y);
     }
   }
   ```

## Benefits

### 1. Extensibility
- Easy to add new input devices (gamepad, spacemouse, etc.)
- Each device can declare its capabilities (2D, 3D, 6DOF)
- No changes required to core jog control logic

### 2. Flexibility  
- Multiple input devices can be active simultaneously
- Per-device enable/disable for user preferences
- Unified processing regardless of input source

### 3. Maintainability
- Clear separation of concerns
- Generic proportional logic reusable across devices
- Device-specific code isolated in drivers

### 4. Testing
- Mock drivers for unit testing
- Test proportional logic independently of input devices  
- Better coverage of edge cases

## Future Enhancements

1. **Additional Drivers**:
   - Xbox/PlayStation gamepad support
   - 3Dconnexion SpaceMouse driver
   - MIDI controller driver (for custom hardware)
   - Keyboard shortcuts driver

2. **Advanced Features**:
   - Input device priority/arbitration
   - Custom dead zone per device
   - Device-specific scaling factors
   - Input recording/playback for testing

3. **UI Improvements**:
   - Input device selection UI
   - Per-device configuration panels
   - Real-time input visualization

---
*This refactor provides the foundation for supporting diverse input methods while maintaining the robust soft limits and proportional control features.*