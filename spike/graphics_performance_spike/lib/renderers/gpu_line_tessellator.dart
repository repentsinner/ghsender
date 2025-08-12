import 'dart:typed_data';
import 'package:flutter_gpu/gpu.dart' as gpu;
import '../scene/scene_manager.dart';
import '../utils/logger.dart';
import 'line_style.dart';

/// Three.js Line2-style line primitive generator
/// Generates minimal geometry for GPU vertex shader billboard extrusion
class GpuLinePrimitive {
  // GPU resources for line rendering
  gpu.HostBuffer? _hostBuffer;
  gpu.BufferView? _vertexBufferView;
  gpu.BufferView? _indexBufferView;
  gpu.RenderPipeline? _linePipeline;
  
  // Line primitive statistics
  int _vertexCount = 0;
  int _indexCount = 0;
  int _lineCount = 0;
  
  bool _initialized = false;

  /// Initialize GPU resources for line rendering
  Future<bool> initialize() async {
    try {
      await _createLinePipeline();
      _initialized = true;
      AppLogger.info('GPU line primitive system initialized');
      return true;
    } catch (e) {
      AppLogger.error('GPU line primitive initialization failed', e);
      return false;
    }
  }

  /// Generate minimal line primitive data for Three.js Line2-style rendering
  /// Returns LineData that contains just start/end points + attributes
  LineData generateLinePrimitives(List<SceneObject> lineObjects, {Map<String, LineStyle>? lineStyles}) {
    if (!_initialized) {
      throw StateError('GPU line primitive not initialized');
    }

    final vertices = <double>[];
    final indices = <int>[];
    int vertexOffset = 0;

    // Process each line object - generate minimal quad per line
    for (final lineObject in lineObjects) {
      if (lineObject.type == SceneObjectType.line) {
        // Get appropriate line style (default to technical if not specified)
        final style = lineStyles?[lineObject.id] ?? LineStyles.technical;
        
        // Add minimal line data (4 vertices per line segment)
        _addLinePrimitive(vertices, lineObject, style);
        
        // Add quad indices (2 triangles per line)
        _addQuadIndices(indices, vertexOffset);
        vertexOffset += 4; // Each line uses 4 vertices
      }
    }

    // Update statistics  
    _vertexCount = vertices.length ~/ 6; // 6 floats per vertex: [startX,startY,startZ, endX,endY,endZ] per vertex
    _indexCount = indices.length;
    _lineCount = lineObjects.where((obj) => obj.type == SceneObjectType.line).length;

    AppLogger.info('GPU line primitives: $_lineCount lines -> $_vertexCount vertices, $_indexCount indices');

    return LineData(
      vertices: Float32List.fromList(vertices),
      indices: Uint16List.fromList(indices.map((i) => i.toInt()).toList()),
      vertexCount: _vertexCount,
      indexCount: _indexCount,
      lineCount: _lineCount,
    );
  }

  /// Create GPU buffers for direct flutter_gpu rendering with line styles
  /// Returns LineRenderData with GPU buffers ready for rendering
  Future<LineRenderData?> createGpuBuffers(List<SceneObject> lineObjects, {Map<String, LineStyle>? lineStyles}) async {
    if (!_initialized) {
      throw StateError('GPU line primitive not initialized');
    }

    try {
      // Generate minimal line primitive data
      final lineData = generateLinePrimitives(lineObjects, lineStyles: lineStyles);
      
      // Create GPU host buffer
      _hostBuffer = gpu.gpuContext.createHostBuffer();
      
      // Upload vertex and index data to GPU
      _vertexBufferView = _hostBuffer!.emplace(lineData.vertices.buffer.asByteData());
      _indexBufferView = _hostBuffer!.emplace(lineData.indices.buffer.asByteData());

      return LineRenderData(
        vertexBufferView: _vertexBufferView!,
        indexBufferView: _indexBufferView!,
        pipeline: _linePipeline!,
        vertexCount: lineData.vertexCount,
        indexCount: lineData.indexCount,
        lineCount: lineData.lineCount,
      );
    } catch (e) {
      AppLogger.error('Failed to create GPU line buffers', e);
      return null;
    }
  }



