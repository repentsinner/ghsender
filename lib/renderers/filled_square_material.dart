/*
 * FilledSquareMaterial implementation for Flutter Scene
 * 
 * Material for rendering filled square interiors with transparency support
 * Based on UnlitMaterial for consistent lighting behavior
 */

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:flutter_scene/scene.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import '../utils/logger.dart';

class FilledSquareMaterial extends UnlitMaterial {
  final Color _fillColor;
  final double _opacity;

  FilledSquareMaterial({required Color fillColor, double opacity = 1.0})
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

    AppLogger.info(
      'FilledSquareMaterial created: color=$_fillColor, opacity=$_opacity',
    );
  }

  /// Get the fill color
  Color get fillColor => _fillColor;

  /// Get the opacity
  double get opacity => _opacity;

  /// Create a new material with different opacity
  FilledSquareMaterial withOpacity(double newOpacity) {
    return FilledSquareMaterial(fillColor: _fillColor, opacity: newOpacity);
  }

  /// Create a new material with different color
  FilledSquareMaterial withColor(Color newColor) {
    return FilledSquareMaterial(fillColor: newColor, opacity: _opacity);
  }

  @override
  bool isOpaque() {
    // Return false if we have any transparency
    // This ensures proper rendering order for semi-transparent squares
    return _opacity >= 1.0;
  }

  /// Override bind() to set correct blend mode for non-premultiplied alpha
  /// Flutter Scene's default blend mode expects premultiplied alpha, but UnlitFragment shader doesn't premultiply
  @override
  void bind(
    gpu.RenderPass pass,
    gpu.HostBuffer transientsBuffer,
    Environment environment,
  ) {
    // Call parent bind first to handle uniforms and textures
    super.bind(pass, transientsBuffer, environment);

    // Only set custom blending for translucent squares
    if (!isOpaque()) {
      // Set correct blend equation for non-premultiplied alpha
      // Standard alpha blending: Result = Source * sourceAlpha + Destination * (1 - sourceAlpha)
      pass.setColorBlendEnable(true);
      pass.setColorBlendEquation(
        gpu.ColorBlendEquation(
          colorBlendOperation: gpu.BlendOperation.add,
          sourceColorBlendFactor: gpu.BlendFactor.sourceAlpha, // Multiply source by its alpha
          destinationColorBlendFactor: gpu.BlendFactor.oneMinusSourceAlpha,
          alphaBlendOperation: gpu.BlendOperation.add,
          sourceAlphaBlendFactor: gpu.BlendFactor.one,
          destinationAlphaBlendFactor: gpu.BlendFactor.oneMinusSourceAlpha,
        ),
      );
      
      AppLogger.info(
        'FilledSquareMaterial: Set standard alpha blending for non-premultiplied colors (opacity: $_opacity)',
      );
    }
  }

  @override
  String toString() {
    return 'FilledSquareMaterial(color: $_fillColor, opacity: $_opacity, isOpaque: ${isOpaque()})';
  }
}
