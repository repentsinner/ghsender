import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import '../scene.dart';
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
      final allObjects = GCodeSceneGenerator.generateSceneObjects(gcodePath);
      
      // Create camera configuration optimized for G-code visualization
      final cameraConfig = GCodeSceneGenerator.calculateCamera(gcodePath);
    
      // Create lighting configuration
      final lightConfig = LightingConfiguration(
        directionalLight: DirectionalLightData(
          direction: vm.Vector3(0, 0, -1), // Top-down lighting for CNC visualization
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
      AppLogger.info('- ${allObjects.length} rendered objects');
      AppLogger.info('- Camera at ${cameraConfig.position}');
      AppLogger.info('- Bounds: ${gcodePath.minBounds} to ${gcodePath.maxBounds}');
    } catch (e) {
      AppLogger.warning('Failed to load G-code: $e');
      AppLogger.info('Falling back to cube scene...');
      
      // Fallback to original cube scene
      await _initializeCubeScene();
    }
  }
  
  /// Fallback initialization with cube scene
  Future<void> _initializeCubeScene() async {
    // Create all cubes using the scene configuration
    final cubes = SceneConfiguration.getAllCubeData().map((cubeData) => 
      SceneObject(
        type: SceneObjectType.cube,
        position: vm.Vector3(cubeData.position.x, cubeData.position.y, cubeData.position.z),
        scale: vm.Vector3.all(cubeData.size),
        rotation: vm.Quaternion.identity(),
        color: cubeData.color,
        id: 'cube_${cubeData.index}',
      )
    ).toList();
    
    // Create coordinate axes
    final axes = [
      // X-axis (Red)
      SceneObject(
        type: SceneObjectType.axis,
        position: vm.Vector3(50.0, 0, 0), // Half length offset
        scale: vm.Vector3(100.0, 1.0, 1.0), // Long, thin box
        rotation: vm.Quaternion.identity(),
        color: Colors.red,
        id: 'axis_x',
      ),
      // Y-axis (Green)
      SceneObject(
        type: SceneObjectType.axis,
        position: vm.Vector3(0, 50.0, 0),
        scale: vm.Vector3(1.0, 100.0, 1.0),
        rotation: vm.Quaternion.identity(),
        color: Colors.green,
        id: 'axis_y',
      ),
      // Z-axis (Blue)
      SceneObject(
        type: SceneObjectType.axis,
        position: vm.Vector3(0, 0, 50.0),
        scale: vm.Vector3(1.0, 1.0, 100.0),
        rotation: vm.Quaternion.identity(),
        color: Colors.blue,
        id: 'axis_z',
      ),
    ];
    
    // Combine all scene objects
    final allObjects = [...cubes, ...axes];
    
    // Create camera configuration
    final cameraConfig = CameraConfiguration(
      position: vm.Vector3(SceneConfiguration.cameraDistance, SceneConfiguration.cameraY, 0),
      target: vm.Vector3.zero(),
      up: vm.Vector3(0, 1, 0),
      fov: SceneConfiguration.fov,
    );
    
    // Create lighting configuration
    final lightConfig = LightingConfiguration(
      directionalLight: DirectionalLightData(
        direction: vm.Vector3(0, -1, 0),
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
    
    AppLogger.info('Fallback cube scene initialized:');
    AppLogger.info('- ${cubes.length} cubes');
    AppLogger.info('- ${axes.length} coordinate axes');
    AppLogger.info('- Camera at ${cameraConfig.position}');
    AppLogger.info('- Total objects: ${allObjects.length}');
  }
  
  /// Get scene objects filtered by type
  List<SceneObject> getObjectsByType(SceneObjectType type) {
    return _sceneData.objects.where((obj) => obj.type == type).toList();
  }
  
  /// Get all cubes in the scene
  List<SceneObject> get cubes => getObjectsByType(SceneObjectType.cube);
  
  /// Get all axes in the scene  
  List<SceneObject> get axes => getObjectsByType(SceneObjectType.axis);
  
  /// Get all lines in the scene
  List<SceneObject> get lines => getObjectsByType(SceneObjectType.line);
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
  final vm.Vector3 position;
  final vm.Vector3 scale;
  final vm.Quaternion rotation;
  final Color color;
  final String id;
  
  // G-code specific properties
  final int? operationIndex;     // Index in the G-code operation sequence
  final double? estimatedTime;   // Estimated time to complete this operation (seconds)
  final bool isRapidMove;        // True for G0 (rapid positioning)
  final bool isCuttingMove;      // True for G1 (linear interpolation)
  final bool isArcMove;          // True for G2/G3 (circular interpolation)
  
  const SceneObject({
    required this.type,
    required this.position,
    required this.scale,
    required this.rotation,
    required this.color,
    required this.id,
    this.operationIndex,
    this.estimatedTime,
    this.isRapidMove = false,
    this.isCuttingMove = false,
    this.isArcMove = false,
  });
  
  /// Get transformation matrix for this object
  vm.Matrix4 get transformMatrix {
    return vm.Matrix4.compose(position, rotation, scale);
  }
}

enum SceneObjectType {
  cube,
  axis,
  line,  // For G-code path segments
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
  
  const LightingConfiguration({
    this.directionalLight,
  });
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