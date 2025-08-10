import 'dart:math' as math;
import '../utils/logger.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math_64.dart' as vm;
import '../scene/scene_manager.dart';
import 'renderer_interface.dart';
import 'gpu_line_tessellator.dart';

/// G-code processing states for visual feedback
enum ProcessingState {
  completed,  // Already processed (dimmed)
  current,    // Currently executing (highlighted)
  upcoming,   // Next ~30s (bright)
  future,     // Not yet reached (normal)
}

class GpuBatchRenderer implements Renderer {
  gpu.HostBuffer? _hostBuffer;
  gpu.BufferView? _vertexBufferView;
  gpu.BufferView? _indexBufferView;
  gpu.RenderPipeline? _fillPipeline;
  gpu.RenderPipeline? _wireframePipeline;
  
  int _vertexCount = 0;
  int _indexCount = 0;
  int _drawCallCount = 0;
  int _polygonCount = 0;
  
  // Renderer state
  bool _initialized = false;
  bool _wireframeMode = false;
  
  // Scene data received from SceneManager
  SceneData? _sceneData;
  
  // GPU line tessellator for consistent line rendering with flutter_scene
  final GpuLineTessellator _lineTessellator = GpuLineTessellator();
  
  // Interactive rotation state
  double _rotationX = 0.0;
  double _rotationY = 0.0;
  
  @override
  Future<bool> initialize() async {
    try {
      // Only create render pipelines during initialization
      // Geometry and buffers will be created when scene data is provided
      await _createRenderPipelines();
      
      // Initialize shared line tessellator
      final lineInitSuccess = await _lineTessellator.initialize();
      if (!lineInitSuccess) {
        AppLogger.warning('GPU line tessellator failed to initialize in GPU renderer');
      }
      
      _initialized = true;
      return true;
    } catch (e) {
      AppLogger.error('GPU renderer initialization failed', e);
      return false;
    }
  }
  
  
  void _createGpuBuffers() {
    try {
      if (_sceneData == null) {
        throw Exception('Scene data not available - call setupScene() first');
      }
      
      // Create host buffer for efficient GPU access
      _hostBuffer = gpu.gpuContext.createHostBuffer();
      
      // Create actual vertex buffer with 3D scene data including colors
      final vertices = <double>[];
      final indices = <int>[];
      int vertexOffset = 0;
      
      // Separate line and non-line objects
      final lineObjects = _sceneData!.objects.where((obj) => obj.type == SceneObjectType.line).toList();
      final nonLineObjects = _sceneData!.objects.where((obj) => obj.type != SceneObjectType.line).toList();
      
      // Process lines using shared tessellator for consistency with flutter_scene
      if (lineObjects.isNotEmpty) {
        final tessellatedData = _lineTessellator.tessellateLines(lineObjects);
        
        // Add tessellated line data directly
        vertices.addAll(tessellatedData.vertices);
        
        // Add tessellated indices with proper offset
        final offsetIndices = tessellatedData.indices.map((index) => index.toInt() + vertexOffset).toList();
        indices.addAll(offsetIndices);
        vertexOffset += tessellatedData.vertexCount;
        
        AppLogger.info('GPU renderer: Using shared tessellator for ${lineObjects.length} lines');
      }
      
      // Process non-line objects with standard cube rendering
      for (final sceneObject in nonLineObjects) {
        _addCubeVerticesWithColor(
          vertices, 
          sceneObject.position.x, 
          sceneObject.position.y, 
          sceneObject.position.z, 
          vm.Vector3(sceneObject.scale.x, sceneObject.scale.y, sceneObject.scale.z),
          sceneObject.color
        );
        
        // Add 36 indices (12 triangles) for this object
        _addCubeIndices(indices, vertexOffset);
        vertexOffset += 8; // Cubes use 8 vertices
      }
      
      // Store vertex and index data in host buffer
      final vertexData = Float32List.fromList(vertices);
      final indexData = Uint16List.fromList(indices.map((i) => i.toInt()).toList());
      
      _vertexBufferView = _hostBuffer!.emplace(vertexData.buffer.asByteData());
      _indexBufferView = _hostBuffer!.emplace(indexData.buffer.asByteData());
      
      // Update performance metrics
      _vertexCount = vertices.length ~/ 6; // 6 floats per vertex (x,y,z,r,g,b)
      _indexCount = indices.length;
      _polygonCount = _indexCount ~/ 3;
      _drawCallCount = 1; // THE KEY: All objects in 1 draw call!
      
      AppLogger.info('GPU batching: ${_sceneData!.objects.length} objects -> $_polygonCount triangles in $_drawCallCount draw call');
    } catch (e) {
      AppLogger.error('GPU buffer creation failed', e);
    }
  }
  
