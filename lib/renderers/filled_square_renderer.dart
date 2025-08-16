/*
 * FilledSquareRenderer implementation for Flutter Scene
 * 
 * Hybrid renderer that combines filled geometry with line edges
 * Creates both fill mesh and edge lines for complete square rendering
 */

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:flutter_scene/scene.dart';
import '../scene/scene_manager.dart';
import 'filled_square_geometry.dart';
import 'filled_square_material.dart';
import 'line_mesh_factory.dart';
import '../utils/logger.dart';

/// Result of filled square creation with both fill and edge meshes
class FilledSquareResult {
  final Mesh fillMesh;
  final Mesh edgeMesh;
  final String id;

  const FilledSquareResult({
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

class FilledSquareRenderer {
  /// Create both fill and edge meshes for a filled square
  static FilledSquareResult createFilledSquare({
    required vm.Vector3 center,
    required double size,
    required SquarePlane plane,
    double rotation = 0.0,
    required Color fillColor,
    required Color edgeColor,
    double edgeWidth = 1.0,
    double opacity = 1.0,
    vm.Vector2? resolution,
    String? id,
  }) {
    try {
      final squareId =
          id ?? 'filled_square_${DateTime.now().millisecondsSinceEpoch}';

      AppLogger.info(
        'Creating filled square: id=$squareId, center=$center, size=$size, plane=$plane',
      );

      // Create filled interior mesh
      final fillGeometry = FilledSquareGeometry(
        center: center,
        size: size,
        plane: plane,
        rotation: rotation,
      );

      final fillMaterial = FilledSquareMaterial(
        fillColor: fillColor,
        opacity: opacity,
      );

      final fillMesh = Mesh.primitives(
        primitives: [MeshPrimitive(fillGeometry, fillMaterial)],
      );

      // Create edge outline using existing line renderer
      final corners = _calculateSquareCorners(center, size, plane, rotation);
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

      AppLogger.info('Filled square created successfully: $squareId');

      return FilledSquareResult(
        fillMesh: fillMesh,
        edgeMesh: edgeLines,
        id: squareId,
      );
    } catch (e) {
      AppLogger.error('Failed to create filled square: $e');
      rethrow;
    }
  }

  /// Calculate square corner points (shared with geometry)
  static List<vm.Vector3> _calculateSquareCorners(
    vm.Vector3 center,
    double size,
    SquarePlane plane,
    double rotation,
  ) {
    final halfSize = size * 0.5;

    // Base corner offsets in 2D (before rotation)
    final baseOffsets = [
      vm.Vector2(-halfSize, -halfSize), // Bottom-left
      vm.Vector2(halfSize, -halfSize), // Bottom-right
      vm.Vector2(halfSize, halfSize), // Top-right
      vm.Vector2(-halfSize, halfSize), // Top-left
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
        case SquarePlane.xy:
          return center + vm.Vector3(offset.x, offset.y, 0.0);
        case SquarePlane.xz:
          return center + vm.Vector3(offset.x, 0.0, offset.y);
        case SquarePlane.yz:
          return center + vm.Vector3(0.0, offset.x, offset.y);
      }
    }).toList();
  }

  /// Create a filled square from a SceneObject
  static FilledSquareResult createFromSceneObject(
    SceneObject square, {
    vm.Vector2? resolution,
  }) {
    if (square.type != SceneObjectType.filledSquare) {
      throw ArgumentError('SceneObject must be of type filledSquare');
    }

    return createFilledSquare(
      center: square.center!,
      size: square.size!,
      plane: square.plane!,
      rotation: square.rotation ?? 0.0,
      fillColor: square.fillColor ?? square.color,
      edgeColor: square.edgeColor ?? square.color,
      edgeWidth: square.edgeWidth ?? 1.0,
      opacity: square.opacity ?? 1.0,
      resolution: resolution,
      id: square.id,
    );
  }
}
