import 'dart:math';
import 'package:vector_math/vector_math.dart' as vm;
import '../models/machine_controller.dart';

/// Utility for checking and filtering movements against soft limits
///
/// This class implements application-level soft limit checking by comparing
/// MACHINE POSITION (MPos) against the Work Envelope boundaries.
///
/// Key Concepts:
/// - Work Envelope: grblHAL's soft limits boundary (hard limits minus pulloff distance)
/// - Machine Position: Absolute position of the machine tool/spindle (MPos)
/// - Work Position: Position of the workpiece in work coordinate system (WPos)
///
/// We check: Machine Position + Jog Vector vs Work Envelope
/// This prevents machine crashes by staying within safe travel boundaries.
class SoftLimitChecker {
  /// Safety buffer distance from soft limit boundaries (in machine units)
  /// This prevents movements that would get too close to the actual limits
  static const double safetyBuffer = 1.0; // 1mm buffer
  /// Check if soft limits should be enforced based on work envelope availability
  /// Note: This is independent of grblHAL's soft limits setting ($20)
  /// Our application-level filtering works best when grblHAL soft limits are disabled
  static bool shouldEnforceLimits({required WorkEnvelope? workEnvelope}) {
    // Only require work envelope - we filter regardless of grblHAL soft limits setting
    return workEnvelope != null;
  }

  /// Check if a position is within the work envelope (with safety buffer)
  static bool isPositionWithinLimits(
    vm.Vector3 position,
    WorkEnvelope workEnvelope, {
    double? customSafetyBuffer,
  }) {
    final buffer = customSafetyBuffer ?? safetyBuffer;
    // Apply safety buffer to all boundaries
    final safeMinX = workEnvelope.minBounds.x + buffer;
    final safeMaxX = workEnvelope.maxBounds.x - buffer;
    final safeMinY = workEnvelope.minBounds.y + buffer;
    final safeMaxY = workEnvelope.maxBounds.y - buffer;
    final safeMinZ = workEnvelope.minBounds.z + buffer;
    final safeMaxZ = workEnvelope.maxBounds.z - buffer;

    return position.x >= safeMinX &&
        position.x <= safeMaxX &&
        position.y >= safeMinY &&
        position.y <= safeMaxY &&
        position.z >= safeMinZ &&
        position.z <= safeMaxZ;
  }

  /// Filter a 3D movement vector (X,Y,Z) to remove components that would violate soft limits
  ///
  /// IMPORTANT: currentPosition must be MACHINE POSITION (MPos), not work position (WPos)
  ///
  /// Returns the filtered movement vector, preserving safe components
  static vm.Vector3 filterMovement3D({
    required vm.Vector3 requestedMovement,
    required vm.Vector3 currentPosition, // Must be machine position (MPos)
    required WorkEnvelope workEnvelope,
    double? customSafetyBuffer,
  }) {
    final buffer = customSafetyBuffer ?? safetyBuffer;
    // Apply safety buffer to all boundaries
    final safeMinX = workEnvelope.minBounds.x + buffer;
    final safeMaxX = workEnvelope.maxBounds.x - buffer;
    final safeMinY = workEnvelope.minBounds.y + buffer;
    final safeMaxY = workEnvelope.maxBounds.y - buffer;
    final safeMinZ = workEnvelope.minBounds.z + buffer;
    final safeMaxZ = workEnvelope.maxBounds.z - buffer;

    // Calculate target position for each axis
    final targetX = currentPosition.x + requestedMovement.x;
    final targetY = currentPosition.y + requestedMovement.y;
    final targetZ = currentPosition.z + requestedMovement.z;

    // Check each axis independently and filter unsafe components
    double safeX = requestedMovement.x;
    double safeY = requestedMovement.y;
    double safeZ = requestedMovement.z;

    // Filter X movement if it would violate safe limits
    if (targetX < safeMinX) {
      safeX = safeMinX - currentPosition.x;
    } else if (targetX > safeMaxX) {
      safeX = safeMaxX - currentPosition.x;
    }

    // Filter Y movement if it would violate safe limits
    if (targetY < safeMinY) {
      safeY = safeMinY - currentPosition.y;
    } else if (targetY > safeMaxY) {
      safeY = safeMaxY - currentPosition.y;
    }

    // Filter Z movement if it would violate safe limits
    if (targetZ < safeMinZ) {
      safeZ = safeMinZ - currentPosition.z;
    } else if (targetZ > safeMaxZ) {
      safeZ = safeMaxZ - currentPosition.z;
    }

    // Clamp to zero if movement is very small (avoid numerical precision issues)
    const minMovement = 0.001; // 1 micron
    if (safeX.abs() < minMovement) safeX = 0.0;
    if (safeY.abs() < minMovement) safeY = 0.0;
    if (safeZ.abs() < minMovement) safeZ = 0.0;

    return vm.Vector3(safeX, safeY, safeZ);
  }

