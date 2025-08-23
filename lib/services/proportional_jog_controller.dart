import 'dart:math';
import 'package:vector_math/vector_math.dart' as vm;
import '../models/machine_controller.dart';
import '../utils/soft_limit_checker.dart';

/// Input data for proportional jog processing
class ProportionalJogInput {
  final double x;
  final double y;
  final double z;
  final double a; // Rotational A axis (typically around X)
  final double b; // Rotational B axis (typically around Y) 
  final double c; // Rotational C axis (typically around Z)
  final int selectedFeedRate;
  final vm.Vector3? currentPosition;
  final WorkEnvelope? workEnvelope;

  const ProportionalJogInput({
    required this.x,
    required this.y,
    this.z = 0.0,
    this.a = 0.0,
    this.b = 0.0,
    this.c = 0.0,
    required this.selectedFeedRate,
    this.currentPosition,
    this.workEnvelope,
  });
}

/// Result of proportional jog processing
class ProportionalJogResult {
  final double x;
  final double y;
  final double z;
  final double a;
  final double b; 
  final double c;
  final double magnitude;
  final bool isActive;
  final int scaledFeedRate;
  final double baseDistance;

  const ProportionalJogResult({
    required this.x,
    required this.y,
    this.z = 0.0,
    this.a = 0.0,
    this.b = 0.0,
    this.c = 0.0,
    required this.magnitude,
    required this.isActive,
    required this.scaledFeedRate,
    required this.baseDistance,
  });

  /// Convert to 2D result for backward compatibility
  ProportionalJogResult to2D() {
    return ProportionalJogResult(
      x: x,
      y: y,
      z: 0.0,
      a: 0.0,
      b: 0.0,
      c: 0.0,
      magnitude: sqrt(x * x + y * y),
      isActive: isActive,
      scaledFeedRate: scaledFeedRate,
      baseDistance: baseDistance,
    );
  }

  /// Convert to 3D result for backward compatibility
  ProportionalJogResult to3D() {
    return ProportionalJogResult(
      x: x,
      y: y,
      z: z,
      a: 0.0,
      b: 0.0,
      c: 0.0,
      magnitude: sqrt(x * x + y * y + z * z),
      isActive: isActive,
      scaledFeedRate: scaledFeedRate,
      baseDistance: baseDistance,
    );
  }
}

/// Generic proportional movement controller
/// Handles dead zones, magnitude calculations, feed rate scaling, and soft limits
/// Supports up to 6DOF input (X,Y,Z linear + A,B,C rotational axes)
class ProportionalJogController {
  static const double _deadZone = 0.05;
  static const double _targetExecutionTimeMs = 25.0;

  /// Process proportional input with full 6DOF support
  static ProportionalJogResult process(ProportionalJogInput input) {
    // Calculate linear magnitude (X,Y,Z)
    final linearMagnitude = sqrt(
      input.x * input.x + 
      input.y * input.y + 
      input.z * input.z
    );
    
    // Calculate rotational magnitude (A,B,C) - treated separately
    final rotationalMagnitude = sqrt(
      input.a * input.a + 
      input.b * input.b + 
      input.c * input.c
    );

    // Overall magnitude considers both linear and rotational input
    final magnitude = max(linearMagnitude, rotationalMagnitude).clamp(0.0, 1.0);

    // Check if input is active (outside dead zone)
    final isActive = magnitude >= _deadZone;

    if (!isActive) {
      return ProportionalJogResult(
        x: 0.0,
        y: 0.0,
        z: 0.0,
        a: 0.0,
        b: 0.0,
        c: 0.0,
        magnitude: 0.0,
        isActive: false,
        scaledFeedRate: input.selectedFeedRate,
        baseDistance: 0.0,
      );
    }

    // Calculate base distance for this execution cycle
    final baseDistance = (input.selectedFeedRate / 60.0) * (_targetExecutionTimeMs / 1000.0);

    // Apply soft limits filtering if we have position and envelope data
    final vm.Vector3 rawLinearInput = vm.Vector3(input.x, input.y, input.z);
    final vm.Vector3 filteredLinearInput;

    if (input.currentPosition != null && input.workEnvelope != null) {
      // Filter 3D linear movement through soft limits
      final requestedMovement = rawLinearInput * baseDistance;
      final filteredMovement = SoftLimitChecker.filterMovement3D(
        requestedMovement: requestedMovement,
        currentPosition: input.currentPosition!,
        workEnvelope: input.workEnvelope!,
      );
      
      // Convert back to proportional values
      filteredLinearInput = baseDistance > 0 ? filteredMovement / baseDistance : vm.Vector3.zero();
    } else {
      // No filtering available - use raw input
      filteredLinearInput = rawLinearInput;
    }

    // Rotational axes don't need soft limit filtering (they don't affect machine position boundaries)
    final filteredRotationalInput = vm.Vector3(input.a, input.b, input.c);

    // Recalculate magnitude after filtering
    final filteredLinearMagnitude = filteredLinearInput.length;
    final filteredRotationalMagnitude = filteredRotationalInput.length;
    final filteredMagnitude = max(filteredLinearMagnitude, filteredRotationalMagnitude).clamp(0.0, 1.0);

    // Scale feed rate based on filtered magnitude
    final scaledFeedRate = (input.selectedFeedRate * filteredMagnitude).round();

    return ProportionalJogResult(
      x: filteredLinearInput.x,
      y: filteredLinearInput.y,
      z: filteredLinearInput.z,
      a: filteredRotationalInput.x, // A mapped to x component of rotational vector
      b: filteredRotationalInput.y, // B mapped to y component of rotational vector  
      c: filteredRotationalInput.z, // C mapped to z component of rotational vector
      magnitude: filteredMagnitude,
      isActive: filteredMagnitude >= _deadZone,
      scaledFeedRate: scaledFeedRate,
      baseDistance: baseDistance,
    );
  }

