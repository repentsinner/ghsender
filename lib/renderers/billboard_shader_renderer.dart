import 'dart:typed_data';
import 'package:flutter/material.dart' hide Material;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;
import 'package:flutter_scene/scene.dart';
import '../utils/logger.dart';

// Note: Billboard sizing is now always pixel-accurate using clip-space calculations
// No need for separate size modes - viewport dimensions handle the conversion

/// Billboard geometry for flutter_scene integration
/// 
/// Creates a simple quad geometry that REQUIRES custom billboard shaders.
/// Will throw exceptions if shaders fail to load or compile.
/// Uses UnskinnedGeometry for flutter_scene compatibility with repurposed attributes.
class BillboardGeometry extends UnskinnedGeometry {
  final double width;
  final double height;
  final vm.Vector3 position;
  final double viewportWidth;
  final double viewportHeight;
  
  // Shader loading state
  static gpu.ShaderLibrary? _shaderLibrary;
  static bool _shaderLoadingAttempted = false;
  static bool _shadersSuccessfullyLoaded = false;

  BillboardGeometry({
    required this.width,
    required this.height,
    required this.position,
    required this.viewportWidth,
    required this.viewportHeight,
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
      _shaderLibrary = gpu.ShaderLibrary.fromAsset(
        'build/shaderbundles/ghsender.shaderbundle',
      );
      _shadersSuccessfullyLoaded = true;
      AppLogger.info('Billboard shaders loaded successfully');
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

  /// Provide vertex shader for billboard rendering
  @override
  gpu.Shader get vertexShader {
    if (!_shadersSuccessfullyLoaded || _shaderLibrary == null) {
      throw Exception(
        'BillboardGeometry vertex shader not available. '
        'Custom shaders must be loaded before using billboard rendering.',
      );
    }

    final customVertexShader = _shaderLibrary!['BillboardVertex'];
    if (customVertexShader == null) {
      throw Exception(
        'BillboardVertex shader not found in shader bundle. '
        'Check that ghsender.shaderbundle.json contains "BillboardVertex" entry.',
      );
    }

    return customVertexShader;
  }

  void _generateQuadGeometry() {
    try {
      // Create vertices for a simple quad - shader generates corners using gl_VertexID
      final vertices = <double>[];
      final indices = <int>[];
      
      // Use the viewport size passed to the constructor
      
      // Define the 4 corners with their UV coordinates and corner offsets
      // Note: Proper winding order for Impeller (counter-clockwise when facing camera)
      final corners = [
        {'uv': vm.Vector2(0, 1), 'offset': vm.Vector3(-0.5, -0.5, 0.0)}, // Bottom left
        {'uv': vm.Vector2(1, 1), 'offset': vm.Vector3( 0.5, -0.5, 0.0)}, // Bottom right  
        {'uv': vm.Vector2(1, 0), 'offset': vm.Vector3( 0.5,  0.5, 0.0)}, // Top right
        {'uv': vm.Vector2(0, 0), 'offset': vm.Vector3(-0.5,  0.5, 0.0)}, // Top left
      ];

      // Add vertices with corner offsets in normal attribute
      for (final corner in corners) {
        final uv = corner['uv'] as vm.Vector2;
        final offset = corner['offset'] as vm.Vector3;
        
        vertices.addAll([
          position.x, position.y, position.z, // position (3) - billboard center world position
          offset.x, offset.y, offset.z,       // normal (3) - corner offset for quad generation
          uv.x, uv.y,                         // texture coordinates (2) - different per vertex
          width, height, viewportWidth, viewportHeight, // color (4) - [width_pixels, height_pixels, viewport_width, viewport_height]
        ]);
      }

      // Define triangles (2 triangles for the quad)
      // Counter-clockwise winding (try opposite of line renderer)
      indices.addAll([
        0, 1, 2, // First triangle: bottom-left, bottom-right, top-right
        0, 2, 3, // Second triangle: bottom-left, top-right, top-left
      ]);

      // Create GPU buffers using standard UnskinnedGeometry approach
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
/// Extends UnlitMaterial for proper uniform binding and blending support.
class BillboardMaterial extends UnlitMaterial {
  final vm.Vector3 billboardPosition;
  final vm.Vector2 billboardSize;
  final Color color;
  final double opacity;
  
  // Billboard-specific properties (inherited from UnlitMaterial)
  // Note: baseColorTexture is inherited from UnlitMaterial
  
  BillboardMaterial({
    required this.billboardPosition,
    required this.billboardSize,
    this.color = Colors.white,
    this.opacity = 1.0,
    gpu.Texture? colorTexture,
  }) : super(colorTexture: colorTexture) {
    // FAIL FAST: Require shaders to be loaded before creating material
    if (!BillboardGeometry._shadersSuccessfullyLoaded) {
      throw Exception(
        'BillboardMaterial creation failed: Custom shaders are REQUIRED but not loaded. '
        'Ensure BillboardGeometry shader loading succeeded before creating materials.'
      );
    }
    
    // Set base color factor from the color parameter  
    baseColorFactor = vm.Vector4(color.red / 255.0, color.green / 255.0, color.blue / 255.0, opacity);
  }
  
  /// Provide fragment shader for billboard rendering
  @override
  gpu.Shader get fragmentShader {
    if (!BillboardGeometry._shadersSuccessfullyLoaded || BillboardGeometry._shaderLibrary == null) {
      throw Exception(
        'BillboardMaterial fragment shader not available. '
        'Custom shaders must be loaded before using billboard rendering.',
      );
    }

    final customFragmentShader = BillboardGeometry._shaderLibrary!['BillboardFragmentSolid'];
    if (customFragmentShader == null) {
      throw Exception(
        'BillboardFragmentSolid shader not found in shader bundle. '
        'Check that ghsender.shaderbundle.json contains "BillboardFragmentSolid" entry.',
      );
    }

    return customFragmentShader;
  }
  
  @override
  bool isOpaque() {
    // Enable alpha blending for billboards
    return opacity >= 1.0;
  }
  
  @override
  void bind(
    gpu.RenderPass pass,
    gpu.HostBuffer transientsBuffer,
    Environment environment,
  ) {
    // Call parent bind first for standard culling and winding setup
    super.bind(pass, transientsBuffer, environment);
    
    // Start with minimal approach - just use what UnlitMaterial provides
    // The parent bind() already handles FragInfo and base_color_texture
    
    // Set up blending for transparent billboards
    if (!isOpaque()) {
      pass.setColorBlendEnable(true);
      pass.setColorBlendEquation(
        gpu.ColorBlendEquation(
          colorBlendOperation: gpu.BlendOperation.add,
          sourceColorBlendFactor: gpu.BlendFactor.sourceAlpha,
          destinationColorBlendFactor: gpu.BlendFactor.oneMinusSourceAlpha,
          alphaBlendOperation: gpu.BlendOperation.add,
          sourceAlphaBlendFactor: gpu.BlendFactor.one,
          destinationAlphaBlendFactor: gpu.BlendFactor.oneMinusSourceAlpha,
        ),
      );
    }
    
    AppLogger.debug('BillboardMaterial.bind() completed successfully');
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
    required double viewportWidth,
    required double viewportHeight,
    double opacity = 1.0,
    String? id,
  }) {
    try {
      // Create billboard geometry at origin (0,0,0) - Node's localTransform handles positioning
      final geometry = BillboardGeometry(
        width: size.x,
        height: size.y,
        position: vm.Vector3.zero(), // Position handled by Node's localTransform
        viewportWidth: viewportWidth,
        viewportHeight: viewportHeight,
      );
      
      // Create billboard material
      final material = BillboardMaterial(
        billboardPosition: position,
        billboardSize: size,
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
      node.name = 'billboard_${nodeId}_${size.x.toStringAsFixed(0)}x${size.y.toStringAsFixed(0)}';
      
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
    required double viewportWidth,
    required double viewportHeight,
    Color tintColor = Colors.white,
    double opacity = 1.0,
    String? id,
  }) {
    try {
      // Create billboard geometry at origin (0,0,0) - Node's localTransform handles positioning
      final geometry = BillboardGeometry(
        width: size.x,
        height: size.y,
        position: vm.Vector3.zero(), // Position handled by Node's localTransform
        viewportWidth: viewportWidth,
        viewportHeight: viewportHeight,
      );
      
      // Create billboard material with texture
      final material = BillboardMaterial(
        billboardPosition: position,
        billboardSize: size,
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
      node.name = 'billboard_${nodeId}_${size.x.toStringAsFixed(0)}x${size.y.toStringAsFixed(0)}';
      
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