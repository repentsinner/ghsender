/*
 * FilledSquareFactory for convenient creation of filled squares
 * 
 * Provides easy-to-use methods for creating common CNC visualization elements
 * like work area boundaries, safety zones, and coordinate indicators
 */

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'scene_manager.dart';

class FilledSquareFactory {
  /// Create a filled square in the XY plane
  static SceneObject createXYFilledSquare({
    required vm.Vector3 center,
    required double size,
    required Color fillColor,
    Color? edgeColor,
    double edgeWidth = 1.0,
    double opacity = 1.0,
    double rotation = 0.0,
    String? id,
  }) {
    return SceneObject(
      type: SceneObjectType.filledSquare,
      color: fillColor, // Base color for compatibility
      id: id ?? 'filled_square_xy_${DateTime.now().millisecondsSinceEpoch}',
      center: center,
      size: size,
      plane: SquarePlane.xy,
      rotation: rotation,
      fillColor: fillColor,
      edgeColor:
          edgeColor ??
          Color.fromARGB(
            255,
            (fillColor.r * 255).round(),
            (fillColor.g * 255).round(),
            (fillColor.b * 255).round(),
          ),
      edgeWidth: edgeWidth,
      opacity: opacity,
    );
  }

  /// Create a filled square in the XZ plane
  static SceneObject createXZFilledSquare({
    required vm.Vector3 center,
    required double size,
    required Color fillColor,
    Color? edgeColor,
    double edgeWidth = 1.0,
    double opacity = 1.0,
    double rotation = 0.0,
    String? id,
  }) {
    return SceneObject(
      type: SceneObjectType.filledSquare,
      color: fillColor, // Base color for compatibility
      id: id ?? 'filled_square_xz_${DateTime.now().millisecondsSinceEpoch}',
      center: center,
      size: size,
      plane: SquarePlane.xz,
      rotation: rotation,
      fillColor: fillColor,
      edgeColor:
          edgeColor ??
          Color.fromARGB(
            255,
            (fillColor.r * 255).round(),
            (fillColor.g * 255).round(),
            (fillColor.b * 255).round(),
          ),
      edgeWidth: edgeWidth,
      opacity: opacity,
    );
  }

  /// Create a filled square in the YZ plane
  static SceneObject createYZFilledSquare({
    required vm.Vector3 center,
    required double size,
    required Color fillColor,
    Color? edgeColor,
    double edgeWidth = 1.0,
    double opacity = 1.0,
    double rotation = 0.0,
    String? id,
  }) {
    return SceneObject(
      type: SceneObjectType.filledSquare,
      color: fillColor, // Base color for compatibility
      id: id ?? 'filled_square_yz_${DateTime.now().millisecondsSinceEpoch}',
      center: center,
      size: size,
      plane: SquarePlane.yz,
      rotation: rotation,
      fillColor: fillColor,
      edgeColor:
          edgeColor ??
          Color.fromARGB(
            255,
            (fillColor.r * 255).round(),
            (fillColor.g * 255).round(),
            (fillColor.b * 255).round(),
          ),
      edgeWidth: edgeWidth,
      opacity: opacity,
    );
  }

  /// Create a semi-transparent work area boundary (common CNC use case)
  static SceneObject createWorkAreaBoundary({
    required double width,
    required double height,
    vm.Vector3? center,
    Color fillColor = Colors.blue,
    Color? edgeColor,
    double opacity = 0.2,
    double edgeWidth = 2.0,
    String? id,
  }) {
    final actualCenter = center ?? vm.Vector3(width / 2, height / 2, 0);
    final size = math.max(width, height); // Use larger dimension for square

    return SceneObject(
      type: SceneObjectType.filledSquare,
      color: fillColor, // Base color for compatibility
      id: id ?? 'work_area_boundary',
      center: actualCenter,
      size: size,
      plane: SquarePlane.xy,
      fillColor: Color.fromARGB(
        (opacity * 255).round(),
        (fillColor.r * 255).round(),
        (fillColor.g * 255).round(),
        (fillColor.b * 255).round(),
      ),
      edgeColor: edgeColor ?? fillColor,
      edgeWidth: edgeWidth,
      opacity: opacity,
    );
  }

