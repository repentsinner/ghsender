/*
 * Line Mesh Factory for Flutter Scene
 * 
 * Factory class providing convenient creation of Line2/LineSegments2 meshes
 * with Three.js-compatible anti-aliased line rendering
 */

import 'dart:math' as math;
import 'package:flutter/material.dart' as flutter;
import 'package:vector_math/vector_math.dart' as vm;
import 'package:flutter_scene/scene.dart';
import '../scene/scene_manager.dart';
import 'line_geometry.dart';
import 'line_material.dart';

/// Result of line mesh creation with actual tessellation metrics
class LineMeshResult {
  final List<Node> nodes;
  final int actualTriangles;
  final int actualVertices;
  final int lineSegments;

  const LineMeshResult({
    required this.nodes,
    required this.actualTriangles,
    required this.actualVertices,
    required this.lineSegments,
  });
}

class LineMeshFactory {
  /// Create a Line2 (continuous polyline) mesh from a list of points
  ///
  /// Example: Create a continuous path for G-code toolpath visualization
  /// ```dart
  /// final toolpath = LineMeshFactory.createPolyline([
  ///   vm.Vector3(0, 0, 0),
  ///   vm.Vector3(10, 0, 0),
  ///   vm.Vector3(10, 10, 0),
  ///   vm.Vector3(0, 10, 0),
  /// ], lineWidth: 2.0, color: Colors.blue);
  /// ```
  static Mesh createPolyline(
    List<vm.Vector3> points, {
    double lineWidth = 1.0,
    flutter.Color color = flutter.Colors.white,
    double opacity = 1.0,
    double sharpness = 0.5,
    vm.Vector2? resolution,
  }) {
    final actualResolution = resolution ?? vm.Vector2(1024, 768);
    final geometry = LineGeometry.polyline(
      points,
      resolution: actualResolution,
      lineWidth: lineWidth,
    );
    final material = LineMaterial(
      lineWidth: lineWidth,
      color: color,
      opacity: opacity,
      sharpness: sharpness,
      resolution: actualResolution,
    );
    return Mesh.primitives(primitives: [MeshPrimitive(geometry, material)]);
  }

  /// Create a LineSegments2 (discrete segments) mesh from point pairs
  ///
  /// Example: Create grid lines or wireframe visualization
  /// ```dart
  /// final gridLines = LineMeshFactory.createSegments([
  ///   // Horizontal lines
  ///   vm.Vector3(0, 0, 0), vm.Vector3(100, 0, 0),
  ///   vm.Vector3(0, 10, 0), vm.Vector3(100, 10, 0),
  ///   // Vertical lines
  ///   vm.Vector3(0, 0, 0), vm.Vector3(0, 100, 0),
  ///   vm.Vector3(10, 0, 0), vm.Vector3(10, 100, 0),
  /// ], lineWidth: 1.0, color: Colors.grey);
  /// ```
  static Mesh createSegments(
    List<vm.Vector3> points, {
    double lineWidth = 1.0,
    flutter.Color color = flutter.Colors.white,
    double opacity = 1.0,
    double sharpness = 0.5,
    vm.Vector2? resolution,
  }) {
    final actualResolution = resolution ?? vm.Vector2(1024, 768);
    final geometry = LineGeometry.segments(
      points,
      resolution: actualResolution,
      lineWidth: lineWidth,
    );
    final material = LineMaterial(
      lineWidth: lineWidth,
      color: color,
      opacity: opacity,
      sharpness: sharpness,
      resolution: actualResolution,
    );
    return Mesh.primitives(primitives: [MeshPrimitive(geometry, material)]);
  }

