import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;
import 'package:flutter_scene/scene.dart';
import '../utils/logger.dart';

/// Size mode for billboard rendering
enum BillboardSizeMode {
  /// Billboard size is specified in world units and scales with camera distance
  worldSpace,
  
  /// Billboard size is specified in pixels and maintains constant screen size
  screenSpace,
}

/// Billboard geometry for flutter_scene integration
/// 
/// Creates a simple quad geometry that REQUIRES custom billboard shaders.
/// Will throw exceptions if shaders fail to load or compile.
/// Inherits from UnskinnedGeometry only for flutter_scene compatibility,
/// but enforces that ONLY custom shaders are used.
class BillboardGeometry extends UnskinnedGeometry {
  final double width;
  final double height;
  final BillboardSizeMode sizeMode;
  final vm.Vector3 position;
  final double pixelSize;
  
  // Shader loading state
  static bool _shaderLoadingAttempted = false;
  static bool _shadersSuccessfullyLoaded = false;

  BillboardGeometry({
    required this.width,
    required this.height,
    required this.position,
    this.sizeMode = BillboardSizeMode.worldSpace,
    this.pixelSize = 24.0,
  }) {
    // FAIL FAST: Require shaders to be loaded before creating geometry
    if (!_shaderLoadingAttempted) {
      _loadShaders();
    }
    
    if (!_shadersSuccessfullyLoaded) {
      throw Exception(
        'BillboardGeometry creation failed: Custom shaders are REQUIRED but not loaded. '
        'This indicates shader compilation or loading failed.'
      );
    }
    
    _generateQuadGeometry();
  }

  /// Load custom billboard shaders - REQUIRED for billboard rendering
  static Future<void> _loadShaders() async {
    _shaderLoadingAttempted = true;
    try {
      final shaderLibrary = gpu.ShaderLibrary.fromAsset(
        'build/shaderbundles/ghsender.shaderbundle',
      );
      _shadersSuccessfullyLoaded = true;
      AppLogger.info('Billboard shaders loaded successfully: $shaderLibrary');
    } catch (e) {
      _shadersSuccessfullyLoaded = false;
      AppLogger.error('SHADER LOADING FAILED - Billboard shaders are REQUIRED during development: $e');
      throw Exception(
        'Billboard shader compilation/loading failed. '
        'Check shader files in shaders/ directory and ensure build hook is working. '
        'Original error: $e'
      );
    }
  }

  void _generateQuadGeometry() {
    try {
      // Create vertices for a simple quad
      // Position will be handled by the vertex shader
      final halfWidth = width / 2;
      final halfHeight = height / 2;
      
      final vertices = <double>[];
      final indices = <int>[];

      // Normal pointing towards camera (will be overridden by billboard shader)
      final normal = vm.Vector3(0, 0, 1);
      
      // Define the 4 corners with UV coordinates
      // Note: Proper winding order for Impeller (counter-clockwise when facing camera)
      final corners = [
        {'pos': vm.Vector3(-halfWidth, -halfHeight, 0), 'uv': vm.Vector2(0, 1)}, // Bottom left
        {'pos': vm.Vector3(halfWidth, -halfHeight, 0), 'uv': vm.Vector2(1, 1)},  // Bottom right
        {'pos': vm.Vector3(halfWidth, halfHeight, 0), 'uv': vm.Vector2(1, 0)},   // Top right
        {'pos': vm.Vector3(-halfWidth, halfHeight, 0), 'uv': vm.Vector2(0, 0)},  // Top left
      ];

      // Add vertices (position + normal + uv + color = 12 floats per vertex)
      for (final corner in corners) {
        final pos = corner['pos'] as vm.Vector3;
        final uv = corner['uv'] as vm.Vector2;
        
        vertices.addAll([
          pos.x, pos.y, pos.z,           // position (3)
          normal.x, normal.y, normal.z,  // normal (3)
          uv.x, uv.y,                    // texture coordinates (2)
          1.0, 1.0, 1.0, 1.0,           // color (4) - white, full alpha
        ]);
      }

      // Define triangles (2 triangles for the quad)
      // Counter-clockwise winding for front-facing
      indices.addAll([
        0, 1, 2, // First triangle: bottom-left, bottom-right, top-right
        0, 2, 3, // Second triangle: bottom-left, top-right, top-left
      ]);

      // Create buffers using the same pattern as other geometries
      _createBuffers(vertices, indices);
      
    } catch (e) {
      AppLogger.error('Failed to generate billboard geometry: $e');
      rethrow;
    }
  }

  void _createBuffers(List<double> vertices, List<int> indices) {
    if (vertices.isEmpty || indices.isEmpty) {
      throw Exception('Cannot create buffers with empty vertex or index data');
    }

    // Convert to typed data
    final vertexData = Float32List.fromList(vertices);
    final indexData = Uint16List.fromList(
      indices.map((i) => i.clamp(0, 65535)).toList(),
    );

    final deviceBuffer = gpu.gpuContext.createDeviceBuffer(
      gpu.StorageMode.hostVisible,
      vertexData.lengthInBytes + indexData.lengthInBytes,
    );

    deviceBuffer.overwrite(
      ByteData.sublistView(vertexData),
      destinationOffsetInBytes: 0,
    );

    final indexOffset = vertexData.lengthInBytes;
    deviceBuffer.overwrite(
      ByteData.sublistView(indexData),
      destinationOffsetInBytes: indexOffset,
    );

    setVertices(
      gpu.BufferView(
        deviceBuffer,
        offsetInBytes: 0,
        lengthInBytes: vertexData.lengthInBytes,
      ),
      vertices.length ~/ 12, // 12 floats per vertex (UnskinnedGeometry format)
    );

    setIndices(
      gpu.BufferView(
        deviceBuffer,
        offsetInBytes: indexOffset,
        lengthInBytes: indexData.lengthInBytes,
      ),
      gpu.IndexType.int16,
    );
  }
}