  void _addCubeVerticesWithColor(List<double> vertices, double x, double y, double z, vm.Vector3 scale, Color color) {
    final sx = scale.x / 2;
    final sy = scale.y / 2;
    final sz = scale.z / 2;
    final r = (color.r * 255.0).round().clamp(0, 255) / 255.0;
    final g = (color.g * 255.0).round().clamp(0, 255) / 255.0;
    final b = (color.b * 255.0).round().clamp(0, 255) / 255.0;
    
    // 8 vertices of a cube, each with position (x,y,z) and color (r,g,b)
    final cubeVerts = [
      // Vertex 0: front bottom-left
      x-sx, y-sy, z+sz, r, g, b,
      // Vertex 1: front bottom-right  
      x+sx, y-sy, z+sz, r, g, b,
      // Vertex 2: front top-right
      x+sx, y+sy, z+sz, r, g, b,
      // Vertex 3: front top-left
      x-sx, y+sy, z+sz, r, g, b,
      // Vertex 4: back bottom-left
      x-sx, y-sy, z-sz, r, g, b,
      // Vertex 5: back bottom-right
      x+sx, y-sy, z-sz, r, g, b,
      // Vertex 6: back top-right
      x+sx, y+sy, z-sz, r, g, b,
      // Vertex 7: back top-left
      x-sx, y+sy, z-sz, r, g, b,
    ];
    vertices.addAll(cubeVerts);
  }
  
  void _addCubeIndices(List<int> indices, int offset) {
    // All faces use consistent counter-clockwise winding for proper barycentric coordinates
    final cubeIndices = [
      0, 1, 2,  0, 2, 3,  // Front face (CCW when viewed from outside)
      5, 4, 7,  5, 7, 6,  // Back face (CCW when viewed from outside)
      4, 0, 3,  4, 3, 7,  // Left face (CCW when viewed from outside)
      1, 5, 6,  1, 6, 2,  // Right face (CCW when viewed from outside)
      3, 2, 6,  3, 6, 7,  // Top face (CCW when viewed from outside)
      4, 5, 1,  4, 1, 0,  // Bottom face (CCW when viewed from outside)
    ];
    
    for (final index in cubeIndices) {
      indices.add(index + offset);
    }
  }

  // Line tessellation now handled by shared GpuLineTessellator
  // G-code state coloring is also handled by the tessellator
  
  Future<void> _createRenderPipelines() async {
    try {
      // Load shader library from asset bundle (path should match pubspec.yaml assets)
      const shaderBundlePath = 'build/shaderbundles/graphics_performance_spike.shaderbundle';
      final shaderLibrary = gpu.ShaderLibrary.fromAsset(shaderBundlePath);
      
      if (shaderLibrary == null) {
        throw Exception('Failed to load shader library from $shaderBundlePath');
      }
      
      // Access shaders from loaded shader library
      final vertexShader = shaderLibrary['VertexColorVertex'];
      final fillFragmentShader = shaderLibrary['VertexColorFragment'];
      final wireframeVertexShader = shaderLibrary['WireframeVertex'];
      final wireframeFragmentShader = shaderLibrary['WireframeFragment'];
      
      if (vertexShader == null || fillFragmentShader == null || wireframeVertexShader == null || wireframeFragmentShader == null) {
        throw Exception('Failed to load shaders from shader library');
      }
      
      // Create render pipelines (vertex layout handled automatically by shaders)
      _fillPipeline = gpu.gpuContext.createRenderPipeline(
        vertexShader,
        fillFragmentShader,
      );
      
      _wireframePipeline = gpu.gpuContext.createRenderPipeline(
        wireframeVertexShader,
        wireframeFragmentShader,
      );
      
      debugPrint('GPU render pipelines created successfully');
      
    } catch (e) {
      debugPrint('Failed to create render pipelines: $e');
      rethrow;
    }
  }
  