  /// Create a safety zone marker (semi-transparent red)
  static SceneObject createSafetyZone({
    required vm.Vector3 center,
    required double size,
    SquarePlane plane = SquarePlane.xy,
    double rotation = 0.0,
    String? id,
  }) {
    return SceneObject(
      type: SceneObjectType.filledSquare,
      color: Colors.red, // Base color for compatibility
      id: id ?? 'safety_zone_${center.hashCode}',
      center: center,
      size: size,
      plane: plane,
      rotation: rotation,
      fillColor: Color.fromARGB(
        76,
        (Colors.red.r * 255).round(),
        (Colors.red.g * 255).round(),
        (Colors.red.b * 255).round(),
      ), // 0.3 * 255 = 76
      edgeColor: Colors.red,
      edgeWidth: 1.5,
      opacity: 0.4,
    );
  }

  /// Create a coordinate system indicator
  static SceneObject createCoordinateIndicator({
    required vm.Vector3 origin,
    double size = 5.0,
    SquarePlane plane = SquarePlane.xy,
    Color color = Colors.green,
    String? id,
  }) {
    return SceneObject(
      type: SceneObjectType.filledSquare,
      color: color, // Base color for compatibility
      id: id ?? 'coordinate_indicator_${origin.hashCode}',
      center: origin,
      size: size,
      plane: plane,
      fillColor: Color.fromARGB(
        127,
        (color.r * 255).round(),
        (color.g * 255).round(),
        (color.b * 255).round(),
      ), // 0.5 * 255 = 127
      edgeColor: color,
      edgeWidth: 1.0,
      opacity: 0.7,
    );
  }

  /// Create a tool path boundary indicator
  static SceneObject createToolPathBoundary({
    required vm.Vector3 center,
    required double size,
    SquarePlane plane = SquarePlane.xy,
    Color color = Colors.yellow,
    String? id,
  }) {
    return SceneObject(
      type: SceneObjectType.filledSquare,
      color: color, // Base color for compatibility
      id: id ?? 'toolpath_boundary_${center.hashCode}',
      center: center,
      size: size,
      plane: plane,
      fillColor: Color.fromARGB(
        25,
        (color.r * 255).round(),
        (color.g * 255).round(),
        (color.b * 255).round(),
      ), // 0.1 * 255 = 25
      edgeColor: color,
      edgeWidth: 1.5,
      opacity: 0.2,
    );
  }

  /// Create multiple squares for a grid pattern
  static List<SceneObject> createGrid({
    required vm.Vector3 origin,
    required int countX,
    required int countY,
    required double spacing,
    required double squareSize,
    SquarePlane plane = SquarePlane.xy,
    Color fillColor = Colors.grey,
    Color? edgeColor,
    double opacity = 0.3,
    double edgeWidth = 0.5,
  }) {
    final squares = <SceneObject>[];

    for (int x = 0; x < countX; x++) {
      for (int y = 0; y < countY; y++) {
        final center = _calculateGridPosition(origin, x, y, spacing, plane);

        squares.add(
          SceneObject(
            type: SceneObjectType.filledSquare,
            color: fillColor, // Base color for compatibility
            id: 'grid_square_${x}_$y',
            center: center,
            size: squareSize,
            plane: plane,
            fillColor: Color.fromARGB(
              (opacity * 255).round(),
              (fillColor.r * 255).round(),
              (fillColor.g * 255).round(),
              (fillColor.b * 255).round(),
            ),
            edgeColor: edgeColor ?? fillColor,
            edgeWidth: edgeWidth,
            opacity: opacity,
          ),
        );
      }
    }

    return squares;
  }

  /// Calculate grid position based on plane
  static vm.Vector3 _calculateGridPosition(
    vm.Vector3 origin,
    int x,
    int y,
    double spacing,
    SquarePlane plane,
  ) {
    final offsetX = x * spacing;
    final offsetY = y * spacing;

    switch (plane) {
      case SquarePlane.xy:
        return origin + vm.Vector3(offsetX, offsetY, 0);
      case SquarePlane.xz:
        return origin + vm.Vector3(offsetX, 0, offsetY);
      case SquarePlane.yz:
        return origin + vm.Vector3(0, offsetX, offsetY);
    }
  }
}
