import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import '../scene.dart';

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
    
    print('=== INITIALIZING SHARED SCENE DATA ===');
    
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
    
    print('Scene initialized with:');
    print('- ${cubes.length} cubes');
    print('- ${axes.length} coordinate axes');  
    print('- Camera at ${cameraConfig.position}');
    print('- Total objects: ${allObjects.length}');
    print('======================================');
  }
  
  /// Get scene objects filtered by type
  List<SceneObject> getObjectsByType(SceneObjectType type) {
    return _sceneData.objects.where((obj) => obj.type == type).toList();
  }
  
  /// Get all cubes in the scene
  List<SceneObject> get cubes => getObjectsByType(SceneObjectType.cube);
  
  /// Get all axes in the scene  
  List<SceneObject> get axes => getObjectsByType(SceneObjectType.axis);
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
  
  const SceneObject({
    required this.type,
    required this.position,
    required this.scale,
    required this.rotation,
    required this.color,
    required this.id,
  });
  
  /// Get transformation matrix for this object
  vm.Matrix4 get transformMatrix {
    return vm.Matrix4.compose(position, rotation, scale);
  }
}

enum SceneObjectType {
  cube,
  axis,
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