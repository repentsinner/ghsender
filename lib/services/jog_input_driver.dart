import 'dart:async';

/// Standardized jog input event from any input device
class JogInputEvent {
  final double x;
  final double y;
  final double z;
  final double a; // Rotational A axis (typically around X)
  final double b; // Rotational B axis (typically around Y)
  final double c; // Rotational C axis (typically around Z)
  final DateTime timestamp;
  final String deviceId; // Identifier for the input device

  JogInputEvent({
    required this.x,
    required this.y,
    this.z = 0.0,
    this.a = 0.0,
    this.b = 0.0,
    this.c = 0.0,
    DateTime? timestamp,
    required this.deviceId,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create 2D input event (most common case)
  JogInputEvent.xy({
    required this.x,
    required this.y,
    DateTime? timestamp,
    required this.deviceId,
  }) : z = 0.0,
       a = 0.0,
       b = 0.0,
       c = 0.0,
       timestamp = timestamp ?? DateTime.now();

  /// Create 3D input event
  JogInputEvent.xyz({
    required this.x,
    required this.y,
    required this.z,
    DateTime? timestamp,
    required this.deviceId,
  }) : a = 0.0,
       b = 0.0,
       c = 0.0,
       timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'JogInputEvent($deviceId: x=$x, y=$y, z=$z, a=$a, b=$b, c=$c)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JogInputEvent &&
        other.x == x &&
        other.y == y &&
        other.z == z &&
        other.a == a &&
        other.b == b &&
        other.c == c &&
        other.deviceId == deviceId;
  }

  @override
  int get hashCode => Object.hash(x, y, z, a, b, c, deviceId);
}

/// Capabilities that an input driver supports
class JogInputCapabilities {
  final bool supportsLinearX;
  final bool supportsLinearY; 
  final bool supportsLinearZ;
  final bool supportsRotationalA;
  final bool supportsRotationalB;
  final bool supportsRotationalC;
  final String displayName;

  const JogInputCapabilities({
    this.supportsLinearX = true,
    this.supportsLinearY = true,
    this.supportsLinearZ = false,
    this.supportsRotationalA = false,
    this.supportsRotationalB = false,
    this.supportsRotationalC = false,
    required this.displayName,
  });

  /// 2D joystick capabilities (X,Y only)
  static const xy2D = JogInputCapabilities(
    supportsLinearX: true,
    supportsLinearY: true,
    displayName: '2D Joystick',
  );

  /// 3D joystick capabilities (X,Y,Z)
  static const xyz3D = JogInputCapabilities(
    supportsLinearX: true,
    supportsLinearY: true,
    supportsLinearZ: true,
    displayName: '3D Joystick',
  );

  /// 6DOF spacemouse capabilities (X,Y,Z,A,B,C)
  static const spacemouse6DOF = JogInputCapabilities(
    supportsLinearX: true,
    supportsLinearY: true,
    supportsLinearZ: true,
    supportsRotationalA: true,
    supportsRotationalB: true,
    supportsRotationalC: true,
    displayName: '6DOF Spacemouse',
  );

  /// Get supported axes count
  int get supportedAxesCount {
    int count = 0;
    if (supportsLinearX) count++;
    if (supportsLinearY) count++;
    if (supportsLinearZ) count++;
    if (supportsRotationalA) count++;
    if (supportsRotationalB) count++;
    if (supportsRotationalC) count++;
    return count;
  }

  /// Check if this is a 2D input device
  bool get is2D => supportsLinearX && supportsLinearY && 
                   !supportsLinearZ && !supportsRotationalA && 
                   !supportsRotationalB && !supportsRotationalC;

  /// Check if this is a 3D input device
  bool get is3D => supportsLinearX && supportsLinearY && supportsLinearZ &&
                   !supportsRotationalA && !supportsRotationalB && 
                   !supportsRotationalC;

  /// Check if this is a 6DOF input device
  bool get is6DOF => supportsLinearX && supportsLinearY && supportsLinearZ &&
                     supportsRotationalA && supportsRotationalB && 
                     supportsRotationalC;
}

/// Abstract base class for jog input drivers
/// Each input device type (joystick UI, gamepad, spacemouse) implements this interface
abstract class JogInputDriver {
  /// Unique identifier for this driver instance
  String get deviceId;

  /// Human-readable display name
  String get displayName;

  /// Capabilities of this input device
  JogInputCapabilities get capabilities;

  /// Stream of input events from this device
  Stream<JogInputEvent> get inputStream;

  /// Whether this driver is currently active/connected
  bool get isActive;

  /// Initialize the driver (setup hardware connections, UI listeners, etc.)
  Future<void> initialize();

  /// Dispose resources and cleanup
  Future<void> dispose();

  /// Enable/disable the driver
  void setEnabled(bool enabled);

  /// Check if driver is enabled
  bool get isEnabled;
}

/// Base implementation with common functionality
abstract class BaseJogInputDriver implements JogInputDriver {
  final String _deviceId;
  final String _displayName;
  final JogInputCapabilities _capabilities;
  
  late final StreamController<JogInputEvent> _inputController;
  bool _isEnabled = true;
  bool _isInitialized = false;

  BaseJogInputDriver({
    required String deviceId,
    required String displayName,
    required JogInputCapabilities capabilities,
  }) : _deviceId = deviceId,
       _displayName = displayName,
       _capabilities = capabilities {
    _inputController = StreamController<JogInputEvent>.broadcast();
  }

  @override
  String get deviceId => _deviceId;

  @override
  String get displayName => _displayName;

  @override
  JogInputCapabilities get capabilities => _capabilities;

  @override
  Stream<JogInputEvent> get inputStream => _inputController.stream;

  @override
  bool get isEnabled => _isEnabled;

  @override
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      // Send zero input when disabled
      _emitInputEvent(JogInputEvent.xy(x: 0.0, y: 0.0, deviceId: deviceId));
    }
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    await onInitialize();
    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    _isEnabled = false;
    await onDispose();
    await _inputController.close();
    _isInitialized = false;
  }

  /// Emit input event to listeners (called by concrete implementations)
  void _emitInputEvent(JogInputEvent event) {
    if (_isEnabled && !_inputController.isClosed) {
      _inputController.add(event);
    }
  }

  /// Concrete implementations override this to handle device-specific initialization
  Future<void> onInitialize();

  /// Concrete implementations override this to handle device-specific cleanup
  Future<void> onDispose();

  /// Helper method for concrete implementations to emit events
  void emitInput({
    double x = 0.0,
    double y = 0.0,
    double z = 0.0,
    double a = 0.0,
    double b = 0.0,
    double c = 0.0,
  }) {
    _emitInputEvent(JogInputEvent(
      x: x,
      y: y,
      z: z,
      a: a,
      b: b,
      c: c,
      deviceId: deviceId,
    ));
  }

  /// Helper method for 2D input
  void emitInput2D(double x, double y) {
    _emitInputEvent(JogInputEvent.xy(x: x, y: y, deviceId: deviceId));
  }

  /// Helper method for 3D input
  void emitInput3D(double x, double y, double z) {
    _emitInputEvent(JogInputEvent.xyz(x: x, y: y, z: z, deviceId: deviceId));
  }
}