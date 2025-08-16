/*
 * AxesFactory for convenient creation of coordinate axes
 * 
 * Provides parameterized methods for creating coordinate axes at different origins
 * with customizable colors, labels, and styling for CNC visualization
 */

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'scene_manager.dart';

/// Color mode for coordinate axes rendering
enum AxesColorMode {
  /// Full color: X=red, Y=green, Z=blue (standard CNC colors)
  fullColor,
  
  /// Grayscale: All axes in shades of gray
  grayscale,
  
  /// Custom colors: User-defined colors for each axis
  custom,
}

/// Configuration for coordinate axes appearance
class AxesConfiguration {
  final vm.Vector3 origin;
  final double length;
  final bool showLabels;
  final TextStyle labelStyle;
  final AxesColorMode colorMode;
  final Map<String, Color>? customColors;
  final String idPrefix;
  final double labelOffset;
  final double labelSize;

  const AxesConfiguration({
    required this.origin,
    this.length = 50.0,
    this.showLabels = true,
    this.labelStyle = const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    this.colorMode = AxesColorMode.fullColor,
    this.customColors,
    this.idPrefix = 'axes',
    this.labelOffset = 5.0,
    this.labelSize = 8.0,
  });
}

class AxesFactory {
  /// Create coordinate axes at world origin (machine origin)
  /// Uses standard CNC colors: X=red, Y=green, Z=blue
  static List<SceneObject> createWorldAxes({
    double length = 50.0,
    bool showLabels = true,
    TextStyle? labelStyle,
    AxesColorMode colorMode = AxesColorMode.fullColor,
  }) {
    final config = AxesConfiguration(
      origin: vm.Vector3.zero(),
      length: length,
      showLabels: showLabels,
      labelStyle: labelStyle ?? const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      colorMode: colorMode,
      idPrefix: 'world_axis',
    );

    return createCustomAxes(config);
  }

  /// Create coordinate axes at workpiece origin
  /// Typically offset from world origin based on workpiece setup
  static List<SceneObject> createWorkpieceAxes({
    required vm.Vector3 workpieceOrigin,
    double length = 30.0,
    bool showLabels = true,
    TextStyle? labelStyle,
    AxesColorMode colorMode = AxesColorMode.grayscale,
  }) {
    final config = AxesConfiguration(
      origin: workpieceOrigin,
      length: length,
      showLabels: showLabels,
      labelStyle: labelStyle ?? const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: Colors.white70,
      ),
      colorMode: colorMode,
      idPrefix: 'workpiece_axis',
    );

    return createCustomAxes(config);
  }

  /// Create fully customized coordinate axes
  static List<SceneObject> createCustomAxes(AxesConfiguration config) {
    final axes = <SceneObject>[];

    // Get colors for each axis based on color mode
    final colors = _getAxisColors(config.colorMode, config.customColors);

    // Create X-axis (positive X moves tool to the right of operator)
    axes.add(
      SceneObject(
        type: SceneObjectType.line,
        startPoint: config.origin,
        endPoint: config.origin + vm.Vector3(config.length, 0.0, 0.0),
        color: colors['x']!,
        id: '${config.idPrefix}_x',
      ),
    );

    // Create Y-axis (positive Y moves tool away from operator, toward back of machine)
    axes.add(
      SceneObject(
        type: SceneObjectType.line,
        startPoint: config.origin,
        endPoint: config.origin + vm.Vector3(0.0, config.length, 0.0),
        color: colors['y']!,
        id: '${config.idPrefix}_y',
      ),
    );

    // Create Z-axis (positive Z moves tool up, away from workpiece)
    axes.add(
      SceneObject(
        type: SceneObjectType.line,
        startPoint: config.origin,
        endPoint: config.origin + vm.Vector3(0.0, 0.0, config.length),
        color: colors['z']!,
        id: '${config.idPrefix}_z',
      ),
    );

    // Add labels if requested
    if (config.showLabels) {
      axes.addAll(_createAxisLabels(config, colors));
    }

    return axes;
  }

  /// Create axis labels with specified configuration
  static List<SceneObject> _createAxisLabels(
    AxesConfiguration config,
    Map<String, Color> colors,
  ) {
    return [
      // X-axis label
      SceneObject(
        type: SceneObjectType.textBillboard,
        color: colors['x']!,
        id: '${config.idPrefix}_label_x',
        center: config.origin + vm.Vector3(config.length + config.labelOffset, 0, 0),
        text: 'X',
        textStyle: config.labelStyle.copyWith(color: colors['x']),
        worldSize: config.labelSize,
        textBackgroundColor: Colors.transparent,
      ),
      // Y-axis label  
      SceneObject(
        type: SceneObjectType.textBillboard,
        color: colors['y']!,
        id: '${config.idPrefix}_label_y',
        center: config.origin + vm.Vector3(0, config.length + config.labelOffset, 0),
        text: 'Y',
        textStyle: config.labelStyle.copyWith(color: colors['y']),
        worldSize: config.labelSize,
        textBackgroundColor: Colors.transparent,
      ),
      // Z-axis label
      SceneObject(
        type: SceneObjectType.textBillboard,
        color: colors['z']!,
        id: '${config.idPrefix}_label_z',
        center: config.origin + vm.Vector3(0, 0, config.length + config.labelOffset),
        text: 'Z',
        textStyle: config.labelStyle.copyWith(color: colors['z']),
        worldSize: config.labelSize,
        textBackgroundColor: Colors.transparent,
      ),
    ];
  }

  /// Get colors for axes based on color mode
  static Map<String, Color> _getAxisColors(
    AxesColorMode colorMode,
    Map<String, Color>? customColors,
  ) {
    switch (colorMode) {
      case AxesColorMode.fullColor:
        return {
          'x': Colors.red,     // Standard CNC X-axis color
          'y': Colors.green,   // Standard CNC Y-axis color  
          'z': Colors.blue,    // Standard CNC Z-axis color
        };

      case AxesColorMode.grayscale:
        return {
          'x': Colors.grey[400]!,  // Light gray for X
          'y': Colors.grey[600]!,  // Medium gray for Y
          'z': Colors.grey[800]!,  // Dark gray for Z
        };

      case AxesColorMode.custom:
        if (customColors == null || 
            !customColors.containsKey('x') ||
            !customColors.containsKey('y') ||
            !customColors.containsKey('z')) {
          throw ArgumentError(
            'Custom color mode requires colors for x, y, and z axes',
          );
        }
        return Map<String, Color>.from(customColors);
    }
  }
}