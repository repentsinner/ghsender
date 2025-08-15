import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../utils/logger.dart';
import 'billboard_geometry.dart';

/// Factory for creating textures from Flutter text rendering
/// Converts TextPainter output to flutter_scene textures for 3D billboard text
class TextTextureFactory {
  static const int _defaultTextureWidth = 512;
  static const int _defaultTextureHeight = 128;
  
  /// Create a texture from text using Flutter's TextPainter
  /// Returns both the texture and the actual text dimensions for proper billboard sizing
  static Future<TextTextureResult> createTextTexture({
    required String text,
    required TextStyle textStyle,
    TextAlign textAlign = TextAlign.center,
    int maxWidth = _defaultTextureWidth,
    int maxHeight = _defaultTextureHeight,
    Color backgroundColor = Colors.transparent,
    EdgeInsets padding = const EdgeInsets.all(8.0),
  }) async {
    try {
      // Create TextPainter to measure and render text
      final textPainter = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textAlign: textAlign,
        textDirection: TextDirection.ltr,
      );
      
      // Layout the text with constraints
      textPainter.layout(
        minWidth: 0,
        maxWidth: maxWidth - padding.horizontal,
      );
      
      // Calculate actual texture size needed
      final textWidth = textPainter.width;
      final textHeight = textPainter.height;
      final textureWidth = (textWidth + padding.horizontal).ceil();
      final textureHeight = (textHeight + padding.vertical).ceil();
      
      AppLogger.info('Creating text texture: "${text.substring(0, text.length.clamp(0, 20))}${text.length > 20 ? "..." : ""}" (${textureWidth}x$textureHeight)');
      
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
      
      // Draw text with padding offset
      textPainter.paint(canvas, Offset(padding.left, padding.top));
      
      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(textureWidth, textureHeight);
      
      // Convert to byte data
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        throw Exception('Failed to convert text image to byte data');
      }
      
      // For now, skip texture creation and return dimensions for sizing
      // TODO: Implement proper texture from ui.Image when flutter_scene API is clear
      AppLogger.info('Text rendered successfully: ${textureWidth}x$textureHeight pixels (texture creation skipped)');
      
      return TextTextureResult(
        // texture: null, // Skip texture for now
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
  
  /// Create a billboard material (without texture for now)
  static UnlitMaterial createBillboardMaterial({
    double opacity = 1.0,
    Color color = Colors.white,
    bool enableAlphaBlending = true,
  }) {
    final material = UnlitMaterial();
    // Skip texture for now, just use solid color
    material.baseColorFactor = vm.Vector4(
      (color.r * 255.0).round().clamp(0, 255) / 255.0,
      (color.g * 255.0).round().clamp(0, 255) / 255.0,
      (color.b * 255.0).round().clamp(0, 255) / 255.0,
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
  // final ImageTexture texture; // Skip texture for now
  final double textWidth;      // Actual text width in pixels
  final double textHeight;     // Actual text height in pixels
  final int textureWidth;      // Texture width in pixels
  final int textureHeight;     // Texture height in pixels
  final double aspectRatio;    // Texture aspect ratio
  
  const TextTextureResult({
    // required this.texture, // Skip texture for now
    required this.textWidth,
    required this.textHeight,
    required this.textureWidth,
    required this.textureHeight,
    required this.aspectRatio,
  });
}