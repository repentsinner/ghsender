import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math_64.dart' as vm;
import '../scene/scene_manager.dart';
import '../utils/logger.dart';

/// High-performance line tessellation using flutter_gpu for batched rendering
/// Can be used by both GPU and flutter_scene renderers for consistent line geometry
class GpuLineTessellator {
  // GPU resources for line rendering
  gpu.HostBuffer? _hostBuffer;
  gpu.BufferView? _vertexBufferView;
  gpu.BufferView? _indexBufferView;
  gpu.RenderPipeline? _linePipeline;
  
  // Tessellation statistics
  int _vertexCount = 0;
  int _indexCount = 0;
  int _lineCount = 0;
  
  bool _initialized = false;

  /// Initialize GPU resources for line tessellation
  Future<bool> initialize() async {
    try {
      await _createLinePipeline();
      _initialized = true;
      AppLogger.info('GPU line tessellator initialized');
      return true;
    } catch (e) {
      AppLogger.error('GPU line tessellator initialization failed', e);
      return false;
    }
  }

  /// Create tessellated line geometry from scene objects
  /// Returns TessellatedLineData that can be used by any renderer
  TessellatedLineData tessellateLines(List<SceneObject> lineObjects) {
    if (!_initialized) {
      throw StateError('GPU line tessellator not initialized');
    }

    final vertices = <double>[];
    final indices = <int>[];
    int vertexOffset = 0;

    // Process each line object
    for (final lineObject in lineObjects) {
      if (lineObject.type == SceneObjectType.line) {
        // Add tessellated vertices for this line
        _addLineVerticesWithColor(vertices, lineObject);
        
        // Add quad indices (2 triangles per line)
        _addLineIndices(indices, vertexOffset);
        vertexOffset += 4; // Each line uses 4 vertices
      }
    }

    // Update statistics
    _vertexCount = vertices.length ~/ 6; // 6 floats per vertex (x,y,z,r,g,b)
    _indexCount = indices.length;
    _lineCount = lineObjects.where((obj) => obj.type == SceneObjectType.line).length;

    AppLogger.info('GPU line tessellation: $_lineCount lines -> $_vertexCount vertices, $_indexCount indices');

    return TessellatedLineData(
      vertices: Float32List.fromList(vertices),
      indices: Uint16List.fromList(indices.map((i) => i.toInt()).toList()),
      vertexCount: _vertexCount,
      indexCount: _indexCount,
      lineCount: _lineCount,
    );
  }

  /// Create GPU buffers for direct flutter_gpu rendering
  /// Returns LineRenderData with GPU buffers ready for rendering
  Future<LineRenderData?> createGpuBuffers(List<SceneObject> lineObjects) async {
    if (!_initialized) {
      throw StateError('GPU line tessellator not initialized');
    }

    try {
      // Generate tessellated line data
      final tessellatedData = tessellateLines(lineObjects);
      
      // Create GPU host buffer
      _hostBuffer = gpu.gpuContext.createHostBuffer();
      
      // Upload vertex and index data to GPU
      _vertexBufferView = _hostBuffer!.emplace(tessellatedData.vertices.buffer.asByteData());
      _indexBufferView = _hostBuffer!.emplace(tessellatedData.indices.buffer.asByteData());

      return LineRenderData(
        vertexBufferView: _vertexBufferView!,
        indexBufferView: _indexBufferView!,
        pipeline: _linePipeline!,
        vertexCount: tessellatedData.vertexCount,
        indexCount: tessellatedData.indexCount,
        lineCount: tessellatedData.lineCount,
      );
    } catch (e) {
      AppLogger.error('Failed to create GPU line buffers', e);
      return null;
    }
  }

