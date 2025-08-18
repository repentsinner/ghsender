/*
 * FilledRectangleFactory for convenient creation of filled rectangles
 * 
 * Provides easy-to-use methods for creating common CNC visualization elements
 * like work area boundaries, safety zones, and coordinate indicators
 */

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'scene_manager.dart';

class FilledRectangleFactory {
  /// Create a filled rectangle in the XY plane
  static SceneObject createXYFilledRectangle({
    required vm.Vector3 center,
    required double width,
    required double height,
    required Color fillColor,
    Color? edgeColor,
    double edgeWidth = 1.0,
    double opacity = 1.0,
    double rotation = 0.0,
    String? id,
  }) {
    return SceneObject(
      type: SceneObjectType.filledRectangle,
      color: fillColor, // Base color for compatibility
      id: id ?? 'filled_rectangle_xy_${DateTime.now().millisecondsSinceEpoch}',
      center: center,
      width: width,
      height: height,
      plane: RectanglePlane.xy,
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

  /// Create a filled rectangle in the XZ plane
  static SceneObject createXZFilledRectangle({
    required vm.Vector3 center,
    required double width,
    required double height,
    required Color fillColor,
    Color? edgeColor,
    double edgeWidth = 1.0,
    double opacity = 1.0,
    double rotation = 0.0,
    String? id,
  }) {
    return SceneObject(
      type: SceneObjectType.filledRectangle,
      color: fillColor, // Base color for compatibility
      id: id ?? 'filled_rectangle_xz_${DateTime.now().millisecondsSinceEpoch}',
      center: center,
      width: width,
      height: height,
      plane: RectanglePlane.xz,
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

  /// Create a filled rectangle in the YZ plane
  static SceneObject createYZFilledRectangle({
    required vm.Vector3 center,
    required double width,
    required double height,
    required Color fillColor,
    Color? edgeColor,
    double edgeWidth = 1.0,
    double opacity = 1.0,
    double rotation = 0.0,
    String? id,
  }) {
    return SceneObject(
      type: SceneObjectType.filledRectangle,
      color: fillColor, // Base color for compatibility
      id: id ?? 'filled_rectangle_yz_${DateTime.now().millisecondsSinceEpoch}',
      center: center,
      width: width,
      height: height,
      plane: RectanglePlane.yz,
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

    return SceneObject(
      type: SceneObjectType.filledRectangle,
      color: fillColor, // Base color for compatibility
      id: id ?? 'work_area_boundary',
      center: actualCenter,
      width: width,
      height: height,
      plane: RectanglePlane.xy,
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
    required double width,
    required double height,
    RectanglePlane plane = RectanglePlane.xy,
    double rotation = 0.0,
    String? id,
  }) {
    return SceneObject(
      type: SceneObjectType.filledRectangle,
      color: Colors.red, // Base color for compatibility
      id: id ?? 'safety_zone_${center.hashCode}',
      center: center,
      width: width,
      height: height,
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
    double width = 5.0,
    double height = 5.0,
    RectanglePlane plane = RectanglePlane.xy,
    Color color = Colors.green,
    String? id,
  }) {
    return SceneObject(
      type: SceneObjectType.filledRectangle,
      color: color, // Base color for compatibility
      id: id ?? 'coordinate_indicator_${origin.hashCode}',
      center: origin,
      width: width,
      height: height,
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
    required double width,
    required double height,
    RectanglePlane plane = RectanglePlane.xy,
    Color color = Colors.yellow,
    String? id,
  }) {
    return SceneObject(
      type: SceneObjectType.filledRectangle,
      color: color, // Base color for compatibility
      id: id ?? 'toolpath_boundary_${center.hashCode}',
      center: center,
      width: width,
      height: height,
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

  /// Create multiple rectangles for a grid pattern
  static List<SceneObject> createGrid({
    required vm.Vector3 origin,
    required int countX,
    required int countY,
    required double spacing,
    required double rectangleWidth,
    required double rectangleHeight,
    RectanglePlane plane = RectanglePlane.xy,
    Color fillColor = Colors.grey,
    Color? edgeColor,
    double opacity = 0.3,
    double edgeWidth = 0.5,
  }) {
    final rectangles = <SceneObject>[];

    for (int x = 0; x < countX; x++) {
      for (int y = 0; y < countY; y++) {
        final center = _calculateGridPosition(origin, x, y, spacing, plane);

        rectangles.add(
          SceneObject(
            type: SceneObjectType.filledRectangle,
            color: fillColor, // Base color for compatibility
            id: 'grid_rectangle_${x}_$y',
            center: center,
            width: rectangleWidth,
            height: rectangleHeight,
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

    return rectangles;
  }

  /// Calculate grid position based on plane
  static vm.Vector3 _calculateGridPosition(
    vm.Vector3 origin,
    int x,
    int y,
    double spacing,
    RectanglePlane plane,
  ) {
    final offsetX = x * spacing;
    final offsetY = y * spacing;

    switch (plane) {
      case RectanglePlane.xy:
        return origin + vm.Vector3(offsetX, offsetY, 0);
      case RectanglePlane.xz:
        return origin + vm.Vector3(offsetX, 0, offsetY);
      case RectanglePlane.yz:
        return origin + vm.Vector3(0, offsetX, offsetY);
    }
  }
}