  /// Convert SceneManager line objects to Line2/LineSegments2 meshes
  ///
  /// Integrates with existing scene data structure for performance testing.
  /// Uses Three.js approach: groups consecutive line objects into polylines (Line2)
  /// while keeping separate segments as discrete LineSegments2.
  /// Returns both the nodes and actual tessellation metrics
  static LineMeshResult createLinesFromSceneData(
    SceneData sceneData, {
    double lineWidth = 1.0,
    flutter.Color? defaultColor,
    double opacity = 1.0,
    double sharpness = 0.5,
    bool enablePolylineGrouping = true,
    vm.Vector2? resolution,
  }) {
    final nodes = <Node>[];
    int totalTriangles = 0;
    int totalVertices = 0;
    int lineSegments = 0;

    // Extract line objects from scene data
    final lineObjects = sceneData.objects
        .where((obj) => obj.type == SceneObjectType.line)
        .toList();

    if (lineObjects.isEmpty) {
      return LineMeshResult(
        nodes: nodes,
        actualTriangles: 0,
        actualVertices: 0,
        lineSegments: 0,
      );
    }

    if (enablePolylineGrouping) {
      // Group consecutive line segments into polylines (Three.js Line2 approach)
      final lineGroups = _groupConsecutiveLines(lineObjects);

      for (final group in lineGroups) {
        if (group.length == 1) {
          // Single line segment - use LineSegments2 approach
          final lineObj = group.first;
          if (lineObj.startPoint != null && lineObj.endPoint != null) {
            final points = [lineObj.startPoint!, lineObj.endPoint!];

            final color = defaultColor ?? lineObj.color;
            final thickness = lineObj.thickness ?? lineWidth; // Use object thickness or fallback

            // Use segments for discrete line segments (LineSegments2 equivalent)
            final mesh = createSegments(
              points,
              lineWidth: thickness,
              color: color,
              opacity: opacity,
              sharpness: sharpness,
              resolution: resolution,
            );

            final node = Node();
            node.mesh = mesh;
            nodes.add(node);

            // Track actual tessellation metrics:
            // Each line segment creates 4 vertices (quad) and 2 triangles
            totalVertices += 4;
            totalTriangles += 2;
            lineSegments += 1;
          }
        } else {
          // Multiple connected segments - use Line2 polyline approach
          final polylinePoints = <vm.Vector3>[];

          // Build continuous point sequence like Three.js LineGeometry.setPositions()
          for (int i = 0; i < group.length; i++) {
            final lineObj = group[i];
            if (lineObj.startPoint != null && lineObj.endPoint != null) {
              if (i == 0) {
                // First segment: add both start and end points
                polylinePoints.add(lineObj.startPoint!);
              }
              // Add end point (start point should match previous end point)
              polylinePoints.add(lineObj.endPoint!);
            }
          }

          if (polylinePoints.length >= 2) {
            final color = defaultColor ?? group.first.color;
            final thickness = group.first.thickness ?? lineWidth; // Use group thickness or fallback

            // Use polyline for continuous line segments (Line2 equivalent)
            final mesh = createPolyline(
              polylinePoints,
              lineWidth: thickness,
              color: color,
              opacity: opacity,
              sharpness: sharpness,
              resolution: resolution,
            );

            final node = Node();
            node.mesh = mesh;
            nodes.add(node);

            // Track actual tessellation metrics:
            // Polyline with N points creates (N-1) segments * 4 vertices/segment * 2 triangles/segment
            final segments = polylinePoints.length - 1;
            totalVertices += segments * 4;
            totalTriangles += segments * 2;
            lineSegments += segments;
          }
        }
      }
    } else {
      // Fallback: treat each line object as separate segment (original approach)
      for (final lineObj in lineObjects) {
        // Use the startPoint and endPoint fields directly
        if (lineObj.startPoint != null && lineObj.endPoint != null) {
          final points = [lineObj.startPoint!, lineObj.endPoint!];

          final color = defaultColor ?? lineObj.color;
          final thickness = lineObj.thickness ?? lineWidth; // Use object thickness or fallback

          // Use segments for discrete line segments (LineSegments2 equivalent)
          final mesh = createSegments(
            points,
            lineWidth: thickness,
            color: color,
            opacity: opacity,
            sharpness: sharpness,
            resolution: resolution,
          );

          final node = Node();
          node.mesh = mesh;
          nodes.add(node);

          // Track actual tessellation metrics:
          // Each line segment creates 4 vertices (quad) and 2 triangles
          totalVertices += 4;
          totalTriangles += 2;
          lineSegments += 1;
        }
      }
    }

    return LineMeshResult(
      nodes: nodes,
      actualTriangles: totalTriangles,
      actualVertices: totalVertices,
      lineSegments: lineSegments,
    );
  }

  /// Group consecutive line objects into polylines for efficiency (Three.js Line2 approach)
  ///
  /// Based on Three.js Line2 approach: connects consecutive points into continuous polylines
  /// by detecting when the end point of one line matches the start point of the next.
  /// This mimics how Three.js LineGeometry.setPositions() creates overlapping point pairs.
  static List<List<SceneObject>> _groupConsecutiveLines(
    List<SceneObject> lineObjects,
  ) {
    if (lineObjects.isEmpty) return [];

    final groups = <List<SceneObject>>[];
    var currentGroup = <SceneObject>[lineObjects.first];

    // Tolerance for endpoint matching (similar to Three.js floating point comparisons)
    const tolerance = 1e-6;

    for (int i = 1; i < lineObjects.length; i++) {
      final currentLine = lineObjects[i];
      final lastInGroup = currentGroup.last;

      // Check if current line's start connects to the last line's end
      // This mimics Three.js Line2 continuous polyline behavior
      if (lastInGroup.endPoint != null && currentLine.startPoint != null) {
        final lastEnd = lastInGroup.endPoint!;
        final currentStart = currentLine.startPoint!;

        final distance = _calculateDistance(lastEnd, currentStart);

        // Only group lines if they are consecutive AND have the same color AND thickness
        // This prevents mixing rapids (thin) with cutting moves (thick)
        if (distance < tolerance && 
            lastInGroup.color == currentLine.color &&
            lastInGroup.thickness == currentLine.thickness) {
          // Lines are consecutive with same color - add to current group
          currentGroup.add(currentLine);
        } else {
          // Gap detected or color changed - start new group
          groups.add(currentGroup);
          currentGroup = [currentLine];
        }
      } else {
        // Missing startPoint/endPoint - treat as separate segment
        groups.add(currentGroup);
        currentGroup = [currentLine];
      }
    }

    // Add the final group
    if (currentGroup.isNotEmpty) {
      groups.add(currentGroup);
    }

    return groups;
  }

  /// Calculate 3D distance between two points (for consecutive line detection)
  static double _calculateDistance(vm.Vector3 point1, vm.Vector3 point2) {
    final dx = point1.x - point2.x;
    final dy = point1.y - point2.y;
    final dz = point1.z - point2.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  /// Update line material resolution for viewport changes
  static void updateResolution(Mesh lineMesh, double width, double height) {
    final material = lineMesh.primitives.first.material;
    if (material is LineMaterial) {
      material.updateResolution(width, height);
    }
    // For other material types, resolution update is not supported
  }
}
