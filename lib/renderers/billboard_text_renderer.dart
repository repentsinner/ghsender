import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../utils/logger.dart';
import 'text_texture_factory.dart';

/// Size mode for billboard text rendering
enum BillboardSizeMode {
  /// Billboard size is specified in world units and scales with camera distance
  worldSpace,
  
  /// Billboard size is specified in pixels and maintains constant screen size
  screenSpace,
}

/// Renderer for 3D-positioned, screen-aligned text billboards
/// Creates text textures and positions them in 3D space while keeping them facing the camera
class BillboardTextRenderer {
  
  /// Create a billboard text node positioned in 3D space
  static Future<Node> createTextBillboard({
    required String text,
    required vm.Vector3 position,
    required TextStyle textStyle,
    double worldSize = 10.0,  // Size in world units
    Color backgroundColor = Colors.transparent,
    double opacity = 1.0,
    String? id,
    BillboardSizeMode sizeMode = BillboardSizeMode.worldSpace,
    double pixelSize = 24.0, // Size in pixels for screen space mode
  }) async {
    try {
      // Create text texture using Flutter's text rendering
      final textureResult = await TextTextureFactory.createTextTexture(
        text: text,
        textStyle: textStyle,
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.all(4.0),
      );
      
      // Calculate billboard size maintaining text aspect ratio
      final billboardWidth = worldSize;
      final billboardHeight = worldSize / textureResult.aspectRatio;
      
      // Create billboard geometry (quad facing camera)
      final geometry = TextTextureFactory.createBillboardGeometry(
        width: billboardWidth,
        height: billboardHeight,
      );
      
      // Create material with text texture
      final material = TextTextureFactory.createBillboardMaterial(
        texture: textureResult.texture,
        opacity: opacity,
        color: textStyle.color ?? Colors.white,
        enableAlphaBlending: backgroundColor == Colors.transparent,
      );
      
      // Create mesh using the flutter_scene pattern
      final mesh = Mesh.primitives(
        primitives: [MeshPrimitive(geometry, material)],
      );
      
      // Create node and position it
      final node = Node();
      node.mesh = mesh;
      node.localTransform = vm.Matrix4.translation(position);
      
      // Mark as billboard for detection during rendering and store size mode metadata
      final nodeId = id ?? 'text';
      node.name = 'billboard_${nodeId}_${sizeMode.name}_${pixelSize.toStringAsFixed(1)}'; // Encode size info in name
      
      return node;
      
    } catch (e) {
      AppLogger.error('Failed to create text billboard: $e');
      rethrow;
    }
  }
  
  /// Create multiple text billboards from a list of text labels
  static Future<List<Node>> createTextBillboards({
    required List<TextBillboardData> billboards,
    required TextStyle defaultTextStyle,
  }) async {
    final nodes = <Node>[];
    
    for (final billboard in billboards) {
      try {
        final node = await createTextBillboard(
          text: billboard.text,
          position: billboard.position,
          textStyle: billboard.textStyle ?? defaultTextStyle,
          worldSize: billboard.worldSize,
          backgroundColor: billboard.backgroundColor,
          opacity: billboard.opacity,
          id: billboard.id,
          sizeMode: billboard.sizeMode,
          pixelSize: billboard.pixelSize,
        );
        nodes.add(node);
      } catch (e) {
        AppLogger.error('Failed to create billboard "${billboard.text}": $e');
      }
    }
    
    AppLogger.info('Created ${nodes.length}/${billboards.length} text billboards');
    return nodes;
  }
  
  /// Create coordinate axis labels for the world origin
  static Future<List<Node>> createAxisLabels({
    double axisLength = 50.0,
    double textSize = 8.0,
    TextStyle? labelStyle,
  }) async {
    final style = labelStyle ?? const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );
    
    final billboards = [
      TextBillboardData(
        text: 'X',
        position: vm.Vector3(axisLength + 5, 0, 0),
        textStyle: style.copyWith(color: Colors.red),
        worldSize: textSize,
        backgroundColor: Colors.black54,
        id: 'axis_label_x',
      ),
      TextBillboardData(
        text: 'Y',
        position: vm.Vector3(0, axisLength + 5, 0),
        textStyle: style.copyWith(color: Colors.green),
        worldSize: textSize,
        backgroundColor: Colors.black54,
        id: 'axis_label_y',
      ),
      TextBillboardData(
        text: 'Z',
        position: vm.Vector3(0, 0, axisLength + 5),
        textStyle: style.copyWith(color: Colors.blue),
        worldSize: textSize,
        backgroundColor: Colors.black54,
        id: 'axis_label_z',
      ),
    ];
    
    return createTextBillboards(
      billboards: billboards,
      defaultTextStyle: style,
    );
  }
  
  /// Create coordinate labels for key points in the scene
  static Future<List<Node>> createCoordinateLabels({
    required List<vm.Vector3> positions,
    double textSize = 6.0,
    TextStyle? labelStyle,
    int decimalPlaces = 1,
  }) async {
    final style = labelStyle ?? const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.normal,
      color: Colors.white,
    );
    
    final billboards = <TextBillboardData>[];
    
    for (int i = 0; i < positions.length; i++) {
      final pos = positions[i];
      final text = '(${pos.x.toStringAsFixed(decimalPlaces)}, ${pos.y.toStringAsFixed(decimalPlaces)}, ${pos.z.toStringAsFixed(decimalPlaces)})';
      
      billboards.add(TextBillboardData(
        text: text,
        position: pos + vm.Vector3(0, 0, textSize * 0.5), // Offset slightly above point
        textStyle: style,
        worldSize: textSize,
        backgroundColor: Colors.black87,
        opacity: 0.9,
        id: 'coord_label_$i',
      ));
    }
    
    return createTextBillboards(
      billboards: billboards,
      defaultTextStyle: style,
    );
  }
  
  /// Update billboard orientation to face the camera
  /// Call this during render loop if billboards need to dynamically face camera
  static void updateBillboardOrientation(Node billboardNode, vm.Vector3 cameraPosition) {
    // Get billboard world position
    // final billboardPos = billboardNode.localTransform.getTranslation();
    
    // Calculate direction from billboard to camera
    // final toCamera = (cameraPosition - billboardPos).normalized();
    
    // Create rotation matrix to face camera
    // For a proper billboard, we'd compute a full look-at matrix
    // For now, this is a simplified version - flutter_scene may handle this automatically
    
    // TODO: Implement proper billboard orientation if flutter_scene doesn't handle it
    // For now, assume flutter_scene handles billboard orientation automatically
  }
}

/// Data class for text billboard configuration
class TextBillboardData {
  final String text;
  final vm.Vector3 position;
  final TextStyle? textStyle;
  final double worldSize;
  final Color backgroundColor;
  final double opacity;
  final String? id;
  final BillboardSizeMode sizeMode;
  final double pixelSize;
  
  const TextBillboardData({
    required this.text,
    required this.position,
    this.textStyle,
    this.worldSize = 10.0,
    this.backgroundColor = Colors.transparent,
    this.opacity = 1.0,
    this.id,
    this.sizeMode = BillboardSizeMode.worldSpace, // Default to world space for backward compatibility
    this.pixelSize = 24.0, // Default pixel size for screen space mode
  });
}