  /// Process 2D input (X,Y only) - convenience method
  static ProportionalJogResult process2D({
    required double rawX,
    required double rawY,
    required int selectedFeedRate,
    vm.Vector3? currentPosition,
    WorkEnvelope? workEnvelope,
  }) {
    final input = ProportionalJogInput(
      x: rawX,
      y: rawY,
      z: 0.0,
      selectedFeedRate: selectedFeedRate,
      currentPosition: currentPosition,
      workEnvelope: workEnvelope,
    );
    return process(input);
  }

  /// Process 3D input (X,Y,Z) - convenience method
  static ProportionalJogResult process3D({
    required double rawX,
    required double rawY,
    required double rawZ,
    required int selectedFeedRate,
    vm.Vector3? currentPosition,
    WorkEnvelope? workEnvelope,
  }) {
    final input = ProportionalJogInput(
      x: rawX,
      y: rawY,
      z: rawZ,
      selectedFeedRate: selectedFeedRate,
      currentPosition: currentPosition,
      workEnvelope: workEnvelope,
    );
    return process(input);
  }

  /// Check for significant direction changes (used for command timing optimization)
  static bool hasSignificantDirectionChange(
    double newX,
    double newY,
    double oldX,
    double oldY,
  ) {
    const double threshold = 0.1; // 10% change threshold
    
    // Skip if either magnitude is too small
    final newMag = sqrt(newX * newX + newY * newY);
    final oldMag = sqrt(oldX * oldX + oldY * oldY);
    
    if (newMag < _deadZone || oldMag < _deadZone) {
      return false;
    }
    
    // Calculate normalized vectors
    final newNormX = newX / newMag;
    final newNormY = newY / newMag;
    final oldNormX = oldX / oldMag;
    final oldNormY = oldY / oldMag;
    
    // Calculate angle difference using dot product
    final dotProduct = (newNormX * oldNormX) + (newNormY * oldNormY);
    final dotProductClamped = dotProduct.clamp(-1.0, 1.0);
    
    // If dot product is less than threshold, direction changed significantly
    return dotProductClamped < (1.0 - threshold);
  }

  /// Check for significant magnitude changes (used for command timing optimization)
  static bool hasSignificantMagnitudeChange(
    double newMagnitude,
    double oldX,
    double oldY,
  ) {
    const double threshold = 0.15; // 15% change threshold
    final oldMagnitude = sqrt(oldX * oldX + oldY * oldY);
    
    // Skip if either magnitude is in dead zone
    if (newMagnitude < _deadZone || oldMagnitude < _deadZone) {
      return false;
    }
    
    final magnitudeRatio = (newMagnitude - oldMagnitude).abs() / oldMagnitude;
    return magnitudeRatio > threshold;
  }
}