  /// Filter a 2D movement vector (X,Y) to remove components that would violate soft limits
  ///
  /// IMPORTANT: currentPosition must be MACHINE POSITION (MPos), not work position (WPos)
  ///
  /// Returns the filtered movement vector, preserving safe components
  static vm.Vector2 filterMovement2D({
    required vm.Vector2 requestedMovement,
    required vm.Vector3 currentPosition, // Must be machine position (MPos)
    required WorkEnvelope workEnvelope,
    double? customSafetyBuffer,
  }) {
    // Convert to 3D, filter, then convert back to 2D
    final requestedMovement3D = vm.Vector3(
      requestedMovement.x,
      requestedMovement.y,
      0.0,
    );
    final filtered3D = filterMovement3D(
      requestedMovement: requestedMovement3D,
      currentPosition: currentPosition,
      workEnvelope: workEnvelope,
      customSafetyBuffer: customSafetyBuffer,
    );
    return vm.Vector2(filtered3D.x, filtered3D.y);
  }

  /// Filter 2D joystick input (X,Y) to respect soft limits
  /// This is the key method for 2D joystick processing pipeline
  static vm.Vector2 filterJoystickInput({
    required double rawX,
    required double rawY,
    required vm.Vector3 currentPosition,
    required WorkEnvelope workEnvelope,
    required double baseDistance,
  }) {
    // Convert normalized joystick input to movement distances
    // CRITICAL: Convert to CNC coordinates here (Y-axis inversion)
    final requestedMovement = vm.Vector2(
      rawX * baseDistance,
      -rawY *
          baseDistance, // Invert Y: joystick Y+ (down) → CNC Y- (towards operator)
    );

    // Apply soft limit filtering
    final filteredMovement = filterMovement2D(
      requestedMovement: requestedMovement,
      currentPosition: currentPosition,
      workEnvelope: workEnvelope,
      customSafetyBuffer: safetyBuffer,
    );

    // Convert back to normalized joystick coordinates
    if (baseDistance == 0.0) {
      return vm.Vector2.zero();
    }

    return vm.Vector2(
      filteredMovement.x / baseDistance,
      -filteredMovement.y /
          baseDistance, // Convert back from CNC Y to joystick Y coordinates
    );
  }

  /// Filter 3D joystick input (X,Y,Z) to respect soft limits
  /// This method supports optional Z-axis input for 3D joystick processing
  static vm.Vector3 filterJoystickInput3D({
    required double rawX,
    required double rawY,
    required double rawZ,
    required vm.Vector3 currentPosition,
    required WorkEnvelope workEnvelope,
    required double baseDistance,
  }) {
    // Convert normalized joystick input to movement distances
    // CRITICAL: Convert to CNC coordinates (Y-axis inversion, Z-axis direct)
    final requestedMovement = vm.Vector3(
      rawX * baseDistance,
      -rawY *
          baseDistance, // Invert Y: joystick Y+ (down) → CNC Y- (towards operator)
      rawZ *
          baseDistance, // Z-axis: joystick Z+ (up) → CNC Z+ (up, away from workpiece)
    );

    // Apply soft limit filtering
    final filteredMovement = filterMovement3D(
      requestedMovement: requestedMovement,
      currentPosition: currentPosition,
      workEnvelope: workEnvelope,
      customSafetyBuffer: safetyBuffer,
    );

    // Convert back to normalized joystick coordinates
    if (baseDistance == 0.0) {
      return vm.Vector3.zero();
    }

    return vm.Vector3(
      filteredMovement.x / baseDistance,
      -filteredMovement.y /
          baseDistance, // Convert back from CNC Y to joystick Y coordinates
      filteredMovement.z / baseDistance, // Z-axis direct conversion back
    );
  }

  /// Calculate the maximum safe distance for a single-axis movement
  static double getMaxSafeDistance({
    required double currentPosition,
    required double direction, // +1 or -1
    required double minBound,
    required double maxBound,
  }) {
    if (direction > 0) {
      // Moving in positive direction
      return max(0.0, maxBound - currentPosition);
    } else if (direction < 0) {
      // Moving in negative direction
      return max(0.0, currentPosition - minBound);
    } else {
      // No movement
      return 0.0;
    }
  }

  /// Check if any movement is possible from current position
  static bool hasMovementSpace({
    required vm.Vector3 currentPosition,
    required WorkEnvelope workEnvelope,
  }) {
    // Check if we can move in any direction
    final canMoveXPos = currentPosition.x < workEnvelope.maxBounds.x;
    final canMoveXNeg = currentPosition.x > workEnvelope.minBounds.x;
    final canMoveYPos = currentPosition.y < workEnvelope.maxBounds.y;
    final canMoveYNeg = currentPosition.y > workEnvelope.minBounds.y;

    return canMoveXPos || canMoveXNeg || canMoveYPos || canMoveYNeg;
  }
}
