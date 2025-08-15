/*
 * BillboardGeometry implementation for Flutter Scene
 * 
 * Creates a simple quad geometry for text billboards
 * Based on the same pattern as FilledSquareGeometry
 */

import 'dart:typed_data';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;
import 'package:flutter_scene/scene.dart';
import '../utils/logger.dart';

class BillboardGeometry extends UnskinnedGeometry {
  final double width;
  final double height;

  BillboardGeometry({
    required this.width,
    required this.height,
  }) {
    _generateQuadGeometry();
  }

  void _generateQuadGeometry() {
    try {
      // Create vertices for a simple quad
      // Two triangles: bottom-left, bottom-right, top-right, top-left
      final halfWidth = width / 2;
      final halfHeight = height / 2;
      
      final vertices = <double>[];
      final indices = <int>[];

      // Normal pointing towards -Z (the default view direction)
      final normal = vm.Vector3(0, 0, -1);
      
      // Define the 4 corners with UV coordinates
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
      indices.addAll([
        0, 1, 2, // First triangle: bottom-left, bottom-right, top-right
        0, 2, 3, // Second triangle: bottom-left, top-right, top-left
      ]);

      // Create buffers using the same pattern as FilledSquareGeometry
      _createBuffers(vertices, indices);

      AppLogger.info('BillboardGeometry created: ${width}x$height units, ${vertices.length ~/ 12} vertices, ${indices.length ~/ 3} triangles');
      
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