  /// Add Three.js Line2-style line primitive (minimal geometry)
  /// Just stores start/end points - vertex shader handles screen-space billboard
  void _addLinePrimitive(List<double> vertices, SceneObject lineObject, LineStyle style) {
    // Use startPoint and endPoint directly - no need for position/scale/rotation transformation
    if (lineObject.startPoint == null || lineObject.endPoint == null) {
      AppLogger.warning('Line object ${lineObject.id} missing startPoint or endPoint - skipping');
      return;
    }
    
    final worldStart = lineObject.startPoint!;
    final worldEnd = lineObject.endPoint!;
    
    // ULTRA-MINIMAL FORMAT: Just [startX,startY,startZ, endX,endY,endZ] per vertex
    // Color, width, and sharpness will be passed as uniforms
    final lineVerts = [
      // All 4 vertices store the same line segment data
      // Vertex shader will use gl_VertexID to determine which corner to generate
      worldStart.x, worldStart.y, worldStart.z, worldEnd.x, worldEnd.y, worldEnd.z, // Vertex 0
      worldStart.x, worldStart.y, worldStart.z, worldEnd.x, worldEnd.y, worldEnd.z, // Vertex 1
      worldStart.x, worldStart.y, worldStart.z, worldEnd.x, worldEnd.y, worldEnd.z, // Vertex 2  
      worldStart.x, worldStart.y, worldStart.z, worldEnd.x, worldEnd.y, worldEnd.z, // Vertex 3
    ];
    vertices.addAll(lineVerts);
  }
  
  /// Add indices for line quad (2 triangles) 
  void _addQuadIndices(List<int> indices, int offset) {
    // Standard quad triangulation for billboard
    final quadIndices = [
      0, 1, 2,  // First triangle (CCW)
      0, 2, 3,  // Second triangle (CCW)
    ];
    
    for (final index in quadIndices) {
      indices.add(index + offset);
    }
  }

  /// Create GPU pipeline for line rendering
  Future<void> _createLinePipeline() async {
    try {
      // Load shader library (same as GPU renderer)
      const shaderBundlePath = 'build/shaderbundles/graphics_performance_spike.shaderbundle';
      final shaderLibrary = gpu.ShaderLibrary.fromAsset(shaderBundlePath);
      
      if (shaderLibrary == null) {
        throw Exception('Failed to load shader library from $shaderBundlePath');
      }
      
      // Use vertex color shaders for line rendering
      final vertexShader = shaderLibrary['VertexColorVertex'];
      final fragmentShader = shaderLibrary['VertexColorFragment'];
      
      if (vertexShader == null || fragmentShader == null) {
        throw Exception('Failed to load line rendering shaders');
      }
      
      // Create pipeline for line rendering
      _linePipeline = gpu.gpuContext.createRenderPipeline(
        vertexShader,
        fragmentShader,
      );
      
      AppLogger.debug('GPU line rendering pipeline created');
      
    } catch (e) {
      AppLogger.error('Failed to create line rendering pipeline', e);
      rethrow;
    }
  }

  /// Cleanup GPU resources
  void dispose() {
    _hostBuffer = null;
    _vertexBufferView = null; 
    _indexBufferView = null;
    _linePipeline = null;
    _initialized = false;
  }
}

/// Minimal line primitive data (Three.js Line2 approach)
class LineData {
  final Float32List vertices;    // [startX,startY,startZ, endX,endY,endZ, ...] per vertex
  final Uint16List indices;      // Triangle indices for quads
  final int vertexCount;
  final int indexCount;
  final int lineCount;
  
  const LineData({
    required this.vertices,
    required this.indices,
    required this.vertexCount,
    required this.indexCount,
    required this.lineCount,
  });
}

/// GPU render data for direct flutter_gpu rendering
class LineRenderData {
  final gpu.BufferView vertexBufferView;
  final gpu.BufferView indexBufferView;
  final gpu.RenderPipeline pipeline;
  final int vertexCount;
  final int indexCount;
  final int lineCount;
  
  const LineRenderData({
    required this.vertexBufferView,
    required this.indexBufferView,
    required this.pipeline,
    required this.vertexCount,
    required this.indexCount,
    required this.lineCount,
  });
}

