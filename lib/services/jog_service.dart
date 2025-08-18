import 'dart:math';

/// Pure functions for jog command generation
class JogCommandBuilder {
  /// Generate G-code work zero command
  static String buildWorkZeroCommand(String axes) {
    switch (axes) {
      case 'X':
        return 'G92 X0';
      case 'Y':
        return 'G92 Y0';
      case 'Z':
        return 'G92 Z0';
      case 'XYZ':
        return 'G92 X0 Y0 Z0';
      default:
        throw ArgumentError('Unknown axes for work zero: $axes');
    }
  }

  /// Generate G-code probe command
  static String buildProbeCommand(double distance, double feedRate) {
    return 'G38.2 Z-${distance.toStringAsFixed(1)} F${feedRate.toInt()}';
  }

  /// Generate G-code homing command
  static String buildHomingCommand() {
    return '\$H';
  }
}

/// Result of joystick input processing
class JoystickProcessResult {
  final double x;
  final double y;
  final double magnitude;
  final bool isActive;
  final int scaledFeedRate;
  final double baseDistance;

  const JoystickProcessResult({
    required this.x,
    required this.y,
    required this.magnitude,
    required this.isActive,
    required this.scaledFeedRate,
    required this.baseDistance,
  });
}

/// Pure functions for joystick input processing
class JoystickProcessor {
  static const double _deadZone = 0.05;
  static const double _targetExecutionTimeMs = 25.0;

  /// Process raw joystick input into actionable data
  static JoystickProcessResult process(
    double rawX,
    double rawY,
    int selectedFeedRate,
  ) {
    // Calculate magnitude and apply dead zone
    double magnitude = sqrt(rawX * rawX + rawY * rawY);
    magnitude = magnitude.clamp(0.0, 1.0);

    // Check if joystick is active (outside dead zone)
    final isActive = magnitude >= _deadZone;

    if (!isActive) {
      return JoystickProcessResult(
        x: 0.0,
        y: 0.0,
        magnitude: 0.0,
        isActive: false,
        scaledFeedRate: selectedFeedRate,
        baseDistance: 0.0,
      );
    }

    // Calculate base distance for fixed execution time
    final baseDistance = (selectedFeedRate / 60.0) * (_targetExecutionTimeMs / 1000.0);
    
    // Scale feed rate by magnitude
    final scaledFeedRate = (magnitude * selectedFeedRate).round();

    return JoystickProcessResult(
      x: rawX,
      y: rawY,
      magnitude: magnitude,
      isActive: true,
      scaledFeedRate: scaledFeedRate,
      baseDistance: baseDistance,
    );
  }

  /// Calculate if there's a significant direction change
  static bool hasSignificantDirectionChange(
    double currentX,
    double currentY,
    double lastX,
    double lastY,
  ) {
    if (lastX == 0.0 && lastY == 0.0) return true;

    final lastAngle = atan2(lastY, lastX);
    final currentAngle = atan2(currentY, currentX);
    final angleDiff = (currentAngle - lastAngle).abs();
    final normalizedAngleDiff = angleDiff > pi ? (2 * pi - angleDiff) : angleDiff;

    return normalizedAngleDiff > (pi / 6); // 30 degrees
  }

  /// Calculate if there's a significant magnitude change
  static bool hasSignificantMagnitudeChange(
    double currentMagnitude,
    double lastX,
    double lastY,
  ) {
    final lastMagnitude = sqrt(lastX * lastX + lastY * lastY);
    return (currentMagnitude - lastMagnitude).abs() > 0.1;
  }
}

/// Buffer management calculations
class BufferManager {
  static const double _targetMinUsed = 1.0;
  static const double _targetMaxUsed = 8.0;
  static const double _minIntervalMs = 8.0;  // 120Hz
  static const double _maxIntervalMs = 33.0; // 30Hz

  /// Calculate optimal command interval based on buffer usage
  static int calculateCommandInterval(
    int? plannerBlocksAvailable,
    int? maxObservedBufferBlocks,
  ) {
    if (plannerBlocksAvailable == null || maxObservedBufferBlocks == null) {
      return _minIntervalMs.round(); // Default to aggressive if no buffer info
    }

    // Calculate used buffer blocks
    final usedBufferBlocks = (maxObservedBufferBlocks - plannerBlocksAvailable).clamp(0.0, 15.0);
    
    // Linear interpolation between min and max intervals
    final bufferRatio = (usedBufferBlocks - _targetMinUsed) / (_targetMaxUsed - _targetMinUsed);
    final clampedRatio = bufferRatio.clamp(0.0, 1.0);
    
    return (_minIntervalMs + (_maxIntervalMs - _minIntervalMs) * clampedRatio).round();
  }

  /// Check if move distance is meaningful (worth sending)
  static bool isMeaningfulMove(double xDistance, double yDistance) {
    return (xDistance.abs() + yDistance.abs()) > 0.01; // > 0.01mm
  }
}

/// Timing utilities for jog commands
class JogTiming {
  /// Check if enough time has passed for next command
  static bool shouldSendCommand(
    DateTime? lastCommandTime,
    int targetIntervalMs,
  ) {
    if (lastCommandTime == null) return true;
    
    final timeSinceLastCommand = DateTime.now().difference(lastCommandTime).inMilliseconds;
    return timeSinceLastCommand >= targetIntervalMs;
  }
}