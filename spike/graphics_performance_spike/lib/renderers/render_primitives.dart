import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// Primitive geometry types that renderers can implement
abstract class RenderPrimitive {
  void render();
}

/// A 3D cube primitive
class CubePrimitive extends RenderPrimitive {
  final vm.Vector3 position;
  final vm.Vector3 scale; 
  final vm.Quaternion rotation;
  final Color color;
  final String id;
  
  CubePrimitive({
    required this.position,
    required this.scale,
    required this.rotation,
    required this.color,
    required this.id,
  });
  
  vm.Matrix4 get transformMatrix {
    return vm.Matrix4.compose(position, rotation, scale);
  }
  
  @override
  void render() {
    // Individual renderers will implement this
  }
}

/// A 3D line primitive (for axes)
class LinePrimitive extends RenderPrimitive {
  final vm.Vector3 start;
  final vm.Vector3 end;
  final Color color;
  final double thickness;
  final String id;
  
  LinePrimitive({
    required this.start,
    required this.end,
    required this.color,
    required this.thickness,
    required this.id,
  });
  
  /// Get the position (midpoint of line)
  vm.Vector3 get position => (start + end) * 0.5;
  
  /// Get the scale (length along appropriate axis, thickness on others)  
  vm.Vector3 get scale {
    final direction = end - start;
    final length = direction.length;
    
    // Determine primary axis
    final absDirection = vm.Vector3(direction.x.abs(), direction.y.abs(), direction.z.abs());
    
    if (absDirection.x >= absDirection.y && absDirection.x >= absDirection.z) {
      // X-axis dominant
      return vm.Vector3(length, thickness, thickness);
    } else if (absDirection.y >= absDirection.x && absDirection.y >= absDirection.z) {
      // Y-axis dominant  
      return vm.Vector3(thickness, length, thickness);
    } else {
      // Z-axis dominant
      return vm.Vector3(thickness, thickness, length);
    }
  }
  
  @override
  void render() {
    // Individual renderers will implement this
  }
}

/// Factory to create primitives from scene objects
class PrimitiveFactory {
  static List<RenderPrimitive> createFromSceneObjects(List<dynamic> sceneObjects) {
    // This will be implemented as we convert the scene objects
    return [];
  }
}