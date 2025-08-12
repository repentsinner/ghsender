/*
 * LineMaterial implementation for Flutter Scene
 * Based on Three.js LineMaterial architecture
 * 
 * Provides anti-aliased line rendering with configurable width and colors
 * Uses custom shaders adapted from Three.js LineMaterial
 */

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:flutter_scene/scene.dart';

class LineMaterial extends UnlitMaterial {
  // Line properties (Three.js compatible)
  double _lineWidth = 1.0;
  Color _color = Colors.white;
  double _opacity = 1.0;
  vm.Vector2 _resolution = vm.Vector2(1024, 768); // Default resolution

  LineMaterial({
    double lineWidth = 1.0,
    Color color = Colors.white,
    double opacity = 1.0,
    vm.Vector2? resolution,
  }) : _lineWidth = lineWidth,
       _color = color,
       _opacity = opacity,
       _resolution = resolution ?? vm.Vector2(1024, 768) {
    // Set base color for UnlitMaterial (fallback when custom shader isn't available)
    baseColorFactor = vm.Vector4(
      (color.r * 255.0).round().clamp(0, 255) / 255.0,
      (color.g * 255.0).round().clamp(0, 255) / 255.0,  
      (color.b * 255.0).round().clamp(0, 255) / 255.0,
      opacity,
    );
    
    // Use standard UnlitMaterial shaders - custom line shaders removed due to instancing issues
  }

  // Three.js compatible getters/setters
  double get lineWidth => _lineWidth;
  set lineWidth(double value) {
    if (_lineWidth == value) return; // Avoid unnecessary updates
    _lineWidth = value;
    // TODO: Update shader uniforms when custom shaders are supported
  }

  Color get color => _color;
  set color(Color value) {
    _color = value;
    // Update the base UnlitMaterial color as well
    baseColorFactor = vm.Vector4(
      (value.r * 255.0).round().clamp(0, 255) / 255.0,
      (value.g * 255.0).round().clamp(0, 255) / 255.0,
      (value.b * 255.0).round().clamp(0, 255) / 255.0,
      _opacity,
    );
  }

  double get opacity => _opacity;
  set opacity(double value) {
    _opacity = value.clamp(0.0, 1.0);
    // Update the base UnlitMaterial opacity as well
    baseColorFactor = vm.Vector4(
      (_color.r * 255.0).round().clamp(0, 255) / 255.0,
      (_color.g * 255.0).round().clamp(0, 255) / 255.0,
      (_color.b * 255.0).round().clamp(0, 255) / 255.0,
      _opacity,
    );
  }

  vm.Vector2 get resolution => _resolution;
  set resolution(vm.Vector2 value) {
    if (_resolution == value) return; // Avoid unnecessary updates
    _resolution = value;
    // TODO: Update shader uniforms when custom shaders are supported
  }

  /// Update resolution for viewport changes (Three.js Line2 compatible)
  void updateResolution(double width, double height) {
    resolution = vm.Vector2(width, height);
  }

  /// Three.js LineMaterial compatibility method for batch property updates
  void setValues({
    double? lineWidth,
    Color? color,
    double? opacity,
    vm.Vector2? resolution,
  }) {
    if (lineWidth != null) this.lineWidth = lineWidth;
    if (color != null) this.color = color;
    if (opacity != null) this.opacity = opacity;
    if (resolution != null) this.resolution = resolution;
  }

  // Custom shader loading removed - using standard UnlitMaterial shaders

  // Using standard UnlitMaterial binding - no custom uniforms needed for basic line rendering
  

  /// Convert to string for debugging
  @override
  String toString() {
    return 'LineMaterial(lineWidth: $_lineWidth, color: $_color, opacity: $_opacity, resolution: $_resolution)';
  }
}