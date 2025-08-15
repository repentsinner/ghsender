/*
 * FilledSquareGeometry implementation for Flutter Scene
 * 
 * Creates plane-aligned filled squares using standard UnskinnedGeometry
 * Generates 2 triangles (6 vertices) for efficient solid fill rendering
 */

import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;
import 'package:flutter_scene/scene.dart';
import '../scene/scene_manager.dart';
import '../utils/logger.dart';

class FilledSquareGeometry extends UnskinnedGeometry {
  final vm.Vector3 center;
  final double size;
  final SquarePlane plane;
  final double rotation;

  FilledSquareGeometry({
    required this.center,
    required this.size,
    required this.plane,
    this.rotation = 0.0,
  }) {
    _generateSquareGeometry();
  }

  void _generateSquareGeometry() {
    try {
      // Calculate the 4 corner points
      final corners = _calculateSquareCorners();

      // Create vertices for 2 triangles forming the square
      // Triangle 1: corners[0], corners[1], corners[2]
      // Triangle 2: corners[0], corners[2], corners[3]
      final vertices = <double>[];
      final indices = <int>[];

      // Add vertices (position + normal + uv + color = 12 floats per vertex)
      final normal = _getPlaneNormal();

      for (int i = 0; i < 4; i++) {
        final corner = corners[i];
        final uv = _getUVCoordinate(i);

        vertices.addAll([
          corner.x, corner.y, corner.z, // position (3)
          normal.x, normal.y, normal.z, // normal (3)
          uv.x, uv.y, // texture coords (2)
          1.0,
          1.0,
          1.0,
          1.0, // color (4) - white, material handles actual color
        ]);
      }

      // Triangle indices (counter-clockwise winding for proper face culling)
      indices.addAll([
        0, 1, 2, // First triangle
        0, 2, 3, // Second triangle
      ]);

      // Create GPU buffers and set geometry data
      _createBuffers(vertices, indices);

      AppLogger.info(
        'FilledSquareGeometry created: ${vertices.length ~/ 12} vertices, ${indices.length ~/ 3} triangles',
      );
    } catch (e) {
      AppLogger.error('Failed to create FilledSquareGeometry: $e');
      rethrow;
    }
  }

  List<vm.Vector3> _calculateSquareCorners() {
    final halfSize = size * 0.5;

    // Base corner offsets in 2D (before rotation)
    final baseOffsets = [
      vm.Vector2(-halfSize, -halfSize), // Bottom-left
      vm.Vector2(halfSize, -halfSize), // Bottom-right
      vm.Vector2(halfSize, halfSize), // Top-right
      vm.Vector2(-halfSize, halfSize), // Top-left
    ];

    // Apply rotation if specified
    final rotatedOffsets = baseOffsets.map((offset) {
      if (rotation != 0.0) {
        final cos = math.cos(rotation);
        final sin = math.sin(rotation);
        return vm.Vector2(
          offset.x * cos - offset.y * sin,
          offset.x * sin + offset.y * cos,
        );
      }
      return offset;
    }).toList();

    // Convert to 3D points based on plane
    return rotatedOffsets.map((offset) {
      switch (plane) {
        case SquarePlane.xy:
          return center + vm.Vector3(offset.x, offset.y, 0.0);
        case SquarePlane.xz:
          return center + vm.Vector3(offset.x, 0.0, offset.y);
        case SquarePlane.yz:
          return center + vm.Vector3(0.0, offset.x, offset.y);
      }
    }).toList();
  }

  vm.Vector3 _getPlaneNormal() {
    switch (plane) {
      case SquarePlane.xy:
        return vm.Vector3(0, 0, 1); // Z-up
      case SquarePlane.xz:
        return vm.Vector3(0, 1, 0); // Y-up
      case SquarePlane.yz:
        return vm.Vector3(1, 0, 0); // X-up
    }
  }

  vm.Vector2 _getUVCoordinate(int cornerIndex) {
    // Standard UV mapping for square
    switch (cornerIndex) {
      case 0:
        return vm.Vector2(0, 0); // Bottom-left
      case 1:
        return vm.Vector2(1, 0); // Bottom-right
      case 2:
        return vm.Vector2(1, 1); // Top-right
      case 3:
        return vm.Vector2(0, 1); // Top-left
      default:
        return vm.Vector2(0, 0);
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

    // Create GPU buffer
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
}
