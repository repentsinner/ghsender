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
import 'package:flutter_gpu/gpu.dart' as gpu;
import '../utils/logger.dart';

class LineMaterial extends UnlitMaterial {
  // Line properties (Three.js compatible)
  double _lineWidth = 1.0;
  Color _color = Colors.white;
  double _opacity = 1.0;
  vm.Vector2 _resolution = vm.Vector2(1024, 768); // Default resolution

  // Shader loading
  static gpu.ShaderLibrary? _shaderLibrary;
  static bool _shadersLoaded = false;
  static bool _shaderLoadingAttempted = false;

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
    // Flutter Color properties are already normalized (0.0-1.0)
    baseColorFactor = vm.Vector4(color.r, color.g, color.b, opacity);

    // Attempt to load custom shaders if not already attempted
    if (!_shaderLoadingAttempted) {
      _loadShaders();
    }
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
    // Flutter Color properties are already normalized (0.0-1.0)
    baseColorFactor = vm.Vector4(value.r, value.g, value.b, _opacity);
  }

  double get opacity => _opacity;
  set opacity(double value) {
    _opacity = value.clamp(0.0, 1.0);
    // Update the base UnlitMaterial opacity as well
    // Flutter Color properties are already normalized (0.0-1.0)
    baseColorFactor = vm.Vector4(_color.r, _color.g, _color.b, _opacity);
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

  /// Load custom fragment shaders matching flutter_scene's UnlitMaterial
  static Future<void> _loadShaders() async {
    _shaderLoadingAttempted = true;
    try {
      _shaderLibrary = gpu.ShaderLibrary.fromAsset(
        'build/shaderbundles/graphics_performance_spike.shaderbundle',
      );
      _shadersLoaded = true;
      AppLogger.info('Custom fragment shaders loaded successfully');
    } catch (e) {
      AppLogger.warning(
        'Failed to load custom fragment shaders, falling back to default: $e',
      );
      // Fall back to UnlitMaterial behavior if shaders fail to load
      _shadersLoaded = false;
    }
  }

  /// Provide fragment shader for SceneEncoder to use in RenderPipeline creation
  /// This follows flutter_scene's architecture where Material provides fragment shaders
  @override
  gpu.Shader get fragmentShader {
    if (!_shadersLoaded || _shaderLibrary == null) {
      // Fallback: use flutter_scene's base shader library directly
      return baseShaderLibrary['UnlitFragment']!;
    }

    try {
      final customFragmentShader = _shaderLibrary!['UnlitFragment'];
      if (customFragmentShader != null) {
        return customFragmentShader;
      } else {
        AppLogger.warning(
          'Custom fragment shader not found in bundle, using flutter_scene default',
        );
        return baseShaderLibrary['UnlitFragment']!;
      }
    } catch (e) {
      AppLogger.error('Failed to get custom fragment shader: $e');
      return baseShaderLibrary['UnlitFragment']!;
    }
  }

  // Using standard UnlitMaterial binding - no custom uniforms needed for basic line rendering

  /// Convert to string for debugging
  @override
  String toString() {
    return 'LineMaterial(lineWidth: $_lineWidth, color: $_color, opacity: $_opacity, resolution: $_resolution)';
  }
}