  // Note: 3D axes would be included in the GPU vertex buffer as geometry
  // Not using Canvas drawing for axes in true GPU renderer

  @override
  void render(Canvas canvas, Size size, double rotationX, double rotationY) {
    // Update internal rotation state
    _rotationX = rotationX;
    _rotationY = rotationY;
    // Clear the screen with black background first
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );
    
    if (_vertexBufferView == null || _indexBufferView == null) {
      // Draw placeholder text while GPU buffers are being created
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Initializing GPU rendering...',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(20, 20));
      return;
    }
    
    // Use actual GPU rendering with flutter_gpu APIs only
    try {
      _renderWithGPU(canvas, size, _rotationX, _rotationY);
    } catch (e) {
      AppLogger.error('GPU rendering error', e);
      // Show error message instead of Canvas fallback
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'GPU rendering failed: $e',
          style: TextStyle(color: Colors.red, fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(20, 50));
    }
    
    // Draw performance info overlay
    _drawPerformanceInfo(canvas, size);
  }
  
  void _renderWithGPU(Canvas canvas, Size size, double rotationX, double rotationY) {
    try {
      // Create render texture for GPU rendering
      final renderTexture = gpu.gpuContext.createTexture(
        gpu.StorageMode.devicePrivate,
        size.width.toInt(),
        size.height.toInt(),
        enableRenderTargetUsage: true,
        enableShaderReadUsage: true,
        coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture,
      );
      
      
      // Create depth texture for 3D rendering
      final depthTexture = gpu.gpuContext.createTexture(
        gpu.StorageMode.deviceTransient,
        size.width.toInt(), 
        size.height.toInt(),
        format: gpu.gpuContext.defaultDepthStencilFormat,
        enableRenderTargetUsage: true,
        coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture,
      );
      
      // Create command buffer
      final commandBuffer = gpu.gpuContext.createCommandBuffer();
      
      // Create render target with color and depth
      final renderTarget = gpu.RenderTarget.singleColor(
        gpu.ColorAttachment(texture: renderTexture),
        depthStencilAttachment: gpu.DepthStencilAttachment(texture: depthTexture),
      );
      
      // Begin render pass
      final renderPass = commandBuffer.createRenderPass(renderTarget);
      
      // Bind the appropriate render pipeline
      final pipeline = _wireframeMode ? _wireframePipeline : _fillPipeline;
      if (pipeline == null) {
        throw Exception('Render pipeline not created');
      }
      renderPass.bindPipeline(pipeline);
      
      // Set up transformation matrices for 3D rendering
      final mvpMatrix = _createMVPMatrix(size, rotationX, rotationY);
      
      // Create uniform buffer with transformation matrix
      final mvpData = Float32List(16);
      mvpMatrix.copyIntoArray(mvpData);
      final uniformView = _hostBuffer!.emplace(mvpData.buffer.asByteData());
      
      // Bind uniform buffer using shader uniform slot
      final vertexShader = _wireframeMode ? _wireframePipeline!.vertexShader : _fillPipeline!.vertexShader;
      final uniformSlot = vertexShader.getUniformSlot('UniformData');
      renderPass.bindUniform(uniformSlot, uniformView);
      
      // Bind vertex buffer 
      renderPass.bindVertexBuffer(_vertexBufferView!, _vertexCount);
      
      // Bind index buffer for indexed drawing
      renderPass.bindIndexBuffer(_indexBufferView!, gpu.IndexType.int16, _indexCount);
      
      // THE KEY: Draw ALL 120,000 triangles in ONE GPU draw call with actual shaders
      renderPass.draw();
      
      // GPU rendering performance logging removed for production
      
      // Submit GPU commands
      commandBuffer.submit();
      
      // Copy GPU render texture to canvas
      final image = renderTexture.asImage();
      canvas.drawImage(image, Offset.zero, Paint());
      
      // Performance metrics logged elsewhere
      
    } catch (e) {
      debugPrint('GPU rendering failed: $e');
      rethrow;
    }
  }
  
  vm.Matrix4 _createMVPMatrix(Size size, double rotationX, double rotationY) {
    // Model matrix (world transform with rotation)
    final rotationMatrixX = vm.Matrix4.rotationX(rotationX);
    final rotationMatrixY = vm.Matrix4.rotationY(rotationY);
    final modelMatrix = rotationMatrixY * rotationMatrixX;
    
    // View matrix (camera transform) - use scene camera configuration
    final cameraConfig = _sceneData!.camera;
    final cameraPos = vm.Vector3(cameraConfig.position.x, cameraConfig.position.y, cameraConfig.position.z);
    final target = vm.Vector3(cameraConfig.target.x, cameraConfig.target.y, cameraConfig.target.z);
    final up = vm.Vector3(cameraConfig.up.x, cameraConfig.up.y, cameraConfig.up.z);
    final viewMatrix = vm.makeViewMatrix(cameraPos, target, up);
    
    // Projection matrix (perspective) - use scene camera configuration
    final aspectRatio = size.width / size.height;
    final fovRadians = cameraConfig.fov * (math.pi / 180.0);
    final nearPlane = 1.0;
    final farPlane = 1000.0;
    final projMatrix = vm.makePerspectiveMatrix(fovRadians, aspectRatio, nearPlane, farPlane);
    
    // Combined MVP matrix
    return projMatrix * viewMatrix * modelMatrix;
  }
  
  // Removed Canvas fallback - GPU only rendering
  
  void _drawPerformanceInfo(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(offset: Offset(2, 2), blurRadius: 4, color: Colors.black),
      ],
    );
    
    final objectCount = _sceneData?.objects.length ?? 0;
    final textSpan = TextSpan(
      text: 'ACTUAL GPU BATCHING: $_polygonCount triangles in $_drawCallCount draw call!\n$objectCount scene objects rendered via flutter_gpu\nNo Canvas shortcuts - true GPU geometry rendering',
      style: textStyle,
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(10, size.height - 80));
  }
  
  @override
  int get actualDrawCalls => _drawCallCount;
  @override
  int get actualPolygons => _polygonCount;
  int get targetDrawCalls => 10000;
  bool get wireframeMode => _wireframeMode;
  
  void toggleWireframe() {
    _wireframeMode = !_wireframeMode;
    // Note: Wireframe mode would require different GPU shaders/render state
    // For true GPU wireframe, we'd need to modify the render pipeline
    debugPrint('Wireframe mode: $_wireframeMode');
  }
  
  // Renderer interface implementation
  @override
  Future<void> setupScene(SceneData sceneData) async {
    _sceneData = sceneData;
    debugPrint('GPU renderer setup: ${sceneData.objects.length} objects');
    // Recreate geometry and buffers with new scene data
    if (_initialized) {
      _createGpuBuffers();
    }
  }
  
  @override
  void updateRotation(double rotationX, double rotationY) {
    _rotationX = rotationX;
    _rotationY = rotationY;
  }
  
  @override
  Widget createWidget() {
    // GPU renderer uses CustomPaint, not its own widget
    return Container(
      color: Colors.black,
      child: const Center(
        child: Text(
          'GPU Renderer uses CustomPaint',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
  @override
  bool get initialized => _initialized;
  
  // Note: Wireframe rendering would be handled by GPU shaders/render state
  // Not using Canvas drawing methods in true GPU renderer
  
  @override
  void dispose() {
    _hostBuffer = null;
    _vertexBufferView = null;
    _indexBufferView = null;
    _fillPipeline = null;
    _wireframePipeline = null;
    _lineTessellator.dispose();
  }
}