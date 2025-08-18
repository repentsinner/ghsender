/*
 * FilledRectangleRenderer implementation for Flutter Scene
 * 
 * Hybrid renderer that combines filled geometry with line edges
 * Creates both fill mesh and edge lines for complete rectangle rendering
 */

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:flutter_scene/scene.dart';
import '../scene/scene_manager.dart';
import 'filled_rectangle_geometry.dart';
import 'filled_rectangle_material.dart';
import 'line_mesh_factory.dart';
import '../utils/logger.dart';

/// Result of filled rectangle creation with both fill and edge meshes
class FilledRectangleResult {
  final Mesh fillMesh;
  final Mesh edgeMesh;
  final String id;

  const FilledRectangleResult({
    required this.fillMesh,
    required this.edgeMesh,
    required this.id,
  });

  /// Get both meshes as scene nodes with proper rendering order
  /// Returns fill first, then edges (edges render after fills for proper depth ordering)
  List<Node> toNodes() {
    final fillNode = Node()..mesh = fillMesh;
    final edgeNode = Node()..mesh = edgeMesh;
    return [fillNode, edgeNode]; // Fill renders first, edges render on top
  }
}

class FilledRectangleRenderer {
  /// Create both fill and edge meshes for a filled rectangle
  static FilledRectangleResult createFilledRectangle({
    required vm.Vector3 center,
    required double width,
    required double height,
    required RectanglePlane plane,
    double rotation = 0.0,
    required Color fillColor,
    required Color edgeColor,
    double edgeWidth = 1.0,
    double opacity = 1.0,
    vm.Vector2? resolution,
    String? id,
  }) {
    try {
      final rectangleId =
          id ?? 'filled_rectangle_${DateTime.now().millisecondsSinceEpoch}';

      // Create filled interior mesh
      final fillGeometry = FilledRectangleGeometry(
        center: center,
        width: width,
        height: height,
        plane: plane,
        rotation: rotation,
      );

      final fillMaterial = FilledRectangleMaterial(
        fillColor: fillColor,
        opacity: opacity,
      );

      final fillMesh = Mesh.primitives(
        primitives: [MeshPrimitive(fillGeometry, fillMaterial)],
      );

      // Create edge outline using existing line renderer
      final corners = _calculateRectangleCorners(center, width, height, plane, rotation);
      final edgeLines = LineMeshFactory.createPolyline(
        [
          ...corners,
          corners[0],
        ], // Close the loop by adding first corner at end
        lineWidth: edgeWidth,
        color: edgeColor,
        opacity: 1.0, // Edges always opaque for clarity
        resolution: resolution,
      );

      return FilledRectangleResult(
        fillMesh: fillMesh,
        edgeMesh: edgeLines,
        id: rectangleId,
      );
    } catch (e) {
      AppLogger.error('Failed to create filled rectangle: $e');
      rethrow;
    }
  }

  /// Calculate rectangle corner points
  static List<vm.Vector3> _calculateRectangleCorners(
    vm.Vector3 center,
    double width,
    double height,
    RectanglePlane plane,
    double rotation,
  ) {
    final halfWidth = width * 0.5;
    final halfHeight = height * 0.5;

    // Base corner offsets in 2D (before rotation)
    final baseOffsets = [
      vm.Vector2(-halfWidth, -halfHeight), // Bottom-left
      vm.Vector2(halfWidth, -halfHeight), // Bottom-right
      vm.Vector2(halfWidth, halfHeight), // Top-right
      vm.Vector2(-halfWidth, halfHeight), // Top-left
    ];

    // Apply rotation if specified
    final rotatedOffsets = baseOffsets.map((offset) {
      if (rotation != 0.0) {
        final cos = math.cos(rotation);
        final sin = math.sin(rotation);
        return vm.Vector2(
          offset.x * cos - offset.y * sin,
          offset.x * sin + offset.y * cos,
        );
      }
      return offset;
    }).toList();

    // Convert to 3D points based on plane
    return rotatedOffsets.map((offset) {
      switch (plane) {
        case RectanglePlane.xy:
          return center + vm.Vector3(offset.x, offset.y, 0.0);
        case RectanglePlane.xz:
          return center + vm.Vector3(offset.x, 0.0, offset.y);
        case RectanglePlane.yz:
          return center + vm.Vector3(0.0, offset.x, offset.y);
      }
    }).toList();
  }

  /// Create a filled rectangle from a SceneObject
  static FilledRectangleResult createFromSceneObject(
    SceneObject rectangle, {
    vm.Vector2? resolution,
  }) {
    if (rectangle.type != SceneObjectType.filledRectangle) {
      throw ArgumentError('SceneObject must be of type filledRectangle');
    }

    return createFilledRectangle(
      center: rectangle.center!,
      width: rectangle.width!,
      height: rectangle.height!,
      plane: rectangle.plane!,
      rotation: rectangle.rotation ?? 0.0,
      fillColor: rectangle.fillColor ?? rectangle.color,
      edgeColor: rectangle.edgeColor ?? rectangle.color,
      edgeWidth: rectangle.edgeWidth ?? 1.0,
      opacity: rectangle.opacity ?? 1.0,
      resolution: resolution,
      id: rectangle.id,
    );
  }
}