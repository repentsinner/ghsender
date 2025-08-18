import 'package:vector_math/vector_math.dart' as vm;
import 'dart:math' as math;

/// Centralized coordinate system conversion utility
/// 
/// Handles conversion between right-handed CNC coordinate system and 
/// left-handed Metal/Impeller coordinate system used by Flutter rendering.
/// 
/// Mathematical basis:
/// - CNC Machines: Right-handed coordinate system (X=right, Y=away from operator, Z=up)
/// - Flutter Scene/Impeller: Left-handed Metal coordinate system (standard across all backends)
/// - Conversion: Negate Y-axis while preserving X and Z axes
/// 
/// Reference: https://github.com/flutter/engine/blob/main/impeller/docs/coordinate_system.md
/// "Since the Metal backend was the first Impeller backend, the Metal coordinate system 
/// was picked as the Impeller coordinate system"
class CoordinateConverter {
  CoordinateConverter._(); // Private constructor - utility class only

  /// Transformation matrix for converting CNC coordinates to display coordinates
  /// Negates Y-axis: Matrix4.diagonal3(Vector3(1, -1, 1))
  static final vm.Matrix4 _cncToDisplayMatrix = vm.Matrix4.diagonal3(vm.Vector3(1, -1, 1));

  /// Transformation matrix for converting display coordinates back to CNC coordinates
  /// Same as forward transform since negation is symmetric: -(-Y) = Y
  static final vm.Matrix4 _displayToCncMatrix = vm.Matrix4.diagonal3(vm.Vector3(1, -1, 1));

  /// Convert CNC coordinates (right-handed) to display coordinates (left-handed Metal)
  /// 
  /// Example: CNC(10, 20, 5) → Display(10, -20, 5)
  static vm.Vector3 cncToDisplay(vm.Vector3 cncCoords) {
    return vm.Vector3(cncCoords.x, -cncCoords.y, cncCoords.z);
  }

  /// Convert display coordinates (left-handed Metal) back to CNC coordinates (right-handed)
  /// 
  /// Example: Display(10, -20, 5) → CNC(10, 20, 5)
  static vm.Vector3 displayToCnc(vm.Vector3 displayCoords) {
    return vm.Vector3(displayCoords.x, -displayCoords.y, displayCoords.z);
  }

  /// Get transformation matrix for converting CNC coordinates to display coordinates
  /// 
  /// Use this for renderer scene graph transformations where you need to apply
  /// the coordinate conversion to an entire node hierarchy.
  static vm.Matrix4 get cncToDisplayMatrix => _cncToDisplayMatrix.clone();

  /// Get transformation matrix for converting display coordinates back to CNC coordinates  
  /// 
  /// Use this when you need to convert user input or display coordinates back to
  /// CNC coordinate system for machine commands.
  static vm.Matrix4 get displayToCncMatrix => _displayToCncMatrix.clone();

  /// Convert camera target from CNC coordinates to display coordinates
  /// 
  /// Specialized method for camera system that documents the specific use case.
  /// Camera targets in CNC space need Y-negation for proper display orientation.
  static vm.Vector3 cncCameraTargetToDisplay(vm.Vector3 cncTarget) {
    return cncToDisplay(cncTarget);
  }

  /// Convert multiple CNC coordinate points to display coordinates efficiently
  /// 
  /// Useful for bulk conversion of G-code paths or work envelope vertices.
  static List<vm.Vector3> cncListToDisplay(List<vm.Vector3> cncPoints) {
    return cncPoints.map(cncToDisplay).toList();
  }

  /// Convert work envelope bounds from CNC to display coordinates
  /// 
  /// Specialized method for work envelope conversion that maintains proper bounds ordering.
  /// Note: After Y-negation, min/max Y bounds will be swapped.
  static ({vm.Vector3 minBounds, vm.Vector3 maxBounds}) cncWorkEnvelopeToDisplay({
    required vm.Vector3 cncMinBounds,
    required vm.Vector3 cncMaxBounds,
  }) {
    final displayMin = cncToDisplay(cncMinBounds);
    final displayMax = cncToDisplay(cncMaxBounds);
    
    // After Y-negation, Y bounds are flipped, so we need to correct the ordering
    return (
      minBounds: vm.Vector3(
        displayMin.x,
        math.min(displayMin.y, displayMax.y), // Take actual minimum Y after negation
        displayMin.z,
      ),
      maxBounds: vm.Vector3(
        displayMax.x,
        math.max(displayMin.y, displayMax.y), // Take actual maximum Y after negation
        displayMax.z,
      ),
    );
  }
}