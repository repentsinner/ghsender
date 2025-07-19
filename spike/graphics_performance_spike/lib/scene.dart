import 'dart:math';
import 'package:flutter/material.dart';

class SceneConfiguration {
  static const int totalCubes = 10000;
  static const double cubeSize = 1.0;
  
  // Camera settings
  static const double cameraDistance = 300.0;
  static const double cameraY = 50.0;
  static const double fov = 400.0;
  
  // Colors for visual variety
  static final List<Color> cubeColors = [
    Colors.orange,
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.purple,
    Colors.cyan,
    Colors.yellow,
    Colors.pink,
  ];
  
  // Calculate 3D position for cube at given index
  static CubeData getCubeData(int index) {
    final normalizedIndex = index / totalCubes;
    
    // Create a 3D volume of cubes using the same algorithm as GPU renderer
    final angle1 = normalizedIndex * 20 * pi;
    final angle2 = (index * 0.618) * 2 * pi; // Golden ratio for even distribution
    final radius = 50.0 + (normalizedIndex * 150.0);
    
    // 3D world coordinates - actual XYZ positions
    final x = cos(angle1) * radius + sin(angle2) * 30;
    final y = sin(index * 0.05) * 80.0 + cos(angle2) * 40; // Vertical spread
    final z = sin(angle1) * radius + cos(angle2) * 30;
    
    // Color selection
    final color = cubeColors[index % cubeColors.length];
    
    // Size variation
    final sizeVariation = 2.0 + sin(index * 0.1) * 1.0;
    
    return CubeData(
      position: Vector3(x, y, z),
      color: color,
      size: sizeVariation,
      index: index,
    );
  }
  
  // Get all cube data for batch processing
  static List<CubeData> getAllCubeData() {
    return List.generate(totalCubes, (index) => getCubeData(index));
  }
}

class CubeData {
  final Vector3 position;
  final Color color;
  final double size;
  final int index;
  
  const CubeData({
    required this.position,
    required this.color,
    required this.size,
    required this.index,
  });
}

class Vector3 {
  final double x;
  final double y;
  final double z;
  
  const Vector3(this.x, this.y, this.z);
  
  @override
  String toString() => 'Vector3($x, $y, $z)';
}