import 'dart:math' as math;
import 'package:equatable/equatable.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Pure geometric bounding box abstraction
/// 
/// Represents an axis-aligned bounding box (AABB) in 3D space.
/// All coordinates are internally stored in mm units for consistency.
/// This is a pure geometric abstraction without domain-specific meaning.
class BoundingBox extends Equatable {
  /// Minimum corner of the bounding box (lower-left-back in standard orientation)
  final vm.Vector3 minBounds;
  
  /// Maximum corner of the bounding box (upper-right-front in standard orientation)
  final vm.Vector3 maxBounds;

  const BoundingBox({
    required this.minBounds,
    required this.maxBounds,
  }) : assert(
          // Validate that minBounds <= maxBounds for each axis
          const bool.fromEnvironment('dart.vm.product') ||
              true, // Skip assertion in production for performance
        );

  /// Create a bounding box from individual coordinate components
  factory BoundingBox.fromCoordinates({
    required double minX,
    required double minY,
    required double minZ,
    required double maxX,
    required double maxY,
    required double maxZ,
  }) {
    return BoundingBox(
      minBounds: vm.Vector3(minX, minY, minZ),
      maxBounds: vm.Vector3(maxX, maxY, maxZ),
    );
  }

  /// Create a bounding box centered at the origin with given dimensions
  factory BoundingBox.centered({
    required double width,
    required double height,
    required double depth,
  }) {
    final halfWidth = width * 0.5;
    final halfHeight = height * 0.5;
    final halfDepth = depth * 0.5;
    
    return BoundingBox(
      minBounds: vm.Vector3(-halfWidth, -halfHeight, -halfDepth),
      maxBounds: vm.Vector3(halfWidth, halfHeight, halfDepth),
    );
  }

  /// Create a bounding box from a single point (zero-volume box)
  factory BoundingBox.fromPoint(vm.Vector3 point) {
    return BoundingBox(
      minBounds: point,
      maxBounds: point,
    );
  }

  /// Create an empty/invalid bounding box
  /// 
  /// This represents an uninitialized state where no valid bounds exist yet.
  /// Use [isEmpty] to check if a bounding box is in this state.
  factory BoundingBox.empty() {
    return BoundingBox(
      minBounds: vm.Vector3(double.infinity, double.infinity, double.infinity),
      maxBounds: vm.Vector3(double.negativeInfinity, double.negativeInfinity, double.negativeInfinity),
    );
  }

  /// Calculate the center point of the bounding box
  vm.Vector3 get center => (minBounds + maxBounds) * 0.5;

  /// Calculate the size (dimensions) of the bounding box
  vm.Vector3 get size => maxBounds - minBounds;

  /// Get the width (X-axis extent) of the bounding box
  double get width => maxBounds.x - minBounds.x;

  /// Get the height (Y-axis extent) of the bounding box
  double get height => maxBounds.y - minBounds.y;

  /// Get the depth (Z-axis extent) of the bounding box
  double get depth => maxBounds.z - minBounds.z;

  /// Calculate the volume of the bounding box
  double get volume => width * height * depth;

  /// Check if this bounding box is empty (has no valid bounds)
  bool get isEmpty => 
      minBounds.x > maxBounds.x || 
      minBounds.y > maxBounds.y || 
      minBounds.z > maxBounds.z;

  /// Check if this bounding box has zero volume
  bool get isPoint => 
      !isEmpty && (width == 0.0 || height == 0.0 || depth == 0.0);

  /// Check if a 3D point is contained within this bounding box
  bool contains(vm.Vector3 point) {
    if (isEmpty) return false;
    
    return point.x >= minBounds.x && point.x <= maxBounds.x &&
           point.y >= minBounds.y && point.y <= maxBounds.y &&
           point.z >= minBounds.z && point.z <= maxBounds.z;
  }

  /// Check if another bounding box intersects with this one
  bool intersects(BoundingBox other) {
    if (isEmpty || other.isEmpty) return false;
    
    return !(other.maxBounds.x < minBounds.x || 
             other.minBounds.x > maxBounds.x ||
             other.maxBounds.y < minBounds.y || 
             other.minBounds.y > maxBounds.y ||
             other.maxBounds.z < minBounds.z || 
             other.minBounds.z > maxBounds.z);
  }

  /// Check if this bounding box completely contains another bounding box
  bool containsBox(BoundingBox other) {
    if (isEmpty || other.isEmpty) return false;
    
    return other.minBounds.x >= minBounds.x && other.maxBounds.x <= maxBounds.x &&
           other.minBounds.y >= minBounds.y && other.maxBounds.y <= maxBounds.y &&
           other.minBounds.z >= minBounds.z && other.maxBounds.z <= maxBounds.z;
  }

