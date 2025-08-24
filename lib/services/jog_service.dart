import 'dart:math';
import 'package:vector_math/vector_math.dart' as vm;
import '../domain/value_objects/work_envelope.dart';
import '../utils/soft_limit_checker.dart';

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

/// 3D joystick processing result for X,Y,Z axis movement
class JoystickProcessResult3D {
  final double x;
  final double y;
  final double z;
  final double magnitude;
  final bool isActive;
  final int scaledFeedRate;
  final double baseDistance;

  const JoystickProcessResult3D({
    required this.x,
    required this.y,
    required this.z,
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

  /// Process raw joystick input into actionable data (original method without soft limits)
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
    final baseDistance =
        (selectedFeedRate / 60.0) * (_targetExecutionTimeMs / 1000.0);

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

  /// Process raw joystick input with soft limit filtering applied before feed rate calculation
  static JoystickProcessResult processWithSoftLimits({
    required double rawX,
    required double rawY,
    required int selectedFeedRate,
    required vm.Vector3 currentPosition,
    required WorkEnvelope? workEnvelope,
  }) {
    // If work envelope unavailable, use original processing
    if (!SoftLimitChecker.shouldEnforceLimits(workEnvelope: workEnvelope)) {
      return process(rawX, rawY, selectedFeedRate);
    }

    // Calculate initial magnitude and apply dead zone
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

    // Calculate base distance for movement scaling
    final baseDistance =
        (selectedFeedRate / 60.0) * (_targetExecutionTimeMs / 1000.0);

    // CRITICAL: Filter joystick input BEFORE calculating final feed rate
    // This ensures the feed rate matches the actual movement vector magnitude
    final filteredInput = SoftLimitChecker.filterJoystickInput(
      rawX: rawX,
      rawY: rawY,
      currentPosition: currentPosition,
      workEnvelope: workEnvelope!,
      baseDistance: baseDistance,
    );

    // Calculate magnitude of filtered input for feed rate scaling
    final filteredMagnitude = sqrt(
      filteredInput.x * filteredInput.x + filteredInput.y * filteredInput.y,
    );
    final clampedFilteredMagnitude = filteredMagnitude.clamp(0.0, 1.0);

    // If filtering reduced movement to essentially zero, return inactive result
    if (clampedFilteredMagnitude < _deadZone) {
      return JoystickProcessResult(
        x: 0.0,
        y: 0.0,
        magnitude: 0.0,
        isActive: false,
        scaledFeedRate: selectedFeedRate,
        baseDistance: 0.0,
      );
    }

    // Scale feed rate by the FILTERED magnitude (this is the key correction)
    final scaledFeedRate = (clampedFilteredMagnitude * selectedFeedRate)
        .round();

    return JoystickProcessResult(
      x: filteredInput.x,
      y: filteredInput.y,
      magnitude: clampedFilteredMagnitude,
      isActive: true,
      scaledFeedRate: scaledFeedRate,
      baseDistance: baseDistance,
    );
  }

  /// Process raw 3D joystick input with soft limit filtering applied before feed rate calculation
  static JoystickProcessResult3D processWithSoftLimits3D({
    required double rawX,
    required double rawY,
    required double rawZ,
    required int selectedFeedRate,
    required vm.Vector3 currentPosition,
    required WorkEnvelope? workEnvelope,
  }) {
    // If work envelope unavailable, fall back to unfiltered 3D processing
    if (!SoftLimitChecker.shouldEnforceLimits(workEnvelope: workEnvelope)) {
      // Calculate 3D magnitude and apply dead zone
      double magnitude = sqrt(rawX * rawX + rawY * rawY + rawZ * rawZ);
      magnitude = magnitude.clamp(0.0, 1.0);

      final isActive = magnitude >= _deadZone;
      if (!isActive) {
        return JoystickProcessResult3D(
          x: 0.0,
          y: 0.0,
          z: 0.0,
          magnitude: 0.0,
          isActive: false,
          scaledFeedRate: selectedFeedRate,
          baseDistance: 0.0,
        );
      }

      final baseDistance =
          (selectedFeedRate / 60.0) * (_targetExecutionTimeMs / 1000.0);
      final scaledFeedRate = (magnitude * selectedFeedRate).round();

      return JoystickProcessResult3D(
        x: rawX,
        y: rawY,
        z: rawZ,
        magnitude: magnitude,
        isActive: true,
        scaledFeedRate: scaledFeedRate,
        baseDistance: baseDistance,
      );
    }

    // Calculate initial 3D magnitude and apply dead zone
    double magnitude = sqrt(rawX * rawX + rawY * rawY + rawZ * rawZ);
    magnitude = magnitude.clamp(0.0, 1.0);

    final isActive = magnitude >= _deadZone;
    if (!isActive) {
      return JoystickProcessResult3D(
        x: 0.0,
        y: 0.0,
        z: 0.0,
        magnitude: 0.0,
        isActive: false,
        scaledFeedRate: selectedFeedRate,
        baseDistance: 0.0,
      );
    }

    final baseDistance =
        (selectedFeedRate / 60.0) * (_targetExecutionTimeMs / 1000.0);

    // Apply 3D soft limit filtering
    final filteredInput = SoftLimitChecker.filterJoystickInput3D(
      rawX: rawX,
      rawY: rawY,
      rawZ: rawZ,
      currentPosition: currentPosition,
      workEnvelope: workEnvelope!,
      baseDistance: baseDistance,
    );

    // Calculate magnitude of filtered 3D input for feed rate scaling
    final filteredMagnitude = sqrt(
      filteredInput.x * filteredInput.x +
          filteredInput.y * filteredInput.y +
          filteredInput.z * filteredInput.z,
    );
    final clampedFilteredMagnitude = filteredMagnitude.clamp(0.0, 1.0);

    // If filtering reduced movement to essentially zero, return inactive result
    if (clampedFilteredMagnitude < _deadZone) {
      return JoystickProcessResult3D(
        x: 0.0,
        y: 0.0,
        z: 0.0,
        magnitude: 0.0,
        isActive: false,
        scaledFeedRate: selectedFeedRate,
        baseDistance: 0.0,
      );
    }

    // Scale feed rate by the FILTERED magnitude
    final scaledFeedRate = (clampedFilteredMagnitude * selectedFeedRate)
        .round();

    return JoystickProcessResult3D(
      x: filteredInput.x,
      y: filteredInput.y,
      z: filteredInput.z,
      magnitude: clampedFilteredMagnitude,
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
    final normalizedAngleDiff = angleDiff > pi
        ? (2 * pi - angleDiff)
        : angleDiff;

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
  static const double _minIntervalMs = 8.0; // 120Hz
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
    final usedBufferBlocks = (maxObservedBufferBlocks - plannerBlocksAvailable)
        .clamp(0.0, 15.0);

    // Linear interpolation between min and max intervals
    final bufferRatio =
        (usedBufferBlocks - _targetMinUsed) / (_targetMaxUsed - _targetMinUsed);
    final clampedRatio = bufferRatio.clamp(0.0, 1.0);

    return (_minIntervalMs + (_maxIntervalMs - _minIntervalMs) * clampedRatio)
        .round();
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

    final timeSinceLastCommand = DateTime.now()
        .difference(lastCommandTime)
        .inMilliseconds;
    return timeSinceLastCommand >= targetIntervalMs;
  }
}
