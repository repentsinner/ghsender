import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;
import '../utils/logger.dart';
import 'billboard_geometry.dart';
import 'transparent_material.dart';

/// Factory for creating textures from Flutter text rendering
/// Converts TextPainter output to flutter_scene textures for 3D billboard text
class TextTextureFactory {
  /// Create a texture from text using Flutter's TextPainter
  /// Renders text at high resolution for crisp display
  /// renderScale: multiplier for resolution (e.g., 7.0 renders 18pt at ~126px)
  static Future<TextTextureResult> createTextTexture({
    required String text,
    required TextStyle textStyle,
    TextAlign textAlign = TextAlign.center,
    Color backgroundColor = Colors.transparent,
    EdgeInsets padding = const EdgeInsets.all(8.0),
    double renderScale = 7.0,  // Scale factor for high-DPI rendering
  }) async {
    try {
      // Create TextPainter to measure and render text
      final textPainter = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textAlign: textAlign,
        textDirection: TextDirection.ltr,
      );
      
      // Layout the text at original size for proper font hinting
      textPainter.layout();
      
      // Calculate base dimensions
      final textWidth = textPainter.width;
      final textHeight = textPainter.height;
      
      // Scale up for high-DPI rendering
      final scaledWidth = (textWidth * renderScale).ceil();
      final scaledHeight = (textHeight * renderScale).ceil();
      final scaledPaddingH = (padding.horizontal * renderScale).ceil();
      final scaledPaddingV = (padding.vertical * renderScale).ceil();
      
      final textureWidth = scaledWidth + scaledPaddingH;
      final textureHeight = scaledHeight + scaledPaddingV;
      
      AppLogger.info('Creating high-DPI text texture: "${text.substring(0, text.length.clamp(0, 20))}${text.length > 20 ? "..." : ""}" (${textureWidth}x$textureHeight at ${renderScale}x scale)');
      
      // Create image recorder for rendering
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Draw background
      if (backgroundColor != Colors.transparent) {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, textureWidth.toDouble(), textureHeight.toDouble()),
          Paint()..color = backgroundColor,
        );
      }
      
      // Scale canvas and draw text at high resolution
      canvas.save();
      canvas.scale(renderScale, renderScale);
      textPainter.paint(canvas, Offset(padding.left, padding.top));
      canvas.restore();
      
      // Convert to image at scaled resolution
      final picture = recorder.endRecording();
      final image = await picture.toImage(textureWidth, textureHeight);
      
      // Convert to byte data
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        throw Exception('Failed to convert text image to byte data');
      }
      
      // Create GPU texture from the image data
      final texture = gpu.gpuContext.createTexture(
        gpu.StorageMode.hostVisible,
        textureWidth,
        textureHeight,
      );
      texture.overwrite(byteData);
      
      AppLogger.info('Text texture created successfully: ${textureWidth}x$textureHeight pixels');
      
      return TextTextureResult(
        texture: texture,
        textWidth: textWidth,
        textHeight: textHeight,
        textureWidth: textureWidth,
        textureHeight: textureHeight,
        aspectRatio: textureWidth / textureHeight,
      );
      
    } catch (e) {
      AppLogger.error('Failed to create text texture: $e');
      rethrow;
    }
  }
  
  /// Create a billboard material with linear filtering
  static BillboardMaterial createBillboardMaterial({
    gpu.Texture? texture,
    double opacity = 1.0,
    Color color = Colors.white,
    bool enableAlphaBlending = true,
  }) {
    // Create material with texture and linear filtering
    final material = BillboardMaterial(colorTexture: texture);
    
    // Set base color factor for tinting/opacity
    material.baseColorFactor = vm.Vector4(
      color.r,
      color.g,
      color.b,
      opacity,
    );
    
    return material;
  }
  
  /// Create a quad geometry for billboard rendering
  /// Returns a geometry that can be used for text billboards
  static BillboardGeometry createBillboardGeometry({
    required double width,
    required double height,
  }) {
    return BillboardGeometry(width: width, height: height);
  }
}

/// Result of text texture creation
class TextTextureResult {
  final gpu.Texture texture;   // GPU texture with rendered text
  final double textWidth;      // Actual text width in pixels
  final double textHeight;     // Actual text height in pixels
  final int textureWidth;      // Texture width in pixels
  final int textureHeight;     // Texture height in pixels
  final double aspectRatio;    // Texture aspect ratio
  
  const TextTextureResult({
    required this.texture,
    required this.textWidth,
    required this.textHeight,
    required this.textureWidth,
    required this.textureHeight,
    required this.aspectRatio,
  });
}

/// Custom TransparentMaterial with linear texture filtering for smooth text rendering
class BillboardMaterial extends TransparentMaterial {
  BillboardMaterial({super.colorTexture});
  
  @override
  void bind(
    gpu.RenderPass pass,
    gpu.HostBuffer transientsBuffer,
    Environment environment,
  ) {
    // Call parent bind first for blend mode setup and standard material setup
    super.bind(pass, transientsBuffer, environment);
    
    // Re-bind texture with linear filtering for smooth text interpolation
    pass.bindTexture(
      fragmentShader.getUniformSlot('base_color_texture'),
      baseColorTexture,
      sampler: gpu.SamplerOptions(
        minFilter: gpu.MinMagFilter.linear,  // Linear when texture is minified
        magFilter: gpu.MinMagFilter.linear,  // Linear when texture is magnified
        mipFilter: gpu.MipFilter.linear,     // Linear between mipmap levels
        widthAddressMode: gpu.SamplerAddressMode.clampToEdge,  // Don't repeat
        heightAddressMode: gpu.SamplerAddressMode.clampToEdge, // Don't repeat
      ),
    );
  }
}