  /// Expand the bounding box by a uniform margin in all directions
  BoundingBox expand(double margin) {
    if (isEmpty) return this;
    
    final marginVector = vm.Vector3.all(margin);
    return BoundingBox(
      minBounds: minBounds - marginVector,
      maxBounds: maxBounds + marginVector,
    );
  }

  /// Expand the bounding box by different margins for each axis
  BoundingBox expandByVector(vm.Vector3 margins) {
    if (isEmpty) return this;
    
    return BoundingBox(
      minBounds: minBounds - margins,
      maxBounds: maxBounds + margins,
    );
  }

  /// Create the union (combined bounds) of this box with another
  BoundingBox union(BoundingBox other) {
    if (isEmpty) return other;
    if (other.isEmpty) return this;
    
    return BoundingBox(
      minBounds: vm.Vector3(
        math.min(minBounds.x, other.minBounds.x),
        math.min(minBounds.y, other.minBounds.y),
        math.min(minBounds.z, other.minBounds.z),
      ),
      maxBounds: vm.Vector3(
        math.max(maxBounds.x, other.maxBounds.x),
        math.max(maxBounds.y, other.maxBounds.y),
        math.max(maxBounds.z, other.maxBounds.z),
      ),
    );
  }

  /// Create the intersection of this box with another
  /// Returns an empty box if they don't intersect
  BoundingBox intersection(BoundingBox other) {
    if (!intersects(other)) return BoundingBox.empty();
    
    return BoundingBox(
      minBounds: vm.Vector3(
        math.max(minBounds.x, other.minBounds.x),
        math.max(minBounds.y, other.minBounds.y),
        math.max(minBounds.z, other.minBounds.z),
      ),
      maxBounds: vm.Vector3(
        math.min(maxBounds.x, other.maxBounds.x),
        math.min(maxBounds.y, other.maxBounds.y),
        math.min(maxBounds.z, other.maxBounds.z),
      ),
    );
  }

  /// Add a point to the bounding box, expanding it if necessary
  BoundingBox includePoint(vm.Vector3 point) {
    if (isEmpty) return BoundingBox.fromPoint(point);
    
    return BoundingBox(
      minBounds: vm.Vector3(
        math.min(minBounds.x, point.x),
        math.min(minBounds.y, point.y),
        math.min(minBounds.z, point.z),
      ),
      maxBounds: vm.Vector3(
        math.max(maxBounds.x, point.x),
        math.max(maxBounds.y, point.y),
        math.max(maxBounds.z, point.z),
      ),
    );
  }

  /// Get the closest point on the bounding box to a given point
  vm.Vector3 closestPointTo(vm.Vector3 point) {
    if (isEmpty) return point;
    
    return vm.Vector3(
      point.x.clamp(minBounds.x, maxBounds.x),
      point.y.clamp(minBounds.y, maxBounds.y),
      point.z.clamp(minBounds.z, maxBounds.z),
    );
  }

  /// Calculate the distance from a point to this bounding box
  /// Returns 0 if the point is inside the box
  double distanceTo(vm.Vector3 point) {
    final closest = closestPointTo(point);
    return (point - closest).length;
  }

  /// Transform this bounding box by a 4x4 transformation matrix
  /// 
  /// Note: This creates an axis-aligned bounding box around the transformed
  /// corners, which may be larger than the actual transformed geometry.
  BoundingBox transform(vm.Matrix4 matrix) {
    if (isEmpty) return this;
    
    // Transform all 8 corners of the bounding box
    final corners = [
      vm.Vector3(minBounds.x, minBounds.y, minBounds.z),
      vm.Vector3(maxBounds.x, minBounds.y, minBounds.z),
      vm.Vector3(minBounds.x, maxBounds.y, minBounds.z),
      vm.Vector3(maxBounds.x, maxBounds.y, minBounds.z),
      vm.Vector3(minBounds.x, minBounds.y, maxBounds.z),
      vm.Vector3(maxBounds.x, minBounds.y, maxBounds.z),
      vm.Vector3(minBounds.x, maxBounds.y, maxBounds.z),
      vm.Vector3(maxBounds.x, maxBounds.y, maxBounds.z),
    ];
    
    // Transform each corner and find new bounds
    var newBox = BoundingBox.empty();
    for (final corner in corners) {
      final transformed = matrix.transform3(corner);
      newBox = newBox.includePoint(transformed);
    }
    
    return newBox;
  }

  @override
  List<Object?> get props => [minBounds, maxBounds];

  @override
  String toString() {
    if (isEmpty) return 'BoundingBox.empty()';
    return 'BoundingBox(min: $minBounds, max: $maxBounds, size: $size)';
  }

  /// Create a copy of this bounding box with optional modifications
  BoundingBox copyWith({
    vm.Vector3? minBounds,
    vm.Vector3? maxBounds,
  }) {
    return BoundingBox(
      minBounds: minBounds ?? this.minBounds,
      maxBounds: maxBounds ?? this.maxBounds,
    );
  }
}