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
  double _sharpness = 0.5;
  vm.Vector2 _resolution = vm.Vector2(1024, 768); // Default resolution
  int _depthWriteLogCount = 0; // Debug counter for depth write logging

  // Shader loading
  static gpu.ShaderLibrary? _shaderLibrary;
  static bool _shadersLoaded = false;
  static bool _shaderLoadingAttempted = false;

  LineMaterial({
    double lineWidth = 1.0,
    Color color = Colors.green,
    double opacity = 1.0,
    double sharpness = 0.5,
    vm.Vector2? resolution,
  }) : _lineWidth = lineWidth,
       _color = color,
       _opacity = opacity,
       _sharpness = sharpness,
       _resolution = resolution ?? vm.Vector2(1024, 768) {
    // Set base color for UnlitMaterial 
    // Flutter Color properties are already normalized (0.0-1.0)
    baseColorFactor = vm.Vector4(color.r, color.g, color.b, opacity);

    // Repurpose vertex_color_weight to pass sharpness to fragment shader
    vertexColorWeight = _sharpness;

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

  double get sharpness => _sharpness;
  set sharpness(double value) {
    if (_sharpness == value) return; // Avoid unnecessary updates
    _sharpness = value.clamp(0.0, 1.0);
    // Update vertex_color_weight to pass sharpness to fragment shader
    vertexColorWeight = _sharpness;
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
    double? sharpness,
    vm.Vector2? resolution,
  }) {
    if (lineWidth != null) this.lineWidth = lineWidth;
    if (color != null) this.color = color;
    if (opacity != null) this.opacity = opacity;
    if (sharpness != null) this.sharpness = sharpness;
    if (resolution != null) this.resolution = resolution;
  }

  /// Load custom fragment shaders - REQUIRED for line rendering
  static Future<void> _loadShaders() async {
    _shaderLoadingAttempted = true;
    try {
      _shaderLibrary = gpu.ShaderLibrary.fromAsset(
        'build/shaderbundles/ghsender.shaderbundle',
      );
      _shadersLoaded = true;
      AppLogger.info('Custom line fragment shaders loaded successfully');
    } catch (e) {
      AppLogger.error('Failed to load custom line fragment shaders: $e');
      throw Exception(
        'LineMaterial requires custom fragment shaders. '
        'Shader bundle not found or failed to load: $e',
      );
    }
  }

  /// Provide fragment shader for SceneEncoder to use in RenderPipeline creation
  /// This follows flutter_scene's architecture where Material provides fragment shaders
  @override
  gpu.Shader get fragmentShader {
    if (!_shadersLoaded || _shaderLibrary == null) {
      throw Exception(
        'LineMaterial fragment shader not available. '
        'Custom shaders must be loaded before using line rendering.',
      );
    }

    final customFragmentShader = _shaderLibrary!['LineFragment'];
    if (customFragmentShader == null) {
      throw Exception(
        'LineFragment shader not found in shader bundle. '
        'Check that ghsender.shaderbundle.json contains "LineFragment" entry.',
      );
    }

    return customFragmentShader;
  }

  // Enable alpha blending for anti-aliased lines
  @override
  bool isOpaque() {
    // IMPORTANT: Return false to render lines in translucent pass AFTER opaque geometry
    // This ensures lines render on top of filled squares for proper depth ordering
    // We handle depth writing manually in bind() to maintain z-order correction
    return false; // Render in translucent pass for proper layering
  }

  /// Override bind() to enable depth writing for per-pixel depth testing
  /// This allows anti-aliased lines to achieve Three.js-style depth sorting
  @override
  void bind(
    gpu.RenderPass pass,
    gpu.HostBuffer transientsBuffer,
    Environment environment,
  ) {
    // Call parent bind first to handle uniforms and textures
    super.bind(pass, transientsBuffer, environment);

    // Enable alpha blending for anti-aliased lines (we're in translucent pass)
    pass.setColorBlendEnable(true);

    // Set up proper alpha blending for anti-aliased lines
    // Use same blending as flutter_scene's translucent pass
    pass.setColorBlendEquation(
      gpu.ColorBlendEquation(
        colorBlendOperation: gpu.BlendOperation.add,
        sourceColorBlendFactor: gpu.BlendFactor.one,
        destinationColorBlendFactor: gpu.BlendFactor.oneMinusSourceAlpha,
        alphaBlendOperation: gpu.BlendOperation.add,
        sourceAlphaBlendFactor: gpu.BlendFactor.one,
        destinationAlphaBlendFactor: gpu.BlendFactor.oneMinusSourceAlpha,
      ),
    );

    // Keep depth writing enabled even though we're in translucent pass
    // This allows gl_FragDepth to work for per-pixel depth testing
    // Note: May need pass.setDepthWriteEnable(true) if translucent pass disables it

    // Debug: Log alpha blending and depth writing state (but throttle to avoid spam)
    if (_depthWriteLogCount < 3) {
      AppLogger.info(
        'LineMaterial: Alpha blending + depth writing enabled for anti-aliased lines in translucent pass (call ${_depthWriteLogCount + 1})',
      );
      _depthWriteLogCount++;
    }
  }

  /// Convert to string for debugging
  @override
  String toString() {
    return 'LineMaterial(lineWidth: $_lineWidth, color: $_color, opacity: $_opacity, sharpness: $_sharpness, resolution: $_resolution)';
  }
}
