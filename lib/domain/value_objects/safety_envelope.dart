import 'package:equatable/equatable.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'dart:math' as math;

/// Immutable safety envelope for machine operation boundaries
/// 
/// Represents the safe operating boundaries for machine movement with configurable
/// safety margins. This value object encapsulates the same logic as the existing
/// WorkEnvelope but as a domain-focused entity.
class SafetyEnvelope extends Equatable {
  final vm.Vector3 minBounds;
  final vm.Vector3 maxBounds;
  final double safetyMargin;

  const SafetyEnvelope({
    required this.minBounds,
    required this.maxBounds,
    this.safetyMargin = 1.0, // 1mm safety margin - matches SoftLimitChecker
  });

  /// Check if a position is within the safety envelope boundaries
  /// 
  /// Applies the safety margin to create a smaller safe area within the bounds.
  /// This matches the logic from SoftLimitChecker.isPositionWithinLimits()
  bool contains(vm.Vector3 position) {
    final adjustedMin = vm.Vector3(
      minBounds.x + safetyMargin,
      minBounds.y + safetyMargin,
      minBounds.z + safetyMargin,
    );
    final adjustedMax = vm.Vector3(
      maxBounds.x - safetyMargin,
      maxBounds.y - safetyMargin,
      maxBounds.z - safetyMargin,
    );

    return position.x >= adjustedMin.x && position.x <= adjustedMax.x &&
           position.y >= adjustedMin.y && position.y <= adjustedMax.y &&
           position.z >= adjustedMin.z && position.z <= adjustedMax.z;
  }

  /// Calculate minimum distance to any envelope boundary
  /// 
  /// Returns the shortest distance from the position to any envelope edge,
  /// which is useful for determining how close to limits the machine is.
  double distanceToEdge(vm.Vector3 position) {
    final distances = [
      position.x - minBounds.x,
      maxBounds.x - position.x,
      position.y - minBounds.y,
      maxBounds.y - position.y,
      position.z - minBounds.z,
      maxBounds.z - position.z,
    ];
    
    return distances.reduce(math.min);
  }

  /// Create SafetyEnvelope from existing WorkEnvelope
  /// 
  /// This factory bridges the gap between existing models and new domain entities
  /// during the migration process.
  factory SafetyEnvelope.fromWorkEnvelope(dynamic workEnvelope) {
    return SafetyEnvelope(
      minBounds: workEnvelope.minBounds,
      maxBounds: workEnvelope.maxBounds,
    );
  }

  @override
  List<Object?> get props => [minBounds, maxBounds, safetyMargin];

  @override
  String toString() => 'SafetyEnvelope(min: $minBounds, max: $maxBounds, margin: ${safetyMargin}mm)';
}