import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../renderers/text_texture_factory.dart';
import '../renderers/billboard_shader_renderer.dart';
import '../utils/logger.dart';

/// Factory for creating text billboards in 3D scenes
/// 
/// Combines text texture generation with billboard rendering to create
/// camera-facing text labels with proper device pixel ratio scaling.
/// Follows the established scene factory pattern for consistent organization.
class TextBillboardFactory {
  
  /// Create a text billboard node for 3D scenes
  /// 
  /// Generates high-quality text textures and creates camera-facing billboards
  /// with proper pixel-accurate sizing and anti-aliasing.
  /// 
  /// Parameters:
  /// - [text]: The text content to display
  /// - [position]: 3D position in world space
  /// - [textStyle]: Flutter TextStyle for font, size, color, etc.
  /// - [viewportWidth]/[viewportHeight]: Current viewport dimensions for scaling
  /// - [devicePixelRatio]: Device pixel ratio for proper text sizing
  /// - [backgroundColor]: Background color for text texture (default: transparent)
  /// - [tintColor]: Additional tint color applied to the billboard
  /// - [opacity]: Overall opacity of the billboard
  /// - [textAlign]: Text alignment within the texture
  /// - [padding]: Padding around the text in the texture
  /// - [id]: Optional identifier for the billboard node
  /// 
  /// Returns a [Node] ready for addition to the scene graph.
  static Future<Node> createTextBillboard({
    required String text,
    required vm.Vector3 position,
    required TextStyle textStyle,
    required double viewportWidth,
    required double viewportHeight,
    required double devicePixelRatio,
    Color backgroundColor = Colors.transparent,
    Color tintColor = Colors.white,
    double opacity = 1.0,
    TextAlign textAlign = TextAlign.center,
    EdgeInsets padding = const EdgeInsets.all(8.0),
    String? id,
  }) async {
    try {
      AppLogger.debug('Creating text billboard: "$text" at position $position');
      
      // Step 1: Generate high-quality text texture
      final textTexture = await TextTextureFactory.createTextTexture(
        text: text,
        textStyle: textStyle,
        devicePixelRatio: devicePixelRatio, // Match texture resolution to display resolution
        textAlign: textAlign,
        backgroundColor: backgroundColor,
        padding: padding,
      );
      
      // Step 2: Calculate billboard size with device pixel ratio scaling
      final billboardSize = vm.Vector2(
        textTexture.textWidth * devicePixelRatio,
        textTexture.textHeight * devicePixelRatio,
      );
      
      // Debug logging for scaling verification
      AppLogger.debug('Text billboard scaling: textWidth=${textTexture.textWidth}, textHeight=${textTexture.textHeight}, devicePixelRatio=$devicePixelRatio, scaledSize=(${billboardSize.x}, ${billboardSize.y})');
      
      // Step 3: Create billboard node using renderer
      final billboardNode = BillboardRenderer.createTexturedBillboard(
        position: position,
        size: billboardSize,
        texture: textTexture.texture,
        viewportWidth: viewportWidth,
        viewportHeight: viewportHeight,
        tintColor: tintColor,
        opacity: opacity,
        id: id,
      );
      
      AppLogger.debug('Text billboard created successfully: ${billboardNode.name}');
      return billboardNode;
      
    } catch (e) {
      AppLogger.error('Failed to create text billboard for "$text": $e');
      rethrow;
    }
  }
  
  /// Create multiple text billboards for axis labels
  /// 
  /// Convenience method for creating X, Y, Z axis labels with consistent styling.
  /// Each label is positioned along its respective axis at the specified distance.
  /// 
  /// Parameters:
  /// - [axisLength]: Distance from origin to place each label
  /// - [textStyle]: Consistent styling for all axis labels
  /// - [viewportWidth]/[viewportHeight]: Current viewport dimensions
  /// - [devicePixelRatio]: Device pixel ratio for proper sizing
  /// - [backgroundColor]: Background color for text textures
  /// 
  /// Returns a list of [Node] objects for X, Y, Z labels respectively.
  static Future<List<Node>> createAxisLabels({
    required double axisLength,
    required TextStyle textStyle,
    required double viewportWidth,
    required double viewportHeight,
    required double devicePixelRatio,
    Color backgroundColor = Colors.transparent,
  }) async {
    try {
      AppLogger.debug('Creating axis labels at distance $axisLength');
      
      // Define axis positions and labels
      final axisData = [
        {'text': 'X', 'position': vm.Vector3(axisLength, 0, 0), 'color': Colors.red},
        {'text': 'Y', 'position': vm.Vector3(0, axisLength, 0), 'color': Colors.green},
        {'text': 'Z', 'position': vm.Vector3(0, 0, axisLength), 'color': Colors.blue},
      ];
      
      final nodes = <Node>[];
      
      // Create each axis label
      for (final axis in axisData) {
        final labelStyle = textStyle.copyWith(color: axis['color'] as Color);
        
        final node = await createTextBillboard(
          text: axis['text'] as String,
          position: axis['position'] as vm.Vector3,
          textStyle: labelStyle,
          viewportWidth: viewportWidth,
          viewportHeight: viewportHeight,
          devicePixelRatio: devicePixelRatio,
          backgroundColor: backgroundColor,
          id: (axis['text'] as String).toLowerCase(),
        );
        
        nodes.add(node);
      }
      
      AppLogger.debug('Created ${nodes.length} axis labels');
      return nodes;
      
    } catch (e) {
      AppLogger.error('Failed to create axis labels: $e');
      rethrow;
    }
  }
}