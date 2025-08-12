/*
 * LineGeometry implementation for Flutter Scene
 * Based on Three.js LineSegments2 and Line2 architecture
 * 
 * Provides both continuous polyline (Line2) and discrete segments (LineSegments2) modes
 * Uses instanced rendering with quad tessellation in vertex shader
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
    // Use standard flutter_scene vertex shader (not instanced)
    // LineMaterial will set the correct fragment shader
    _generateTraditionalGeometry();

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

  void _generateTraditionalGeometry() {
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

      // Generate 4 corner positions
      final corners = [
        start - perpendicular * halfWidth, // Bottom-left
        start + perpendicular * halfWidth, // Top-left
        end + perpendicular * halfWidth, // Top-right
        end - perpendicular * halfWidth, // Bottom-right
      ];

      // Add vertex data: position (3) + normal (3) + uv (2) + color (4) = 12 floats per vertex
      // This matches UnskinnedGeometry's expected format: kUnskinnedPerVertexSize = 48 bytes = 12 floats
      for (int j = 0; j < 4; j++) {
        final corner = corners[j];
        vertices.addAll([
          corner.x, corner.y, corner.z, // position (3 floats)
          0.0, 0.0, 1.0, // normal (3 floats, pointing up)
          j % 2 == 0 ? 0.0 : 1.0, // u (1 float, 0 for left, 1 for right)
          j < 2 ? 0.0 : 1.0, // v (1 float, 0 for start, 1 for end)
          1.0, 1.0, 1.0, 1.0, // color (4 floats, white RGBA)
        ]);
      }

      // Add quad indices (2 triangles)
      indices.addAll([
        vertexOffset + 0, vertexOffset + 1, vertexOffset + 2, // Triangle 1
        vertexOffset + 0, vertexOffset + 2, vertexOffset + 3, // Triangle 2
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
      final customVertexShader = _shaderLibrary!['UnskinnedVertex'];
      if (customVertexShader != null) {
        return customVertexShader;
      } else {
        AppLogger.warning(
          'Custom vertex shader not found in bundle, using flutter_scene default',
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