/// Billboard material for flutter_scene integration
/// 
/// REQUIRES custom billboard shaders - no fallback to default materials.
/// Inherits from UnlitMaterial only for flutter_scene compatibility,
/// but enforces that ONLY custom shaders are used.
class BillboardMaterial extends UnlitMaterial {
  final BillboardSizeMode sizeMode;
  final double pixelSize;
  final vm.Vector3 billboardPosition;
  final vm.Vector2 billboardSize;
  
  BillboardMaterial({
    required this.billboardPosition,
    required this.billboardSize,
    this.sizeMode = BillboardSizeMode.worldSpace,
    this.pixelSize = 24.0,
    Color color = Colors.white,
    double opacity = 1.0,
  }) {
    // FAIL FAST: Require shaders to be loaded before creating material
    if (!BillboardGeometry._shadersSuccessfullyLoaded) {
      throw Exception(
        'BillboardMaterial creation failed: Custom shaders are REQUIRED but not loaded. '
        'Ensure BillboardGeometry shader loading succeeded before creating materials.'
      );
    }
    
    // Set base color - this will be passed to custom fragment shader
    baseColorFactor = vm.Vector4(color.r, color.g, color.b, opacity);
    
    // Store size mode as vertex color weight for custom shader access
    vertexColorWeight = sizeMode == BillboardSizeMode.screenSpace ? 1.0 : 0.0;
  }
  
  @override
  bool isOpaque() {
    // Enable alpha blending for billboards
    return baseColorFactor.w >= 1.0;
  }
}

/// Billboard renderer that integrates with flutter_scene
/// 
/// Creates billboard nodes that work within the existing scene graph
/// while using GPU shaders for efficient camera-facing orientation.
class BillboardRenderer {
  
  /// Create a solid color billboard node
  /// 
  /// REQUIRES custom shaders to be compiled and loaded successfully.
  /// Will throw exceptions if shader requirements are not met.
  static Node createSolidBillboard({
    required vm.Vector3 position,
    required vm.Vector2 size,
    required Color color,
    BillboardSizeMode sizeMode = BillboardSizeMode.worldSpace,
    double pixelSize = 24.0,
    double opacity = 1.0,
    String? id,
  }) {
    try {
      // Create billboard geometry
      final geometry = BillboardGeometry(
        width: size.x,
        height: size.y,
        position: position,
        sizeMode: sizeMode,
        pixelSize: pixelSize,
      );
      
      // Create billboard material
      final material = BillboardMaterial(
        billboardPosition: position,
        billboardSize: size,
        sizeMode: sizeMode,
        pixelSize: pixelSize,
        color: color,
        opacity: opacity,
      );
      
      // Create mesh
      final mesh = Mesh.primitives(
        primitives: [MeshPrimitive(geometry, material)],
      );
      
      // Create node
      final node = Node();
      node.mesh = mesh;
      node.localTransform = vm.Matrix4.translation(position);
      
      // Encode metadata in name for scene graph processing
      final nodeId = id ?? 'billboard';
      node.name = 'billboard_${nodeId}_${sizeMode.name}_${pixelSize.toStringAsFixed(1)}';
      
      return node;
      
    } catch (e) {
      AppLogger.error('BILLBOARD CREATION FAILED - This is likely due to shader compilation issues: $e');
      throw Exception(
        'Failed to create solid billboard. This typically indicates:\n'
        '1. Shader compilation failed (check shaders/ directory)\n'
        '2. Build hook not working (check hook/build.dart)\n'
        '3. Shader bundle not generated (check build/shaderbundles/)\n'
        'Original error: $e'
      );
    }
  }
  
  /// Create a textured billboard node
  /// 
  /// REQUIRES custom shaders to be compiled and loaded successfully.
  /// Will throw exceptions if shader requirements are not met.
  static Node createTexturedBillboard({
    required vm.Vector3 position,
    required vm.Vector2 size,
    required gpu.Texture texture,
    BillboardSizeMode sizeMode = BillboardSizeMode.worldSpace,
    double pixelSize = 24.0,
    Color tintColor = Colors.white,
    double opacity = 1.0,
    String? id,
  }) {
    try {
      // Create billboard geometry
      final geometry = BillboardGeometry(
        width: size.x,
        height: size.y,
        position: position,
        sizeMode: sizeMode,
        pixelSize: pixelSize,
      );
      
      // Create billboard material with texture
      final material = BillboardMaterial(
        billboardPosition: position,
        billboardSize: size,
        sizeMode: sizeMode,
        pixelSize: pixelSize,
        color: tintColor,
        opacity: opacity,
      );
      
      // Set the texture on the material
      material.baseColorTexture = texture;
      
      // Create mesh
      final mesh = Mesh.primitives(
        primitives: [MeshPrimitive(geometry, material)],
      );
      
      // Create node
      final node = Node();
      node.mesh = mesh;
      node.localTransform = vm.Matrix4.translation(position);
      
      // Encode metadata in name for scene graph processing
      final nodeId = id ?? 'billboard';
      node.name = 'billboard_${nodeId}_${sizeMode.name}_${pixelSize.toStringAsFixed(1)}';
      
      return node;
      
    } catch (e) {
      AppLogger.error('TEXTURED BILLBOARD CREATION FAILED - This is likely due to shader compilation issues: $e');
      throw Exception(
        'Failed to create textured billboard. This typically indicates:\n'
        '1. Shader compilation failed (check shaders/ directory)\n'
        '2. Build hook not working (check hook/build.dart)\n'
        '3. Shader bundle not generated (check build/shaderbundles/)\n'
        'Original error: $e'
      );
    }
  }
  
}