  /// Create flutter_scene compatible geometry from tessellated line data
  /// This allows flutter_scene to benefit from GPU tessellation
  FlutterSceneLineGeometry createFlutterSceneGeometry(List<SceneObject> lineObjects) {
    final tessellatedData = tessellateLines(lineObjects);
    
    // Group vertices by color for flutter_scene material batching
    final colorGroups = <Color, List<LineVertex>>{}; 
    
    // Convert tessellated vertices back to structured data
    for (int i = 0; i < tessellatedData.vertices.length; i += 6) {
      final vertex = LineVertex(
        position: vm.Vector3(
          tessellatedData.vertices[i],     // x
          tessellatedData.vertices[i + 1], // y  
          tessellatedData.vertices[i + 2], // z
        ),
        color: Color.fromRGBO(
          (tessellatedData.vertices[i + 3] * 255).round(), // r
          (tessellatedData.vertices[i + 4] * 255).round(), // g
          (tessellatedData.vertices[i + 5] * 255).round(), // b
          1.0,
        ),
      );
      
      if (colorGroups.containsKey(vertex.color)) {
        colorGroups[vertex.color]!.add(vertex);
      } else {
        colorGroups[vertex.color] = [vertex];
      }
    }

    return FlutterSceneLineGeometry(
      colorGroups: colorGroups,
      indices: tessellatedData.indices,
      totalVertices: tessellatedData.vertexCount,
      totalLines: tessellatedData.lineCount,
    );
  }

  /// Add tessellated line vertices with proper width and coloring
  void _addLineVerticesWithColor(List<double> vertices, SceneObject lineObject) {
    // Use the same tessellation logic as the GPU renderer
    final scale = lineObject.scale;
    final position = lineObject.position;
    final rotation = lineObject.rotation;
    
    final lineLength = scale.x;  // X = length 
    final lineWidth = scale.y;   // Y = width
    
    // Create line geometry in local space
    final halfLength = lineLength / 2;
    final halfWidth = lineWidth / 2;
    
    // Define 4 corners of the line quad in local space (X-axis aligned)
    final localCorners = [
      vm.Vector3(-halfLength, -halfWidth, 0), // Bottom-left
      vm.Vector3(-halfLength, halfWidth, 0),  // Top-left  
      vm.Vector3(halfLength, halfWidth, 0),   // Top-right
      vm.Vector3(halfLength, -halfWidth, 0),  // Bottom-right
    ];
    
    // Transform each corner to world space using position + rotation
    final rotationMatrix = vm.Matrix4.identity();
    rotationMatrix.setRotation(rotation.asRotationMatrix());
    
    final worldCorners = localCorners.map((corner) {
      final transformed = rotationMatrix.transformed3(corner);
      return transformed + position;
    }).toList();
    
    // Convert color to normalized floats
    final color = lineObject.color;
    final r = (color.r * 255.0).round().clamp(0, 255) / 255.0;
    final g = (color.g * 255.0).round().clamp(0, 255) / 255.0;
    final b = (color.b * 255.0).round().clamp(0, 255) / 255.0;
    
    // Create 4 vertices for line quad using the transformed corners
    final lineVerts = [
      // Vertex 0: Bottom-left
      worldCorners[0].x, worldCorners[0].y, worldCorners[0].z, r, g, b,
      // Vertex 1: Top-left
      worldCorners[1].x, worldCorners[1].y, worldCorners[1].z, r, g, b,
      // Vertex 2: Top-right  
      worldCorners[2].x, worldCorners[2].y, worldCorners[2].z, r, g, b,
      // Vertex 3: Bottom-right
      worldCorners[3].x, worldCorners[3].y, worldCorners[3].z, r, g, b,
    ];
    vertices.addAll(lineVerts);
  }
  
  /// Add indices for line quad (2 triangles)
  void _addLineIndices(List<int> indices, int offset) {
    // Create quad with proper winding order
    final lineIndices = [
      0, 1, 2,  // First triangle (CCW)
      0, 2, 3,  // Second triangle (CCW)
    ];
    
    for (final index in lineIndices) {
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

/// Raw tessellated line data that can be used by any renderer
class TessellatedLineData {
  final Float32List vertices;    // [x,y,z,r,g,b, x,y,z,r,g,b, ...]
  final Uint16List indices;      // Triangle indices
  final int vertexCount;
  final int indexCount;
  final int lineCount;
  
  const TessellatedLineData({
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

/// flutter_scene compatible line geometry
class FlutterSceneLineGeometry {
  final Map<Color, List<LineVertex>> colorGroups;
  final Uint16List indices;
  final int totalVertices;
  final int totalLines;
  
  const FlutterSceneLineGeometry({
    required this.colorGroups,
    required this.indices,
    required this.totalVertices,
    required this.totalLines,
  });
}

/// Individual vertex data for flutter_scene integration
class LineVertex {
  final vm.Vector3 position;
  final Color color;
  
  const LineVertex({
    required this.position,
    required this.color,
  });
}