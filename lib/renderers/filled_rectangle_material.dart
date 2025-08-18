/*
 * FilledRectangleMaterial implementation for Flutter Scene
 * 
 * Material for rendering filled rectangle interiors with transparency support
 * Based on UnlitMaterial for consistent lighting behavior
 */

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'transparent_material.dart';

class FilledRectangleMaterial extends TransparentMaterial {
  final Color _fillColor;
  final double _opacity;

  FilledRectangleMaterial({required Color fillColor, double opacity = 1.0})
    : _fillColor = fillColor,
      _opacity = opacity.clamp(0.0, 1.0) {
    // Set base color with opacity
    // Flutter Color properties are already normalized (0.0-1.0)
    baseColorFactor = vm.Vector4(
      _fillColor.r,
      _fillColor.g,
      _fillColor.b,
      _opacity,
    );
  }

  /// Get the fill color
  Color get fillColor => _fillColor;

  /// Get the opacity
  double get opacity => _opacity;

  /// Create a new material with different opacity
  FilledRectangleMaterial withOpacity(double newOpacity) {
    return FilledRectangleMaterial(fillColor: _fillColor, opacity: newOpacity);
  }

  /// Create a new material with different color
  FilledRectangleMaterial withColor(Color newColor) {
    return FilledRectangleMaterial(fillColor: newColor, opacity: _opacity);
  }

  @override
  bool isOpaque() {
    // Return false if we have any transparency
    // This ensures proper rendering order for semi-transparent rectangles
    return _opacity >= 1.0;
  }

  @override
  String toString() {
    return 'FilledRectangleMaterial(color: $_fillColor, opacity: $_opacity, isOpaque: ${isOpaque()})';
  }
}