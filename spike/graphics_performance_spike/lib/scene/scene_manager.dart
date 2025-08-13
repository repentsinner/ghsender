import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../gcode/gcode_parser.dart';
import '../gcode/gcode_scene.dart';

/// Centralized scene manager that creates and manages the 3D scene
/// All renderers receive the same scene data from this manager
class SceneManager {
  static SceneManager? _instance;
  static SceneManager get instance => _instance ??= SceneManager._();

  SceneManager._();

  // Scene data - created once and shared by all renderers
  late final SceneData _sceneData;
  bool _initialized = false;

  bool get initialized => _initialized;
  SceneData get sceneData => _sceneData;

  /// Initialize the scene data once
  Future<void> initialize() async {
    if (_initialized) return;

    AppLogger.info('Initializing G-code scene data');

    try {
      // Parse G-code file from assets
      final parser = GCodeParser();
      final gcodePath = await parser.parseAsset('assets/complex_10k.nc');

      // Generate scene objects from G-code
      final gcodeObjects = GCodeSceneGenerator.generateSceneObjects(gcodePath);

      // Add world origin axes for debugging
      final worldAxes = _createWorldOriginAxes();
      final allObjects = [...gcodeObjects, ...worldAxes];

      // Create camera configuration independent of G-code content
      final cameraConfig = _createCameraConfiguration(gcodePath);

      // Create lighting configuration
      final lightConfig = LightingConfiguration(
        directionalLight: DirectionalLightData(
          direction: vm.Vector3(
            0,
            0,
            -1,
          ), // Top-down lighting for CNC visualization
          color: Colors.white,
          intensity: 1.0,
        ),
      );

      _sceneData = SceneData(
        objects: allObjects,
        camera: cameraConfig,
        lighting: lightConfig,
      );

      _initialized = true;

      AppLogger.info('G-code scene initialized:');
      AppLogger.info('- ${gcodePath.totalOperations} G-code operations');
      AppLogger.info(
        '- ${gcodeObjects.length} G-code objects + ${worldAxes.length} world axes = ${allObjects.length} total objects',
      );
      AppLogger.info('- Camera at ${cameraConfig.position}');
      AppLogger.info(
        '- Bounds: ${gcodePath.minBounds} to ${gcodePath.maxBounds}',
      );
    } catch (e) {
      AppLogger.error('Failed to load G-code: $e');
      rethrow;
    }
  }

  /// Get scene objects filtered by type
  List<SceneObject> getObjectsByType(SceneObjectType type) {
    return _sceneData.objects.where((obj) => obj.type == type).toList();
  }

  /// Get all lines in the scene (includes coordinate axes)
  List<SceneObject> get lines => getObjectsByType(SceneObjectType.line);

  /// Create camera configuration optimized for the scene bounds
  CameraConfiguration _createCameraConfiguration(GCodePath gcodePath) {
    // Calculate scene bounds and center
    final center = (gcodePath.minBounds + gcodePath.maxBounds) * 0.5;
    final size = gcodePath.maxBounds - gcodePath.minBounds;
    final maxDimension = max(max(size.x, size.y), size.z);

    // Position camera to view the entire part with some margin
    final cameraDistance = maxDimension * 2.0;
    final cameraHeight = maxDimension * 0.8;

    // Standard CNC viewing angle - elevated and diagonal for good visibility
    return CameraConfiguration(
      position: vm.Vector3(
        center.x + cameraDistance * 0.7,
        center.y + cameraDistance * 0.7,
        center.z + cameraHeight,
      ),
      target: center,
      up: vm.Vector3(0, 0, 1), // Z-up for CNC coordinate system
      fov: 45.0,
    );
  }

  /// Create world origin coordinate axes for debugging
  List<SceneObject> _createWorldOriginAxes() {
    const double axisLength = 50.0;

    return [
      // X-axis (Red) - from origin to +X
      SceneObject(
        type: SceneObjectType.line,
        startPoint: vm.Vector3(0.0, 0.0, 0.0),
        endPoint: vm.Vector3(axisLength, 0.0, 0.0),
        color: Colors.red,
        id: 'world_axis_x',
      ),
      // Y-axis (Green) - from origin to +Y
      SceneObject(
        type: SceneObjectType.line,
        startPoint: vm.Vector3(0.0, 0.0, 0.0),
        endPoint: vm.Vector3(0.0, axisLength, 0.0),
        color: Colors.green,
        id: 'world_axis_y',
      ),
      // Z-axis (Blue) - from origin to +Z
      SceneObject(
        type: SceneObjectType.line,
        startPoint: vm.Vector3(0.0, 0.0, 0.0),
        endPoint: vm.Vector3(0.0, 0.0, axisLength),
        color: Colors.blue,
        id: 'world_axis_z',
      ),
    ];
  }
}

/// Complete scene data that all renderers receive
class SceneData {
  final List<SceneObject> objects;
  final CameraConfiguration camera;
  final LightingConfiguration lighting;

  const SceneData({
    required this.objects,
    required this.camera,
    required this.lighting,
  });
}

/// Individual object in the 3D scene
class SceneObject {
  final SceneObjectType type;
  final Color color;
  final String id;

  // Line segment properties (for SceneObjectType.line)
  final vm.Vector3? startPoint; // Start point for line segments
  final vm.Vector3? endPoint; // End point for line segments

  // G-code specific properties
  final int? operationIndex; // Index in the G-code operation sequence
  final double?
  estimatedTime; // Estimated time to complete this operation (seconds)
  final bool isRapidMove; // True for G0 (rapid positioning)
  final bool isCuttingMove; // True for G1 (linear interpolation)
  final bool isArcMove; // True for G2/G3 (circular interpolation)

  const SceneObject({
    required this.type,
    required this.color,
    required this.id,
    this.startPoint,
    this.endPoint,
    this.operationIndex,
    this.estimatedTime,
    this.isRapidMove = false,
    this.isCuttingMove = false,
    this.isArcMove = false,
  });
}

enum SceneObjectType {
  line, // For G-code path segments and coordinate axes
  cube, // For 3D cube objects
}

/// Camera configuration for the scene
class CameraConfiguration {
  final vm.Vector3 position;
  final vm.Vector3 target;
  final vm.Vector3 up;
  final double fov;

  const CameraConfiguration({
    required this.position,
    required this.target,
    required this.up,
    required this.fov,
  });
}

/// Lighting configuration for the scene
class LightingConfiguration {
  final DirectionalLightData? directionalLight;

  const LightingConfiguration({this.directionalLight});
}

class DirectionalLightData {
  final vm.Vector3 direction;
  final Color color;
  final double intensity;

  const DirectionalLightData({
    required this.direction,
    required this.color,
    required this.intensity,
  });
}
