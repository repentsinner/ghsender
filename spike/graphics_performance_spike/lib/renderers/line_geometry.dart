/*
 * LineGeometry implementation for Flutter Scene
 * Based on Three.js LineSegments2 and Line2 architecture
 * 
 * Provides both continuous polyline (Line2) and discrete segments
 * (LineSegments2) modes
 */

import 'dart:typed_data';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;
import 'package:flutter_scene/scene.dart';
import '../utils/logger.dart';

enum LineGeometryMode {
  polyline, // Line2 equivalent - continuous polyline
  segments, // LineSegments2 equivalent - discrete segment pairs
}

class LineGeometry extends UnskinnedGeometry {
  final LineGeometryMode mode;
  final List<vm.Vector3> points;

  // Shader loading
  static gpu.ShaderLibrary? _shaderLibrary;
  static bool _shadersLoaded = false;
  static bool _shaderLoadingAttempted = false;

  // Private constructor
  LineGeometry._(this.mode, this.points) {
    // Use modified flutter_scene vertex shader (not instanced)
    _generateParametricGeometry();

    // Attempt to load custom shaders if not already attempted
    if (!_shaderLoadingAttempted) {
      _loadShaders();
    }
  }

  // Factory constructors following Three.js Line2/LineSegments2 pattern
  factory LineGeometry.polyline(List<vm.Vector3> points) {
    if (points.length < 2) {
      throw ArgumentError('Polyline requires at least 2 points');
    }
    return LineGeometry._(LineGeometryMode.polyline, points);
  }

  factory LineGeometry.segments(List<vm.Vector3> points) {
    if (points.length < 2 || points.length % 2 != 0) {
      throw ArgumentError(
        'Segments mode requires even number of points (pairs)',
      );
    }
    return LineGeometry._(LineGeometryMode.segments, points);
  }

  void _generateParametricGeometry() {
    // Generate line segments based on mode
    final segments = _generateLineSegments();

    if (segments.isEmpty) return;

    // Generate actual quad vertices for each line segment (non-instanced)
    final vertices = <double>[];
    final indices = <int>[];

    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final vertexOffset = i * 4; // 4 vertices per quad

      // Create 4 vertices for this line segment's quad
      // We'll use a simple approach: create a thin rectangle along the line
      final start = segment.start;
      final end = segment.end;

      // Calculate line direction and perpendicular for width
      final direction = end - start;
      final length = direction.length;

      if (length < 0.001) continue; // Skip degenerate lines

      direction.normalize();

      // Create perpendicular vector (assuming 2D-ish for now - can enhance later)
      final perpendicular = vm.Vector3(
        -direction.y,
        direction.x,
        0.0,
      ).normalized();
      final halfWidth = 0.5; // Will be scaled by lineWidth uniform

      // Add vertex data: position (3) + normal (3) + uv (2) + color (4) = 12 floats per vertex
      // This matches UnskinnedGeometry's expected format: kUnskinnedPerVertexSize = 48 bytes = 12 floats
      // Repurpose attributes to carry line segment data instead of pre-calculated corners
      for (int j = 0; j < 4; j++) {
        vertices.addAll([
          start.x, start.y, start.z, // position -> line start point (3 floats)
          end.x, end.y, end.z, // normal -> line end point (3 floats)
          j % 2 == 0
              ? -1.0
              : 1.0, // uv.x -> side direction (1 float: -1 = left, +1 = right)
          j < 2
              ? 0.0
              : 1.0, // uv.y -> u coordinate (1 float: 0 = start, 1 = end)
          1.0, 1.0, 1.0, 1.0, // color -> keep as white (4 floats)
        ]);
      }

      // Add quad indices (2 triangles) with correct winding (clockwise)
      indices.addAll([
        vertexOffset + 0, vertexOffset + 2, vertexOffset + 1, // Triangle 1
        vertexOffset + 1, vertexOffset + 2, vertexOffset + 3, // Triangle 2
      ]);
    }

    if (vertices.isEmpty) return;

    // Convert to typed data
    final vertexData = Float32List.fromList(vertices);
    final indexData = Uint16List.fromList(
      indices.map((i) => i.clamp(0, 65535)).toList(),
    );

    // Create GPU buffers
    final deviceBuffer = gpu.gpuContext.createDeviceBuffer(
      gpu.StorageMode.hostVisible,
      vertexData.lengthInBytes + indexData.lengthInBytes,
    );

    // Upload vertex data
    deviceBuffer.overwrite(
      ByteData.sublistView(vertexData),
      destinationOffsetInBytes: 0,
    );

    // Upload index data
    final indexOffset = vertexData.lengthInBytes;
    deviceBuffer.overwrite(
      ByteData.sublistView(indexData),
      destinationOffsetInBytes: indexOffset,
    );

    // Set geometry buffers
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

  List<LineSegment> _generateLineSegments() {
    final segments = <LineSegment>[];

    switch (mode) {
      case LineGeometryMode.polyline:
        // Convert consecutive points to line segments: [P1,P2,P3,P4] → [(P1→P2), (P2→P3), (P3→P4)]
        for (int i = 0; i < points.length - 1; i++) {
          segments.add(LineSegment(points[i], points[i + 1]));
        }
        break;

      case LineGeometryMode.segments:
        // Use point pairs directly: [P1,P2,P3,P4] → [(P1→P2), (P3→P4)]
        for (int i = 0; i < points.length; i += 2) {
          segments.add(LineSegment(points[i], points[i + 1]));
        }
        break;
    }

    return segments;
  }

  /// Load custom vertex shaders matching flutter_scene's UnskinnedGeometry
  static Future<void> _loadShaders() async {
    _shaderLoadingAttempted = true;
    try {
      _shaderLibrary = gpu.ShaderLibrary.fromAsset(
        'build/shaderbundles/graphics_performance_spike.shaderbundle',
      );
      _shadersLoaded = true;
      AppLogger.info('Custom vertex shaders loaded successfully');
    } catch (e) {
      AppLogger.warning(
        'Failed to load custom vertex shaders, falling back to default: $e',
      );
      // Fall back to UnskinnedGeometry behavior if shaders fail to load
      _shadersLoaded = false;
    }
  }

  /// Provide vertex shader for SceneEncoder to use in RenderPipeline creation
  /// This follows flutter_scene's architecture where Geometry provides vertex shaders
  @override
  gpu.Shader get vertexShader {
    if (!_shadersLoaded || _shaderLibrary == null) {
      // Fallback: use flutter_scene's base shader library directly
      return baseShaderLibrary['UnskinnedVertex']!;
    }

    try {
      // Use custom line vertex shader that handles screen-space expansion
      final customVertexShader = _shaderLibrary!['UnskinnedVertex'];
      if (customVertexShader != null) {
        return customVertexShader;
      } else {
        AppLogger.warning(
          'Custom line vertex shader not found in bundle, using UnskinnedVertex default',
        );
        return baseShaderLibrary['UnskinnedVertex']!;
      }
    } catch (e) {
      AppLogger.error('Failed to get custom vertex shader: $e');
      return baseShaderLibrary['UnskinnedVertex']!;
    }
  }

  // Using standard UnskinnedGeometry binding - no custom binding needed
}

// Helper class for line segment data
class LineSegment {
  final vm.Vector3 start;
  final vm.Vector3 end;

  LineSegment(this.start, this.end);
}
