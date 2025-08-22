import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import '../utils/logger.dart';

/// Factory for creating textures from Flutter text rendering
/// Converts TextPainter output to flutter_scene textures for 3D billboard text
class TextTextureFactory {
  /// Create a texture from text using Flutter's TextPainter
  /// Renders text at device pixel ratio resolution for crisp display
  /// devicePixelRatio: device DPI scale from MediaQuery.devicePixelRatio
  /// debugSaveToFile: optional file path to save rendered image for debugging
  static Future<TextTextureResult> createTextTexture({
    required String text,
    required TextStyle textStyle,
    required double devicePixelRatio,
    TextAlign textAlign = TextAlign.center,
    Color backgroundColor = Colors.transparent,
    EdgeInsets padding = const EdgeInsets.all(8.0),
    String? debugSaveToFile,
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

      // Calculate base dimensions (logical pixels from TextPainter)
      final textWidth = textPainter.width;
      final textHeight = textPainter.height;

      // Calculate texture dimensions at device pixel ratio resolution
      final textureWidth = ((textWidth + padding.horizontal) * devicePixelRatio)
          .ceil();
      final textureHeight = ((textHeight + padding.vertical) * devicePixelRatio)
          .ceil();

      // Create image recorder for rendering
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw filled background
      if (backgroundColor != Colors.transparent) {
        canvas.drawRect(
          Rect.fromLTWH(
            0,
            0,
            textureWidth.toDouble(),
            textureHeight.toDouble(),
          ),
          Paint()..color = backgroundColor,
        );
      }

      // Scale canvas and draw text at device pixel ratio resolution
      canvas.save();
      canvas.scale(devicePixelRatio);
      textPainter.paint(canvas, Offset(padding.left, padding.top));
      canvas.restore();

      // Convert to image at scaled resolution
      final picture = recorder.endRecording();
      final image = await picture.toImage(textureWidth, textureHeight);

      // Debug: Save image to file if requested
      if (debugSaveToFile != null) {
        try {
          AppLogger.debug('Starting debug texture save to: $debugSaveToFile');

          final pngBytes = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (pngBytes != null) {
            final file = File(debugSaveToFile);

            // Ensure parent directory exists
            final parentDir = file.parent;
            if (!await parentDir.exists()) {
              AppLogger.debug('Creating parent directory: ${parentDir.path}');
              await parentDir.create(recursive: true);
            }

            AppLogger.debug(
              'Writing ${pngBytes.lengthInBytes} bytes to: ${file.absolute.path}',
            );
            await file.writeAsBytes(pngBytes.buffer.asUint8List());

            // Verify file was created
            if (await file.exists()) {
              final fileSize = await file.length();
              AppLogger.info(
                'Successfully saved text texture: ${file.absolute.path} ($fileSize bytes)',
              );
            } else {
              AppLogger.error(
                'File save appeared to succeed but file does not exist: ${file.absolute.path}',
              );
            }
          } else {
            AppLogger.error('Failed to convert image to PNG bytes');
          }
        } catch (e, stackTrace) {
          AppLogger.error(
            'Failed to save debug texture to $debugSaveToFile: $e',
          );
          AppLogger.error('Stack trace: $stackTrace');
        }
      }

      // Convert to byte data, note that alpha is pre-multiplied
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) {
        throw Exception('Failed to convert text image to byte data');
      }

      // Create GPU texture from the image data with pixel-perfect parameters
      final texture = gpu.gpuContext.createTexture(
        gpu.StorageMode.hostVisible,
        textureWidth,
        textureHeight,
        format: gpu.PixelFormat.r8g8b8a8UNormInt, // Explicit RGBA8 format
        enableRenderTargetUsage: false, // Read-only texture
        enableShaderReadUsage: true, // Enable shader sampling
        coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture,
      );
      texture.overwrite(byteData);

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
}

/// Result of text texture creation
class TextTextureResult {
  final gpu.Texture texture; // GPU texture with rendered text
  final double textWidth; // Actual text width in pixels
  final double textHeight; // Actual text height in pixels
  final int textureWidth; // Texture width in pixels
  final int textureHeight; // Texture height in pixels
  final double aspectRatio; // Texture aspect ratio

  const TextTextureResult({
    required this.texture,
    required this.textWidth,
    required this.textHeight,
    required this.textureWidth,
    required this.textureHeight,
    required this.aspectRatio,
  });
}
