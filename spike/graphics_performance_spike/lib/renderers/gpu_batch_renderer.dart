import 'dart:math' as math;
import '../utils/logger.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;
import '../scene/scene_manager.dart';
import 'renderer_interface.dart';
import 'gpu_line_tessellator.dart';
import 'line_style.dart';

/// G-code processing states for visual feedback
enum ProcessingState {
  completed,  // Already processed (dimmed)
  current,    // Currently executing (highlighted)
  upcoming,   // Next ~30s (bright)
  future,     // Not yet reached (normal)
}

class GpuBatchRenderer implements Renderer {
  // Buffers for lines (6-float format)
  gpu.HostBuffer? _hostBuffer;
  gpu.BufferView? _lineVertexBufferView;
  gpu.BufferView? _lineIndexBufferView;
  
  // Pipeline for line rendering
  gpu.RenderPipeline? _linePipeline;        // Uses VertexColor shaders (6-float format)
  gpu.RenderPipeline? _wireframePipeline;   // Uses Wireframe shaders (6-float format)
  
  int _vertexCount = 0;
  int _indexCount = 0;
  int _drawCallCount = 0;
  int _polygonCount = 0;
  
  // Renderer state
  bool _initialized = false;
  bool _wireframeMode = false;
  
  // Scene data received from SceneManager
  SceneData? _sceneData;
  
  // GPU line primitive generator for consistent line rendering with flutter_scene
  final GpuLinePrimitive _linePrimitive = GpuLinePrimitive();
  
  // Dynamic line style settings
  LineStyle _currentLineStyle = LineStyles.technical;
  
  // Interactive rotation state
  double _rotationX = 0.0;
  double _rotationY = 0.0;
  
  @override
  Future<bool> initialize() async {
    try {
      // Only create render pipelines during initialization
      // Geometry and buffers will be created when scene data is provided
      await _createRenderPipelines();
      
      // Initialize shared line primitive generator
      final lineInitSuccess = await _linePrimitive.initialize();
      if (!lineInitSuccess) {
        AppLogger.warning('GPU line primitive failed to initialize in GPU renderer');
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
      
      // Process only line objects
      final lineObjects = _sceneData!.objects.where((obj) => obj.type == SceneObjectType.line).toList();
      
      AppLogger.info('GPU renderer: Scene has ${_sceneData!.objects.length} total objects');
      AppLogger.info('GPU renderer: ${lineObjects.length} line objects');
      
      var totalVertexCount = 0;
      var totalIndexCount = 0;
      var drawCallCount = 0;
      
      // Process lines using GPU tessellator (6-float format with vertex color shaders)
      if (lineObjects.isNotEmpty) {
        AppLogger.info('GPU renderer: Processing ${lineObjects.length} lines with tessellator');
        
        // Create line style mapping using current dynamic settings
        final lineStyles = <String, LineStyle>{
          for (final obj in lineObjects) obj.id: _currentLineStyle,
        };
        
        // Generate minimal line primitive data (Three.js Line2 approach)
        final lineData = _linePrimitive.generateLinePrimitives(lineObjects, lineStyles: lineStyles);
        
        if (lineData.vertexCount > 0) {
          // Create GPU buffers for line rendering (6-float format: start+end points)
          _lineVertexBufferView = _hostBuffer!.emplace(lineData.vertices.buffer.asByteData());
          _lineIndexBufferView = _hostBuffer!.emplace(lineData.indices.buffer.asByteData());
          
          totalVertexCount += lineData.vertexCount;
          totalIndexCount += lineData.indexCount;
          drawCallCount += 1;
          
          AppLogger.info('GPU renderer: Line primitives complete - ${lineData.lineCount} lines, ${lineData.vertexCount} vertices (Line2 approach)');
        }
      }
      
      
      // Update performance metrics
      _vertexCount = totalVertexCount;
      _indexCount = totalIndexCount;
      _polygonCount = totalIndexCount ~/ 3;
      _drawCallCount = drawCallCount;
      
      AppLogger.info('ACTUAL GPU batching metrics: ${_sceneData!.objects.length} objects -> $_polygonCount triangles in $_drawCallCount draw calls');
      AppLogger.info('GPU tessellation details: $_vertexCount vertices, $_indexCount indices ($_indexCount ÷ 3 = $_polygonCount triangles)');
    } catch (e) {
      AppLogger.error('GPU buffer creation failed', e);
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
      
      // Create render pipelines for line rendering
      _linePipeline = gpu.gpuContext.createRenderPipeline(
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
    
    if (_lineVertexBufferView == null) {
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
      
      
      // Set up transformation matrices for 3D rendering
      final mvpMatrix = _createMVPMatrix(size, rotationX, rotationY);
      
      // Create uniform buffer with transformation matrix + line style parameters
      final uniformData = Float32List(24); // 16 (matrix) + 4 (color) + 4 (width, sharpness, aspectRatio, padding)
      mvpMatrix.copyIntoArray(uniformData, 0);
      
      // Add line style uniforms
      final lineColor = _currentLineStyle.colorComponents;
      uniformData[16] = lineColor[0]; // r
      uniformData[17] = lineColor[1]; // g  
      uniformData[18] = lineColor[2]; // b
      uniformData[19] = lineColor[3]; // a
      uniformData[20] = _currentLineStyle.width;
      uniformData[21] = _currentLineStyle.sharpness;
      uniformData[22] = size.width / size.height; // aspectRatio
      uniformData[23] = 0.0; // padding
      
      final uniformView = _hostBuffer!.emplace(uniformData.buffer.asByteData());
      
      // Render lines with line pipeline (6-float format)
      if (_lineVertexBufferView != null && _lineIndexBufferView != null) {
        final pipeline = _wireframeMode ? _wireframePipeline! : _linePipeline!;
        renderPass.bindPipeline(pipeline);
        
        // Bind uniform for line shader
        final lineVertexShader = pipeline.vertexShader;
        final lineUniformSlot = lineVertexShader.getUniformSlot('UniformData');
        renderPass.bindUniform(lineUniformSlot, uniformView);
        
        // Bind line buffers and draw
        renderPass.bindVertexBuffer(_lineVertexBufferView!, _lineVertexBufferView!.lengthInBytes ~/ (6 * 4)); // 6 floats * 4 bytes
        renderPass.bindIndexBuffer(_lineIndexBufferView!, gpu.IndexType.int16, _lineIndexBufferView!.lengthInBytes ~/ 2); // 2 bytes per index
        renderPass.draw();
      }
      
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

  /// Update the line style for dynamic line settings control
  void updateLineStyle(LineStyle newStyle) {
    _currentLineStyle = newStyle;
  }
  
  // Renderer interface implementation
  @override
  Future<void> setupScene(SceneData sceneData) async {
    _sceneData = sceneData;
    AppLogger.info('GPU renderer setupScene called with ${sceneData.objects.length} objects');
    
    if (sceneData.objects.isNotEmpty) {
      AppLogger.info('GPU renderer: First object - type: ${sceneData.objects.first.type}, id: ${sceneData.objects.first.id}');
    }
    
    // Recreate geometry and buffers with new scene data
    if (_initialized) {
      AppLogger.info('GPU renderer: Calling _createGpuBuffers...');
      _createGpuBuffers();
    } else {
      AppLogger.warning('GPU renderer: Not initialized yet, skipping buffer creation');
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
    _lineVertexBufferView = null;
    _lineIndexBufferView = null;
    _linePipeline = null;
    _wireframePipeline = null;
    _linePrimitive.dispose();
  }
}